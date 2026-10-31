extends Control
## Presentation-only adapter. Controllers and the root scientific viewport retain ownership.
const ThemeSource = preload("res://ui/theme/wavez_theme.gd")
const About = preload("res://ui/about/about_dialog.gd")
const ResizeProfile = preload("res://ui/shell/resize_profile.gd")
const WORKSPACES = ["Particles", "Fields", "Meshes"]
var viewer
var orbit_editor
var shortcuts := preload("res://ui/keyboard_shortcuts.gd").new()
var shortcuts_editor
var file_locations_dialog
var shortcut_hints_map := {}

func edit_shortcuts() -> void:
	if viewer.offline_instance: return
	viewer._clear_manual_navigation()
	if shortcuts_editor == null:
		var canvas := CanvasLayer.new(); canvas.layer = 20; add_child(canvas)
		shortcuts_editor = preload("res://ui/shell/keyboard_shortcuts_editor.gd").new()
		canvas.add_child(shortcuts_editor); shortcuts_editor.setup(self)
	if focus_navigation != null: focus_navigation.begin_overlay(shortcuts_editor)
	shortcuts_editor.open()

func edit_file_locations() -> void:
	if viewer.offline_instance: return
	viewer._clear_manual_navigation()
	if file_locations_dialog == null:
		file_locations_dialog = preload("res://ui/shell/file_locations_dialog.gd").new()
		add_child(file_locations_dialog)
		file_locations_dialog.setup(self)
	file_locations_dialog.open()

func editing_shortcuts() -> bool:
	return shortcuts_editor != null and shortcuts_editor.visible

func invoke_shortcut_command(key: String) -> void:
	viewer._clear_manual_navigation()
	refresh_commands()
	var entry: Dictionary = commands[key]
	if not entry.popup.is_item_disabled(entry.index): entry.popup.id_pressed.emit(entry.index)

func cycle_category(direction: int) -> void:
	select_workspace(posmod(workspace + direction, WORKSPACES.size()))

func shortcut_context(action: String) -> String:
	var menu_keys := {"export_video":"video", "mapping":"tool:Mapping", "derive_range":"tool:Derive range"}
	if menu_keys.has(action):
		var entry: Dictionary = commands[menu_keys[action]]
		if entry.popup.is_item_disabled(entry.index): return entry.popup.get_item_tooltip(entry.index)
	if viewer.generic_reader == null and action in ["frame_scene","play_pause","previous_sample","next_sample","loop_playback","recorded_history"]:
		return "Open a capture to use this action."
	if action == "recorded_history" and not viewer._has_particle_ids(): return "Recorded history requires recorded particle IDs."
	return ""

func refresh_shortcut_hints() -> void:
	if navigation == null: return
	if shortcut_hints_map == shortcuts.active: return
	shortcut_hints_map = shortcuts.active.duplicate()
	navigation.get_child(0).tooltip_text = "Frame scene" + shortcuts.hint("frame_scene")
	navigation.get_child(1).tooltip_text = "Reset camera" + shortcuts.hint("reset_camera")
	navigation.get_child(2).tooltip_text = "Navigate" + shortcuts.hint("navigate") + " · Right-drag to steer; orbit keys in Keyboard Shortcuts"
	for pair in [["fullscreen","fullscreen"],["open","open_capture"],["video","export_video"],["tool:Mapping","mapping"],["tool:Derive range","derive_range"]]:
		var entry: Dictionary = commands[pair[0]]
		var shortcut := Shortcut.new()
		if shortcuts.active[pair[1]] != 0: shortcut.events = [shortcuts.event_for(pair[1])]
		# Display only: the viewer owns dispatch and its focus/busy guards.
		entry.popup.set_item_shortcut(entry.index, shortcut)
		entry.popup.set_item_shortcut_disabled(entry.index, true)
	if transport != null:
		transport.loop.tooltip_text = "Loop recorded interval" + shortcuts.hint("loop_playback")
		viewer.play_button.tooltip_text = "Play or pause" + shortcuts.hint("play_pause")
	for pair in [["Auto orbit  [O]","Auto orbit","auto_orbit"],["Recorded history  [T]","Recorded history","recorded_history"]]:
		if viewer.control_checks.has(pair[0]): viewer.control_checks[pair[0]].text = pair[1] + shortcuts.hint(pair[2])

func edit_orbit_center() -> void:
	if viewer.offline_instance or viewer.inspection_busy: return
	viewer._clear_manual_navigation()
	if orbit_editor == null:
		orbit_editor = preload("res://ui/shell/orbit_center_editor.gd").new()
		add_child(orbit_editor); orbit_editor.setup(viewer)
	if focus_navigation != null: focus_navigation.begin_overlay(orbit_editor)
	orbit_editor.open()

func dismiss_orbit_editor() -> void:
	if orbit_editor != null: orbit_editor.dismiss()

var legend_available := Vector2.ZERO
var layer_legends
var particle_legend_panel: Panel
var transport
var status_ui
var title_drag: Control
var window_chrome
var bar: PanelContainer
var dock: PanelContainer
var scroll: ScrollContainer
var tabs: GridContainer
var chooser: OptionButton
var navigation: HBoxContainer
var edge_reveal
var bottom_strip: Control
var empty: VBoxContainer
var open_error: PanelContainer
var error_text: Label
var error_details := ""
var details: AcceptDialog
var detail_text: TextEdit
var detail_heading: Label
var detail_close: Button
var detail_failure_action: Button
var about: AcceptDialog
var particle_empty: Label
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
var changing_layout := false
var layout_queued := false
# Session-only presentation state; never change serialized scientific visibility.
var immersive := false
var immersive_hint: Label
var immersive_started := 0
var immersive_native_seen := false
var immersive_mode := DisplayServer.WINDOW_MODE_WINDOWED
var immersive_focus: WeakRef
var immersive_edges := {}
var immersive_chrome := {}
var style_slice
var focus_navigation
var appearance

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
	title_drag = Control.new(); title_drag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_drag.tooltip_text = "Drag to move window · Double-click to maximize/restore"; row.add_child(title_drag)
	edge_reveal = preload("res://ui/shell/edge_reveal.gd").new()
	add_child(edge_reveal); edge_reveal.shell = self
	build_menus(row)
	edge_reveal.add_pin(row, "top")
	dock = viewer.overlay_panel
	dock.theme = theme
	dock.theme_type_variation = "PropertyGroup"
	scroll = viewer.inspector_box.get_parent()
	dock.remove_child(scroll)
	var dock_box := VBoxContainer.new(); dock.add_child(dock_box)
	var header := HBoxContainer.new(); dock_box.add_child(header)
	var title := Label.new(); title.text = "Simulation"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	edge_reveal.add_pin(header, "right")
	tabs = GridContainer.new(); tabs.columns = 3; dock_box.add_child(tabs)
	chooser = OptionButton.new(); chooser.custom_minimum_size.y = 32; dock_box.add_child(chooser)
	for i in WORKSPACES.size():
		var tab := button(tabs, WORKSPACES[i], select_workspace.bind(i))
		tab.tooltip_text = ""
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tab_buttons.append(tab)
		chooser.add_item(WORKSPACES[i])
	chooser.item_selected.connect(select_workspace)
	dock_box.add_child(scroll); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	adapter = VBoxContainer.new(); adapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# All retained controls stay in their original VBox and retain serialized section keys.
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.remove_child(viewer.inspector_box); scroll.add_child(content)
	content.add_child(adapter); content.add_child(viewer.inspector_box)
	particle_empty = Label.new();particle_empty.text = "No particles";content.add_child(particle_empty)
	navigation = HBoxContainer.new(); row.add_child(navigation)
	row.move_child(navigation, 0)
	var frame_action := button(navigation, "", viewer._focus_activity, "frame"); frame_action.tooltip_text = "Frame scene [F]"
	var reset_action := button(navigation, "", viewer._reset_camera, "reset"); reset_action.tooltip_text = "Reset camera [R]"
	var navigate := MenuButton.new(); navigate.flat = false; navigate.icon = icon("view"); navigate.tooltip_text = "Navigate [Alt+N] · Right-drag to steer; orbit keys in Keyboard Shortcuts"; navigate.custom_minimum_size.y = 32; navigation.add_child(navigate); decorate_menu(navigate)
	var modes := navigate.get_popup(); modes.add_check_item("Free camera"); modes.add_check_item("Auto orbit"); modes.add_item("Orbit speed"); modes.add_item("Edit orbit center…")
	navigate.about_to_popup.connect(func(): viewer._clear_manual_navigation(); modes.set_item_checked(0, viewer.free_camera); modes.set_item_checked(1, viewer.orbit_enabled))
	navigate.about_to_popup.connect(func():
		if viewer.session_log != null: viewer.session_log.record("MENU", "Navigate opened"))
	modes.id_pressed.connect(func(id):
		if id == 0: viewer._toggle_free_camera()
		elif id == 1: viewer._toggle_auto_orbit()
		elif id == 2: viewer.tools_ui.open("Camera")
		else: edit_orbit_center()
		viewer._sync_control_state())
	window_chrome = preload("res://ui/shell/window_chrome.gd").new(); add_child(window_chrome); window_chrome.setup(self, row)
	empty = VBoxContainer.new(); add_child(empty)
	button(empty, "Open File", viewer._show_open_dialog, "open").theme_type_variation = "PrimaryButton"
	open_error = PanelContainer.new(); add_child(open_error)
	var error_row := HBoxContainer.new(); open_error.add_child(error_row)
	error_text = Label.new(); error_text.text = "File could not be opened"; error_text.add_theme_color_override("font_color", theme.c(&"state.error")); error_row.add_child(error_text)
	button(error_row, "Details…", func(): show_details("Open failed", error_details), "warning")
	button(error_row, "Choose another…", viewer._show_open_dialog, "open")
	button(error_row, "Dismiss", func():
		open_error.hide()
		if status_ui != null: status_ui.failures.erase("Open file"); status_ui.refresh(), "close")
	open_error.hide()
	details = AcceptDialog.new(); details.title = "Source details"; details.borderless = true; add_child(details)
	var detail_body := VBoxContainer.new(); detail_body.add_theme_constant_override("separation",8); details.add_child(detail_body)
	var detail_header := HBoxContainer.new(); detail_body.add_child(detail_header)
	detail_heading = Label.new(); detail_heading.theme_type_variation = "PanelTitle"; detail_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE; detail_header.add_child(detail_heading)
	detail_close = close_action(detail_header, func(): details.hide(); restore_focus(), "Close details")
	detail_header.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not details.is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
			DisplayServer.window_start_drag(details.get_window_id()))
	detail_text = TextEdit.new(); detail_text.editable = false; detail_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; detail_text.custom_minimum_size = Vector2(480, 220); detail_body.add_child(detail_text)
	details.get_ok_button().hide()
	var detail_actions := HBoxContainer.new(); detail_actions.alignment = BoxContainer.ALIGNMENT_END; detail_body.add_child(detail_actions)
	detail_failure_action = Button.new(); detail_failure_action.text = "Acknowledge failures"; detail_failure_action.theme_type_variation = "SecondaryButton"
	detail_failure_action.tooltip_text = "Dismiss retained failure notices after reviewing them; jobs and results remain unchanged"
	detail_failure_action.hide(); detail_actions.add_child(detail_failure_action)
	var detail_done := Button.new(); detail_done.text = "Close"; detail_done.theme_type_variation = "SecondaryButton"
	detail_done.pressed.connect(func(): details.hide(); restore_focus()); detail_actions.add_child(detail_done)
	details.close_requested.connect(restore_focus); details.confirmed.connect(restore_focus)
	about = About.new(); about.theme = theme; add_child(about)
	about.close_requested.connect(restore_focus); about.confirmed.connect(restore_focus)
	viewer.resize_handle.gui_input.connect(resize_input)
	preload("res://analysis/ui_controls.gd").fit(viewer.inspector_box)
	transport = preload("res://ui/shell/viewer_transport.gd").new()
	add_child(transport); transport.setup(self)
	status_ui = preload("res://ui/shell/viewer_status.gd").new()
	add_child(status_ui); status_ui.setup(self)
	bottom_strip = Control.new(); bottom_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bottom_strip)
	transport.reparent(bottom_strip); status_ui.reparent(bottom_strip)
	edge_reveal.add_pin(transport.options, "bottom")
	immersive_hint = Label.new()
	immersive_hint.text = "Press Esc to exit fullscreen"
	immersive_hint.theme = theme
	immersive_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	immersive_hint.focus_mode = Control.FOCUS_NONE
	get_parent().add_child(immersive_hint)
	immersive_hint.hide()
	particle_legend_panel = Panel.new()
	particle_legend_panel.add_theme_stylebox_override("panel", theme.box(&"surface.1", &"border.subtle", 8, 6))
	particle_legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(particle_legend_panel)
	get_parent().move_child(particle_legend_panel, viewer.colorbar.get_index())
	viewer.legend.resized.connect(reposition_legend)
	viewer.legend.theme = theme
	viewer.legend.visibility_changed.connect(reposition_legend)
	layer_legends = preload("res://ui/shell/layer_legends.gd").new()
	get_parent().add_child(layer_legends); layer_legends.setup(viewer)
	style_slice = preload("res://ui/shell/violet_style_slice.gd").new()
	style_slice.install(self)
	if not viewer.offline_instance:
		var error: Error = shortcuts.load_preferences()
		if error != OK: push_warning("Could not load keyboard shortcuts: " + error_string(error))
	refresh_shortcut_hints()
	window_chrome.refresh()
	select_workspace(0)
	refresh()
	layout()
	layout.call_deferred()
	if not viewer.offline_instance:
		focus_navigation = preload("res://ui/shell/focus_navigation.gd").new()
		add_child(focus_navigation); focus_navigation.setup(self)
		appearance = preload("res://ui/theme/application_theme.gd").new()
		add_child(appearance); appearance.setup(self)

func icon(id: String) -> Texture2D:
	return load("res://ui/shell/icons/" + id + ".svg")

func button(parent: Node, title: String, action: Callable, icon_id := "") -> Button:
	var control := Button.new(); control.text = title; control.custom_minimum_size.y = 32
	control.tooltip_text = title
	if not icon_id.is_empty(): control.icon = icon(icon_id)
	control.pressed.connect(action); parent.add_child(control)
	return control

func close_action(parent: Node, action: Callable, tooltip: String) -> Button:
	var control := button(parent, "", action, "close")
	control.custom_minimum_size = Vector2(32, 32)
	control.theme_type_variation = "IconAction"; control.tooltip_text = tooltip
	control.set_meta("shell_close", true)
	if style_slice != null:
		style_slice.style_close_action(control)
	return control

func menu(parent: Node, title: String, icon_id: String, entries: Array, action: Callable) -> void:
	var control := MenuButton.new(); control.flat = false; control.text = title; control.icon = icon(icon_id); control.custom_minimum_size.y = 32
	parent.add_child(control); decorate_menu(control); menus[title] = control
	control.about_to_popup.connect(viewer._clear_manual_navigation)
	control.about_to_popup.connect(func():
		if viewer.session_log != null: viewer.session_log.record("MENU", title + " opened"))
	for entry in entries: control.get_popup().add_item(entry)
	control.get_popup().id_pressed.connect(action)

func decorate_menu(control: MenuButton) -> void:
	control.focus_mode = Control.FOCUS_ALL
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBox = theme.get_stylebox(state, "MenuButton").duplicate()
		style.content_margin_right += 20
		control.add_theme_stylebox_override(state, style)
	var arrow := TextureRect.new(); arrow.texture = preload("res://ui/icons/chevron_down.svg")
	arrow.set_meta("chrome_icon", "chevron_down")
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(arrow)
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	arrow.offset_left = -24; arrow.offset_right = -8; arrow.offset_top = -8; arrow.offset_bottom = 8

func select_workspace(index: int) -> void:
	if workspace == 0 and scroll != null: scroll_position = scroll.scroll_vertical
	index = clampi(index,0,WORKSPACES.size()-1)
	if index != workspace and viewer.session_log != null: viewer.session_log.record("UI", "Simulation category = " + WORKSPACES[index])
	workspace = index
	chooser.select(index)
	for i in tab_buttons.size(): tab_buttons[i].theme_type_variation = "SelectedButton" if i == index else "SecondaryButton"
	viewer.inspector_box.visible = index == 0
	adapter.visible = index != 0
	if viewer.scene_layers != null: viewer.scene_layers.show_category(index)
	scroll.set_deferred("scroll_vertical",scroll_position if index == 0 else 0)
	refresh()

func select_initial_scene_category() -> void:
	# A successful interactive load chooses from declared source kinds, regardless
	# of the previous tab or current visibility. Export workers retain their
	# explicit presentation state.
	if viewer.offline_instance or viewer.generic_reader == null: return
	var objects: Dictionary = viewer.generic_reader.objects
	var kinds := {}
	for object in objects.values():
		kinds[object.kind] = true
	for kind in ["particles", "volume", "mesh"]:
		if kinds.has(kind):
			select_workspace(["particles", "volume", "mesh"].find(kind))
			return

func show_section(section: String) -> void:
	if viewer.tools_ui.SECTIONS.has(section):
		viewer.tools_ui.open(viewer.tools_ui.SECTIONS[section]); return
	if section == "Scene layers":
		if viewer.scene_layers == null: return
		if not viewer.overlay_visible: viewer._toggle_overlay()
		select_workspace(1)
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
		"WVZ1 • %d layer samples" % viewer.generic_reader.records.size(), viewer.cache_label.text]
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

func show_details(title: String, text: String, show_failure_action := false) -> void:
	viewer._cursor_idle_reset()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	details.theme = style_slice.theme
	detail_close.icon = style_slice.theme.chrome_icon("close")
	details.title = title; detail_heading.text = title; detail_text.text = text
	detail_failure_action.visible = show_failure_action
	var available := get_viewport().get_visible_rect().size - Vector2(32,32)
	details.popup_centered(Vector2i(Vector2(560,360).min(available)))

func restore_focus() -> void:
	if previous_focus != null:
		var control = previous_focus.get_ref()
		if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus(); return
	if navigation.get_child(0).is_visible_in_tree(): navigation.get_child(0).grab_focus()

func refresh() -> void:
	if menus.is_empty(): return
	var profile_started := ResizeProfile.stamp()
	var loaded: bool = viewer.generic_reader != null
	refresh_commands()
	refresh_shortcut_hints()
	viewer.tools_ui.refresh_context()
	empty.visible = not immersive and not loaded and not loading
	var has_particles: bool = loaded and viewer.scene_layers != null and not viewer.scene_layers.particle_id.is_empty()
	viewer.inspector_box.visible = has_particles and workspace == 0
	particle_empty.visible = loaded and workspace == 0 and not has_particles
	adapter.visible = loaded and workspace != 0
	if viewer.scene_layers != null: viewer.scene_layers.show_category(workspace)
	ResizeProfile.record("shell_refresh", profile_started)

func begin_open() -> void:
	loading = true; refresh()

func finish_open(problem: String) -> void:
	loading = false
	preload("res://analysis/ui_controls.gd").fit(viewer.inspector_box)
	if not problem.is_empty():
		error_details = problem; open_error.show()
		if status_ui != null: status_ui.remember("Open file",problem)
	else:
		# Only the failed-open diagnostic is superseded by a successful load.
		error_details = ""; open_error.hide()
		if status_ui != null: status_ui.failures.erase("Open file")
	if status_ui != null: status_ui.refresh()
	refresh()

func toggle_dock() -> void:
	if immersive: return
	# Retained internal presentation callers; public visibility lives on the pin.
	edge_reveal.set_pinned("right", not dock.visible)
	if not edge_reveal.states.right.pinned: edge_reveal.states.right.visible = false
	layout()

func resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: viewer.resizing_panel = event.pressed
	if event is InputEventMouseMotion and viewer.resizing_panel:
		viewer.panel_width = clampf(viewer.panel_width - event.relative.x, 320, minf(560, size.x - 650))
		layout()

func request_layout() -> void:
	# A native drag can deliver hundreds of sizes between drawn frames. Use
	# the latest viewport size once per frame, including after the last event.
	if layout_queued: return
	layout_queued = true
	_flush_requested_layout.call_deferred()

func _flush_requested_layout() -> void:
	if not layout_queued: return
	layout_queued = false
	layout()

func layout() -> void:
	if changing_layout or dock == null: return
	layout_queued = false
	var profile_started := ResizeProfile.stamp()
	changing_layout = true
	var extent := get_viewport().get_visible_rect().size
	size = extent
	var now_compact := extent.x < 1200
	if not has_layout or compact != now_compact: viewer.panel_width = 320 if now_compact else 360
	compact = now_compact; has_layout = true
	bar.position = Vector2.ZERO; bar.size = Vector2(extent.x, 48)
	tabs.visible = not compact; chooser.visible = compact
	# Preserve the root camera projection and export sampling. This is overlay chrome.
	var too_narrow := extent.x < 970
	if not viewer.offline_instance and not immersive: viewer.overlay_visible = edge_reveal.states.right.visible
	# The offline SubViewport is the video frame. Keep its scientific legends,
	# but never reserve or render space for application controls.
	var dock_visible: bool = false if viewer.offline_instance else edge_reveal.states.right.visible
	bar.visible = not viewer.offline_instance and edge_reveal.states.top.visible
	bottom_strip.visible = not viewer.offline_instance and edge_reveal.states.bottom.visible
	var width := clampf(viewer.panel_width, 320, maxf(320, minf(560, extent.x - 650)))
	if too_narrow: width = minf(560, extent.x)
	var top := 48.0 if bar.visible else 0.0
	var status_height: float = status_ui.layout(extent.x,extent.y) if bottom_strip.visible else 0.0
	var bottom: float = extent.y - status_height - (transport.layout(extent.x,extent.y-status_height) if bottom_strip.visible else 0.0)
	dock.position = Vector2(extent.x-width, top); dock.size = Vector2(width, maxf(0, bottom-top)); dock.visible = dock_visible
	viewer.resize_handle.position = Vector2(extent.x-width-8, top); viewer.resize_handle.size = Vector2(8, maxf(0, bottom-top)); viewer.resize_handle.visible = dock_visible
	var scene_width := extent.x-width-8 if dock_visible else extent.x
	empty.position = Vector2(maxf(12, (scene_width-empty.size.x)/2), maxf(top+12, top+(bottom-top-empty.size.y)/2))
	open_error.position = Vector2(12, top+96)
	layout_legend(Vector2(dock.position.x if dock_visible else extent.x, bottom))
	if window_chrome != null: window_chrome.refresh()
	refresh()
	changing_layout = false
	ResizeProfile.record("shell_layout_inclusive", profile_started)

func layout_legend(available: Vector2) -> void:
	if viewer.colorbar == null or viewer.legend == null: return
	legend_available = available
	var width := minf(preload("res://ui/shell/legend_text.gd").WIDTH,maxf(0,available.x-40))
	viewer.legend.size.x = width
	viewer.colorbar.size.x = width
	viewer.legend.size.y = viewer.legend.get_minimum_size().y
	reposition_legend()

func reposition_legend() -> void:
	# Text shaping can grow the label after layout; move only the scientific overlay.
	if legend_available == Vector2.ZERO: return
	var right := maxf(viewer.colorbar.size.x, viewer.legend.size.x)
	viewer.colorbar.position = Vector2(maxf(20, legend_available.x-right-20), maxf(18, legend_available.y-viewer.legend.size.y-20-18))
	viewer.legend.position = viewer.colorbar.position+Vector2(0,20)
	particle_legend_panel.position = viewer.colorbar.position-Vector2(8,6)
	particle_legend_panel.size = Vector2(right+16, viewer.legend.size.y+32)
	particle_legend_panel.visible = viewer.legend.visible
	if layer_legends != null:
		layer_legends.place(legend_available, particle_legend_panel.position.y if viewer.legend.visible else legend_available.y)

func enter_immersive() -> void:
	if immersive: return
	viewer._clear_manual_navigation()
	if viewer.session_log != null: viewer.session_log.record("UI", "Window.Fullscreen")
	transport.seek_dialog.hide()
	immersive_mode = DisplayServer.window_get_mode()
	var focused := get_viewport().gui_get_focus_owner()
	immersive_focus = weakref(focused) if focused != null else null
	if focused != null: focused.release_focus()
	for control in menus.values(): control.get_popup().hide()
	viewer.tools_ui.close(false)
	immersive_edges = edge_reveal.states.duplicate(true)
	immersive_chrome = {"navigation":navigation.visible,"error":open_error.visible}
	for side in edge_reveal.states:
		edge_reveal.states[side] = {"pinned":false,"visible":false,"dwell":0.0,"leave":0.0}
		edge_reveal.update_pin(side)
	immersive = true
	immersive_started = Time.get_ticks_msec()
	immersive_native_seen = immersive_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	# Relocated camera actions follow their top-bar parent's edge visibility.
	empty.hide(); open_error.hide()
	dock.hide()
	viewer.resize_handle.hide()
	if viewer.screenshot_notice != null: viewer.screenshot_notice.hide()
	immersive_hint.hide()
	layout()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func exit_immersive(restore_native := true) -> void:
	if not immersive: return
	var current_focus := get_viewport().gui_get_focus_owner()
	viewer._clear_manual_navigation()
	if viewer.session_log != null: viewer.session_log.record("UI", "Window.Exit fullscreen")
	immersive = false
	edge_reveal.states = immersive_edges.duplicate(true)
	immersive_edges.clear()
	for side in edge_reveal.states: edge_reveal.update_pin(side)
	navigation.visible = immersive_chrome.navigation
	open_error.visible = immersive_chrome.error
	immersive_chrome.clear()
	immersive_hint.hide()
	if restore_native: DisplayServer.window_set_mode(immersive_mode)
	show()
	refresh()
	layout()
	# Configure events subsequently lay out the restored native window size.
	if is_instance_valid(current_focus) and current_focus.is_visible_in_tree():
		current_focus.grab_focus()
	elif immersive_focus != null and get_viewport().gui_get_focus_owner() == null:
		var focused = immersive_focus.get_ref()
		if is_instance_valid(focused) and focused.is_visible_in_tree(): focused.grab_focus()
	immersive_focus = null

func _process(_delta: float) -> void:
	if not immersive: return
	if window_chrome != null and window_chrome.minimized_from >= 0: return
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
	# Export Overlays gates eligible scientific annotations, never shell chrome.
	visible = false
	# Legends are siblings of this shell and retain their own export gates.

func build_menus(row: HBoxContainer) -> void:
	for entry in [["File","open"],["Edit","view"],["View","view"],["Tools","analysis"],["Help","help"]]:
		menu(row,entry[0],entry[1],[],func(_id):pass)
		menus[entry[0]].about_to_popup.connect(refresh_commands)
	var file: PopupMenu = menus.File.get_popup()
	command(file,"Open file…",viewer._show_open_dialog,"open")
	command(file,"Close File",viewer._close_capture,"close_file")
	command(file,"Details…",func(): status_ui.show_status(),"details")
	var state := submenu(file,"State")
	command(state,"Copy state",viewer._copy_inspection_state,"copy")
	command(state,"Save view preset…",viewer._show_recipe_dialog.bind(true),"Save scene")
	command(state,"Load view preset…",viewer._show_recipe_dialog.bind(false),"Load scene")
	for title in ["Save analysis","Load analysis"]: command(state,title,viewer.tools_ui.open.bind(title),title)
	command(state,"Resolve input",func(): viewer.selection_controller.temporal.durable.choose_input(),"resolve")
	var export_menu := submenu(file,"Export")
	command(export_menu,"Image",viewer.tools_ui.open.bind("Image"),"image")
	command(export_menu,"Video",func():viewer.video_dialog.open(),"video")
	command(export_menu,"Data",viewer.tools_ui.open.bind("Data"),"data")
	file.add_separator()
	command(file,"Exit",func(): window_chrome.request_close(),"exit")
	var preferences := submenu(menus.Edit.get_popup(),"Preferences")
	command(preferences,"Keyboard Shortcuts",edit_shortcuts,"keyboard_shortcuts")
	command(preferences,"File Locations",edit_file_locations,"file_locations")
	var theme_menu := submenu(preferences,"Theme")
	command(theme_menu,"Dark",func():appearance.select(false),"theme_dark",true)
	command(theme_menu,"Light",func():appearance.select(true),"theme_light",true)
	var view: PopupMenu = menus.View.get_popup()
	var window_menu := submenu(view,"Window")
	command(window_menu,"Fullscreen",viewer._toggle_fullscreen,"fullscreen",true)
	command(view,"Global effects",viewer.tools_ui.open.bind("Global effects"),"global_effects")
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
	for title in ["Mapping","Derive range","Slice","Clipping","Isosurface","Source probe","Performance","Geometry"]: command(tools,title,viewer.tools_ui.open.bind(title),"tool:"+title)
	var help: PopupMenu = menus.Help.get_popup()
	command(help,"About",func():
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null:previous_focus = weakref(focus)
		about.open(),"about")

func submenu(parent: PopupMenu, title: String) -> PopupMenu:
	var popup := PopupMenu.new(); popup.name = title.replace(" ",""); popup.set_meta("wavez_menu_label", title); parent.add_child(popup)
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
		var enabled: bool = loaded or key in ["open","details","fullscreen","file_locations","keyboard_shortcuts","theme_dark","theme_light","about","exit"]
		if key in ["probe","tool:Clipping","tool:Isosurface","tool:Source probe"]: enabled = fields
		if key == "tool:Mapping": enabled = particles
		if key in ["tool:Slice","tool:Derive range"]: enabled = fields or particles
		if key == "resolve":
			var jobs = viewer.selection_controller.jobs
			enabled = loaded and jobs.background_operation == "load_recipe" and jobs.background_scene == viewer.capture_generation and jobs.background_error_code == "unopened_source"
		if key.begins_with("preset:"): enabled = loaded and viewer.preset_available.get(key.trim_prefix("preset:"),true)
		entry.popup.set_item_disabled(entry.index,not enabled)
		entry.popup.set_item_tooltip(entry.index,"" if enabled else ("Open a compatible capture first" if not loaded else "Unavailable for the current source or state"))
		if key == "close_file": entry.popup.set_item_tooltip(entry.index, "")
		var checked := false
		if key == "theme_dark": checked = appearance == null or not appearance.light
		elif key == "theme_light": checked = appearance != null and appearance.light
		elif key == "fullscreen": checked = immersive
		elif key == "probe": checked = fields and viewer.scene_layers.probe_marker_enabled
		elif key == "grid": checked = viewer.guide_mesh.visible
		elif key.begins_with("guide:"):
			var guide: String = key.trim_prefix("guide:")
			checked = viewer.guide_visibility[guide]
			var metadata_key: String = "imposed_regions" if guide == "imposed" else guide
			entry.popup.set_item_disabled(entry.index,not loaded or (guide != "data" and not viewer.geometry_metadata.has(metadata_key)))
		elif key.begins_with("preset:"): checked = viewer.selected_preset == key.trim_prefix("preset:")
		if entry.popup.is_item_checkable(entry.index): entry.popup.set_item_checked(entry.index,checked)
