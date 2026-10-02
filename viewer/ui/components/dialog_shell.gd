extends Window
## Explicit theme/window boundary; fixed title/actions, scrolling body; close != application cancel.
signal action_requested(action_id: StringName)
const T = preload("res://ui/theme/wavez_tokens.tres")
var panel := PanelContainer.new()
var layout := VBoxContainer.new()
var heading := Label.new()
var scroll := ScrollContainer.new()
var body := VBoxContainer.new()
var actions := HBoxContainer.new()
var return_focus: Control

func _init() -> void:
	visible = false; transient = true; exclusive = true
	theme = preload("res://ui/theme/wavez_dark.tres")
	panel.theme_type_variation = &"PopupSurface"
	panel.add_theme_stylebox_override("panel", theme.dialog_body(&"surface.3", &"border.control", 24, 24))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(layout); layout.add_child(heading); layout.add_child(scroll); layout.add_child(actions)
	heading.theme_type_variation = &"PanelTitle"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(body); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_END
	close_requested.connect(dismiss)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: dismiss())

func add_action(id: StringName, label: String, role: StringName = &"SecondaryButton") -> Button:
	var button := Button.new(); button.text = label; button.theme_type_variation = role
	actions.add_child(button); button.pressed.connect(func(): action_requested.emit(id))
	return button

func present(caption: String, parent_window: Window) -> void:
	title = caption; heading.text = caption
	return_focus = parent_window.gui_get_focus_owner()
	# Inherit logical-to-device factor once. No token/font multiplication.
	content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	content_scale_factor = parent_window.content_scale_factor
	content_scale_size = Vector2i.ZERO
	var available := Vector2(parent_window.size) / content_scale_factor * 0.9
	var logical := Vector2(minf(T.dialog_width, available.x), minf(480, available.y))
	size = Vector2i(logical * content_scale_factor)
	popup_centered(size)
	if actions.get_child_count(): actions.get_child(0).grab_focus()

func dismiss() -> void:
	hide()
	if is_instance_valid(return_focus): return_focus.grab_focus()
