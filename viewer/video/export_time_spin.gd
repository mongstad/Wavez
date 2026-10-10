extends SpinBox
## Whole-second projection of an exact export endpoint. Refresh is silent.
## Arrows shift the exact endpoint; explicitly edited text chooses a whole second.
signal timestamp_changed(time: float)
const FloatText = preload("res://ui/components/float64_text.gd")
var timestamp := 0.0
var _displayed := 0.0
var _draft := false
var _draft_text := ""

func _init() -> void:
	step = 1
	value_changed.connect(_changed)

func _ready() -> void:
	var editor := get_line_edit()
	editor.text_changed.connect(func(text: String): _draft = true; _draft_text = text)
	editor.text_submitted.connect(func(_text: String): _commit_text())
	editor.focus_exited.connect(_commit_text)
	# Native SpinBox can consume Enter without submitting an unchanged snapped
	# value. Commit after native validation even when only its exact model differs.
	editor.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_commit_text.call_deferred())

func set_timestamp(time: float) -> void:
	timestamp = clampf(time, min_value, max_value)
	_displayed = project_time(timestamp)
	set_value_no_signal(_displayed)
	_draft = false

static func project_time(time: float) -> float:
	# Nearest second, ties toward the later second. Translation by an integer
	# stays consistent across zero (0.5 -> -0.5 must also shift the display by 1).
	var lower := floorf(time)
	return lower + (1.0 if time - lower >= .5 else 0.0)

func _changed(seconds: float) -> void:
	# Native Range snaps its value to step; that projection is not the source clock.
	timestamp = clampf(seconds if _draft else timestamp + (seconds - _displayed), min_value, max_value)
	_displayed = seconds
	timestamp_changed.emit(timestamp)

func _commit_text() -> void:
	if not _draft: return # Unchanged Enter/focus loss must preserve fractional time.
	var parsed := FloatText.parse(_draft_text.trim_suffix(" s").strip_edges())
	# An explicit numeric edit also commits when the rounded display is unchanged.
	# Invalid text retains the native control's previous value and the exact clock.
	if not parsed.has("error"):
		var previous := timestamp
		set_timestamp(value)
		if timestamp != previous: timestamp_changed.emit(timestamp)
	_draft = false
