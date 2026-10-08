extends Node
## LMB-only inversion, staged preference editing and persisted hotkey ownership.
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
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 8: await get_tree().process_frame
	if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
func focus_none() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
func key(code: int, echo := false) -> InputEventKey:
	var event := InputEventKey.new(); event.keycode = code & KEY_CODE_MASK; event.pressed = true; event.echo = echo
	event.ctrl_pressed = bool(code & KEY_MASK_CTRL); event.alt_pressed = bool(code & KEY_MASK_ALT); event.shift_pressed = bool(code & KEY_MASK_SHIFT)
	return event
func trigger(view, code: int, echo := false) -> void:
	view._unhandled_input(key(code, echo))
func drag(view, delta: Vector2) -> void:
	view.dragging = true; view.last_mouse = Vector2.ZERO
	var event := InputEventMouseMotion.new(); event.position = delta; view._unhandled_input(event)
	view.dragging = false
func steer(view, delta: Vector2) -> void:
	view.free_look_dragging = true; view.free_look_last_mouse = Vector2.ZERO
	var event := InputEventMouseMotion.new(); event.position = delta; view._input(event)
	view._set_free_look_dragging(false)
func pose(view) -> void:
	view.camera_orbit_basis_active = false; view.camera_target = Vector3(3,-2,7); view.camera_distance = 32
	view.yaw = .4; view.pitch = .3; view._update_camera()
func world(view) -> Dictionary:
	var result := {view:view.transform, view.scene_layers:view.scene_layers.transform, view.current_instance:view.current_instance.transform}
	for node in view.scene_layers.views.values(): result[node] = node.transform
	return result
func picture(name: String) -> void:
	if DisplayServer.get_name() != "headless": check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Save " + name)
func edit_checks(view) -> void:
	var shell = view.shell
	var prefs = shell.shortcuts
	check(not prefs.invert_y_axis and prefs.active.toggle_invert_y_axis == 0, "First launch is Off and Unbound")
	shell.edit_shortcuts(); await settle()
	var dialog = shell.shortcuts_editor
	check(dialog.rows.size() == Bindings.ACTIONS.size() and dialog.rows.toggle_invert_y_axis.label.text == "Toggle Invert Y Axis", "Action appears exactly once with its authoritative name")
	check(dialog.rows.toggle_invert_y_axis.key.get_parent().get_parent() == dialog.groups.Navigation.body, "Inversion action belongs to Navigation")
	check(not dialog.invert_y_toggle.button_pressed and dialog.invert_y_toggle.text == "Off" and dialog.focus_order.has(dialog.invert_y_toggle), "Visible preference toggle reports Off and participates in keyboard focus")
	var initial := Visual.snapshot(view)
	for exit in ["cancel", "close", "escape"]:
		dialog.invert_y_toggle.button_pressed = true
		check(dialog.staged_invert_y_axis and not prefs.invert_y_axis and not dialog.apply_button.disabled, exit + ": toggle edits stay staged without moving camera")
		check(Visual.snapshot(view) == initial, exit + ": staged toggle preserves camera and scientific presentation")
		if exit == "cancel": dialog.cancel.pressed.emit()
		elif exit == "close": dialog.close_button.pressed.emit()
		else: dialog.handle_input(key(KEY_ESCAPE))
		check(not dialog.visible and not prefs.invert_y_axis, exit + ": silently discards inversion draft")
		shell.edit_shortcuts(); await settle()
		check(not dialog.invert_y_toggle.button_pressed, exit + ": reopened editor restores active Off")
	dialog.invert_y_toggle.button_pressed = true; dialog.commit()
	check(prefs.invert_y_axis and dialog.visible and dialog.apply_button.disabled and Visual.snapshot(view) == initial, "Apply activates On without closing editor or moving camera")
	var bytes := FileAccess.get_file_as_bytes(prefs.storage_path)
	dialog.reset.pressed.emit()
	check(not dialog.staged_invert_y_axis and not dialog.invert_y_toggle.button_pressed and not dialog.apply_button.disabled and prefs.invert_y_axis, "Reset stages Off even when the binding map is already default")
	dialog.dismiss()
	check(prefs.invert_y_axis and FileAccess.get_file_as_bytes(prefs.storage_path) == bytes, "Cancelling Reset preserves saved On")
	shell.edit_shortcuts(); dialog.reset.pressed.emit(); dialog.commit()
	check(not prefs.invert_y_axis and prefs.active == Bindings.defaults() and dialog.visible and dialog.apply_button.disabled, "Reset Apply restores Off and default/Unbound binding")
	dialog.start_capture("toggle_invert_y_axis"); dialog.handle_input(key(KEY_R))
	check(dialog.staged.reset_camera == 0 and dialog.staged.toggle_invert_y_axis == KEY_R and prefs.active.reset_camera == KEY_R, "One-key transfer affects only the staged map")
	dialog.dismiss(); shell.edit_shortcuts()
	check(dialog.staged.reset_camera == KEY_R and dialog.staged.toggle_invert_y_axis == 0, "Cancelled binding transfer restores both prior owners")
	dialog.start_capture("toggle_invert_y_axis"); dialog.handle_input(key(KEY_I | KEY_MASK_ALT)); dialog.invert_y_toggle.button_pressed = true; dialog.commit()
	check(prefs.invert_y_axis and prefs.active.toggle_invert_y_axis == (KEY_I | KEY_MASK_ALT), "Apply saves both inversion and assigned hotkey")
	var loaded = Bindings.new(); check(loaded.load_preferences() == OK and loaded.invert_y_axis and loaded.active == prefs.active, "ConfigFile reload restores both preferences")
	dialog.clear_binding("toggle_invert_y_axis"); dialog.commit()
	check(prefs.active.toggle_invert_y_axis == 0 and prefs.invert_y_axis, "Clear binding does not turn inversion Off")
	dialog.start_capture("toggle_invert_y_axis"); dialog.handle_input(key(KEY_I | KEY_MASK_ALT)); dialog.commit(); dialog.dismiss(); focus_none()
	initial = Visual.snapshot(view)
	trigger(view, KEY_I); trigger(view, KEY_I | KEY_MASK_ALT, true)
	check(prefs.invert_y_axis, "Unmodified I and OS echo do not toggle Alt+I")
	trigger(view, KEY_I | KEY_MASK_ALT)
	check(not prefs.invert_y_axis and Visual.snapshot(view) == initial, "Authoritative hotkey toggles Off without camera motion")
	trigger(view, KEY_I | KEY_MASK_ALT)
	check(prefs.invert_y_axis and Visual.snapshot(view) == initial, "Authoritative hotkey toggles back On without camera motion")
	# Real rename failure rejects the entire settings transaction after the temp save.
	var path: String = prefs.storage_path
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	prefs.storage_path = output.path_join("blocked-settings")
	DirAccess.make_dir_absolute(prefs.storage_path)
	var active: Dictionary = prefs.active.duplicate()
	shell.edit_shortcuts(); dialog.invert_y_toggle.button_pressed = false; dialog.clear_binding("toggle_invert_y_axis"); dialog.commit()
	check(dialog.visible and dialog.notice.visible and prefs.invert_y_axis and prefs.active == active, "Failed save leaves active state/map intact and draft retryable")
	check(FileAccess.get_file_as_bytes(path) == saved_bytes, "Original persisted preference file remains intact after rejected save")
	prefs.storage_path = path; dialog.dismiss()
	check(prefs.apply(prefs.active, "invalid") == ERR_INVALID_DATA and prefs.invert_y_axis, "Malformed inversion candidate is rejected")
	for layout in [{"name":"normal","size":Vector2i(1440,900)}, {"name":"compact","size":Vector2i(1024,640)}]:
		root.size = layout.size; await settle(); shell.edit_shortcuts(); await settle()
		dialog.invert_y_toggle.grab_focus(); await settle()
		check(dialog.invert_y_toggle.get_global_rect().grow(3).intersection(dialog.scroller.get_global_rect()) == dialog.invert_y_toggle.get_global_rect().grow(3), layout.name + ": toggle focus outline stays in scroll viewport")
		check(dialog.rows.toggle_invert_y_axis.label.size.x >= dialog.rows.toggle_invert_y_axis.label.get_minimum_size().x and dialog.rows.toggle_invert_y_axis.key.text == "Alt+I", layout.name + ": preference and hotkey remain visible")
		var controls: Array = dialog.find_children("*", "Control", true, false)
		check(controls.all(func(control): return control.tooltip_text.is_empty()), layout.name + ": tooltip-free editor preserved")
		picture(layout.name + "-inversion-on")
		dialog.invert_y_toggle.button_pressed = false; await settle(); picture(layout.name + "-inversion-off-draft")
		layouts.append({"name":layout.name,"toggle_rect":str(dialog.invert_y_toggle.get_global_rect()),"panel_rect":str(dialog.panel.get_global_rect())})
		dialog.dismiss()
	root.size = Vector2i(1440,900); await settle()
func navigation_checks(view, label: String) -> void:
	focus_none(); view.orbit_enabled = false; view.inspection_paused = false
	var sample: Dictionary = view.committed_sample.duplicate(true)
	var worlds := world(view)
	var results := {}
	for inverted in [false,true]:
		check(view.shell.shortcuts.apply(view.shell.shortcuts.active,inverted) == OK,label + ": apply navigation preference")
		var direction: float = -1.0 if inverted else 1.0
		for delta in [Vector2(0,40),Vector2(40,0),Vector2(40,-30)]:
			pose(view)
			var yaw: float = view.yaw; var pitch: float = view.pitch
			drag(view,delta)
			check(is_equal_approx(view.yaw,yaw-delta.x*.006) and is_equal_approx(view.pitch,pitch-delta.y*.006*direction),label + ": only vertical drag reverses " + str(inverted) + str(delta))
			var expected := Basis(Vector3.UP,yaw-delta.x*.006)*Basis(Vector3.RIGHT,-(pitch-delta.y*.006*direction))
			check(view.camera.basis.is_equal_approx(expected) and view.camera_target == Vector3(3,-2,7) and is_equal_approx(view.camera_distance,32),label + ": independent accepted tumble formula/radius/target")
		# Two full vertical revolutions in both directions, through exact poles.
		for sign in [-1,1]:
			pose(view); view.pitch = 0; view._update_camera()
			var start: Transform3D = view.camera.transform
			for step in 144:
				var before: Basis = view.camera.basis
				drag(view,Vector2(0,sign*deg_to_rad(5)/.006))
				check(view.camera.transform.is_finite() and absf(view.camera.basis.determinant()-1) < .00001 and before.y.dot(view.camera.basis.y) > .99,label + ": continuous orthonormal revolution " + str(inverted))
			check(view.camera.transform.is_equal_approx(start),label + ": two revolutions return to initial pose")
		pose(view); view._adopt_camera_basis(); drag(view,Vector2(20,30))
		check(view.camera.transform.is_finite(),label + ": LMB composes with an adopted full basis")
		pose(view); var before_rmb: Transform3D = view.camera.transform
		steer(view,Vector2(40,30))
		var expected_rmb := (before_rmb.basis*Basis(Vector3.UP,-40*view.FREE_LOOK_SENSITIVITY)*Basis(Vector3.RIGHT,-30*view.FREE_LOOK_SENSITIVITY)).orthonormalized()
		check(view.camera.basis.is_equal_approx(expected_rmb) and view.camera.position == before_rmb.origin,label + ": current two-axis RMB steering preserved")
		var comparison := {"rmb":view.camera.transform}
		pose(view)
		var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.factor = .5
		view._unhandled_input(wheel); comparison.wheel = view.camera.transform
		for pair in [[KEY_W,Vector3.FORWARD],[KEY_S,Vector3.BACK],[KEY_A,Vector3.LEFT],[KEY_D,Vector3.RIGHT],[KEY_Q,Vector3.DOWN],[KEY_E,Vector3.UP]]:
			pose(view); view.free_camera = true
			var start: Transform3D = view.camera.transform
			var event := InputEventKey.new(); event.physical_keycode = pair[0]; event.pressed = true
			Input.parse_input_event(event); Input.flush_buffered_events(); view._move_free_camera(.1)
			event = event.duplicate(); event.pressed = false; Input.parse_input_event(event); Input.flush_buffered_events()
			var shift: Vector3 = start.basis * pair[1] * .1 * 16 * view.free_camera_speed_scale
			check(view.camera.position.is_equal_approx(start.origin+shift) and view.camera.basis == start.basis,label + ": unchanged camera-relative translation " + str(pair[0]))
			comparison[str(pair[0])] = view.camera.transform
		pose(view); view.orbit_enabled = true; view.scene_layers.tick(.1); comparison.auto = view.camera.transform; view.orbit_enabled = false
		pose(view); view.manual_orbit_axis = view.camera.basis.y; view.manual_orbit_start_basis = view.camera.basis; view.manual_orbit_angle = 0
		view._orbit_camera_horizontally(.2, view.MANUAL_ORBIT_RATE); comparison.manual_orbit = view.camera.transform
		view._focus_activity(); comparison.frame = view.camera.transform
		view._reset_camera(); comparison.reset = view.camera.transform
		view.shell.edit_orbit_center(); var saved: Transform3D = view.camera.transform
		view.shell.orbit_editor.dismiss(); check(view.camera.transform == saved,label + ": orbit-center Cancel retains pose")
		results[str(inverted)] = comparison
	check(results["false"] == results["true"],label + ": RMB/wheel/translation/Auto Orbit/manual orbit/framing/reset identical in both states")
	check(view.committed_sample == sample and world(view) == worlds,label + ": world transforms and committed scientific sample unchanged")
	check(not JSON.stringify(Visual.snapshot(view)).contains("invert_y_axis"),label + ": application preference stays out of scientific visual state")
func finish(view) -> void:
	var report := {"checks":checks,"failures":failures,"restart":restart,"packaged":not OS.has_feature("editor"),"renderer":RenderingServer.get_current_rendering_method(),"layouts":layouts}
	var file := FileAccess.open(output.path_join("restart-report.json" if restart else "report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	view.queue_free(); await settle(); await settle()
	print("Invert Y Axis: ",checks," checks; failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--invert-output="): output = arg.trim_prefix("--invert-output=")
		if arg == "--invert-restart": restart = true
	if output.is_empty(): return
	get_tree().create_timer(140).timeout.connect(func(): push_error("Inversion test timed out"); get_tree().quit(1))
	await get_tree().process_frame
	var view = get_tree().current_scene
	if view == null: view = Viewer.new(); root.add_child(view)
	view.set_process(false); view.scene_prebuffer_enabled = false; view.orbit_enabled = false
	OS.low_processor_usage_mode = false
	await settle()
	if restart:
		check(view.shell.shortcuts.invert_y_axis and view.shell.shortcuts.active.toggle_invert_y_axis == (KEY_I | KEY_MASK_ALT), "Fresh process restores On and Alt+I")
		view.shell.edit_shortcuts(); await settle()
		check(view.shell.shortcuts_editor.invert_y_toggle.button_pressed and view.shell.shortcuts_editor.invert_y_toggle.text == "On", "Restarted editor reflects persisted state")
		view.shell.shortcuts_editor.dismiss(); focus_none()
		var before := Visual.snapshot(view)
		trigger(view,KEY_I|KEY_MASK_ALT)
		check(not view.shell.shortcuts.invert_y_axis and Visual.snapshot(view) == before,"Restarted hotkey toggles Off without moving camera")
		await finish(view); return
	await edit_checks(view)
	for kind in ["particles","fields","meshes","mixed"]:
		view._open_capture(output.path_join(kind+".wvz")); await settle()
		check(not view.committed_sample.is_empty(),kind+": fixture has a usable sample")
		navigation_checks(view,kind+" normal")
		if DisplayServer.get_name() != "headless":
			view.shell.enter_immersive(); await settle()
			check(view.shell.immersive and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,kind+": native Fullscreen entered")
			navigation_checks(view,kind+" fullscreen")
			view.shell.exit_immersive(); await settle()
			check(not view.shell.immersive,kind+": Fullscreen restored")
	view.shell.shortcuts.apply(view.shell.shortcuts.active,true)
	await finish(view)
