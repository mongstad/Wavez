extends "res://ui/shell/test_immersive_desktop.gd"
## Native mode/geometry regression using the existing PID-scoped desktop harness.

func key(code: Key, shift := false) -> void:
	var focused := root.gui_get_focus_owner()
	if focused != null: focused.release_focus()
	var event := InputEventKey.new()
	event.keycode = code; event.shift_pressed = shift; event.pressed = true
	root.push_input(event)

func checkpoint(label: String, expected: int, restore := "") -> void:
	await create_timer(.7).timeout
	check(root.mode == expected, label + " native mode")
	var after := Visual.snapshot(viewer)
	# Responsive panel width is presentation geometry and changes with the window.
	after.erase("panel_width")
	check(after == before and viewer.committed_sample == sample, label + " scientific state and clock")
	check(not viewer.shell.immersive, label + " interactive shell recovered")
	var report := {"stage":label,"mode":root.mode,"expected_mode":expected,"restore":restore,
		"window_size":str(root.size),"checks":checks,"failures":failures}
	FileAccess.open(output.path_join("stage.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	for i in 1200:
		if FileAccess.file_exists(output.path_join(label+".ack")): return
		await create_timer(.05).timeout
	check(false,"Desktop acknowledgement timed out"); quit(1)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-output="): output = arg.trim_prefix("--review-output=")
		if arg.begins_with("--review-capture="): capture = arg.trim_prefix("--review-capture=")
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(capture); viewer.playing = false; viewer.orbit_enabled = false
	await create_timer(1).timeout
	check(viewer.frame_a != null,"Fixture opens")
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1100,700)
	await create_timer(.7).timeout
	before = Visual.snapshot(viewer); sample = viewer.committed_sample.duplicate(true)
	before.erase("panel_width")
	await checkpoint("manual",Window.MODE_WINDOWED)
	key(KEY_F11)
	await checkpoint("manual-fullscreen",Window.MODE_FULLSCREEN)
	viewer.shell.fullscreen_button.pressed.emit()
	await checkpoint("manual-restored",Window.MODE_WINDOWED,"manual")
	root.mode = Window.MODE_MAXIMIZED
	await checkpoint("maximized",Window.MODE_MAXIMIZED)
	for i in 2:
		key(KEY_F11)
		await checkpoint("max-fullscreen-"+str(i),Window.MODE_FULLSCREEN)
		if i == 0: key(KEY_F11)
		else: viewer.shell.fullscreen_button.pressed.emit()
		await checkpoint("max-restored-"+str(i),Window.MODE_MAXIMIZED,"maximized")
	# Entering immersive from interactive fullscreen must not overwrite its return mode.
	viewer.shell.menus.View.get_popup().id_pressed.emit(1)
	await checkpoint("nested-fullscreen",Window.MODE_FULLSCREEN)
	key(KEY_F11,true); await create_timer(.7).timeout
	check(viewer.shell.immersive,"Shift F11 enters immersive")
	key(KEY_ESCAPE)
	await checkpoint("nested-interactive",Window.MODE_FULLSCREEN)
	viewer.shell.fullscreen_button.pressed.emit()
	await checkpoint("nested-max-restored",Window.MODE_MAXIMIZED,"maximized")
	# Restore and resize after maximization, then exercise a fresh manual round trip.
	root.mode = Window.MODE_WINDOWED; await create_timer(.7).timeout
	root.size = Vector2i(1200,760)
	await checkpoint("resized",Window.MODE_WINDOWED)
	viewer.shell.menus.View.get_popup().id_pressed.emit(1)
	await checkpoint("resized-fullscreen",Window.MODE_FULLSCREEN)
	key(KEY_F11)
	await checkpoint("resized-restored",Window.MODE_WINDOWED,"resized")
	# Direct immersive round trip retains its existing maximized return behavior.
	root.mode = Window.MODE_MAXIMIZED
	await checkpoint("maximized-again",Window.MODE_MAXIMIZED,"maximized")
	key(KEY_F11,true); await create_timer(.7).timeout
	check(viewer.shell.immersive,"Direct maximized immersive entry")
	key(KEY_ESCAPE)
	await checkpoint("immersive-max-restored",Window.MODE_MAXIMIZED,"maximized")
	print("RESTORE: ",checks," checks; ",failures.size()," failures")
	viewer.free(); await process_frame; quit(0 if failures.is_empty() else 1)
