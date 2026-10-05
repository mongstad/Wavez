extends Node
## Reset and Frame Scene on deliberately off-origin and differently scaled WVZ1 layers.
const Viewer = preload("res://main.gd")
const GridView = preload("res://layers/grid_view.gd")
const MeshView = preload("res://layers/mesh_view.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
@onready var root: Window = get_tree().root

func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func points(view) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if view.frame_a != null:
		for p in view.frame_a.positions: result.append(p)
	for id in view.scene_layers.views:
		var layer = view.scene_layers.views[id]
		if layer is MeshView:
			for p in layer.source_positions: result.append(layer.transform * p)
		elif layer is GridView and not layer.data.is_empty():
			var transform: Transform3D = layer.world_to_grid.affine_inverse()
			for x in [layer.bounds_min.x, layer.bounds_max.x]:
				for y in [layer.bounds_min.y, layer.bounds_max.y]:
					for z in [layer.bounds_min.z, layer.bounds_max.z]: result.append(transform * Vector3(x, y, z))
	return result
func visible(view, positions: Array[Vector3]) -> bool:
	if positions.is_empty(): return false
	var aspect: float = float(root.size.x) / maxf(1.0, float(root.size.y))
	var vertical_tangent := tan(deg_to_rad(view.camera.fov) * .5)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	var inverse: Transform3D = view.camera.global_transform.affine_inverse()
	for point in positions:
		var local: Vector3 = inverse * point
		var depth: float = -local.z
		if not local.is_finite() or depth <= view.camera.near or depth >= view.camera.far: return false
		var projected := Vector2(local.x / (depth * vertical_tangent * aspect), local.y / (depth * vertical_tangent))
		if not projected.is_finite() or absf(projected.x) > .95 or absf(projected.y) > .95: return false
		low = low.min(projected); high = high.max(projected)
	return maxf(high.x - low.x, high.y - low.y) > .06
func wheel(view) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP; event.pressed = true; event.factor = 1.0
	view._zoom_camera(event, true)
func move_free_camera(view) -> bool:
	var focused := root.gui_get_focus_owner()
	if focused != null: focused.release_focus()
	var before: Vector3 = view.camera_target
	var key := InputEventKey.new(); key.physical_keycode = KEY_D; key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	view._move_free_camera(.1)
	key = key.duplicate(); key.pressed = false
	Input.parse_input_event(key); Input.flush_buffered_events()
	return view.camera_target != before
func verify(view, name: String, path := "") -> void:
	view._open_capture(output.path_join(name + ".wvz") if path.is_empty() else path)
	check(view._shell_open_error.is_empty(), name + " opens")
	if not view._shell_open_error.is_empty(): return
	var positions := points(view)
	var source_sample: Dictionary = view.committed_sample.duplicate(true)
	var initial_target: Vector3 = view.camera_target
	check(visible(view, positions), name + " opens in a useful view")
	view._reset_camera()
	check(visible(view, positions), name + " Reset Camera keeps content in view")
	check(view.camera_target.distance_to(initial_target) < .0001 * maxf(1.0, initial_target.length()), name + " reset uses scene center")
	var first: Transform3D = view.camera.transform
	view._reset_camera()
	check(view.camera.transform.is_equal_approx(first), name + " repeated reset is stable")
	view.camera_distance = .00001; view.yaw = 2.5; view.pitch = -1.3; view._update_camera()
	view._reset_camera()
	check(visible(view, positions), name + " recovers after close zoom and LMB tumble")
	view.camera_distance = view.camera.far * 20.0; view._update_camera()
	view._reset_camera()
	check(visible(view, positions), name + " recovers after distant zoom")
	view.manual_orbit_axis = view.camera.basis.y.normalized()
	view.manual_orbit_start_basis = view.camera.basis
	view.manual_orbit_angle = 0.0
	view._orbit_camera_horizontally(80.0, .006)
	check(view.camera_orbit_basis_active, name + " view-relative orbit basis is active")
	view.orbit_enabled = true; view.free_camera = true
	check(move_free_camera(view), name + " Free Camera key translates camera before reset")
	view._reset_camera()
	check(visible(view, positions) and not view.camera_orbit_basis_active, name + " recovers after view-relative orbit and Free Camera translation")
	check(view.orbit_enabled and view.free_camera, name + " reset preserves navigation modes")
	check(view.camera.transform.is_finite() and view.camera_target.is_finite() and is_finite(view.camera_distance) and view.camera_distance > 0, name + " reset camera is finite")
	var radius: float = view.camera_distance
	wheel(view)
	check(view.camera_distance < radius and view.camera_target == initial_target, name + " wheel zoom works after reset")
	view.yaw = 1.8; view.pitch = -.4; view._update_camera()
	var orientation: Basis = view.camera.basis
	view.camera_target += Vector3(10, 10, 10) * maxf(1.0, view.half_extent)
	view._focus_activity()
	check(view.camera.basis.is_equal_approx(orientation) and visible(view, positions), name + " Frame Scene preserves orientation and reframes")
	check(view.committed_sample == source_sample and points(view) == positions, name + " camera actions preserve scientific samples and geometry")
	view.orbit_enabled = false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reset-output="): output = arg.trim_prefix("--reset-output=")
	var external := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reset-capture="): external = arg.trim_prefix("--reset-capture=")
	if output.is_empty(): get_tree().quit(1); return
	get_tree().create_timer(90).timeout.connect(func(): push_error("Reset validation timeout"); get_tree().quit(1))
	var view = Viewer.new(); view.offline_instance = true; root.add_child(view); view.set_process(false)
	for name in ["particles", "field", "mesh", "mixed", "small", "large"]: verify(view, name)
	if not external.is_empty(): verify(view, "external mesh", external)
	if DisplayServer.get_name() != "headless":
		var positions := points(view)
		for mode in [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN]:
			root.mode = mode
			for i in 4: await get_tree().process_frame
			view._reset_camera()
			check(visible(view, positions), "Reset Camera frames scene in window mode " + str(mode))
			RenderingServer.force_draw(false)
			check(root.get_texture().get_image().save_png(output.path_join("reset-window-" + str(mode) + ".png")) == OK, "Reset screenshot saved in window mode " + str(mode))
		root.mode = Window.MODE_WINDOWED
	FileAccess.open(output.path_join("reset-report.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "packaged": not OS.has_feature("editor")}, "\t"))
	view.queue_free(); await get_tree().process_frame
	print("CAMERA RESET: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
