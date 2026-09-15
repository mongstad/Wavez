extends "res://layers/test_scene_playback.gd"
func draw(viewport) -> Image:
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--field-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--field-job=")))
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(job.oracle))
	var vp := SubViewport.new();vp.size = Vector2i(512,384);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED;vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED;vp.use_taa = false;vp.use_debanding = false;root.add_child(vp)
	var view = load("res://main.gd").new();view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false
	vp.add_child(view);view.set_process(false);view._set_clean(true)
	view.overlay_panel.visible = false;view.show_panel_button.visible = false;view.resize_handle.visible = false
	view.legend.visible = false;view.colorbar.visible = false;view.environment.glow_enabled = false;view.environment.fog_enabled = false
	view.camera_target = Vector3(4,4,2.5);view.camera.position = Vector3(14,-11,11.5);view.camera.look_at(view.camera_target,Vector3.BACK)
	view.camera.near = .01;view.camera.far = 150;view.camera.fov = 45
	var state: Dictionary = view.scene_layers.states.field;state.lower = 0;state.upper = 1;state.opacity = 2;state.step = .05
	var field = view.scene_layers.views.field
	for frame in oracle.frames:
		var time: float = str(frame.time_float64_le).hex_decode().decode_double(0)
		check(await sample(view,time,true),"asynchronous field time "+str(frame.index))
		var key: String = field.key;var worker = view.scene_layers.field_playback.worker
		var began := Time.get_ticks_msec();var prepared: Dictionary = worker.get_frame(key)
		while prepared.is_empty() and Time.get_ticks_msec()-began<10000:
			await process_frame;prepared = worker.get_frame(key)
		check(not prepared.is_empty(),"CPU prepared frame is available")
		if prepared.is_empty():break
		check(Hash.digest(field.data.channels[oracle.scalar].to_byte_array())==frame.value_sha256,"exact float64 scientific source bytes")
		check(field.data.channels[oracle.scalar] is PackedFloat64Array,"source dtype remains float64")
		var raw := PackedByteArray()
		for plane in prepared.planes:raw.append_array(plane.get_data())
		check(Hash.digest(raw)==frame.float32_sha256,"GPU preparation matches NumPy float32 oracle")
		check(field.data.time==time and view.committed_sample.requested_time==time,"native source timestamp committed exactly")
		check(field.lod==1 and field.data.geometry==oracle.geometry,"full grid geometry and LOD preserved")
		for probe in frame.probes:
			var expected: float = str(probe.float64_le).hex_decode().decode_double(0)
			check(field.probe(Vector3(probe.world[0],probe.world[1],probe.world[2]))==expected,"native probe matches retained scientific oracle")
	check(view.scene_layers.field_playback.worker.status().bytes<=view.scene_layers.field_playback.cpu_limit,"bounded prepared field cache")
	if DisplayServer.get_name()!="headless":
		check(await sample(view,2.0,true),"render asynchronous field")
		var asynchronous := await draw(vp)
		var committed: Dictionary = view.committed_sample.duplicate(true)
		# Release the texture so the reference must reconvert and upload synchronously.
		field.clear();check(not view.scene_layers.sample(2.0,false).is_empty(),"render synchronous reference")
		var synchronous := await draw(vp)
		check(asynchronous.get_data()==synchronous.get_data(),"asynchronous and synchronous volume pixels identical")
		check(committed==view.committed_sample,"render metadata identical")
		var backend := RenderingServer.get_current_rendering_method()
		asynchronous.save_png(job.output.get_base_dir().path_join("field-async-"+backend+".png"))
		synchronous.save_png(job.output.get_base_dir().path_join("field-sync-"+backend+".png"))
		var lit := 0
		for y in range(asynchronous.get_height()):
			for x in range(asynchronous.get_width()):
				var c := asynchronous.get_pixel(x,y)
				if maxf(c.r,maxf(c.g,c.b))>.08:lit += 1
		check(lit>100,"field render contains visible plume")
		# A slice uses the same staged RF texture and scientific source data.
		state.volume = false;state.slice = true;state.slice_distance = 2.625
		check(await sample(view,1.0,true),"asynchronous slice sample")
		asynchronous = await draw(vp)
		field.clear();view.scene_layers.sample(1.0,false);synchronous = await draw(vp)
		check(asynchronous.get_data()==synchronous.get_data(),"asynchronous and synchronous slice pixels identical")
		asynchronous.save_png(job.output.get_base_dir().path_join("field-slice-"+backend+".png"))
	Job.write_json(job.output,{"checks":checks,"failures":failures,"field":view.scene_layers.field_playback.profile_report()})
	view.free();vp.queue_free();await process_frame
	print("FIELD PREPARATION: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
