extends SceneTree
## Focused issue #314 audit; baseline mode records the same layouts before styling.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var shell
var output := ""
var baseline := false
var checks := 0
var failures: Array[String] = []
var measurements := {}
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	for i in 6: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func picture(name: String):
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name+".png"))
func find_close(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and (child.has_meta("shell_close") or child.text == "×" or child.tooltip_text.begins_with("Close File Locations")): return child
		var found := find_close(child)
		if found != null: return found
	return null
func metric(node: Node, data: Array):
	if node is Control and node.is_visible_in_tree():
		data.append([node.get_class(), str(node.position), str(node.size), node.text if node is Label or node is BaseButton else ""])
	for child in node.get_children(): metric(child, data)
func styles(button: Button, reference: Button, name: String):
	if baseline: return
	check(button.size == reference.size and button.custom_minimum_size == reference.custom_minimum_size, name+": shell dimensions")
	check(button.icon == reference.icon and button.icon.get_size() == Vector2(16,16) and button.text.is_empty(), name+": shared shell glyph")
	check(button.theme_type_variation == reference.theme_type_variation, name+": shared IconAction")
	check(button.focus_mode == Control.FOCUS_ALL and button.has_meta("violet_motion"), name+": keyboard focus and shell hover motion")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var actual: StyleBoxFlat = button.get_theme_stylebox(state)
		var expected: StyleBoxFlat = reference.get_theme_stylebox(state)
		check(actual.bg_color == expected.bg_color and actual.border_color == expected.border_color and actual.get_border_width_min() == expected.get_border_width_min() and actual.get_minimum_size() == expected.get_minimum_size() and actual.expand_margin_top == expected.expand_margin_top and actual.corner_radius_top_left == expected.corner_radius_top_left, name+": shell style "+state)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		check(button.get_theme_color("icon_"+state+"_color") == reference.get_theme_color("icon_"+state+"_color"), name+": shell ink "+state)
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
	check(focus.draw_center == false and focus.border_width_top > 0 and focus.expand_margin_top == 0 and focus.expand_margin_bottom == 0 and focus.expand_margin_left == 0 and focus.expand_margin_right == 0, name+": visible focus contained in 32px hit area")
func key(code: Key, window: Window, reverse := false):
	var event := InputEventKey.new(); event.keycode=code; event.pressed=true; event.shift_pressed=reverse; event.window_id=window.get_window_id()
	Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed=false; Input.parse_input_event(release)
func walk(window: Window, name: String):
	var order: Array = shell.focus_navigation.chain(window)
	check(not order.is_empty(), name+": traversal available")
	if order.is_empty(): return
	order[0].grab_focus(); await settle()
	for i in order.size():
		key(KEY_TAB,window); await settle()
		check(window.gui_get_focus_owner() == order[(i+1)%order.size()],name+": Tab order "+str(i))
	for i in order.size():
		key(KEY_TAB,window,true); await settle()
		check(window.gui_get_focus_owner() == order[posmod(-i-1,order.size())],name+": reverse Tab order "+str(i))
func mouse(button: Button, pressed: bool):
	var window := button.get_window()
	var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=button.get_global_rect().get_center(); event.pressed=pressed
	if window.is_embedded():
		event.position += Vector2(window.position); root.push_input(event)
	else: window.push_input(event)
func inspect(name: String, surface: Node, button: Button):
	var reference: Button = shell.window_chrome.actions.get_child(2)
	styles(button,reference,name)
	var layout: Array = []
	metric(surface, layout)
	# The orbit X intentionally changes its text/glyph and only its header width.
	measurements[name] = {"size":str(surface.size),"layout":layout,"close_size":str(button.size),"focus_owner":str(button.get_window().gui_get_focus_owner().get_path()) if button.get_window().gui_get_focus_owner() != null else ""}
	picture(name)
func tool_case(title: String, name: String, interactions: bool):
	var origin: Button = shell.navigation.get_child(0)
	origin.grab_focus(); await settle()
	var science := Visual.snapshot(viewer)
	viewer.tools_ui.open(title); await settle()
	var tools = viewer.tools_ui
	inspect(name,tools.window,tools.close_button)
	if interactions:
		await walk(tools.window,name)
		tools.close_button.grab_focus(); await settle(); picture(name+"-focus")
		tools.done_button.grab_focus()
		var motion := InputEventMouseMotion.new(); motion.position=tools.close_button.get_global_rect().get_center()
		if tools.window.is_embedded():
			motion.position += Vector2(tools.window.position); root.push_input(motion)
		else: tools.window.push_input(motion)
		await create_timer(.12).timeout; await settle(); picture(name+"-hover")
		if DisplayServer.get_name() != "headless":
			check(tools.close_button.is_hovered(),name+": mouse hover")
			mouse(tools.close_button,true); await settle(); picture(name+"-pressed")
			mouse(tools.close_button,false); await settle()
		else:
			tools.close_button.pressed.emit(); await settle()
		check(not tools.window.visible and root.gui_get_focus_owner() == origin,name+": click dismisses and restores initiator")
		tools.open(title); await settle(); key(KEY_ESCAPE,tools.window); await settle()
		check(not tools.window.visible,name+": Escape dismisses")
		tools.open(title); await settle(); tools.done_button.pressed.emit(); await settle()
		check(not tools.window.visible,name+": bottom Close dismisses")
		tools.open(title); await settle(); tools.window.close_requested.emit(); await settle()
		check(not tools.window.visible,name+": native close signal dismisses")
	else: tools.close(false); await settle()
	check(Visual.snapshot(viewer) == science,name+": scientific presentation unchanged")
func run():
	output=OS.get_cmdline_user_args()[0]; baseline=OS.get_cmdline_user_args().has("baseline")
	create_timer(180).timeout.connect(func(): push_error("Close audit timeout"); quit(1))
	viewer=Viewer.new();viewer.scene_prebuffer_enabled=false;root.add_child(viewer);viewer.set_process(false)
	shell=viewer.shell;shell.edge_reveal.set_process(false)
	viewer._open_capture(output.path_join("mixed.wvz"));viewer.playing=false;viewer.orbit_enabled=false
	var deadline := Time.get_ticks_msec()+15000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()<deadline:
		viewer.scene_layers.tick(0);await process_frame
	check(not viewer.scene_layers.is_buffering(),"Fixture ready")
	viewer._sync_control_state();shell.refresh();await settle()
	for light in [false,true]:
		shell.appearance.light=light;shell.appearance.apply();await settle()
		var theme_name := "light" if light else "dark"
		for dimensions in [Vector2i(1440,900),Vector2i(970,600)]:
			root.size=dimensions;await settle();shell.layout();await settle()
			var suffix := theme_name+"-"+str(dimensions.x)
			await tool_case("Global effects","global-"+suffix,true)
			await tool_case("Mapping","mapping-"+suffix,false)
			viewer.tools_ui.open("Performance");await settle();viewer.tools_ui.scroller.scroll_vertical=100000;await settle()
			inspect("performance-scrolled-"+suffix,viewer.tools_ui.window,viewer.tools_ui.close_button);viewer.tools_ui.close(false);await settle()
			shell.show_source();await settle();inspect("details-"+suffix,shell.details,shell.detail_close);shell.detail_close.pressed.emit();await settle();check(not shell.details.visible,"Details X dismisses")
			shell.about.open();await settle();inspect("about-"+suffix,shell.about,shell.about.close_button);shell.about.close_button.pressed.emit();await settle();check(not shell.about.visible,"About X dismisses")
			shell.status_ui.open_jobs();await settle();inspect("jobs-"+suffix,shell.status_ui.jobs_dialog,shell.status_ui.jobs_header_close);key(KEY_ESCAPE,shell.status_ui.jobs_dialog);await settle();check(not shell.status_ui.jobs_dialog.visible,"Jobs Escape dismisses")
			viewer.video_dialog.open();await settle();inspect("video-"+suffix,viewer.video_dialog,viewer.video_dialog.header_close);viewer.video_dialog.header_close.pressed.emit();await settle();check(not viewer.video_dialog.visible,"Video X dismisses idle dialog")
			shell.edit_shortcuts();await settle();inspect("shortcuts-"+suffix,shell.shortcuts_editor, shell.shortcuts_editor.close_button);shell.shortcuts_editor.close_button.pressed.emit();await settle();check(not shell.shortcuts_editor.visible,"Shortcuts X discards and dismisses")
			shell.edit_file_locations();await settle();var location_close := find_close(shell.file_locations_dialog);inspect("locations-"+suffix,shell.file_locations_dialog,location_close);key(KEY_ESCAPE,shell.file_locations_dialog);await settle();check(not shell.file_locations_dialog.visible,"File Locations Escape discards and dismisses")
			var camera: Transform3D = viewer.camera.transform
			shell.edit_orbit_center();await settle();var orbit_close := find_close(shell.orbit_editor.panel);inspect("orbit-"+suffix,shell.orbit_editor.panel,orbit_close);orbit_close.pressed.emit();await settle();check(not shell.orbit_editor.visible and viewer.camera.transform == camera,"Orbit X cancels and restores camera")
		root.size=Vector2i(3840,2160);root.content_scale_factor=2.0;await settle();shell.layout();await settle()
		await tool_case("Global effects","global-"+theme_name+"-3840-scale2",false)
		root.content_scale_factor=1.0;await settle()
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"baseline":baseline,"measurements":measurements},"  "));file.close()
	viewer.free();await process_frame
	print("DIALOG CLOSE: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
