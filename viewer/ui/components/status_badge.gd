extends HBoxContainer
## Compact status with an icon and a textual state; never a color-only indicator.
var symbol := TextureRect.new()
var label := Label.new()
func _init() -> void:
	add_child(symbol); add_child(label)
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	label.theme_type_variation = &"StatusLabel"
func configure(severity: String, text: String) -> void:
	assert(severity in ["info", "success", "warning", "error"])
	label.text = text
	symbol.texture = preload("res://ui/theme/simscope_dark.tres").icon_named("check" if severity == "success" else severity, StringName("state." + severity))
