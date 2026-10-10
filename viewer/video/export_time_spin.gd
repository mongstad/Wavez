extends SpinBox
## Whole-second elapsed controls backed by exact recorded export endpoints.
signal timestamp_changed(time: float)
const FloatText = preload("res://ui/components/float64_text.gd")
var timestamp := 0.0
var origin := 0.0
var lower := 0.0
var upper := 0.0
var duration := 0.0
var include_remainder := false
var _displayed := 0.0
var _draft := false
var _draft_text := ""
var _refreshing := false
var _anchor := 0.0
var _steps := 0.0

func _init() -> void:
	step = 1
	# Let a button tick reach an exact fractional boundary even if its integer
	# projection is already at the displayed limit. _changed clamps synchronously.
	allow_greater = true; allow_lesser = true
	value_changed.connect(_changed)

func _ready() -> void:
	var editor := get_line_edit()
	editor.text_changed.connect(func(text: String): _draft = true; _draft_text = text)
	editor.text_submitted.connect(func(_text: String): _commit_text())
	# Native Tab can publish edited text after focus_exited; commit after that flush.
	editor.focus_exited.connect(func(): _commit_text.call_deferred())
	# Native Enter/Tab can bypass submission when the projected number is unchanged.
	editor.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_TAB]:
			_commit_text.call_deferred())

func configure_bounds(first: float, last: float, minimum: float, maximum: float) -> void:
	origin = first; duration = last - first
	lower = minimum; upper = maximum
	# Range setters can emit value_changed. Refresh must not edit the exact model.
	_refreshing = true
	max_value = maxf(max_value, projection(upper))
	min_value = projection(lower)
	max_value = projection(upper)
	_refreshing = false
	if timestamp < lower or timestamp > upper:
		set_timestamp(timestamp)
	else:
		_refresh()

func elapsed_time() -> float:
	return timestamp - origin

func projection(time: float) -> float:
	# Never display an integer beyond a fractional simulation duration.
	return clampf(project_time(time - origin), 0, floorf(duration))

func set_timestamp(time: float) -> void:
	timestamp = clampf(time, lower, upper)
	_anchor = timestamp; _steps = 0
	_refresh()

func _refresh() -> void:
	_displayed = projection(timestamp)
	set_value_no_signal(_displayed)
	_draft = false

static func project_time(time: float) -> float:
	var nearest_lower := floorf(time)
	return nearest_lower + (1.0 if time - nearest_lower >= .5 else 0.0)

func _changed(seconds: float) -> void:
	if _refreshing: return
	if _draft:
		_commit_text()
		return
	var previous := timestamp
	var steps := _steps + (seconds - _displayed)
	var candidate := _anchor + steps
	timestamp = clampf(_edited_endpoint(candidate), lower, upper)
	if timestamp == candidate:
		_steps = steps
	else:
		_anchor = timestamp; _steps = 0
	_refresh()
	if timestamp != previous: timestamp_changed.emit(timestamp)

func _commit_text() -> void:
	if not _draft: return
	var parsed := FloatText.parse(_draft_text.trim_suffix(" s").strip_edges())
	var previous := timestamp
	# Parse the draft before native clipping: an out-of-range edit selects the
	# exact boundary, including a fractional final sample or the opposite endpoint.
	if not parsed.has("error"):
		set_timestamp(_edited_endpoint(origin + project_time(parsed.value)))
	else:
		set_timestamp(previous)
	if timestamp != previous: timestamp_changed.emit(timestamp)
	_draft = false

func commit_edit() -> void:
	# Start Export can be pressed in the same input batch as focus loss, before
	# deferred validation runs. Flush native text before reading job settings.
	get_line_edit().unedit()
	_commit_text()

func _edited_endpoint(time: float) -> float:
	# Only deliberate End edits include the last partial second. Silent refreshes
	# and restored ranges must retain their originally selected exact endpoints.
	if include_remainder and duration > floorf(duration) and time >= origin + floorf(duration):
		return upper
	return time
