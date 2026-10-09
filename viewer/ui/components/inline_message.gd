extends PanelContainer
## Durable message/notification primitive. Caller owns job lifetime and dismissal policy.
signal acknowledged()
var line := HBoxContainer.new()
var symbol := TextureRect.new()
var current_severity := ""

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not current_severity.is_empty(): refresh_symbol()

func refresh_symbol() -> void:
	var key := "status_" + current_severity
	symbol.texture = get_theme_icon(key, "TextureRect") if has_theme_icon(key, "TextureRect") else preload("res://ui/theme/wavez_dark.tres").icon_named("check" if current_severity == "success" else current_severity, StringName("state." + current_severity))

var content := VBoxContainer.new()
var title := Label.new()
var detail := Label.new()
var dismiss := Button.new()

func _init() -> void:
	add_child(line); line.add_child(symbol); line.add_child(content); line.add_child(dismiss)
	symbol.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	symbol.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	symbol.custom_minimum_size = Vector2(16, 24)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(title); content.add_child(detail)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.theme_type_variation = &"SecondaryLabel"; detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dismiss.text = "Dismiss"; dismiss.theme_type_variation = &"CompactButton"
	dismiss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dismiss.pressed.connect(func(): acknowledged.emit())

func configure(severity: String, message: String, explanation: String = "", dismissible: bool = false) -> void:
	assert(severity in ["info", "success", "warning", "error"])
	theme_type_variation = StringName(severity.capitalize() + "Message")
	title.text = severity.capitalize() + ": " + message
	detail.text = explanation; detail.visible = not explanation.is_empty()
	dismiss.visible = dismissible
	current_severity = severity
	refresh_symbol()
