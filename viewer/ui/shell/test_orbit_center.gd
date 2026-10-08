extends SceneTree
## Also runs against an accepted-main source snapshot for direct contract comparison.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Job = preload("res://video/render_job.gd")
const Hash = preload("res://data/capture_index.gd")
var output := ""
var reference := false
var checks := 0
var failures: Array[String] = []
var camera_trace := []
var playback_trace := []
var idle_draws := {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func camera_state(view) -> Dictionary:
	var state := Visual.snapshot(view)
	var result := {}
	for key in ["camera_target","camera_distance","camera_transform","yaw","pitch","orbit_enabled","orbit_speed"]: result[key] = state[key]
	result.free_camera = view.free_camera
	return result
func wheel(view, button: MouseButton) -> void:
	var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = true
	view._unhandled_input(event)
func drag(view) -> void:
	view.dragging = true; view.last_mouse = Vector2.ZERO
	var motion := InputEventMouseMotion.new(); motion.position = Vector2(41,619)
	view._unhandled_input(motion); view.dragging = false
func free_move(view) -> void:
	view.free_camera = true
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
	for code in [KEY_D,KEY_W,KEY_E,KEY_A,KEY_S,KEY_Q]:
		var before: Vector3 = view.camera_target
		var key := InputEventKey.new(); key.physical_keycode = code; key.pressed = true
		Input.parse_input_event(key); Input.flush_buffered_events(); view._move_free_camera(.125)
		key = key.duplicate(); key.pressed = false; Input.parse_input_event(key); Input.flush_buffered_events()
		check(view.camera_target != before,"Free movement key works: "+str(code))
		camera_trace.append(camera_state(view))
func fields(editor, center: Vector3, radius: float) -> void:
	for axis in 3: editor.coordinates[axis].text = str(center[axis])
	editor.radius_input.text = str(radius)
	check(editor.read_fields(),"Finite XYZ/radius accepted")
func commit(view, center: Vector3, radius: float) -> void:
	if reference:
		view.camera_target = center; view.camera_distance = radius; view._update_camera()
	else:
		view.shell.edit_orbit_center()
		fields(view.shell.orbit_editor,center,radius)
		view.shell.orbit_editor.commit()
		check(not view.shell.orbit_editor.visible and not view.shell.orbit_editor.guide.visible,"Apply hides editor and guide")
func ready(view) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 12000:
		await process_frame; view._process(0); view.timeline.refresh(view,true)
		var field = view.scene_layers.field_playback
		if not view.scene_layers.is_buffering() and (not field.active() or field.worker.status().session.get("state") == "ready"): break
	check(not view.scene_layers.is_buffering(),"Requested sample becomes ready")
func playback_state(view, label: String) -> Dictionary:
	view.timeline.refresh(view,true)
	var field = view.scene_layers.field_playback
	var status: Dictionary = field.worker.status()
	return {"label":label,"sample":view.committed_sample.duplicate(true),"requested_time":view.requested_time,"rate":view.physical_rate,"playing":view.playing,"buffering":view.scene_layers.is_buffering(),"coverage":view.timeline.coverage.duplicate(true),"range":field.playback_range(),"prepared_range":field.prepared_range.duplicate(),"session_state":status.session.get("state"),"prepared_count":status.charges.size(),"redraw_on_change":OS.low_processor_usage_mode,"max_fps":Engine.max_fps}
func image_file(name: String) -> void:
	await process_frame; await process_frame; RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,"Rendered "+name)
func editor_tests(view, kind: String) -> void:
	var navigate: MenuButton = view.shell.navigation.get_child(2)
	var menu := navigate.get_popup()
	check(menu.get_item_text(3) == "Edit orbit center…","Navigate exposes target/radius editor")
	menu.id_pressed.emit(3); var editor = view.shell.orbit_editor
	var original := camera_state(view); var sample: Dictionary = view.committed_sample.duplicate(true)
	check(editor.visible and editor.guide.visible,"Editor opens")
	await process_frame; await process_frame
	for axis in 3:
		fields(editor,view.camera_target,view.camera_distance*.4)
		var handle: Dictionary = editor.guide.handle(axis)
		check(not handle.is_empty(),"XYZ handle available: "+str(axis))
		if handle.is_empty(): continue
		var before: Vector3 = editor.center
		var button := InputEventMouseButton.new(); button.position = handle.end; button.button_index = MOUSE_BUTTON_LEFT; button.pressed = true
		root.push_input(button,true)
		check(editor.drag_axis == axis and not view.dragging,"Handle input exclusively edits draft")
		var motion := InputEventMouseMotion.new(); motion.position = handle.end+handle.direction*24
		root.push_input(motion,true)
		button = button.duplicate(); button.pressed = false; button.position = editor.panel.global_position+Vector2(10,10); root.push_input(button,true)
		check(editor.drag_axis == -1,"Handle release over chrome ends drag")
		var movement: Vector3 = editor.edit_basis.inverse()*(editor.center-before)
		check(movement[axis] > 0,"Handle moves captured view axis "+str(axis))
		for other in 3:
			if other != axis: check(absf(movement[other]) < .0001,"Other view coordinate unchanged")
		check(camera_state(view) == original,"XYZ drag never moves accepted camera")
	fields(editor,Vector3(1300,-100,3439),12)
	var radius: float = editor.radius
	editor.adjust_radius(1,false); check(is_equal_approx(editor.radius,radius*1.25),"Coarse logarithmic adjustment")
	editor.adjust_radius(-1,true); check(is_equal_approx(editor.radius,radius*1.25/1.02),"Fine logarithmic adjustment")
	radius = editor.radius
	var radius_wheel := InputEventMouseButton.new(); radius_wheel.button_index = MOUSE_BUTTON_WHEEL_UP; radius_wheel.pressed = true; radius_wheel.shift_pressed = true
	radius_wheel.position = editor.radius_input.get_global_rect().get_center(); root.push_input(radius_wheel,true)
	check(is_equal_approx(editor.radius,radius/1.02) and camera_state(view) == original,"GUI radius wheel changes only draft")
	editor.place_ahead(); check(editor.center.is_equal_approx(view.camera.position-view.camera.basis.z*editor.radius),"Place ahead changes draft only")
	check(camera_state(view) == original and view.committed_sample == sample,"Draft preserves camera and scientific sample")
	for bad in ["nan","inf","-1","0","1e30","oops"]:
		editor.radius_input.text = bad; editor.commit()
		check(editor.visible and camera_state(view) == original,"Reject invalid radius "+bad)
	fields(editor,view.camera_target,view.camera_distance*.4)
	await image_file(kind+"-editor-dark")
	# A test-only white contrast backing exercises the projected UI on both
	# renderers independently of their environment/background rendering.
	var contrast := ColorRect.new(); contrast.color = Color.WHITE
	contrast.mouse_filter = Control.MOUSE_FILTER_IGNORE; contrast.show_behind_parent = true
	editor.guide.add_child(contrast); contrast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await image_file(kind+"-editor-bright")
	check(root.get_texture().get_image().get_pixel(20,120).r > .8,"Bright-background fixture is visibly bright")
	contrast.free()
	editor.dismiss(); check(camera_state(view) == original and not editor.guide.visible,"Cancel preserves accepted camera and hides guide")
	for repeat in 5:
		view.shell.edit_orbit_center(); fields(editor,Vector3(repeat,repeat+1,repeat+2),repeat+1); editor.dismiss()
	check(camera_state(view) == original,"Repeated cancelled setup has no drift")
	view.shell.edit_orbit_center(); fields(editor,view.camera_target,view.camera_distance*.4)
	await create_timer(.5).timeout
	var frames := Engine.get_frames_drawn()
	await create_timer(1.0).timeout
	idle_draws[kind] = Engine.get_frames_drawn()-frames
	check(idle_draws[kind] <= 4,"Stationary editor retains redraw-on-change: "+str(idle_draws[kind]))
	# A proposed target cannot enter any visual snapshot or offline job.
	var saved := Visual.snapshot(view)
	fields(editor,Vector3(123,456,789),.001)
	check(Visual.snapshot(view) == saved,"Serialization excludes proposal without special camera keys")
	editor.dismiss()
	OS.low_processor_usage_mode = false # Ensure frame_post_draw for the capture test.
	await view._capture_inspection_png(output.path_join(kind+"-clean.png"),false)
	view.shell.edit_orbit_center(); fields(editor,view.camera_target,view.camera_distance*.4)
	await view._capture_inspection_png(output.path_join(kind+"-from-editor.png"),false)
	check(not editor.visible and not editor.guide.visible,"PNG dismisses transient guide")
	var clean := Image.load_from_file(output.path_join(kind+"-clean.png"))
	var from_editor := Image.load_from_file(output.path_join(kind+"-from-editor.png"))
	check(Hash.digest(clean.get_data()) == Hash.digest(from_editor.get_data()),"PNG pixels equal without/with pending editor")
	view._process(0)
	if kind == "mixed":
		view.shell.edit_orbit_center(); fields(editor,view.camera_target,view.camera_distance*.4)
		var size := root.size; root.size = Vector2i(960,640); editor.show_details(false); await image_file("compact-editor")
		check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(editor.panel.get_global_rect()),"Compact panel stays inside window")
		check(not editor.panel.get_global_rect().has_point(editor.guide.handle(0).end),"Collapsed controls keep compact gizmo accessible")
		editor.show_details(true)
		root.size = size; view._toggle_fullscreen(); await image_file("fullscreen-editor")
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true; view._input(escape)
		check(not view.shell.immersive and editor.visible,"Fullscreen Escape retains existing recovery and draft")
		editor.dismiss()
func camera_tests(view) -> void:
	camera_trace.append(camera_state(view)); free_move(view)
	for proposal in [[Vector3(1300,-100,3439),17.0],[Vector3(-45000,2600,-9300),13000.0],[Vector3(.003,-.008,.002),.0001]]:
		var pitch: float = view.pitch; var yaw: float = view.yaw
		commit(view,proposal[0],proposal[1]); camera_trace.append(camera_state(view))
		check(view.yaw == yaw and view.pitch == pitch and view.free_camera,"Apply preserves orientation and Free-camera setting")
		var before: float = view.camera_distance
		wheel(view,MOUSE_BUTTON_WHEEL_UP); check(is_equal_approx(view.camera_distance,minf(before,maxf(maxf(view.camera.near*2,view.half_extent+view.camera.near),before*.9))),"Ordinary wheel up uses progressive scene-scale bounds")
		camera_trace.append(camera_state(view)); before = view.camera_distance
		wheel(view,MOUSE_BUTTON_WHEEL_DOWN); check(is_equal_approx(view.camera_distance,maxf(before,minf(maxf(maxf(view.camera.near*2,view.half_extent+view.camera.near),view.camera.far-view.half_extent),before/.9))),"Ordinary wheel down uses progressive scene-scale bounds")
		drag(view); camera_trace.append(camera_state(view)); free_move(view)
		view.orbit_enabled = true; view.orbit_speed = .2; yaw = view.yaw
		view.scene_layers.tick(.125)
		check(is_equal_approx(view.yaw,yaw+.025),"Auto Orbit uses ordinary yaw update")
		camera_trace.append(camera_state(view)); view.orbit_enabled = false
		view._focus_activity(); camera_trace.append(camera_state(view))
		view._reset_camera(); camera_trace.append(camera_state(view))
	view.free_camera = false
func fixture(view, kind: String) -> void:
	await ready(view)
	view.physical_rate = 1.25
	camera_tests(view)
	# Viewport controls remain ordinary navigation even while a proposal is open.
	if not reference: view.shell.edit_orbit_center(); fields(view.shell.orbit_editor,Vector3(31,42,53),37)
	wheel(view,MOUSE_BUTTON_WHEEL_UP); drag(view); free_move(view)
	view.orbit_enabled = true; view.scene_layers.tick(.125); view.orbit_enabled = false
	var navigated := camera_state(view); camera_trace.append(navigated)
	if not reference:
		view.shell.orbit_editor.dismiss(); check(camera_state(view) == navigated,"Cancel preserves deliberate navigation during setup")
	view.free_camera = false; view._reset_camera()
	if not reference: await editor_tests(view,kind)
	view._seek_time(0); await ready(view); view.display_accum = 0
	view.playing = true
	for phase in ["before","during","cancelled","after"]:
		if not reference and phase == "during":
			view.shell.edit_orbit_center(); fields(view.shell.orbit_editor,Vector3(31,42,53),37)
		if not reference and phase == "cancelled": view.shell.orbit_editor.dismiss()
		if phase == "after": commit(view,Vector3(2,1,-3),23)
		for step in 3:
			var before: float = view.committed_sample.requested_time
			view._process(.1); await ready(view)
			check(view.committed_sample.requested_time > before,"Playback advances "+phase)
			playback_trace.append(playback_state(view,kind+"/"+phase+"/"+str(step)))
	view.playing = false; view._process(0)
	if not reference:
		view.shell.edit_orbit_center(); view._focus_activity(); check(not view.shell.orbit_editor.visible,"Frame dismisses proposal")
		view.shell.edit_orbit_center(); view._reset_camera(); check(not view.shell.orbit_editor.visible,"Reset dismisses proposal")
	# Export jobs use the same accepted camera fields regardless of an open proposal.
	if kind == "mixed":
		view.camera_target = Vector3(2,1,-3); view.camera_distance = 23; view._update_camera()
		if not reference: view.shell.edit_orbit_center(); fields(view.shell.orbit_editor,Vector3(77,88,99),.1)
		var state := Visual.snapshot(view)
		for mode in ["locked","orbit"]:
			Job.write_json(output.path_join(mode+"-job.json"),{"version":1,"capture_path":view.capture_path,"state":state,"start_time":0,"end_time":.5,"fps":4,"playback_rate":1,"width":960,"height":540,"output_path":output.path_join(mode+".mp4"),"camera_mode":mode,"orbit_speed":.08,"quality":"high","keep_frames":true,"inspection_sidecars":true,"ffmpeg_path":"/usr/bin/ffmpeg"})
func run() -> void:
	output = OS.get_cmdline_user_args()[0]; reference = "--reference" in OS.get_cmdline_user_args()
	create_timer(180).timeout.connect(func(): push_error("Orbit center test timeout"); quit(1))
	for kind in ["particles","field","mesh","mixed","small","large"]:
		var view = Viewer.new(); view.playing = false; view.orbit_enabled = false; view.capture_path = output.path_join(kind+".wvz")
		root.add_child(view); view.set_process(false)
		await fixture(view,kind)
		view.free(); await process_frame
	Job.write_json(output.path_join("orbit-report.json"),{"checks":checks,"failures":failures,"camera_trace":camera_trace,"playback_trace":playback_trace,"idle_draws":idle_draws})
	print("ORBIT CENTER: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
