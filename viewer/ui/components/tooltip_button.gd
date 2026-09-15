extends Button
const T = preload("res://ui/theme/simscope_tokens.tres")

func _make_custom_tooltip(for_text: String) -> Object:
	var label := Label.new(); label.text = for_text
	label.custom_minimum_size.x = minf(T.tooltip_width, get_theme_font("font").get_string_size(for_text, HORIZONTAL_ALIGNMENT_LEFT, -1, T.help_size).x)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_type_variation = &"HelpLabel"
	return label
