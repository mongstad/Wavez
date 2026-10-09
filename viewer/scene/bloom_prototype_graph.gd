extends Node
## Manually attached #306 experiment. Main/UI/export workers do not load it.
const CATEGORIES = ["particles", "fields", "meshes"]
const GRID = preload("res://layers/grid_view.gd")
const SIZE_LIMIT = Vector2i(3840, 2160)
const WEIGHTED = """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_test_disabled, depth_draw_never;
uniform sampler2D particles : filter_linear, repeat_disable;
uniform sampler2D fields : filter_linear, repeat_disable;
uniform sampler2D meshes : filter_linear, repeat_disable;
uniform sampler2D base_image : filter_nearest, repeat_disable;
uniform vec3 gains;
uniform float white = 1.0;
void vertex() { POSITION = vec4(VERTEX.xy, 1.0, 1.0); }
void fragment() {
	vec3 glow = texture(particles, SCREEN_UV).rgb * gains.x
		+ texture(fields, SCREEN_UV).rgb * gains.y + texture(meshes, SCREEN_UV).rgb * gains.z;
	vec3 base = texture(base_image, SCREEN_UV).rgb;
	vec3 normalized_glow = clamp(glow / white, vec3(0.0), vec3(1.0));
	ALBEDO = base + (vec3(white) - base) * normalized_glow;
}
"""
const COMPOSITE = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D glow_image : filter_nearest, repeat_disable;
uniform bool hdr_output = false;
float encode(float x) {
	return x < 0.0031308 ? 12.92 * x : 1.055 * pow(max(x, 0.0), 1.0 / 2.4) - 0.055;
}
void fragment() {
	vec3 result = texture(glow_image, UV).rgb;
	COLOR = vec4(hdr_output ? result : vec3(encode(result.r), encode(result.g), encode(result.b)), 1.0);
}
"""
var viewer
var gains := Vector3(1.35, 0.0, 0.0)
var sources := {}
var base: SubViewport
var tone: SubViewport
var overlay: CanvasLayer
var rectangle: ColorRect
var weighted_material: ShaderMaterial
var black: ImageTexture
var original_mask := 0
var original_camera_environment: Environment
var original_glow := false
var size := Vector2i.ZERO
var error := ""
var allocation_events := 0
var release_events := 0
# Experimental admission ceiling; not an approved production policy or VRAM bound.
var reservation_limit := 2 * 1024 * 1024 * 1024
var generation := 0
var last_signature := 0
var invalidated := true

func invalidate() -> void:
	invalidated = true

func attach(target) -> bool:
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		error = "Prototype requires Forward+; Compatibility is left on its native path."
		return false
	viewer = target
	if viewer.environment.glow_blend_mode != Environment.GLOW_BLEND_MODE_SCREEN or viewer.environment.tonemap_exposure != 1.0:
		error = "Bounded prototype requires the accepted Screen glow blend and exposure 1."
		viewer = null
		return false
	original_mask = viewer.camera.cull_mask
	original_camera_environment = viewer.camera.environment
	original_glow = viewer.environment.glow_enabled
	var image := Image.create(1, 1, false, Image.FORMAT_RGBAH)
	image.fill(Color(0, 0, 0, 1))
	black = ImageTexture.create_from_image(image)
	return true

func viewport(own_world: bool, environment: Environment) -> SubViewport:
	var node := SubViewport.new()
	node.size = size
	node.use_hdr_2d = true
	node.own_world_3d = own_world
	if not own_world: node.world_3d = viewer.get_world_3d()
	node.msaa_3d = viewer.get_viewport().msaa_3d
	node.screen_space_aa = viewer.get_viewport().screen_space_aa
	node.use_taa = false # Prototype camera histories are separate; test no-TAA explicitly.
	node.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(node)
	var camera := Camera3D.new()
	camera.environment = environment
	node.add_child(camera)
	camera.current = true
	RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(), true)
	allocation_events += 1
	return node

func environment_copy(source_pass: bool) -> Environment:
	var result: Environment = viewer.environment.duplicate()
	result.glow_enabled = source_pass
	if source_pass:
		result.background_mode = Environment.BG_COLOR
		result.background_color = Color.BLACK
		result.fog_light_color = Color.BLACK
		result.fog_sun_scatter = 0.0
		result.fog_aerial_perspective = 0.0
		result.glow_blend_mode = Environment.GLOW_BLEND_MODE_REPLACE
		result.glow_intensity = 1.0 # Fixed kernel output; category gain is downstream.
		result.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		result.tonemap_exposure = 1.0
	return result

func copy_camera(target: Camera3D) -> void:
	target.global_transform = viewer.camera.global_transform
	for property in ["projection", "fov", "size", "near", "far", "keep_aspect", "frustum_offset", "h_offset", "v_offset"]:
		target.set(property, viewer.camera.get(property))

func entries() -> Array:
	var result: Array = []
	for node in [viewer.current_instance] + viewer.trail_instances:
		if is_instance_valid(node) and node.multimesh != null and node.multimesh.instance_count > 0 and node.is_visible_in_tree():
			result.append({"node":node, "category":"particles"})
	if viewer.scene_layers != null:
		for id in viewer.scene_layers.views:
			var node = viewer.scene_layers.views[id]
			if node is GRID:
				for mesh in [node.quad, node.slice]:
					if mesh.mesh != null and mesh.is_visible_in_tree(): result.append({"node":mesh, "category":"fields"})
			elif node.mesh != null and node.is_visible_in_tree(): result.append({"node":node, "category":"meshes"})
		var iso = viewer.scene_layers.iso_node
		if is_instance_valid(iso) and iso.mesh != null and iso.is_visible_in_tree(): result.append({"node":iso, "category":"fields"})
	return result

func pass_material(original: Material, emitting: bool) -> Material:
	if emitting: return original
	# Do not duplicate a live ShaderMaterial: its property-list validation can
	# replace Transform3D-backed mat4 cache values with Projection defaults.
	var result: Material = ShaderMaterial.new() if original is ShaderMaterial else original.duplicate()
	if result is StandardMaterial3D:
		result.vertex_color_use_as_albedo = false
		result.albedo_color = Color.BLACK
	elif result is ShaderMaterial:
		var program := Shader.new()
		var code: String = original.shader.code
		var end := code.rfind("}")
		program.code = code.insert(end, "\n ALBEDO = vec3(0.0); EMISSION = vec3(0.0);\n")
		result.shader = program
	return result

func sync_proxy(record: Dictionary, original: GeometryInstance3D) -> void:
	var proxy: GeometryInstance3D = record.proxy
	proxy.global_transform = original.global_transform
	proxy.extra_cull_margin = original.extra_cull_margin
	proxy.sorting_offset = original.sorting_offset
	proxy.sorting_use_aabb_center = original.sorting_use_aabb_center
	if original is MultiMeshInstance3D: proxy.multimesh = original.multimesh
	else:
		proxy.mesh = original.mesh
		if original.mesh is ArrayMesh:
			for i in original.mesh.get_blend_shape_count(): proxy.set_blend_shape_value(i, original.get_blend_shape_value(i))
	var material: Material = original.material_override
	if material == null and original is MultiMeshInstance3D: material = original.multimesh.mesh.surface_get_material(0)
	if record.original_material != material:
		record.original_material = material
		record.material = pass_material(material, record.emitting)
		proxy.material_override = record.material
	if material is ShaderMaterial and not record.emitting:
		for uniform in material.shader.get_shader_uniform_list():
			record.material.set_shader_parameter(uniform.name, material.get_shader_parameter(uniform.name))
	elif material is StandardMaterial3D and record.emitting:
		proxy.material_override = material # Read-only shared accepted mesh material.

func rebuild_proxies(pass_record: Dictionary, visible: Array, category: String) -> void:
	var records: Dictionary = pass_record.proxies
	var keep := {}
	for entry in visible:
		var original: GeometryInstance3D = entry.node
		# Accepted additive particles do not attenuate other categories.
		if entry.category == "particles" and category != "particles": continue
		var id := original.get_instance_id()
		keep[id] = true
		if not records.has(id):
			var proxy: GeometryInstance3D = MultiMeshInstance3D.new() if original is MultiMeshInstance3D else MeshInstance3D.new()
			pass_record.viewport.add_child(proxy)
			records[id] = {"proxy":proxy, "emitting":entry.category == category, "original_material":null}
		sync_proxy(records[id], original)
	for id in records.keys():
		if not keep.has(id): records[id].proxy.free(); records.erase(id)

func release(node: Node) -> void:
	if not is_instance_valid(node): return
	node.get_parent().remove_child(node)
	node.queue_free()
	if node is SubViewport: release_events += 1

func release_targets() -> void:
	for category in sources: release(sources[category].viewport)
	sources.clear()
	release(base); base = null
	release(tone); tone = null
	release(overlay); overlay = null
	if is_instance_valid(viewer):
		viewer.camera.cull_mask = original_mask
		viewer.camera.environment = original_camera_environment

func sync() -> bool:
	error = ""
	if viewer == null: return false
	# Explicit opt-in fixture path: scene environment never owns category gains.
	if viewer.environment.glow_enabled: viewer.environment.glow_enabled = false
	var next_size: Vector2i = viewer.get_viewport().get_texture().get_size()
	var visible := entries()
	var signature_values: Array = [viewer.camera.global_transform, next_size, gains, viewer.clean_view, viewer.requested_time]
	if viewer.scene_layers != null: signature_values.append(viewer.scene_layers.states)
	for entry in visible:
		var node: GeometryInstance3D = entry.node
		signature_values.append([node.get_instance_id(), node.global_transform, node.multimesh if node is MultiMeshInstance3D else node.mesh])
		var mat: Material = node.material_override
		if mat == null and node is MultiMeshInstance3D: mat = node.multimesh.mesh.surface_get_material(0)
		if mat is ShaderMaterial:
			for uniform in mat.shader.get_shader_uniform_list(): signature_values.append(mat.get_shader_parameter(uniform.name))
	var signature := hash(signature_values)
	if not invalidated and signature == last_signature: return true
	last_signature = signature; invalidated = false
	var active: Array[String] = []
	if not viewer.clean_view:
		for i in 3:
			if gains[i] <= 0.0: continue
			for entry in visible:
				if entry.category == CATEGORIES[i]: active.append(CATEGORIES[i]); break
	if active.is_empty(): release_targets(); generation += 1; return true
	# Conservative reservation model, includes private 3D intermediates/native glow.
	var reservation: int = next_size.x * next_size.y * (active.size() * 48 + 64)
	if next_size.x > SIZE_LIMIT.x or next_size.y > SIZE_LIMIT.y or reservation > reservation_limit:
		release_targets(); error = "Bloom prototype render-target reservation rejected; scientific resources unchanged."; return false
	if next_size != size: release_targets(); size = next_size
	if base == null:
		base = viewport(false, environment_copy(false))
		base.get_child(0).environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		tone = viewport(true, environment_copy(false))
		base.reparent(tone)
		tone.get_child(0).environment.background_mode = Environment.BG_COLOR
		tone.get_child(0).environment.background_color = Color.BLACK
		tone.get_child(0).environment.fog_enabled = false
		var quad := MeshInstance3D.new(); quad.mesh = QuadMesh.new(); quad.mesh.size = Vector2(2, 2); quad.extra_cull_margin = 16384
		weighted_material = ShaderMaterial.new(); var program := Shader.new(); program.code = WEIGHTED; weighted_material.shader = program
		weighted_material.set_shader_parameter("base_image",base.get_texture())
		weighted_material.set_shader_parameter("white",viewer.environment.tonemap_white)
		quad.material_override = weighted_material; tone.add_child(quad)
		overlay = CanvasLayer.new(); overlay.layer = -1; add_child(overlay)
		rectangle = ColorRect.new(); rectangle.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(rectangle)
		var composite := ShaderMaterial.new(); var shader := Shader.new(); shader.code = COMPOSITE; composite.shader = shader
		composite.set_shader_parameter("glow_image", tone.get_texture())
		rectangle.material = composite
	for category in sources.keys():
		if category not in active: release(sources[category].viewport); sources.erase(category)
	for category in active:
		if not sources.has(category):
			var source := viewport(true, environment_copy(true))
			# Native parent ordering supplies the source before the tone consumer
			# even for the worker's single force_draw/readback barrier.
			source.reparent(tone)
			sources[category] = {"viewport":source, "proxies":{}}
		var record: Dictionary = sources[category]
		copy_camera(record.viewport.get_child(0))
		rebuild_proxies(record, visible, category)
	for category in CATEGORIES:
		weighted_material.set_shader_parameter(category, sources[category].viewport.get_texture() if sources.has(category) else black)
	weighted_material.set_shader_parameter("gains", gains)
	copy_camera(base.get_child(0)); base.get_child(0).cull_mask = original_mask
	# Hide only the original root's 3D draw, never the shared instances/base camera.
	viewer.camera.cull_mask = 0
	var root_environment := Environment.new(); root_environment.background_mode = Environment.BG_COLOR
	root_environment.background_color = Color.BLACK; root_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewer.camera.environment = root_environment
	rectangle.position = Vector2.ZERO; rectangle.size = viewer.get_viewport().get_visible_rect().size
	rectangle.material.set_shader_parameter("hdr_output", viewer.get_viewport().use_hdr_2d)
	for node in [base, tone]: node.render_target_update_mode = SubViewport.UPDATE_ONCE
	for category in sources: sources[category].viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	generation += 1
	return true

func inventory() -> Dictionary:
	var proxy_count := 0
	for category in sources: proxy_count += sources[category].proxies.size()
	var count := sources.size() + (2 if base != null else 0)
	return {"active_categories":sources.keys(), "private_viewports":count, "proxies":proxy_count,
		"explicit_color_depth_min_bytes":size.x * size.y * count * 12,
		"reservation_bytes":size.x * size.y * (sources.size() * 48 + 64) if count > 0 else 0,
		"allocation_events":allocation_events, "release_events":release_events, "generation":generation}

func gpu_ms() -> float:
	var result := 0.0
	for node in [base, tone]:
		if is_instance_valid(node): result += RenderingServer.viewport_get_measured_render_time_gpu(node.get_viewport_rid())
	for category in sources: result += RenderingServer.viewport_get_measured_render_time_gpu(sources[category].viewport.get_viewport_rid())
	return result

func dispose() -> void:
	release_targets()
	if is_instance_valid(viewer): viewer.environment.glow_enabled = original_glow and not viewer.clean_view
	viewer = null
