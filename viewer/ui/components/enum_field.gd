extends VBoxContainer
## IDs survive label/order changes. Refresh never emits selection intent.
signal selection_requested(id: StringName)
var selector := OptionButton.new()
var reason := Label.new()
var selected_id: StringName
var entries: Array[Dictionary] = []

func _init() -> void:
	add_child(selector); add_child(reason)
	reason.theme_type_variation = &"SecondaryLabel"; reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.hide()
	selector.item_selected.connect(func(index: int): selected_id = entries[index].id; _reason(index); selection_requested.emit(selected_id))

func set_options(options: Array, current_id: StringName) -> void:
	entries.assign(options.duplicate(true)); selected_id = current_id
	selector.clear()
	var selected := -1
	for index in entries.size():
		var item := entries[index]
		assert(item.has_all(["id", "label"]))
		selector.add_item(item.label)
		selector.set_item_metadata(index, item.id)
		selector.set_item_disabled(index, not item.get("available", true))
		selector.set_item_tooltip(index, item.get("reason", ""))
		if item.id == current_id: selected = index
	selector.select(selected)
	_reason(selected)

func _reason(index: int) -> void:
	reason.text = entries[index].get("reason", "") if index >= 0 else "No matching option is available."
	reason.visible = not reason.text.is_empty()
