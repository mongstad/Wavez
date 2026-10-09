extends SceneTree
## Issue #306: observation harness for the accepted renderer, not a new renderer.
const Visual = preload("res://scene/visual_state.gd")
const Preset = preload("res://scene/view_preset.gd")
const Job = preload("res://video/render_job.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var loads: Array = []
var controls: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func settle(frames := 5) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw

func state() -> Dictionary:
	return {"preset":viewer.selected_preset,"editable":viewer.glow_slider.editable,
		"intensity":viewer.environment.glow_intensity,"slider":viewer.glow_slider.value,
		"glow_enabled":viewer.environment.glow_enabled,"clean_view":viewer.clean_view}

func screen(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK, name+" image saved")

func region(point: Vector3) -> Array:
	var center: Vector2 = viewer.camera.unproject_position(point)
	return [int(center.x)-80,int(center.y)-95,int(center.x)+80,int(center.y)+95]

func measure() -> Dictionary:
	await settle(15)
	var gpu: Array = []; var cpu: Array = []; var wall: Array = []
	for i in 45:
		var began := Time.get_ticks_usec()
		await process_frame; await RenderingServer.frame_post_draw
		wall.append((Time.get_ticks_usec()-began)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	gpu.sort();cpu.sort();wall.sort()
	return {"frames":45,"gpu_ms_median":gpu[22],"gpu_ms_p95":gpu[42],
		"render_cpu_ms_median":cpu[22],"wall_ms_median":wall[22],
		"objects":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"draw_calls":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"engine_texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"engine_buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"decoded_cache_bytes":viewer.generic_reader.cache.used}

func hide_ui() -> void:
	viewer.tools_ui.close(false);viewer.shell.hide();viewer.overlay_panel.hide()
	viewer.legend.hide();viewer.colorbar.hide();viewer.show_legend = false
	viewer.guide_mesh.hide();viewer.resize_handle.hide()

func input_probe(scene: String, preset: String) -> void:
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
	check((keyboard > before) == (preset == "Cinematic"),scene+" "+preset+" keyboard availability")
	check((not is_equal_approx(after,keyboard)) == (preset == "Cinematic"),scene+" "+preset+" mouse availability")
	check(is_equal_approx(viewer.environment.glow_intensity,after),scene+" input callback reaches environment")
	controls.append({"scene":scene,"preset":preset,"before":before,"keyboard":keyboard,"mouse":after,"state":state()})
	hide_ui()

func run() -> void:
	if OS.get_cmdline_user_args().is_empty():quit(1);return
	output = OS.get_cmdline_user_args()[0]
	create_timer(210).timeout.connect(func():push_error("Bloom baseline timeout");quit(1))
	OS.low_processor_usage_mode = false;Engine.max_fps = 0
	viewer = load("res://main.gd").new();root.add_child(viewer);viewer.set_process(false)
	viewer.playing = false;viewer.orbit_enabled = false
	viewer.shell.set_process(false);viewer.shell.transport.set_process(false);viewer.shell.status_ui.set_process(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	for scene in ["particles","fields","meshes","mixed"]:
		var before := state()
		viewer._open_capture(output.path_join(scene+".wvz"))
		check(viewer._shell_open_error.is_empty(),scene+" WVZ1 opens")
		check(state() == before,scene+" load preserves preset and Bloom state")
		loads.append({"scene":scene,"before":before,"after":state(),"workspace":viewer.shell.workspace})
		# A shared camera frames three separated, stationary category landmarks.
		viewer.camera.position = Vector3(0,0,12);viewer.camera.look_at(Vector3.ZERO)
		viewer.camera.fov = 45;viewer._adopt_camera_basis();viewer.camera_target = Vector3.ZERO
		hide_ui()
		for preset in ["Cinematic","Scientific"]:
			viewer._apply_preset(preset)
			check(viewer.glow_slider.editable == (preset == "Cinematic"),scene+" "+preset+" slider state")
			check(viewer.environment.glow_enabled == (preset == "Cinematic"),scene+" "+preset+" effective glow")
			viewer.glow_slider.value = 1.35
			await input_probe(scene,preset)
			var name: String = scene+"-"+preset
			var readings := {}
			for setting in [{"label":"zero","value":0.0},{"label":"default","value":1.35},{"label":"high","value":2.0}]:
				# Programmatic diagnostic writes also exercise disabled Scientific state.
				viewer.glow_slider.set_value_no_signal(setting.value)
				viewer.environment.glow_intensity = setting.value
				await screen(name+"-"+setting.label)
				readings[setting.label] = state()
			var timing := await measure()
			cases.append({"name":name,"preset":preset,"scene":scene,"readings":readings,"timing":timing,
				"resolution":[root.size.x,root.size.y],
				"regions":{"particles":region(Vector3(-3.1,0,0)),"fields":region(Vector3.ZERO),"meshes":region(Vector3(3.1,0,0))}})
			# Actual snapshot/restore path may carry Scientific effects under a Cinematic label.
			var saved := Visual.snapshot(viewer)
			viewer._apply_preset("Scientific" if preset == "Cinematic" else "Cinematic")
			Visual.apply(viewer,saved)
			check(state() == readings.high,scene+" recipe restores effective state")
			viewer._apply_preset("Cinematic")
			check(is_equal_approx(viewer.environment.glow_intensity,2.),scene+" return to Cinematic retains intensity")
		# Category selection and theme changes must not disable the accepted control.
		viewer._apply_preset("Cinematic");viewer.glow_slider.value = 1.35
		for light in [false,true]:
			viewer.shell.appearance.select(light)
			root.size = Vector2i(1440,900)
			viewer.shell.show();viewer.shell.layout();viewer.tools_ui.open("Global effects")
			var theme: String = "light" if light else "dark"
			await screen(scene+"-"+theme+"-normal-control")
			check(viewer.glow_slider.editable,scene+" "+theme+" remains editable")
			if scene == "mixed":
				root.size = Vector2i(970,600);viewer.shell.layout()
				await screen(scene+"-"+theme+"-compact-control")
			root.size = Vector2i(970,640);viewer.shell.layout()
			hide_ui()
	# Explicitly demonstrate saved-state label/effect separation, not a load bug.
	var inconsistent := Visual.snapshot(viewer)
	inconsistent.preset = "Cinematic";inconsistent.environment.glow_enabled = false
	Visual.apply(viewer,inconsistent)
	var recipe_label_case := state()
	check(viewer.selected_preset == "Cinematic" and not viewer.glow_slider.editable,"Explicit restored environment can suppress Bloom under Cinematic label")
	viewer._apply_preset("Cinematic")
	check(viewer.glow_slider.editable,"Reapplying Cinematic enables Bloom")
	var portable := Preset.snapshot(viewer)
	check(portable.settings.environment.has("glow_intensity"),"Portable view preset contains global intensity")
	await settle()
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"cases":cases,"loads":loads,
		"controls":controls,"recipe_label_case":recipe_label_case,"renderer":RenderingServer.get_current_rendering_method(),
		"device":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"baseline_only":true})
	viewer.queue_free();await process_frame
	print("BLOOM BASELINE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
