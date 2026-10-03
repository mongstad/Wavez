extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Seek = preload("res://ui/shell/time_seek_popover.gd")
const Chrome = preload("res://ui/shell/window_chrome.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var viewer
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	await create_timer(.18).timeout
	await RenderingServer.frame_post_draw
func ready() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	viewer.shell.transport.refresh()
	check(not viewer.scene_layers.is_buffering(), "Source preparation completes")
func picture(name: String) -> void: root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func visible_ink(image: Image, control: Control) -> bool:
	var rect := Rect2i(control.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var color := image.get_pixel(x,y)
			if maxf(color.r, maxf(color.g,color.b)) > .3: return true
	return false
func click(point: Vector2, double := false) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true; event.double_click = double; event.position = point; root.push_input(event)
	var release := event.duplicate(); release.pressed = false; release.double_click = false; root.push_input(release)
func key(code: Key, window = root, alt := false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; event.alt_pressed = alt
	event.window_id = window.get_window_id(); Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	var shell = viewer.shell; var ui = shell.transport
	ui.open_seek(); check(not ui.seek_dialog.visible and ui.rate.disabled, "Empty capture cannot seek or change speed")
	viewer._open_capture(output.path_join("scene.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await ready(); await settle()
	check(root.borderless and not root.unresizable, "Interactive window is borderless and resizable")
	check(shell.bar.is_ancestor_of(shell.navigation), "Camera actions integrated in top bar")
	check(shell.window_chrome.actions.get_child_count() == 3 and shell.bar.is_ancestor_of(shell.window_chrome.actions), "Three window actions at right of top bar")
	check(ui.rate.item_count == 8 and ui.rate.size.x <= 96, "Eight speed presets in a compact selector")
	check(ui.rate.get_parent() == ui.duration.get_parent() and ui.rate.get_index() > ui.duration.get_index(), "Speed follows timeline end-time readout")
	for i in ui.SPEEDS.size():
		check(ui.rate.get_item_text(i) == ["0.25×", "0.5×", "0.75×", "1×", "1.5×", "2×", "3×", "4×"][i], "Exact speed preset " + str(i))
		ui.rate.item_selected.emit(i); ui.refresh()
		check(viewer.physical_rate == ui.SPEEDS[i], "Preset routes to canonical rate " + str(i))
	for value in [-.5, 0.0, .12345678912345678, 12.0]:
		viewer.physical_rate = value; ui.refresh()
		check(viewer.physical_rate == value and ui.rate.selected == -1 and ui.rate.item_count == 8, "Saved custom rate remains exact " + str(value))
	viewer.physical_rate = 1; ui.refresh()
	for pair in [["00:00",0.0],["01:45",105.0],["12:43",763.0],["01:02:03",3723.0]]:
		check(Seek.parse_time(pair[0]).get("value") == pair[1], "Formatted time parser " + pair[0])
	for text in ["NaN","INF","00:60","01:60:00","-01:02","1::2","bad","1:2:3:4","1.25","01:02.125","01:02:03.25","1:02","+01:02","00:-1"]:
		check(Seek.parse_time(text).has("error"), "Malformed clock refused " + text)
	var sample: Dictionary = viewer.committed_sample.duplicate(true); var camera: Transform3D = viewer.camera.transform
	click(ui.displayed.get_global_rect().get_center(), true); await settle()
	check(ui.seek_dialog.visible, "Current-time double-click opens shared popover")
	check(ui.seek_dialog.editor.has_focus() and ui.seek_dialog.editor.get_selected_text() == ui.seek_dialog.editor.text, "Seek prefill selected for immediate typing")
	check(ui.seek_dialog.position.y < ui.displayed.global_position.y, "Popover anchored above initiating time")
	ui.seek_dialog.editor.text = "NaN"; key(KEY_ENTER, ui.seek_dialog); await settle()
	check(ui.seek_dialog.visible and ui.seek_dialog.error_label.visible and viewer.committed_sample == sample, "Invalid Enter retains scene and shows restrained feedback")
	picture("seek-invalid")
	ui.seek_dialog.editor.text = "99:00"; key(KEY_ENTER, ui.seek_dialog); await settle()
	check(ui.seek_dialog.visible and ui.seek_dialog.error_label.text.contains("interval") and viewer.committed_sample == sample, "Out-of-range time refused")
	ui.seek_dialog.editor.text = "00:02"; key(KEY_ESCAPE, ui.seek_dialog); await settle()
	check(not ui.seek_dialog.visible and viewer.committed_sample == sample, "Esc cancels entire popover without seek")
	ui.open_seek(); await settle(); ui.seek_dialog.editor.text = "00:02"
	click(Vector2(200, 180)); await settle()
	check(not ui.seek_dialog.visible and viewer.committed_sample == sample, "Click away dismisses without applying")
	click(viewer.timeline.global_position + viewer.timeline.playhead_rect().get_center(), true); await settle()
	check(ui.seek_dialog.visible, "Playhead double-click opens same seek popover")
	check(absf(ui.seek_dialog.position.x + ui.seek_dialog.size.x * .5 - (viewer.timeline.global_position + viewer.timeline.playhead_rect().get_center()).x) < ui.seek_dialog.size.x, "Popover remains near playhead")
	picture("seek-playhead")
	ui.seek_dialog.editor.text = "00:02"; key(KEY_ENTER, ui.seek_dialog); await settle(); await ready(); await settle()
	check(not ui.seek_dialog.visible and viewer.committed_sample.requested_time == 2.0, "Enter routes whole clock through the scientific seek controller")
	viewer._seek_time(1.0000000000000002); await ready(); ui.open_seek(); await settle()
	check(ui.seek_dialog.editor.text == ui.displayed.text and ui.displayed.text == "00:01", "Whole-clock prefill equals the displayed current time")
	key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample.requested_time == 1.0000000000000002, "Unchanged whole-clock prefill preserves exact float64 source time")
	check(viewer.camera.transform == camera and not viewer.playing, "Seek preserves camera and paused state")
	# A real native Slider drag continues to use the union-sample index.
	var start: Vector2 = viewer.timeline.global_position + viewer.timeline.playhead_rect().get_center()
	var finish: Vector2 = viewer.timeline.global_position + Vector2(viewer.timeline.size.x, viewer.timeline.size.y * .5)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = start; root.push_input(press)
	var move := InputEventMouseMotion.new(); move.position = finish; move.button_mask = MOUSE_BUTTON_MASK_LEFT; root.push_input(move)
	var release := press.duplicate(); release.pressed = false; release.position = finish; root.push_input(release)
	await ready(); await settle()
	check(viewer.current_index == viewer.frame_count - 1 and not ui.seek_dialog.visible, "Dragging playhead still scrubs to union endpoint")
	check(viewer.timeline.tooltip_text.contains("Drag to scrub · Double-click to seek"), "Timeline explains drag and seek")
	viewer._seek_time(0.0); await ready()
	click(viewer.play_button.get_global_rect().get_center(), true); await settle()
	check(not ui.seek_dialog.visible, "Play is never a seek entry point")
	viewer.playing = false
	var nav: MenuButton = shell.navigation.get_child(2)
	var focus := root.gui_get_focus_owner(); if focus != null: focus.release_focus()
	key(KEY_N, root, true); await settle()
	check(nav.get_popup().visible, "Unused Alt+N opens Navigate menu")
	nav.get_popup().hide()
	viewer.yaw = 1.7; viewer._update_camera(); shell.navigation.get_child(1).pressed.emit()
	check(is_equal_approx(viewer.yaw, deg_to_rad(38)), "Relocated Reset uses existing camera handler")
	for side in shell.edge_reveal.pins:
		var pin: Button = shell.edge_reveal.pins[side]
		check(pin.theme_type_variation == "PinAction" and pin.get_theme_stylebox("pressed").bg_color.a == 0, side + " pin has no persistent active fill")
		var icon = pin.icon; shell.edge_reveal.set_pinned(side, false)
		check(pin.icon != icon and not pin.button_pressed, side + " pin silhouette distinguishes state")
		shell.edge_reveal.set_pinned(side, true)
	for point in [Vector2(1,1),Vector2(500,1),Vector2(1439,1),Vector2(1,400),Vector2(1439,400),Vector2(1,899),Vector2(500,899),Vector2(1439,899)]:
		check(Chrome.resize_edge(point, Vector2(1440,900)) >= 0, "Native resize edge/corner " + str(point))
	check(Chrome.resize_edge(Vector2(200,200),Vector2(1440,900)) == -1, "Interior never starts window resizing")
	var requests: Array = []
	var drag_api: Callable = shell.window_chrome.start_drag
	var resize_api: Callable = shell.window_chrome.start_resize
	shell.window_chrome.start_drag = func(id): requests.append(["drag", id])
	shell.window_chrome.start_resize = func(edge, id): requests.append(["resize", edge, id])
	var title_press := InputEventMouseButton.new(); title_press.button_index = MOUSE_BUTTON_LEFT; title_press.pressed = true
	shell.window_chrome.title_input(title_press)
	check(requests.size() == 1 and requests[0] == ["drag", root.get_window_id()], "Title press delegates one native drag request")
	title_press.pressed = false; shell.window_chrome.title_input(title_press)
	check(requests.size() == 1, "Release never starts native dragging")
	title_press.pressed = true; title_press.position = Vector2(1,1)
	shell.window_chrome._input(title_press)
	check(requests.size() == 2 and requests[1] == ["resize", DisplayServer.WINDOW_EDGE_TOP_LEFT, root.get_window_id()], "Corner press delegates correct native resize request")
	title_press.position = Vector2(200,200); shell.window_chrome._input(title_press)
	check(requests.size() == 2, "Interior click cannot request native resize")
	shell.window_chrome.start_drag = drag_api; shell.window_chrome.start_resize = resize_api
	check(shell.window_chrome.grips.size() == 8 and shell.window_chrome.grips[0].mouse_default_cursor_shape == Control.CURSOR_FDIAGSIZE, "Eight invisible resize grips retain cursor affordances")
	ui.open_seek(); await settle(); shell.enter_immersive(); await settle()
	check(not ui.seek_dialog.visible and root.gui_get_focus_owner() == null, "Fullscreen dismisses seek and releases chrome focus")
	check(not shell.navigation.is_visible_in_tree(), "Relocated actions remain hidden at fullscreen entry")
	shell.edge_reveal.tick(.51, Vector2(100,1), true, false)
	check(shell.bar.is_visible_in_tree() and shell.navigation.is_visible_in_tree(), "Fullscreen top-edge reveal includes relocated camera actions")
	shell.exit_immersive(); await settle()
	check(shell.bar.get_theme_stylebox("panel") is StyleBoxTexture and shell.dock.get_theme_stylebox("panel") is StyleBoxTexture, "Related static tones give structural depth")
	for group in ["Rendering", "Color Mapping"]: viewer.section_buttons[group].button_pressed = true
	await settle(); shell.scroll.scroll_vertical = 0; await settle(); picture("round2-1440")
	ui.rate.get_popup().popup(Rect2i(1000,600,100,0)); await settle(); picture("speed-presets"); ui.rate.get_popup().hide()
	shell.show_source(); await settle(); picture("source-dialog"); shell.details.hide()
	shell.about.open(); await settle(); picture("about-dialog"); shell.about.hide()
	viewer.video_dialog.cancel_confirmation.theme = shell.style_slice.theme
	viewer.video_dialog.cancel_confirmation.popup_centered(); await settle(); picture("confirmation-dialog"); viewer.video_dialog.cancel_confirmation.hide()
	root.size = Vector2i(1024,640); await settle(); shell.layout(); await settle(); picture("round2-1024")
	check(shell.bar.get_combined_minimum_size().x <= 1024, "Top bar fits minimum review window")
	check(shell.window_chrome.actions.get_global_rect().end.x <= 1024 and shell.navigation.get_global_rect().end.x < shell.window_chrome.actions.global_position.x, "Relocated/window actions retain separate usable areas")
	var chrome_geometry: Array = []
	for action in shell.window_chrome.actions.get_children():
		chrome_geometry.append({"rect":str(action.get_global_rect()), "visible":action.is_visible_in_tree(), "icon":str(action.icon.get_size()), "modulate":str(action.self_modulate)})
		check(action.is_visible_in_tree() and action.size.x >= 32 and action.get_global_rect().position.x >= 0 and action.get_global_rect().end.x <= 1024, "Every native window action remains usable in compact layout")
		check(visible_ink(root.get_texture().get_image(), action), "Every compact window-action glyph is rendered")
	# Offset origin and long formatted time map back to unchanged source units.
	viewer._open_capture(output.path_join("clock.wvz")); viewer.playing = false; await ready()
	ui.open_seek(); await settle(); ui.seek_dialog.editor.text = "01:00"; key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample.requested_time == 160.0, "Formatted elapsed time maps to nonzero scientific origin")
	ui.open_seek(); await settle(); ui.seek_dialog.editor.text = "01:00:00"; key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample.requested_time == 3700.0, "Hour format maps to established source seek")
	ui.open_seek(); await settle(); var exact: Dictionary = viewer.committed_sample.duplicate(true); key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample == exact, "Unchanged formatted prefill preserves exact clock")
	ui.open_seek(); viewer._open_capture(output.path_join("scene.wvz")); await ready()
	check(not ui.seek_dialog.visible, "Capture replacement dismisses stale popover")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"compact_chrome":chrome_geometry}, "\t")); file.close()
	viewer.free(); await process_frame
	print("ROUND 2: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
