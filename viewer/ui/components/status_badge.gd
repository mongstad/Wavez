extends HBoxContainer
## Compact status with an icon and a textual state; never a color-only indicator.
var symbol := TextureRect.new()
var current_severity := ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not current_severity.is_empty(): refresh_symbol()

func refresh_symbol() -> void:
	var key := "status_" + current_severity
	symbol.texture = get_theme_icon(key, "TextureRect") if has_theme_icon(key, "TextureRect") else preload("res://ui/theme/wavez_dark.tres").icon_named("check" if current_severity == "success" else current_severity, StringName("state." + current_severity))

var label := Label.new()
func _init() -> void:
	add_child(symbol); add_child(label)
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	label.theme_type_variation = &"StatusLabel"
func configure(severity: String, text: String) -> void:
	assert(severity in ["info", "success", "warning", "error"])
	label.text = text
	current_severity = severity
	refresh_symbol()
