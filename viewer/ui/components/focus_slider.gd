extends HSlider
## Native Slider has no focus StyleBox. Add the shared persistent ring without an idle callback.
func _init() -> void:
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

func _draw() -> void:
	if has_focus(): draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(Vector2.ZERO, size))
