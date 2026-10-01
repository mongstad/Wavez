extends Node
const Viewer = preload("res://main.gd")
const Bindings = preload("res://ui/keyboard_shortcuts.gd")
const Visual = preload("res://scene/visual_state.gd")
var output := ""
var restart := false
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
func picture(name: String) -> void:
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func wait_ready(viewer) -> void:
	for i in 1000:
		viewer.scene_layers.tick(.01)
		if not viewer.scene_layers.is_buffering(): return
		await get_tree().create_timer(.01).timeout
	check(false, "Fixture preparation completes")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shortcut-output="): output = argument.trim_prefix("--shortcut-output=")
		if argument == "--shortcut-restart": restart = true
	if output.is_empty(): queue_free(); return
	get_tree().create_timer(120).timeout.connect(func(): push_error("Shortcut tests timed out"); get_tree().quit(1))
	await get_tree().process_frame
	var viewer = get_tree().current_scene
	if viewer == null:
		viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	viewer.set_process(false)
	var shell = viewer.shell
	if restart:
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("saved-map.json")))
		for action in saved: saved[action] = int(saved[action]) # JSON numbers decode as floats.
		check(shell.shortcuts.active == saved, "Fresh application process restores every saved and unbound binding")
		check(unique(shell.shortcuts.active), "Restart has no duplicate bindings")
		check(shell.shortcuts.active.reset_camera == 0 and shell.shortcuts.active.frame_scene == KEY_R, "Duplicate transfer survives restart")
		viewer.yaw = 1.7; viewer._update_camera(); var before: Transform3D = viewer.camera.transform
		trigger(shell, "frame_scene")
		check(viewer.camera.transform == before, "Restart uses new Frame Scene binding; old Reset Camera does not fire")
		var offline = Viewer.new(); offline.offline_instance = true; root.add_child(offline); offline.set_process(false)
		check(offline.shell.shortcuts.active == Bindings.defaults(), "Offline viewer does not consume interactive preferences")
		offline.free()
		finish(viewer); return
	check(shell.shortcuts.active == Bindings.defaults(), "New profile preserves accepted default shortcuts")
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
	check(dialog.footer.is_ancestor_of(dialog.cancel) and dialog.footer.is_ancestor_of(dialog.apply_button) and not dialog.scroller.is_ancestor_of(dialog.footer), "Cancel and Apply remain in fixed footer")
	check(dialog.apply_button.theme_type_variation == "PrimaryButton", "Apply is the primary action")
	check(dialog.apply_button.disabled and not dialog.focus_order.has(dialog.apply_button), "Apply starts disabled and is excluded from keyboard traversal")
	dialog.apply_button.pressed.emit()
	check(dialog.visible and not FileAccess.file_exists(shell.shortcuts.storage_path), "Unchanged draft cannot apply, close or create preferences")
	dialog.reset.pressed.emit()
	check(dialog.apply_button.disabled, "Reset Defaults leaves Apply disabled when defaults are already active")
	check(not dialog.notice.visible and dialog.notice.custom_minimum_size.y == 0, "No permanent footer instructions or reserved helper-text space")
	check(dialog.scroller.get_index() == 1, "Title leads directly into list without top instruction text")
	check(dialog.rows.export_video.key.tooltip_text.contains("Open a compatible capture") and not dialog.rows.export_video.key.disabled, "Unavailable source action explains requirements while binding stays editable")
	picture("shortcuts-overview")
	var original: Dictionary = shell.shortcuts.active.duplicate()
	dialog.rows.reset_camera.key.grab_focus(); key(KEY_ENTER); await settle()
	check(dialog.listening == "reset_camera", "Focused binding button enters capture through keyboard activation")
	check(dialog.apply_button.disabled, "Entering key capture does not enable Apply")
	key(KEY_ESCAPE)
	dialog.start_capture("reset_camera"); key(KEY_R)
	check(dialog.apply_button.disabled, "Capturing the current binding leaves Apply disabled")
	dialog.clear_binding("reset_camera")
	check(not dialog.apply_button.disabled, "Clearing a bound action enables Apply")
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
	viewer.orbit_enabled = false; trigger(shell,"auto_orbit")
	check(viewer.orbit_enabled and not viewer.inspection_paused, "Remapped Auto Orbit uses accepted toggle")
	trigger(shell,"auto_orbit"); check(not viewer.orbit_enabled, "Auto Orbit toggles back")
	viewer.free_camera = false; trigger(shell,"free_camera")
	check(viewer.free_camera and not viewer.orbit_enabled, "Free Camera uses Navigate mode semantics")
	trigger(shell,"free_camera"); check(not viewer.free_camera and viewer.orbit_enabled, "Free Camera restores orbit mode through same path")
	viewer.orbit_enabled = false
	trigger(shell,"open_capture"); await settle(); check(viewer.open_dialog.visible, "Open Capture opens authoritative picker")
	viewer.open_dialog.hide(); await settle()
	trigger(shell,"navigate"); await settle(); check(shell.navigation.get_child(2).get_popup().visible, "Remapped Navigate opens existing menu")
	shell.navigation.get_child(2).get_popup().hide(); await settle()
	viewer._open_capture(output.path_join("mixed.ssc")); viewer.playing = false; viewer.orbit_enabled = false
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
		trigger(shell,"fullscreen"); await get_tree().create_timer(.35).timeout; await settle()
		check(shell.immersive, "Remapped Fullscreen invokes existing shell path")
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
		dialog.apply_button.grab_focus(); key(KEY_TAB); await settle()
		check(root.gui_get_focus_owner() == dialog.close_button, "Edited footer Tab wraps to X " + str(layout))
		key(KEY_TAB); await settle()
		check(root.gui_get_focus_owner() == field, "Edited X advances to first shortcut " + str(layout))
		key(KEY_TAB | KEY_MASK_SHIFT); await settle()
		key(KEY_TAB | KEY_MASK_SHIFT); await settle()
		check(root.gui_get_focus_owner() == dialog.apply_button, "Shift Tab wraps back to footer " + str(layout))
		dialog.rows.previous_category.key.grab_focus(); await settle()
		check(dialog.scroller.scroll_vertical > 0 and dialog.scroller.get_global_rect().intersects(dialog.rows.previous_category.key.get_global_rect()), "Focus scrolls last action into view " + str(layout))
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
	check(shell.shortcuts.active.reset_camera == 0 and shell.shortcuts.active.frame_scene == KEY_R, "Final Apply stores transferred duplicate and explicit Unbound")
	var file := FileAccess.open(output.path_join("saved-map.json"),FileAccess.WRITE); file.store_string(JSON.stringify(shell.shortcuts.active)); file.close()
	var malformed := Bindings.new(); malformed.storage_path = output.path_join("malformed.cfg")
	var config := ConfigFile.new(); config.set_value("shortcuts","reset_camera",KEY_R); config.set_value("shortcuts","frame_scene",KEY_R)
	config.set_value("shortcuts","auto_orbit","bad value"); config.set_value("shortcuts","fullscreen",KEY_ESCAPE); config.save(malformed.storage_path)
	check(malformed.load_preferences() == OK and unique(malformed.active) and malformed.active.reset_camera == 0 and malformed.active.frame_scene == KEY_R, "Manually edited profile resolves duplicates deterministically")
	check(malformed.active.auto_orbit == KEY_O and malformed.active.fullscreen == KEY_F11, "Invalid stored values preserve safe defaults")
	finish(viewer)

func trigger_without_focus_release(shell, action: String) -> void: key(shell.shortcuts.active[action])

func finish(viewer) -> void:
	var report := {"checks":checks,"failures":failures,"layouts":layouts,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name(),"packaged":OS.has_feature("template"),"executable":OS.get_executable_path(),"restart":restart,"preference_path":viewer.shell.shortcuts.storage_path}
	var file := FileAccess.open(output.path_join("restart-report.json" if restart else "report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("KEYBOARD SHORTCUTS: ",checks," checks; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1) # Exercise normal application teardown.
