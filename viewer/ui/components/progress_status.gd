extends VBoxContainer
## No timer or worker ownership. Unknown progress is stated explicitly, without fabricated %.
var label := Label.new()
var bar := ProgressBar.new()

func _init() -> void:
	add_child(label); add_child(bar)
	label.theme_type_variation = &"NumericValue"
	bar.show_percentage = false
	bar.custom_minimum_size.y = 16

func set_progress(stage: String, fraction: float = -1.0) -> void:
	bar.visible = fraction >= 0.0
	if fraction >= 0.0:
		bar.value = clampf(fraction, 0.0, 1.0) * 100.0
		label.text = "%s  %5.1f%%" % [stage, bar.value]
	else: label.text = stage + " — progress unknown"
