extends SpinBox
## Bounded approximate visual settings only; scientific/exact values use NumberField.
func _ready() -> void:
	get_line_edit().theme_type_variation = &"NumericInput"
	custom_minimum_size.y = preload("res://ui/theme/simscope_tokens.tres").control_height
