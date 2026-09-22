extends Control
## Presentation-only adapter. Controllers and the root scientific viewport retain ownership.
const ThemeSource = preload("res://ui/theme/simscope_theme.gd")
const WORKSPACES = ["Scene", "Appearance"]
var viewer
var transport
var status_ui
var bar: PanelContainer
var dock: PanelContainer
var scroll: ScrollContainer
var tabs: GridContainer
var chooser: OptionButton
var source_button: Button
var navigation: HBoxContainer
var recovery: Button
var fullscreen_button: Button
var empty: VBoxContainer
var open_error: PanelContainer
var error_text: Label
var error_details := ""
var details: AcceptDialog
var detail_text: TextEdit
var adapter: VBoxContainer
var workspace := 0
var tab_buttons: Array[Button] = []
var menus: Dictionary = {}
var commands: Dictionary = {}
var loading := false
var previous_focus: WeakRef
var compact := false
var has_layout := false
var scroll_position := 0
var requested_dock := true
var auto_collapsed := false
var changing_layout := false
var narrow_open := false
# Session-only presentation state; never change serialized scientific visibility.
var immersive := false
var immersive_hint: Label
var immersive_started := 0
var immersive_native_seen := false
var immersive_mode := DisplayServer.WINDOW_MODE_WINDOWED
var immersive_focus: WeakRef

func setup(owner_viewer) -> void:
	viewer = owner_viewer
	# Responsive logical pixels; retain the configured scale factor exactly once.
	if get_viewport() is Window: get_viewport().content_scale_size = Vector2i.ZERO
	name = "ViewerShell"
	theme = ThemeSource.new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	bar = PanelContainer.new(); bar.add_theme_stylebox_override("panel", theme.box(&"surface.1", &"border.subtle", 0, 0, 0)); add_child(bar)
	var margin := MarginContainer.new(); bar.add_child(margin)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_"+side, 12)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 8)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); margin.add_child(row)
	var brand := Label.new(); brand.text = "SimScope"; row.add_child(brand)
	source_button = button(row, "No capture", show_source, "info")
	source_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_button.clip_text = true; source_button.custom_minimum_size.x = 80
	build_menus(row)
	dock = viewer.overlay_panel
	dock.theme = theme
	dock.theme_type_variation = "PropertyGroup"
	scroll = viewer.inspector_box.get_parent()
	dock.remove_child(scroll)
	var dock_box := VBoxContainer.new(); dock.add_child(dock_box)
	var header := HBoxContainer.new(); dock_box.add_child(header)
	var title := Label.new(); title.text = "Workspace"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	button(header, "Hide panel", viewer._toggle_overlay, "close")
	tabs = GridContainer.new(); tabs.columns = 2; dock_box.add_child(tabs)
	chooser = OptionButton.new(); chooser.custom_minimum_size.y = 32; dock_box.add_child(chooser)
	for i in WORKSPACES.size():
		var tab := button(tabs, WORKSPACES[i], select_workspace.bind(i), ["scene", "appearance", "selection", "analysis"][i])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tab_buttons.append(tab)
		chooser.add_item(WORKSPACES[i])
	chooser.item_selected.connect(select_workspace)
	dock_box.add_child(scroll); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	adapter = VBoxContainer.new(); adapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# All retained controls stay in their original VBox and retain serialized section keys.
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.remove_child(viewer.inspector_box); scroll.add_child(content)
	content.add_child(adapter); content.add_child(viewer.inspector_box)
	recovery = button(self, "Show panels", viewer._toggle_overlay, "view")
	navigation = HBoxContainer.new(); add_child(navigation)
	button(navigation, "Frame scene", viewer._focus_activity, "frame")
	button(navigation, "Reset camera", viewer._reset_camera, "reset")
	var navigate := MenuButton.new(); navigate.flat = false; navigate.text = "Navigate"; navigate.custom_minimum_size.y = 32; navigation.add_child(navigate); decorate_menu(navigate)
	var modes := navigate.get_popup(); modes.add_check_item("Free camera"); modes.add_check_item("Auto orbit"); modes.add_item("Orbit speed")
	navigate.about_to_popup.connect(func(): modes.set_item_checked(0, viewer.free_camera); modes.set_item_checked(1, viewer.orbit_enabled))
	modes.id_pressed.connect(func(id):
		if id == 0:
			viewer.free_camera = not viewer.free_camera; viewer.orbit_enabled = not viewer.free_camera
		elif id == 1: viewer.orbit_enabled = not viewer.orbit_enabled; viewer.inspection_paused = false
		else: viewer.tools_ui.open("Camera")
		viewer._sync_control_state())
	fullscreen_button = button(self, "Exit fullscreen", viewer._toggle_fullscreen, "view")
	empty = VBoxContainer.new(); add_child(empty)
	var welcome := Label.new(); welcome.text = "Open a capture to begin"; empty.add_child(welcome)
	button(empty, "Open capture", viewer._show_open_dialog, "open").theme_type_variation = "PrimaryButton"
	open_error = PanelContainer.new(); add_child(open_error)
	var error_row := HBoxContainer.new(); open_error.add_child(error_row)
	error_text = Label.new(); error_text.text = "Capture could not be opened"; error_text.add_theme_color_override("font_color", theme.c(&"state.error")); error_row.add_child(error_text)
	button(error_row, "Details…", func(): show_details("Open failed", error_details), "warning")
	button(error_row, "Choose another…", viewer._show_open_dialog, "open")
	button(error_row, "Dismiss", func():
		open_error.hide()
		if status_ui != null: status_ui.failures.erase("Open capture"); status_ui.refresh(), "close")
	open_error.hide()
	details = AcceptDialog.new(); details.title = "Source details"; details.theme = theme; add_child(details)
	detail_text = TextEdit.new(); detail_text.editable = false; detail_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; detail_text.custom_minimum_size = Vector2(480, 220); details.add_child(detail_text)
	details.close_requested.connect(restore_focus); details.confirmed.connect(restore_focus)
	viewer.resize_handle.gui_input.connect(resize_input)
	preload("res://analysis/ui_controls.gd").fit(viewer.inspector_box)
	transport = preload("res://ui/shell/viewer_transport.gd").new()
	add_child(transport); transport.setup(self)
	status_ui = preload("res://ui/shell/viewer_status.gd").new()
	add_child(status_ui); status_ui.setup(self)
	immersive_hint = Label.new()
	immersive_hint.text = "Press Esc to exit fullscreen"
	immersive_hint.theme = theme
	immersive_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	immersive_hint.focus_mode = Control.FOCUS_NONE
	get_parent().add_child(immersive_hint)
	immersive_hint.hide()
	select_workspace(0)
	refresh()
	layout()
	layout.call_deferred()

func icon(id: String) -> Texture2D:
	return load("res://ui/shell/icons/" + id + ".svg")

func button(parent: Node, title: String, action: Callable, icon_id := "") -> Button:
	var control := Button.new(); control.text = title; control.custom_minimum_size.y = 32
	control.tooltip_text = title
	if not icon_id.is_empty(): control.icon = icon(icon_id)
	control.pressed.connect(action); parent.add_child(control)
	return control

func menu(parent: Node, title: String, icon_id: String, entries: Array, action: Callable) -> void:
	var control := MenuButton.new(); control.flat = false; control.text = title; control.icon = icon(icon_id); control.custom_minimum_size.y = 32
	parent.add_child(control); decorate_menu(control); menus[title] = control
	for entry in entries: control.get_popup().add_item(entry)
	control.get_popup().id_pressed.connect(action)

func decorate_menu(control: MenuButton) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = theme.get_stylebox(state, "MenuButton").duplicate()
		style.content_margin_right += 20
		control.add_theme_stylebox_override(state, style)
	var arrow := TextureRect.new(); arrow.texture = preload("res://ui/icons/chevron_down.svg")
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(arrow)
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	arrow.offset_left = -24; arrow.offset_right = -8; arrow.offset_top = -8; arrow.offset_bottom = 8

func select_workspace(index: int) -> void:
	if workspace == 0 and scroll != null: scroll_position = scroll.scroll_vertical
	index = clampi(index,0,WORKSPACES.size()-1)
	workspace = index
	chooser.select(index)
	for i in tab_buttons.size(): tab_buttons[i].theme_type_variation = "SelectedButton" if i == index else "SecondaryButton"
	for child in adapter.get_children(): adapter.remove_child(child); child.queue_free()
	viewer.inspector_box.visible = index == 0
	adapter.visible = index != 0
	if index != 0:
		var note := Label.new(); note.text = "Open a control group in the inspector."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; adapter.add_child(note)
		var targets: Array = [[], ["Rendering", "Color Mapping", "Scene layers"]][index]
		for target in targets:
			if viewer.sections.has(target) or target == "Scene layers": button(adapter, target, show_section.bind(target))
	else: scroll.set_deferred("scroll_vertical", scroll_position)
	refresh()

func show_section(section: String) -> void:
	if viewer.tools_ui.SECTIONS.has(section):
		viewer.tools_ui.open(viewer.tools_ui.SECTIONS[section]); return
	if section == "Scene layers":
		if viewer.scene_layers == null: return
		if not viewer.overlay_visible: viewer._toggle_overlay()
		select_workspace(0)
		await get_tree().process_frame
		scroll.ensure_control_visible(viewer.scene_layers.panel)
		return
	if not viewer.sections.has(section): return
	if not viewer.overlay_visible: viewer._toggle_overlay()
	select_workspace(0)
	viewer.sections[section].show(); viewer.section_buttons[section].set_pressed_no_signal(true)
	await get_tree().process_frame
	scroll.ensure_control_visible(viewer.section_buttons[section])
	viewer.section_buttons[section].grab_focus()

func show_source() -> void:
	show_details("Source details", source_details())

func source_details() -> String:
	if viewer.generic_reader == null: return "No capture loaded."
	var lines := [viewer.capture_path, viewer.hud.text,
		"SIMSCP3 • %d layer samples" % viewer.generic_reader.records.size(), viewer.cache_label.text]
	var layers = viewer.scene_layers
	if layers != null:
		for id in layers.labels:
			var label = layers.labels[id]
			if is_instance_valid(label): lines.append(label.text + "\n" + label.tooltip_text)
		for id in layers.color_controls:
			lines.append(str(id) + " — Color mapping\n" + layers.color_controls[id].status.text)
	else: lines.append(viewer.fields_availability.text)
	lines.append("Current viewer message\n" + viewer.status_label.text)
	return "\n\n".join(lines)

func show_details(title: String, text: String) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	details.title = title; detail_text.text = text; details.popup_centered()

func restore_focus() -> void:
	if previous_focus != null:
		var control = previous_focus.get_ref()
		if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus(); return
	source_button.grab_focus()

func refresh() -> void:
	if immersive: return
	if source_button == null: return
	var loaded: bool = viewer.generic_reader != null
	refresh_commands()
	viewer.tools_ui.refresh_context()
	var title: String = viewer.capture_path.get_file() if loaded else "No capture"
	if source_button.text != title: source_button.text = title; source_button.tooltip_text = viewer.capture_path if loaded else "Source details"
	empty.visible = not loaded and not loading
	viewer.inspector_box.visible = loaded and workspace == 0
	adapter.visible = loaded and workspace != 0
	var fullscreen: bool = not viewer.offline_instance and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_button.visible = fullscreen
	if bar.visible == fullscreen:
		var focused := get_viewport().gui_get_focus_owner()
		var move_focus := fullscreen and focused != null and bar.is_ancestor_of(focused)
		bar.visible = not fullscreen
		# Window configure events can arrive during layout; update after that pass.
		layout.call_deferred()
		if move_focus: fullscreen_button.grab_focus()

func begin_open() -> void:
	loading = true; refresh()

func finish_open(problem: String) -> void:
	loading = false
	preload("res://analysis/ui_controls.gd").fit(viewer.inspector_box)
	if not problem.is_empty():
		error_details = problem; open_error.show()
		if status_ui != null: status_ui.remember("Open capture",problem)
	# A successful open does not silently acknowledge the previous error.
	refresh()

func toggle_dock() -> void:
	if immersive: return
	var focused := get_viewport().gui_get_focus_owner()
	if viewer.overlay_visible:
		if focused != null and dock.is_ancestor_of(focused): previous_focus = weakref(focused)
		requested_dock = false
	else: requested_dock = true
	if auto_collapsed: narrow_open = requested_dock
	viewer.overlay_visible = requested_dock
	layout()
	if viewer.overlay_visible: restore_focus()
	else: recovery.grab_focus()

func resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: viewer.resizing_panel = event.pressed
	if event is InputEventMouseMotion and viewer.resizing_panel:
		viewer.panel_width = clampf(viewer.panel_width - event.relative.x, 320, minf(560, size.x - 650))
		layout()

func layout() -> void:
	if immersive:
		dock.hide(); viewer.resize_handle.hide()
		immersive_hint.position = Vector2((get_viewport().get_visible_rect().size.x - immersive_hint.size.x) / 2, 24)
		return
	if changing_layout or dock == null: return
	changing_layout = true
	var extent := get_viewport().get_visible_rect().size
	size = extent
	var now_compact := extent.x < 1200
	if not has_layout or compact != now_compact: viewer.panel_width = 320 if now_compact else 360
	compact = now_compact; has_layout = true
	bar.position = Vector2.ZERO; bar.size = Vector2(extent.x, 48)
	tabs.visible = not compact; chooser.visible = compact
	# Preserve the root camera projection and export sampling. This is overlay chrome.
	var was_visible: bool = viewer.overlay_visible
	var too_narrow := extent.x < 970
	if not auto_collapsed: requested_dock = viewer.overlay_visible
	if not too_narrow: narrow_open = false
	auto_collapsed = too_narrow
	viewer.overlay_visible = narrow_open if too_narrow else requested_dock
	if was_visible != viewer.overlay_visible: viewer._update_particle_legend()
	var width := clampf(viewer.panel_width, 320, maxf(320, minf(560, extent.x - 650)))
	if too_narrow: width = minf(560, extent.x)
	var top := 48.0 if bar.visible else 0.0
	var status_height: float = status_ui.layout(extent.x,extent.y) if status_ui != null else 0.0
	var bottom: float = extent.y - status_height - (transport.layout(extent.x,extent.y-status_height) if transport != null else 0.0)
	dock.position = Vector2(extent.x-width, top); dock.size = Vector2(width, maxf(0, bottom-top)); dock.visible = viewer.overlay_visible
	viewer.resize_handle.position = Vector2(extent.x-width-8, top); viewer.resize_handle.size = Vector2(8, maxf(0, bottom-top)); viewer.resize_handle.visible = viewer.overlay_visible
	var scene_width := extent.x-width-8 if viewer.overlay_visible else extent.x
	navigation.position = Vector2(12, top+12)
	recovery.position = Vector2(maxf(12, extent.x-recovery.size.x-12), top+12); recovery.visible = not viewer.overlay_visible
	recovery.tooltip_text = "Show panels as a temporary sheet (F1)" if too_narrow else "Show panels (F1)"
	fullscreen_button.position = Vector2(12, top+52)
	empty.position = Vector2(maxf(12, (scene_width-empty.size.x)/2), maxf(152, extent.y/2-40))
	open_error.position = Vector2(12, top+96)
	if viewer.colorbar != null:
		viewer.colorbar.position = Vector2(maxf(12, scene_width-352), bottom-118)
		viewer.legend.position = viewer.colorbar.position+Vector2(0,24)
	refresh()
	changing_layout = false

func enter_immersive() -> void:
	if immersive: return
	immersive_mode = DisplayServer.window_get_mode()
	var focused := get_viewport().gui_get_focus_owner()
	immersive_focus = weakref(focused) if focused != null else null
	if focused != null: focused.release_focus()
	for control in menus.values(): control.get_popup().hide()
	viewer.tools_ui.close(false)
	immersive = true
	immersive_started = Time.get_ticks_msec()
	immersive_native_seen = immersive_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	hide()
	dock.hide()
	viewer.resize_handle.hide()
	if viewer.screenshot_notice != null: viewer.screenshot_notice.hide()
	immersive_hint.show()
	layout()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func exit_immersive(restore_native := true) -> void:
	if not immersive: return
	immersive = false
	immersive_hint.hide()
	if restore_native: DisplayServer.window_set_mode(immersive_mode)
	show()
	refresh()
	layout()
	# Configure events subsequently lay out the restored native window size.
	if immersive_focus != null:
		var focused = immersive_focus.get_ref()
		if is_instance_valid(focused) and focused.is_visible_in_tree(): focused.grab_focus()
	immersive_focus = null

func _process(_delta: float) -> void:
	if not immersive: return
	var elapsed := Time.get_ticks_msec() - immersive_started
	if elapsed >= 3000: immersive_hint.hide()
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		immersive_native_seen = true
	elif immersive_native_seen or elapsed >= 1500:
		# Compositor rejection/external exit: recover chrome without fighting the WM.
		exit_immersive(false)

func export_state() -> Dictionary:
	return {"workspace":workspace,"scroll":scroll.scroll_vertical,"remaining":transport.show_remaining}

func prepare_export(state: Dictionary) -> void:
	# Export settings own visibility; no desktop fullscreen, popup, focus or job state.
	set_process(false); transport.set_process(false); status_ui.set_process(false)
	select_workspace(int(state.get("workspace",0)))
	transport.show_remaining = state.get("remaining",false)
	scroll_position = int(state.get("scroll",0))
	scroll.set_deferred("scroll_vertical",scroll_position)
	refresh_export()

func refresh_export() -> void:
	refresh(); transport.refresh(); status_ui.refresh(); layout()
	visible = viewer.overlay_visible
	# Scientific annotations remain outside the shell, with their existing gates.

func build_menus(row: HBoxContainer) -> void:
	for entry in [["File","open"],["View","view"],["Tools","analysis"],["Help","help"]]:
		menu(row,entry[0],entry[1],[],func(_id):pass)
		menus[entry[0]].about_to_popup.connect(refresh_commands)
	var file: PopupMenu = menus.File.get_popup()
	command(file,"Open capture",viewer._show_open_dialog,"open")
	var state := submenu(file,"State")
	command(state,"Copy state",viewer._copy_inspection_state,"copy")
	for title in ["Save scene","Load scene","Save analysis","Load analysis"]: command(state,title,viewer.tools_ui.open.bind(title),title)
	command(state,"Resolve input",func(): viewer.selection_controller.temporal.durable.choose_input(),"resolve")
	var export_menu := submenu(file,"Export")
	command(export_menu,"Image",viewer.tools_ui.open.bind("Image"),"image")
	command(export_menu,"Video",func():viewer.video_dialog.open(),"video")
	command(export_menu,"Data",viewer.tools_ui.open.bind("Data"),"data")
	var view: PopupMenu = menus.View.get_popup()
	command(view,"Panels",viewer._toggle_overlay,"panels",true)
	command(view,"Fullscreen",viewer._toggle_fullscreen,"fullscreen",true)
	command(view,"Immersive",enter_immersive,"immersive")
	command(view,"Probe marker",func():viewer.scene_layers.set_probe_marker_enabled(not viewer.scene_layers.probe_marker_enabled),"probe",true)
	var guides := submenu(view,"Guides")
	command(guides,"Grid and axes",func():viewer.guide_mesh.visible = not viewer.guide_mesh.visible,"grid",true)
	for pair in [["Domain","domain"],["Data bounds","data"],["Absorber","absorber"],["Imposed regions","imposed"]]:
		command(guides,pair[0],toggle_guide.bind(pair[1]),"guide:"+pair[1],true)
	var presets := submenu(view,"Viewing preset")
	for title in viewer.VIEWING_PRESETS: command(presets,"Minimal" if title == "Minimal / Presentation" else title,viewer._apply_preset.bind(title),"preset:"+title,true)
	var tools: PopupMenu = menus.Tools.get_popup()
	command(tools,"Selection",viewer.tools_ui.open.bind("Selection"),"tool:Selection")
	var analysis := submenu(tools,"Analysis")
	for title in ["Temporal","Space time","Diagnostics","Compare","Matched runs","Period","Bookmarks","Results"]: command(analysis,title,viewer.tools_ui.open.bind(title),"tool:"+title)
	for title in ["Mapping","Quick setup","Derive range","Slice","Clipping","Isosurface","Source probe","Performance","Geometry"]: command(tools,title,viewer.tools_ui.open.bind(title),"tool:"+title)
	var help: PopupMenu = menus.Help.get_popup()
	command(help,"Shortcuts",func():show_details("Shortcuts","Drag to orbit. Scroll to zoom.\nF: Frame scene   R: Reset camera\nO: Auto orbit   F1: Panels   F11: Fullscreen\nShift+F11: Immersive   Esc: Restore preceding shell\nSpace: Play or pause   Left and Right: Step sample\n\nTab and Shift+Tab move focus. Enter or Space activates buttons.\n\nMidnight Scientific"),"shortcuts")
	command(help,"Handbook",func():
		var path := ProjectSettings.globalize_path("res://../docs/SIMSCOPE_HANDBOOK.md")
		show_details("Handbook",FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "Handbook unavailable in this installation."),"handbook")

func submenu(parent: PopupMenu, title: String) -> PopupMenu:
	var popup := PopupMenu.new(); popup.name = title.replace(" ",""); parent.add_child(popup)
	parent.add_submenu_item(title,popup.name)
	return popup

func command(popup: PopupMenu, title: String, action: Callable, key: String, checked := false) -> void:
	var id := popup.item_count
	if checked: popup.add_check_item(title,id)
	else: popup.add_item(title,id)
	popup.id_pressed.connect(func(chosen):
		if chosen == id and not popup.is_item_disabled(id): action.call())
	commands[key] = {"popup":popup,"index":id}

func toggle_guide(key: String) -> void:
	viewer.guide_visibility[key] = not viewer.guide_visibility[key]; viewer._apply_geometry()

func refresh_commands() -> void:
	var loaded: bool = viewer.generic_reader != null
	var fields := false
	if loaded:
		for obj in viewer.generic_reader.objects.values():
			if obj.kind == "volume": fields = true
	var particles: bool = loaded and viewer.scene_layers != null and not viewer.scene_layers.particle_id.is_empty()
	for key in commands:
		var entry: Dictionary = commands[key]
		var enabled: bool = loaded or key in ["open","panels","fullscreen","immersive","shortcuts","handbook"]
		if key in ["probe","tool:Quick setup","tool:Clipping","tool:Isosurface","tool:Source probe"]: enabled = fields
		if key == "tool:Mapping": enabled = particles
		if key in ["tool:Slice","tool:Derive range"]: enabled = fields or particles
		if key == "resolve":
			var jobs = viewer.selection_controller.jobs
			enabled = loaded and jobs.background_operation == "load_recipe" and jobs.background_scene == viewer.capture_generation and jobs.background_error_code == "unopened_source"
		if key.begins_with("preset:"): enabled = loaded and viewer.preset_available.get(key.trim_prefix("preset:"),true)
		entry.popup.set_item_disabled(entry.index,not enabled)
		entry.popup.set_item_tooltip(entry.index,"" if enabled else ("Open a compatible capture first" if not loaded else "Unavailable for the current source or state"))
		var checked := false
		if key == "panels": checked = viewer.overlay_visible
		elif key == "fullscreen": checked = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		elif key == "probe": checked = fields and viewer.scene_layers.probe_marker_enabled
		elif key == "grid": checked = viewer.guide_mesh.visible
		elif key.begins_with("guide:"):
			var guide: String = key.trim_prefix("guide:")
			checked = viewer.guide_visibility[guide]
			var metadata_key: String = "imposed_regions" if guide == "imposed" else guide
			entry.popup.set_item_disabled(entry.index,not loaded or (guide != "data" and not viewer.geometry_metadata.has(metadata_key)))
		elif key.begins_with("preset:"): checked = viewer.selected_preset == key.trim_prefix("preset:")
		if entry.popup.is_item_checkable(entry.index): entry.popup.set_item_checked(entry.index,checked)
