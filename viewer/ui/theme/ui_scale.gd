extends RefCounted
## Opt-in presentation boundary. Never call on the production root until UX3/UX6 approval.
const T = preload("res://ui/theme/simscope_tokens.tres")

static func apply(window: Window, factor: float) -> void:
	assert(factor in T.scales)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_factor = factor
