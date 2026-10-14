extends SceneTree
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Job = preload("res://video/render_job.gd")
var viewer
var output := ""
var baseline := false
var checks := 0
var failures: Array = []
var controls: Array = []
var restored: Array = []
var timings: Array = []
var render_cases: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func settle(count := 4) -> void:
	for i in count: await process_frame
	await RenderingServer.frame_post_draw

func state() -> Dictionary:
	return {"preset":viewer.selected_preset,"enabled":viewer.environment.glow_enabled,
		"editable":viewer.glow_slider.editable,"intensity":viewer.environment.glow_intensity,
		"slider":viewer.glow_slider.value,"points":viewer.clean_view}

func hide_ui() -> void:
	viewer.tools_ui.close(false);viewer.shell.hide();viewer.overlay_panel.hide()
	viewer.legend.hide();viewer.colorbar.hide();viewer.show_legend = false
	viewer.guide_mesh.hide();viewer.resize_handle.hide()

func screen(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,name+" screenshot")

# Dispatch through the real Window GUI input/focus path, not the slider callback.
func input_probe(label: String, enabled: bool) -> void:
	viewer.shell.show();viewer.shell.layout();viewer.tools_ui.open("Global effects")
	await settle()
	var slider: HSlider = viewer.glow_slider
	var before := slider.value
	slider.grab_focus()
	var key := InputEventKey.new();key.keycode = KEY_RIGHT;key.pressed = true
	viewer.tools_ui.window.push_input(key);await settle(2)
	key.pressed = false;viewer.tools_ui.window.push_input(key);await settle(2)
	var keyboard := slider.value
	var at := slider.global_position+Vector2(slider.size.x*.2,slider.size.y*.5)
	var motion := InputEventMouseMotion.new();motion.position = at;motion.global_position = at
	viewer.tools_ui.window.push_input(motion)
	var mouse := InputEventMouseButton.new();mouse.position = at;mouse.global_position = at
	mouse.button_index = MOUSE_BUTTON_LEFT;mouse.pressed = true
	viewer.tools_ui.window.push_input(mouse);await settle(2)
	mouse.pressed = false;viewer.tools_ui.window.push_input(mouse);await settle(2)
	var after := slider.value
	check((keyboard > before) == enabled,label+" keyboard interaction")
	check((not is_equal_approx(after,keyboard)) == enabled,label+" mouse interaction")
	check(is_equal_approx(viewer.environment.glow_intensity,after),label+" shared environment callback")
	mouse.pressed = true;viewer.tools_ui.window.push_input(mouse)
	motion.position.x += slider.size.x*.4;motion.global_position = motion.position
	viewer.tools_ui.window.push_input(motion);await settle(2)
	mouse.position = motion.position;mouse.global_position = motion.position
	mouse.pressed = false;viewer.tools_ui.window.push_input(mouse);await settle(2)
	check((not is_equal_approx(slider.value,after)) == enabled,label+" mouse drag interaction")
	controls.append({"case":label,"before":before,"keyboard":keyboard,"mouse":after,"drag":slider.value,"state":state()})
	hide_ui()

func restoration(scene: String) -> void:
	viewer._apply_preset("Cinematic");viewer.glow_slider.value = .8
	var saved := Visual.snapshot(viewer)
	saved.environment.glow_enabled = false
	# Reproduce the reported label/control mismatch without assuming its provenance.
	Visual.apply(viewer,saved)
	check(not viewer.environment.glow_enabled and viewer.glow_slider.editable == not baseline,scene+" explicit off pixels retained")
	check(viewer.selected_preset == "Cinematic",scene+" VisualState off retains named preset")
	check(Visual.snapshot(viewer).environment == saved.environment,scene+" VisualState environment unchanged")
	check(viewer.camera.transform == Transform3D(Basis(Visual.vector(saved.camera_transform[0]),Visual.vector(saved.camera_transform[1]),Visual.vector(saved.camera_transform[2])),Visual.vector(saved.camera_transform[3])),scene+" VisualState camera unchanged")
	restored.append({"case":scene+" VisualState off","state":state()})
	await screen(scene+"-restored-off")
	viewer._apply_preset("Cinematic")
	check(viewer.glow_slider.editable and viewer.environment.glow_enabled,scene+" explicit Cinematic re-enables")
	var native := Inspection.snapshot(viewer)
	native.visual.environment.glow_enabled = false
	var path := output.path_join(scene+"-inspection.json")
	check(Job.write_json(path,native) == OK,scene+" write inspection recipe")
	viewer._load_scientific_inspection(path)
	check(viewer.selected_preset == "Cinematic",scene+" inspection recipe off retains named preset")
	check(not viewer.environment.glow_enabled and viewer.glow_slider.editable == not baseline,scene+" inspection preserves explicit off")
	# Portable presets retain their explicit name and independent environment.
	viewer._apply_preset("Scientific")
	var portable := Preset.snapshot(viewer)
	path = output.path_join(scene+"-scientific.json")
	check(Job.write_json(path,portable) == OK,scene+" write Scientific portable preset")
	viewer._apply_preset("Cinematic")
	check(viewer._load_inspection(path).is_empty(),scene+" load Scientific portable preset")
	check(viewer.selected_preset == ("Cinematic" if baseline else "Scientific"),scene+" portable off label reconciled")
	check(not viewer.environment.glow_enabled and viewer.glow_slider.editable == not baseline,scene+" portable Scientific remains no Bloom")
	restored.append({"case":scene+" portable off","state":state()})
	await screen(scene+"-portable-off")
	viewer._apply_preset("Cinematic")
	portable = Preset.snapshot(viewer)
	path = output.path_join(scene+"-cinematic.json")
	check(Job.write_json(path,portable) == OK,scene+" write Cinematic portable preset")
	viewer._apply_preset("Scientific")
	check(viewer._load_inspection(path).is_empty(),scene+" load Cinematic portable preset")
	check(viewer.selected_preset == ("Scientific" if baseline else "Cinematic"),scene+" portable on label reconciled")
	check(viewer.glow_slider.editable and viewer.environment.glow_enabled,scene+" portable on usable")
	await input_probe(scene+" portable on",true)
	# Partial settings must not reset the selected scientific mapping or environment.
	viewer._apply_preset("Temperature")
	var env: Dictionary = Visual.snapshot(viewer).environment
	check(Preset.apply(viewer,{"kind":Preset.KIND,"version":1,"settings":{"view":{"exposure":1.2}}}).error.is_empty(),scene+" partial preset")
	check(viewer.selected_preset == "Temperature" and Visual.snapshot(viewer).environment == env,scene+" partial leaves scientific environment/mapping")
	viewer._apply_preset("Cinematic");viewer._set_point_rendering(true)
	check(viewer.glow_slider.editable and viewer.selected_preset == "Cinematic",scene+" point representation independent of Bloom")
	viewer._set_point_rendering(false)

func measure(scene: String) -> void:
	await settle(12)
	var gpu: Array = [];var wall: Array = []
	for i in 30:
		var began := Time.get_ticks_usec()
		await process_frame;await RenderingServer.frame_post_draw
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		wall.append((Time.get_ticks_usec()-began)/1000.0)
	gpu.sort();wall.sort()
	timings.append({"scene":scene,"gpu_median_ms":gpu[15],"gpu_p95_ms":gpu[28],"wall_median_ms":wall[15],
		"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"cache_bytes":viewer.generic_reader.cache.used,
		"viewports":root.find_children("*","SubViewport",true,false).size()})

func run() -> void:
	var args := OS.get_cmdline_user_args();output = args[0];baseline = "baseline" in args
	create_timer(180).timeout.connect(func():push_error("Global Bloom test timed out");quit(1))
	OS.low_processor_usage_mode = false;Engine.max_fps = 0
	viewer = load("res://main.gd").new();root.add_child(viewer);viewer.set_process(false)
	viewer.playing = false;viewer.orbit_enabled = false
	viewer.shell.set_process(false);viewer.shell.transport.set_process(false);viewer.shell.status_ui.set_process(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	check(is_equal_approx(viewer.environment.glow_intensity,1.35 if baseline else .30),"fresh Bloom intensity default")
	check(viewer.glow_slider.get_parent() == viewer.tools_ui.form("Global effects"),"one Global effects Bloom control")
	check(viewer.visual_sliders.keys().filter(func(k):return k.contains("Bloom")).size() == 1,"no category Bloom controls")
	for scene in ["particles","fields","meshes","mixed"]:
		var before := state()
		viewer._open_capture(output.path_join(scene+".wvz"))
		check(viewer._shell_open_error.is_empty(),scene+" opens WVZ1")
		check(state() == before,scene+" capture switch preserves Bloom")
		viewer.camera.position = Vector3(0,0,12);viewer.camera.look_at(Vector3.ZERO)
		viewer.camera.fov = 45;viewer._adopt_camera_basis();viewer.camera_target = Vector3.ZERO
		hide_ui()
		for light in [false,true]:
			viewer.shell.appearance.select(light)
			var theme: String = "light" if light else "dark"
			for preset in ["Cinematic","Scientific","Cinematic"]:
				viewer._apply_preset(preset);viewer.glow_slider.value = 1.34
				check(viewer.glow_slider.editable == (preset == "Cinematic" or not baseline),scene+" "+theme+" "+preset+" availability")
				check(viewer.environment.glow_enabled == (preset == "Cinematic"),scene+" "+preset+" glow state")
				await input_probe(scene+" "+theme+" "+preset,preset == "Cinematic" or not baseline)
			viewer.glow_slider.value = 1.35
			viewer.shell.show();viewer.shell.layout();viewer.tools_ui.open("Global effects")
			await screen(scene+"-"+theme+"-control")
			if scene == "mixed":
				root.size = Vector2i(970,600);viewer.shell.layout()
				await screen(scene+"-"+theme+"-compact-control")
				root.size = Vector2i(1440,900);viewer.shell.layout()
			hide_ui()
		for preset in ["Cinematic","Scientific"]:
			viewer._apply_preset(preset)
			for intensity in [0.,1.35,2.]:
				viewer.glow_slider.value = intensity
				await screen(scene+"-"+preset+"-"+str(intensity))
			var regions := {}
			for kind in ["particles","fields","meshes"]:
				if scene != "mixed" and scene != kind:continue
				var position: Vector3 = Vector3(-3.1,0,0) if kind == "particles" else (Vector3(3.1,0,0) if kind == "meshes" else Vector3.ZERO)
				var center: Vector2 = viewer.camera.unproject_position(position)
				regions[kind] = [int(center.x)-110,int(center.y)-110,int(center.x)+110,int(center.y)+110]
			render_cases.append({"scene":scene,"preset":preset,"regions":regions})
			viewer.glow_slider.value = 1.35
			check(await viewer._capture_inspection_png(output.path_join(scene+"-"+preset+"-export.png"),false) == OK,scene+" "+preset+" native PNG export")
			if scene == "mixed":
				Job.write_json(output.path_join(preset+"-video-state.json"),Visual.snapshot(viewer))
		if not baseline:
			viewer._apply_preset("Scientific");viewer._set_bloom_enabled(false);viewer.glow_slider.value=2
			await screen(scene+"-Scientific-manual-off")
			viewer._set_bloom_enabled(true)
			await screen(scene+"-Scientific-manual-on")
			check(viewer.selected_preset=="Scientific" and viewer.clean_view,"Manual Bloom leaves Scientific representation and label intact")
			viewer._set_bloom_enabled(false)
		await restoration(scene)
		viewer._apply_preset("Cinematic");viewer.glow_slider.value = 1.35
		await measure(scene)
		viewer._apply_preset("Scientific")
	# Finish with Scientific and switch again: no particles required and no implicit enable.
	viewer._open_capture(output.path_join("fields.wvz"))
	check(viewer.selected_preset == "Scientific" and viewer.glow_slider.editable == not baseline and not viewer.environment.glow_enabled,"Scientific capture switch")
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"controls":controls,
		"restored":restored,"timings":timings,"render_cases":render_cases,"baseline":baseline,"renderer":RenderingServer.get_current_rendering_method(),
		"device":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y]})
	await settle();viewer.queue_free();await process_frame
	print("GLOBAL BLOOM: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
