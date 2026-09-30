extends SceneTree
## Real production controls: native input, recipe rebuilds, source replacement.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
var audit_counts := []
var layouts := []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	await create_timer(.16).timeout
	await RenderingServer.frame_post_draw
func ready() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	viewer._sync_control_state(); viewer.shell.transport.refresh(); viewer.shell.status_ui.refresh()
	check(not viewer.scene_layers.is_buffering(), "Fixture ready")
func picture(name: String) -> void:
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func key(code: Key, window = root) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	event.window_id = window.get_window_id(); Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true; event.position = point; root.push_input(event)
	var release := event.duplicate(); release.pressed = false; root.push_input(release)
func booleans(node: Node) -> Array:
	if node is FileDialog: return []
	var result := []
	if node is CheckButton or node is CheckBox: result.append(node)
	for child in node.get_children(): result.append_array(booleans(child))
	return result
func audit(stage: String) -> void:
	var theme = viewer.shell.style_slice.theme
	var widgets := booleans(viewer)
	check(widgets.size() >= 25, stage + " includes real panel, dynamic layer, transport, Tools and export booleans")
	for control in widgets:
		var membership: bool = control.get_parent() == viewer.filter_box
		check((control is CheckBox) if membership else (control is CheckButton), stage + " semantic widget: " + control.text)
		var type := "CheckBox" if membership else "CheckButton"
		for icon in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
			check(control.get_theme_icon(icon) == theme.get_icon(icon,type), stage + " shared " + icon + ": " + control.text)
		check(control.get_theme_stylebox("focus").border_color == theme.c(&"focus.ring"), stage + " visible focus: " + control.text)
		check(control.get_theme_stylebox("hover").bg_color == theme.c(&"surface.hover"), stage + " shared hover: " + control.text)
	audit_counts.append({"stage":stage,"booleans":widgets.size()})
func details() -> void:
	var shell = viewer.shell
	var before := Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var requests: int = viewer.selection_controller.jobs.serial
	shell.navigation.get_child(0).grab_focus(); click(shell.menus.File.get_global_rect().get_center()); await settle()
	var entry: Dictionary = shell.commands.details
	check(entry.popup.visible and entry.popup == shell.menus.File.get_popup(), "File menu opens by pointer")
	check(entry.popup.get_item_text(entry.index) == "Details…" and not entry.popup.is_item_disabled(entry.index), "Direct File Details command is available")
	entry.popup.set_focused_item(entry.index); key(KEY_ENTER,entry.popup); await settle()
	check(shell.details.visible and shell.details.title == "Status details", "Native File command opens existing status Details")
	check(shell.detail_text.text.contains(shell.status_ui.readiness) and shell.detail_text.text.contains(viewer.capture_path), "Details retains readiness and full source path")
	check(shell.detail_text.editable == false and shell.detail_text.selecting_enabled, "Source diagnostics stay selectable and read-only")
	check(Visual.snapshot(viewer) == before and viewer.committed_sample == sample and viewer.selection_controller.jobs.serial == requests, "Menu/Details preserves scientific state, clock and jobs")
	picture("file-details")
	key(KEY_ESCAPE,shell.details); await settle()
	check(not shell.details.visible and shell.navigation.get_child(0).has_focus(), "Esc closes Details and restores prior focus")
	for node in shell.bar.find_children("*", "Button",true,false):
		check(node.tooltip_text != "Source details", "No permanent top Source action")
	check(shell.status_ui.find_child("CaptureFilename",true,false) == null, "No passive filename")
	for node in shell.status_ui.find_children("*","Button",true,false):
		check(not node.is_visible_in_tree() or node.text != "Details…", "No persistent status Details button")
func filter_interaction() -> void:
	var shell = viewer.shell
	viewer.section_buttons["Particle Filters"].button_pressed = true
	shell.select_workspace(0); shell.scroll.ensure_control_visible(viewer.filter_box); await settle()
	check(viewer.filter_box.get_child_count() == 2,"Two independent type members")
	var original := Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var first: CheckBox = viewer.filter_box.get_child(0)
	var title: String = viewer._type_label(0)
	check(first == viewer.control_checks[title] and first.tooltip_text.contains("Type 0"),"Filter retains its original key/provenance")
	first.grab_focus(); await settle(); picture("filters-focus")
	key(KEY_ENTER); await ready(); await settle()
	check(viewer.hidden_types == {0:true},"Native Enter excludes only selected type")
	var expected: Dictionary = original.duplicate(true); expected.hidden_types = [0]
	check(Visual.snapshot(viewer) == expected and not viewer.playing,"Filter affects only accepted membership state")
	for field in ["requested_time","source_indices","source_times","alpha","scalar_time"]:
		check(viewer.committed_sample.get(field) == sample.get(field),"Filter preserves scientific clock/sample: "+field)
	check(viewer.filter_box.get_child(1).button_pressed,"Other member remains included")
	picture("filters-unchecked")
	var preset := Visual.snapshot(viewer)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(preset))
	viewer.hidden_types.clear(); viewer._restyle(); await ready()
	Visual.apply(viewer,saved)
	await ready(); await settle()
	check(viewer.hidden_types == {0:true} and not viewer.filter_box.get_child(0).button_pressed,"Saved exclusions and rebuilt checkbox state survive visual-state load")
	Visual.apply(viewer,original); await ready(); await settle()
	check(Visual.snapshot(viewer) == original,"Visual recipe restores original state")
	first = viewer.filter_box.get_child(0)
	var before := Visual.snapshot(viewer)
	first.grab_focus(); first.mouse_entered.emit(); await settle(); picture("filters-hover")
	first.mouse_exited.emit(); first.disabled = true; await settle(); picture("filters-disabled")
	key(KEY_ENTER); await settle()
	check(Visual.snapshot(viewer) == before,"Disabled membership emits no change")
	first.disabled = false; first.release_focus(); await settle()
	check(first.get_combined_minimum_size().y <= 36,"Membership row remains compact")
func switches() -> void:
	var shell = viewer.shell
	var original := Visual.snapshot(viewer)
	var layers = viewer.scene_layers
	for pair in [["volume0","visible"],["volume0","volume"],["volume0","legend"],["mesh0","visible"],["mesh0","wireframe"],["mesh0","legend"]]:
		var id: String = pair[0]; var field: String = pair[1]
		shell.select_workspace(1 if id.begins_with("volume") else 2)
		layers.panel_groups[id+"/Rendering"].button_pressed = true
		layers.panel_groups[id+"/Color Mapping"].button_pressed = true
		var control: CheckButton = layers.panel_controls[id][field]
		shell.scroll.ensure_control_visible(control); await settle()
		var value := control.button_pressed
		control.grab_focus(); key(KEY_SPACE); await ready(); await settle()
		check(control.button_pressed != value,"Native switch activation: "+id+"/"+field)
		var state: bool = layers.legend_visibility[id] if field == "legend" else layers.states[id][field]
		check(state == control.button_pressed,"Existing boolean controller: "+id+"/"+field)
		key(KEY_SPACE); await ready(); await settle()
		check(control.button_pressed == value,"Switch round trip: "+id+"/"+field)
		if id == "volume0" and field == "volume": picture("fields-switches")
		if id == "mesh0" and field == "wireframe": picture("meshes-switches")
	Visual.apply(viewer,original); await ready(); await settle()
	check(Visual.snapshot(viewer) == original,"Switch round trips preserve full saved presentation")
func about() -> void:
	var shell = viewer.shell
	var original := Visual.snapshot(viewer)
	for scenario in [[Vector2i(1440,900),1.0],[Vector2i(1024,640),1.0],[Vector2i(3840,2160),2.0]]:
		root.size = scenario[0]; root.content_scale_factor = scenario[1]; await settle(); shell.layout()
		shell.about.open(); await settle()
		var dialog = shell.about
		var available := root.get_visible_rect().size
		check(Vector2(dialog.size).x <= available.x and Vector2(dialog.size).y <= available.y,"About fits logical viewport "+str(scenario))
		check(dialog.logo.texture.get_size() == Vector2(1254,1254) and dialog.logo.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"Full owner raster with mipmaps")
		check(dialog.logo.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and dialog.logo.size.x == dialog.logo.size.y,"Logo retains square aspect without stretching")
		picture("about-"+str(scenario[0].x)+"-scale-"+str(scenario[1]))
		layouts.append({"requested":scenario[0],"scale":scenario[1],"actual":root.size,"logical":available})
		dialog.hide()
	root.content_scale_factor = 1; root.size = Vector2i(1440,900); await settle()
	check(Visual.snapshot(viewer) == original,"About/scaling preserves scientific presentation")
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(115).timeout.connect(func():push_error("Cleanup test timeout");quit(1))
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer.shell.edge_reveal.set_process(false)
	viewer.shell.refresh_commands()
	check(not viewer.shell.commands.details.popup.is_item_disabled(viewer.shell.commands.details.index),"Details available before capture")
	viewer.shell.commands.details.popup.id_pressed.emit(viewer.shell.commands.details.index); await settle()
	check(viewer.shell.detail_text.text.contains("No capture loaded."),"Existing empty-capture Details")
	viewer.shell.details.hide()
	viewer._open_capture(output.path_join("mixed.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	await ready();await settle();audit("mixed capture")
	await details();await filter_interaction();audit("saved visual-state rebuild")
	await switches();audit("visual recipe rebuild");await about()
	viewer._open_capture(output.path_join("particles.ssc"));viewer.playing = false;await ready();await settle()
	audit("capture replacement")
	viewer.free();await process_frame
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"audits":audit_counts,"layouts":layouts},"\t"));file.close()
	print("VIOLET CLEANUP: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
