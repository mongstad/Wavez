extends "res://ui/shell/test_immersive_desktop.gd"
## Dedicated native-window regression. KWin acknowledges each tested state.
var shell
var edges: Dictionary

func key(code: Key) -> void:
	var focus := root.gui_get_focus_owner(); if focus != null: focus.release_focus()
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; root.push_input(event)

func checkpoint(label: String, expected: int, restore := "", action := "") -> void:
	await create_timer(.7).timeout
	check(root.mode == expected or (expected == Window.MODE_MINIMIZED and DisplayServer.get_name() == "Wayland"), label + " native mode (KWin verifies Wayland minimize)")
	check(root.borderless and not root.unresizable, label + " borderless/resizable flags")
	check(shell.immersive == (expected == Window.MODE_FULLSCREEN or label == "minimized-fullscreen"), label + " fullscreen presentation")
	var current := Visual.snapshot(viewer); current.erase("panel_width"); current.erase("overlay_visible")
	check(current == before and viewer.committed_sample == sample, label + " preserves scientific state and clock")
	var drag: Vector2 = shell.title_drag.get_global_rect().get_center()
	var state_change: Dictionary = {}
	for id in before:
		if current.get(id) != before[id]: state_change[id] = {"before":before[id], "after":current.get(id)}
	FileAccess.open(output.path_join("stage.json"), FileAccess.WRITE).store_string(JSON.stringify({"stage":label, "mode":root.mode, "expected_mode":expected, "restore":restore, "action":action, "checks":checks, "failures":failures, "drag_local":[drag.x, drag.y], "scientific_change":state_change, "clock_unchanged":viewer.committed_sample == sample}))
	for i in 1200:
		if FileAccess.file_exists(output.path_join(label + ".ack")): return
		await create_timer(.05).timeout
	check(false, "Native chrome acknowledgement timed out"); quit(1)

func run() -> void:
	output = OS.get_cmdline_user_args()[0]; capture = OS.get_cmdline_user_args()[1]
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(capture); viewer.playing = false; viewer.orbit_enabled = false; shell = viewer.shell
	shell.edge_reveal.set_process(false)
	await create_timer(1).timeout
	before = Visual.snapshot(viewer); before.erase("panel_width"); before.erase("overlay_visible")
	sample = viewer.committed_sample.duplicate(true)
	root.mode = Window.MODE_WINDOWED; root.size = Vector2i(1100,700)
	await checkpoint("restored", Window.MODE_WINDOWED)
	await checkpoint("resize-request", Window.MODE_WINDOWED, "", "resize")
	await checkpoint("resized", Window.MODE_WINDOWED)
	check(root.size == Vector2i(1200,760), "Restored window can resize through native compositor")
	shell.window_chrome.maximize_button.pressed.emit()
	await checkpoint("maximized", Window.MODE_MAXIMIZED)
	check(shell.window_chrome.maximize_button.tooltip_text == "Restore window", "Maximized control exposes Restore")
	shell.window_chrome.actions.get_child(0).pressed.emit()
	await checkpoint("minimized-max", Window.MODE_MINIMIZED, "", "unminimize")
	await checkpoint("unminimized-max", Window.MODE_MAXIMIZED, "maximized")
	key(KEY_F11)
	await checkpoint("max-fullscreen", Window.MODE_FULLSCREEN)
	shell.window_chrome.actions.get_child(0).pressed.emit()
	await checkpoint("minimized-fullscreen", Window.MODE_MINIMIZED, "", "unminimize")
	await checkpoint("unminimized-fullscreen", Window.MODE_FULLSCREEN, "max-fullscreen")
	key(KEY_ESCAPE)
	await checkpoint("max-restored", Window.MODE_MAXIMIZED, "maximized")
	shell.window_chrome.maximize_button.pressed.emit()
	await checkpoint("restore-button", Window.MODE_WINDOWED, "resized")
	check(shell.window_chrome.maximize_button.tooltip_text == "Maximize", "Restored control exposes Maximize")
	# Double-click the application-owned title area, then restore it again.
	var double := InputEventMouseButton.new(); double.button_index = MOUSE_BUTTON_LEFT; double.pressed = true; double.double_click = true
	shell.window_chrome.title_input(double)
	await checkpoint("title-max", Window.MODE_MAXIMIZED)
	shell.window_chrome.title_input(double)
	await checkpoint("title-restore", Window.MODE_WINDOWED, "resized")
	shell.window_chrome.actions.get_child(0).pressed.emit()
	await checkpoint("minimized-window", Window.MODE_MINIMIZED, "", "unminimize")
	await checkpoint("unminimized-window", Window.MODE_WINDOWED, "resized")
	for side in shell.edge_reveal.states: shell.edge_reveal.set_pinned(side, false)
	shell.edge_reveal.tick(.36, Vector2(200,200), false, false)
	edges = shell.edge_reveal.states.duplicate(true)
	key(KEY_F11)
	await checkpoint("unpinned-fullscreen", Window.MODE_FULLSCREEN)
	shell.edge_reveal.set_pinned("top", true); shell.edge_reveal.set_pinned("right", true)
	key(KEY_ESCAPE)
	await checkpoint("unpinned-restored", Window.MODE_WINDOWED, "resized")
	check(shell.edge_reveal.states == edges, "Fullscreen discards temporary pins and restores exact edge timers/visibility")
	await checkpoint("close-request", Window.MODE_WINDOWED)
	print("CHROME: ", checks, " checks, ", failures.size(), " failures")
	# Exercise the actual production Close handler; harness verifies process exit.
	shell.window_chrome.actions.get_child(2).pressed.emit()
