extends PopupPanel
## Draft-only until a finite, in-range decimal is accepted.
signal confirmed(value: float)
const FloatText = preload("res://ui/components/float64_text.gd")
var editor := LineEdit.new()
var error_label := Label.new()
var return_focus: WeakRef

func _init() -> void:
	name = "ParticleSizePopover"
	var form := VBoxContainer.new(); form.custom_minimum_size.x = 224; add_child(form)
	form.add_theme_constant_override("separation", 8)
	var title := Label.new(); title.text = "Particle size"; title.theme_type_variation = "PropertyLabel"; form.add_child(title)
	editor.theme_type_variation = "NumericInput"; editor.select_all_on_focus = true
	editor.keep_editing_on_text_submit = true; form.add_child(editor)
	editor.text_submitted.connect(func(_text): submit())
	editor.text_changed.connect(func(_text): show_error(""))
	editor.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			hide(); editor.accept_event())
	var bounds := Label.new(); bounds.text = "0.01–8"; bounds.theme_type_variation = "HelpLabel"; form.add_child(bounds)
	error_label.theme_type_variation = "ErrorLabel"
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; form.add_child(error_label); error_label.hide()
	popup_hide.connect(func():
		if return_focus != null:
			var anchor = return_focus.get_ref()
			if is_instance_valid(anchor) and anchor.is_visible_in_tree(): anchor.grab_focus())

func configure(current: float, anchor: Control) -> void:
	editor.text = FloatText.format_value(current); show_error(""); return_focus = weakref(anchor)

func submit() -> void:
	var parsed := FloatText.parse(editor.text)
	if parsed.has("error"): show_error(parsed.error); return
	if parsed.value < 0.01 or parsed.value > 8.0:
		show_error("Enter a value from 0.01 to 8."); return
	confirmed.emit(parsed.value)

func show_error(message: String) -> void:
	error_label.text = message; error_label.visible = not message.is_empty()
	editor.theme_type_variation = "NumericInput" if message.is_empty() else "InvalidNumericInput"
	reset_size()

func open_at(anchor: Rect2) -> void:
	reset_size()
	var extent := get_parent().get_viewport().get_visible_rect().size
	var point := Vector2i(clampf(anchor.get_center().x - size.x * .5, 8, maxf(8, extent.x - size.x - 8)), clampf(anchor.position.y - size.y - 10, 8, maxf(8, extent.y - size.y - 8)))
	if not is_embedded(): point += get_parent().get_window().position
	popup(Rect2i(point, size)); editor.grab_focus(); editor.edit(); editor.select_all()
