extends HBoxContainer
## Approximate visual parameter only. Scientific thresholds use number_field.gd.
signal value_requested(value: float)
var slider := preload("res://ui/components/focus_slider.gd").new()
var readout := Label.new()

func _init() -> void:
	add_child(slider); add_child(readout)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(100, 32)
	readout.theme_type_variation = &"NumericValue"
	readout.custom_minimum_size.x = 64; readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float): _readout(value); value_requested.emit(value))

func configure(low: float, high: float, step_value: float, value: float) -> void:
	slider.min_value = low; slider.max_value = high; slider.step = step_value
	set_value(value)

func set_value(value: float) -> void:
	slider.set_value_no_signal(value); _readout(slider.value)

func _readout(value: float) -> void: readout.text = "%0.2f" % value
