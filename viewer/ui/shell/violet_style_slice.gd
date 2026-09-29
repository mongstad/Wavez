extends RefCounted
## A bounded production slice for owner review; no controller or scientific state.
const ThemeSource = preload("res://ui/theme/violet_slice_theme.gd")
var theme := ThemeSource.new()

func install(shell) -> void:
	for surface in [shell.bar, shell.transport, shell.status_ui]:
		surface.theme = theme
		surface.add_theme_stylebox_override("panel", theme.flat_box(&"surface.1", 0, 0, 0))
	# Deeper dock foundation; only the first particle control groups are migrated.
	shell.dock.add_theme_stylebox_override("panel", theme.flat_box(&"surface.1", 12, 12, 0))
	var header = shell.edge_reveal.pins.right.get_parent()
	header.theme = theme
	shell.tabs.theme = theme; shell.chooser.theme = theme
	for group in ["Rendering", "Color Mapping"]:
		var body: Control = shell.viewer.sections[group]
		body.theme = theme
		if group == "Rendering":
			for child in body.get_children():
				if child is Label:
					child.remove_theme_color_override("font_color")
					child.theme_type_variation = "PropertyLabel"
		var disclosure: Button = shell.viewer.section_buttons[group]
		disclosure.theme = theme
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			disclosure.add_theme_stylebox_override(state, theme.flat_box(&"surface.hover" if state.begins_with("hover") else &"surface.1", 4, 8, 0))
		animate_buttons(body)
		animate_buttons(disclosure)
	# MenuButton padding overrides were built before the review Theme existed.
	for menu in shell.menus.values():
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBox = theme.get_stylebox(state, "MenuButton").duplicate()
			style.content_margin_right += 20
			menu.add_theme_stylebox_override(state, style)
	for node in [shell.bar, header, shell.tabs, shell.transport, shell.status_ui]: animate_buttons(node)
	for side in shell.edge_reveal.pins:
		var pin: Button = shell.edge_reveal.pins[side]
		pin.theme = theme; pin.theme_type_variation = "IconAction"
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
	shell.transport.seek_dialog.theme = shell.theme
	shell.status_ui.jobs_dialog.theme = shell.theme

func animate_buttons(node: Node) -> void:
	if node is Button and not node.has_meta("violet_motion"):
		node.set_meta("violet_motion", true)
		node.self_modulate = Color(.94, .94, .94)
		node.mouse_entered.connect(fade.bind(node, Color.WHITE))
		node.mouse_exited.connect(fade.bind(node, Color(.94, .94, .94)))
		if node.icon != null and node.icon.resource_path.begins_with("res://ui/shell/icons/"):
			node.icon = theme.shell_icon(node.icon.resource_path.get_file().get_basename())
	for child in node.get_children():
		# Dialogs/Jobs are deferred until visual slice acceptance.
		if not child is Window: animate_buttons(child)

func fade(control: Button, color: Color) -> void:
	var previous = control.get_meta("violet_tween") if control.has_meta("violet_tween") else null
	if previous != null and previous.is_valid(): previous.kill()
	var tween := control.create_tween()
	control.set_meta("violet_tween", tween)
	tween.tween_property(control, "self_modulate", color, .08)
