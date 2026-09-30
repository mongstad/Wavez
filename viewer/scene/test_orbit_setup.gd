extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
const Sampler = preload("res://scene/timeline_sampler.gd")
var out := ""
var checks := 0
var failures: Array[String] = []
var view
var rendered := {}
var point := Vector2(440,260)
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func close(a: Vector3, b: Vector3, tolerance := .001) -> bool: return a.distance_to(b) <= tolerance
func button(which: MouseButton, down: bool, position := Vector2(440,260), fine := false) -> void:
	var event := InputEventMouseButton.new(); event.button_index = which; event.pressed = down; event.position = position; event.shift_pressed = fine
	if down and not view._orbit_setup_active(): view._unhandled_input(event)
	else: view._input(event)
func reset() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_R; event.pressed = true
	if view._orbit_setup_active(): view._input(event)
	else: view._unhandled_input(event)
func move(code: Key) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); view._move_free_camera(.02)
	event = event.duplicate(); event.pressed = false; Input.parse_input_event(event); Input.flush_buffered_events()
func unchanged_state() -> Dictionary:
	var state := Visual.snapshot(view)
	for key in ["camera_target","camera_transform","camera_distance","yaw","pitch","custom_orbit","camera","orbit_enabled","orbit_speed"]: state.erase(key)
	state.sliders.erase("Orbit speed • radians / second")
	# Preset restoration explicitly stores false for an initially absent legend
	# key. Compare the accepted effective visibility, including its default.
	for id in state.scene.layers:
		if not state.scene.legend_visibility.has(id): state.scene.legend_visibility[id] = false
	state.sample = view.committed_sample.duplicate(true);state.playing = view.playing
	state.requested_time = view.requested_time
	state.selection = view.selection_controller.state.snapshot()
	return state
func snapshot_png(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for n in 3: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK, "Preview evidence "+name)

func wait_jobs(control) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 20000:
		await create_timer(.01).timeout
		if not control.jobs.busy(): return control.jobs.error.is_empty()
	return false

func visible_scene(viewport: SubViewport, observer: Camera3D, label: String) -> void:
	observer.transform = view.camera.global_transform
	observer.fov = view.camera.fov; observer.near = view.camera.near; observer.far = view.camera.far
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for n in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var background := image.get_pixel(0,0)
	var pixels := 0
	for x in image.get_width():
		for y in image.get_height():
			var color := image.get_pixel(x,y)
			if absf(color.r-background.r)+absf(color.g-background.g)+absf(color.b-background.b) > .05: pixels += 1
	check(pixels > 20,label+" renders scientific scene pixels")
	check(image.save_png(out.path_join(label+".png")) == OK,label+" rendered evidence saved")
	rendered[label] = {"scene_pixels":pixels,"target":Visual.vec(view.camera_target),"radius":view.camera_distance,"near":view.camera.near,"far":view.camera.far,"transform":Visual.snapshot(view).camera_transform}
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func recovery_tests(kind: String, tiny_commit := true) -> void:
	view._open_capture(out.path_join(kind+".ssc"));view.playing = false;view.orbit_enabled = false;view.free_camera = true
	var sample: Dictionary = view.committed_sample.duplicate(true)
	var center: Vector3 = view.camera_target
	var environment: Color = view.environment.background_color
	var mode: int = view.environment.background_mode
	var fog: bool = view.environment.fog_enabled
	var stars: bool = view.starfield.visible
	var guides: bool = view.guide_mesh.visible
	view.starfield.hide();view.guide_mesh.hide()
	view.environment.background_mode = Environment.BG_COLOR;view.environment.background_color = Color(.02,.02,.02);view.environment.fog_enabled = false
	var viewport := SubViewport.new();viewport.size = Vector2i(640,400);viewport.world_3d = view.get_world_3d();root.add_child(viewport)
	var observer := Camera3D.new();viewport.add_child(observer);observer.current = true
	await visible_scene(viewport,observer,kind+"-before")
	button(MOUSE_BUTTON_RIGHT,true)
	var setup = view.orbit_setup
	var distance: float = view.camera.position.distance_to(setup.pivot)
	check(distance > setup.radius*3.9,kind+" initial observer is outside compact front sphere")
	var edge: Vector2 = view.camera.unproject_position(setup.pivot+view.camera.basis.x*setup.radius)
	var marker: Vector2 = view.camera.unproject_position(setup.pivot)
	var width: float = marker.distance_to(edge)
	check(width > 20 and width < root.size.x*.25,kind+" initial sphere has manageable projected size")
	if kind == "mesh": await snapshot_png("compact-front-sphere")
	button(MOUSE_BUTTON_WHEEL_DOWN,true)
	edge = view.camera.unproject_position(setup.pivot+view.camera.basis.x*setup.radius)
	check(marker.distance_to(edge) > width*1.55,kind+" normal wheel substantially resizes visible sphere")
	if kind == "mesh": await snapshot_png("coarse-front-sphere")
	var coarse: float = marker.distance_to(edge)
	button(MOUSE_BUTTON_WHEEL_DOWN,true,point,true)
	edge = view.camera.unproject_position(setup.pivot+view.camera.basis.x*setup.radius)
	check(marker.distance_to(edge) > coarse and marker.distance_to(edge) < coarse*1.02,kind+" Shift wheel resizes visible sphere gradually")
	setup.set_radius(.01 if tiny_commit else setup.radius)
	button(MOUSE_BUTTON_RIGHT,false)
	await visible_scene(viewport,observer,kind+"-small-commit")
	check(view.camera.far > view.camera.position.distance_to(center),kind+" custom clipping retains loaded bounds")
	# Simulate the previous, finite but broken clip budget before each actual
	# Auto Orbit input path; it must be repaired before the next rendered frame.
	view.camera.near = .000001;view.camera.far = .08
	var orbit := InputEventKey.new();orbit.keycode = KEY_O;orbit.pressed = true
	view._unhandled_input(orbit);view._advance_orbit(.1)
	await visible_scene(viewport,observer,kind+"-keyboard-auto")
	view.orbit_enabled = false
	view.camera.near = .000001;view.camera.far = .08
	for control in view.shell.navigation.get_children():
		if control is MenuButton: control.get_popup().id_pressed.emit(1)
	view._advance_orbit(.1)
	await visible_scene(viewport,observer,kind+"-menu-auto")
	view.orbit_enabled = false
	reset()
	check(not view.custom_orbit and view.camera_target == center,kind+" reset recovers loaded off-center target")
	await visible_scene(viewport,observer,kind+"-reset")
	for failure in ["radius","target","angles","basis","clip"]:
		view.custom_orbit = true
		match failure:
			"radius": view.camera_distance = NAN
			"target": view.camera_target = Vector3(INF,0,0)
			"angles": view.yaw = NAN;view.pitch = INF
			"basis": view.camera.basis = Basis.IDENTITY.scaled(Vector3(2,1,.5))
			"clip": view.camera.near = 2000;view.camera.far = 1000
		view._set_auto_orbit(true);view._advance_orbit(.1);view.orbit_enabled = false
		check(view._camera_pose_valid() and not view.custom_orbit and view.camera_target == center,kind+" Auto Orbit recovers malformed "+failure)
		await visible_scene(viewport,observer,kind+"-recovered-"+failure)
	# Reset itself must work without the custom flag and without trusting half_extent.
	view.camera_target = Vector3(NAN,INF,0);view.camera_distance = -1;view.yaw = NAN
	var extent: float = view.half_extent;view.half_extent = NAN
	reset();view.half_extent = extent
	check(view._camera_pose_valid() and view.camera_target == center,kind+" reset ignores malformed live camera/extent")
	await visible_scene(viewport,observer,kind+"-malformed-reset")
	for bad in [NAN,INF,-1.0]:
		button(MOUSE_BUTTON_RIGHT,true);setup.radius = bad;button(MOUSE_BUTTON_RIGHT,false)
		check(not setup.active and not view.custom_orbit and view._camera_pose_valid() and view.camera_target == center,kind+" rejects malformed proposal "+str(bad))
	button(MOUSE_BUTTON_RIGHT,true);setup.target_distance = NAN;button(MOUSE_BUTTON_RIGHT,false)
	check(not setup.active and not view.custom_orbit and view._camera_pose_valid(),kind+" rejects malformed placement")
	view.custom_orbit = true;view.camera_distance = NAN;view.orbit_enabled = true
	view._advance_orbit(.1);view.orbit_enabled = false
	check(view._camera_pose_valid() and not view.custom_orbit and view.camera_target == center,kind+" already enabled Auto Orbit recovers invalid state")
	await visible_scene(viewport,observer,kind+"-active-auto-recovery")
	check(view.committed_sample == sample,kind+" recovery preserves committed scientific sample")
	view.camera_target = Vector3(1e8,1e8,1e8);view.camera_distance = 5;view._update_camera()
	button(MOUSE_BUTTON_RIGHT,true);setup.set_radius(.0001);button(MOUSE_BUTTON_RIGHT,false)
	check(not setup.active and not view.custom_orbit and view.camera_target == center and view._camera_pose_valid(),kind+" unrepresentable tiny radius at huge coordinates recovers safely")
	check(view.status_label.text.contains("Restored scene camera"),kind+" precision rejection explains camera recovery")
	await visible_scene(viewport,observer,kind+"-precision-reset")
	viewport.queue_free();await process_frame;await process_frame
	view.environment.background_mode = mode;view.environment.background_color = environment;view.environment.fog_enabled = fog
	view.starfield.visible = stars;view.guide_mesh.visible = guides

func scale_tests() -> void:
	for distance in [.001,.1,10.,97.,10000.,1e8]:
		view.camera_target = Vector3.ZERO;view.camera_distance = distance;view._update_camera()
		button(MOUSE_BUTTON_RIGHT,true)
		var setup = view.orbit_setup
		check(is_equal_approx(setup.radius,maxf(.0001,distance*.05)) and is_equal_approx(setup.target_distance,distance*.4),"initial radius scales with camera distance "+str(distance))
		check(view.camera.position.distance_to(setup.pivot) > setup.radius*3.9,"front sphere remains outside observer across scales "+str(distance))
		var before: float = setup.radius
		button(MOUSE_BUTTON_WHEEL_DOWN,true)
		check(is_equal_approx(setup.radius,before*1.6),"coarse wheel scales consistently "+str(distance))
		setup.cancel()
	reset()

func interaction(kind: String) -> void:
	view._open_capture(out.path_join(kind+".ssc"));view.playing = false;view.orbit_enabled = false
	check(view.frame_count > 0, kind+" opened")
	view.free_camera = false
	button(MOUSE_BUTTON_RIGHT,true)
	check(not view.orbit_setup.active, kind+" setup requires Free camera")
	view.free_camera = true
	button(MOUSE_BUTTON_RIGHT,true,view.shell.dock.get_global_rect().get_center())
	check(not view.orbit_setup.active, kind+" dock rejects setup")
	var guard := unchanged_state()
	var framed_center: Vector3 = view.camera_target
	for target in [Vector3(1300,-100,3439),Vector3(-5200,670,9200)]:
		view.camera_target = target;view.camera_distance = 32;view.yaw = .6;view.pitch = .4;view._update_camera()
		var pose: Transform3D = view.camera.transform
		button(MOUSE_BUTTON_RIGHT,true)
		var setup = view.orbit_setup
		check(setup.active and setup.visible, kind+" hold starts temporary preview")
		check(close(setup.pivot,pose.origin-pose.basis.z*setup.target_distance), kind+" ray proposal at arbitrary target")
		check(is_equal_approx(setup.radius,1.6) and is_equal_approx(setup.target_distance,12.8),kind+" small initial sphere ahead of observer")
		var before_coarse: float = setup.radius
		var original_pivot: Vector3 = setup.pivot
		button(MOUSE_BUTTON_WHEEL_DOWN,true)
		check(is_equal_approx(setup.radius,before_coarse*1.6) and close(setup.pivot,original_pivot),kind+" coarse wheel resizes sphere without moving pivot")
		button(MOUSE_BUTTON_WHEEL_UP,true)
		for radius in [.001,.1,3.0,300.0,100000.0,1e8]:
			setup.set_radius(radius)
			check(is_equal_approx(setup.radius,radius), kind+" radius scale "+str(radius))
			check(view.camera_distance == 32 and view.camera_target == target and not view.custom_orbit, kind+" proposal does not commit")
			var before: float = setup.radius
			button(MOUSE_BUTTON_WHEEL_DOWN,true,point,true)
			check(is_equal_approx(setup.radius,before*1.01),kind+" fine multiplicative wheel")
			button(MOUSE_BUTTON_WHEEL_UP,true,point,true)
			check(is_equal_approx(setup.radius,before),kind+" reciprocal wheel no drift")
		setup.set_radius(12)
		setup.slider.value = log(.5)
		check(is_equal_approx(setup.radius,.5),kind+" logarithmic slider dispatch")
		setup.set_radius(12)
		for key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]:
			var previous: Vector3 = view.camera.position
			move(key)
			check(not close(previous,view.camera.position,.00001),kind+" setup navigation "+str(key))
			check(close(setup.pivot,view.camera.position-view.camera.basis.z*setup.target_distance),kind+" live translated proposal")
			check(view.camera_target == target and view.camera_distance == 32,kind+" navigation leaves orbit proposal uncommitted")
		var before_look: Vector3 = view.camera.position
		var before_basis: Basis = view.camera.basis
		var event := InputEventMouseMotion.new(); event.position = point; event.relative = Vector2(24,-17)
		view._input(event)
		check(close(view.camera.position,before_look) and not view.camera.basis.is_equal_approx(before_basis),kind+" mouse look preserves free position")
		check(close(setup.pivot,view.camera.position-view.camera.basis.z*setup.target_distance),kind+" look updates geometric ray")
		var angle: float = view.yaw
		view.orbit_enabled = true;view._advance_orbit(.5);view.orbit_enabled = false
		check(view.yaw == angle,kind+" setup suspends auto orbit")
		var proposal: Vector3 = setup.pivot;var origin: Vector3 = view.camera.position
		if target.x > 0: await snapshot_png(kind+"-setup-dark")
		button(MOUSE_BUTTON_RIGHT,false,view.shell.dock.get_global_rect().get_center())
		check(not setup.active and not setup.visible and view.custom_orbit,kind+" release over chrome commits and hides")
		check(close(view.camera_target,proposal) and is_equal_approx(view.camera_distance,12) and close(view.camera.position,proposal+view.camera.basis.z*12),kind+" commit lands on preview sphere with exact chosen radius")
		var saved := Visual.snapshot(view)
		view.orbit_enabled = true;view.orbit_speed = .2;view._advance_orbit(.5);view.orbit_enabled = false
		check(close(view.camera.position,Sampler.camera_at(saved,.5,true,.2).origin),kind+" committed orbit matches deterministic video")
		check(close(view.camera.position-view.camera.basis.z*12,proposal),kind+" orbit centers local structure")
		move(KEY_D)
		check(view.camera_target == proposal and view.camera_distance == 12,kind+" later free movement retains custom state")
		origin = view.camera.position
		view._align_custom_orbit();view._update_camera()
		check(close(origin,view.camera.position) and view.camera_target == proposal,kind+" resume orbit preserves camera position and pivot")
		for repeat in 20:
			origin = view.camera.position
			button(MOUSE_BUTTON_RIGHT,true)
			view.orbit_setup.set_target_distance(view.camera_distance);view.orbit_setup.set_radius(view.camera_distance)
			button(MOUSE_BUTTON_RIGHT,false)
			check(close(origin,view.camera.position),kind+" repeated equal placement/radius has no numeric drift")
		var recipe := Preset.snapshot(view)
		reset()
		check(not view.custom_orbit and view.camera_target == framed_center,kind+" R clears custom state and restores source center")
		check(Preset.apply(view,recipe).error.is_empty(),kind+" portable custom camera restored")
		check(view.custom_orbit and close(view.camera_target,proposal),kind+" portable preset keeps generic custom pivot")
		var restored: Vector3 = view.camera.position
		view._update_camera()
		check(close(restored,view.camera.position),kind+" preset first update has no snap")
		button(MOUSE_BUTTON_RIGHT,true);view.orbit_setup.set_radius(.25)
		var window_mode := DisplayServer.window_get_mode()
		var immersive: bool = view.shell.immersive
		reset()
		check(not setup.active and not setup.visible and not view.custom_orbit and view.camera_target == framed_center,kind+" R during setup abandons proposal")
		check(view.shell.immersive == immersive and DisplayServer.window_get_mode() == window_mode,kind+" R preserves window state")
		check(is_equal_approx(view.yaw,deg_to_rad(38)) and is_equal_approx(view.pitch,deg_to_rad(24)) and is_equal_approx(view.camera_distance,view.half_extent*2.8),kind+" reset restores framed scene distance and default angles")
	var after := unchanged_state()
	if after != guard:
		for key in guard:
			if guard[key] != after.get(key): print("STATE_DIFF ",kind," ",key," before=",guard[key]," after=",after.get(key))
	check(after == guard,kind+" camera work preserves scientific and non-camera state")
	view._focus_activity()
	check(not view.custom_orbit,kind+" Frame Scene restores ordinary orbit")
	var framed: Vector3 = view.camera_target
	view._advance_orbit(.1)
	check(view.camera_target == framed,kind+" framed orbit unchanged")

func capture_tests() -> void:
	if DisplayServer.get_name() == "headless":return
	view.free_camera = true;view.orbit_enabled = false
	button(MOUSE_BUTTON_RIGHT,true);view.orbit_setup.set_radius(12)
	await snapshot_png("mixed-visible-preview")
	view._update_hud()
	view.orbit_setup.suppress_capture(true)
	for n in 3:await process_frame
	await RenderingServer.frame_post_draw
	var expected := root.get_texture().get_image()
	expected.convert(Image.FORMAT_RGBA8)
	expected.save_png(out.path_join("expected-clean.png"))
	view.orbit_setup.suppress_capture(false)
	check(await view._capture_inspection_png(out.path_join("clean-screenshot.png"),false) == OK,"normal screenshot succeeds during setup")
	var screenshot := Image.load_from_file(out.path_join("clean-screenshot.png"))
	screenshot.convert(Image.FORMAT_RGBA8)
	# The capture busy lock intentionally disables transport controls. Compare
	# the entire simulation area (including the setup panel's former position).
	var scene_area := Rect2i(0,48,int(view.shell.dock.position.x),int(view.shell.transport.position.y)-48)
	check(screenshot.get_region(scene_area).get_data() == expected.get_region(scene_area).get_data(),"normal screenshot scene pixels exclude temporary guide and panel")
	check(view.orbit_setup.active and view.orbit_setup.visible,"screenshot restores active preview")
	view.inspection_busy = true
	await process_frame;await process_frame
	check(not view.orbit_setup.visible,"direct durable capture busy lock hides preview")
	view.inspection_busy = false;await process_frame
	button(MOUSE_BUTTON_RIGHT,false)
	var state := Visual.snapshot(view)
	var offline = Viewer.new();offline.offline_instance = true;root.add_child(offline);offline.set_process(false)
	check(offline.orbit_setup == null,"offline/export viewer never constructs preview")
	Visual.apply(offline,state)
	check(offline.camera.transform.is_equal_approx(view.camera.transform) and offline.custom_orbit,"export consumes committed camera state")
	offline.queue_free();await process_frame
	view.environment.background_mode = Environment.BG_COLOR;view.environment.background_color = Color(.85,.85,.85)
	button(MOUSE_BUTTON_RIGHT,true)
	await snapshot_png("mixed-setup-bright")
	view.orbit_setup.cancel()
	# Exercise the direct scientific PNG/bundle entry as well as the ordinary
	# action. Its worker resolves real exact-ID membership from this fixture.
	var control = view.selection_controller
	control.bind_source()
	check(await wait_jobs(control),"durable source binding succeeds")
	control._request("define_selection",{"key":"orbit-check","object":"p","kind":"particle_ids","selector":{"ids":["7"]}})
	check(await wait_jobs(control),"durable exact-ID selection succeeds")
	check(await control.await_committed_overlay(),"durable selection overlay settled")
	button(MOUSE_BUTTON_RIGHT,true)
	view._update_hud();view.orbit_setup.suppress_capture(true)
	for n in 3: await process_frame
	await RenderingServer.frame_post_draw
	expected = root.get_texture().get_image();expected.convert(Image.FORMAT_RGBA8)
	view.orbit_setup.suppress_capture(false)
	check(await control.temporal.durable.capture_to(out.path_join("durable-clean.png")) == OK,"direct durable screenshot succeeds during setup")
	screenshot = Image.load_from_file(out.path_join("durable-clean.png"));screenshot.convert(Image.FORMAT_RGBA8)
	check(screenshot.get_region(scene_area).get_data() == expected.get_region(scene_area).get_data(),"direct durable screenshot scene pixels exclude preview")
	check(view.orbit_setup.active and view.orbit_setup.visible,"direct durable capture restores preview")
	check(await view._capture_inspection_png(out.path_join("nested-clean.png"),true) == OK,"ordinary action with scientific sidecar uses nested suppression")
	check(view.orbit_setup.active and view.orbit_setup.visible and view.orbit_setup.capture_depth == 0,"nested capture scopes fully restore preview")
	check(await view._capture_inspection_png(out.path_join("nested-clean.png"),true) == ERR_ALREADY_EXISTS and view.orbit_setup.capture_depth == 0,"rejected nested capture also restores preview")
	view.orbit_setup.cancel()

func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	create_timer(150).timeout.connect(func():push_error("Orbit setup timeout");quit(1))
	view = Viewer.new();root.add_child(view);view.set_process(false)
	await process_frame
	for kind in ["particles","volume","mesh","mixed"]:await interaction(kind)
	if DisplayServer.get_name() != "headless":
		for kind in ["particles","volume","mesh","mixed"]:await recovery_tests(kind)
		for kind in ["mesh-small-scale","mesh-large-scale"]:await recovery_tests(kind,false)
		view._open_capture(out.path_join("mixed.ssc"));view.playing = false;view.orbit_enabled = false
	scale_tests()
	await capture_tests()
	view.free_camera = true
	button(MOUSE_BUTTON_RIGHT,true);view.orbit_setup.set_radius(100)
	var prior: Vector3 = view.camera_target
	view.get_window().focus_exited.emit()
	check(not view.orbit_setup.active and view.camera_target == prior,"focus-loss cancellation does not commit pivot")
	button(MOUSE_BUTTON_RIGHT,true)
	view.playing = true
	button(MOUSE_BUTTON_RIGHT,false)
	check(view.playing,"commit preserves active playback")
	view.playing = false
	view.camera.position = view.camera_target
	view._align_custom_orbit();view._update_camera()
	check(view.camera.position.distance_to(view.camera_target) < .00011,"orbit resume at pivot avoids old-radius jump")
	for radius in [.0001,.001,1.,100000.,1e8]:
		reset();view.camera_target = Vector3.ZERO;view.camera_distance = 5;view._update_camera()
		var pose: Transform3D = view.camera.transform
		button(MOUSE_BUTTON_RIGHT,true);view.orbit_setup.set_radius(radius);button(MOUSE_BUTTON_RIGHT,false)
		check(close(view.camera.position,view.camera_target+pose.basis.z*radius,maxf(.001,radius*.000001)),"commit matches preview landing at radius "+str(radius))
		check(view.camera.near > 0 and view.camera.far > view.camera.near and view.camera.far/view.camera.near <= 100000,"representable custom clip ratio at radius "+str(radius))
		if DisplayServer.get_name() != "headless":
			await process_frame;await RenderingServer.frame_post_draw
			var projection: Projection = view.camera.get_camera_projection()
			var finite := true
			for column in 4:
				for row in 4: finite = finite and is_finite(projection[column][row])
			check(finite,"native tiny/large custom projection "+str(radius))
	reset()
	check(is_equal_approx(view.camera.near,.05) and view.camera.far >= 1000,"reset restores normal scene clipping after custom scale")
	if DisplayServer.get_name() != "headless":
		view.shell.enter_immersive();await process_frame;await process_frame
		check(view.shell.immersive,"enter accepted Fullscreen for reset regression")
		button(MOUSE_BUTTON_RIGHT,true)
		check(view.orbit_setup.active,"setup works in Fullscreen")
		var mode := DisplayServer.window_get_mode()
		reset()
		check(view.shell.immersive and DisplayServer.window_get_mode() == mode and not view.orbit_setup.active,"R cancels/resets while preserving Fullscreen")
		button(MOUSE_BUTTON_RIGHT,true)
		var escape := InputEventKey.new();escape.keycode = KEY_ESCAPE;escape.pressed = true;view._input(escape)
		check(not view.shell.immersive,"Esc retains accepted fullscreen recovery during setup")
		view.orbit_setup.cancel()
	var report := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"rendered_recovery":rendered},"\t"));report.close()
	view.queue_free();await process_frame;await process_frame
	print("ORBIT_SETUP: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
