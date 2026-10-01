extends VBoxContainer
## Presentation-only action intent. An unavailable reason is visible outside the disabled button.
signal invoked(action_id: StringName)
const T = preload("res://ui/theme/wavez_tokens.tres")
var action_id: StringName
var button := preload("res://ui/components/tooltip_button.gd").new()
var reason := Label.new()

func _init() -> void:
	add_child(button); add_child(reason)
	button.custom_minimum_size.y = T.control_height
	button.pressed.connect(func(): invoked.emit(action_id))
	reason.theme_type_variation = &"SecondaryLabel"
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.hide()

func configure(id: StringName, label: String, role: StringName = &"SecondaryButton", shortcut_text: String = "") -> void:
	action_id = id; button.text = label; button.accessibility_name = label
	button.theme_type_variation = role
	button.tooltip_text = label + (" (" + shortcut_text + ")" if not shortcut_text.is_empty() else "")

func set_available(available: bool, explanation: String = "") -> void:
	assert(available or not explanation.is_empty(), "Unavailable actions need a visible reason")
	button.disabled = not available
	reason.text = explanation; reason.visible = not available

func set_icon(texture: Texture2D, icon_only: bool = false) -> void:
	button.icon = texture
	if icon_only:
		button.text = ""; button.custom_minimum_size.x = T.control_height
		button.theme_type_variation = &"IconAction"
