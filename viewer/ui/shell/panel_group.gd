extends RefCounted
## One disclosure level; body visibility remains the existing recipe-facing value.
const ThemeSource = preload("res://ui/theme/violet_slice_theme.gd")
const CLOSED = preload("res://ui/icons/chevron_right.svg")
const OPEN = preload("res://ui/icons/chevron_down.svg")
static func create(parent: VBoxContainer, title: String, expanded := false) -> VBoxContainer:
	var theme := ThemeSource.new()
	var header := Button.new(); header.text = title; header.toggle_mode = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT; header.custom_minimum_size.y = 36
	header.button_pressed = expanded; header.icon = OPEN if expanded else CLOSED
	header.set_meta("panel_disclosure",true)
	header.theme = theme; header.theme_type_variation = "PanelDisclosure"
	parent.add_child(header)
	var margin := MarginContainer.new();margin.add_theme_constant_override("margin_left",12)
	margin.add_theme_constant_override("margin_bottom",12);parent.add_child(margin)
	var body := VBoxContainer.new();body.add_theme_constant_override("separation",8);margin.add_child(body)
	body.set_meta("panel_header",header);body.visible = expanded;margin.visible = expanded
	header.toggled.connect(func(value):body.visible = value)
	body.visibility_changed.connect(func():
		margin.visible = body.visible
		header.set_pressed_no_signal(body.visible);header.icon = OPEN if body.visible else CLOSED)
	return body

static func fit(parent: Node) -> void:
	for child in parent.get_children():
		if child is Label:child.remove_theme_font_size_override("font_size")
		if child is VBoxContainer:child.add_theme_constant_override("separation",8)
		if child is Button or child is Range or child is LineEdit:child.custom_minimum_size.y = 32
		fit(child)
