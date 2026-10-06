extends RefCounted
## A bounded production slice for owner review; no controller or scientific state.
const ThemeSource = preload("res://ui/theme/violet_slice_theme.gd")
var theme := ThemeSource.new()

func install(shell) -> void:
	for surface in [shell.bar, shell.transport, shell.status_ui]:
		surface.theme = theme
		surface.add_theme_stylebox_override("panel", theme.tonal_surface())
	shell.status_ui.add_theme_stylebox_override("panel", theme.flat_box(&"surface.shade", 0, 0, 0))
	# Deeper dock foundation; full group styling remains a bounded particle slice.
	shell.dock.add_theme_stylebox_override("panel", theme.tonal_surface(14, 12))
	var header = shell.edge_reveal.pins.right.get_parent()
	header.theme = theme
	header.get_child(0).theme_type_variation = "PanelTitle"
	header.get_parent().add_theme_constant_override("separation", 10)
	shell.tabs.theme = theme; shell.chooser.theme = theme
	for group in ["Rendering", "Color Mapping"]:
		var body: Control = shell.viewer.sections[group]
		body.theme = theme
		body.add_theme_constant_override("separation", 8)
		if group == "Rendering":
			for child in body.get_children():
				if child is Label:
					child.remove_theme_color_override("font_color")
					child.theme_type_variation = "PropertyLabel"
		animate_buttons(body)
	# Slider widgets alone adopt the accepted violet treatment, including those
	# in deferred Tools forms. Their values, ranges and signal wiring stay intact.
	for slider in shell.viewer.visual_sliders.values(): slider.theme = theme
	# MenuButton padding overrides were built before the review Theme existed.
	for menu in shell.menus.values() + [shell.navigation.get_child(2)]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = theme.get_stylebox(state, "MenuButton").duplicate()
			style.content_margin_right += 20
			menu.add_theme_stylebox_override(state, style)
	for action in shell.navigation.get_children(): action.theme_type_variation = "IconAction"
	for node in [shell.bar, header, shell.tabs, shell.transport, shell.status_ui]: animate_buttons(node)
	for side in shell.edge_reveal.pins:
		var pin: Button = shell.edge_reveal.pins[side]
		pin.theme = theme; pin.theme_type_variation = "PinAction"
		shell.edge_reveal.update_pin(side)
	# The readiness overlay retains its accepted blue/teal meaning and geometry.
	# Only the native playhead is violet; scientific legends retain the old theme.
	shell.viewer.timeline.theme = theme
	# PreparedTimeline installed transparent native-track overrides in _ready.
	# Keep those overrides and its endpoint-centred axis intact.
	var track: StyleBoxFlat = shell.viewer.timeline.get_theme_stylebox("slider").duplicate()
	track.border_color = theme.c(&"border.control")
	shell.viewer.timeline.add_theme_stylebox_override("slider", track)
	for action in shell.transport.actions.get_children(): action.theme_type_variation = "IconAction"
	shell.transport.displayed.theme_type_variation = "NumericValue"
	# Label and CompactButton must resolve the same numeric font and size.
	for readout in [shell.transport.displayed, shell.transport.duration]:
		readout.add_theme_font_override("font", theme.get_font("font", "NumericValue"))
		readout.add_theme_font_size_override("font_size", theme.get_font_size("font_size", "NumericValue"))
	shell.transport.seek_dialog.theme = theme
	shell.details.theme = theme
	shell.about.theme = theme
	animate_buttons(shell.about)
	# Jobs uses the same borderless surface, title and action roles as Video Export.
	shell.status_ui.jobs_dialog.theme = theme
	shell.status_ui.jobs_dialog.add_theme_stylebox_override("panel", theme.flat_box(&"surface.1",16,16,0))
	shell.status_ui.jobs_header_close.icon = theme.chrome_icon("close")
	animate_buttons(shell.status_ui.jobs_dialog)
	style_dropdowns(shell.viewer)
	style_booleans(shell.viewer)

func style_booleans(node: Node) -> void:
	# Bind only boolean widgets; forms, callbacks and semantic ownership stay intact.
	if node is FileDialog: return
	if node is CheckButton or node is CheckBox:
		node.theme = theme
		animate_buttons(node)
	for child in node.get_children(): style_booleans(child)

func style_dropdowns(node: Node) -> void:
	# Widget-only binding: deferred forms/dialogs keep their surrounding theme.
	# OptionButton's internal PopupMenu is not in get_children(); bind it explicitly
	# so native/embedded popups and reparented tool selectors share the same skin.
	if node is FileDialog: return
	if node is OptionButton:
		node.theme = theme
		node.get_popup().theme = theme
		animate_buttons(node)
	elif node is PopupMenu:
		node.theme = theme
	for child in node.get_children(): style_dropdowns(child)

func animate_buttons(node: Node) -> void:
	if node is Button and not node.has_meta("violet_motion"):
		node.set_meta("violet_motion", true)
		node.self_modulate = Color(.94, .94, .94)
		node.mouse_entered.connect(fade.bind(node, Color.WHITE))
		node.mouse_exited.connect(fade.bind(node, Color(.94, .94, .94)))
		if node.icon != null and node.icon.resource_path.begins_with("res://ui/shell/icons/"):
			node.icon = theme.shell_icon(node.icon.resource_path.get_file().get_basename())
	for child in node.get_children():
		# Nested windows are styled separately by their owning surfaces.
		if not child is Window: animate_buttons(child)

func fade(control: Button, color: Color) -> void:
	var previous = control.get_meta("violet_tween") if control.has_meta("violet_tween") else null
	if previous != null and previous.is_valid(): previous.kill()
	var tween := control.create_tween()
	control.set_meta("violet_tween", tween)
	tween.tween_property(control, "self_modulate", color, .08)
