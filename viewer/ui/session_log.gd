extends Node
## Best-effort, bounded diagnostics for one interactive application session.
## All events pass through record() so a later preference can select a policy.
const VERBOSE := 0
const MINIMAL := 1
const DISABLED := 2
const MAX_SESSION_BYTES := 2 * 1048576
const MAX_DIRECTORY_BYTES := 64 * 1048576
const MAX_SESSIONS := 30
var level := VERBOSE
var viewer
var path := ""
var file: FileAccess
var bytes_written := 0
var last_seek_target := NAN
var pending_ranges := {}
var committed_text := {}

func start(owner) -> void:
	viewer = owner
	if level == DISABLED: return
	var directory: String = viewer.file_locations.log_directory() if viewer.file_locations != null else ProjectSettings.globalize_path("user://logs")
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return
	var stamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	path = directory.path_join("wavez-%s-%013d-%d-%016d.log" % [stamp, int(Time.get_unix_time_from_system() * 1000.0), OS.get_process_id(), Time.get_ticks_usec()])
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null: return
	_prune(directory)
	record("APP", "WAVEZ %s started" % str(ProjectSettings.get_setting("application/config/version", "unknown")), true)
	get_tree().node_added.connect(_observe)
	_observe_tree(viewer)
	set_process(false)

func _exit_tree() -> void:
	if file != null:
		if is_instance_valid(viewer) and not viewer.capture_path.is_empty():
			record("FILE", "Close capture: filename=%s path=%s" % [viewer.capture_path.get_file(), ProjectSettings.globalize_path(viewer.capture_path)], true)
		record("APP", "Session ended", true)
		file.flush()
		file.close()
		file = null

func record(category: String, message: String, essential := false) -> void:
	if file == null or level == DISABLED or (level == MINIMAL and not essential): return
	var clean := message.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	if clean.length() > 8192: clean = clean.substr(0, 8192) + "…"
	var line := "%s.%03d  %-9s %s\n" % [Time.get_datetime_string_from_system().replace("T", " "), int(Time.get_unix_time_from_system() * 1000.0) % 1000, category, clean]
	var count := line.to_utf8_buffer().size()
	if bytes_written + count > MAX_SESSION_BYTES:
		file.close(); file = null
		return
	file.store_string(line)
	file.flush()
	if file.get_error() != OK:
		file.close(); file = null
		return
	bytes_written += count

func source_opened(source_path: String, success: bool) -> void:
	if success: last_seek_target = NAN
	record("FILE", "Open capture: filename=%s path=%s result=%s" % [source_path.get_file(), source_path, "ready" if success else "failed"], true)

func seek(previous: float, target: float) -> void:
	last_seek_target = target
	record("PLAYBACK", "Seek: %.5f → %.5f" % [previous, target], true)

func failure(owner: String, message: String) -> void:
	if message.is_empty(): return
	record("ERROR", "%s: %s" % [owner, message], true)
	_record_context(message)

func warning(message: String) -> void:
	record("WARNING", message, true)
	_record_context(message)

func _record_context(message: String) -> void:
	var context := "playback_t=%.5f frame=%d" % [viewer.requested_time, viewer.current_index + 1]
	if not viewer.capture_path.is_empty(): context += " source=" + viewer.capture_path.get_file()
	if is_finite(last_seek_target) and not is_equal_approx(last_seek_target, viewer.requested_time):
		context += " last_seek_target=%.5f" % last_seek_target
	if viewer.tools_ui != null and viewer.tools_ui.window != null and viewer.tools_ui.window.visible: context += " tool=" + viewer.tools_ui.current
	if viewer.selection_controller != null and viewer.selection_controller.target != null:
		var target: OptionButton = viewer.selection_controller.target
		if target.selected >= 0 and target.selected < target.item_count:
			context += " selection_object=" + str(target.get_item_metadata(target.selected))
	if viewer.selection_controller != null and ("memory" in message.to_lower() or "budget" in message.to_lower()):
		context += " analysis_budget_mib=%d" % (viewer.selection_controller.jobs.memory_bytes / 1048576)
	record("CONTEXT", context, true)

func _prune(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.begins_with("wavez-") and name.ends_with(".log"):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	var total := 0
	for item in names:
		var reader := FileAccess.open(directory.path_join(item), FileAccess.READ)
		if reader != null: total += reader.get_length(); reader.close()
	while names.size() > MAX_SESSIONS or (total > MAX_DIRECTORY_BYTES and names.size() > 1):
		var oldest: String = names.pop_front()
		var old_path := directory.path_join(oldest)
		var reader := FileAccess.open(old_path, FileAccess.READ)
		if reader != null: total -= reader.get_length(); reader.close()
		DirAccess.remove_absolute(old_path)

func _observe_tree(node: Node) -> void:
	_observe(node)
	for child in node.get_children(): _observe_tree(child)

func _observe(node: Node) -> void:
	if viewer == null or not viewer.is_ancestor_of(node) or node.has_meta("wavez_log_connected"): return
	if node is PopupMenu:
		node.id_pressed.connect(_menu_item.bind(node))
	elif node is FileDialog:
		node.file_selected.connect(func(selected): record("FILE", "File selected: " + selected))
		node.dir_selected.connect(func(selected): record("FILE", "Folder selected: " + selected))
	elif node is ItemList:
		node.item_selected.connect(func(index):
			if node.is_visible_in_tree() and index >= 0 and index < node.item_count:
				record("CONTROL", "%s → %s selected: %s" % [_scope(node), _label(node), node.get_item_text(index)]))
		node.multi_selected.connect(func(index, selected):
			if node.is_visible_in_tree() and index >= 0 and index < node.item_count:
				record("CONTROL", "%s → %s: %s = %s" % [_scope(node), _label(node), node.get_item_text(index), str(selected)]))
	elif node is OptionButton:
		node.item_selected.connect(_option_selected.bind(node))
	elif node is BaseButton:
		node.pressed.connect(_button_pressed.bind(node))
	elif node is LineEdit:
		if node.secret or node.get_parent() is SpinBox: return
		committed_text[node.get_instance_id()] = node.text
		node.focus_entered.connect(func(): committed_text[node.get_instance_id()] = node.text)
		node.text_submitted.connect(func(_value): _text_committed(node))
		node.focus_exited.connect(_text_committed.bind(node))
	elif node is SpinBox or node is Slider:
		if node == viewer.timeline: return
		node.value_changed.connect(_range_changed.bind(node))
		if node is Slider: node.drag_ended.connect(func(changed):
			if changed: _range_commit(node))
	else: return
	node.set_meta("wavez_log_connected", true)

func _scope(node: Node) -> String:
	if viewer.tools_ui != null and viewer.tools_ui.window != null and viewer.tools_ui.window.is_ancestor_of(node):
		return "Tools → " + viewer.tools_ui.current
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != viewer:
		if ancestor is Window and not ancestor.title.is_empty(): return ancestor.title
		ancestor = ancestor.get_parent()
	return "Viewer"

func _label(node: Control) -> String:
	if node is BaseButton and not node is OptionButton and not node.text.is_empty(): return node.text.strip_edges()
	if node is BaseButton and not node is OptionButton and not node.tooltip_text.is_empty():
		return node.tooltip_text.get_slice("\n", 0).strip_edges()
	var parent := node.get_parent()
	if parent != null:
		var earlier := ""
		for sibling in parent.get_children():
			if sibling == node: break
			if sibling is Label and not sibling.text.is_empty(): earlier = sibling.text.strip_edges()
		if not earlier.is_empty(): return earlier
	if not node.name.begins_with("@"): return node.name
	if not node.tooltip_text.is_empty(): return node.tooltip_text.get_slice("\n", 0).strip_edges()
	return node.get_class()

func _button_pressed(button: BaseButton) -> void:
	if not button.is_visible_in_tree() or button.disabled: return
	if button is MenuButton: return
	if button == viewer.play_button: return # The playback transition is logged by its controller.
	if viewer.shell != null and viewer.shell.transport != null and button == viewer.shell.transport.loop: return
	var caption := _scope(button)
	if button.text in ["Open…", "Details…", "Cancel"] and button.get_parent() != null:
		for sibling in button.get_parent().get_children():
			if sibling == button: break
			if sibling is Label and not sibling.text.is_empty(): caption += " → " + sibling.text.strip_edges(); break
	caption += " → " + _label(button)
	if button is CheckBox or button is CheckButton: caption += " = " + str(button.button_pressed)
	record("CONTROL", caption)

func _menu_item(id: int, popup: PopupMenu) -> void:
	var index := popup.get_item_index(id)
	if index < 0: return
	var parts := [popup.get_item_text(index)]
	if popup.has_meta("wavez_menu_label"): parts.push_front(str(popup.get_meta("wavez_menu_label")))
	var ancestor: Node = popup.get_parent()
	while ancestor != null and ancestor != viewer:
		if ancestor is OptionButton: return # OptionButton.item_selected logs the same choice with its control label.
		if ancestor is PopupMenu and ancestor.has_meta("wavez_menu_label"): parts.push_front(str(ancestor.get_meta("wavez_menu_label")))
		elif ancestor is MenuButton: parts.push_front(ancestor.text)
		ancestor = ancestor.get_parent()
	record("MENU", " → ".join(parts))

func _option_selected(index: int, option: OptionButton) -> void:
	if not option.is_visible_in_tree() or index < 0 or index >= option.item_count: return
	if viewer.shell != null and viewer.shell.transport != null and option == viewer.shell.transport.rate: return
	record("CONTROL", "%s → %s = %s" % [_scope(option), _label(option), option.get_item_text(index)])

func _text_committed(field: LineEdit) -> void:
	if not is_instance_valid(field) or not field.is_visible_in_tree(): return
	var id := field.get_instance_id()
	if committed_text.get(id, field.text) == field.text: return
	committed_text[id] = field.text
	var label := _label(field)
	var lower := label.to_lower()
	var value := "[redacted]" if "password" in lower or "secret" in lower or "token" in lower or "credential" in lower or "api key" in lower else field.text
	record("CONTROL", "%s → %s = %s" % [_scope(field), label, value])

func _range_changed(_value: float, control: Range) -> void:
	if not control.is_visible_in_tree(): return
	if not control.has_focus() and not (control.get_global_rect().has_point(control.get_global_mouse_position()) and Input.is_anything_pressed()): return
	pending_ranges[control.get_instance_id()] = {"control": weakref(control), "at": Time.get_ticks_msec()}
	set_process(true)

func _range_commit(control: Range) -> void:
	if not is_instance_valid(control): return
	pending_ranges.erase(control.get_instance_id())
	record("CONTROL", "%s → %s = %s" % [_scope(control), _label(control), str(control.value)])
	if pending_ranges.is_empty(): set_process(false)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for id in pending_ranges.keys():
		var pending: Dictionary = pending_ranges[id]
		if now - int(pending.at) < 350: continue
		pending_ranges.erase(id)
		var control = pending.control.get_ref()
		if is_instance_valid(control): _range_commit(control)
	if pending_ranges.is_empty(): set_process(false)
