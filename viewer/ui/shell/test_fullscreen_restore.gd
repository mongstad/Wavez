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
	if expected == Window.MODE_FULLSCREEN:
		check(viewer.legend.is_visible_in_tree(),label+" retains enabled particle legend")
		check(root.get_visible_rect().encloses(viewer.shell.particle_legend_panel.get_global_rect()),label+" particle legend stays inside viewport")
		check(root.get_visible_rect().encloses(viewer.shell.layer_legends.get_global_rect()),label+" layer legends stay inside viewport")
	var after := Visual.snapshot(viewer)
	# Responsive panel width is presentation geometry and changes with the window.
	after.erase("panel_width")
	check(after == before and viewer.committed_sample == sample, label + " scientific state and clock")
	check(viewer.shell.immersive == (expected == Window.MODE_FULLSCREEN), label + " fullscreen presentation matches native state")
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
	viewer.color_channel = "value"; viewer.show_legend = true; viewer._update_particle_legend()
	for id in viewer.scene_layers.states:
		if viewer.scene_layers.panel_controls.has(id) and viewer.scene_layers.panel_controls[id].has("legend"):
			viewer.scene_layers.panel_controls[id].legend.button_pressed = true
	await create_timer(.5).timeout
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1100,700)
	await create_timer(.7).timeout
	before = Visual.snapshot(viewer); sample = viewer.committed_sample.duplicate(true)
	before.erase("panel_width")
	await checkpoint("manual",Window.MODE_WINDOWED)
	key(KEY_F11)
	await checkpoint("manual-fullscreen",Window.MODE_FULLSCREEN)
	key(KEY_ESCAPE)
	await checkpoint("manual-restored",Window.MODE_WINDOWED,"manual")
	root.mode = Window.MODE_MAXIMIZED
	await checkpoint("maximized",Window.MODE_MAXIMIZED)
	for i in 2:
		key(KEY_F11)
		await checkpoint("max-fullscreen-"+str(i),Window.MODE_FULLSCREEN)
		if i == 0: key(KEY_F11)
		else: key(KEY_ESCAPE)
		await checkpoint("max-restored-"+str(i),Window.MODE_MAXIMIZED,"maximized")
	root.mode = Window.MODE_WINDOWED; await create_timer(.7).timeout
	root.size = Vector2i(1200,760)
	await checkpoint("resized",Window.MODE_WINDOWED)
	var entry: Dictionary = viewer.shell.commands.fullscreen
	entry.popup.id_pressed.emit(entry.index)
	await checkpoint("resized-fullscreen",Window.MODE_FULLSCREEN)
	key(KEY_ESCAPE)
	await checkpoint("resized-restored",Window.MODE_WINDOWED,"resized")
	root.mode = Window.MODE_MAXIMIZED
	await checkpoint("maximized-again",Window.MODE_MAXIMIZED,"maximized")
	viewer.shell.edge_reveal.set_process(false)
	for revealed in [false,true]:
		for side in viewer.shell.edge_reveal.states: viewer.shell.edge_reveal.set_pinned(side,false)
		if not revealed: viewer.shell.edge_reveal.tick(.36,Vector2(200,200),false,false)
		var pins: Dictionary = viewer.shell.edge_reveal.states.duplicate(true)
		# Panel visibility is presentation state; snapshot science separately above.
		before.overlay_visible = viewer.overlay_visible
		key(KEY_F11)
		await checkpoint("unpinned-fullscreen-"+str(revealed),Window.MODE_FULLSCREEN)
		key(KEY_ESCAPE)
		check(viewer.shell.edge_reveal.states == pins,"Exact unpinned state restored "+str(revealed))
		await checkpoint("unpinned-restored-"+str(revealed),Window.MODE_MAXIMIZED,"maximized")
	print("RESTORE: ",checks," checks; ",failures.size()," failures")
	viewer.free(); await process_frame; quit(0 if failures.is_empty() else 1)
