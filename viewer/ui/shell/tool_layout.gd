extends RefCounted
## Presentation only. Existing widgets keep their signals, drafts and controller owners.
const UI = preload("res://analysis/ui_controls.gd")

static func label(parent: Node, text: String) -> Label:
	var result := Label.new(); result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(result)
	return result

static func flatten(parent: Node) -> void:
	for child in parent.get_children():
		if not is_instance_valid(child):continue
		if child.has_meta("analysis_group"):
			var body: Control = child.get_meta("analysis_group")
			flatten(body)
			var index := child.get_index()
			for item in body.get_children():
				item.reparent(parent); parent.move_child(item,index); index += 1
			body.free(); child.free()

static func page(parent: Node) -> VBoxContainer:
	var result := VBoxContainer.new(); result.add_theme_constant_override("separation",10)
	parent.add_child(result);return result

static func pages(parent: VBoxContainer, names: Array, bodies: Array, title := "Section") -> OptionButton:
	var heading := label(parent,title);parent.move_child(heading,0)
	var choice := OptionButton.new();parent.add_child(choice);parent.move_child(choice,1)
	for name in names:choice.add_item(name)
	choice.set_meta("tool_pages",bodies)
	choice.item_selected.connect(func(index):
		for i in bodies.size():bodies[i].visible = i == index
		var ancestor: Node = parent
		while ancestor != null and not ancestor is ScrollContainer:ancestor = ancestor.get_parent()
		if ancestor != null:ancestor.set_deferred("scroll_vertical",0))
	for i in bodies.size():bodies[i].visible = i == 0
	return choice

static func grouped_pages(parent: VBoxContainer, main_name: String) -> void:
	# Unwrap legacy groups into sibling task sections, never nested disclosures.
	var names: Array = [main_name];var bodies: Array = []
	var main := page(parent); bodies.append(main)
	for child in parent.get_children():
		if child == main:continue
		if child.has_meta("analysis_group"):
			var body: Control = child.get_meta("analysis_group")
			names.append({"Select by ID or region":"Definition","Surface and cohort tools":"Surfaces and cohorts","Selection groups":"Groups"}.get(child.text,child.text.replace("Advanced • ","")));bodies.append(body)
			flatten(body);body.show();child.free()
		elif not bodies.has(child):child.reparent(main)
	if bodies.size() > 1:pages(parent,names,bodies)
	else:
		for child in main.get_children():child.reparent(parent)
		main.free()

static func visibility(control: Control, visible: bool) -> void:
	control.visible = visible
	var index := control.get_index()
	if index > 0 and control.get_parent().get_child(index-1) is Label:control.get_parent().get_child(index-1).visible = visible

static func fit(parent: Node) -> void:
	UI.fit(parent)
	for child in parent.get_children():
		if child is BaseButton or child is LineEdit or child is SpinBox:child.custom_minimum_size.y = maxf(child.custom_minimum_size.y,32)
		if child is VBoxContainer:child.add_theme_constant_override("separation",10)
		fit(child)
