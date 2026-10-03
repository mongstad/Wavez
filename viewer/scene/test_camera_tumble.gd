extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Sampler = preload("res://scene/timeline_sampler.gd")
var output := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func close_transform(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < .0001 and a.basis.x.distance_to(b.basis.x) < .00001 and a.basis.y.distance_to(b.basis.y) < .00001 and a.basis.z.distance_to(b.basis.z) < .00001
func drag(viewer, delta: Vector2) -> void:
	viewer.dragging = true
	viewer.last_mouse = Vector2.ZERO
	var event := InputEventMouseMotion.new(); event.position = delta
	viewer._unhandled_input(event)
	viewer.dragging = false
func press(viewer, code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	viewer._unhandled_input(event)
func wheel(viewer, button: MouseButton) -> void:
	var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = true
	viewer._unhandled_input(event)

func manual_orbit(viewer, movement: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(480, 320)
	viewer._unhandled_input(press)
	check(viewer.manual_orbit_dragging, "Right press in viewport begins manual orbit")
	var motion := InputEventMouseMotion.new(); motion.position = press.position + movement
	viewer._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT; release.position = Vector2(0, 0)
	viewer._input(release)
	check(not viewer.manual_orbit_dragging, "Right release over chrome ends manual orbit")

func manual_orbit_tests(viewer, kind: String) -> void:
	viewer.orbit_enabled = false
	viewer.dragging = false
	viewer.camera_target = Vector3(2, -1, 3)
	viewer.camera_distance = 40
	viewer.half_extent = 12
	viewer.yaw = .4; viewer.pitch = .2; viewer._update_camera()
	var target: Vector3 = viewer.camera_target
	var radius: float = viewer.camera_distance
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var initial_yaw: float = viewer.yaw
	var initial_pitch: float = viewer.pitch
	var sensitivity: float = viewer._manual_orbit_sensitivity()
	manual_orbit(viewer, Vector2(80, -60))
	check(is_equal_approx(viewer.yaw, initial_yaw - 80*sensitivity) and viewer.pitch == initial_pitch, kind + " right drag changes yaw only despite vertical motion")
	check(viewer.camera_target == target and viewer.camera_distance == radius and absf(viewer.camera.position.distance_to(target)-radius) < .0001, kind + " orbit preserves center and radius")
	check(is_equal_approx(viewer.camera.position.y, target.y + radius * sin(initial_pitch)) and viewer.camera.basis.z.dot((viewer.camera.position-target).normalized()) > .99999, kind + " right orbit holds elevation and looks at center")
	check(viewer.committed_sample == sample, kind + " orbit leaves committed scientific sample untouched")
	var before_vertical: Transform3D = viewer.camera.transform
	var yaw_before_vertical: float = viewer.yaw
	manual_orbit(viewer, Vector2(0, 150))
	check(viewer.yaw == yaw_before_vertical and viewer.pitch == initial_pitch and viewer.camera.transform == before_vertical, kind + " vertical-only right drag leaves the camera unchanged")
	var circle_pixels: float = TAU / sensitivity
	for direction in [-1.0, 1.0]:
		var start: Transform3D = viewer.camera.transform
		var starting_yaw: float = viewer.yaw
		var start_horizontal := Vector2(start.origin.x-target.x, start.origin.z-target.z).normalized()
		var circle_press := InputEventMouseButton.new()
		circle_press.button_index = MOUSE_BUTTON_RIGHT; circle_press.pressed = true; circle_press.position = Vector2(480, 320)
		viewer._unhandled_input(circle_press)
		for step in range(1, 73):
			var circle_motion := InputEventMouseMotion.new()
			circle_motion.position = circle_press.position + Vector2(direction * circle_pixels * step / 72.0, 120.0 * step / 72.0)
			viewer._input(circle_motion)
			check(viewer.pitch == initial_pitch and viewer.camera_target == target and viewer.camera_distance == radius and absf(viewer.camera.position.distance_to(target)-radius) < .0001 and absf(viewer.camera.position.y-start.origin.y) < .0001 and viewer.camera.basis.z.dot((viewer.camera.position-target).normalized()) > .99999, kind + " full-circle orbit keeps elevation, center, radius and aim at step " + str(step) + " direction " + str(direction))
			if step == 36:
				var opposite_horizontal := Vector2(viewer.camera.position.x-target.x, viewer.camera.position.z-target.z).normalized()
				check(start_horizontal.dot(opposite_horizontal) < -.999, kind + " half-circle reaches opposite side in direction " + str(direction))
		circle_press.pressed = false; viewer._input(circle_press)
		check(is_equal_approx(viewer.yaw, starting_yaw - direction * TAU) and close_transform(start, viewer.camera.transform), kind + " full horizontal revolution returns to starting view without tilt in direction " + str(direction))
	check(viewer.committed_sample == sample, kind + " full-circle orbit leaves committed scientific sample untouched")
	var stopped: Transform3D = viewer.camera.transform
	var stray := InputEventMouseMotion.new(); stray.position = Vector2(700, 500); viewer._input(stray)
	check(viewer.camera.transform == stopped, kind + " released right drag does not move camera")
	viewer.camera_distance = 3; var close_sensitivity: float = viewer._manual_orbit_sensitivity()
	viewer.camera_distance = 400; var far_sensitivity: float = viewer._manual_orbit_sensitivity()
	check(close_sensitivity < sensitivity and sensitivity < far_sensitivity and close_sensitivity > 0, kind + " smooth distance response gives close precision and distant reach")
	viewer.camera_distance = radius; viewer._update_camera()
	wheel(viewer, MOUSE_BUTTON_WHEEL_UP)
	check(viewer.camera_target == target and viewer.camera_distance < radius, kind + " wheel zoom composes with manual orbit")
	var after_zoom: float = viewer.camera_distance
	manual_orbit(viewer, Vector2(-35, 25))
	check(viewer.camera_distance == after_zoom and viewer.camera_target == target, kind + " orbit after zoom preserves zoom state")
	viewer.orbit_enabled = true; viewer.orbit_speed = .2
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(480, 320)
	viewer._unhandled_input(press)
	var held_yaw: float = viewer.yaw
	viewer.scene_layers.tick(.1)
	check(viewer.yaw == held_yaw, kind + " right drag temporarily suspends Auto Orbit")
	press.pressed = false; viewer._input(press)
	viewer.scene_layers.tick(.1)
	check(is_equal_approx(viewer.yaw, held_yaw + .02), kind + " Auto Orbit resumes after release")
	viewer.orbit_enabled = false
	viewer._focus_activity()
	check(viewer.camera_target.is_finite() and viewer.camera_distance > 0, kind + " Frame Scene works after manual orbit")

func math_tests(viewer) -> void:
	viewer.camera_target = Vector3(3, -2, 7); viewer.camera_distance = 32
	# Independent legacy reference: look_at is well-defined inside the old range.
	var reference := Camera3D.new(); root.add_child(reference)
	for yaw_degrees in [-175, 0, 38, 170]:
		for pitch_degrees in [-82, -24, 0, 24, 82]:
			viewer.yaw = deg_to_rad(yaw_degrees); viewer.pitch = deg_to_rad(pitch_degrees); viewer._update_camera()
			reference.position = viewer.camera_target + Vector3(sin(viewer.yaw)*cos(viewer.pitch), sin(viewer.pitch), cos(viewer.yaw)*cos(viewer.pitch))*32
			reference.look_at(viewer.camera_target, Vector3.UP)
			check(close_transform(viewer.camera.transform, reference.transform), "Legacy orientation preserved %s/%s" % [yaw_degrees,pitch_degrees])
	reference.queue_free()
	# Exercise real drag handling for three complete revolutions per axis/direction.
	for axis in [Vector2.RIGHT, Vector2.DOWN]:
		for direction in [-1, 1]:
			viewer.yaw = .4; viewer.pitch = 0; viewer._update_camera()
			var start: Transform3D = viewer.camera.transform
			for step in 1080:
				var before: Transform3D = viewer.camera.transform
				drag(viewer, axis * direction * deg_to_rad(1.0) / .006)
				var after: Transform3D = viewer.camera.transform
				check(after.is_finite() and absf(after.basis.determinant()-1) < .00001, "Finite orthonormal tumble")
				check(before.basis.x.dot(after.basis.x) > .999 and before.basis.y.dot(after.basis.y) > .999 and before.basis.z.dot(after.basis.z) > .999, "No jump through former limits/poles")
				check(absf(after.origin.distance_to(viewer.camera_target)-32) < .0001 and after.basis.z.dot((after.origin-viewer.camera_target).normalized()) > .99999, "Orbit radius and target preserved")
			check(close_transform(start,viewer.camera.transform), "Three revolutions return to start")
	# Diagonal drags through exact poles must not depend on world-up reconstruction.
	for degrees in [-450, -270, -90, 90, 270, 450]:
		viewer.pitch = deg_to_rad(degrees); viewer._update_camera()
		var before: Transform3D = viewer.camera.transform
		drag(viewer, Vector2(1,1))
		check(before.basis.y.dot(viewer.camera.basis.y) > .999, "Continuous diagonal drag at pole " + str(degrees))

func fixture_tests(viewer, kind: String) -> void:
	viewer._open_capture(output.path_join(kind + ".ssc")); viewer.playing = false; viewer.orbit_enabled = false
	check(viewer.frame_count == 2, kind + " fixture opened")
	viewer._seek_time(.5)
	manual_orbit_tests(viewer, kind)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var target: Vector3 = viewer.camera_target
	viewer.yaw = .6; viewer.pitch = deg_to_rad(120); viewer._update_camera()
	var distance: float = viewer.camera_distance
	wheel(viewer, MOUSE_BUTTON_WHEEL_UP)
	check(is_equal_approx(viewer.camera_distance,minf(distance,maxf(maxf(viewer.camera.near*2,viewer.half_extent+viewer.camera.near),distance*.9))) and viewer.camera_target == target, kind + " wheel zoom retains center")
	var before_pan: Transform3D = viewer.camera.transform
	viewer.free_camera = true
	var focused := root.gui_get_focus_owner()
	if focused != null: focused.release_focus()
	var key := InputEventKey.new(); key.physical_keycode = KEY_D; key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	viewer._move_free_camera(.1)
	key = key.duplicate(); key.pressed = false; Input.parse_input_event(key); Input.flush_buffered_events()
	viewer.free_camera = false
	var shift: Vector3 = before_pan.basis.x * .1 * maxf(1,viewer.camera_distance*.5)
	check(viewer.camera_target.distance_to(target + shift) < .0001 and viewer.camera.position.distance_to(before_pan.origin + shift) < .0001, kind + " pan follows inverted camera right without changing orbit radius")
	var orientation: Basis = viewer.camera.basis
	press(viewer,KEY_F)
	check(viewer.camera.basis.is_equal_approx(orientation) and viewer.camera_target.is_finite() and viewer.camera_distance > 0, kind + " Frame scene preserves orientation")
	var centered: Vector3 = viewer.camera_target
	drag(viewer,Vector2(50,50))
	check(viewer.camera_target == centered, kind + " drag preserves framed center")
	# Existing serialized fields must restore an upside-down view and continue smoothly.
	viewer.pitch = deg_to_rad(270); viewer._update_camera()
	var saved: Transform3D = viewer.camera.transform
	var path := output.path_join(kind + "-recipe.json")
	check(viewer._save_inspection(path) == OK, kind + " save pole camera recipe")
	press(viewer,KEY_R)
	check(viewer.camera_target == Vector3.ZERO and is_equal_approx(viewer.yaw,deg_to_rad(38)) and is_equal_approx(viewer.pitch,deg_to_rad(24)), kind + " reset restores defaults")
	check(viewer._load_inspection(path).is_empty(), kind + " restore portable camera preset")
	check(close_transform(saved,viewer.camera.transform), kind + " recipe camera round trip")
	viewer._update_camera()
	check(close_transform(saved,viewer.camera.transform), kind + " restored camera has no first-update snap")
	var visual := Visual.snapshot(viewer)
	check(close_transform(Sampler.camera_at(visual,2,false,.2),saved), kind + " locked video camera preserves orientation")
	viewer.inspection_paused = false; viewer.orbit_enabled = true; viewer.orbit_speed = .2
	var old_pitch: float = viewer.pitch
	viewer.scene_layers.tick(.1)
	check(close_transform(Sampler.camera_at(visual,.1,true,.2),viewer.camera.transform) and viewer.pitch == old_pitch, kind + " live auto orbit matches deterministic world-Y video orbit")
	var yaw: float = viewer.yaw
	viewer.dragging = true; viewer.scene_layers.tick(.1); viewer.dragging = false
	check(viewer.yaw == yaw, kind + " drag suspends auto orbit")
	viewer.orbit_enabled = false
	check(viewer.committed_sample == sample, kind + " camera operations preserve committed scientific sample")
	if DisplayServer.get_name() != "headless":
		viewer._apply_preset("Scientific"); viewer.overlay_panel.hide()
		for degrees in [80, 90, 100, 180]:
			viewer.pitch = deg_to_rad(degrees); viewer._update_camera()
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join(kind + "-pitch" + str(degrees) + ".png")) == OK, "Rendered " + kind + " at " + str(degrees))

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-output="): output = arg.trim_prefix("--camera-output=")
	if output.is_empty(): quit(1); return
	create_timer(120).timeout.connect(func():push_error("Camera test timed out");quit(1))
	var viewer = Viewer.new(); viewer.offline_instance = true; root.add_child(viewer); viewer.set_process(false)
	math_tests(viewer)
	for kind in ["particles", "volume", "mesh", "mixed"]: await fixture_tests(viewer,kind)
	var file := FileAccess.open(output.path_join("camera-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"\t")); file.close()
	viewer.queue_free(); await process_frame
	print("CAMERA: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
