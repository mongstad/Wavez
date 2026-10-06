extends SceneTree
## Issue #258: free-look in place and held view-relative orbit; no scene motion.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Bindings = preload("res://ui/keyboard_shortcuts.gd")
var output := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func close_pose(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < .0001 and a.basis.is_equal_approx(b.basis)
func focus_none() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
func orbit_key(view, action: String, held: bool) -> InputEventKey:
	var event: InputEventKey = view.shell.shortcuts.event_for(action); event.pressed = held
	if held: view._unhandled_input(event)
	else: view._input(event)
	return event
func mouse(view, button: MouseButton, held: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = held
	event.position = Vector2(400,300) if held else Vector2(0,0)
	if held: view._unhandled_input(event)
	else: view._input(event)
func steering(view, delta: Vector2) -> void:
	mouse(view,MOUSE_BUTTON_RIGHT,true)
	var event := InputEventMouseMotion.new(); event.position = Vector2(400,300)+delta
	view._input(event)
	mouse(view,MOUSE_BUTTON_RIGHT,false)
func held_orbit(view, action: String, seconds: float, frames: int) -> void:
	orbit_key(view,action,true)
	for frame in frames: view._update_manual_orbit(seconds/frames)
	orbit_key(view,action,false)
func poses(view) -> Dictionary:
	var result := {view:view.transform,view.scene_layers:view.scene_layers.transform,view.current_instance:view.current_instance.transform}
	for node in view.scene_layers.views.values(): result[node] = node.transform
	for node in view.trail_instances: result[node] = node.transform
	return result

func navigate(view, label: String) -> void:
	focus_none(); view._reset_camera(); view.inspection_paused = false; view.free_camera = true
	view.camera_target = Vector3(3,-2,7); view.camera_distance = 32
	view.yaw = .7; view.pitch = deg_to_rad(115); view._update_camera()
	var world := poses(view)
	var sample: Dictionary = view.committed_sample.duplicate(true)
	var speed: float = view.free_camera_speed_scale
	var start: Transform3D = view.camera.transform
	var radius: float = view.camera_distance
	view.orbit_enabled = true
	mouse(view,MOUSE_BUTTON_RIGHT,true)
	check(view.free_look_dragging and not view.orbit_enabled and view.camera.transform == start,label+": RMB takes control on press without moving or snapping")
	var motion := InputEventMouseMotion.new(); motion.position = Vector2(480,255)
	view._input(motion)
	var expected: Basis = (start.basis * Basis(Vector3.UP,-80*view.FREE_LOOK_SENSITIVITY) * Basis(Vector3.RIGHT,45*view.FREE_LOOK_SENSITIVITY)).orthonormalized()
	check(view.camera.position == start.origin and view.camera.basis.is_equal_approx(expected),label+": both RMB axes steer around local view axes at a fixed position")
	check(view.camera_distance == radius,label+": steering retains the radius")
	var steered: Transform3D = view.camera.transform
	mouse(view,MOUSE_BUTTON_RIGHT,false)
	motion.position += Vector2(200,200); view._input(motion)
	check(not view.free_look_dragging and view.camera.transform == steered,label+": release over chrome stops steering with no snap")
	view._update_camera()
	check(close_pose(steered,view.camera.transform),label+": target/basis synchronization survives the next camera update")
	# Verify every unchanged translation direction after steering, including
	# a long W flight through the former target/geometry with no collision gate.
	for pair in [[KEY_W,Vector3.FORWARD],[KEY_S,Vector3.BACK],[KEY_A,Vector3.LEFT],[KEY_D,Vector3.RIGHT],[KEY_Q,Vector3.DOWN],[KEY_E,Vector3.UP]]:
		var before: Transform3D = view.camera.transform
		var event := InputEventKey.new(); event.physical_keycode = pair[0]; event.pressed = true
		Input.parse_input_event(event); Input.flush_buffered_events()
		view._move_free_camera(4.0)
		event = event.duplicate(); event.pressed = false; Input.parse_input_event(event); Input.flush_buffered_events()
		var shift: Vector3 = before.basis * pair[1] * 4.0 * maxf(1,radius*.5) * speed
		check(view.camera.position.distance_to(before.origin+shift) < .0001 and view.camera.basis.is_equal_approx(before.basis),label+": camera-relative translation after steering "+str(pair[0]))
	# Two-axis steering can cross poles and make complete turns without a clamp.
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		var before: Transform3D = view.camera.transform
		for step in 72:
			view._steer_camera(axis * TAU / (72*view.FREE_LOOK_SENSITIVITY))
			check(view.camera.position == before.origin and view.camera.basis.is_finite() and absf(view.camera.basis.determinant()-1) < .00001,label+": continuous in-place steering through poles")
		check(close_pose(view.camera.transform,before),label+": full steering revolution returns to the same view")
	var saved := Visual.snapshot(view)
	view.free_camera_speed_scale = .02; steering(view,Vector2(30,20)); var slow: Transform3D = view.camera.transform
	Visual.apply(view,saved); view.free_camera_speed_scale = 2.5; steering(view,Vector2(30,20))
	check(close_pose(slow,view.camera.transform) and view.free_camera_speed_scale == 2.5,label+": translation scale cannot change steering sensitivity")
	view.free_camera_speed_scale = speed
	var before_left: Transform3D = view.camera.transform
	view.dragging = true; view.last_mouse = Vector2.ZERO
	motion.position = Vector2(70,-100); view._unhandled_input(motion); view.dragging = false
	expected = (Basis(Vector3.UP,-70*.006) * before_left.basis * Basis(Vector3.RIGHT,-100*.006)).orthonormalized()
	check(close_pose(view.camera.transform,Transform3D(expected,view.camera_target+expected.z*radius)),label+": accepted LMB tumble and sensitivity survive steering")
	var target: Vector3 = view.camera_target
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.factor = .5
	view._unhandled_input(wheel)
	check(view.camera_target == target and is_equal_approx(view.camera_distance,minf(radius,maxf(maxf(view.camera.near*2,view.half_extent+view.camera.near),radius*pow(.9,.5)))),label+": existing fractional wheel zoom after steering")
	view.camera_distance = radius; view._update_camera()
	manual_orbit(view,label)
	var before_restore: Transform3D = view.camera.transform
	var path := output.path_join(label.replace(" ","-")+"-preset.json")
	check(view._save_inspection(path) == OK,label+": save steered/orbited view preset")
	view._reset_camera(); check(view._load_inspection(path).is_empty(),label+": load view preset")
	view._update_camera(); check(close_pose(before_restore,view.camera.transform),label+": restored full camera basis does not snap")
	var orientation: Basis = view.camera.basis
	view._focus_activity(); check(view.camera.basis.is_equal_approx(orientation),label+": Frame Scene retains steered orientation")
	view._reset_camera()
	check(not view.camera_orbit_basis_active and is_equal_approx(view.yaw,deg_to_rad(38)) and is_equal_approx(view.pitch,deg_to_rad(24)),label+": Reset Camera restores accepted scene framing and orientation")
	for node in world: check(node.transform == world[node],label+": scientific/world transform unchanged: "+node.name)
	check(view.committed_sample == sample and not view.playing,label+": navigation preserves scientific sample and playback state")
	check(view.free_camera_speed_scale == speed,label+": navigation retains selected translation scale")

func manual_orbit(view, label: String) -> void:
	var target: Vector3 = view.camera_target
	var radius: float = view.camera_distance
	var saved := Visual.snapshot(view)
	var initial: Transform3D = view.camera.transform
	var axis: Vector3 = initial.basis.y.normalized()
	view.orbit_enabled = true
	var key := orbit_key(view,"orbit_camera_left",true)
	check(not view.orbit_enabled and not view.manual_orbit_keys.is_empty(),label+": first orbit key immediately takes manual control")
	view._update_manual_orbit(.1)
	var expected := (Basis(axis,-view.MANUAL_ORBIT_RATE*.1)*initial.basis).orthonormalized()
	check(close_pose(view.camera.transform,Transform3D(expected,target+expected.z*radius)),label+": left key moves camera left around the captured screen-up axis")
	var echo: InputEventKey = key.duplicate(); echo.echo = true; view._unhandled_input(echo)
	view._update_manual_orbit(.1)
	expected = (Basis(axis,-view.MANUAL_ORBIT_RATE*.2)*initial.basis).orthonormalized()
	check(view.camera.basis.is_equal_approx(expected),label+": OS repeat adds no orbit step or reset")
	orbit_key(view,"orbit_camera_left",false)
	var stopped: Transform3D = view.camera.transform
	view._update_manual_orbit(1.0); check(view.camera.transform == stopped,label+": release stops orbit immediately")
	Visual.apply(view,saved); held_orbit(view,"orbit_camera_right",.2,12)
	expected = (Basis(axis,view.MANUAL_ORBIT_RATE*.2)*initial.basis).orthonormalized()
	check(view.camera.basis.is_equal_approx(expected),label+": right key mirrors left")
	for rate in [12,120]:
		Visual.apply(view,saved); held_orbit(view,"orbit_camera_left",1.0,rate)
		expected = (Basis(axis,-view.MANUAL_ORBIT_RATE)*initial.basis).orthonormalized()
		check(close_pose(view.camera.transform,Transform3D(expected,target+expected.z*radius)),label+": elapsed-time orbit is independent of frame rate "+str(rate))
	for action in ["orbit_camera_left","orbit_camera_right"]:
		Visual.apply(view,saved); orbit_key(view,action,true)
		for step in 72:
			view._update_manual_orbit(TAU/(72*view.MANUAL_ORBIT_RATE))
			check(view.camera_target == target and view.camera_distance == radius and view.camera.basis.y.distance_to(axis) < .00001 and absf(view.camera.position.distance_to(target)-radius) < .0001,label+": held orbit preserves view-up, target and radius")
		orbit_key(view,action,false); check(close_pose(initial,view.camera.transform),label+": complete orbit returns to starting view")
	var speed: float = view.free_camera_speed_scale
	view.free_camera_speed_scale = .02; held_orbit(view,"orbit_camera_left",.2,12); var slow: Transform3D = view.camera.transform
	Visual.apply(view,saved); view.free_camera_speed_scale = 2.5; held_orbit(view,"orbit_camera_left",.2,12)
	check(close_pose(slow,view.camera.transform),label+": translation scale cannot change orbit angular rate")
	view.free_camera_speed_scale = speed
	orbit_key(view,"orbit_camera_left",true); orbit_key(view,"orbit_camera_right",true)
	stopped = view.camera.transform; view._update_manual_orbit(.2)
	check(view.camera.transform == stopped,label+": opposite orbit keys cancel")
	orbit_key(view,"orbit_camera_right",false); view._update_manual_orbit(.1)
	check(not close_pose(stopped,view.camera.transform),label+": releasing one direction resumes the other")
	view._clear_manual_navigation(); stopped = view.camera.transform; view._update_manual_orbit(.2)
	check(view.camera.transform == stopped and view.manual_orbit_keys.is_empty(),label+": focus-loss cleanup stops held orbit")

func guards(view) -> void:
	var line := LineEdit.new(); root.add_child(line); line.grab_focus()
	var before: Transform3D = view.camera.transform
	orbit_key(view,"orbit_camera_left",true); view._update_manual_orbit(.1)
	check(view.manual_orbit_keys.is_empty() and view.camera.transform == before,"Text focus protects orbit shortcuts")
	line.release_focus(); line.free()
	orbit_key(view,"orbit_camera_left",true); view.inspection_busy = true; view._update_manual_orbit(.1)
	check(view.manual_orbit_keys.is_empty() and view.camera.transform == before,"Capture busy cancels held orbit")
	view.inspection_busy = false
	orbit_key(view,"orbit_camera_left",true); view.shell.edit_shortcuts(); view._update_manual_orbit(.1)
	check(view.manual_orbit_keys.is_empty() and view.camera.transform == before,"Shortcut editor cancels held orbit")
	view.shell.shortcuts_editor.dismiss(); focus_none()
	view.shell.shortcuts.active.orbit_camera_left = KEY_F6 | KEY_MASK_CTRL
	var event := orbit_key(view,"orbit_camera_left",true)
	check(not view.manual_orbit_keys.is_empty(),"Rebound modifier chord starts orbit")
	var modifier := InputEventKey.new(); modifier.keycode = KEY_CTRL; modifier.pressed = false; view._input(modifier)
	check(view.manual_orbit_keys.is_empty(),"Modifier release ends held orbit chord")
	view.shell.shortcuts.active.orbit_camera_left = KEY_F6
	for command in ["reset_camera","frame_scene"]:
		orbit_key(view,"orbit_camera_left",true); view._update_manual_orbit(.1)
		view._dispatch_shortcut(command); before = view.camera.transform
		view._update_manual_orbit(.1)
		check(view.manual_orbit_keys.is_empty() and view.camera.transform == before,command+": framing replaces an active hold without a stale orbit step")

func live_hold(view) -> void:
	focus_none(); view.inspection_paused = false
	var start: Transform3D = view.camera.transform
	var event: InputEventKey = view.shell.shortcuts.event_for("orbit_camera_left"); event.pressed = true
	root.push_input(event)
	view.set_process(true)
	await create_timer(.15).timeout
	check(not close_pose(start,view.camera.transform),"Real process loop advances the held orbit shortcut")
	event = event.duplicate(); event.pressed = false; root.push_input(event)
	var stopped: Transform3D = view.camera.transform
	await create_timer(.1).timeout
	check(view.camera.transform == stopped and view.manual_orbit_keys.is_empty(),"Real process loop stops immediately on key release")
	view.set_process(false); view._restore_render_pacing()

func viewport_mouse_dispatch(view) -> void:
	focus_none()
	var before: Transform3D = view.camera.transform
	var pointer_before := DisplayServer.mouse_get_position()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Cursor starts visible before viewport navigation")
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(400,300)
	root.push_input(press,true)
	check(view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and view.camera.transform == before,"Viewport RMB press hides cursor without a camera snap")
	var motion := InputEventMouseMotion.new(); motion.position = press.position+Vector2(30,20); motion.relative = Vector2(30,20); motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion,true)
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and view.camera.position == before.origin and not view.camera.basis.is_equal_approx(before.basis),"Hidden cursor keeps normal steering without translation")
	press.pressed = false; press.position = Vector2.ZERO; root.push_input(press,true)
	check(not view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Viewport RMB release over chrome restores cursor immediately")
	check(DisplayServer.mouse_get_position() == pointer_before,"RMB hide and restore never warp the pointer")

func cursor_interruptions(view) -> void:
	focus_none()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Viewport hover alone leaves cursor visible")
	mouse(view,MOUSE_BUTTON_LEFT,true)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"LMB alone leaves cursor visible")
	mouse(view,MOUSE_BUTTON_LEFT,false)
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.factor = 1.0
	view._unhandled_input(wheel)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Wheel zoom leaves cursor visible")
	orbit_key(view,"orbit_camera_left",true)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Held orbit shortcut leaves cursor visible")
	orbit_key(view,"orbit_camera_left",false)
	var move := InputEventKey.new(); move.physical_keycode = KEY_W; move.pressed = true
	view._unhandled_input(move)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Free Camera translation key leaves cursor visible")
	move.pressed = false; view._input(move)
	for reason in ["focus", "menu", "shortcuts", "tools", "fullscreen"]:
		mouse(view,MOUSE_BUTTON_RIGHT,true)
		check(view.free_look_dragging and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_HIDDEN),"RMB starts hidden-cursor steering before " + reason)
		match reason:
			"focus": view.get_window().focus_exited.emit()
			"menu": view.shell.menus.File.about_to_popup.emit()
			"shortcuts": view.shell.edit_shortcuts(); view.shell.shortcuts_editor.dismiss()
			"tools": view.tools_ui.open("Camera"); view.tools_ui.close()
			"fullscreen": view.shell.exit_immersive() if view.shell.immersive else view.shell.enter_immersive()
		check(not view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,reason + " ends steering and restores cursor")
	if view.shell.immersive: view.shell.exit_immersive()
	mouse(view,MOUSE_BUTTON_RIGHT,true)
	view.inspection_busy = true
	var motion := InputEventMouseMotion.new(); motion.position = Vector2(410,310); view._input(motion)
	check(not view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Busy inspection ends steering and restores cursor")
	view.inspection_busy = false
	mouse(view,MOUSE_BUTTON_RIGHT,true)
	view._clear_manual_navigation()
	check(not view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Manual navigation cleanup restores cursor")
	mouse(view,MOUSE_BUTTON_RIGHT,true)
	var left_press := InputEventMouseButton.new(); left_press.button_index = MOUSE_BUTTON_LEFT; left_press.pressed = true; left_press.position = Vector2(10,10)
	view._input(left_press)
	check(not view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"LMB press on chrome interrupts RMB and restores cursor")
	left_press.pressed = false; view._input(left_press)
	if DisplayServer.get_name() != "headless":
		view.shell.enter_immersive()
		mouse(view,MOUSE_BUTTON_RIGHT,true)
		check(view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"Fullscreen RMB hides cursor")
		view.shell.exit_immersive()
		check(not view.free_look_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Leaving fullscreen during RMB restores cursor")
		view.shell.enter_immersive()
		mouse(view,MOUSE_BUTTON_RIGHT,true)
		mouse(view,MOUSE_BUTTON_RIGHT,false)
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Fullscreen RMB release restores cursor")
		var double_click := InputEventMouseButton.new(); double_click.button_index = MOUSE_BUTTON_LEFT; double_click.pressed = true; double_click.double_click = true; double_click.position = Vector2(400,300)
		view._unhandled_input(double_click)
		check(not view.shell.immersive and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Double-click exits fullscreen after RMB steering with cursor visible")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-output="): output = arg.trim_prefix("--camera-output=")
	if output.is_empty(): quit(1); return
	create_timer(120).timeout.connect(func(): push_error("Navigation test timed out"); quit(1))
	var view = Viewer.new(); root.add_child(view); view.set_process(false)
	check(view.shell.shortcuts.active.orbit_camera_left == 0 and view.shell.shortcuts.active.orbit_camera_right == 0,"Both orbit actions default to Unbound")
	view.shell.shortcuts.active.orbit_camera_left = KEY_F6; view.shell.shortcuts.active.orbit_camera_right = KEY_F7
	for kind in ["particles","volume","mesh","mixed"]:
		view._open_capture(output.path_join(kind+".wvz")); view.playing = false
		check(await view.scene_layers.wait_for_surface(),kind+": scene ready")
		navigate(view,kind)
	guards(view)
	await live_hold(view)
	if DisplayServer.get_name() != "headless":
		viewport_mouse_dispatch(view)
		view.shell.enter_immersive(); await create_timer(.4).timeout
		navigate(view,"fullscreen")
		viewport_mouse_dispatch(view)
		check(view.shell.immersive,"Navigation preserves fullscreen")
		view.shell.exit_immersive()
	cursor_interruptions(view)
	var file := FileAccess.open(output.path_join("camera-report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"\t")); file.close()
	view.queue_free(); await process_frame
	print("CAMERA NAVIGATION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
