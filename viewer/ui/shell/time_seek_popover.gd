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
	var form := VBoxContainer.new(); form.custom_minimum_size.x = 192; add_child(form)
	form.add_theme_constant_override("separation", 8)
	editor.theme_type_variation = "NumericInput"
	editor.placeholder_text = "MM:SS"
	editor.select_all_on_focus = true; form.add_child(editor)
	editor.keep_editing_on_text_submit = true
	editor.text_submitted.connect(func(_text): confirmed.emit())
	editor.text_changed.connect(func(_text): show_error(""))
	editor.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			hide(); editor.accept_event())
	error_label.theme_type_variation = "ErrorLabel"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; form.add_child(error_label); error_label.hide()
	popup_hide.connect(func():
		if return_focus != null:
			var control = return_focus.get_ref()
			if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus())

static func format_time(seconds: float) -> String:
	# Display completed seconds only; never round the scientific/source clock.
	var whole := floorf(maxf(0, seconds))
	if whole < 3600: return "%02d:%02d" % [int(whole / 60), int(fmod(whole, 60))]
	return "%02.0f:%02d:%02d" % [floor(whole / 3600), int(fmod(floor(whole / 60), 60)), int(fmod(whole, 60))]

static func parse_time(text: String) -> Dictionary:
	var error := {"error":"Use MM:SS or HH:MM:SS."}
	var parts := text.strip_edges().split(":")
	if parts.size() not in [2, 3]: return error
	var total := 0.0
	for i in parts.size():
		if parts[i].length() < 2 or (i > 0 and parts[i].length() != 2): return error
		for digit in parts[i]:
			if digit < "0" or digit > "9": return error
		var unit := float(parts[i])
		if i > 0 and unit >= 60: return error
		total = total * 60 + unit
	if not is_finite(total): return {"error":"Time is too large."}
	return {"value":total}

func configure(first: float, last: float, clock: float, anchor: Control) -> void:
	origin = first; end = last; current = clock
	initial_text = format_time(maxf(0, current - origin))
	editor.text = initial_text; show_error(""); return_focus = weakref(anchor)
	editor.tooltip_text = "Elapsed time · MM:SS or HH:MM:SS"

func source_target() -> Dictionary:
	# Accepting an unchanged whole-second prefill must not quantize source timing.
	if editor.text == initial_text and current >= origin and current <= end: return {"value":current}
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
