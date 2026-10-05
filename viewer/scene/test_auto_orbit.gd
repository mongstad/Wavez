extends SceneTree
## Focused navigation-mode and orbit-center transitions on four WVZ1 scene types.
const Viewer = preload("res://main.gd")
var output := ""
var real_capture := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func close_pose(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < .0001 and a.basis.is_equal_approx(b.basis)
func camera_state(viewer) -> Dictionary:
	return {
		"transform": viewer.camera.transform, "target": viewer.camera_target,
		"distance": viewer.camera_distance, "yaw": viewer.yaw, "pitch": viewer.pitch,
		"orbit_enabled": viewer.orbit_enabled, "free_camera": viewer.free_camera,
		"orbit_speed": viewer.orbit_speed, "orbit_basis": viewer.camera_orbit_basis,
		"orbit_basis_active": viewer.camera_orbit_basis_active,
		"orbit_basis_yaw": viewer.camera_orbit_basis_yaw,
		"orbit_basis_pitch": viewer.camera_orbit_basis_pitch,
	}
func check_orbit(viewer, target: Vector3, label: String) -> void:
	var radial: Vector3 = viewer.camera.global_position - target
	check(viewer.camera_target == target and absf(radial.length() - viewer.camera_distance) < .0001 and viewer.camera.global_basis.z.dot(radial.normalized()) > .99999, label)
func world_poses(viewer) -> Dictionary:
	var result := {
		viewer: viewer.global_transform,
		viewer.scene_layers: viewer.scene_layers.global_transform,
		viewer.current_instance: viewer.current_instance.global_transform,
	}
	for view in viewer.scene_layers.views.values(): result[view] = view.global_transform
	for node in viewer.trail_instances: result[node] = node.global_transform
	return result
func check_world(poses: Dictionary, label: String) -> void:
	for node in poses:
		check(is_instance_valid(node) and node.global_transform == poses[node], label + ": " + node.name)
func move_key(viewer, keycode: Key, delta: float) -> void:
	var event := InputEventKey.new(); event.physical_keycode = keycode; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	viewer.scene_layers.tick(delta)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
func local_move(keycode: Key) -> Vector3:
	match keycode:
		KEY_W: return Vector3.FORWARD
		KEY_S: return Vector3.BACK
		KEY_A: return Vector3.LEFT
		KEY_D: return Vector3.RIGHT
		KEY_Q: return Vector3.DOWN
		KEY_E: return Vector3.UP
	return Vector3.ZERO
func drag_left(viewer) -> void:
	viewer.dragging = true; viewer.last_mouse = Vector2.ZERO
	var motion := InputEventMouseMotion.new(); motion.position = Vector2(45, -30)
	viewer._unhandled_input(motion); viewer.dragging = false
func drag_right(viewer) -> void:
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(480, 320)
	viewer._unhandled_input(press)
	var motion := InputEventMouseMotion.new(); motion.position = press.position + Vector2(60, 0)
	viewer._input(motion)
	press.pressed = false; viewer._input(press)
func wheel_in(viewer) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_WHEEL_UP; event.factor = 1; event.pressed = true
	viewer._zoom_camera(event, true)
func fields(editor, target: Vector3, radius: float) -> void:
	for axis in 3: editor.coordinates[axis].text = str(target[axis])
	editor.radius_input.text = str(radius)
	check(editor.read_fields(), "Editor accepts proposed center/radius")

func movement_transition(viewer, kind: String, keycode: Key) -> void:
	viewer._reset_camera(); viewer.orbit_enabled = true
	viewer.free_camera = keycode != KEY_Q # The movement key also recovers a disabled Free Camera toggle.
	var before: Transform3D = viewer.camera.transform
	var target: Vector3 = viewer.camera_target
	var radius: float = viewer.camera_distance
	var yaw: float = viewer.yaw
	var shift: Vector3 = before.basis * local_move(keycode) * .1 * maxf(1, radius * .5) * viewer.free_camera_speed_scale
	move_key(viewer, keycode, .1)
	var label := kind + " / " + OS.get_keycode_string(keycode)
	check(not viewer.orbit_enabled and viewer.free_camera, label + " exits Auto Orbit on first movement press")
	check(viewer.camera_target.distance_to(target + shift) < .0001 and viewer.camera.position.distance_to(before.origin + shift) < .0001, label + " applies that same camera-relative movement")
	check(viewer.camera_distance == radius and viewer.yaw == yaw, label + " uses ordinary Free Camera translation without an orbit step")
	check_orbit(viewer, viewer.camera_target, label + " keeps the existing camera representation")
	var stopped: Transform3D = viewer.camera.transform
	viewer.scene_layers.tick(.1)
	check(close_pose(stopped, viewer.camera.transform), label + " remains in Free Camera mode after release")
	viewer._toggle_auto_orbit()
	check(close_pose(stopped, viewer.camera.transform), label + " re-enables orbit without a snap")
	viewer.scene_layers.tick(.1)
	check(viewer.camera.position.distance_to(stopped.origin) > .001, label + " resumes orbit from the translated pose")
	viewer.orbit_enabled = false

func through_scene_center(viewer, kind: String, started_in_orbit: bool) -> void:
	viewer._reset_camera(); viewer.orbit_enabled = started_in_orbit; viewer.free_camera = true
	var center: Vector3 = viewer.camera_target
	var before: Transform3D = viewer.camera.transform
	move_key(viewer, KEY_W, 4.0)
	var direction: Vector3 = before.basis.z
	var label := kind + " / center crossing from Auto Orbit " + str(started_in_orbit)
	check((before.origin - center).dot(direction) > 0.0 and (viewer.camera.position - center).dot(direction) < 0.0, label + " passes through the original scene center")
	check(viewer.camera.basis.is_equal_approx(before.basis) and not viewer.orbit_enabled, label + " keeps orientation and free movement")
	var crossed: Transform3D = viewer.camera.transform
	drag_left(viewer); drag_right(viewer)
	check(not close_pose(crossed, viewer.camera.transform) and not viewer.orbit_enabled, label + " retains LMB/RMB navigation beyond the center")

func mouse_and_wheel(viewer, kind: String) -> void:
	viewer._reset_camera(); viewer.orbit_enabled = true; viewer.free_camera = true
	var target: Vector3 = viewer.camera_target
	var before: Transform3D = viewer.camera.transform
	drag_left(viewer)
	check(viewer.orbit_enabled and not close_pose(before, viewer.camera.transform), kind + " LMB remains available in Auto Orbit")
	check_orbit(viewer, target, kind + " LMB keeps the accepted target/radius")
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(480, 320)
	viewer._unhandled_input(press)
	before = viewer.camera.transform; viewer.scene_layers.tick(.1)
	check(close_pose(before, viewer.camera.transform) and viewer.orbit_enabled, kind + " held RMB suspends automatic motion")
	press.pressed = false; viewer._input(press)
	before = viewer.camera.transform; drag_right(viewer)
	check(viewer.orbit_enabled and not close_pose(before, viewer.camera.transform), kind + " RMB remains available in Auto Orbit")
	check_orbit(viewer, target, kind + " RMB keeps the accepted world target")
	var radius: float = viewer.camera_distance
	wheel_in(viewer)
	check(viewer.orbit_enabled and viewer.camera_distance < radius, kind + " wheel zoom retains Auto Orbit")
	check_orbit(viewer, target, kind + " wheel zoom keeps the target")
	viewer.scene_layers.tick(.1)
	check_orbit(viewer, target, kind + " automatic motion resumes after mouse navigation")
	viewer.orbit_enabled = false

func editor_transitions(viewer, kind: String) -> void:
	for started_in_orbit in [true, false]:
		viewer._reset_camera(); viewer.orbit_enabled = started_in_orbit
		viewer.free_camera = started_in_orbit
		var prior: Dictionary = camera_state(viewer)
		viewer.shell.edit_orbit_center()
		var editor = viewer.shell.orbit_editor
		check(editor.visible and editor.guide.visible and not viewer.orbit_enabled and viewer.free_camera, kind + " editor suspends orbit and enables Free Camera from " + str(started_in_orbit))
		check(close_pose(viewer.camera.transform, prior.transform), kind + " editor entry does not move the camera")
		viewer._toggle_auto_orbit(); viewer._toggle_free_camera()
		check(not viewer.orbit_enabled and viewer.free_camera, kind + " editor retains its temporary navigation mode")
		var position: Vector3 = viewer.camera.position
		move_key(viewer, KEY_W, .1)
		check(viewer.camera.position.distance_to(position) > .001 and not viewer.orbit_enabled, kind + " W navigates while placing center")
		drag_left(viewer); drag_right(viewer); wheel_in(viewer)
		fields(editor, Vector3(15, -7, 3), 18)
		editor.dismiss()
		check(not editor.visible and not editor.guide.visible and camera_state(viewer) == prior, kind + " Cancel restores complete pre-edit state from " + str(started_in_orbit))
		viewer.shell.edit_orbit_center()
		check(not viewer.orbit_enabled and viewer.free_camera, kind + " editor reopens in placement mode")
		move_key(viewer, KEY_E, .1)
		var chosen := Vector3(21, -9, 6)
		fields(editor, chosen, 27)
		editor.commit()
		check(not editor.visible and not editor.guide.visible and viewer.orbit_enabled and viewer.free_camera, kind + " Apply starts Auto Orbit from " + str(started_in_orbit))
		check_orbit(viewer, chosen, kind + " Apply uses the new world target and radius")
		var before: Transform3D = viewer.camera.transform
		viewer.scene_layers.tick(.1)
		check(viewer.camera.position.distance_to(before.origin) > .001 and viewer.camera_target == chosen, kind + " Apply orbits immediately around the new center")
		viewer.orbit_enabled = false

func transitions(viewer, kind: String) -> void:
	viewer._open_capture(output.path_join(kind + ".wvz")); viewer.playing = false
	check(viewer.frame_count == 2 and viewer._shell_open_error.is_empty(), kind + " fixture opened")
	viewer._seek_time(.5); viewer._reset_camera()
	viewer.orbit_speed = .4; viewer.free_camera = true; viewer.orbit_enabled = false
	var poses := world_poses(viewer)
	var target: Vector3 = viewer.camera_target
	var before: Transform3D = viewer.camera.transform
	move_key(viewer, KEY_W, .1)
	check(viewer.free_camera and not viewer.orbit_enabled and viewer.camera_target != target and viewer.camera.position != before.origin, kind + " Free Camera movement is active by default")
	viewer._reset_camera(); viewer._toggle_auto_orbit()
	before = viewer.camera.transform; target = viewer.camera_target
	viewer.scene_layers.tick(.2)
	check(viewer.orbit_enabled and viewer.camera.position.distance_to(before.origin) > .01, kind + " Auto Orbit moves the camera when no movement key is held")
	check_orbit(viewer, target, kind + " Auto Orbit keeps the world target")
	for keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]: movement_transition(viewer, kind, keycode)
	through_scene_center(viewer, kind, false)
	through_scene_center(viewer, kind, true)
	mouse_and_wheel(viewer, kind)
	editor_transitions(viewer, kind)
	check_world(poses, kind + " scientific/world transform unchanged")

func real_scene_smoke(viewer) -> void:
	viewer._open_capture(real_capture); viewer.playing = false; viewer._reset_camera()
	check(viewer._shell_open_error.is_empty() and viewer.frame_count > 0, "real scene opened")
	var world: Transform3D = viewer.global_transform
	viewer.orbit_enabled = true; viewer.free_camera = true
	var before: Transform3D = viewer.camera.transform
	viewer.scene_layers.tick(.2)
	check(viewer.camera.position.distance_to(before.origin) > .01, "real scene Auto Orbit moves the camera")
	before = viewer.camera.transform
	move_key(viewer, KEY_W, .1)
	check(not viewer.orbit_enabled and viewer.camera.position.distance_to(before.origin) > .001, "real scene W exits orbit and moves on the first press")
	check(viewer.global_transform == world, "real scene root transform unchanged")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-output="): output = arg.trim_prefix("--camera-output=")
		if arg.begins_with("--camera-capture="): real_capture = arg.trim_prefix("--camera-capture=")
	if output.is_empty(): quit(1); return
	create_timer(120).timeout.connect(func(): push_error("Auto Orbit test timed out"); quit(1))
	var viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	for kind in ["particles", "volume", "mesh", "mixed"]: transitions(viewer, kind)
	if not real_capture.is_empty(): real_scene_smoke(viewer)
	if DisplayServer.get_name() != "headless":
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
	var file := FileAccess.open(output.path_join("camera-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method()}, "\t")); file.close()
	viewer.queue_free(); await process_frame
	print("AUTO ORBIT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
