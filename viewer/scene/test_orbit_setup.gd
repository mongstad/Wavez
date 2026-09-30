extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
const Sampler = preload("res://scene/timeline_sampler.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var view
var point := Vector2(300,300)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func close_transform(a: Transform3D, b: Transform3D, tolerance := 0.002) -> bool:
	return a.origin.distance_to(b.origin) < tolerance and a.basis.is_equal_approx(b.basis)
func button(code: MouseButton, pressed := true, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = code; event.pressed = pressed; event.position = point; event.shift_pressed = shift
	if view.orbit_setup.active: view._input(event)
	else: view._unhandled_input(event)
func key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	if view.orbit_setup.active: view._input(event)
	else: view._unhandled_input(event)
func movement(code: Key) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	view._move_free_camera(0.1)
	event = event.duplicate(); event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
func look() -> void:
	var event := InputEventMouseMotion.new(); event.relative = Vector2(9,-5)
	view._input(event)
func noncamera() -> Dictionary:
	var state := Visual.snapshot(view)
	# Preset loading materializes explicit false entries for default-hidden legends.
	for id in view.scene_layers.states:
		state.scene.legend_visibility[id] = state.scene.legend_visibility.get(id,false)
	for name in ["camera_transform","camera_target","camera_distance","yaw","pitch","custom_orbit"]: state.erase(name)
	return {"visual":state,"sample":view.committed_sample.duplicate(true),"playing":view.playing,"selection":view.selection_controller.state.snapshot()}
func settle() -> void:
	for i in 4: await process_frame
	RenderingServer.force_draw(false)

func fixture(kind: String) -> void:
	view._open_capture(output.path_join(kind+".ssc")); view.playing = false; view.orbit_enabled = false
	view._focus_activity(); view.free_camera = true
	if root.gui_get_focus_owner() != null: root.gui_get_focus_owner().release_focus()
	var setup = view.orbit_setup
	var science := noncamera()
	var ordinary_state := Visual.snapshot(view); ordinary_state.erase("custom_orbit")
	check(preload("res://scene/inspection_state.gd").validate_visual(view,ordinary_state).is_empty(),kind+" navigation preference is optional in inspection state")
	for location in [Vector3(1300,-100,3439),Vector3(-740,890,-1210)]:
		view.camera_target = location; view.camera_distance = 30; view.yaw = 0.6; view.pitch = 0.3; view._update_camera()
		var before: Transform3D = view.camera.transform
		var saved_target: Vector3 = view.camera_target
		var saved_preset := Preset.snapshot(view)
		button(MOUSE_BUTTON_RIGHT)
		check(setup.active and setup.guide.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,kind+" RMB starts captured preview")
		button(MOUSE_BUTTON_WHEEL_UP,true,true)
		check(setup.radius < 30 and setup.radius > 29,kind+" fine radius step")
		button(MOUSE_BUTTON_WHEEL_DOWN,true,true)
		check(is_equal_approx(setup.radius,30),kind+" reciprocal fine steps")
		for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]:
			var start: Vector3 = view.camera.position
			movement(code)
			check(view.camera.position != start,kind+" live setup movement "+str(code))
			check(setup.pivot.distance_to(view.camera.position-view.camera.basis.z*setup.radius) < 0.002,kind+" moving camera carries proposal")
		var position: Vector3 = view.camera.position
		look()
		check(view.camera.position == position and view.camera.basis != before.basis,kind+" mouse look turns in place")
		check(view.camera_target == saved_target and view.camera_distance == 30,kind+" preview never commits target or radius")
		check(Preset.snapshot(view) == saved_preset,kind+" saving during preview uses committed camera")
		var expected: Vector3 = setup.pivot
		var expected_distance: float = setup.radius
		var pose: Transform3D = view.camera.transform
		button(MOUSE_BUTTON_RIGHT,false)
		check(not setup.active and not setup.guide.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,kind+" release hides guide and restores pointer")
		check(view.camera_target == expected and view.camera_distance == expected_distance and view.custom_orbit,kind+" release commits exact proposal")
		check(close_transform(view.camera.transform,pose),kind+" no position/orientation snap on commit")
		for repeat in 12:
			button(MOUSE_BUTTON_RIGHT); button(MOUSE_BUTTON_RIGHT,false)
		check(close_transform(view.camera.transform,pose) and view.camera_target.distance_to(expected) < 0.002,kind+" repeated setup has no accumulated drift")
		var state := Visual.snapshot(view)
		view.orbit_enabled = true; view.scene_layers.tick(0.1); view.orbit_enabled = false
		check(close_transform(view.camera.transform,Sampler.camera_at(state,0.1,true,view.orbit_speed)),kind+" custom live orbit matches deterministic video")
		check(view.camera.basis.z.normalized().dot((view.camera.position-expected).normalized()) > 0.99999,kind+" target centered through orbit")
		for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]:
			position = view.camera.position
			var target: Vector3 = view.camera_target
			movement(code)
			check(view.camera.position != position,kind+" committed orbit allows free movement "+str(code))
			check((view.camera.position-position).distance_to(view.camera_target-target) < 0.002,kind+" free movement translates camera and local orbit together")
			check(is_equal_approx(view.camera_distance,expected_distance),kind+" free movement preserves configured radius")
		var start_basis: Basis = view.camera.basis
		button(MOUSE_BUTTON_LEFT)
		var drag := InputEventMouseMotion.new(); drag.position = point+Vector2(20,15)
		view._unhandled_input(drag); button(MOUSE_BUTTON_LEFT,false)
		check(view.camera.basis != start_basis,kind+" normal drag still rotates after commit")
		expected = view.camera_target
		button(MOUSE_BUTTON_WHEEL_UP); button(MOUSE_BUTTON_WHEEL_DOWN)
		check(view.camera_target == expected and view.camera_distance != expected_distance,kind+" normal zoom works about the new local target")
		var path := output.path_join(kind+"-preset.json")
		pose = view.camera.transform
		check(view._save_inspection(path) == OK,kind+" portable custom preset saved")
		view._reset_camera()
		check(view._load_inspection(path).is_empty() and view.custom_orbit and view.camera_target == expected,kind+" portable custom pivot restored")
		view._update_camera()
		check(close_transform(view.camera.transform,pose),kind+" restored custom camera continues without snap")
		check(noncamera() == science,kind+" camera interaction preserves scientific and non-camera state")
	# Continuous logarithmic travel covers both ends without legacy 8..500 clamps.
	view.camera_target = Vector3.ZERO; view.camera_distance = 0.02; view._update_camera()
	button(MOUSE_BUTTON_RIGHT)
	for i in 25: button(MOUSE_BUTTON_WHEEL_UP,true,true)
	check(setup.radius > 0 and setup.radius < 0.02,kind+" sub-unit fine adjustment")
	for i in 125: button(MOUSE_BUTTON_WHEEL_DOWN)
	check(setup.radius > 1.0e7 and is_finite(setup.radius) and setup.pivot.is_finite(),kind+" large radius travel remains finite")
	button(MOUSE_BUTTON_RIGHT,false)
	var large: float = view.camera_distance
	button(MOUSE_BUTTON_WHEEL_UP)
	check(view.camera_distance < large and view.camera_distance > 500,kind+" custom zoom has no legacy clamp jump")
	button(MOUSE_BUTTON_RIGHT); look(); key(KEY_R)
	check(not setup.active and not view.custom_orbit and view.camera_target == Vector3.ZERO,kind+" R abandons proposal and custom state")
	check(is_equal_approx(view.yaw,deg_to_rad(38)) and is_equal_approx(view.pitch,deg_to_rad(24)),kind+" R retains accepted reset angles")
	button(MOUSE_BUTTON_RIGHT,false)
	check(not view.custom_orbit,kind+" release after reset does not commit")
	button(MOUSE_BUTTON_RIGHT); look(); view.get_window().focus_exited.emit()
	check(not setup.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,kind+" focus loss cancels and restores pointer")
	button(MOUSE_BUTTON_RIGHT); view._focus_activity()
	check(not setup.active and not view.custom_orbit,kind+" Frame Scene abandons custom setup")
	view._focus_activity()
	if kind == "mixed": await image_checks()

func image_checks() -> void:
	view._apply_preset("Scientific"); view._focus_activity()
	var setup = view.orbit_setup
	await settle()
	check(await view._capture_inspection_png(output.path_join("before.png"),false) == OK,"baseline screenshot succeeds")
	button(MOUSE_BUTTON_RIGHT)
	await settle()
	root.get_texture().get_image().save_png(output.path_join("preview-dark.png"))
	var original_size := root.size
	root.size = Vector2i(1024,640); view.shell.layout(); setup.refresh()
	await settle(); root.get_texture().get_image().save_png(output.path_join("preview-compact.png"))
	check(setup.guide.panel_rect().end.x <= view.shell.dock.get_global_rect().position.x,"compact radius readout clears the simulation panel")
	check(setup.guide.panel_rect().end.y <= view.shell.transport.get_global_rect().position.y,"compact radius readout clears playback controls")
	root.size = original_size; view.shell.layout(); setup.refresh()
	var background: Color = view.environment.background_color
	view.environment.background_color = Color.WHITE
	await settle(); root.get_texture().get_image().save_png(output.path_join("preview-bright.png"))
	view.environment.background_color = background
	look(); movement(KEY_W)
	check(await view._capture_inspection_png(output.path_join("during.png"),false) == OK,"screenshot during draft succeeds")
	check(not setup.active and not setup.guide.visible,"screenshot cancels draft and hides guide")
	var a := Image.load_from_file(output.path_join("before.png")); var b := Image.load_from_file(output.path_join("during.png"))
	check(a.get_data() == b.get_data(),"draft screenshot pixels equal committed view with no guide")
	view.camera_target = Vector3(0.75,0.2,1); view.camera_distance = 12; view._update_camera()
	button(MOUSE_BUTTON_RIGHT); button(MOUSE_BUTTON_RIGHT,false)
	var state := Visual.snapshot(view)
	var f := FileAccess.open(output.path_join("custom-state.json"),FileAccess.WRITE); f.store_string(JSON.stringify(state)); f.close()
	button(MOUSE_BUTTON_RIGHT); view._save_image()
	check(not setup.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and view.screenshot_dialog.visible,"first PNG picker abandons setup and restores pointer")
	view.screenshot_dialog.canceled.emit(); view.screenshot_dialog.hide()
	button(MOUSE_BUTTON_RIGHT)
	view.shell.enter_immersive()
	var mode := DisplayServer.window_get_mode()
	key(KEY_R)
	check(view.shell.immersive and DisplayServer.window_get_mode() == mode,"R resets camera without changing Fullscreen")
	button(MOUSE_BUTTON_RIGHT)
	key(KEY_ESCAPE)
	check(not view.shell.immersive and setup.active,"Escape remains fullscreen recovery, not setup reset")
	button(MOUSE_BUTTON_RIGHT,false)
	view.free_camera = false; button(MOUSE_BUTTON_RIGHT)
	check(not setup.active,"RMB requires Free camera")
	view.free_camera = true
	check(not setup.begin(Vector2(10,10)),"RMB over top chrome cannot begin setup")
	view.inspection_busy = true; check(not setup.begin(point),"image capture busy blocks setup"); view.inspection_busy = false
	# The complete input pipeline must route release even when the cursor is over UI.
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_RIGHT; down.position = point; down.pressed = true
	Input.parse_input_event(down); Input.flush_buffered_events()
	check(setup.active,"real input dispatch enters setup")
	var up := down.duplicate(); up.pressed = false; up.position = Vector2(10,10)
	Input.parse_input_event(up); Input.flush_buffered_events()
	check(not setup.active and view.custom_orbit,"real input release over chrome commits and ends setup")
	# Static guide and completed gestures must not introduce continuous redraw.
	view.set_process(true); view.orbit_enabled = false
	for active in [false,true,false]:
		if active: button(MOUSE_BUTTON_RIGHT)
		else: button(MOUSE_BUTTON_RIGHT,false)
		await create_timer(0.7).timeout
		var frames := Engine.get_frames_drawn()
		await create_timer(0.5).timeout
		check(Engine.get_frames_drawn()-frames <= 2,"stationary custom/preview camera returns to idle; preview="+str(active))
	view.set_process(false)

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(150).timeout.connect(func():push_error("Orbit setup test timed out");quit(1))
	view = Viewer.new(); view.playing = false; view.orbit_enabled = false; view.scene_prebuffer_enabled = false
	root.add_child(view); view.set_process(false)
	for kind in ["particles","field","mesh","mixed"]: await fixture(kind)
	var viewport := SubViewport.new(); viewport.own_world_3d = true; viewport.size = Vector2i(64,64); root.add_child(viewport)
	var offline = Viewer.new(); offline.offline_instance = true; viewport.add_child(offline)
	check(offline.orbit_setup == null,"offline workers never construct temporary guides")
	await settle()
	viewport.queue_free(); view.queue_free()
	for i in 4: await process_frame
	RenderingServer.force_draw(false)
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ORBIT SETUP: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
