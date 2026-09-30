extends SceneTree
## Owner corrections after b9a2df3: real menu dispatch while native Fullscreen.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
var opened: Array = []
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
func picture(title: String) -> void: root.get_texture().get_image().save_png(output.path_join(title + ".png"))
func click(point: Vector2, window = root) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true; event.position = point; window.push_input(event)
	var release := event.duplicate(); release.pressed = false; window.push_input(release)
func key(code: Key, window = root) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	event.window_id = window.get_window_id(); Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func disclosures(node: Node) -> void:
	if node is Button and node.has_meta("panel_disclosure"):
		var icon: Texture2D = node.icon
		var prior: bool = node.button_pressed
		var margin: MarginContainer = node.get_parent().get_child(node.get_index() + 1)
		var body: Control = margin.get_child(0)
		node.button_pressed = not prior
		check(node.icon != icon and body.visible == node.button_pressed and margin.visible == body.visible, node.text + " chevron still routes disclosure")
		node.button_pressed = prior
	for child in node.get_children(): disclosures(child)
func invoke(menu_name: String, command: String) -> void:
	var shell = viewer.shell
	# Production 10px dwell route reveals the bar; actual MenuButton click and
	# PopupMenu keyboard selection exercise the binding, never Tools.open directly.
	shell.edge_reveal.tick(.51, Vector2(100, 1), true, false)
	await settle()
	check(shell.bar.is_visible_in_tree(), "Fullscreen toolbar edge-revealed for " + command)
	var menu: MenuButton = shell.menus[menu_name]
	click(menu.get_global_rect().get_center()); await settle()
	var popup: PopupMenu = menu.get_popup()
	check(popup.visible, menu_name + " menu opened through revealed toolbar")
	var entry: Dictionary = shell.commands[command]
	check(entry.popup == popup and not popup.is_item_disabled(entry.index), command + " is enabled in production menu")
	popup.set_focused_item(entry.index); key(KEY_ENTER, popup); await settle()
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	var shell = viewer.shell; var ui = shell.transport
	shell.edge_reveal.set_process(false)
	check(shell.status_ui.find_child("CaptureFilename",true,false) == null, "Empty capture has no passive filename")
	viewer._open_capture(output.path_join("scene.ssc")); viewer.playing = false; viewer.orbit_enabled = false
	await ready(); await settle()
	var scientific: Dictionary = Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	disclosures(viewer.inspector_box); disclosures(shell.adapter)
	check(Visual.snapshot(viewer) == scientific and viewer.committed_sample == sample, "Disclosure round trips preserve scientific state and clock")
	check(shell.commands.details.popup == shell.menus.File.get_popup(), "Details is in File")
	check(shell.status_ui.find_child("CaptureFilename",true,false) == null, "No passive capture filename")
	shell.commands.details.popup.id_pressed.emit(shell.commands.details.index); await settle()
	check(shell.details.visible and shell.detail_text.text.contains(viewer.capture_path), "Source path remains available through explicit details command")
	shell.details.hide()
	for title in ["Rendering", "Particle Filters", "Color Mapping", "Advanced • Size / Brightness"]: viewer.section_buttons[title].button_pressed = true
	await settle(); shell.scroll.scroll_vertical = 0; await settle(); picture("corrected-panel-1440")
	shell.scroll.ensure_control_visible(viewer.visual_sliders.Gamma); await settle(); picture("violet-exposure-gamma")
	for title in ["Rendering", "Particle Filters", "Color Mapping", "Advanced • Size / Brightness"]: viewer.sections[title].visible = scientific.sections[title]
	# Mixed pre-fullscreen pin state, including timers, must survive Tools windows.
	shell.edge_reveal.set_pinned("right", false)
	shell.edge_reveal.tick(.36, Vector2(100, 200), false, false)
	var saved_edges: Dictionary = shell.edge_reveal.states.duplicate(true)
	var before: Dictionary = Visual.snapshot(viewer)
	var camera: Transform3D = viewer.camera.transform
	var focus := root.gui_get_focus_owner(); if focus != null: focus.release_focus()
	key(KEY_F11); await settle()
	check(shell.immersive and root.mode == Window.MODE_FULLSCREEN and not shell.bar.visible, "Native F11 enters Fullscreen with hidden toolbar")
	for title in ["Performance", "Mapping", "Source probe"]:
		await invoke("Tools", "tool:" + title)
		var tools = viewer.tools_ui
		check(tools.window.visible and tools.current == title and tools.forms[title].is_visible_in_tree(), title + " tool visibly opens from Fullscreen menu")
		check(tools.window.size.x >= 320 and tools.window.size.y >= 240 and tools.window.position.y >= 0, title + " has usable Fullscreen bounds")
		check(shell.edge_reveal.popup_active(viewer), title + " protects edge reveal while dialog is open")
		var close_button: Button = tools.footer.get_parent().get_child(tools.footer.get_index() + 1)
		close_button.grab_focus()
		check(close_button.has_focus(), title + " dialog accepts keyboard focus")
		opened.append({"tool":title,"native_mode":root.mode,"embedded":tools.window.is_embedded(),"size":str(tools.window.size)})
		picture("fullscreen-" + title.to_lower().replace(" ", "-"))
		key(KEY_ENTER, tools.window); await settle()
		check(not tools.window.visible and shell.immersive, title + " closes through focused button without exiting Fullscreen")
	await invoke("View", "global_effects")
	check(viewer.tools_ui.window.visible and viewer.tools_ui.current == "Global effects", "View global-effects form also opens in Fullscreen")
	viewer.tools_ui.close(); await settle()
	await invoke("Help", "shortcuts")
	check(shell.details.visible and shell.details.title == "Shortcuts", "Informational dialog opens through Fullscreen menu")
	shell.details.hide(); await settle()
	await invoke("File", "details")
	check(shell.details.visible and shell.details.title == "Status details" and shell.detail_text.text.contains(viewer.capture_path), "File Details retains source/status access in Fullscreen")
	check(shell.edge_reveal.popup_active(viewer), "Details protects edge reveal while open")
	picture("fullscreen-file-details")
	key(KEY_ESCAPE,shell.details); await settle()
	check(not shell.details.visible and shell.immersive, "Esc closes Details without exiting Fullscreen")
	check(Visual.snapshot(viewer) == before and viewer.committed_sample == sample and viewer.camera.transform == camera, "Tools navigation preserves scientific state, precise clock and camera")
	shell.edge_reveal.set_pinned("top", true)
	key(KEY_F11); await settle()
	check(not shell.immersive and shell.edge_reveal.states == saved_edges, "Exit restores all original edge/pin/timer states after Tools and temporary pin")
	# Whole-second clocks stay identical before playback, while playing and paused.
	viewer._open_capture(output.path_join("clock.ssc")); viewer.playing = false; await ready()
	check(ui.displayed.text == "00:00", "Capture with nonzero precise origin starts at 00:00")
	viewer._seek_time(205.875); await ready()
	for playing in [false, true, false]:
		viewer.playing = playing; ui.refresh(); ui.open_seek(); await settle()
		check(ui.displayed.text == "01:45" and ui.seek_dialog.editor.text == ui.displayed.text, "Whole-clock representation and prefill are stable at playback state " + str(playing))
		check(ui.seek_dialog.get_child(0).get_child_count() == 2 and not ui.seek_dialog.error_label.visible, "Seek has only focused input and conditional feedback")
		ui.seek_dialog.hide()
	viewer.playing = false
	ui.open_seek(); var precise: float = viewer.committed_sample.requested_time
	key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample.requested_time == precise, "Accepting whole-clock prefill retains precise origin and subsecond source time")
	ui.open_seek(); ui.seek_dialog.editor.text = "01:01:40"; key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample.requested_time == 3800.125 and ui.displayed.text == "01:01:40", "Hour clock seeks up to capture's final whole second")
	ui.open_seek(); ui.seek_dialog.editor.text = "01:01:41"; key(KEY_ENTER, ui.seek_dialog); await settle()
	check(ui.seek_dialog.visible and ui.seek_dialog.error_label.visible and viewer.committed_sample.requested_time == 3800.125, "Next whole second beyond fractional capture end is refused")
	picture("clock-invalid-end"); ui.seek_dialog.hide()
	viewer._seek_time(3800.625); await ready(); ui.open_seek(); await settle(); key(KEY_ENTER, ui.seek_dialog); await settle(); await ready()
	check(viewer.committed_sample.requested_time == 3800.625, "Unchanged prefill at fractional capture endpoint preserves exact end")
	root.size = Vector2i(1024, 640); await settle(); shell.layout(); await settle()
	check(shell.status_ui.get_global_rect().end.x <= 1024 and shell.bar.get_combined_minimum_size().x <= 1024, "Status and top actions fit compact window")
	picture("corrected-1024")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name(),"fullscreen_dialogs":opened}, "\t")); file.close()
	viewer.free(); await process_frame
	print("REVIEW CORRECTIONS: ", checks, " checks, ", failures.size(), " failures"); quit(0 if failures.is_empty() else 1)
