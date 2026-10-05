extends SceneTree
## Focused Auto Orbit/navigation transitions on particle, field, mesh and mixed WVZ1 scenes.
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
func check_orbit(viewer, target: Vector3, label: String) -> void:
	var radial: Vector3 = viewer.camera.global_position - target
	check(viewer.camera_target == target and absf(radial.length() - viewer.camera_distance) < .0001 and viewer.camera.global_basis.z.dot(radial.normalized()) > .99999, label)
func world_poses(viewer) -> Dictionary:
	# Field/mesh render nodes may be rebuilt while preparation finishes; the
	# stable scientific roots and particle instances must never follow the camera.
	var result := {viewer: viewer.global_transform, viewer.current_instance: viewer.current_instance.global_transform}
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
func drag_left(viewer) -> void:
	viewer._orbit_camera_by_drag(Vector2(45, -30), .006)
func drag_right(viewer) -> void:
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(480, 320)
	viewer._unhandled_input(press)
	var motion := InputEventMouseMotion.new(); motion.position = press.position + Vector2(60, 0)
	viewer._input(motion)
	press.pressed = false; viewer._input(press)
func wheel_in(viewer) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_WHEEL_UP; event.factor = 1; event.pressed = true
	viewer._zoom_camera(event, true)

func transitions(viewer, kind: String) -> void:
	viewer._open_capture(output.path_join(kind + ".wvz")); viewer.playing = false
	check(viewer.frame_count == 2, kind + " scene opened")
	viewer._seek_time(.5)
	viewer._reset_camera()
	viewer.orbit_speed = .4
	viewer.free_camera = true
	viewer.orbit_enabled = false
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var poses := world_poses(viewer)
	var target: Vector3 = viewer.camera_target

	# LMB -> Auto Orbit -> off. The camera moves around the target and holds its final pose.
	drag_left(viewer)
	var before: Transform3D = viewer.camera.transform
	viewer._toggle_auto_orbit()
	check(close_pose(before, viewer.camera.transform), kind + " enabling orbit preserves the current LMB pose")
	viewer.scene_layers.tick(.2)
	check(viewer.camera.position.distance_to(before.origin) > .01, kind + " Auto Orbit moves the camera in world space")
	check_orbit(viewer, target, kind + " Auto Orbit uses the world target and radius after LMB")
	viewer._toggle_auto_orbit()
	before = viewer.camera.transform; viewer.scene_layers.tick(.2)
	check(close_pose(before, viewer.camera.transform), kind + " disabling orbit holds the resulting pose")

	# RMB -> Auto Orbit -> RMB, including a held right drag that suspends orbit.
	drag_right(viewer); before = viewer.camera.transform
	viewer._toggle_auto_orbit()
	check(close_pose(before, viewer.camera.transform), kind + " enabling orbit preserves the RMB pose")
	viewer.scene_layers.tick(.1)
	var right_press := InputEventMouseButton.new(); right_press.button_index = MOUSE_BUTTON_RIGHT; right_press.pressed = true; right_press.position = Vector2(480, 320)
	viewer._unhandled_input(right_press)
	before = viewer.camera.transform; viewer.scene_layers.tick(.1)
	check(close_pose(before, viewer.camera.transform), kind + " held RMB suspends orbit")
	right_press.pressed = false; viewer._input(right_press)
	drag_right(viewer)
	check_orbit(viewer, target, kind + " RMB after Auto Orbit keeps the world target")

	# Wheel changes radius; Free Camera forward/back changes that same radius.
	var radius: float = viewer.camera_distance
	wheel_in(viewer)
	check(viewer.camera_distance < radius, kind + " wheel zoom decreases the orbit radius")
	check_orbit(viewer, target, kind + " wheel zoom keeps the world target")
	radius = viewer.camera_distance
	var previous_yaw: float = viewer.yaw
	move_key(viewer, KEY_W, .1)
	check(viewer.camera_distance < radius, kind + " forward movement decreases the orbit radius")
	check(is_equal_approx(viewer.yaw, previous_yaw + .1 * viewer.orbit_speed), kind + " Auto Orbit keeps rotating during forward movement")
	check_orbit(viewer, target, kind + " forward movement keeps the world target")
	radius = viewer.camera_distance
	previous_yaw = viewer.yaw
	move_key(viewer, KEY_S, .1)
	check(viewer.camera_distance > radius, kind + " backward movement increases the orbit radius")
	check(is_equal_approx(viewer.yaw, previous_yaw + .1 * viewer.orbit_speed), kind + " Auto Orbit keeps rotating during backward movement")
	check_orbit(viewer, target, kind + " backward movement keeps the world target")
	radius = viewer.camera_distance
	var pan: Vector3 = viewer.camera.global_basis.x * .1 * maxf(1, radius * .5)
	move_key(viewer, KEY_D, .1)
	check(viewer.camera_target.distance_to(target + pan) < .0001 and is_equal_approx(viewer.camera_distance, radius), kind + " side translation retains its accepted pan behavior")
	target = viewer.camera_target
	viewer.camera_distance = viewer.camera.near * 2.1; viewer._update_camera()
	move_key(viewer, KEY_W, .5)
	check(viewer.camera_distance >= viewer.camera.near * 2.0, kind + " forward movement cannot cross the orbit target")
	check_orbit(viewer, target, kind + " near-target movement remains a valid orbit")

	# Edit Orbit Center's accepted state, Reset and Frame each remain authoritative.
	target += Vector3(3, -2, 5); viewer.camera_target = target; viewer.camera_distance = 35; viewer._update_camera()
	viewer.scene_layers.tick(.1)
	check_orbit(viewer, target, kind + " edited orbit center remains fixed")
	viewer._reset_camera(); target = viewer.camera_target
	viewer.scene_layers.tick(.1)
	check_orbit(viewer, target, kind + " Reset Camera composes with Auto Orbit")
	viewer._focus_activity(); target = viewer.camera_target
	viewer.scene_layers.tick(.1)
	check_orbit(viewer, target, kind + " Frame Scene composes with Auto Orbit")
	for i in 3:
		before = viewer.camera.transform
		viewer._toggle_auto_orbit(); check(close_pose(before, viewer.camera.transform), kind + " toggle off has no snap " + str(i))
		viewer._toggle_auto_orbit(); check(close_pose(before, viewer.camera.transform), kind + " toggle on has no snap " + str(i))
		viewer.scene_layers.tick(.1)
		check_orbit(viewer, target, kind + " repeated orbit uses the current pose " + str(i))
	viewer.orbit_enabled = false
	check_world(poses, kind + " world/scientific transform unchanged")
	check(viewer.committed_sample == sample, kind + " navigation leaves the scientific sample unchanged")

func real_scene_smoke(viewer) -> void:
	viewer._open_capture(real_capture); viewer.playing = false
	check(viewer._shell_open_error.is_empty() and viewer.frame_count > 0, "real scene opened")
	viewer._reset_camera()
	var target: Vector3 = viewer.camera_target
	var world: Transform3D = viewer.global_transform
	viewer.orbit_enabled = true
	var before: Transform3D = viewer.camera.transform
	viewer.scene_layers.tick(.2)
	check(viewer.camera.position.distance_to(before.origin) > .01, "real scene Auto Orbit moves the camera")
	move_key(viewer, KEY_W, .1)
	check_orbit(viewer, target, "real scene forward movement keeps the target")
	move_key(viewer, KEY_S, .1)
	check_orbit(viewer, target, "real scene backward movement keeps the target")
	check(viewer.global_transform == world, "real scene root transform unchanged")
	viewer.orbit_enabled = false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-output="): output = arg.trim_prefix("--camera-output=")
		if arg.begins_with("--camera-capture="): real_capture = arg.trim_prefix("--camera-capture=")
	if output.is_empty(): quit(1); return
	create_timer(120).timeout.connect(func(): push_error("Auto Orbit test timed out"); quit(1))
	var viewer = Viewer.new(); viewer.offline_instance = true; root.add_child(viewer); viewer.set_process(false)
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
