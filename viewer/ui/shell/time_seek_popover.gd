extends PopupPanel
## Edit the displayed elapsed clock; submit through the existing scientific seek.
signal confirmed
var editor := LineEdit.new()
var error_label := Label.new()
var origin := 0.0
var end := 0.0
var current := 0.0
var initial_text := ""
var return_focus: WeakRef

func _init() -> void:
	name = "TimeSeekPopover"
	var form := VBoxContainer.new(); form.custom_minimum_size.x = 268; add_child(form)
	form.add_theme_constant_override("separation", 8)
	var title := Label.new(); title.text = "Seek · elapsed time"; title.theme_type_variation = "SectionTitle"; form.add_child(title)
	editor.theme_type_variation = "NumericInput"
	editor.placeholder_text = "seconds · m:ss.s · h:mm:ss.s"
	editor.select_all_on_focus = true; form.add_child(editor)
	editor.keep_editing_on_text_submit = true
	editor.text_submitted.connect(func(_text): confirmed.emit())
	editor.text_changed.connect(func(_text): show_error(""))
	editor.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			hide(); editor.accept_event())
	error_label.theme_type_variation = "ErrorLabel"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; form.add_child(error_label); error_label.hide()
	var hint := Label.new(); hint.text = "Enter to seek · Esc to cancel"; hint.theme_type_variation = "HelpLabel"; form.add_child(hint)
	popup_hide.connect(func():
		if return_focus != null:
			var control = return_focus.get_ref()
			if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus())

static func format_time(seconds: float) -> String:
	# Unlike the rounded readout, the editable value retains float64 precision.
	const FloatText = preload("res://ui/components/float64_text.gd")
	if seconds < 60 or seconds >= 1e15: return FloatText.format_value(seconds)
	var minutes := floori(seconds / 60)
	var tail := FloatText.format_value(seconds - minutes * 60.0)
	if seconds - minutes * 60.0 < 10: tail = "0" + tail
	if minutes < 60: return "%d:%s" % [minutes, tail]
	return "%d:%02d:%s" % [minutes / 60, minutes % 60, tail]

static func parse_time(text: String) -> Dictionary:
	const FloatText = preload("res://ui/components/float64_text.gd")
	var parts := text.strip_edges().split(":")
	if parts.size() == 1: return FloatText.parse(parts[0])
	if parts.size() not in [2, 3]: return {"error":"Use seconds, m:ss.s or h:mm:ss.s."}
	var total := 0.0
	for i in parts.size():
		if i < parts.size() - 1:
			if parts[i].is_empty() or not parts[i].is_valid_int() or parts[i].begins_with("-") or parts[i].begins_with("+"):
				return {"error":"Use non-negative clock digits."}
			var unit := float(parts[i])
			if i > 0 and unit >= 60: return {"error":"Minutes must be below 60."}
			total = total * 60 + unit
		else:
			var parsed := FloatText.parse(parts[i])
			if parsed.has("error") or parsed.get("value", -1.0) < 0 or parsed.get("value", 60.0) >= 60:
				return {"error":"Seconds must be in [0, 60)."}
			total = total * 60 + parsed.value
	if not is_finite(total): return {"error":"Time is too large."}
	return {"value":total}

func configure(first: float, last: float, clock: float, anchor: Control) -> void:
	origin = first; end = last; current = clock
	initial_text = format_time(maxf(0, current - origin))
	editor.text = initial_text; show_error(""); return_focus = weakref(anchor)
	editor.tooltip_text = "Elapsed time from the first sample. Source time " + preload("res://ui/components/float64_text.gd").format_value(current)

func source_target() -> Dictionary:
	if editor.text == initial_text: return {"value":current}
	var parsed := parse_time(editor.text)
	if parsed.has("error"): return parsed
	if parsed.value < 0 or parsed.value > end - origin: return {"error":"Outside the recorded interval."}
	return {"value":origin + parsed.value}

func show_error(message: String) -> void:
	error_label.text = message; error_label.visible = not message.is_empty()
	editor.theme_type_variation = "NumericInput" if message.is_empty() else "InvalidNumericInput"
	reset_size()

func open_at(anchor: Rect2) -> void:
	reset_size()
	var extent := get_parent().get_viewport().get_visible_rect().size
	var local := Vector2(clampf(anchor.get_center().x - size.x * .5, 8, maxf(8, extent.x - size.x - 8)), maxf(8, anchor.position.y - size.y - 10))
	# Embedded popup coordinates are local; native coordinates include the window origin.
	var point := Vector2i(local)
	if not is_embedded(): point += get_parent().get_window().position
	popup(Rect2i(point, size)); editor.grab_focus(); editor.edit(); editor.select_all()
