extends RefCounted
# Presentation helpers only; nested groups never enter saved scientific state.
static func group(parent: VBoxContainer, first: Control, last: Control, title: String, hint := "", expanded := false) -> VBoxContainer:
	var start: Node = first
	while start.get_parent() != parent:start = start.get_parent()
	var end: Node = last
	while end.get_parent() != parent:end = end.get_parent()
	var index: int = start.get_index()
	if (first is LineEdit or first is OptionButton) and index > 0 and parent.get_child(index-1) is Label:index -= 1
	var children := parent.get_children().slice(index,end.get_index()+1)
	var toggle := Button.new();toggle.text = title;toggle.toggle_mode = true;toggle.button_pressed = expanded;toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT;toggle.tooltip_text = hint
	var body := VBoxContainer.new();body.visible = expanded;body.add_theme_constant_override("separation",5)
	toggle.set_meta("analysis_group",body)
	parent.add_child(toggle);parent.move_child(toggle,index);parent.add_child(body);parent.move_child(body,index+1)
	for child in children:child.reparent(body)
	toggle.toggled.connect(func(value):body.visible = value)
	return body

static func button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:return child
	return null

static func fit(parent: Node) -> void:
	for child in parent.get_children():
		if child is Label:child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if child is Button:
			child.clip_text = true
			if child.tooltip_text.is_empty():child.tooltip_text = child.text
		if child is OptionButton:
			child.fit_to_longest_item = false
			for index in range(child.item_count):child.set_item_tooltip(index,child.get_item_text(index))
		fit(child)

static func hint(control: Control, text: String) -> void:
	control.tooltip_text = text
	var index := control.get_index()
	if index > 0 and control.get_parent().get_child(index-1) is Label:control.get_parent().get_child(index-1).tooltip_text = text

static func axis_name(value: String) -> String:
	return {"native_time":"Recorded time","record_index":"Sample index","lag":"Time lag"}.get(value,value)
