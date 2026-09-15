extends VBoxContainer
## Layout only; conversion/validation belongs to the supplied editor.
const T = preload("res://ui/theme/simscope_tokens.tres")
var line := BoxContainer.new()
var label := Label.new()
var field := HBoxContainer.new()
var unit := Label.new()
var help := Label.new()
var editor: Control
var stacked := false

func _init() -> void:
	add_child(line); line.add_child(label); line.add_child(field)
	add_child(help)
	label.theme_type_variation = &"PropertyLabel"; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit.theme_type_variation = &"SecondaryLabel"
	help.theme_type_variation = &"HelpLabel"; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.hide()
	resized.connect(_layout)

func configure(title: String, control: Control, suffix: String = "", explanation: String = "") -> void:
	assert(editor == null, "Configure a property row once")
	label.text = title; editor = control
	field.add_child(editor); field.add_child(unit)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit.text = suffix; unit.visible = not suffix.is_empty()
	help.text = explanation; help.visible = not explanation.is_empty()
	_layout()

func _layout() -> void:
	stacked = size.x < T.property_stack_width
	line.vertical = stacked
	label.custom_minimum_size.x = 0 if stacked else T.property_label_width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_FILL
