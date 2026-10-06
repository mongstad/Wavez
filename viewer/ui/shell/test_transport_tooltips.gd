extends SceneTree
## Native input/hover checks limited to the two transport clocks (#275).
const Viewer = preload("res://main.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
func ready():
	var deadline := Time.get_ticks_msec() + 10000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	viewer.shell.transport.refresh()
	check(not viewer.scene_layers.is_buffering(), "Preparation completed")
func click(control: Control, double := false):
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true; event.double_click = double; event.position = control.get_global_rect().get_center()
	root.push_input(event)
	var release := event.duplicate(); release.pressed = false; release.double_click = false; root.push_input(release)
func key(code: Key, window = root):
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; event.window_id = window.get_window_id()
	Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func tooltip_labels(node: Node) -> Array:
	var labels: Array = []
	if node is Label and node.theme_type_variation == "TooltipLabel" and node.is_visible_in_tree(): labels.append(node.text)
	for child in node.get_children(): labels.append_array(tooltip_labels(child))
	return labels
func hover(control: Control, should_show: bool, label: String):
	var motion := InputEventMouseMotion.new(); motion.position = control.get_global_rect().get_center(); root.push_input(motion)
	await create_timer(.8).timeout; await RenderingServer.frame_post_draw
	check(root.gui_get_hovered_control() == control, label + ": mouse reaches control")
	check(not control.get_tooltip().is_empty() if should_show else control.get_tooltip().is_empty(), label + ": tooltip contract")
	var visible := tooltip_labels(root)
	check(not visible.is_empty() if should_show else visible.is_empty(), label + ": visible hover popup")
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
func run():
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("scene.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await ready(); await settle()
	var ui = viewer.shell.transport
	check(ui.displayed.get_theme_font("font") == ui.duration.get_theme_font("font") and ui.displayed.get_theme_font_size("font_size") == ui.duration.get_theme_font_size("font_size"), "Accepted shared typography retained")
	var states: Array = []
	for state in ["normal", "hover", "pressed", "disabled", "focus"]: states.append(ui.duration.get_theme_stylebox(state))
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	await hover(ui.displayed, false, "elapsed-hover")
	await hover(ui.duration, false, "total-hover")
	click(ui.duration); await settle()
	check(ui.show_remaining and ui.duration.text == "-00:06", "Native click toggles total to negative remaining")
	await hover(ui.duration, false, "remaining-hover")
	click(ui.duration); await settle()
	check(not ui.show_remaining and ui.duration.text == "00:06", "Native click toggles back to total")
	check(viewer.committed_sample == sample, "Toggle leaves committed time unchanged")
	click(ui.displayed, true); await settle()
	check(ui.seek_dialog.visible and ui.seek_dialog.editor.has_focus(), "Double-click opens focused seek editor")
	ui.seek_dialog.editor.text = "00:02"; key(KEY_ENTER, ui.seek_dialog); await settle(); await ready(); await settle()
	check(not ui.seek_dialog.visible and viewer.committed_sample.requested_time == 2.0 and ui.displayed.text == "00:02", "Native Enter applies valid whole-clock seek")
	click(ui.displayed, true); await settle()
	ui.seek_dialog.editor.text = "00:04"; key(KEY_ESCAPE, ui.seek_dialog); await settle()
	check(not ui.seek_dialog.visible and viewer.committed_sample.requested_time == 2.0, "Native Escape cancels edited seek")
	check(ui.displayed.has_focus(), "Seek dismissal restores elapsed focus")
	check(ui.displayed.has_theme_stylebox_override("normal") and ui.displayed.get_theme_stylebox("normal").border_color == viewer.shell.style_slice.theme.c(&"focus.ring"), "Elapsed retains accepted focus outline")
	key(KEY_TAB); await settle()
	check(viewer.timeline.has_focus(), "Tab from elapsed reaches timeline")
	key(KEY_TAB); await settle()
	check(ui.duration.has_focus(), "Tab from timeline reaches duration")
	check(not ui.displayed.has_theme_stylebox_override("normal"), "Elapsed outline clears on focus exit")
	for i in states.size(): check(states[i] == ui.duration.get_theme_stylebox(["normal", "hover", "pressed", "disabled", "focus"][i]), "Duration state style retained " + str(i))
	await hover(ui.loop, true, "loop-hover")
	check(not viewer.play_button.get_tooltip().is_empty() and not viewer.timeline.get_tooltip().is_empty(), "Play and timeline tooltips remain available")
	for dimensions in [Vector2i(1440,900), Vector2i(1024,640)]:
		root.size = dimensions; await settle(); viewer.shell.layout(); await settle()
		check(ui.size.x == dimensions.x and ui.size.y == (64 if dimensions.x == 1440 else 104), "Normal/compact transport allocation " + str(dimensions))
		check(ui.displayed.get_global_rect().end.x < viewer.timeline.global_position.x and viewer.timeline.get_global_rect().end.x < ui.duration.global_position.x and ui.rate.get_global_rect().end.x <= dimensions.x, "Readouts and speed retain slider clearance " + str(dimensions))
		check(absf(ui.displayed.get_global_rect().get_center().y - ui.duration.get_global_rect().get_center().y) <= 1, "Clock alignment retained " + str(dimensions))
		ui.displayed.grab_focus(); await hover(ui.displayed, false, "elapsed-focus-" + str(dimensions.x))
		ui.duration.grab_focus(); await hover(ui.duration, false, "duration-focus-" + str(dimensions.x))
		for remaining in [true, false]:
			ui.show_remaining = remaining; ui.refresh()
			check(ui.duration.text == ("-00:04" if remaining else "00:06") and ui.displayed.get_tooltip().is_empty() and ui.duration.get_tooltip().is_empty(), "Refresh/toggle remains tooltip-free " + str(dimensions))
	viewer.free(); await process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t")); file.close()
	print("TRANSPORT TOOLTIPS: %d checks, %d failures" % [checks, failures.size()]); quit(0 if failures.is_empty() else 1)
