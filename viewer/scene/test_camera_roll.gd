extends Node
## #331: measured camera-local roll, connected navigation, and shortcut lifecycle.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Bindings = preload("res://ui/keyboard_shortcuts.gd")
var output := ""
var restart := false
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
@onready var root: Window = get_tree().root

func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 4: await get_tree().process_frame
	if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
func unfocus() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
func key(code: int, pressed: bool = true, physical: int = 0) -> InputEventKey:
	var event := InputEventKey.new(); event.keycode = code & KEY_CODE_MASK; event.physical_keycode = physical; event.pressed = pressed
	event.ctrl_pressed = bool(code & KEY_MASK_CTRL); event.shift_pressed = bool(code & KEY_MASK_SHIFT)
	event.alt_pressed = bool(code & KEY_MASK_ALT); event.meta_pressed = bool(code & KEY_MASK_META)
	return event
func held(view, action: String, seconds: float, frames: int = 60) -> void:
	var event: InputEventKey = view.shell.shortcuts.event_for(action); event.pressed = true
	root.push_input(event)
	for i in frames: view._update_camera_roll(seconds / frames)
	event.pressed = false; root.push_input(event)
func same_pose(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < .0001 and a.basis.is_equal_approx(b.basis)
func poses(view) -> Dictionary:
	var result := {view:view.transform, view.scene_layers:view.scene_layers.transform, view.current_instance:view.current_instance.transform, view.guide_mesh:view.guide_mesh.transform}
	for node in view.scene_layers.views.values(): result[node] = node.transform
	return result
func picture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK, name+": screenshot saved")

func angles(view, label: String) -> void:
	unfocus(); view.inspection_paused = false; view.free_camera = true; view.orbit_enabled = false; view._reset_camera()
	view.camera_target = Vector3(3,-2,7); view.camera_distance = 32
	view.yaw = .7; view.pitch = deg_to_rad(115); view._update_camera()
	var saved := Visual.snapshot(view)
	var start: Transform3D = view.camera.transform
	var target: Vector3 = view.camera_target
	var radius: float = view.camera_distance
	var world := poses(view)
	var source_state: Dictionary = view.scene_layers.snapshot().duplicate(true)
	var sample: Dictionary = view.committed_sample.duplicate(true)
	var points: PackedVector3Array = view.frame_a.positions.duplicate() if view.frame_a != null else PackedVector3Array()
	for action in ["roll_camera_left","roll_camera_right"]:
		var sign := 1.0 if action == "roll_camera_left" else -1.0
		Visual.apply(view,saved); unfocus()
		var event: InputEventKey = view.shell.shortcuts.event_for(action); event.pressed = true; root.push_input(event)
		check(view.camera.transform == start,label+": roll press does not jump")
		var echo: InputEventKey = event.duplicate(); echo.echo = true; root.push_input(echo)
		for step in 240:
			view._update_camera_roll(1.0/60)
			check(view.camera.position == start.origin and view.camera.basis.z.distance_to(start.basis.z) < .00001 and absf(view.camera.basis.determinant()-1.0) < .00001,label+": fixed position/forward and orthonormal basis "+action)
			if (step+1) in [60,120,240]:
				var angle := sign * float(step+1) / 60 * PI / 2
				var expected := (start.basis * Basis(Vector3.BACK,angle)).orthonormalized()
				check(view.camera.basis.is_equal_approx(expected),label+": measured "+action+" angle "+str(rad_to_deg(angle)))
				measurements.append({"scene":label,"action":action,"degrees":rad_to_deg(angle),"position_error":view.camera.position.distance_to(start.origin),"forward_error":view.camera.basis.z.distance_to(start.basis.z),"up":Visual.vec(view.camera.basis.y)})
		event.pressed = false; root.push_input(event)
		check(same_pose(start,view.camera.transform),label+": 360 degree revolution returns to original orientation")
		var stopped: Transform3D = view.camera.transform; view._update_camera_roll(.2)
		check(view.camera.transform == stopped and view.camera_roll_keys.is_empty(),label+": release stops immediately")
		check(view.camera_target == target and view.camera_distance == radius,label+": navigation target and radius stay fixed")
	Visual.apply(view,saved); unfocus()
	held(view,"roll_camera_left",1.0); held(view,"roll_camera_right",1.0)
	check(same_pose(start,view.camera.transform),label+": opposing rolls undo one another")
	for frames in [12,120]:
		Visual.apply(view,saved); unfocus(); held(view,"roll_camera_left",1.0,frames)
		check(view.camera.basis.y.distance_to(-start.basis.x) < .00001,label+": 90 degree bank uses elapsed time at "+str(frames)+" Hz")
	check(view.scene_layers.snapshot() == source_state and view.committed_sample == sample and not view.playing,label+": roll leaves scene presentation/source clocks and sample unchanged")
	# Translation and steering must use the banked local axes.
	for pair in [[KEY_W,Vector3.FORWARD],[KEY_S,Vector3.BACK],[KEY_A,Vector3.LEFT],[KEY_D,Vector3.RIGHT],[KEY_Q,Vector3.DOWN],[KEY_E,Vector3.UP]]:
		var before: Transform3D = view.camera.transform
		Input.parse_input_event(key(pair[0],true,pair[0])); Input.flush_buffered_events()
		view._move_free_camera(.1)
		Input.parse_input_event(key(pair[0],false,pair[0])); Input.flush_buffered_events()
		var shift: Vector3 = before.basis * pair[1] * .1 * maxf(1,radius*.5) * view.free_camera_speed_scale
		check(view.camera.position.distance_to(before.origin+shift) < .0001 and view.camera.basis.is_equal_approx(before.basis),label+": rolled local translation "+str(pair[0]))
	var before: Transform3D = view.camera.transform
	view._steer_camera(Vector2(30,20))
	var expected: Basis = (before.basis * Basis(Vector3.UP,-30*view.FREE_LOOK_SENSITIVITY) * Basis(Vector3.RIGHT,-20*view.FREE_LOOK_SENSITIVITY)).orthonormalized()
	check(view.camera.position == before.origin and view.camera.basis.is_equal_approx(expected),label+": RMB uses banked local right/up")
	var rolled := Visual.snapshot(view)
	var path := output.path_join(label+"-preset.json")
	check(view._save_inspection(path) == OK,label+": rolled view preset saves")
	view._reset_camera(); check(view._load_inspection(path).is_empty(),label+": rolled view preset loads")
	view._update_camera(); check(same_pose(view.camera.transform,Transform3D(expected,before.origin)),label+": persisted roll survives camera update")
	var offline = Viewer.new(); offline.offline_instance = true; root.add_child(offline); offline.set_process(false)
	Visual.apply(offline,rolled); offline._update_camera()
	check(same_pose(offline.camera.transform,view.camera.transform),label+": export worker snapshot retains full rolled camera transform")
	offline.queue_free()
	view._focus_activity(); check(view.camera.basis.is_equal_approx(expected),label+": Frame Scene preserves rolled heading")
	view.orbit_enabled = true; var basis: Basis = view.camera.basis; var old_yaw: float = view.yaw
	view._advance_auto_orbit(.1)
	check(view.camera.basis.is_equal_approx((Basis(Vector3.UP,.1*view.orbit_speed)*basis).orthonormalized()) and view.yaw != old_yaw,label+": Auto Orbit continues banked basis without horizon reset")
	view.orbit_enabled = false
	view.shell.shortcuts.active.orbit_camera_left = KEY_F6
	view.shell.shortcuts.active.orbit_camera_right = KEY_F7
	view.manual_orbit_keys.clear(); view.manual_orbit_direction = 0.0; unfocus()
	root.push_input(key(KEY_F6)); root.push_input(key(KEY_F8))
	var axis: Vector3 = view.camera.basis.y
	for i in 10:
		var prior: Basis = view.camera.basis
		view._update_manual_orbit(.01); view._update_camera_roll(.01)
		check(view.camera.basis.is_equal_approx((Basis(axis,-.01*view.MANUAL_ORBIT_RATE)*prior*Basis(Vector3.BACK,.01*view.CAMERA_ROLL_RATE)).orthonormalized()),label+": simultaneous held orbit carries bank forward")
	root.push_input(key(KEY_F6,false)); root.push_input(key(KEY_F8,false))
	view.shell.shortcuts.active.orbit_camera_left = 0; view.shell.shortcuts.active.orbit_camera_right = 0
	for node in world: check(node.transform == world[node],label+": scientific/world transform unchanged: "+node.name)
	if view.frame_a != null: check(view.frame_a.positions == points,label+": original scientific coordinates unchanged")
	view._reset_camera(); check(not view.camera_orbit_basis_active,label+": intentional Reset Camera clears roll")

func guards(view) -> void:
	unfocus(); view.free_camera = true; view.orbit_enabled = true
	var before: Transform3D = view.camera.transform
	root.push_input(key(KEY_F8)); check(not view.orbit_enabled and view.free_camera and view.camera.transform == before,"Roll takes manual control from Auto Orbit on press")
	view._update_camera_roll(.1); root.push_input(key(KEY_F8,false))
	check(not view.orbit_enabled,"Roll release leaves Auto Orbit off")
	view.free_camera = false; before = view.camera.transform
	root.push_input(key(KEY_F8)); view._update_camera_roll(.1); root.push_input(key(KEY_F8,false))
	check(not view.free_camera and view.camera.transform == before,"Roll does not enable a disabled Free Camera")
	view.free_camera = true
	root.push_input(key(KEY_F8)); root.push_input(key(KEY_F9)); view._update_camera_roll(.1)
	check(view.camera.transform == before,"Opposite roll keys cancel")
	root.push_input(key(KEY_F9,false)); view._update_camera_roll(.1)
	check(not view.camera.basis.is_equal_approx(before.basis),"Releasing one roll direction resumes the other")
	root.push_input(key(KEY_F8,false))
	for guard in ["inspection_busy","inspection_paused","offline_instance","dragging","free_look_dragging"]:
		root.push_input(key(KEY_F8)); view.set(guard,true); before = view.camera.transform; view._update_camera_roll(.1)
		check(view.camera_roll_keys.is_empty() and view.camera.transform == before,guard+": held roll is suppressed")
		view.set(guard,false)
	for control in [LineEdit.new(),TextEdit.new(),SpinBox.new(),Button.new()]:
		root.add_child(control)
		var editor: Control = control.get_line_edit() if control is SpinBox else control
		root.push_input(key(KEY_F8)); editor.grab_focus(); before = view.camera.transform; view._update_camera_roll(.1)
		root.push_input(key(KEY_F9)); view._update_camera_roll(.1)
		check(view.camera_roll_keys.is_empty() and view.camera.transform == before,"Keyboard focus suppresses existing/new roll: "+control.get_class())
		editor.release_focus(); control.free()
	root.push_input(key(KEY_F8)); root.focus_exited.emit(); before = view.camera.transform; view._update_camera_roll(.1)
	check(view.camera_roll_keys.is_empty() and view.camera.transform == before,"Window focus loss ends roll")
	view.shell.shortcuts.active.roll_camera_left = KEY_F8 | KEY_MASK_CTRL
	root.push_input(key(KEY_F8 | KEY_MASK_CTRL)); check(not view.camera_roll_keys.is_empty(),"Modifier chord starts roll")
	root.push_input(key(KEY_CTRL,false)); check(view.camera_roll_keys.is_empty(),"Modifier release stops roll")
	view.shell.shortcuts.active.roll_camera_left = KEY_F8
	root.push_input(key(KEY_F8)); view.shell.shortcuts.active.roll_camera_left = KEY_F10; before = view.camera.transform; view._update_camera_roll(.1)
	check(view.camera_roll_keys.is_empty() and view.camera.transform == before,"Rebinding a held key cancels stale roll")
	view.shell.shortcuts.active.roll_camera_left = KEY_F8
	for command in ["reset_camera","frame_scene"]:
		root.push_input(key(KEY_F8)); view._dispatch_shortcut(command); before = view.camera.transform; view._update_camera_roll(.1)
		check(view.camera_roll_keys.is_empty() and view.camera.transform == before,command+": stale roll does not resume")
	root.push_input(key(KEY_F8)); view.shell.edit_orbit_center(); before = view.camera.transform; view._update_camera_roll(.1)
	root.push_input(key(KEY_F9)); view._update_camera_roll(.1)
	check(view.camera_roll_keys.is_empty() and view.camera.transform == before,"Orbit editor suppresses roll without changing its chosen plane")
	view.shell.dismiss_orbit_editor(); unfocus()
	view.shell.edit_orbit_center(); var orbit = view.shell.orbit_editor
	orbit.center = view.camera_target; orbit.write_fields(); orbit.commit(); unfocus()
	var plane: Dictionary = orbit.applied_orbit.duplicate(true)
	root.push_input(key(KEY_F8)); view._update_camera_roll(.1); root.push_input(key(KEY_F8,false))
	check(orbit.matches_applied_orbit() and orbit.applied_orbit.axis == plane.axis and orbit.applied_orbit.center == plane.center and orbit.applied_orbit.radius == plane.radius,"Roll preserves the Apply-time observer plane, center and radius")
	var banked: Basis = view.camera.basis
	view._toggle_auto_orbit(); view._advance_auto_orbit(.1)
	check(view.camera.basis.is_equal_approx((Basis(plane.axis,.1*view.orbit_speed)*banked).orthonormalized()) and absf(plane.axis.dot(view.camera.position-view.camera_target)) < .0001,"Resumed custom Auto Orbit retains bank and its chosen plane")
	for inward in [false,true]:
		var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP if inward else MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true; wheel.factor = .5
		banked = view.camera.basis; var distance: float = view.camera_distance
		view._unhandled_input(wheel)
		check(view.camera.basis.is_equal_approx(banked) and orbit.applied_orbit.axis == plane.axis and (view.camera_distance < distance if inward else view.camera_distance > distance),"Fractional zoom retains bank and custom plane: "+str(inward))
	view.orbit_enabled = false
	root.push_input(key(KEY_F8)); var reopening_basis: Basis = view.camera.basis; view._open_capture(output.path_join("mixed.wvz")); await view.scene_layers.wait_for_surface(); view.inspection_paused = false
	check(view.camera_roll_keys.is_empty(),"Capture replacement clears held roll")
	check(view.camera.basis.is_equal_approx(reopening_basis),"Capture replacement preserves intentional camera bank")
	before = view.camera.transform; view._update_camera_roll(.1); check(view.camera.transform == before,"Opening a capture does not resume stale roll")
	await settle(); unfocus(); root.push_input(key(KEY_F8)); view.set_process(true); await get_tree().create_timer(.15).timeout
	check(not view.camera.basis.is_equal_approx(before.basis) and view.camera.position.distance_to(before.origin) < .0001,"Actual process loop continuously banks in place")
	root.push_input(key(KEY_F8,false)); before = view.camera.transform; await get_tree().create_timer(.1).timeout
	check(view.camera.transform == before,"Actual process loop stops on release")
	view.set_process(false); view._restore_render_pacing()

func shortcuts(view) -> void:
	var shell = view.shell
	shell.edit_shortcuts(); await settle(); var dialog = shell.shortcuts_editor
	for action in ["roll_camera_left","roll_camera_right"]:
		check(dialog.rows.has(action) and dialog.rows[action].label.text == ("Roll Camera Left" if action.ends_with("left") else "Roll Camera Right") and dialog.rows[action].key.text == "Unbound","Both named roll rows are initially Unbound: "+action)
		dialog.rows[action].clear.pressed.emit()
	dialog.start_capture("roll_camera_left"); root.push_input(key(KEY_F8)); root.push_input(key(KEY_F8,false))
	dialog.start_capture("roll_camera_right"); root.push_input(key(KEY_F8)); root.push_input(key(KEY_F8,false))
	check(dialog.staged.roll_camera_left == 0 and dialog.staged.roll_camera_right == KEY_F8,"Binding conflict transfers within roll actions")
	dialog.start_capture("roll_camera_left"); root.push_input(key(KEY_F8)); dialog.start_capture("roll_camera_right"); root.push_input(key(KEY_F9))
	dialog.apply_button.pressed.emit(); await settle()
	check(dialog.visible and shell.shortcuts.active.roll_camera_left == KEY_F8 and shell.shortcuts.active.roll_camera_right == KEY_F9,"Apply saves/activates separate roll bindings and remains open")
	var before: Transform3D = view.camera.transform; root.push_input(key(KEY_F8)); view._update_camera_roll(.1)
	check(view.camera_roll_keys.is_empty() and view.camera.transform == before,"Editor blocks navigation even after Apply")
	for name in ["Dark","Light"]:
		shell.appearance.select(name == "Light"); await settle()
		check(dialog.rows.roll_camera_left.label.get_theme_font("font") == dialog.rows.orbit_camera_left.label.get_theme_font("font") and dialog.rows.roll_camera_left.label.get_theme_color("font_color") == dialog.rows.orbit_camera_left.label.get_theme_color("font_color"),name+": roll labels use existing Navigation typography")
		picture("shortcuts-"+name.to_lower())
	dialog.rows.roll_camera_left.clear.pressed.emit(); check(dialog.staged.roll_camera_left == 0,"Clear stages Unbound")
	dialog.cancel.pressed.emit(); check(shell.shortcuts.active.roll_camera_left == KEY_F8,"Cancel discards only unapplied Clear")
	shell.edit_shortcuts(); dialog.reset.pressed.emit(); check(dialog.staged.roll_camera_left == 0 and dialog.staged.roll_camera_right == 0,"Reset Defaults restores Unbound rolls")
	dialog.close_button.pressed.emit(); check(shell.shortcuts.active.roll_camera_left == KEY_F8,"Close X discards unapplied defaults")
	shell.edit_shortcuts(); dialog.rows.roll_camera_left.clear.pressed.emit(); root.push_input(key(KEY_ESCAPE)); check(not dialog.visible and shell.shortcuts.active.roll_camera_left == KEY_F8,"Escape discards unapplied edits")
	shell.edit_shortcuts(); dialog.rows.roll_camera_left.clear.pressed.emit(); dialog.apply_button.pressed.emit(); dialog.cancel.pressed.emit(); unfocus()
	before = view.camera.transform; root.push_input(key(KEY_F8)); view._update_camera_roll(.1); root.push_input(key(KEY_F8,false))
	check(shell.shortcuts.active.roll_camera_left == 0 and view.camera.transform == before,"Applied Clear disables old roll binding")
	shell.edit_shortcuts(); dialog.start_capture("roll_camera_left"); root.push_input(key(KEY_F8)); dialog.apply_button.pressed.emit()
	var prior_path: String = shell.shortcuts.storage_path
	shell.shortcuts.storage_path = output.path_join("missing/profile.cfg")
	dialog.start_capture("roll_camera_left"); root.push_input(key(KEY_F10)); dialog.apply_button.pressed.emit()
	check(dialog.visible and shell.shortcuts.active.roll_camera_left == KEY_F8,"Failed persistence does not activate draft roll binding")
	shell.shortcuts.storage_path = prior_path; dialog.cancel.pressed.emit(); unfocus()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--roll-output="): output = arg.trim_prefix("--roll-output=")
		if arg == "--roll-restart": restart = true
	if output.is_empty(): queue_free(); return
	get_tree().create_timer(120).timeout.connect(func(): push_error("Roll tests timed out"); get_tree().quit(1))
	await get_tree().process_frame
	var view = get_tree().current_scene
	if view == null: view = Viewer.new(); root.add_child(view)
	view.set_process(false); view.scene_prebuffer_enabled = false
	if restart:
		check(view.shell.shortcuts.active.roll_camera_left == KEY_F8 and view.shell.shortcuts.active.roll_camera_right == KEY_F9,"Fresh process restores separate roll bindings")
		unfocus(); view.inspection_paused = false; var before: Transform3D = view.camera.transform
		held(view,"roll_camera_left",1.0); check(view.camera.basis.y.distance_to(-before.basis.x) < .00001,"Persisted roll binding dispatches after restart")
	else:
		check(view.shell.shortcuts.active.roll_camera_left == 0 and view.shell.shortcuts.active.roll_camera_right == 0,"Fresh profile leaves both roll defaults Unbound")
		check(Bindings.ACTIONS.filter(func(a): return a[0].begins_with("roll_camera_")).size() == 2,"Exactly two independent roll actions")
		await shortcuts(view)
		for scene in ["particles","fields","meshes","mixed"]:
			view._open_capture(output.path_join(scene+".wvz")); view.playing = false
			check(await view.scene_layers.wait_for_surface(),scene+": fixture ready")
			angles(view,scene)
		await guards(view)
		if DisplayServer.get_name() != "headless":
			view.shell.enter_immersive(); await settle(); angles(view,"fullscreen")
			view._reset_camera(); unfocus(); view.shell.exit_immersive(); await settle()
			view.camera_target = Vector3(.5,.5,.5); view.camera_distance = 5; view.yaw = 0; view.pitch = 0; view._update_camera()
			var initial_projection: Vector2
			for angle in [0,90,180,360]:
				view._reset_camera(); view.camera_target = Vector3(.5,.5,.5); view.camera_distance = 5; view.yaw = 0; view.pitch = 0; view._update_camera()
				held(view,"roll_camera_left",float(angle)/90); await settle()
				var projection: Vector2 = view.camera.unproject_position(Vector3(.3,.9,0))
				var center := root.get_visible_rect().size*.5
				if angle == 0: initial_projection = projection-center
				check((projection-center).distance_to(initial_projection.rotated(deg_to_rad(angle))) < .001,"Screen projection banks around fixed view axis: "+str(angle))
				picture("bank-"+str(angle))
	var report := {"checks":checks,"failures":failures,"measurements":measurements,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"packaged":OS.has_feature("template"),"restart":restart}
	var file := FileAccess.open(output.path_join("restart-report.json" if restart else "roll-report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	view._clear_manual_navigation(); view.queue_free(); await get_tree().process_frame
	# Flush queued native texture releases before the rendering server shuts down.
	if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
	await get_tree().process_frame
	print("CAMERA ROLL: %d checks, %d failures" % [checks,failures.size()]); get_tree().quit(0 if failures.is_empty() else 1)
