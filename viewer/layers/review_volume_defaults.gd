extends SceneTree
const Job = preload("res://video/render_job.gd")
const Hash = preload("res://data/capture_index.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:failures.append(text);push_error(text)
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--review-job=")))
	if job.is_empty():quit(1);return
	var vp := SubViewport.new();vp.size = Vector2i(960,640);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var viewer = load("res://main.gd").new();viewer.offline_instance = true;viewer.capture_path = job.capture;vp.add_child(viewer);viewer.set_process(false)
	viewer.playing = false;viewer.orbit_enabled = false
	check(viewer.frame_a != null,"Real capture opened")
	var initial := Job.snapshot(viewer)
	# Hide inspector only for unobstructed comparisons; retain camera and scientific defaults.
	viewer.overlay_panel.hide();viewer.legend.hide();viewer.colorbar.hide()
	var defaults: Dictionary = viewer.scene_layers.states[job.field].duplicate(true)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(),true)
	var results: Array = []
	for item in job.cases:
		if item.name != "opening":
			viewer._apply_preset(item.preset);viewer.particle_layer_visible = item.particles
			viewer.scene_layers.states[job.field] = defaults.duplicate(true)
			viewer.scene_layers.states[job.field].channel = item.channel
			for key in item.changes:viewer.scene_layers.states[job.field][key] = item.changes[key]
		var began := Time.get_ticks_usec()
		check(not viewer.scene_layers.sample(item.time,false).is_empty(),item.name+" samples recorded time")
		var sample_ms := (Time.get_ticks_usec()-began)/1000.0
		var grid = viewer.scene_layers.views[job.field]
		check(Hash.digest(grid.data.channels[grid.channel].to_byte_array()) == item.oracle.sha256,item.name+" exact source array hash")
		var probe = grid.probe(Vector3(item.oracle.probe_world[0],item.oracle.probe_world[1],item.oracle.probe_world[2]))
		check(probe != null and absf(probe-item.oracle.probe_value) < 1e-7,item.name+" independent source-grid probe")
		check(grid.data.time == item.time and grid.lod == 1,item.name+" source timestamp and full grid LOD")
		for warmup in 8:await process_frame
		var gpu: Array = [];var cpu: Array = [];var elapsed: Array = []
		for frame in 30:
			began = Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
			elapsed.append((Time.get_ticks_usec()-began)/1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid()))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid()))
		gpu.sort();cpu.sort();elapsed.sort()
		var image := vp.get_texture().get_image()
		check(image.save_png(job.output.path_join(item.name+".png")) == OK,item.name+" screenshot")
		results.append({"name":item.name,"time":item.time,"state":viewer.scene_layers.states[job.field].duplicate(true),"particles":viewer.particle_layer_visible,"preset":viewer.selected_preset,"sample_ms":sample_ms,"gpu_ms_median":gpu[15],"gpu_ms_p95":gpu[28],"render_cpu_ms_median":cpu[15],"frame_wall_ms_median":elapsed[15],"probe":probe,"grid_lod":grid.lod})
	Job.write_json(job.output.path_join("render-report.json"),{"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"initial_state":initial,"cases":results})
	vp.queue_free();await process_frame;print("VOLUME REVIEW: ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
