extends Control
## Flat modal preferences surface; all edits remain local until Apply succeeds.
const Bindings = preload("res://ui/keyboard_shortcuts.gd")
var shell
var staged := {}
var listening := ""
var panel: PanelContainer
var scroller: ScrollContainer
var rows := {}
var notice: Label
var footer: HBoxContainer
var cancel: Button
var apply_button: Button
var close_button: Button
var previous_focus: WeakRef
var reset: Button
var focus_order: Array[Control] = []

func setup(owner_shell) -> void:
	shell = owner_shell
	name = "KeyboardShortcuts"
	theme = shell.style_slice.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, .45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	panel = PanelContainer.new(); add_child(panel)
	panel.add_theme_stylebox_override("panel", theme.flat_box(&"surface.1", 20, 16, 0))
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); panel.add_child(box)
	var header := HBoxContainer.new(); box.add_child(header)
	var title := Label.new(); title.text = "Keyboard Shortcuts"; title.theme_type_variation = "PanelTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	close_button = shell.close_action(header, dismiss, "")
	scroller = ScrollContainer.new(); scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroller.follow_focus = true; box.add_child(scroller)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4); scroller.add_child(list)
	var group := ""
	for action in Bindings.ACTIONS:
		if action[2] != group:
			group = action[2]
			var heading := Label.new(); heading.text = group; heading.theme_type_variation = "PropertyLabel"
			heading.add_theme_color_override("font_color", theme.c(&"text.secondary")); list.add_child(heading)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); list.add_child(row)
		var label := Label.new(); label.text = action[1]; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true; label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; row.add_child(label)
		var key := Button.new(); key.custom_minimum_size = Vector2(152, 32); key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		key.theme_type_variation = "SecondaryButton"; key.pressed.connect(start_capture.bind(action[0])); row.add_child(key)
		var clear := Button.new(); clear.text = "Clear"; clear.custom_minimum_size.y = 32
		clear.pressed.connect(clear_binding.bind(action[0])); row.add_child(clear)
		rows[action[0]] = {"key":key, "clear":clear, "label":label}
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.theme_type_variation = "PropertyLabel"; box.add_child(notice); notice.hide()
	footer = HBoxContainer.new(); footer.add_theme_constant_override("separation", 8); box.add_child(footer)
	reset = Button.new(); reset.text = "Reset Defaults"; footer.add_child(reset)
	reset.pressed.connect(func(): staged = Bindings.defaults(); listening = ""; notice.hide(); refresh_rows())
	var space := Control.new(); space.size_flags_horizontal = Control.SIZE_EXPAND_FILL; footer.add_child(space)
	cancel = Button.new(); cancel.text = "Cancel"; cancel.pressed.connect(dismiss); footer.add_child(cancel)
	apply_button = Button.new(); apply_button.text = "Apply"; apply_button.theme_type_variation = "PrimaryButton"; apply_button.disabled = true
	apply_button.pressed.connect(commit); footer.add_child(apply_button)
	get_window().size_changed.connect(fit.call_deferred)
	hide()

func open() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focused) if focused != null else null
	staged = shell.shortcuts.active.duplicate(); listening = ""
	notice.hide()
	refresh_rows(); scroller.scroll_vertical = 0; show(); fit(); fit.call_deferred()
	rows.reset_camera.key.grab_focus()

func dismiss() -> void:
	listening = ""; staged.clear(); hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused): focused.release_focus()
	if previous_focus != null:
		var prior = previous_focus.get_ref()
		if is_instance_valid(prior) and prior.is_visible_in_tree(): prior.grab_focus()
	previous_focus = null

func commit() -> void:
	if apply_button.disabled: return
	var changed: Array[String] = []
	for action in staged:
		if staged[action] != shell.shortcuts.active.get(action, 0): changed.append(action)
	var error: Error = shell.shortcuts.apply(staged)
	if error != OK:
		notice.text = "Could not save shortcuts: " + error_string(error) + ". Current bindings are unchanged."
		notice.show(); fit.call_deferred()
		return
	if shell.viewer.session_log != null:
		for action in changed:
			shell.viewer.session_log.record("CONTROL", "Shortcut %s = %s" % [action, Bindings.text(shell.shortcuts.active[action])])
	shell.refresh_shortcut_hints()
	staged = shell.shortcuts.active.duplicate(); listening = ""; notice.hide(); refresh_rows()
	if apply_button.has_focus(): cancel.grab_focus()

func start_capture(action: String) -> void:
	listening = action; notice.hide(); refresh_rows()
	rows[action].key.grab_focus()

func clear_binding(action: String) -> void:
	listening = ""; staged[action] = 0; notice.hide(); refresh_rows()

func refresh_rows() -> void:
	apply_button.disabled = staged == shell.shortcuts.active
	focus_order.assign([close_button])
	for action in rows:
		var row: Dictionary = rows[action]
		row.key.text = "Press a key…" if action == listening else Bindings.text(staged[action])
		row.key.theme_type_variation = "SelectedButton" if action == listening else "SecondaryButton"
		var context: String = shell.shortcut_context(action)
		row.label.add_theme_color_override("font_color", theme.c(&"text.primary" if context.is_empty() else &"text.secondary"))
		row.clear.disabled = staged[action] == 0
		focus_order.append(row.key)
		if not row.clear.disabled: focus_order.append(row.clear)
	focus_order.append_array([reset, cancel])
	if not apply_button.disabled: focus_order.append(apply_button)
	for index in focus_order.size():
		var control: Control = focus_order[index]
		var previous := control.get_path_to(focus_order[posmod(index - 1, focus_order.size())])
		var next := control.get_path_to(focus_order[(index + 1) % focus_order.size()])
		control.focus_previous = previous; control.focus_next = next
		control.focus_neighbor_top = previous; control.focus_neighbor_left = previous
		control.focus_neighbor_bottom = next; control.focus_neighbor_right = next

func handle_input(event: InputEvent) -> bool:
	if not visible or not event is InputEventKey: return false
	if not event.pressed or event.echo: return not listening.is_empty()
	if event.keycode == KEY_ESCAPE:
		if listening.is_empty(): dismiss()
		else:
			listening = ""; notice.hide(); refresh_rows()
		return true
	if listening.is_empty(): return false
	var value := Bindings.binding(event)
	if value == 0: return true
	var action := listening
	Bindings.assign(staged, action, value); listening = ""; notice.hide(); refresh_rows()
	return true

func fit() -> void:
	if not visible: return
	var extent := get_viewport_rect().size
	panel.size = Vector2(minf(640, extent.x - 32), minf(560, extent.y - 32))
	panel.position = (extent - panel.size) * .5
