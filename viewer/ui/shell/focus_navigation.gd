extends Node
## Event-driven, live visual-order Tab traversal. No frame polling or numeric tab IDs.
var shell
var main_window: Window
var windows: Array[WeakRef] = []
var watched := {}
var positions := {}
var origins := {}
var handoffs := {}
var restores: Array = []
var overlay_origins := {}
var queued := false
var installed := false
var reconciliations := 0

func setup(owner_shell) -> void:
	shell = owner_shell; main_window = shell.get_window()
	set_process(false)
	get_tree().node_added.connect(watch)
	watch_branch(shell.viewer)
	watch(main_window)
	shell.scroll.follow_focus = true
	installed = true

func watch_branch(node: Node) -> void:
	watch(node)
	for child in node.get_children(true): watch_branch(child)

func watch(node: Node) -> void:
	if not (node is Control or node is Window) or watched.has(node.get_instance_id()): return
	if node != main_window and not shell.viewer.is_ancestor_of(node): return
	watched[node.get_instance_id()] = weakref(node)
	if node is Window:
		node.gui_focus_changed.connect(focus_changed.bind(node))
		if node != main_window:
			node.visibility_changed.connect(window_visibility.bind(node))
			if not node is PopupMenu:
				var input := preload("res://ui/shell/focus_scope_input.gd").new()
				input.navigation = self; node.add_child(input)
	elif node is Control:
		node.visibility_changed.connect(visibility_changed.bind(node))
		node.tree_exiting.connect(removing.bind(node, true))
		node.tree_exited.connect(request_reconcile)
		if node == shell.orbit_editor or node == shell.shortcuts_editor:
			node.visibility_changed.connect(overlay_visibility.bind(node))

func request_reconcile() -> void:
	if queued or not installed: return
	queued = true; reconcile.call_deferred()

func region_roots() -> Array:
	# Actual screen order: camera/application bar, viewport-adjacent actions,
	# Simulation header/content, then playback and status/Jobs.
	return [shell.bar, shell.empty, shell.open_error, shell.orbit_editor, shell.dock, shell.bottom_strip, shell.shortcuts_editor]

func active_overlay() -> Control:
	for overlay in [shell.shortcuts_editor, shell.orbit_editor]:
		if overlay != null and overlay.is_visible_in_tree(): return overlay
	return null

func collect(node: Node, scope: Window, result: Array) -> void:
	if node == null or (node is Window and node != scope): return
	if node is Control and not node is SpinBox and node.focus_mode == Control.FOCUS_ALL: result.append(node)
	for child in node.get_children(true): collect(child, scope, result)

func chain(scope: Window, visible_only := true) -> Array:
	var result: Array = []
	if scope == main_window:
		for region in region_roots(): collect(region, scope, result)
	else: collect(scope, scope, result)
	if visible_only:
		var overlay := active_overlay() if scope == main_window else null
		if overlay != null:
			result = result.filter(func(control): return overlay.is_ancestor_of(control))
		result = result.filter(func(control): return eligible(control, scope))
	return result

func eligible(control, scope: Window) -> bool:
	if not is_instance_valid(control) or not control is Control: return false
	if control.get_viewport() != scope or not control.is_visible_in_tree() or control.is_queued_for_deletion(): return false
	if control.focus_mode != Control.FOCUS_ALL: return false
	if control is BaseButton and control.disabled: return false
	if control is Slider and not control.editable: return false
	if control is LineEdit and not control.editable: return false
	if control.get_parent() is SpinBox and not control.get_parent().editable: return false
	return true

func snapshot(control: Control, scope: Window) -> Dictionary:
	var order: Array = []; var ids: Array = []
	for item in chain(scope, false):
		order.append(weakref(item)); ids.append(item.get_instance_id())
	var ancestors: Array = []; var node: Node = control
	while node != null and node != scope:
		ancestors.append(weakref(node)); node = node.get_parent()
	return {"control":weakref(control), "control_id":control.get_instance_id(), "scope":weakref(scope), "order":order, "ids":ids, "ancestors":ancestors}

func focus_changed(control: Control, scope: Window) -> void:
	if control != null and eligible(control, scope): positions[scope.get_instance_id()] = snapshot(control, scope)

func hidden_region(position: Dictionary, fallback: Node) -> Node:
	var region := fallback
	for ref in position.ancestors:
		var node = ref.get_ref()
		if node is Control and not node.is_visible_in_tree(): region = node
	return region

func removal(position: Dictionary, region: Node) -> Dictionary:
	var cutoff: int = position.ids.find(position.control_id) if region == null else -1
	for i in position.order.size():
		var control = position.order[i].get_ref()
		if region != null and is_instance_valid(control) and (control == region or region.is_ancestor_of(control)): cutoff = i
	return {"position":position, "cutoff":cutoff}

func visibility_changed(control: Control) -> void:
	if control.is_visible_in_tree(): return # Revealing never pulls focus back.
	removing(control)

func removing(control: Control, leaving_tree := false) -> void:
	var scope = control.get_viewport()
	if not scope is Window or not positions.has(scope.get_instance_id()): return
	var position: Dictionary = positions[scope.get_instance_id()]
	var focused = position.control.get_ref()
	if not is_instance_valid(focused) or not (focused == control or control.is_ancestor_of(focused)): return
	var region := hidden_region(position, control)
	var id := scope.get_instance_id()
	var record := removal(position, region)
	record["leaving_tree"] = leaving_tree or handoffs.get(id, {}).get("leaving_tree", false)
	handoffs[id] = record
	request_reconcile()

func successor(record: Dictionary, scope: Window) -> Control:
	var available := chain(scope)
	if available.is_empty(): return null
	var order: Array = record.position.order
	for offset in order.size():
		var index: int = posmod(record.cutoff + 1 + offset, order.size())
		var candidate = order[index].get_ref()
		if candidate in available: return candidate
	# A source rebuild can replace the entire old region with new controls.
	return available[0]

func active_window() -> Window:
	for i in range(windows.size()-1, -1, -1):
		var window = windows[i].get_ref()
		if is_instance_valid(window) and window.visible and not window.is_queued_for_deletion(): return window
	return main_window

func begin_overlay(control: Control) -> void:
	if not control.visible:
		overlay_origins[control.get_instance_id()] = positions.get(main_window.get_instance_id(), {})

func overlay_visibility(control: Control) -> void:
	var id := control.get_instance_id()
	if not control.visible and overlay_origins.has(id):
		restores.append(overlay_origins[id]); overlay_origins.erase(id); request_reconcile()

func window_visibility(window: Window) -> void:
	if window is PopupMenu: return # Native menu selection/arrow handling stays native.
	var id := window.get_instance_id()
	if window.visible:
		var scope := active_window()
		var origin: Dictionary = positions.get(scope.get_instance_id(), {})
		origins[id] = origin
		windows.append(weakref(window))
	else:
		if origins.has(id): restores.append(origins[id]); origins.erase(id)
		windows = windows.filter(func(ref): return ref.get_ref() != window and ref.get_ref() != null)
	request_reconcile()

func restore_position(position: Dictionary, scope: Window) -> void:
	if position.is_empty() or position.scope.get_ref() != scope: return
	var control = position.control.get_ref()
	if eligible(control, scope): control.grab_focus(); return
	var fallback: Node = control if is_instance_valid(control) else null
	var region := hidden_region(position, fallback)
	var record: Dictionary
	if region != null: record = removal(position, region)
	else:
		# A removed initiator has no live node; advance from its saved position.
		var cutoff := -1
		for i in position.order.size():
			if position.ids[i] == position.control_id: cutoff = i
		record = {"position":position, "cutoff":cutoff}
	var next := successor(record, scope)
	if next != null: next.grab_focus()

func reconcile() -> void:
	queued = false; reconciliations += 1
	for id in watched.keys():
		if watched[id].get_ref() == null: watched.erase(id)
	if not is_instance_valid(shell) or shell.viewer.offline_instance: return
	var scope := active_window()
	var id := scope.get_instance_id()
	if handoffs.has(id):
		var record: Dictionary = handoffs[id]; handoffs.erase(id)
		var original = record.position.control.get_ref()
		if record.leaving_tree and eligible(original, scope):
			# Responsive layout can reparent an available control in the same turn.
			if not eligible(scope.gui_get_focus_owner(), scope): original.grab_focus()
		else:
			var next := successor(record, scope)
			if next != null: next.grab_focus()
			else:
				var focused := scope.gui_get_focus_owner()
				if focused != null: focused.release_focus()
	for position in restores: restore_position(position, scope)
	restores.clear()
	if scope != main_window and not eligible(scope.gui_get_focus_owner(), scope):
		var available := chain(scope)
		if not available.is_empty(): available[0].grab_focus()

func menus_open() -> bool:
	for ref in watched.values():
		var node = ref.get_ref()
		if node is PopupMenu and node.visible: return true
	return false

func traverse(scope: Window, reverse := false) -> void:
	var available := chain(scope)
	if available.is_empty(): return
	var focused := scope.gui_get_focus_owner()
	var index := available.find(focused)
	var next: Control
	if index >= 0: next = available[posmod(index + (-1 if reverse else 1), available.size())]
	elif positions.has(scope.get_instance_id()):
		var position: Dictionary = positions[scope.get_instance_id()]
		if not reverse:
			next = successor(removal(position, hidden_region(position, position.control.get_ref())), scope)
		else: next = available[-1]
	else: next = available[-1] if reverse else available[0]
	shell.edge_reveal.keyboard_navigation = true
	next.grab_focus()

func handle(event: InputEvent, receiver: Window) -> void:
	if not event is InputEventKey or not event.pressed or event.keycode != KEY_TAB: return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or menus_open(): return
	if shell.editing_shortcuts() and not shell.shortcuts_editor.listening.is_empty(): return
	reconcile()
	traverse(active_window(), event.shift_pressed)
	receiver.set_input_as_handled()

func _input(event: InputEvent) -> void: handle(event, main_window)
