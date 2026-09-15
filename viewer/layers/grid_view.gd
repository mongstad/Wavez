extends Node3D
const Reader = preload("res://layers/scene_reader.gd")
var quad: MeshInstance3D
var slice := MeshInstance3D.new()
var material := ShaderMaterial.new()
var slice_material := ShaderMaterial.new()
var texture: ImageTexture3D
var data := {}
var object := {}
var channel := ""
var key := ""
var gpu_bytes := 0
var lod := 1
var error := ""
var world_to_grid := Transform3D.IDENTITY
var grid_size := Vector3.ZERO
var bounds_min := Vector3.ZERO
var bounds_max := Vector3.ZERO
func setup(camera: Camera3D) -> void:
	quad = MeshInstance3D.new();var screen := QuadMesh.new();screen.size = Vector2(2,2);quad.mesh = screen
	material.shader = preload("res://layers/volume.gdshader");quad.material_override = material;quad.extra_cull_margin = 16384
	camera.add_child(quad)
	slice_material.shader = preload("res://layers/slice.gdshader");slice.material_override = slice_material;add_child(slice)
func clear() -> void:
	texture = null;data = {};key = "";gpu_bytes = 0
	material.set_shader_parameter("field_texture",null);slice_material.set_shader_parameter("field_texture",null)
	if quad != null:quad.visible = false
	slice.visible = false
func _exit_tree() -> void:
	if is_instance_valid(quad): quad.queue_free()
static func sample_key(obj: Dictionary, sequence: int, selected: String, budget: int) -> String:
	return "%s/%s/%s/%s" % [obj.id,sequence,selected,budget]
static func upload(prepared: Dictionary) -> Dictionary:
	if prepared.is_empty() or prepared.has("error"):return prepared
	var result := prepared.duplicate()
	var next := ImageTexture3D.new();var reduced: Vector3i = prepared.reduced
	if next.create(Image.FORMAT_RF,reduced.x,reduced.y,reduced.z,false,prepared.planes) != OK:return {"error":"Volume GPU allocation failed; preview released."}
	result.erase("planes");result.texture = next
	return result
func load_sample(obj: Dictionary, sample: Dictionary, selected: String, budget: int, staged: Dictionary = {}) -> bool:
	var target := sample_key(obj,sample.sequence,selected,budget)
	if key == target:return true
	clear();error = ""
	var ready := staged
	if ready.is_empty():ready = upload(preload("res://layers/field_prepare.gd").prepare(obj,sample,selected,budget))
	if ready.is_empty() or ready.has("error"):error = ready.get("error","Field preparation cancelled.");return false
	texture = ready.texture;lod = ready.lod;gpu_bytes = ready.gpu_bytes
	object = obj;data = sample;channel = selected;key = target
	world_to_grid = ready.grid_to_world.affine_inverse();grid_size = Vector3(ready.dims)
	bounds_min = Vector3.ZERO if sample.geometry.centering == "node" else Vector3.ONE*-.5
	bounds_max = grid_size-Vector3.ONE if sample.geometry.centering == "node" else grid_size-Vector3.ONE*.5
	for mat in [material,slice_material]:
		mat.set_shader_parameter("field_texture",texture);mat.set_shader_parameter("world_to_grid",world_to_grid)
		mat.set_shader_parameter("grid_size",grid_size);mat.set_shader_parameter("texture_size",Vector3(ready.reduced));mat.set_shader_parameter("bounds_min",bounds_min);mat.set_shader_parameter("bounds_max",bounds_max)
	return true
func apply(state: Dictionary, lut: Texture2D) -> void:
	if texture == null: return
	quad.visible = state.visible and state.volume;slice.visible = state.visible and state.slice
	for mat in [material,slice_material]:
		mat.set_shader_parameter("lower",state.lower);mat.set_shader_parameter("upper",state.upper);mat.set_shader_parameter("transfer",lut)
	material.set_shader_parameter("opacity",state.opacity);material.set_shader_parameter("step_world",state.step)
	material.set_shader_parameter("clip_enabled",state.clip);material.set_shader_parameter("clip_plane",Vector4(state.clip_normal[0],state.clip_normal[1],state.clip_normal[2],state.clip_distance))
	var normal := Reader.vec(state.slice_normal).normalized()
	var tangent := normal.cross(Vector3.UP if absf(normal.y)<.9 else Vector3.RIGHT).normalized();var bitangent := normal.cross(tangent).normalized()
	var transform := world_to_grid.affine_inverse();var center := transform*((bounds_min+bounds_max)*.5)
	center += normal*(float(state.slice_distance)-normal.dot(center))
	var size := 2*(transform.basis.x.length()*grid_size.x+transform.basis.y.length()*grid_size.y+transform.basis.z.length()*grid_size.z)
	if slice.mesh == null: slice.mesh = QuadMesh.new()
	slice.mesh.size = Vector2(size,size);slice.transform = Transform3D(Basis(tangent,bitangent,normal),center)
func probe(world: Vector3):
	if data.is_empty(): return null
	var p := world_to_grid*world
	if p.x < bounds_min.x or p.y < bounds_min.y or p.z < bounds_min.z or p.x > bounds_max.x or p.y > bounds_max.y or p.z > bounds_max.z: return null
	p = p.clamp(Vector3.ZERO,grid_size-Vector3.ONE)
	var lo := Vector3i(p.floor());var hi := (lo+Vector3i.ONE).min(Vector3i(grid_size)-Vector3i.ONE);var f := p-Vector3(lo);var result := 0.0
	var values = data.channels[channel];var nx := int(grid_size.x);var ny := int(grid_size.y)
	for dz in range(2):
		for dy in range(2):
			for dx in range(2):
				var value: float = values[((hi.z if dz else lo.z)*ny+(hi.y if dy else lo.y))*nx+(hi.x if dx else lo.x)]
				if not is_finite(value): return null
				result += value*(f.x if dx else 1-f.x)*(f.y if dy else 1-f.y)*(f.z if dz else 1-f.z)
	return result
