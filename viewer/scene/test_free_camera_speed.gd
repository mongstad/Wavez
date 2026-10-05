extends SceneTree
## Focused speed, key-layout and camera invariants for issues #200 and #256.
const Viewer = preload("res://main.gd")
const Bindings = preload("res://ui/keyboard_shortcuts.gd")
var output := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func near(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= maxf(.000001, absf(expected) * .00001)
func key(code: Key, unicode_value := 0, shift := false, physical: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = physical
	event.unicode = unicode_value; event.shift_pressed = shift; event.pressed = true
	return event
func press_speed(viewer, event: InputEventKey) -> void:
	var focused := root.gui_get_focus_owner()
	if focused != null: focused.release_focus()
	viewer._unhandled_input(event)
func release_speed(viewer, pressed: InputEventKey) -> void:
	var event: InputEventKey = pressed.duplicate()
	event.pressed = false; event.unicode = 0
	viewer._input(event)
func move(viewer, code: Key, delta: float) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	viewer._move_free_camera(delta)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
func world_poses(viewer) -> Dictionary:
	var result := {viewer: viewer.global_transform, viewer.scene_layers: viewer.scene_layers.global_transform, viewer.current_instance: viewer.current_instance.global_transform}
	for view in viewer.scene_layers.views.values(): result[view] = view.global_transform
	for node in viewer.trail_instances: result[node] = node.global_transform
	return result
func check_world(poses: Dictionary, label: String) -> void:
	for node in poses: check(is_instance_valid(node) and node.global_transform == poses[node], label + ": " + node.name)

func shortcut_and_repeat(viewer) -> void:
	var shortcuts = viewer.shell.shortcuts
	check(near(viewer.free_camera_speed_scale, .7), "Default movement scale is 70% of accepted main")
	check(shortcuts.active.increase_camera_speed == KEY_PLUS and shortcuts.active.decrease_camera_speed == KEY_MINUS, "Default bindings are logical + and -")
	var nordic_plus := key(KEY_PLUS, KEY_PLUS, false, KEY_PLUS)
	var us_plus := key(KEY_EQUAL, KEY_PLUS, true, KEY_EQUAL)
	var minus := key(KEY_MINUS, KEY_MINUS, false, KEY_MINUS)
	check(Bindings.binding(nordic_plus) == KEY_PLUS and shortcuts.match_action(nordic_plus) == "increase_camera_speed", "Dedicated Nordic + resolves by character")
	check(Bindings.binding(us_plus) == KEY_PLUS and shortcuts.match_action(us_plus) == "increase_camera_speed", "Shift+= producing + resolves on US layouts")
	check(Bindings.binding(minus) == KEY_MINUS and shortcuts.match_action(minus) == "decrease_camera_speed", "Logical - resolves without a physical US position")
	press_speed(viewer, us_plus)
	check(near(viewer.free_camera_speed_scale, .7 * 1.10) and viewer.camera_speed_hold_action == "increase_camera_speed", "First + press applies exactly 10% immediately")
	var first: int = viewer.camera_speed_next_repeat_msec
	viewer._update_camera_speed_repeat(first - 1)
	check(near(viewer.free_camera_speed_scale, .7 * 1.10), "Hold does not adjust before 200 ms")
	var echo: InputEventKey = us_plus.duplicate(); echo.echo = true
	viewer._unhandled_input(echo)
	check(near(viewer.free_camera_speed_scale, .7 * 1.10), "OS echo does not bypass the controlled cadence")
	viewer._update_camera_speed_repeat(first)
	check(near(viewer.free_camera_speed_scale, .7 * pow(1.10, 2)) and viewer.camera_speed_next_repeat_msec == first + 200, "Held + applies one 10% step at 200 ms")
	viewer._update_camera_speed_repeat(first + 199)
	check(near(viewer.free_camera_speed_scale, .7 * pow(1.10, 2)), "No extra step between repeat boundaries")
	viewer._update_camera_speed_repeat(first + 400)
	check(near(viewer.free_camera_speed_scale, .7 * pow(1.10, 3)) and viewer.camera_speed_next_repeat_msec == first + 600, "Delayed frame applies one controlled step without catch-up burst")
	var before: float = viewer.free_camera_speed_scale
	release_speed(viewer, us_plus)
	viewer._update_camera_speed_repeat(first + 1000)
	check(viewer.camera_speed_hold_action.is_empty() and near(viewer.free_camera_speed_scale, before), "Key release stops repeats immediately")
	press_speed(viewer, minus)
	check(near(viewer.free_camera_speed_scale, before * .90), "First - press decreases current speed by exactly 10%")
	var minus_next: int = viewer.camera_speed_next_repeat_msec
	viewer._update_camera_speed_repeat(minus_next)
	check(near(viewer.free_camera_speed_scale, before * pow(.90, 2)), "Held - repeats at 200 ms")
	release_speed(viewer, minus)
	press_speed(viewer, nordic_plus)
	check(near(viewer.free_camera_speed_scale, before * pow(.90, 2) * 1.10), "Dedicated + applies the same step")
	release_speed(viewer, nordic_plus)
	var old: Dictionary = shortcuts.active.duplicate()
	var rebound: Dictionary = old.duplicate()
	Bindings.assign(rebound, "increase_camera_speed", KEY_F6)
	Bindings.assign(rebound, "decrease_camera_speed", KEY_F7)
	shortcuts.active = rebound
	var speed_before: float = viewer.free_camera_speed_scale
	press_speed(viewer, nordic_plus); release_speed(viewer, nordic_plus)
	check(near(viewer.free_camera_speed_scale, speed_before), "Default + stops acting after rebound")
	var plus_rebound := key(KEY_F6)
	press_speed(viewer, plus_rebound)
	check(near(viewer.free_camera_speed_scale, speed_before * 1.10), "Rebound increase acts immediately")
	viewer._update_camera_speed_repeat(viewer.camera_speed_next_repeat_msec)
	check(near(viewer.free_camera_speed_scale, speed_before * pow(1.10, 2)), "Rebound increase holds at the same controlled cadence")
	release_speed(viewer, plus_rebound)
	var minus_rebound := key(KEY_F7)
	press_speed(viewer, minus_rebound)
	check(near(viewer.free_camera_speed_scale, speed_before * pow(1.10, 2) * .90), "Rebound decrease acts immediately")
	viewer._update_camera_speed_repeat(viewer.camera_speed_next_repeat_msec)
	check(near(viewer.free_camera_speed_scale, speed_before * pow(1.10, 2) * pow(.90, 2)), "Rebound decrease holds at the same controlled cadence")
	release_speed(viewer, minus_rebound)
	shortcuts.active = old
	viewer.free_camera_speed_scale = .7
	for step in 200: viewer._adjust_camera_speed("increase_camera_speed")
	check(near(viewer.free_camera_speed_scale, viewer.MAX_FREE_CAMERA_SPEED) and is_finite(viewer.free_camera_speed_scale), "Repeated + stops at finite upper bound")
	for step in 300: viewer._adjust_camera_speed("decrease_camera_speed")
	check(near(viewer.free_camera_speed_scale, viewer.MIN_FREE_CAMERA_SPEED) and viewer.free_camera_speed_scale > 0, "Repeated - stops at positive lower bound")
	viewer.free_camera_speed_scale = viewer.MAX_FREE_CAMERA_SPEED - .01
	viewer._adjust_camera_speed("increase_camera_speed")
	check(near(viewer.free_camera_speed_scale, 2.5), "Near-ceiling + clamps without overshoot")
	viewer._adjust_camera_speed("increase_camera_speed")
	check(near(viewer.free_camera_speed_scale, 2.5), "Further + stays at the ceiling")
	viewer.free_camera_speed_scale = viewer.MIN_FREE_CAMERA_SPEED + .001
	viewer._adjust_camera_speed("decrease_camera_speed")
	check(near(viewer.free_camera_speed_scale, .02), "Near-floor - clamps without undershoot")
	viewer._adjust_camera_speed("decrease_camera_speed")
	check(near(viewer.free_camera_speed_scale, .02), "Further - stays at the floor")
	viewer.free_camera_speed_scale = .7
	press_speed(viewer, us_plus)
	var shifted_speed: float = viewer.free_camera_speed_scale
	var shift_release := key(KEY_SHIFT); shift_release.pressed = false
	viewer._input(shift_release)
	viewer._update_camera_speed_repeat(Time.get_ticks_msec() + 1000)
	check(viewer.camera_speed_hold_action.is_empty() and near(viewer.free_camera_speed_scale, shifted_speed), "Releasing Shift stops a held US plus key")
	viewer.free_camera_speed_scale = .7
	var focused_line := LineEdit.new(); root.add_child(focused_line); focused_line.show(); focused_line.grab_focus()
	viewer._unhandled_input(us_plus)
	check(near(viewer.free_camera_speed_scale, .7) and viewer.camera_speed_hold_action.is_empty(), "Text focus protects speed shortcut")
	focused_line.release_focus(); focused_line.free()
	press_speed(viewer, us_plus)
	viewer._clear_camera_speed_hold()
	check(viewer.camera_speed_hold_action.is_empty(), "Focus-loss cancellation stops a held speed key")
	viewer.free_camera_speed_scale = .7

func fixture_navigation(viewer, kind: String) -> void:
	viewer._open_capture(output.path_join(kind + ".wvz")); viewer.playing = false
	check(viewer._shell_open_error.is_empty() and viewer.frame_count == 2, kind + " scene opens")
	viewer._reset_camera(); viewer.orbit_enabled = false; viewer.free_camera = true
	viewer.free_camera_speed_scale = .7
	var playback_before: bool = viewer.playing
	var poses := world_poses(viewer)
	var initial: Transform3D = viewer.camera.transform
	var center: Vector3 = viewer.camera_target
	var radius: float = viewer.camera_distance
	var old_rate := .1 * maxf(1, radius * .5)
	move(viewer, KEY_W, .1)
	var first_shift: Vector3 = initial.basis * Vector3.FORWARD * old_rate * .7
	check(viewer.camera_target.distance_to(center + first_shift) < .0001 and viewer.camera.position.distance_to(initial.origin + first_shift) < .0001, kind + " free movement is exactly 30% slower than accepted main")
	check(viewer.camera.basis.is_equal_approx(initial.basis) and near(viewer.camera_distance, radius), kind + " speed changes translation only")
	var before: Vector3 = viewer.camera.position
	press_speed(viewer, key(KEY_PLUS, KEY_PLUS)); release_speed(viewer, key(KEY_PLUS, KEY_PLUS))
	move(viewer, KEY_W, .1)
	check(near(viewer.camera.position.distance_to(before), old_rate * .7 * 1.10), kind + " + affects the next movement immediately")
	before = viewer.camera.position
	press_speed(viewer, key(KEY_MINUS, KEY_MINUS)); release_speed(viewer, key(KEY_MINUS, KEY_MINUS))
	move(viewer, KEY_W, .1)
	check(near(viewer.camera.position.distance_to(before), old_rate * .7 * 1.10 * .90), kind + " - affects the next movement immediately")
	viewer.orbit_enabled = true
	before = viewer.camera.position
	press_speed(viewer, key(KEY_PLUS, KEY_PLUS)); release_speed(viewer, key(KEY_PLUS, KEY_PLUS))
	check(viewer.orbit_enabled and viewer.camera.position == before, kind + " speed adjustment does not alter Auto Orbit state or pose")
	move(viewer, KEY_W, .1)
	check(not viewer.orbit_enabled and viewer.camera.position != before, kind + " first W still exits Auto Orbit and uses current speed")
	check(viewer.playing == playback_before, kind + " speed and navigation preserve playback state")
	check_world(poses, kind + " scientific/world transform remains fixed")

func fullscreen_navigation(viewer) -> void:
	if DisplayServer.get_name() == "headless": return
	viewer._reset_camera(); viewer.orbit_enabled = false; viewer.free_camera = true
	viewer.free_camera_speed_scale = .7
	var plus := key(KEY_PLUS, KEY_PLUS)
	press_speed(viewer, plus); release_speed(viewer, plus)
	check(near(viewer.free_camera_speed_scale, .77), "Normal window accepts speed shortcut")
	viewer._toggle_fullscreen()
	check(viewer.shell.immersive, "Fullscreen inspection mode opens")
	press_speed(viewer, plus); release_speed(viewer, plus)
	check(near(viewer.free_camera_speed_scale, .77 * 1.10), "Fullscreen inspection mode accepts speed shortcut")
	viewer._toggle_fullscreen()
	check(not viewer.shell.immersive, "Normal window restores after fullscreen check")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-output="): output = arg.trim_prefix("--camera-output=")
	if output.is_empty(): quit(1); return
	create_timer(120).timeout.connect(func(): push_error("Free Camera speed test timed out"); quit(1))
	var viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	shortcut_and_repeat(viewer)
	for kind in ["particles", "volume", "mesh", "mixed"]: fixture_navigation(viewer, kind)
	fullscreen_navigation(viewer)
	if DisplayServer.get_name() != "headless":
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
	var file := FileAccess.open(output.path_join("camera-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method()}, "\t")); file.close()
	viewer.queue_free(); await process_frame
	print("FREE CAMERA SPEED: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
