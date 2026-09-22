extends Node3D

# SimScope
# Godot 4 scientific viewer for SIMSCP3 particle, mesh and volume scenes.
#
# The renderer is observational only. It never feeds information back into the
# Python/CuPy simulation.

const TRAIL_LAYERS := 5
const DISPLAY_HZ := 30.0
const Profile = preload("res://scene/playback_profile.gd")
const Normalization = preload("res://scene/normalization.gd")
const Geometry = preload("res://scene/geometry.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const VisualState = preload("res://scene/visual_state.gd")
const SharedTimeline = preload("res://scene/timeline_sampler.gd")
var shared_timeline
var physical_rate := 1.0
var requested_time := 0.0
var committed_sample: Dictionary = {}
var capture_generation := 0
var inspection_busy := false
var inspection_paused := false
var screenshot_sidecar := false
var particle_layer_visible := true
var normalization_mode := "frame"
var cyclic := false
var range_interval: Dictionary = {}
var channel_preferences: Dictionary = {}
var range_request := 0
var geometry_override: Dictionary = {}
var geometry_metadata: Dictionary = {}
var guide_visibility := {"domain":false,"data":false,"absorber":false,"imposed":false}
var geometry_meshes: Dictionary = {}
var geometry_label: Label
var normalization_option: OptionButton
var interval_start: SpinBox
var interval_end: SpinBox
var recipe_dialog: FileDialog
var geometry_dialog: FileDialog
var recipe_saving := false

class FrameData:
	var source_index := 0
	var sim_time: float = 0.0
	var positions := PackedVector3Array()
	var intensity := PackedFloat32Array()
	var channels: Dictionary = {}
	var components: Dictionary = {}
	var scalar_cache: Dictionary = {}
	var scalar_cache_ready := false
	var has_ids := false
	var identity_map
	var ids := PackedInt64Array()
	var unavailable_channels: Array = []

var identity_pair_a: FrameData
var identity_pair_b: FrameData
var identity_matches := PackedInt32Array()
var held_positions_ready := false
var generic_reader # Native SceneReader; name retained for current scene tools.
var scene_layers
var selection_controller
# SIMSCP3-only controls; retained synchronous mode supports export and comparisons.
var scene_prebuffer_enabled := true
var scene_hidden_fast_path := true
var scene_loop_playback := false
var play_button: Button
var reader_generation := -1
var decoded_cache_mib := 256
var cache_label: Label
var fields_availability: Label
var capture: FileAccess
var capture_path := ""
var particle_count := 0
var half_extent := 40.0
var frame_count := 0
var current_index := 0
var frame_a: FrameData
var frame_b: FrameData
var history: Array[FrameData] = []

var playing := true
var phase := 0.0
var display_accum := 0.0
var mode := 0 # Reserved visual-state field in existing native recipes; no display dispatch.
var observer_scale := 1.0e28
var trails_enabled := false
var orbit_enabled := true

var camera: Camera3D
var yaw := deg_to_rad(38.0)
var pitch := deg_to_rad(24.0)
var camera_distance := 112.0
var dragging := false
var last_mouse := Vector2.ZERO

var current_instance: MultiMeshInstance3D
var current_mm: MultiMesh
var trail_instances: Array[MultiMeshInstance3D] = []
var trail_mms: Array[MultiMesh] = []
var current_sizes := PackedFloat32Array()
var current_buffer := PackedFloat32Array()

var hud: Label
var status_label: Label
var timeline: HSlider
var open_dialog: FileDialog
var overlay_panel: PanelContainer
var overlay_visible := true
var shell
var _timeline_guard := false
var environment: Environment
var starfield: MultiMeshInstance3D
var guide_mesh := MeshInstance3D.new()
var visual_panel: PanelContainer
var camera_target := Vector3.ZERO
var particle_materials: Array[ShaderMaterial] = []
var point_scale := 1.8
var exposure := 0.65
var intensity_floor := 0.08
var clean_view := false
var slice_enabled := false
var slice_x := 0.0
var glow_slider: HSlider
var legend: Label
var tail_poll := 0.0

var offline_instance := false
var video_dialog
var screenshot_directory := ""
var screenshot_dialog: FileDialog
var screenshot_pending := false
var screenshot_saving := false
var screenshot_count := 0
var screenshot_notice: Label
var screenshot_notice_serial := 0

func _ready() -> void:
	if not offline_instance:
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--simscope-render-job="):
				set_process_unhandled_input(false) # The bootstrap never builds interactive controls.
				var worker = preload("res://video/render_worker.gd").new()
				worker.job_path = argument.trim_prefix("--simscope-render-job=")
				get_tree().root.add_child.call_deferred(worker)
				guide_mesh.free() # This bootstrap instance never builds its world.
				queue_free()
				return
	_build_world()
	_build_starfield()
	_build_particles()
	_build_ui()
	_build_visual_ui()
	_build_guides()
	_update_camera()

	var args := OS.get_cmdline_user_args()
	if offline_instance: args = PackedStringArray()
	for arg in args:
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	if FileAccess.file_exists(capture_path):
		_open_capture(capture_path)
	else:
		status_label.text = "No capture loaded. Open a SIMSCP3 scene (.ssc)."
	for arg in args:
		if arg.begins_with("--inspection="): _load_inspection(arg.trim_prefix("--inspection="))

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0010, 0.0010, 0.0032)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_energy = 0.20
	# Forward+ glow turns the HDR emission in the particle shader into bloom.
	env.glow_enabled = true
	env.glow_intensity = 1.35
	env.glow_strength = 1.55
	env.glow_bloom = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.12, 0.18)
	env.fog_light_energy = 0.12
	env.fog_density = 0.0009
	env.fog_sky_affect = 0.10
	environment = env
	world_env.environment = env
	_build_backdrop(env)
	add_child(world_env)

	camera = Camera3D.new()
	camera.fov = 55.0
	camera.near = 0.05
	camera.far = 1000.0
	add_child(camera)


func _star_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

varying vec4 particle_data;

void vertex() {
    particle_data = INSTANCE_CUSTOM;
    float scale = length(MODEL_MATRIX[0].xyz);
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(INV_VIEW_MATRIX[0].xyz * scale, 0.0),
        vec4(INV_VIEW_MATRIX[1].xyz * scale, 0.0),
        vec4(INV_VIEW_MATRIX[2].xyz * scale, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float r2 = dot(uv, uv);
    if (r2 > 1.0) {
        discard;
    }
    float glow = exp(-3.5 * r2);
    vec3 c = particle_data.rgb * (0.22 + 1.6 * glow);
    ALBEDO = c;
    EMISSION = c * (0.8 + 3.0 * glow);
    ALPHA = particle_data.a * glow;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _build_starfield() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.28, 0.28)
	mesh.material = _star_material()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var star_count: int = 2400
	mm.instance_count = star_count

	var rng := RandomNumberGenerator.new()
	rng.seed = 5800813
	var shell_r: float = 420.0
	for i in range(star_count):
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var p := dir * rng.randf_range(shell_r * 0.68, shell_r)
		var s := rng.randf_range(0.18, 1.00)
		var temp_t: float = rng.randf()
		var col := Color.from_hsv(lerpf(0.56, 0.16, pow(temp_t, 1.35)), rng.randf_range(0.08, 0.32), rng.randf_range(0.6, 1.0), rng.randf_range(0.10, 0.35))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), p))
		mm.set_instance_custom_data(i, col)

	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	starfield = inst

func _particle_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float exposure = 0.65;
uniform float gamma_value = 1.0;
uniform float brightness_gain = 1.0;
uniform bool scalar_map = false;
uniform sampler2D colormap_lut : filter_linear, repeat_disable;
uniform float point_scale = 1.8;
uniform bool slice_enabled = false;
uniform float slice_x = 0.0;
uniform float slice_width = 3.0;
uniform bool clean_view = false;
varying vec4 particle_data;
varying float world_x;
void vertex() {
    particle_data = INSTANCE_CUSTOM;
    world_x = MODEL_MATRIX[3].x;
    float scale = length(MODEL_MATRIX[0].xyz) * point_scale;
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(INV_VIEW_MATRIX[0].xyz * scale, 0.0),
        vec4(INV_VIEW_MATRIX[1].xyz * scale, 0.0),
        vec4(INV_VIEW_MATRIX[2].xyz * scale, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
    if (slice_enabled && abs(world_x - slice_x) > slice_width) discard;
    vec2 uv = UV * 2.0 - 1.0;
    float r2 = dot(uv, uv);
    if (r2 > 1.0) discard;
    float core = exp(-32.0 * r2);
    float halo = exp(-5.0 * r2) * pow(1.0-r2, 2.0);
    float rays = exp(-65.0 * abs(uv.x * uv.y)) * exp(-8.0 * r2);
    float light = clean_view ? exp(-14.0*r2) : 0.65*halo + 1.3*core + 0.08*rays;
    vec3 rgb = scalar_map ? texture(colormap_lut, vec2((particle_data.r * 255.0 + 0.5) / 256.0, 0.5)).rgb * particle_data.g : particle_data.rgb;
    rgb = pow(max(rgb * brightness_gain, vec3(0.0)), vec3(1.0 / gamma_value));
    ALBEDO = rgb * exposure;
    EMISSION = rgb * exposure * 3.0;
    ALPHA = particle_data.a * light;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	particle_materials.append(mat)
	return mat

func _make_particle_layer() -> Dictionary:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.36, 0.36)
	mesh.material = _particle_material()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh

	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	return {"instance": inst, "multimesh": mm}

func _build_particles() -> void:
	var layer: Dictionary = _make_particle_layer()
	current_instance = layer["instance"] as MultiMeshInstance3D
	current_mm = layer["multimesh"] as MultiMesh
	for _i in range(TRAIL_LAYERS):
		var trail: Dictionary = _make_particle_layer()
		trail_instances.append(trail["instance"] as MultiMeshInstance3D)
		trail_mms.append(trail["multimesh"] as MultiMesh)

func _build_ui() -> void:
	_build_inspector_controls()
	shell = preload("res://ui/shell/viewer_shell.gd").new()
	overlay_panel.get_parent().add_child(shell)
	shell.setup(self)
	# Neutral dock owns the retained canonical controls pending UX4 migration.
	overlay_panel.get_parent().move_child(overlay_panel, -1)
	overlay_panel.get_parent().move_child(resize_handle, -1)
	get_viewport().size_changed.connect(shell.layout)
	if offline_instance:
		set_process_unhandled_input(false)
		shell.prepare_export({})

func _open_from_picker(path: String) -> void:
	if shell != null:
		shell.begin_open()
		await get_tree().process_frame
		await get_tree().process_frame
	_open_capture(path)

func _show_open_dialog() -> void:
	open_dialog.popup_centered_ratio(0.78)

func _toggle_overlay() -> void:
	if shell.immersive: return
	shell.toggle_dock()
	_update_particle_legend()

func _toggle_fullscreen() -> void:
	if shell != null and shell.immersive:
		shell.exit_immersive(); return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if shell != null: shell.refresh.call_deferred()

func _open_capture(path: String) -> void:
	if shell != null: shell.begin_open()
	var started := Profile.begin()
	_open_capture_profiled(path)
	Profile.end("open_inclusive",started)
	if shell != null: shell.finish_open(_shell_open_error)

var _shell_open_error := ""

func _open_capture_profiled(path: String) -> void:
	_shell_open_error = ""
	if inspection_busy:
		_shell_open_error = "Inspection is busy. Try opening the capture again when it finishes."
		return
	_open_scene(path)

func _refresh_frame_count() -> void:
	var started := Profile.begin()
	_refresh_frame_count_profiled()
	Profile.end("index_refresh_inclusive",started)

func _refresh_frame_count_profiled() -> void:
	if scene_layers != null:
		scene_layers.refresh()
		_set_timeline_extent()

func _read_frame(index: int) -> FrameData:
	var started := Profile.begin()
	var result := _read_frame_profiled(index)
	Profile.end("read_frame_inclusive",started)
	return result

func _read_frame_profiled(index: int) -> FrameData:
	return scene_layers.particle_frame_at_union(index) if scene_layers != null else null

func _process(delta: float) -> void:
	var started := Profile.begin()
	_process_profiled(delta)
	Profile.end("process_inclusive",started)

func _process_profiled(delta: float) -> void:
	if offline_instance or inspection_busy or inspection_paused: return
	if scene_layers != null:
		scene_layers.tick(delta)
		return
	_move_free_camera(delta)
	if orbit_enabled and not dragging:
		yaw += delta * orbit_speed
		_update_camera()

func _render_current(alpha: float) -> void:
	var started := Profile.begin()
	_render_current_profiled(alpha)
	Profile.end("interpolation_submission_inclusive",started)

func _render_current_profiled(alpha: float) -> void:
	if scene_layers != null and not scene_layers.publishing: scene_layers.resample();return
	if frame_a == null:
		return
	var b: FrameData = frame_b if frame_b != null else frame_a
	var positions := frame_a.positions
	var next := b.positions
	var matching := frame_a.has_ids and b.has_ids
	var weight := clampf(alpha,0,1)
	if not matching and held_positions_ready:
		_commit_sample(alpha)
		return
	if matching: _prepare_identity_pair(b)
	var pack_started := Profile.begin()
	# Row-major 3x4 transform followed by RGBA custom data (16 floats).
	for i in range(particle_count):
		var p := positions[i]
		if matching and identity_matches[i] >= 0: p = p.lerp(next[identity_matches[i]],weight)
		if not p.is_finite(): p = Vector3.ZERO
		var offset := i*16
		current_buffer[offset+3] = p.x
		current_buffer[offset+7] = p.y
		current_buffer[offset+11] = p.z
	Profile.end("interpolation_pack",pack_started)
	var upload_started := Profile.begin()
	current_mm.buffer = current_buffer
	held_positions_ready = not matching
	Profile.end("buffer_submit",upload_started)
	_commit_sample(alpha)

func _rebuild_style() -> void:
	if scene_layers != null and scene_layers.use_async() and not scene_layers.publishing:scene_layers.resample();return
	var started := Profile.begin()
	_rebuild_style_profiled()
	Profile.end("style_inclusive",started)

func _rebuild_style_profiled() -> void:
	_rebuild_generic_style()

func _rebuild_trails() -> void:
	if scene_layers != null and scene_layers.use_async() and not scene_layers.publishing:scene_layers.resample();return
	var started := Profile.begin()
	_rebuild_trails_profiled()
	Profile.end("trails_inclusive",started)

func _rebuild_trails_profiled() -> void:
	if not _has_particle_ids(): trails_enabled = false
	if not trails_enabled or clean_view: history.clear()
	_rebuild_generic_trails()

func _clear_trails() -> void:
	history.clear()
	_rebuild_trails()

func _robust_high(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 1.0
	var sample: Array[float] = []
	var stride: int = maxi(1, int(values.size() / 2048))
	var i := 0
	while i < values.size():
		sample.append(values[i])
		i += stride
	sample.sort()
	var idx: int = clampi(int(sample.size() * 0.99), 0, sample.size() - 1)
	return maxf(sample[idx], 1.0e-10)

func _toggle_trails() -> void:
	trails_enabled = not trails_enabled
	_sync_control_state()
	_rebuild_trails()

func _timeline_changed(value: float) -> void:
	if _timeline_guard or capture == null:
		return
	_seek_frame(int(value))

func _seek_frame(index: int) -> void:
	if scene_layers == null: return
	if index >= 0 and index < frame_count: scene_layers.seek(generic_reader.frames[index].time)

func _update_hud() -> void:
	var started := Profile.begin()
	_update_hud_profiled()
	Profile.end("hud_cpu",started)
	if shell != null: shell.refresh()

func _update_hud_profiled() -> void:
	if cache_label != null: cache_label.text = generic_reader.status() if generic_reader != null else "No scene loaded"
	if scene_layers != null and frame_a != null:
		var population := "%d particles" % particle_count if not scene_layers.particle_id.is_empty() else "%d scene layers" % generic_reader.objects.size()
		hud.text = "SimScope • %s\nFrame %d / %d  ·  t = %.5f\n%s\n%s" % [generic_reader.metadata.get("simulation_name", capture_path.get_file()), current_index + 1, frame_count, committed_sample.get("requested_time",frame_a.sim_time), population, _sample_label()]

func _input(event: InputEvent) -> void:
	# Recovery precedes GUI, busy-inspection and selection input handling.
	if shell != null and shell.immersive and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		shell.exit_immersive()
		get_viewport().set_input_as_handled()
		return
	# A release over chrome must still end a drag that started in the viewport.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		resizing_panel = false

func _unhandled_input(event: InputEvent) -> void:
	if inspection_busy: return
	var editor := get_viewport().gui_get_focus_owner()
	if event is InputEventKey and (editor is LineEdit or editor is TextEdit or editor is SpinBox): return
	if selection_controller != null and selection_controller.handle_input(event):get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				var focused := get_viewport().gui_get_focus_owner()
				if focused != null: focused.release_focus()
			dragging = mouse_button.pressed
			last_mouse = mouse_button.position
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(8.0, camera_distance * 0.90)
			_update_camera()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(500.0, camera_distance * 1.11)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		var d: Vector2 = mouse_event.position - last_mouse
		last_mouse = mouse_event.position
		yaw -= d.x * 0.006
		pitch -= d.y * 0.006
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT: _step_frame(-1)
			KEY_RIGHT: _step_frame(1)
			KEY_SPACE: _toggle_playback()
			KEY_O: orbit_enabled = not orbit_enabled; inspection_paused = false; _sync_control_state()
			KEY_T: _toggle_trails()
			KEY_F: _focus_activity()
			KEY_V: _set_point_rendering(not clean_view)
			KEY_P: _save_image()
			KEY_F1: _toggle_overlay()
			KEY_F11:
				if event.shift_pressed and shell != null:
					if shell.immersive: shell.exit_immersive()
					else: shell.enter_immersive()
				else: _toggle_fullscreen()
			KEY_R: _reset_camera()

func _reset_camera() -> void:
	camera_target = Vector3.ZERO; yaw = deg_to_rad(38.0); pitch = deg_to_rad(24.0); camera_distance = maxf(30.0, half_extent * 2.8); _update_camera()

func _update_camera() -> void:
	# Carry the camera up axis through the poles instead of reconstructing it
	# from world-up (look_at becomes singular at +/-90 degrees and flips beyond).
	# This is the existing yaw/pitch orbit with continuous orientation; keeping
	# those angles also preserves recipe fields and independent world-Y auto orbit.
	var orientation := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	camera.transform = Transform3D(orientation, camera_target + orientation.z * camera_distance)

func _comma(v: Variant) -> String:
	var s := str(v)
	var out := ""
	var n := s.length()
	for i in range(n):
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


func _build_backdrop(env: Environment) -> void:
	var shader := Shader.new()
	shader.code = """
shader_type sky;
void sky() {
    vec3 d = normalize(EYEDIR);
    float belt = exp(-pow((d.y + 0.24*d.x) * 5.0, 2.0));
    float cloud = 0.5 + 0.20*sin(d.x*17.0 + sin(d.z*13.0)) + 0.16*sin(d.z*29.0+d.y*9.0);
    float dust = 0.6 + 0.4*sin(d.z*22.0+sin(d.x*31.0));
    COLOR = vec3(0.001, 0.002, 0.006) + belt*cloud*mix(vec3(0.012,0.022,0.043),vec3(0.032,0.014,0.048),dust);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var sky := Sky.new()
	sky.sky_material = mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY

func _visual_slider(parent: VBoxContainer, title: String, low: float, high: float, initial: float, action: Callable) -> HSlider:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("91b6ca"))
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high-low)/100.0
	slider.value = initial
	slider.value_changed.connect(action)
	parent.add_child(slider)
	visual_sliders[title] = slider
	return slider

func _build_visual_ui() -> void:
	_sync_visuals()

func _sync_visuals() -> void:
	var started := Profile.begin()
	_sync_visuals_profiled()
	Profile.end("shader_uniforms_cpu",started)

func _sync_visuals_profiled() -> void:
	for mat in particle_materials:
		mat.set_shader_parameter("brightness_gain", brightness_scale)
		mat.set_shader_parameter("gamma_value", gamma)
		mat.set_shader_parameter("scalar_map", scene_layers != null and color_channel not in ["fixed", "visual_color"])
		if map_texture != null: mat.set_shader_parameter("colormap_lut", map_texture)
		mat.set_shader_parameter("exposure", exposure)
		mat.set_shader_parameter("point_scale", point_scale)
		mat.set_shader_parameter("clean_view", clean_view)
		mat.set_shader_parameter("slice_enabled", slice_enabled)
		mat.set_shader_parameter("slice_x", slice_x * half_extent)

func _set_point_rendering(value: bool) -> void:
	clean_view = value
	_sync_control_state()
	_sync_visuals()
	_rebuild_trails()

func _set_clean(value: bool) -> void:
	# Viewing presets retain their combined particle/environment behavior.
	_set_point_rendering(value)
	environment.background_mode = Environment.BG_COLOR if value else Environment.BG_SKY
	environment.glow_enabled = not value
	environment.fog_enabled = not value
	starfield.visible = not value
	glow_slider.editable = not value
	status_label.text = "Scientific view — decorative backdrop and bloom disabled." if value else "Cinematic view — artistic backdrop, halos and bloom enabled."

func _build_guides() -> void:
	if guide_mesh.get_parent() == null:
		add_child(guide_mesh)
		guide_mesh.visible = false
	var vertices := PackedVector3Array()
	for axis in range(3):
		var p := Vector3.ZERO; var q := Vector3.ZERO
		p[axis] = -half_extent; q[axis] = half_extent
		vertices.append_array([p,q])
	for n in range(-4,5):
		var offset := n*half_extent/4
		vertices.append_array([Vector3(-half_extent,0,offset),Vector3(half_extent,0,offset),Vector3(offset,0,-half_extent),Vector3(offset,0,half_extent)])
	guide_mesh.mesh = Geometry.lines(vertices,Color(0.35,0.50,0.62,0.35))
	_apply_geometry()
	_sync_visuals()

func _focus_activity() -> void:
	if scene_layers != null:scene_layers.frame_scene();return
	if frame_a == null: return
	var high := _robust_high(frame_a.intensity)
	var center := Vector3.ZERO
	var weight := 0.0
	for i in range(particle_count):
		var w := clampf(frame_a.intensity[i]/high, 0.0, 1.0)
		if w < maxf(intensity_floor, 0.15): continue
		center += frame_a.positions[i]*w
		weight += w
	if weight <= 0.0: return
	camera_target = center/weight
	var radius2 := 0.0
	for i in range(particle_count):
		var w := clampf(frame_a.intensity[i]/high, 0.0, 1.0)
		if w >= maxf(intensity_floor, 0.15):
			radius2 += frame_a.positions[i].distance_squared_to(camera_target)*w
	camera_distance = clampf(sqrt(radius2/weight)*3.5, 8.0, 500.0)
	_update_camera()

func _save_image() -> void:
	if screenshot_pending or screenshot_saving: return
	if screenshot_directory.is_empty():
		if screenshot_dialog == null:
			screenshot_dialog = FileDialog.new()
			screenshot_dialog.title = "Choose screenshot folder (this session)"
			screenshot_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			screenshot_dialog.access = FileDialog.ACCESS_FILESYSTEM
			screenshot_dialog.dir_selected.connect(_screenshot_directory_selected)
			screenshot_dialog.canceled.connect(func(): screenshot_pending = false)
			add_child(screenshot_dialog)
		screenshot_pending = true
		screenshot_dialog.popup_centered_ratio(.65)
		return
	await _write_screenshot()

func _screenshot_directory_selected(path: String) -> void:
	if not screenshot_pending: return
	screenshot_pending = false
	if not DirAccess.dir_exists_absolute(path):
		_notify_screenshot("Screenshot folder is unavailable: " + path)
		return
	screenshot_directory = path
	screenshot_saving = true
	await get_tree().process_frame # Let the directory chooser disappear first.
	await _write_screenshot()

func _write_screenshot() -> void:
	screenshot_saving = true
	if screenshot_notice != null: screenshot_notice.hide()
	screenshot_count += 1
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := screenshot_directory.path_join("simscope-%s-%d-%04d.png" % [stamp, Time.get_ticks_usec(), screenshot_count])
	while FileAccess.file_exists(path): path = path.get_basename() + "-1.png"
	var result: Error = await _capture_inspection_png(path,screenshot_sidecar)
	screenshot_saving = false
	_notify_screenshot("Saved " + path if result == OK else "Could not save PNG: " + path)

func _notify_screenshot(message: String) -> void:
	status_label.text = message
	if screenshot_notice == null:
		screenshot_notice = Label.new()
		screenshot_notice.position = Vector2(20, 12)
		screenshot_notice.add_theme_color_override("font_color", Color.WHITE)
		screenshot_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
		screenshot_notice.add_theme_constant_override("shadow_offset_x", 2)
		screenshot_notice.add_theme_constant_override("shadow_offset_y", 2)
		screenshot_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_panel.get_parent().add_child(screenshot_notice)
	screenshot_notice.text = message
	screenshot_notice.visible = shell == null or not shell.immersive
	screenshot_notice_serial += 1
	var serial := screenshot_notice_serial
	await get_tree().create_timer(5).timeout
	if is_instance_valid(screenshot_notice) and serial == screenshot_notice_serial: screenshot_notice.hide()

# SimScope inspector and generic visualization layer.
var inspector_box: VBoxContainer
var sections: Dictionary = {}
var color_option: OptionButton
var size_option: OptionButton
var brightness_option: OptionButton
var colormap_option: OptionButton
var filter_box: VBoxContainer
var generic_box: VBoxContainer
var colorbar: TextureRect
var color_channel := "fixed"
var size_channel := "fixed"
var brightness_channel := "fixed"
var colormap_name := "viridis"
var colormaps: Dictionary = {}
var map_texture: ImageTexture
var auto_range := true
var logarithmic := false
var invert_map := false
var clamp_map := true
var manual_min := 0.0
var manual_max := 1.0
var range_min := 0.0
var range_max := 1.0
var show_legend := true
var hidden_types: Dictionary = {}
var brightness_scale := 1.0
var gamma := 1.0
var orbit_speed := 0.08
var free_camera := false
var panel_width := 340.0
var resizing_panel := false
var resize_handle: Control
var control_checks: Dictionary = {}
var manual_spins: Array[SpinBox] = []
var selected_preset := "Cinematic"
const VIEWING_PRESETS := ["Cinematic", "Scientific", "Temperature", "Density", "Velocity", "Minimal / Presentation"]
var preset_available := {}
var tools_ui
var legacy_sections := {}
var channel_signature := ""
var filter_values := PackedFloat64Array()
var filter_source_generation := -1
var filter_hidden_types: Dictionary = {}
var mapping_guard := false
var visual_sliders: Dictionary = {}
var section_buttons: Dictionary = {}

func _section(title: String, expanded := false) -> VBoxContainer:
	if tools_ui.SECTIONS.has(title):
		legacy_sections[title] = expanded
		return tools_ui.form(tools_ui.SECTIONS[title])
	var toggle := Button.new()
	toggle.text = title
	toggle.toggle_mode = true
	toggle.button_pressed = expanded
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	inspector_box.add_child(toggle)
	var body := VBoxContainer.new()
	body.visible = expanded
	body.add_theme_constant_override("separation", 5)
	inspector_box.add_child(body)
	toggle.toggled.connect(func(v: bool): body.visible = v)
	sections[title] = body
	section_buttons[title] = toggle
	return body

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _check(parent: Control, title: String, initial: bool, action: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = title
	check.button_pressed = initial
	check.toggled.connect(action)
	parent.add_child(check)
	control_checks[title] = check
	return check

func _option(parent: Control, title: String) -> OptionButton:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option)
	return option

func _build_inspector_controls() -> void:
	colormaps = JSON.parse_string(FileAccess.get_file_as_string("res://colormaps.json"))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	overlay_panel = PanelContainer.new()
	canvas.add_child(overlay_panel)
	tools_ui = preload("res://ui/shell/viewer_tools.gd").new(); add_child(tools_ui); tools_ui.setup(self,canvas)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay_panel.add_child(scroll)
	inspector_box = VBoxContainer.new()
	inspector_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector_box)
	hud = Label.new()
	hud.text = "SimScope"
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_box.add_child(hud)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_box.add_child(status_label)
	resize_handle = Control.new()
	resize_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	canvas.add_child(resize_handle)
	fields_availability = Label.new();fields_availability.text = "Fields unavailable • no grid recorded";fields_availability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;inspector_box.add_child(fields_availability)
	var data_controls := _section("Data cache")
	cache_label = Label.new(); cache_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	data_controls.add_child(cache_label)
	var budget := SpinBox.new(); budget.min_value = 0; budget.max_value = 2048; budget.step = 64
	budget.value = decoded_cache_mib; budget.suffix = "MiB"; data_controls.add_child(budget)
	budget.tooltip_text = "Decoded frame cache budget. 0 disables caching. Displayed frames and rendering use additional memory."
	budget.value_changed.connect(func(value: float):
		decoded_cache_mib = int(value)
		if generic_reader != null: generic_reader.configure_cache(decoded_cache_mib*1048576,false)
		_update_hud())
	_button(data_controls,"Clear decoded cache",func():
		if generic_reader != null:
			generic_reader.configure_cache(0,false)
			generic_reader.configure_cache(decoded_cache_mib*1048576,false)
		_update_hud())
	var rendering := _section("Rendering", true)
	_visual_slider(rendering, "Particle size", 0.1, 8, point_scale, func(v: float): point_scale = v; _sync_visuals())
	_visual_slider(rendering, "Brightness", 0.0, 5, brightness_scale, func(v: float): brightness_scale = v; _restyle())
	_check(rendering, "Point rendering", clean_view, func(v: bool): _set_point_rendering(v))
	var colors := _section("Color Mapping", true)
	generic_box = VBoxContainer.new()
	colors.add_child(generic_box)
	color_option = _option(generic_box, "Color by")
	color_option.item_selected.connect(func(i: int): _choose_color(color_option.get_item_text(i)))
	colormap_option = _option(generic_box, "Colormap")
	for name in colormaps: colormap_option.add_item(name)
	colormap_option.item_selected.connect(func(i: int): colormap_name = colormap_option.get_item_text(i); _remember_mapping(); _update_colormap(); _restyle())
	normalization_option = _option(generic_box,"Range policy")
	for label in Normalization.LABELS: normalization_option.add_item(label)
	normalization_option.item_selected.connect(func(i: int): _set_normalization(Normalization.MODES[i]))
	_button(generic_box,"Symmetric about zero",func(): _set_normalization("symmetric"))
	var advanced_toggle := Button.new()
	advanced_toggle.text = "Advanced normalization"
	advanced_toggle.toggle_mode = true
	generic_box.add_child(advanced_toggle)
	var advanced_color := VBoxContainer.new()
	advanced_color.visible = false
	generic_box.add_child(advanced_color)
	advanced_toggle.toggled.connect(func(v: bool): advanced_color.visible = v)
	var norm := _check(tools_ui.form("Mapping"), "Logarithmic", false, func(v: bool): logarithmic = v; _remember_mapping(); _restyle())
	norm.tooltip_text = "Only finite positive values are valid; signed channels cannot use ordinary logarithms."
	_check(tools_ui.form("Mapping"),"Cyclic phase",false,func(v: bool): cyclic = v; logarithmic = false if v else logarithmic; _remember_mapping(); _restyle())
	interval_start = _inspection_number(tools_ui.form("Derive range"),"Interval start",0)
	interval_end = _inspection_number(tools_ui.form("Derive range"),"Interval end",1)
	_button(tools_ui.form("Derive range"),"Freeze range from recorded interval",_freeze_interval)
	_button(tools_ui.form("Derive range"),"Cancel range scan",func(): range_request += 1)
	for key in ["Minimum", "Maximum"]:
		var label := Label.new()
		label.text = "Manual " + key
		advanced_color.add_child(label)
		var spin := SpinBox.new()
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.step = 0.001
		spin.value = 0 if key == "Minimum" else 1
		spin.value_changed.connect(func(v: float):
			if key == "Minimum": manual_min = v
			else: manual_max = v
			_remember_mapping()
			_restyle())
		advanced_color.add_child(spin)
		manual_spins.append(spin)
		spin.editable = not auto_range
	_check(generic_box, "Invert", false, func(v: bool): invert_map = v; _restyle())
	_check(tools_ui.form("Mapping"), "Clamp out-of-range values", true, func(v: bool): clamp_map = v; _restyle())
	_check(generic_box, "Show legend", true, func(v: bool): show_legend = v; _restyle())
	colorbar = TextureRect.new()
	colorbar.custom_minimum_size = Vector2(0, 18)
	colorbar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.add_child(colorbar)
	colorbar.position = Vector2(1060, 818)
	colorbar.size = Vector2(340, 18)
	colorbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend = Label.new()
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(legend)
	legend.position = Vector2(1060, 842)
	legend.size = Vector2(340, 90)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mappings := _section("Advanced • Size / Brightness")
	size_option = _option(mappings, "Size by")
	size_option.item_selected.connect(func(i: int): size_channel = size_option.get_item_text(i); _restyle())
	brightness_option = _option(mappings, "Brightness by")
	brightness_option.item_selected.connect(func(i: int): brightness_channel = brightness_option.get_item_text(i); _restyle())
	mappings.tooltip_text = "Semantic size and brightness use a per-frame finite linear range. Visual overrides are direct multipliers."
	var cam := _section("Camera")
	_visual_slider(cam, "Orbit speed • radians / second", -0.5, 0.5, orbit_speed, func(v: float): orbit_speed = v)
	var trails := _section("Trails")
	_check(trails, "Recorded history  [T]", trails_enabled, func(v: bool): trails_enabled = v; _rebuild_trails())
	filter_box = _section("Particle Filters")
	var post := _section("Advanced • Post-processing")
	_visual_slider(post, "Exposure", .05, 3, exposure, func(v: float): exposure = v; _sync_visuals())
	_visual_slider(post, "Gamma", .2, 3, gamma, func(v: float): gamma = v; _sync_visuals())
	glow_slider = _visual_slider(post, "Bloom", 0, 2, environment.glow_intensity, func(v: float): environment.glow_intensity = v)
	_check(tools_ui.form("Slice"), "X slice • ±3 simulation units", false, func(v: bool): slice_enabled = v; _sync_visuals())
	_visual_slider(tools_ui.form("Slice"), "Slice position • box fraction", -1, 1, 0, func(v: float): slice_x = v; _sync_visuals())
	_build_geometry_ui()
	selection_controller = preload("res://selection/selection_controller.gd").new()
	add_child(selection_controller);selection_controller.setup(self)
	var export_box := _section("Capture / Export")
	_button(export_box, "Image", _save_image)
	_check(export_box,"PNG inspection JSON sidecar",false,func(v: bool): screenshot_sidecar = v).text = "Inspection sidecar"
	video_dialog = preload("res://video/export_dialog.gd").new()
	video_dialog.viewer = self
	add_child(video_dialog)
	tools_ui.finish_static()
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.filters = PackedStringArray(["*.ssc ; SimScope scene (SIMSCP3)"])
	open_dialog.file_selected.connect(_open_from_picker)
	canvas.add_child(open_dialog)
	_update_colormap()
	_refresh_mapping_options()

func _toggle_playback() -> void:
	if not playing and scene_layers != null and scene_layers.is_buffering():return
	playing = not playing;inspection_paused = false

func _step_frame(direction: int) -> void:
	playing = false
	_timeline_changed(clampi(current_index + direction, 0, maxi(0, frame_count - 1)))

func _move_free_camera(delta: float) -> void:
	if not free_camera or get_viewport().gui_get_focus_owner() != null: return
	var move := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	camera_target += camera.global_basis * move * delta * maxf(1, camera_distance * .5)
	_update_camera()

func _apply_preset(name: String) -> void:
	selected_preset = name
	_set_clean(name != "Cinematic")
	if name in ["Temperature", "Density", "Velocity"]:
		var requested := name.to_lower() if name != "Velocity" else "velocity_magnitude"
		if _scalar_channels(frame_a,requested == "velocity_magnitude").has(requested):
			color_channel = requested
			channel_signature = ""
			_refresh_mapping_options()
		else: status_label.text = "Capture has no " + requested + " channel."
	if name == "Minimal / Presentation" and overlay_visible: _toggle_overlay()
	_restyle()

func _open_scene(path: String) -> void:
	var reader = preload("res://layers/scene_reader.gd").new()
	if not reader.open(path):
		status_label.text = reader.error; _shell_open_error = reader.error; return
	tools_ui.close(false)
	_reset_inspection_source()
	if generic_reader != null: generic_reader.close()
	generic_reader = reader;reader_generation = reader.generation
	reader.configure_cache(decoded_cache_mib*1048576,false)
	capture = reader.file;capture_path = path;frame_count = reader.frames.size()
	frame_a = null;frame_b = null;current_index = 0;phase = 0;history.clear();hidden_types.clear();channel_signature = ""
	color_channel = "fixed";size_channel = "fixed";brightness_channel = "fixed"
	current_mm.instance_count = 0
	for mm in trail_mms: mm.instance_count = 0
	scene_layers = preload("res://layers/scene_layers.gd").new();add_child(scene_layers);scene_layers.setup(self,reader)
	_set_timeline_extent()
	if frame_count == 0: status_label.text = "Waiting for a complete scene sample.";return
	requested_time = reader.frames[0].time
	scene_layers.sample(requested_time)
	scene_layers.frame_scene()
	_build_guides();_apply_geometry();_update_camera();_sync_visuals();_sync_inspection_controls()
	status_label.text = "Loaded %s • SIMSCP3 • %d layer samples" % [path.get_file(),reader.records.size()]
	scene_layers.playback.begin(requested_time)
	_update_hud()

func _frame_from_data(data: Dictionary, index: int) -> FrameData:
	var decode_started := Profile.begin()
	if data.is_empty():
		status_label.text = generic_reader.error
		current_mm.instance_count = 0; committed_sample.clear(); playing = false
		return null
	var fr := FrameData.new()
	fr.source_index = index
	fr.sim_time = data.time
	fr.channels = data.channels
	fr.components = data.components
	fr.unavailable_channels = data.get("unavailable_channels",[])
	fr.has_ids = data.get("has_ids",false)
	fr.identity_map = data.get("identity_map")
	if fr.has_ids: fr.ids = fr.channels.particle_id
	if data.has("_display_positions"):
		fr.positions = data._display_positions;fr.intensity = data._display_intensity
		fr.scalar_cache = data._display_scalars.duplicate();fr.scalar_cache_ready = true
		Profile.end("position_decode",decode_started)
		return fr
	var xyz = fr.channels.position
	# Keep source precision; cast only the display copy to the engine's Vector3.
	if xyz is PackedFloat32Array and PackedVector3Array([Vector3.ZERO]).to_byte_array().size() == 12:
		fr.positions = xyz.to_byte_array().to_vector3_array()
	else:
		fr.positions.resize(data.count)
		for i in range(data.count):
			fr.positions[i] = Vector3(xyz[i*3], xyz[i*3+1], xyz[i*3+2])
			if not fr.positions[i].is_finite():
				status_label.text = "Position exceeds the viewer coordinate range; source values remain unchanged."
				current_mm.instance_count = 0;committed_sample.clear();playing = false
				Profile.end("position_decode",decode_started)
				return null
	fr.intensity.resize(data.count)
	fr.intensity.fill(1.0)
	Profile.end("position_decode",decode_started)
	return fr

func _scalar_channels(fr: FrameData, derive_velocity := true) -> Dictionary:
	if fr == null: return {}
	if not fr.scalar_cache_ready:
		Profile.count("scalar_cache_miss")
		for key in fr.channels:
			if fr.components[key] == 1 and key != "particle_id": fr.scalar_cache[key] = fr.channels[key]
		fr.scalar_cache_ready = true
	else: Profile.count("scalar_cache_hit")
	if derive_velocity and not fr.scalar_cache.has("velocity_magnitude") and _has_velocity(fr):
		var started := Profile.begin()
		var values: PackedFloat64Array = Normalization.values64(fr.channels.velocity)
		var magnitude := PackedFloat32Array()
		magnitude.resize(fr.positions.size())
		for i in range(magnitude.size()): magnitude[i] = Vector3(values[i*3], values[i*3+1], values[i*3+2]).length()
		fr.scalar_cache.velocity_magnitude = magnitude
		Profile.end("scalar_derivation",started)
	return fr.scalar_cache

func _has_velocity(fr: FrameData) -> bool:
	return fr != null and fr.components.get("velocity",0) == 3

func _fill_options(option: OptionButton, choices: Array, selected: String) -> String:
	option.clear()
	for key in choices: option.add_item(key)
	var index := choices.find(selected)
	option.select(maxi(0, index))
	return choices[maxi(0, index)]

func _refresh_mapping_options() -> void:
	var started := Profile.begin()
	_refresh_mapping_options_profiled()
	Profile.end("ui_mapping_inclusive",started)

func _refresh_mapping_options_profiled() -> void:
	if fields_availability != null:fields_availability.visible = scene_layers == null
	if generic_box == null: return
	generic_box.visible = scene_layers != null and not scene_layers.particle_id.is_empty()
	size_option.disabled = scene_layers == null
	brightness_option.disabled = scene_layers == null
	var available := _scalar_channels(frame_a, false).duplicate() if scene_layers != null else {}
	if scene_layers != null and _has_velocity(frame_a): available.velocity_magnitude = true
	for preset_name in VIEWING_PRESETS:
		var required: String = "velocity_magnitude" if preset_name == "Velocity" else preset_name.to_lower()
		preset_available[preset_name] = not preset_name in ["Temperature", "Density", "Velocity"] or available.has(required)
	if scene_layers == null:
		legend.visible = false
		colorbar.visible = false
		for child in filter_box.get_children(): child.queue_free()
		return
	var scalars := _scalar_channels(frame_a, false)
	var names: Array = available.keys()
	names.sort()
	var signature := str(names) + str(frame_a.components if frame_a != null else {})
	# Compare complete category arrays natively; do not assume stable categories
	# from unchanged channel names or use a collision-prone fingerprint.
	var types_now := Normalization.values64(scalars.get("particle_type",PackedFloat64Array()))
	if filter_source_generation != capture_generation or types_now != filter_values or hidden_types != filter_hidden_types:
		filter_source_generation = capture_generation
		filter_values = types_now
		filter_hidden_types = hidden_types.duplicate()
		for child in filter_box.get_children():
			filter_box.remove_child(child)
			child.queue_free()
		var types: Dictionary = {}
		for value in types_now: types[int(value)] = true
		for value in types:
			_check(filter_box, _type_label(value), not hidden_types.has(value), func(v: bool):
				if v: hidden_types.erase(value)
				else: hidden_types[value] = true
				_restyle())
	if signature == channel_signature: return
	channel_signature = signature
	var choices: Array = ["fixed"] + names
	var color_choices := choices.duplicate()
	if frame_a != null and frame_a.components.get("visual_color", 0) in [3, 4]: color_choices.append("visual_color")
	color_channel = _fill_options(color_option, color_choices, color_channel)
	size_channel = _fill_options(size_option, choices, size_channel)
	brightness_channel = _fill_options(brightness_option, choices, brightness_channel)

func _finite_range(values, use_log: bool) -> Vector2:
	return Normalization.finite_range(values,use_log)

func _normalized(value: float, low: float, high: float, use_log: bool, clamp_values := true) -> float:
	return Normalization.normalized(value,low,high,use_log,clamp_values)

func _update_colormap() -> void:
	var entries: Array = colormaps[colormap_name]
	var img := Image.create(entries.size(), 1, false, Image.FORMAT_RGBF)
	for i in range(entries.size()): img.set_pixel(i, 0, Color(entries[i][0], entries[i][1], entries[i][2]))
	map_texture = ImageTexture.create_from_image(img)
	if colorbar != null: colorbar.texture = map_texture
	_sync_visuals()

func _restyle() -> void:
	if scene_layers != null and scene_layers.use_async() and not scene_layers.publishing:
		if logarithmic and (_channel_semantics(color_channel) == "signed" or cyclic or _effective_normalization() == "symmetric"):logarithmic = false
		_sync_control_state();scene_layers.resample();_sync_visuals();return
	if logarithmic and (_channel_semantics(color_channel) == "signed" or cyclic or _effective_normalization() == "symmetric"):
		logarithmic = false
		status_label.text = "Ordinary log is unavailable for signed/symmetric/cyclic mapping. Using linear."
	_sync_control_state()
	_rebuild_style()
	_rebuild_trails()
	_render_current(phase)
	_sync_visuals()

func _rebuild_generic_style() -> void:
	if frame_a == null: return
	particle_count = frame_a.positions.size()
	if current_mm.instance_count != particle_count: current_mm.instance_count = particle_count
	current_sizes.resize(particle_count)
	_style_generic_frame(frame_a, current_mm, 1.0, true)

func _style_generic_frame(fr: FrameData, mm: MultiMesh, fade: float, current: bool) -> void:
	if current: held_positions_ready = false
	var derive_velocity := "velocity_magnitude" in [color_channel,size_channel,brightness_channel]
	var scalars := _scalar_channels(fr, derive_velocity)
	# Typed local arrays avoid Variant/dictionary dispatch for every particle.
	# float64 exactly represents every existing f4 and u4 source value.
	var color_values := Normalization.values64(scalars.get(color_channel,PackedFloat64Array()))
	var sizes := Normalization.values64(scalars.get(size_channel,PackedFloat64Array()))
	var brights := Normalization.values64(scalars.get(brightness_channel,PackedFloat64Array()))
	var opacity := Normalization.values64(scalars.get("opacity",PackedFloat64Array()))
	var types := Normalization.values64(scalars.get("particle_type",PackedFloat64Array()))
	var rgb := Normalization.values64(fr.channels.get("visual_color",PackedFloat64Array()))
	var c: int = fr.components.get("visual_color",0)
	var scalar_color := color_channel not in ["fixed","visual_color"]
	var direct_color := color_channel == "visual_color" and c in [3,4]
	var direct_size := size_channel == "visual_size"
	var direct_bright := brightness_channel == "visual_brightness"
	var count := fr.positions.size()
	var has_size := sizes.size() == count
	var has_bright := brights.size() == count
	var has_opacity := opacity.size() == count
	var has_filter := not hidden_types.is_empty() and types.size() == count
	var positions := fr.positions
	var range_started := Profile.begin()
	var color_range := Normalization.resolve(color_values, _effective_normalization(), logarithmic, manual_min, manual_max)
	var size_range := _finite_range(sizes, false) if has_size and not direct_size else Vector2.ZERO
	var bright_range := _finite_range(brights, false) if has_bright and not direct_bright else Vector2.ZERO
	Profile.end("normalization_ranges",range_started)
	if current:
		range_min = color_range.x; range_max = color_range.y
		_update_particle_legend()
	var color_mapping := Normalization.prepare(color_range,logarithmic,clamp_map,cyclic)
	var size_mapping := Normalization.prepare(size_range,false)
	var bright_mapping := Normalization.prepare(bright_range,false)
	if scalar_color:
		var pack_started := Profile.begin()
		var packed := preload("res://scene/particle_style.gd").scalar_buffer(positions,color_values,sizes,brights,opacity,types,hidden_types,color_mapping,size_mapping,bright_mapping,direct_size,direct_bright,invert_map,fade)
		Profile.end("style_particle_pack",pack_started)
		var upload_started := Profile.begin()
		mm.buffer = packed.buffer
		Profile.end("buffer_submit",upload_started)
		if current:
			current_buffer = packed.buffer
			current_sizes = packed.sizes
		return
	var buffer := PackedFloat32Array()
	buffer.resize(count*16)
	var pack_started := Profile.begin()
	for i in range(count):
		var alpha := fade
		var col := Color.WHITE
		if direct_color:
			col = Color(rgb[i*c], rgb[i*c+1], rgb[i*c+2], rgb[i*c+3] if c == 4 else 1.0)
			if not is_finite(col.r) or not is_finite(col.g) or not is_finite(col.b) or not is_finite(col.a): alpha = 0
			alpha *= clampf(col.a, 0, 1) if is_finite(col.a) else 0
		var bright := 1.0
		if has_bright:
			bright = maxf(0, brights[i]) if direct_bright else bright_mapping.sample(brights[i])
			if not is_finite(brights[i]) or bright < 0: bright = 0
		var size := .35
		if has_size:
			size = maxf(0, sizes[i]) if direct_size else .07 + .48 * size_mapping.sample(sizes[i])
			if not is_finite(sizes[i]) or size < 0: size = 0
		if has_opacity: alpha *= clampf(opacity[i], 0, 1) if is_finite(opacity[i]) else 0
		if has_filter and hidden_types.has(int(types[i])): alpha = 0
		var pos := positions[i]
		if not pos.is_finite(): pos = Vector3.ZERO; alpha = 0
		if not is_finite(col.r) or not is_finite(col.g) or not is_finite(col.b): col = Color.BLACK
		col *= bright
		var offset := i*16
		buffer[offset] = size
		buffer[offset+5] = size
		buffer[offset+10] = size
		buffer[offset+3] = pos.x
		buffer[offset+7] = pos.y
		buffer[offset+11] = pos.z
		buffer[offset+12] = col.r
		buffer[offset+13] = col.g
		buffer[offset+14] = col.b
		buffer[offset+15] = alpha
		if current: current_sizes[i] = size
	Profile.end("style_particle_pack",pack_started)
	var upload_started := Profile.begin()
	mm.buffer = buffer
	Profile.end("buffer_submit",upload_started)
	if current: current_buffer = buffer


func _update_particle_legend() -> void:
	legend.visible = scene_layers != null and show_legend and overlay_visible and color_channel not in ["fixed", "visual_color"]
	colorbar.visible = legend.visible
	colorbar.flip_h = invert_map
	legend.text = "%s • %s\n%.5f → %.5f • %s%s" % [color_channel, colormap_name, range_min, range_max, {"frame":"auto per frame","symmetric":"auto symmetric","manual":"fixed manual","interval":"fixed interval"}[_effective_normalization()], " • cyclic" if cyclic else (" • log" if logarithmic else " • linear")] if color_channel not in ["fixed","visual_color"] else ""
	if color_channel not in ["fixed","visual_color"] and (not is_finite(range_min) or not is_finite(range_max) or range_max < range_min): legend.text = color_channel + " • no valid range"

func _rebuild_generic_trails() -> void:
	var active: Dictionary = frame_a.identity_map.rows.duplicate() if _has_particle_ids() else {}
	for layer in range(TRAIL_LAYERS):
		var mm := trail_mms[layer]
		if not trails_enabled or clean_view or layer >= history.size() or active.is_empty():
			mm.instance_count = 0
			continue
		var fr := history[layer]
		if not fr.has_ids or fr.source_index != frame_a.source_index-layer-1:
			active.clear();mm.instance_count = 0;continue
		for id in active.keys():
			if not fr.identity_map.rows.has(id): active.erase(id)
		mm.instance_count = fr.positions.size()
		_style_generic_frame(fr, mm, .3 / float(layer+1), false)
		var buffer := mm.buffer
		for i in range(fr.ids.size()):
			if not active.has(fr.ids[i]): buffer[i*16+15] = 0
		mm.buffer = buffer

func _has_particle_ids() -> bool:
	return frame_a != null and frame_a.has_ids

func _prepare_identity_pair(b: FrameData) -> void:
	if frame_a == identity_pair_a and b == identity_pair_b: return
	var start := Profile.begin()
	identity_pair_a = frame_a;identity_pair_b = b
	identity_matches.resize(frame_a.ids.size())
	for i in range(frame_a.ids.size()): identity_matches[i] = int(b.identity_map.rows.get(frame_a.ids[i],-1))
	Profile.end("identity_match",start)

func _sync_control_state() -> void:
	var started := Profile.begin()
	_sync_control_state_profiled()
	Profile.end("ui_controls_cpu",started)

func _sync_control_state_profiled() -> void:
	if not _has_particle_ids(): trails_enabled = false
	if control_checks.has("Recorded history  [T]"):
		control_checks["Recorded history  [T]"].disabled = not _has_particle_ids()
		control_checks["Recorded history  [T]"].tooltip_text = "Historical markers require explicitly recorded particle IDs."
	var states := {"Point rendering":clean_view, "Auto orbit  [O]":orbit_enabled, "Recorded history  [T]":trails_enabled, "Automatic range":auto_range, "Logarithmic":logarithmic, "Invert":invert_map, "Clamp out-of-range values":clamp_map, "Show legend":show_legend,"X slice • ±3 simulation units":slice_enabled,"Particle layer visible":particle_layer_visible}
	for key in states:
		if control_checks.has(key): control_checks[key].set_pressed_no_signal(states[key])
	for spin in manual_spins: spin.editable = not auto_range
	_sync_inspection_controls()

# G1 command methods: shared by controls, recipes and deterministic export.
func _reset_inspection_source() -> void:
	if selection_controller != null:selection_controller.reset_source()
	if scene_layers != null:
		scene_layers.close();remove_child(scene_layers);scene_layers.queue_free();scene_layers = null
	inspection_paused = false
	capture_generation += 1
	range_request += 1
	shared_timeline = null
	committed_sample.clear()
	identity_pair_a = null;identity_pair_b = null;identity_matches.clear()
	geometry_override.clear()
	geometry_metadata.clear()
	channel_preferences.clear()
	range_interval.clear()
	normalization_mode = "frame"
	auto_range = true
	cyclic = false
	logarithmic = false
	requested_time = 0

func _ensure_timeline() -> bool:
	if shared_timeline == null or shared_timeline.times.size() != frame_count:
		shared_timeline = SharedTimeline.new()
		return shared_timeline.build(self)
	return shared_timeline.valid_axis

func _seek_time(time: float) -> bool:
	if inspection_busy: return false
	if scene_layers != null:
		if not scene_layers.refresh() or generic_reader.frames.is_empty() or not is_finite(time) or time < generic_reader.frames[0].time or time > generic_reader.frames[-1].time:return false
		playing = false
		return scene_layers.seek(time)
	if not _ensure_timeline():
		status_label.text = shared_timeline.error
		return false
	if shared_timeline.bracket(time).is_empty():
		status_label.text = "Time unavailable: requests must lie within complete recorded timestamps."
		return false
	playing = false
	var point: Dictionary = shared_timeline.sample(time)
	_sync_inspection_controls()
	return not point.is_empty()

func _commit_sample(alpha: float) -> void:
	if frame_a == null: return
	var b: FrameData = frame_b if frame_b != null else frame_a
	var w := clampf(alpha,0,1)
	var requested := lerpf(frame_a.sim_time,b.sim_time,w)
	var exact := w == 0 or b == frame_a or b.sim_time == frame_a.sim_time
	var matching := frame_a.has_ids and b.has_ids
	committed_sample = {"requested_time":requested,"source_indices":[frame_a.source_index,b.source_index],"source_times":[frame_a.sim_time,b.sim_time],"alpha":w,"positions":"exact" if exact else ("interpolated by ID; unmatched held" if matching else "held (no IDs)"),"scalars":"exact" if exact else "held","scalar_time":frame_a.sim_time,"missing_layers":[],"stale_layers":[],"unavailable_channels":frame_a.unavailable_channels.duplicate()}
	current_instance.visible = particle_layer_visible
	for instance in trail_instances: instance.visible = particle_layer_visible
	if guide_visibility.data: _update_data_guide()

func _sample_label() -> String:
	if committed_sample.is_empty(): return ""
	if scene_layers != null and not scene_layers.current.has(scene_layers.particle_id):
		return "%s\nLayer samples held\n%s\nSee layer source times" % ["Recorded time","No particle layer" if scene_layers.particle_id.is_empty() else "Particles unavailable"]
	# Short, explicit lines keep the same height at exact and in-between samples.
	# The detailed scientific policy remains in committed_sample and its sidecars.
	var position_status := "exact"
	if committed_sample.positions != "exact": position_status = "ID interpolation" if _has_particle_ids() else "held"
	var label := "%s\nPositions: %s\n%s\nScalars held at t=%.5f" % ["Recorded time",position_status,"Unmatched IDs held" if _has_particle_ids() else "No IDs; samples held",committed_sample.scalar_time]
	var unavailable: Array = committed_sample.get("unavailable_channels",[])
	if not unavailable.is_empty(): label += "\nUnavailable channels: "+", ".join(unavailable)
	return label

func _channel_semantics(channel: String) -> String:
	if scene_layers == null or generic_reader == null: return "unspecified"
	var descriptors = generic_reader.metadata.get("channel_descriptors",{})
	if not descriptors is Dictionary or not descriptors.get(channel,{}) is Dictionary: return "unspecified"
	return str(descriptors.get(channel,{}).get("semantics","unspecified"))

func _effective_normalization() -> String:
	if cyclic: return "manual"
	if not auto_range: return "interval" if normalization_mode == "interval" else "manual"
	return "symmetric" if normalization_mode == "symmetric" else "frame"

func _set_normalization(value: String) -> void:
	if value == "interval":
		_freeze_interval()
		return
	normalization_mode = value
	auto_range = value in ["frame","symmetric"]
	if value == "symmetric": logarithmic = false; cyclic = false
	_remember_mapping()
	_restyle()

func _remember_mapping() -> void:
	var pref := {}
	for key in ["normalization_mode","auto_range","manual_min","manual_max","logarithmic","cyclic","colormap_name","invert_map","clamp_map","range_interval"]: pref[key] = get(key)
	channel_preferences[color_channel] = pref.duplicate(true)

func _channel_defaults() -> void:
	if channel_preferences.has(color_channel):
		for key in channel_preferences[color_channel]: set(key,channel_preferences[color_channel][key])
	else:
		var semantics := _channel_semantics(color_channel)
		if semantics == "signed":
			normalization_mode = "symmetric"; auto_range = true; logarithmic = false; cyclic = false; colormap_name = "coolwarm"
		elif semantics == "phase":
			var descriptor: Dictionary = generic_reader.metadata.channel_descriptors[color_channel]
			var origin = descriptor.get("origin",-PI)
			var period = descriptor.get("period",TAU)
			if Inspection.numeric(origin) and Inspection.numeric(period) and period > 0:
				normalization_mode = "manual"; auto_range = false; logarithmic = false; cyclic = true; colormap_name = "twilight"
				manual_min = origin; manual_max = origin+period
		else:
			cyclic = false
			normalization_mode = "frame"; auto_range = true
	_remember_mapping()

func _choose_color(channel: String) -> void:
	_remember_mapping()
	color_channel = channel
	_channel_defaults()
	_update_colormap()
	_restyle()

func _freeze_interval() -> void:
	if frame_a == null or scene_layers == null: return
	if not _ensure_timeline(): status_label.text = shared_timeline.error; return
	var start := interval_start.value
	var end := interval_end.value
	if end < start: status_label.text = "Interval end must be at or after its start."; return
	range_request += 1
	var request := range_request
	var generation := capture_generation
	var channel := color_channel
	var use_log := logarithmic
	var low := INF; var high := -INF; var samples := 0
	status_label.text = "Scanning recorded samples for one fixed range…"
	for i in range(frame_count):
		var time: float = shared_timeline.times[i]
		if time < start or time > end: continue
		var fr := _read_frame(i)
		if generation != capture_generation: return
		if fr == null: status_label.text = "Interval frame became unavailable."; return
		var values = _scalar_channels(fr,channel == "velocity_magnitude").get(channel,[])
		var bounds := _finite_range(values,use_log)
		low = minf(low,bounds.x); high = maxf(high,bounds.y)
		samples += 1
		if i % 8 == 0:
			await get_tree().process_frame
			if request != range_request or generation != capture_generation or channel != color_channel or use_log != logarithmic:
				return
	if not is_finite(low) or not is_finite(high): status_label.text = "Interval has no valid recorded channel values."; return
	normalization_mode = "interval"; auto_range = false; cyclic = false
	manual_min = low; manual_max = high
	range_interval = {"start":start,"end":end,"channel":channel,"samples":samples}
	_remember_mapping()
	_restyle()
	status_label.text = "Fixed range from %d recorded samples, t=%.5f…%.5f." % [samples,start,end]

func _type_label(value: int) -> String:
	var labels = generic_reader.metadata.get("type_labels",{}) if scene_layers != null else {}
	if labels is Dictionary and labels.get(str(value)) is String:
		return "%s (Type %d)" % [labels[str(value)].left(160),value]
	return "Type %d" % value

func _inspection_number(parent: Control, title: String, value: float) -> SpinBox:
	var label := Label.new(); label.text = title; parent.add_child(label)
	var spin := SpinBox.new(); spin.allow_lesser = true; spin.allow_greater = true; spin.step = .0001; spin.value = value; parent.add_child(spin)
	return spin

func _sync_inspection_controls() -> void:
	if normalization_option != null: normalization_option.select(Normalization.MODES.find(_effective_normalization()))
	if control_checks.has("Cyclic phase"): control_checks["Cyclic phase"].set_pressed_no_signal(cyclic)
	if control_checks.has("Logarithmic"): control_checks["Logarithmic"].disabled = _channel_semantics(color_channel) == "signed" or cyclic or _effective_normalization() == "symmetric"
	for i in range(manual_spins.size()): manual_spins[i].set_value_no_signal(manual_min if i == 0 else manual_max)
	for i in range(colormap_option.item_count) if colormap_option != null else []:
		if colormap_option.get_item_text(i) == colormap_name: colormap_option.select(i)
	for key in guide_visibility:
		var label: String = {"domain":"Declared simulation domain","data":"Recorded sample data bounds","absorber":"Declared absorber","imposed":"Declared imposed regions"}[key]
		if control_checks.has(label): control_checks[label].set_pressed_no_signal(guide_visibility[key])
	if control_checks.has("Reference grid / axes (display only)"): control_checks["Reference grid / axes (display only)"].set_pressed_no_signal(guide_mesh.visible)

func _build_geometry_ui() -> void:
	var panel := _section("Geometry / Guides")
	geometry_label = Label.new(); geometry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(geometry_label)
	_check(sections["Rendering"],"Particle layer visible",true,func(v: bool): particle_layer_visible = v; _render_current(phase))
	_button(panel,"Load geometry override JSON…",func():
		if geometry_dialog == null:
			geometry_dialog = FileDialog.new(); geometry_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; geometry_dialog.access = FileDialog.ACCESS_FILESYSTEM
			geometry_dialog.filters = PackedStringArray(["*.json ; Explicit geometry override"])
			geometry_dialog.file_selected.connect(_load_geometry_override); add_child(geometry_dialog)
		geometry_dialog.popup_centered_ratio(.65))
	_button(panel,"Clear geometry override",func(): geometry_override.clear(); _apply_geometry())

func _load_geometry_override(path: String) -> void:
	var parsed = _read_small_json(path)
	var invalid := Geometry.validate(parsed)
	if not invalid.is_empty(): status_label.text = invalid; return
	geometry_override = parsed
	_apply_geometry()
	status_label.text = "Applied user geometry override; capture bytes are unchanged."

func _apply_geometry() -> void:
	var data = generic_reader.metadata.get("geometry",{}) if scene_layers != null and generic_reader != null else {}
	var invalid := Geometry.validate(data)
	geometry_metadata = geometry_override.duplicate(true) if not geometry_override.is_empty() else (data.duplicate(true) if invalid.is_empty() else {})
	if geometry_label != null:
		geometry_label.text = Geometry.describe(geometry_metadata,not geometry_override.is_empty())
		if not invalid.is_empty() and geometry_override.is_empty(): geometry_label.text += "\nInvalid metadata: " + invalid
	for key in guide_visibility:
		if not geometry_meshes.has(key):
			var node := MeshInstance3D.new(); add_child(node); geometry_meshes[key] = node
		geometry_meshes[key].visible = guide_visibility[key]
	var g := geometry_metadata
	geometry_meshes.domain.mesh = Geometry.lines(Geometry.box(Geometry.v(g.domain.min),Geometry.v(g.domain.max)),Color(0.35,0.85,1.0,.8)) if g.has("domain") else null
	var rings := PackedVector3Array()
	if g.has("absorber"):
		rings.append_array(Geometry.sphere(Geometry.v(g.absorber.center),g.absorber.start))
		rings.append_array(Geometry.sphere(Geometry.v(g.absorber.center),g.absorber.start+g.absorber.width,true))
	geometry_meshes.absorber.mesh = Geometry.lines(rings,Color(1.0,.65,.2,.8))
	var boxes := PackedVector3Array()
	for region in g.get("imposed_regions",[]): boxes.append_array(Geometry.box(Geometry.v(region.min),Geometry.v(region.max)))
	geometry_meshes.imposed.mesh = Geometry.lines(boxes,Color(.95,.35,.85,.8))
	_update_data_guide()
	_sync_inspection_controls()

func _update_data_guide() -> void:
	var started := Profile.begin()
	_update_data_guide_profiled()
	Profile.end("data_guide_cpu",started)

func _update_data_guide_profiled() -> void:
	if not geometry_meshes.has("data") or not guide_visibility.data: return
	var low := Vector3(INF,INF,INF); var high := Vector3(-INF,-INF,-INF)
	if frame_a != null:
		for p in frame_a.positions:
			if p.is_finite(): low = low.min(p); high = high.max(p)
	geometry_meshes.data.mesh = Geometry.lines(Geometry.box(low,high),Color(.6,1.0,.5,.65)) if low.is_finite() else null
	geometry_label.text = Geometry.describe(geometry_metadata,not geometry_override.is_empty())
	geometry_label.text += "\nData bounds at recorded scalar sample t=%.5f: %s → %s" % [frame_a.sim_time,Geometry.a(low),Geometry.a(high)] if frame_a != null and low.is_finite() else "\nData bounds: unavailable"

func _copy_inspection_state() -> void:
	if frame_a == null: status_label.text = "Open a capture first."; return
	if scene_layers != null: _refresh_frame_count()
	var state := Inspection.snapshot(self)
	if state.is_empty(): status_label.text = "Source changed during inspection; retry when stable."; return
	DisplayServer.clipboard_set(JSON.stringify(state,"\t"))
	status_label.text = "Copied versioned inspection JSON with committed sample and capture identity."

func _show_recipe_dialog(saving: bool) -> void:
	if frame_a == null: status_label.text = "Open the capture first."; return
	if recipe_dialog == null:
		recipe_dialog = FileDialog.new(); recipe_dialog.access = FileDialog.ACCESS_FILESYSTEM
		recipe_dialog.filters = PackedStringArray(["*.json ; SimScope inspection recipe"])
		recipe_dialog.file_selected.connect(func(path: String):
			if recipe_saving: _save_inspection(path)
			else: _load_inspection(path))
		add_child(recipe_dialog)
	recipe_saving = saving
	recipe_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	recipe_dialog.title = "Save inspection recipe" if saving else "Load recipe for the open capture"
	recipe_dialog.popup_centered_ratio(.65)

func _read_small_json(path: String):
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > Inspection.MAX_JSON_BYTES: return null
	return JSON.parse_string(file.get_as_text())

func _save_inspection(path: String) -> Error:
	if selection_controller != null and not selection_controller.state.definitions.is_empty():
		selection_controller.temporal.durable.save_to(path.get_basename()+".inspection")
		status_label.text = selection_controller.temporal.durable.status.text
		return OK
	if scene_layers != null: _refresh_frame_count()
	if frame_a == null: return ERR_UNAVAILABLE
	var state := Inspection.snapshot(self)
	if state.is_empty(): status_label.text = "Source changed during inspection; retry when stable."; return ERR_BUSY
	var result: Error = preload("res://video/render_job.gd").write_json(path,state)
	status_label.text = "Saved inspection " + path if result == OK else "Could not save inspection."
	return result

func _load_inspection(path: String) -> String:
	var recipe = _read_small_json(path)
	if not recipe is Dictionary: status_label.text = "Invalid or oversized inspection JSON."; return status_label.text
	if recipe.get("version") == 3 and selection_controller != null:
		selection_controller.temporal.durable.load_from(path)
		status_label.text = selection_controller.temporal.durable.status.text
		return status_label.text
	var invalid := Inspection.restore(self,recipe)
	status_label.text = "Restored inspection; playback paused." if invalid.is_empty() else invalid
	return invalid

func _capture_inspection_png(path: String, with_state: bool) -> Error:
	if with_state and selection_controller != null and not selection_controller.state.definitions.is_empty():return await selection_controller.temporal.durable.capture_to(path)
	if inspection_busy: return ERR_BUSY
	if with_state and frame_a == null: return ERR_UNAVAILABLE
	if scene_layers != null:
		_refresh_frame_count()
		if frame_a == null: return ERR_UNAVAILABLE
	inspection_busy = true
	if scene_layers != null and not await scene_layers.wait_for_surface():
		status_label.text = scene_layers.iso_error;inspection_busy = false;return ERR_CANT_CREATE
	if selection_controller != null and not selection_controller.state.definitions.is_empty() and not await selection_controller.await_committed_overlay():inspection_busy = false;return ERR_BUSY
	# Synchronous readers publish before rendering. Lock the realtime clock/input;
	# verify the visual/sample fingerprint again after draw in case a UI callback
	# applied newer state while awaiting the renderer. No stale image gets a label.
	var stable := false
	for attempt in range(8):
		if selection_controller != null and not selection_controller.state.definitions.is_empty() and not await selection_controller.await_committed_overlay():inspection_busy = false;return ERR_BUSY
		_update_hud()
		var before := _inspection_frame_fingerprint()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if before == _inspection_frame_fingerprint(): stable = true; break
	if not stable: inspection_busy = false; return ERR_BUSY
	var image := get_viewport().get_texture().get_image()
	var state := Inspection.snapshot(self) if with_state else {}
	if with_state and state.is_empty(): inspection_busy = false; return ERR_BUSY
	var result := image.save_png(path)
	if result == OK and with_state:
		state.image = {"file":path.get_file(),"width":image.get_width(),"height":image.get_height(),"sha256":FileAccess.get_sha256(path)}
		result = preload("res://video/render_job.gd").write_json(path.get_basename()+".json",state)
	inspection_busy = false
	return result

func _inspection_frame_fingerprint() -> String:
	return JSON.stringify([VisualState.snapshot(self),committed_sample,selection_controller.state.snapshot() if selection_controller != null and not selection_controller.state.definitions.is_empty() else {}],"",true,true)

func _set_timeline_extent() -> void:
	var was_guarded := _timeline_guard
	_timeline_guard = true
	timeline.max_value = maxi(0,frame_count-1)
	_timeline_guard = was_guarded

# Reader publication happens on this thread; worker results never touch scene nodes.
func _sync_generic_source() -> bool:
	return scene_layers.refresh() if scene_layers != null else false

func _exit_tree() -> void:
	if scene_layers != null:scene_layers.close()
	if generic_reader != null: generic_reader.close()
