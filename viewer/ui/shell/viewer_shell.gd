extends Control
## Presentation-only adapter. Controllers and the root scientific viewport retain ownership.
const ThemeSource = preload("res://ui/theme/simscope_theme.gd")
const WORKSPACES = ["Scene", "Appearance", "Selection", "Analysis"]
var viewer
var bar: PanelContainer
var dock: PanelContainer
var scroll: ScrollContainer
var tabs: GridContainer
var chooser: OptionButton
var context_title: Label
var context_detail: Label
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
var loading := false
var previous_focus: WeakRef
var compact := false
var has_layout := false
var scroll_position := 0
var requested_dock := true
var auto_collapsed := false
var changing_layout := false
var narrow_open := false

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
	button(row, "Open…", viewer._show_open_dialog, "open").theme_type_variation = "PrimaryButton"
	source_button = button(row, "No capture", show_source, "info")
	source_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_button.clip_text = true; source_button.custom_minimum_size.x = 80
	menu(row, "State", "state", ["Scene recipe controls…", "Analysis recipe controls…"], func(id):
		show_section("Capture / Export" if id == 0 else "Analysis export and state"))
	menu(row, "Export", "export", ["Save PNG…", "Export video…", "Numerical export controls…"], func(id):
		match id:
			0: viewer._save_image()
			1: viewer.video_dialog.open()
			2: show_section("Analysis export and state")
	)
	menu(row, "View", "view", ["Show or hide panels", "Fullscreen", "Frame scene", "Reset camera"], func(id):
		match id:
			0: viewer._toggle_overlay()
			1: viewer._toggle_fullscreen()
			2: viewer._focus_activity()
			3: viewer._reset_camera()
	)
	menu(row, "Help", "help", ["Navigation help…", "Source details…"], func(id):
		if id == 1: show_source()
		else: show_details("Navigation help", "Drag to orbit. Scroll to zoom.\nF: Frame scene   R: Reset camera\nO: Auto orbit   F1: Show or hide panels   F11: Fullscreen\nSpace: Play or pause   Left / Right: Step sample\n\nTab and Shift+Tab move focus. Enter or Space activates buttons.\nScientific controls remain in the existing inspector during shell migration.\n\nMidnight Scientific"))
	dock = viewer.overlay_panel
	dock.remove_theme_stylebox_override("panel")
	dock.theme = theme
	dock.theme_type_variation = "PropertyGroup"
	scroll = viewer.inspector_box.get_parent()
	dock.remove_child(scroll)
	var dock_box := VBoxContainer.new(); dock.add_child(dock_box)
	var header := HBoxContainer.new(); dock_box.add_child(header)
	var title := Label.new(); title.text = "Workspace"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	button(header, "Hide", viewer._toggle_overlay, "close")
	tabs = GridContainer.new(); tabs.columns = 2; dock_box.add_child(tabs)
	chooser = OptionButton.new(); chooser.custom_minimum_size.y = 32; dock_box.add_child(chooser)
	for i in WORKSPACES.size():
		var tab := button(tabs, WORKSPACES[i], select_workspace.bind(i), ["scene", "appearance", "selection", "analysis"][i])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tab_buttons.append(tab)
		chooser.add_item(WORKSPACES[i])
	chooser.item_selected.connect(select_workspace)
	context_title = Label.new(); context_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; context_title.theme_type_variation = "SectionTitle"; dock_box.add_child(context_title)
	context_detail = Label.new(); context_detail.text = "Current capture"; context_detail.theme_type_variation = "SecondaryLabel"; dock_box.add_child(context_detail)
	dock_box.add_child(scroll); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	adapter = VBoxContainer.new(); adapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# All retained controls stay in their original VBox and retain serialized section keys.
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.remove_child(viewer.inspector_box); scroll.add_child(content)
	content.add_child(adapter); content.add_child(viewer.inspector_box)
	viewer.show_panel_button.hide()
	recovery = button(self, "Show panels", viewer._toggle_overlay, "view")
	navigation = HBoxContainer.new(); add_child(navigation)
	button(navigation, "Frame scene", viewer._focus_activity, "frame")
	button(navigation, "Reset camera", viewer._reset_camera, "reset")
	var navigate := MenuButton.new(); navigate.flat = false; navigate.text = "Navigate"; navigate.custom_minimum_size.y = 32; navigation.add_child(navigate); decorate_menu(navigate)
	var modes := navigate.get_popup(); modes.add_check_item("Free camera"); modes.add_check_item("Auto orbit")
	navigate.about_to_popup.connect(func(): modes.set_item_checked(0, viewer.free_camera); modes.set_item_checked(1, viewer.orbit_enabled))
	modes.id_pressed.connect(func(id):
		if id == 0:
			viewer.control_checks["Free camera • WASD / Q / E"].button_pressed = not viewer.free_camera
		else: viewer.orbit_enabled = not viewer.orbit_enabled; viewer.inspection_paused = false
		viewer._sync_control_state())
	fullscreen_button = button(self, "Exit fullscreen", viewer._toggle_fullscreen, "view")
	empty = VBoxContainer.new(); add_child(empty)
	var welcome := Label.new(); welcome.text = "Open a capture to begin"; empty.add_child(welcome)
	button(empty, "Open capture…", viewer._show_open_dialog, "open").theme_type_variation = "PrimaryButton"
	open_error = PanelContainer.new(); add_child(open_error)
	var error_row := HBoxContainer.new(); open_error.add_child(error_row)
	error_text = Label.new(); error_text.text = "Capture could not be opened"; error_text.add_theme_color_override("font_color", theme.c(&"state.error")); error_row.add_child(error_text)
	button(error_row, "Details…", func(): show_details("Open failed", error_details), "warning")
	button(error_row, "Choose another…", viewer._show_open_dialog, "open")
	button(error_row, "Dismiss", func(): open_error.hide(), "close")
	open_error.hide()
	details = AcceptDialog.new(); details.title = "Source details"; details.theme = theme; add_child(details)
	detail_text = TextEdit.new(); detail_text.editable = false; detail_text.custom_minimum_size = Vector2(480, 220); details.add_child(detail_text)
	details.close_requested.connect(restore_focus); details.confirmed.connect(restore_focus)
	viewer.resize_handle.gui_input.connect(resize_input)
	preload("res://analysis/ui_controls.gd").fit(viewer.inspector_box)
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
	workspace = index
	chooser.select(index)
	for i in tab_buttons.size(): tab_buttons[i].theme_type_variation = "SelectedButton" if i == index else "SecondaryButton"
	for child in adapter.get_children(): adapter.remove_child(child); child.queue_free()
	viewer.inspector_box.visible = index == 0
	adapter.visible = index != 0
	if index != 0:
		var note := Label.new(); note.text = "Open a control group in the inspector."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; adapter.add_child(note)
		var targets: Array = [[], ["Rendering", "Color Mapping", "Camera", "Scene layers"], ["Selections"], ["Temporal analysis", "Space-time analysis", "Diagnostics and comparisons", "Matched runs", "Analysis export and state"]][index]
		for target in targets:
			if viewer.sections.has(target) or target == "Scene layers": button(adapter, target, show_section.bind(target))
	else: scroll.set_deferred("scroll_vertical", scroll_position)
	refresh()

func show_section(section: String) -> void:
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
	show_details("Source details", "No capture loaded." if viewer.generic_reader == null else viewer.capture_path + "\n\n" + viewer.hud.text + "\n\n" + viewer.status_label.text)

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
	if source_button == null: return
	var loaded: bool = viewer.generic_reader != null
	for menu_name in ["State", "Export"]:
		menus[menu_name].disabled = not loaded
		menus[menu_name].tooltip_text = menu_name if loaded else "Open a capture first"
	var title: String = viewer.capture_path.get_file() if loaded else "No capture"
	if source_button.text != title: source_button.text = title; source_button.tooltip_text = viewer.capture_path if loaded else "Source details"
	context_title.text = title
	# Context is capture-level until UX4 supplies selected-object adapters. No implicit binding.
	var availability := "Current capture" if loaded else "No capture loaded"
	if loading: availability = "Opening capture…"
	elif loaded and viewer.scene_layers != null and viewer.scene_layers.is_buffering(): availability = "Preparing sample…"
	elif loaded and viewer.frame_count == 0: availability = "Waiting for a complete sample"
	context_detail.text = availability
	empty.visible = not loaded and not loading
	viewer.inspector_box.visible = loaded and workspace == 0
	adapter.visible = loaded and workspace != 0
	fullscreen_button.visible = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func begin_open() -> void:
	loading = true; refresh()

func finish_open(problem: String) -> void:
	loading = false
	preload("res://analysis/ui_controls.gd").fit(viewer.inspector_box)
	if not problem.is_empty(): error_details = problem; open_error.show()
	# A successful open does not silently acknowledge the previous error.
	refresh()

func toggle_dock() -> void:
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
	dock.position = Vector2(extent.x-width, 48); dock.size = Vector2(width, maxf(0, extent.y-48)); dock.visible = viewer.overlay_visible
	viewer.resize_handle.position = Vector2(extent.x-width-8, 48); viewer.resize_handle.size = Vector2(8, maxf(0, extent.y-48)); viewer.resize_handle.visible = viewer.overlay_visible
	viewer.show_panel_button.hide()
	var scene_width := extent.x-width-8 if viewer.overlay_visible else extent.x
	navigation.position = Vector2(12, 60)
	recovery.position = Vector2(maxf(12, extent.x-recovery.size.x-12), 60); recovery.visible = not viewer.overlay_visible
	recovery.tooltip_text = "Show panels as a temporary sheet (F1)" if too_narrow else "Show panels (F1)"
	fullscreen_button.position = Vector2(12, 100)
	empty.position = Vector2(maxf(12, (scene_width-empty.size.x)/2), maxf(152, extent.y/2-40))
	open_error.position = Vector2(12, 144)
	if viewer.colorbar != null:
		viewer.colorbar.position = Vector2(maxf(12, scene_width-352), extent.y-118)
		viewer.legend.position = viewer.colorbar.position+Vector2(0,24)
	refresh()
	changing_layout = false
