extends VBoxContainer
signal expansion_requested(section_id: StringName, expanded: bool)
const ThemeFactory = preload("res://ui/theme/wavez_theme.gd")
var section_id: StringName
var header := Button.new()
var body: Control
var expanded := true

func _init() -> void:
	header.theme_type_variation = &"SectionHeader"
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.toggle_mode = true
	add_child(header)
	header.toggled.connect(func(value: bool): set_expanded(value); expansion_requested.emit(section_id, value))

func configure(id: StringName, title: String, content: Control) -> void:
	assert(body == null)
	section_id = id; header.text = title; body = content
	add_child(body); set_expanded(expanded)

func set_expanded(value: bool) -> void:
	expanded = value; header.set_pressed_no_signal(value)
	var ui_theme = preload("res://ui/theme/wavez_dark.tres")
	header.icon = ui_theme.icon_named("chevron_down" if value else "chevron_right")
	if body != null:
		var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if not value and focused != null and (focused == body or body.is_ancestor_of(focused)): header.grab_focus()
		body.visible = value
