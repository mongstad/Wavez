extends Node
const Viewer = preload("res://main.gd")
const Bindings = preload("res://ui/keyboard_shortcuts.gd")
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
var output := ""
var restart := false
var speed_only := false
var orbit_only := false
var tooltip_only := false
var checks := 0
var failures: Array[String] = []
var layouts: Array = []
@onready var root: Window = get_tree().root

func _ready() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)
func settle() -> void:
	for i in 8: await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func key(value: int) -> void:
	var event := InputEventKey.new(); event.keycode = value & KEY_CODE_MASK; event.pressed = true
	event.ctrl_pressed = bool(value & KEY_MASK_CTRL); event.shift_pressed = bool(value & KEY_MASK_SHIFT)
	event.alt_pressed = bool(value & KEY_MASK_ALT); event.meta_pressed = bool(value & KEY_MASK_META)
	root.push_input(event)
	event = event.duplicate(); event.pressed = false; root.push_input(event)
func release_focus() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
func trigger(shell, action: String) -> void:
	release_focus(); key(shell.shortcuts.active[action])
func unique(map: Dictionary) -> bool:
	var seen := {}
	for value in map.values():
		if value == 0: continue
		if seen.has(value): return false
		seen[value] = true
	return true
func speed_move(viewer) -> void:
	release_focus()
	var before: Transform3D = viewer.camera.transform
	var target: Vector3 = viewer.camera_target
	var expected: float = .1 * maxf(1, viewer.camera_distance * .5) * viewer.free_camera_speed_scale
	var event := InputEventKey.new(); event.physical_keycode = KEY_W; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	viewer._move_free_camera(.1)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
	check(is_equal_approx(viewer.camera.position.distance_to(before.origin), expected) and viewer.camera_target != target and viewer.camera.basis.is_equal_approx(before.basis), "Adjusted speed controls packaged and source camera translation without rotating the view")
func navigation_review(viewer, shell, label: String) -> void:
	check(shell.shortcuts.active.free_camera == KEY_F and shell.shortcuts.active.auto_orbit == KEY_O and shell.shortcuts.active.frame_scene == KEY_R and shell.shortcuts.active.reset_camera == 0 and unique(shell.shortcuts.active), label + " F and O have distinct unique owners")
	var f_event := InputEventKey.new(); f_event.keycode = KEY_F; f_event.pressed = true
	check(shell.shortcuts.match_action(f_event) == "free_camera", label + " one F key resolves only to Free Camera")
	viewer.free_camera = true; viewer.orbit_enabled = false
	trigger(shell,"free_camera")
	check(not viewer.free_camera and not viewer.orbit_enabled, label + " F turns Free Camera off without enabling Auto Orbit")
	trigger(shell,"free_camera")
	check(viewer.free_camera and not viewer.orbit_enabled, label + " F turns Free Camera on with Auto Orbit still off")
	trigger(shell,"auto_orbit")
	check(viewer.free_camera and viewer.orbit_enabled, label + " O enables Auto Orbit without changing Free Camera")
	trigger(shell,"free_camera")
	check(not viewer.free_camera and viewer.orbit_enabled, label + " F turns Free Camera off with Auto Orbit on")
	trigger(shell,"free_camera")
	check(viewer.free_camera and viewer.orbit_enabled, label + " F turns Free Camera on with Auto Orbit on")
	trigger(shell,"auto_orbit")
	check(viewer.free_camera and not viewer.orbit_enabled, label + " O disables Auto Orbit without changing Free Camera")
	trigger(shell,"free_camera"); trigger(shell,"auto_orbit")
	check(not viewer.free_camera and viewer.orbit_enabled, label + " O enables Auto Orbit with Free Camera off")
	trigger(shell,"auto_orbit")
	check(not viewer.free_camera and not viewer.orbit_enabled, label + " O disables Auto Orbit with Free Camera off")
	trigger(shell,"free_camera")
	var modes: PopupMenu = shell.navigation.get_child(2).get_popup()
	modes.id_pressed.emit(0)
	check(not viewer.free_camera and not viewer.orbit_enabled, label + " Navigate Free camera changes only Free Camera")
	modes.id_pressed.emit(1)
	check(not viewer.free_camera and viewer.orbit_enabled, label + " Navigate Auto orbit changes only Auto Orbit")
	modes.id_pressed.emit(0)
	check(viewer.free_camera and viewer.orbit_enabled, label + " Navigate Free camera restores only Free Camera")
	modes.id_pressed.emit(1)
	check(viewer.free_camera and not viewer.orbit_enabled, label + " Navigate Auto orbit restores only Auto Orbit")
	shell.navigation.get_child(2).about_to_popup.emit()
	check(modes.is_item_checked(0) and not modes.is_item_checked(1), label + " Navigate checks reflect the independent final states")
func picture(name: String) -> void:
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func check_no_dialog_tooltips(dialog, context: String) -> void:
	var controls: Array = [dialog]
	controls.append_array(dialog.find_children("*", "Control", true, false))
	var offenders: Array[String] = []
	for control in controls:
		if not control.tooltip_text.is_empty(): offenders.append(str(control.get_path()))
	check(controls.size() >= Bindings.ACTIONS.size() * 4 and offenders.is_empty(), context + ": all shortcut rows, headings, footer and close controls have no tooltip text " + str(offenders))
func tooltip_review(shell) -> void:
	shell.edit_shortcuts(); await settle()
	var dialog = shell.shortcuts_editor
	check(dialog.visible and dialog.rows.size() == Bindings.ACTIONS.size(), "Keyboard Shortcuts opens with every action")
	check_no_dialog_tooltips(dialog, "Initial dialog")
	check(not shell.navigation.get_child(1).tooltip_text.is_empty(), "Outside Reset Camera control keeps its tooltip")
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(dialog.rows.reset_camera.key.get_global_rect().get_center())
		await get_tree().create_timer(.7).timeout
		picture("shortcuts-hover-no-tooltip")
	dialog.start_capture("reset_camera"); check_no_dialog_tooltips(dialog, "Listening for a key")
	key(KEY_ESCAPE)
	dialog.clear_binding("reset_camera"); check_no_dialog_tooltips(dialog, "After Clear")
	dialog.start_capture("frame_scene"); key(KEY_R)
	check(dialog.staged.reset_camera == 0 and dialog.staged.frame_scene == KEY_R, "Conflicting key transfers in draft")
	check_no_dialog_tooltips(dialog, "After key transfer")
	dialog.reset.pressed.emit(); check_no_dialog_tooltips(dialog, "After Reset Defaults")
	dialog.rows.previous_category.key.grab_focus(); await settle()
	check(dialog.scroller.scroll_vertical > 0, "Last shortcut scrolls into view")
	check_no_dialog_tooltips(dialog, "After scrolling")
	dialog.dismiss()
func wait_ready(viewer) -> void:
	for i in 1000:
		viewer.scene_layers.tick(.01)
		if not viewer.scene_layers.is_buffering(): return
		await get_tree().create_timer(.01).timeout
	check(false, "Fixture preparation completes")

func speed_shortcut_review(viewer, shell) -> void:
	if restart:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("saved-map.json")))
		for action in saved: saved[action] = int(saved[action])
		check(shell.shortcuts.active == saved and unique(saved), "Fresh process restores both rebound speed keys without conflicts")
		var rate: float = viewer.free_camera_speed_scale
		trigger(shell, "increase_camera_speed")
		check(is_equal_approx(viewer.free_camera_speed_scale, rate * 1.10), "Restarted increase key adjusts movement speed")
		trigger(shell, "decrease_camera_speed")
		check(is_equal_approx(viewer.free_camera_speed_scale, rate * 1.10 * .90), "Restarted decrease key adjusts movement speed")
		speed_move(viewer)
		return
	check(shell.shortcuts.active.increase_camera_speed == KEY_PLUS and shell.shortcuts.active.decrease_camera_speed == KEY_MINUS, "Fresh profile uses logical + and - defaults")
	shell.edit_shortcuts(); await settle()
	var dialog = shell.shortcuts_editor
	check(dialog.visible and dialog.rows.has("increase_camera_speed") and dialog.rows.has("decrease_camera_speed"), "Both speed actions appear in the existing editor")
	check(dialog.rows.increase_camera_speed.label.text == "Increase Camera Movement Speed" and dialog.rows.decrease_camera_speed.label.text == "Decrease Camera Movement Speed", "Speed row labels explain their actions")
	dialog.start_capture("increase_camera_speed")
	var us_plus := InputEventKey.new(); us_plus.keycode = KEY_EQUAL; us_plus.unicode = KEY_PLUS; us_plus.shift_pressed = true; us_plus.pressed = true
	root.push_input(us_plus)
	us_plus = us_plus.duplicate(); us_plus.pressed = false; root.push_input(us_plus)
	check(dialog.staged.increase_camera_speed == KEY_PLUS and dialog.apply_button.disabled, "US Shift+= captures logical + without changing the default")
	dialog.start_capture("increase_camera_speed"); key(KEY_F6)
	dialog.start_capture("decrease_camera_speed"); key(KEY_F6)
	check(dialog.staged.increase_camera_speed == 0 and dialog.staged.decrease_camera_speed == KEY_F6 and unique(dialog.staged), "Speed key conflict unbinds the prior draft owner")
	dialog.cancel.pressed.emit(); await settle()
	check(not dialog.visible and shell.shortcuts.active == Bindings.defaults() and not FileAccess.file_exists(shell.shortcuts.storage_path), "Cancel discards both staged speed edits")
	shell.edit_shortcuts()
	dialog.start_capture("increase_camera_speed"); key(KEY_F6)
	dialog.start_capture("decrease_camera_speed"); key(KEY_F7)
	dialog.apply_button.pressed.emit(); await settle()
	check(dialog.visible and dialog.apply_button.disabled and shell.shortcuts.active.increase_camera_speed == KEY_F6 and shell.shortcuts.active.decrease_camera_speed == KEY_F7 and unique(shell.shortcuts.active), "Apply persists and activates both rebound speed actions")
	dialog.reset.pressed.emit()
	check(dialog.staged.increase_camera_speed == KEY_PLUS and dialog.staged.decrease_camera_speed == KEY_MINUS and not dialog.apply_button.disabled, "Reset Defaults stages both logical speed keys")
	dialog.cancel.pressed.emit(); await settle()
	check(shell.shortcuts.active.increase_camera_speed == KEY_F6 and shell.shortcuts.active.decrease_camera_speed == KEY_F7, "Cancel after Apply keeps the persisted rebound keys")
	var rate: float = viewer.free_camera_speed_scale
	trigger(shell, "increase_camera_speed")
	check(is_equal_approx(viewer.free_camera_speed_scale, rate * 1.10), "Applied increase key works immediately")
	trigger(shell, "decrease_camera_speed")
	check(is_equal_approx(viewer.free_camera_speed_scale, rate * 1.10 * .90), "Applied decrease key works immediately")
	speed_move(viewer)
	var file := FileAccess.open(output.path_join("saved-map.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(shell.shortcuts.active)); file.close()

func orbit_shortcut_move(viewer, action: String) -> void:
	release_focus()
	viewer.orbit_enabled = true
	var before: Transform3D = viewer.camera.transform
	var target: Vector3 = viewer.camera_target
	var radius: float = viewer.camera_distance
	var speed: float = viewer.free_camera_speed_scale
	var event: InputEventKey = viewer.shell.shortcuts.event_for(action); event.pressed = true
	root.push_input(event)
	check(not viewer.orbit_enabled and viewer.manual_orbit_keys.has(action),action+": native key dispatch takes control immediately")
	viewer._update_manual_orbit(.1)
	var angle: float = viewer.MANUAL_ORBIT_RATE*.1 * (-1 if action == "orbit_camera_left" else 1)
	var expected := (Basis(before.basis.y.normalized(),angle)*before.basis).orthonormalized()
	check(viewer.camera.basis.is_equal_approx(expected) and viewer.camera_target == target and viewer.camera_distance == radius and viewer.free_camera_speed_scale == speed,action+": applied binding performs view-relative orbit only")
	event = event.duplicate(); event.pressed = false; root.push_input(event)
	check(viewer.manual_orbit_keys.is_empty(),action+": native key release stops the hold")

func orbit_shortcut_review(viewer, shell) -> void:
	if restart:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("saved-map.json")))
		for action in saved: saved[action] = int(saved[action])
		check(shell.shortcuts.active == saved and unique(saved),"Fresh process restores both orbit bindings without conflicts")
		for action in ["orbit_camera_left","orbit_camera_right"]: orbit_shortcut_move(viewer,action)
		return
	check(shell.shortcuts.active == Bindings.defaults() and shell.shortcuts.active.orbit_camera_left == 0 and shell.shortcuts.active.orbit_camera_right == 0,"Both orbit actions start Unbound without changing existing defaults")
	for action in Bindings.ACTIONS:
		if action[0] in ["orbit_camera_left","orbit_camera_right"]: check(action[2] == "Navigation","Orbit action uses authoritative Navigation category")
	shell.edit_shortcuts(); await settle()
	var dialog = shell.shortcuts_editor
	check(dialog.rows.orbit_camera_left.label.text == "Orbit Camera Left" and dialog.rows.orbit_camera_right.label.text == "Orbit Camera Right","Both orbit labels appear in the existing editor")
	check(dialog.rows.orbit_camera_left.key.text == "Unbound" and dialog.rows.orbit_camera_right.key.text == "Unbound","Visible orbit binding labels start Unbound")
	dialog.start_capture("orbit_camera_left"); key(KEY_F6)
	dialog.start_capture("orbit_camera_right"); key(KEY_F6)
	check(dialog.staged.orbit_camera_left == 0 and dialog.staged.orbit_camera_right == KEY_F6 and unique(dialog.staged),"Orbit conflict transfers the draft binding to its last owner")
	dialog.cancel.pressed.emit(); await settle()
	check(not dialog.visible and shell.shortcuts.active == Bindings.defaults() and not FileAccess.file_exists(shell.shortcuts.storage_path),"Cancel discards orbit edits without writing preferences")
	shell.edit_shortcuts()
	dialog.start_capture("orbit_camera_left"); key(KEY_F6)
	dialog.start_capture("orbit_camera_right"); key(KEY_F7)
	dialog.apply_button.pressed.emit(); await settle()
	check(dialog.visible and dialog.apply_button.disabled and shell.shortcuts.active.orbit_camera_left == KEY_F6 and shell.shortcuts.active.orbit_camera_right == KEY_F7,"Apply persists and activates both orbit keys while keeping the editor open")
	var before: Transform3D = viewer.camera.transform
	key(KEY_F6); viewer._update_manual_orbit(.1)
	check(viewer.camera.transform == before and viewer.manual_orbit_keys.is_empty(),"Modal editor blocks orbit navigation after Apply")
	picture("orbit-shortcuts")
	dialog.rows.orbit_camera_left.clear.pressed.emit()
	check(dialog.staged.orbit_camera_left == 0 and not dialog.apply_button.disabled,"Clear stages an Unbound orbit action")
	dialog.reset.pressed.emit()
	check(dialog.staged.orbit_camera_left == 0 and dialog.staged.orbit_camera_right == 0,"Reset Defaults stages both orbit actions as Unbound")
	dialog.cancel.pressed.emit(); await settle()
	check(shell.shortcuts.active.orbit_camera_left == KEY_F6 and shell.shortcuts.active.orbit_camera_right == KEY_F7,"Cancel after Apply preserves saved orbit keys")
	for action in ["orbit_camera_left","orbit_camera_right"]: orbit_shortcut_move(viewer,action)
	var saved := FileAccess.open(output.path_join("saved-map.json"),FileAccess.WRITE)
	saved.store_string(JSON.stringify(shell.shortcuts.active)); saved.close()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shortcut-output="): output = argument.trim_prefix("--shortcut-output=")
		if argument == "--shortcut-restart": restart = true
		if argument == "--shortcut-speed-only": speed_only = true
		if argument == "--shortcut-orbit-only": orbit_only = true
		if argument == "--shortcut-tooltip-only": tooltip_only = true
	if output.is_empty(): queue_free(); return
	get_tree().create_timer(120).timeout.connect(func(): push_error("Shortcut tests timed out"); get_tree().quit(1))
	await get_tree().process_frame
	var viewer = get_tree().current_scene
	if viewer == null:
		viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	viewer.set_process(false)
	var shell = viewer.shell
	if tooltip_only:
		await tooltip_review(shell)
		finish(viewer); return
	if speed_only:
		await speed_shortcut_review(viewer, shell)
		finish(viewer); return
	if orbit_only:
		await orbit_shortcut_review(viewer, shell)
		finish(viewer); return
	check(Bindings.ACTIONS.any(func(action): return action[0] == "open_capture" and action[1] == "Open File"), "Open shortcut has current visible label")
	check(viewer.open_dialog.use_native_dialog and viewer.open_dialog.title == "Open File", "Open route keeps native scene picker configured")
	check(not viewer.orbit_enabled and viewer.free_camera, "Fresh viewer starts with Auto Orbit off and Free Camera on")
	if restart:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("saved-map.json")))
		for action in saved: saved[action] = int(saved[action]) # JSON numbers decode as floats.
		check(shell.shortcuts.active == saved, "Fresh application process restores every saved and unbound binding")
		shell.edit_shortcuts(); await settle()
		check_no_dialog_tooltips(shell.shortcuts_editor, "Restarted editor")
		shell.shortcuts_editor.dismiss()
		check(unique(shell.shortcuts.active), "Restart has no duplicate bindings")
		check(shell.shortcuts.active.reset_camera == 0 and shell.shortcuts.active.frame_scene == KEY_R, "Duplicate transfer survives restart")
		var restart_speed: float = viewer.free_camera_speed_scale
		trigger(shell, "increase_camera_speed")
		check(is_equal_approx(viewer.free_camera_speed_scale, restart_speed * 1.10), "Persisted increase shortcut works after restart")
		trigger(shell, "decrease_camera_speed")
		check(is_equal_approx(viewer.free_camera_speed_scale, restart_speed * 1.10 * .90), "Persisted decrease shortcut works after restart")
		navigation_review(viewer, shell, "Restart")
		viewer.yaw = 1.7; viewer._update_camera(); var before: Transform3D = viewer.camera.transform
		trigger(shell, "frame_scene")
		check(viewer.camera.transform == before, "Restart uses new Frame Scene binding; old Reset Camera does not fire")
		var offline = Viewer.new(); offline.offline_instance = true; root.add_child(offline); offline.set_process(false)
		check(offline.shell.shortcuts.active == Bindings.defaults(), "Offline viewer does not consume interactive preferences")
		offline.free()
		finish(viewer); return
	check(shell.shortcuts.active == Bindings.defaults(), "New profile preserves accepted default shortcuts")
	check(shell.shortcuts.active.auto_orbit == KEY_O and shell.shortcuts.active.free_camera == 0, "Existing Auto Orbit and Free Camera bindings retain O and Unbound defaults")
	check(shell.shortcuts.active.increase_camera_speed == KEY_PLUS and shell.shortcuts.active.decrease_camera_speed == KEY_MINUS, "Movement speed defaults are logical + and -")
	var navigation_actions := {"auto_orbit":0, "free_camera":0}
	for action in Bindings.ACTIONS:
		if navigation_actions.has(action[0]): navigation_actions[action[0]] += 1
	check(navigation_actions.auto_orbit == 1 and navigation_actions.free_camera == 1, "Navigation actions appear once each in the editable catalog")
	var modes: PopupMenu = shell.navigation.get_child(2).get_popup()
	shell.navigation.get_child(2).about_to_popup.emit()
	check(modes.is_item_checked(0) and not modes.is_item_checked(1), "Navigate checks reflect the startup modes")
	trigger(shell,"auto_orbit")
	check(viewer.orbit_enabled and viewer.free_camera, "Default O toggles Auto Orbit on while Free Camera remains on")
	trigger(shell,"auto_orbit")
	check(not viewer.orbit_enabled and viewer.free_camera, "Default O toggles Auto Orbit back off")
	viewer._reset_camera()
	check(not viewer.orbit_enabled and viewer.free_camera, "Reset Camera preserves the chosen navigation modes")
	check(unique(shell.shortcuts.active), "Defaults contain no duplicates")
	check(shell.shortcuts.active.navigate == (KEY_N | KEY_MASK_ALT), "Navigate retains Alt+N default")
	check(shell.shortcuts.active.fullscreen_alternate == (KEY_F11 | KEY_MASK_SHIFT), "Documented Shift+F11 alternate remains explicit and editable")
	for action in ["free_camera","open_capture","export_video","derive_range","mapping","pin_top","pin_right","pin_bottom","next_category","previous_category","loop_playback"]:
		check(shell.shortcuts.active[action] == 0, "No invented default for " + action)
	check(not shell.commands.has("shortcuts"), "Old Help Shortcuts command is removed")
	check(shell.menus.Help.get_popup().item_count == 1, "Help has only About")
	var edit: PopupMenu = shell.menus.Edit.get_popup()
	check(edit.get_item_text(0) == "Preferences", "Edit contains exact Preferences label")
	check(edit.get_node(edit.get_item_submenu(0)).get_item_text(0) == "Keyboard Shortcuts", "Exact Keyboard Shortcuts submenu label")
	check(not shell.commands.keyboard_shortcuts.popup.is_item_disabled(shell.commands.keyboard_shortcuts.index), "Preferences available without a capture")
	shell.invoke_shortcut_command("keyboard_shortcuts"); await settle()
	var dialog = shell.shortcuts_editor
	check(dialog is Control and not dialog is Window, "Custom in-canvas Control, no Godot/native dialog chrome")
	check(dialog.theme == shell.style_slice.theme, "Editor uses accepted production violet theme")
	var shell_close: Button = shell.window_chrome.actions.get_child(2)
	check(dialog.close_button.icon == shell_close.icon and dialog.close_button.custom_minimum_size == shell_close.custom_minimum_size and dialog.close_button.theme_type_variation == shell_close.theme_type_variation, "Dialog X shares shell close icon, dimensions and control variation")
	for state in ["normal","hover","pressed","disabled","focus"]:
		check(dialog.close_button.get_theme_stylebox(state) == shell_close.get_theme_stylebox(state), "Dialog X shares shell close styling: " + state)
	check(dialog.close_button.has_meta("violet_motion") and dialog.focus_order.has(dialog.close_button), "Dialog X shares shell hover treatment and is keyboard navigable")
	check(dialog.rows.size() == Bindings.ACTIONS.size(), "Every supported action has a key capture row")
	check(dialog.rows.has("auto_orbit") and dialog.rows.has("free_camera"), "Both navigation toggles are present under Edit Preferences Keyboard Shortcuts")
	check(dialog.rows.has("increase_camera_speed") and dialog.rows.has("decrease_camera_speed") and dialog.rows.increase_camera_speed.label.text == "Increase Camera Movement Speed" and dialog.rows.decrease_camera_speed.label.text == "Decrease Camera Movement Speed", "Both speed controls are discoverable in Keyboard Shortcuts")
	check(dialog.footer.is_ancestor_of(dialog.cancel) and dialog.footer.is_ancestor_of(dialog.apply_button) and not dialog.scroller.is_ancestor_of(dialog.footer), "Cancel and Apply remain in fixed footer")
	check(dialog.apply_button.theme_type_variation == "PrimaryButton", "Apply is the primary action")
	check(dialog.apply_button.disabled and not dialog.focus_order.has(dialog.apply_button), "Apply starts disabled and is excluded from keyboard traversal")
	check_no_dialog_tooltips(dialog, "Initial editor")
	dialog.apply_button.pressed.emit()
	check(dialog.visible and not FileAccess.file_exists(shell.shortcuts.storage_path), "Unchanged draft cannot apply, close or create preferences")
	dialog.reset.pressed.emit()
	check(dialog.apply_button.disabled, "Reset Defaults leaves Apply disabled when defaults are already active")
	check(not dialog.notice.visible and dialog.notice.custom_minimum_size.y == 0, "No permanent footer instructions or reserved helper-text space")
	check(dialog.scroller.get_index() == 1, "Title leads directly into list without top instruction text")
	check(not dialog.rows.export_video.key.disabled, "Unavailable source action remains editable without a tooltip")
	picture("shortcuts-overview")
	var original: Dictionary = shell.shortcuts.active.duplicate()
	dialog.start_capture("increase_camera_speed")
	var us_plus := InputEventKey.new(); us_plus.keycode = KEY_EQUAL; us_plus.unicode = KEY_PLUS; us_plus.shift_pressed = true; us_plus.pressed = true
	root.push_input(us_plus)
	us_plus = us_plus.duplicate(); us_plus.pressed = false; root.push_input(us_plus)
	check(dialog.staged.increase_camera_speed == KEY_PLUS and dialog.apply_button.disabled, "US Shift+= captures the same logical + default as Nordic +")
	dialog.start_capture("increase_camera_speed"); key(KEY_F6)
	dialog.start_capture("decrease_camera_speed"); key(KEY_F6)
	check(dialog.staged.increase_camera_speed == 0 and dialog.staged.decrease_camera_speed == KEY_F6 and unique(dialog.staged), "Speed shortcut conflict transfers ownership in the draft")
	dialog.reset.pressed.emit()
	check(dialog.apply_button.disabled and dialog.staged.increase_camera_speed == KEY_PLUS and dialog.staged.decrease_camera_speed == KEY_MINUS, "Reset Defaults restores both speed keys")
	dialog.rows.reset_camera.key.grab_focus(); key(KEY_ENTER); await settle()
	check(dialog.listening == "reset_camera", "Focused binding button enters capture through keyboard activation")
	check(dialog.apply_button.disabled, "Entering key capture does not enable Apply")
	key(KEY_ESCAPE)
	dialog.start_capture("reset_camera"); key(KEY_R)
	check(dialog.apply_button.disabled, "Capturing the current binding leaves Apply disabled")
	dialog.clear_binding("reset_camera")
	check(not dialog.apply_button.disabled, "Clearing a bound action enables Apply")
	check_no_dialog_tooltips(dialog, "After Clear")
	dialog.start_capture("reset_camera"); key(KEY_R)
	check(dialog.apply_button.disabled, "Restoring the original binding disables Apply again")
	viewer.yaw = 1.7; viewer._update_camera(); key(KEY_R)
	check(is_equal_approx(viewer.yaw,1.7), "Modal editor blocks underlying viewport shortcuts outside capture")
	viewer.dragging = true; viewer.resizing_panel = true
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	root.push_input(release)
	check(not viewer.dragging and not viewer.resizing_panel, "Mouse release over modal editor still ends existing viewport drag")
	dialog.start_capture("frame_scene"); key(KEY_R); await settle()
	check(dialog.staged.frame_scene == KEY_R and dialog.staged.reset_camera == 0, "Duplicate capture immediately unbinds previous action without confirmation")
	check_no_dialog_tooltips(dialog, "After duplicate transfer")
	check(unique(dialog.staged) and shell.shortcuts.active == original, "Duplicate resolution is staged and active bindings remain intact")
	check(not dialog.apply_button.disabled, "Duplicate transfer enables Apply")
	dialog.start_capture("frame_scene"); key(KEY_F); dialog.start_capture("reset_camera"); key(KEY_R)
	check(dialog.apply_button.disabled, "Reverting every duplicate-transfer change disables Apply")
	dialog.start_capture("frame_scene"); key(KEY_R)
	dialog.start_capture("reset_camera"); key(KEY_ESCAPE)
	check(dialog.visible and dialog.listening.is_empty() and dialog.staged.reset_camera == 0, "Escape cancels single capture without closing dialog or changing draft")
	dialog.start_capture("reset_camera"); key(KEY_CTRL)
	check(dialog.listening == "reset_camera", "Modifier alone is not accepted")
	key(KEY_R | KEY_MASK_CTRL | KEY_MASK_SHIFT)
	check(dialog.staged.reset_camera == (KEY_R | KEY_MASK_CTRL | KEY_MASK_SHIFT), "Ctrl and Shift are captured exactly")
	dialog.start_capture("open_capture"); key(KEY_O | KEY_MASK_ALT | KEY_MASK_META)
	check(dialog.staged.open_capture == (KEY_O | KEY_MASK_ALT | KEY_MASK_META), "Alt and Meta are captured exactly")
	dialog.start_capture("free_camera"); key(KEY_TAB)
	check(dialog.listening == "free_camera", "Tab remains reserved for focus traversal")
	key(KEY_ESCAPE); dialog.cancel.pressed.emit(); await settle()
	check(not dialog.visible and shell.shortcuts.active == original and not FileAccess.file_exists(shell.shortcuts.storage_path), "Cancel discards edits without persistence")
	shell.edit_shortcuts(); dialog.clear_binding("reset_camera"); dialog.start_capture("open_capture")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT
	click.position = dialog.close_button.get_global_rect().get_center(); click.pressed = true; root.push_input(click)
	click = click.duplicate(); click.pressed = false; root.push_input(click); await settle()
	check(not dialog.visible and shell.shortcuts.active == original and not FileAccess.file_exists(shell.shortcuts.storage_path) and dialog.listening.is_empty() and not dialog.notice.visible, "Clicking X discards unapplied draft/capture without warning, saving or quitting")
	shell.edit_shortcuts()
	check(dialog.apply_button.disabled, "Reopening after Cancel starts with Apply disabled")
	dialog.clear_binding("reset_camera"); key(KEY_ESCAPE)
	check(not dialog.visible and shell.shortcuts.active == original, "Dismissing with Escape behaves like Cancel")
	# Rebind all exposed actions to unique modified keys. Exercise production input.
	shell.edit_shortcuts()
	for index in Bindings.ACTIONS.size():
		var action: String = Bindings.ACTIONS[index][0]
		dialog.start_capture(action); key((KEY_A + index) | KEY_MASK_CTRL | KEY_MASK_ALT)
		check(dialog.staged[action] == ((KEY_A + index) | KEY_MASK_CTRL | KEY_MASK_ALT), "Capture works for " + action)
	dialog.apply_button.grab_focus(); key(KEY_ENTER); await settle()
	check(dialog.visible and FileAccess.file_exists(shell.shortcuts.storage_path) and unique(shell.shortcuts.active), "Apply persists validated unique map and keeps editor open")
	check(dialog.staged == shell.shortcuts.active and dialog.apply_button.disabled and dialog.listening.is_empty(), "Apply establishes a clean draft and disables Apply while keeping editor open")
	check(root.gui_get_focus_owner() == dialog.cancel, "Keyboard Apply moves focus to enabled Cancel when Apply disables")
	var applied: Dictionary = shell.shortcuts.active.duplicate()
	var active_speed: float = viewer.free_camera_speed_scale
	dialog.cancel.pressed.emit(); await settle()
	trigger(shell, "increase_camera_speed")
	check(is_equal_approx(viewer.free_camera_speed_scale, active_speed * 1.10), "Rebound increase shortcut takes effect after Apply")
	trigger(shell, "decrease_camera_speed")
	check(is_equal_approx(viewer.free_camera_speed_scale, active_speed * 1.10 * .90), "Rebound decrease shortcut takes effect after Apply")
	shell.edit_shortcuts()
	dialog.clear_binding("save_image"); dialog.apply_button.pressed.emit(); await settle()
	check(dialog.visible and shell.shortcuts.active.save_image == 0 and dialog.apply_button.disabled, "A second Apply saves another edit without closing the editor")
	dialog.start_capture("save_image"); key(applied.save_image); dialog.apply_button.pressed.emit(); await settle()
	check(dialog.visible and shell.shortcuts.active == applied and dialog.apply_button.disabled, "Repeated Apply uses the latest active map as the clean baseline")
	dialog.clear_binding("reset_camera"); dialog.cancel.pressed.emit(); await settle()
	check(not dialog.visible and shell.shortcuts.active == applied, "Cancel after Apply discards only subsequent unapplied changes")
	shell.edit_shortcuts(); dialog.clear_binding("reset_camera"); dialog.close_button.pressed.emit(); await settle()
	check(not dialog.visible and shell.shortcuts.active == applied and not dialog.notice.visible, "X after Apply retains applied bindings and silently discards later edits")
	check(shell.navigation.get_child(1).tooltip_text.contains("Ctrl+Alt+A"), "Reset Camera tooltip immediately follows remap")
	viewer.yaw = 1.7; viewer._update_camera(); trigger(shell,"reset_camera")
	check(is_equal_approx(viewer.yaw,deg_to_rad(38.0)), "Remapped Reset Camera invokes existing reset path immediately")
	viewer.yaw = 1.7; viewer._update_camera(); key(KEY_R)
	check(is_equal_approx(viewer.yaw,1.7), "Old hardcoded Reset Camera key no longer fires")
	viewer.orbit_enabled = false; viewer.inspection_paused = true; trigger(shell,"auto_orbit")
	check(viewer.orbit_enabled and viewer.inspection_paused, "Remapped Auto Orbit changes only its navigation state")
	trigger(shell,"auto_orbit"); check(not viewer.orbit_enabled and viewer.inspection_paused, "Auto Orbit toggles back without changing inspection pause")
	viewer.inspection_paused = false
	viewer.free_camera = true; trigger(shell,"free_camera")
	check(not viewer.free_camera and not viewer.orbit_enabled, "Free Camera shortcut turns OFF without enabling Auto Orbit")
	trigger(shell,"free_camera"); check(viewer.free_camera and not viewer.orbit_enabled, "Free Camera shortcut turns ON without enabling Auto Orbit")
	viewer.orbit_enabled = false
	viewer.open_dialog.use_native_dialog = false # Scripted activation uses the embedded control.
	trigger(shell,"open_capture"); await settle(); check(viewer.open_dialog.visible, "Open File opens authoritative picker")
	viewer.open_dialog.hide(); await settle()
	trigger(shell,"navigate"); await settle(); check(shell.navigation.get_child(2).get_popup().visible, "Remapped Navigate opens existing menu")
	shell.navigation.get_child(2).get_popup().hide(); await settle()
	viewer._open_capture(output.path_join("mixed.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await wait_ready(viewer); await settle()
	check(viewer.generic_reader != null, "Mixed particles/fields/meshes fixture opens")
	trigger(shell,"play_pause"); check(viewer.playing, "Play Pause invokes existing transport toggle")
	trigger(shell,"play_pause"); check(not viewer.playing, "Play Pause returns to paused")
	trigger(shell,"next_sample"); await wait_ready(viewer); check(viewer.current_index == 1, "Next Sample uses accepted frame stepping")
	trigger(shell,"previous_sample"); await wait_ready(viewer); check(viewer.current_index == 0, "Previous Sample uses accepted frame stepping")
	viewer.camera_target = Vector3(100,100,100); viewer._update_camera(); trigger(shell,"frame_scene")
	check(viewer.camera_target != Vector3(100,100,100) and viewer.camera.transform.is_finite(), "Frame Scene uses accepted framing")
	trigger(shell,"export_video"); await settle(); check(viewer.video_dialog.visible, "Export Video opens existing export dialog")
	viewer.video_dialog.hide(); await settle()
	trigger(shell,"save_image"); await settle(); check(viewer.screenshot_dialog != null and viewer.screenshot_dialog.visible, "Save Image preserves accepted screenshot flow")
	viewer.screenshot_dialog.canceled.emit(); viewer.screenshot_dialog.hide(); await settle()
	for action in ["recorded_history", "point_rendering"]:
		var before: bool = viewer.trails_enabled if action == "recorded_history" else viewer.clean_view
		trigger(shell, action)
		check((viewer.trails_enabled if action == "recorded_history" else viewer.clean_view) != before, "Accepted toggle route: " + action)
		trigger(shell, action)
		check((viewer.trails_enabled if action == "recorded_history" else viewer.clean_view) == before, "Accepted toggle restores state: " + action)
	for action in ["derive_range","mapping"]:
		trigger(shell,action); await settle()
		check(viewer.tools_ui.window.visible and viewer.tools_ui.current == ("Mapping" if action == "mapping" else "Derive range"), "Authoritative tool route: " + action)
		viewer.tools_ui.close(); await settle()
	var loop_before: bool = viewer.scene_loop_playback
	trigger(shell,"loop_playback"); check(viewer.scene_loop_playback != loop_before, "Loop Playback uses existing loop callback")
	trigger(shell,"loop_playback"); check(viewer.scene_loop_playback == loop_before, "Loop Playback restores prior value")
	for side in ["top","right","bottom"]:
		var pinned: bool = shell.edge_reveal.states[side].pinned
		trigger(shell,"pin_"+side); check(shell.edge_reveal.states[side].pinned != pinned, "Pin shortcut toggles authoritative " + side + " state")
		trigger(shell,"pin_"+side); check(shell.edge_reveal.states[side].pinned == pinned, "Pin shortcut restores " + side)
	var science: Dictionary = Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	shell.select_workspace(0)
	for expected in [1,2,0]:
		trigger(shell,"next_category"); check(shell.workspace == expected, "Next category preserves Particles / Fields / Meshes order " + str(expected))
	for expected in [2,1,0]:
		trigger(shell,"previous_category"); check(shell.workspace == expected, "Previous category wraps in accepted order " + str(expected))
	check(Visual.snapshot(viewer) == science and viewer.committed_sample == sample, "Category cycling preserves scientific state and committed sample")
	var text := LineEdit.new(); shell.add_child(text); text.grab_focus(); viewer.yaw = 1.7; viewer._update_camera()
	trigger_without_focus_release(shell,"reset_camera")
	check(is_equal_approx(viewer.yaw,1.7), "Editable text suppresses remapped viewer actions")
	text.release_focus(); text.free()
	viewer.inspection_busy = true; trigger(shell,"reset_camera"); viewer.inspection_busy = false
	check(is_equal_approx(viewer.yaw,1.7), "Busy inspection suppresses remapped actions")
	if DisplayServer.get_name() != "headless":
		var edges: Dictionary = shell.edge_reveal.states.duplicate(true)
		viewer.orbit_enabled = false; viewer.free_camera = true
		trigger(shell,"fullscreen"); await get_tree().create_timer(.35).timeout; await settle()
		check(shell.immersive and not viewer.orbit_enabled and viewer.free_camera, "Fullscreen preserves default navigation state")
		trigger(shell,"auto_orbit"); trigger(shell,"auto_orbit")
		trigger(shell,"free_camera"); trigger(shell,"free_camera")
		check(not viewer.orbit_enabled and viewer.free_camera, "Both navigation shortcuts toggle through Fullscreen and restore the starting modes")
		shell.edit_shortcuts(); dialog.start_capture("frame_scene"); key(KEY_ESCAPE)
		check(shell.immersive and dialog.visible, "Capture Escape does not exit underlying Fullscreen")
		key(KEY_ESCAPE); check(shell.immersive and not dialog.visible, "Editor dismissal preserves Fullscreen")
		key(KEY_ESCAPE); await get_tree().create_timer(.35).timeout
		check(not shell.immersive and shell.edge_reveal.states == edges, "Reserved Escape restores authoritative fullscreen pin snapshot")
		trigger(shell,"fullscreen_alternate"); await get_tree().create_timer(.35).timeout
		check(shell.immersive, "Remapped Fullscreen Alternate uses same authoritative path")
		key(KEY_ESCAPE); await get_tree().create_timer(.35).timeout
	# Modal focus, scroll and geometry at normal, compact and simulated KDE scales.
	root.min_size = Vector2i.ZERO
	for layout in [[Vector2i(1440,900),1.0],[Vector2i(970,600),1.0],[Vector2i(640,480),1.0],[Vector2i(3840,2160),2.0],[Vector2i(3840,2160),2.5]]:
		root.content_scale_factor = layout[1]; root.size = layout[0]; await settle(); shell.layout()
		shell.edit_shortcuts(); await settle(); dialog.fit(); await settle()
		var extent: Vector2 = root.get_visible_rect().size
		check(Rect2(Vector2.ZERO,extent).encloses(dialog.panel.get_global_rect()), "Editor fits logical viewport " + str(layout))
		check(dialog.panel.size.y <= 560.5 and dialog.scroller.size.y > 80, "Compact capped height leaves usable scroll region " + str(layout))
		check(dialog.panel.get_global_rect().encloses(dialog.footer.get_global_rect()), "Fixed footer stays inside panel " + str(layout))
		check(dialog.scroller.get_v_scroll_bar().max_value > dialog.scroller.size.y, "Long list scrolls at " + str(layout))
		var field: Button = dialog.rows.reset_camera.key
		field.grab_focus(); key(KEY_TAB); await settle()
		check(dialog.is_ancestor_of(root.gui_get_focus_owner()), "Tab stays within modal editor " + str(layout))
		dialog.cancel.grab_focus(); key(KEY_TAB); await settle()
		check(dialog.apply_button.disabled and root.gui_get_focus_owner() == dialog.close_button, "Unchanged footer skips disabled Apply and wraps to X " + str(layout))
		key(KEY_TAB); await settle()
		check(root.gui_get_focus_owner() == field, "X advances keyboard focus to first shortcut " + str(layout))
		key(KEY_TAB | KEY_MASK_SHIFT); await settle()
		check(root.gui_get_focus_owner() == dialog.close_button, "First shortcut wraps backward to X " + str(layout))
		key(KEY_TAB | KEY_MASK_SHIFT); await settle()
		check(root.gui_get_focus_owner() == dialog.cancel, "Unchanged Shift Tab wraps to Cancel " + str(layout))
		dialog.reset.pressed.emit()
		check(not dialog.apply_button.disabled, "Reset Defaults enables Apply when active map differs " + str(layout))
		check_no_dialog_tooltips(dialog, "After Reset Defaults " + str(layout))
		check(dialog.staged.auto_orbit == KEY_O and dialog.staged.free_camera == 0, "Reset Defaults retains O and Unbound for navigation " + str(layout))
		dialog.apply_button.grab_focus(); key(KEY_TAB); await settle()
		check(root.gui_get_focus_owner() == dialog.close_button, "Edited footer Tab wraps to X " + str(layout))
		key(KEY_TAB); await settle()
		check(root.gui_get_focus_owner() == field, "Edited X advances to first shortcut " + str(layout))
		key(KEY_TAB | KEY_MASK_SHIFT); await settle()
		key(KEY_TAB | KEY_MASK_SHIFT); await settle()
		check(root.gui_get_focus_owner() == dialog.apply_button, "Shift Tab wraps back to footer " + str(layout))
		dialog.rows.previous_category.key.grab_focus(); await settle()
		check(dialog.scroller.scroll_vertical > 0 and dialog.scroller.get_global_rect().intersects(dialog.rows.previous_category.key.get_global_rect()), "Focus scrolls last action into view " + str(layout))
		check_no_dialog_tooltips(dialog, "Scrolled to last row " + str(layout))
		picture("shortcuts-"+str(layout[0].x)+"-"+str(layout[0].y)+"-"+str(layout[1]))
		layouts.append({"window":str(root.size),"scale":root.content_scale_factor,"logical":str(extent),"panel":str(dialog.panel.get_global_rect()),"scroll_height":dialog.scroller.size.y})
		dialog.dismiss()
	root.content_scale_factor = 1; root.size = Vector2i(1440,900); await settle()
	shell.edit_shortcuts(); dialog.start_capture("frame_scene"); key(KEY_R)
	# Move Reset to R first, then Frame takes it, proving persistent unbound state.
	Bindings.assign(dialog.staged,"reset_camera",KEY_R); Bindings.assign(dialog.staged,"frame_scene",KEY_R); dialog.refresh_rows()
	var prior: Dictionary = shell.shortcuts.active.duplicate()
	var path: String = shell.shortcuts.storage_path; shell.shortcuts.storage_path = output.path_join("missing-parent/shortcuts.cfg")
	dialog.commit()
	check(dialog.visible and shell.shortcuts.active == prior and dialog.notice.text.contains("Could not save"), "Failed persistence keeps dialog open and prior active bindings intact")
	shell.shortcuts.storage_path = path; dialog.commit(); await settle()
	check(dialog.visible and dialog.apply_button.disabled and not dialog.notice.visible and dialog.staged == shell.shortcuts.active, "Successful save retry clears error and keeps a clean editor open")
	check_no_dialog_tooltips(dialog, "After Apply")
	check(shell.shortcuts.active.reset_camera == 0 and shell.shortcuts.active.frame_scene == KEY_R, "Final Apply stores transferred duplicate and explicit Unbound")
	dialog.reset.pressed.emit(); dialog.commit()
	check(shell.shortcuts.active.frame_scene == KEY_F and shell.shortcuts.active.free_camera == 0, "Reset Defaults restores F to Frame Scene before owner reproduction")
	dialog.start_capture("free_camera"); key(KEY_F)
	check(dialog.staged.free_camera == KEY_F and dialog.staged.frame_scene == 0 and unique(dialog.staged), "Assigning F to Free Camera immediately unbinds Frame Scene")
	dialog.commit()
	check(shell.shortcuts.active.free_camera == KEY_F and shell.shortcuts.active.frame_scene == 0 and unique(shell.shortcuts.active), "Applied F belongs only to Free Camera")
	# Transfer the same key to another action and back through the editor.
	dialog.start_capture("frame_scene"); key(KEY_F)
	check(dialog.staged.free_camera == 0 and dialog.staged.frame_scene == KEY_F and unique(dialog.staged), "Conflicting F assignment removes the prior Free Camera owner")
	dialog.commit()
	var f_event := InputEventKey.new(); f_event.keycode = KEY_F; f_event.pressed = true
	check(shell.shortcuts.active.free_camera == 0 and shell.shortcuts.active.frame_scene == KEY_F and shell.shortcuts.match_action(f_event) == "frame_scene", "Only Frame Scene resolves from F after Apply")
	dialog.start_capture("frame_scene"); key(KEY_R)
	dialog.start_capture("free_camera"); key(KEY_F)
	dialog.commit()
	dialog.dismiss()
	navigation_review(viewer, shell, "Initial process")
	var file := FileAccess.open(output.path_join("saved-map.json"),FileAccess.WRITE); file.store_string(JSON.stringify(shell.shortcuts.active)); file.close()
	var malformed := Bindings.new(); malformed.storage_path = output.path_join("malformed.cfg")
	var config := ConfigFile.new(); config.set_value("shortcuts","reset_camera",KEY_R); config.set_value("shortcuts","frame_scene",KEY_R)
	config.set_value("shortcuts","auto_orbit","bad value"); config.set_value("shortcuts","fullscreen",KEY_ESCAPE); config.save(malformed.storage_path)
	check(malformed.load_preferences() == OK and unique(malformed.active) and malformed.active.reset_camera == 0 and malformed.active.frame_scene == KEY_R, "Manually edited profile resolves duplicates deterministically")
	check(malformed.active.auto_orbit == KEY_O and malformed.active.fullscreen == KEY_F11, "Invalid stored values preserve safe defaults")
	viewer.orbit_enabled = false; viewer.free_camera = true
	for kind in ["particles", "fields", "meshes", "mixed"]:
		viewer._open_capture(output.path_join(kind + ".wvz")); viewer.playing = false
		await wait_ready(viewer)
		check(viewer.generic_reader != null and not viewer.orbit_enabled and viewer.free_camera, kind + " scene opening preserves navigation defaults")
		check(not Visual.snapshot(viewer).orbit_enabled and Preset.snapshot(viewer).settings.view.free_camera, kind + " scene snapshots expose the intended navigation state")
	var saved := Preset.snapshot(viewer)
	saved.settings.view.orbit_enabled = true; saved.settings.view.free_camera = false
	check(Preset.apply(viewer, saved).error.is_empty() and viewer.orbit_enabled and not viewer.free_camera, "Explicit view preset overrides both application defaults")
	var partial := Preset.snapshot(viewer)
	partial.settings.view.erase("orbit_enabled"); partial.settings.view.erase("free_camera")
	check(Preset.apply(viewer, partial).error.is_empty() and viewer.orbit_enabled and not viewer.free_camera, "Preset omitting navigation modes preserves current intentional state")
	var visual := Visual.snapshot(viewer)
	visual.orbit_enabled = false
	Visual.apply(viewer, visual)
	check(not viewer.orbit_enabled and not viewer.free_camera, "Explicit recipe orbit state restores while session-only Free Camera remains untouched")
	finish(viewer)

func trigger_without_focus_release(shell, action: String) -> void: key(shell.shortcuts.active[action])

func finish(viewer) -> void:
	var report := {"checks":checks,"failures":failures,"layouts":layouts,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name(),"packaged":OS.has_feature("template"),"executable":OS.get_executable_path(),"restart":restart,"preference_path":viewer.shell.shortcuts.storage_path}
	var file := FileAccess.open(output.path_join("restart-report.json" if restart else "report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("KEYBOARD SHORTCUTS: ",checks," checks; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1) # Exercise normal application teardown.
