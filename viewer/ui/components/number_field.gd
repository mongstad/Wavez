extends VBoxContainer
## Exact draft/commit boundary. Float64 fields and signed int64 IDs never share conversion.
## Refresh and Escape are silent. Focus loss retains a draft; only Enter/commit submits.
signal committed(value: Variant)
signal draft_changed(text: String)
signal validation_changed(message: String)
enum Kind { SCIENTIFIC, EXACT_INTEGER }
const FloatText = preload("res://ui/components/float64_text.gd")
const T = preload("res://ui/theme/wavez_tokens.tres")
var kind: Kind = Kind.SCIENTIFIC
var minimum: float = -INF
var maximum: float = INF
var validator: Callable
var model: Variant = 0.0
var committed_text := ""
var editor := LineEdit.new()
var error_label := Label.new()

func _init() -> void:
	add_child(editor); add_child(error_label)
	editor.theme_type_variation = &"NumericInput"
	editor.custom_minimum_size.y = T.control_height
	editor.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	editor.select_all_on_focus = true
	error_label.theme_type_variation = &"ErrorLabel"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.hide()
	editor.text_changed.connect(func(value: String): _error(""); draft_changed.emit(value))
	editor.text_submitted.connect(func(_value: String): commit())
	editor.gui_input.connect(_input_editor)
	set_model(0.0)

func set_model(value: Variant) -> void:
	if kind == Kind.EXACT_INTEGER:
		assert(value is int, "Exact IDs must arrive as int64, never float")
	else:
		assert(value is float and is_finite(value), "Scientific model must be finite float64")
	model = value
	committed_text = str(value) if kind == Kind.EXACT_INTEGER else FloatText.format_value(value)
	editor.text = committed_text
	_error("", false)

func _error(message: String, notify: bool = true) -> void:
	var changed := error_label.text != message
	error_label.text = message; error_label.visible = not message.is_empty()
	editor.theme_type_variation = &"NumericInput" if message.is_empty() else &"InvalidNumericInput"
	if notify and changed: validation_changed.emit(message)

func cancel() -> void:
	editor.text = committed_text; _error("", false)

func _input_editor(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel(); editor.accept_event()

static func parse_integer(text: String) -> Dictionary:
	var cleaned := text.strip_edges()
	var negative := cleaned.begins_with("-")
	var digits := cleaned.substr(1) if negative or cleaned.begins_with("+") else cleaned
	if digits.is_empty(): return {"error": "Enter a decimal integer."}
	for ch in digits:
		if ch < "0" or ch > "9": return {"error": "Use decimal digits only; IDs never use exponents or decimals."}
	while digits.length() > 1 and digits.begins_with("0"): digits = digits.substr(1)
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() > limit.length() or (digits.length() == limit.length() and digits > limit):
		return {"error": "Outside the signed 64-bit integer range."}
	return {"value": (("-" if negative else "") + digits).to_int()}

func commit() -> bool:
	# Do not parse an unchanged display: this also preserves negative zero bit-for-bit.
	if editor.text == committed_text:
		_error(""); return true
	var candidate: Variant
	if kind == Kind.EXACT_INTEGER:
		var parsed := parse_integer(editor.text)
		if parsed.has("error"): _error(parsed.error); return false
		candidate = parsed.value
	else:
		var parsed := FloatText.parse(editor.text)
		if parsed.has("error"): _error(parsed.error); return false
		candidate = parsed.value
		if candidate < minimum or candidate > maximum:
			_error("Outside the allowed range [%s, %s]." % [minimum, maximum]); return false
	if validator.is_valid():
		var message: String = validator.call(candidate)
		if not message.is_empty(): _error(message); return false
	set_model(candidate)
	committed.emit(candidate)
	return true
