extends SceneTree
const Job = preload("res://video/render_job.gd")
var view
var base: String
func _initialize() -> void:run.call_deferred()
func stats(values: Array) -> Dictionary:
	var a := values.duplicate();a.sort();var sum := 0.
	for v in a:sum += v
	return {"mean":sum/maxi(1,a.size()),"p50":a[a.size()/2],"p95":a[mini(a.size()-1,int(a.size()*.95))],"max":a[-1]}
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(1);return
	create_timer(150).timeout.connect(func():push_error("Profile watchdog expired");quit(1))
	base = ProjectSettings.globalize_path("res://../results/g3")
	var source := base.path_join("scene-demo.wvz")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):source = arg.trim_prefix("--capture=")
	view = load("res://main.gd").new();view.capture_path = source;view.playing = false;view.orbit_enabled = false
	var started := Time.get_ticks_usec();root.add_child(view);var open_ms := (Time.get_ticks_usec()-started)/1000.;view.set_process(false)
	view._set_clean(true);view.scene_layers.states.density.slice = true;view.scene_layers.states.density.slice_distance = -2
	view.guide_visibility.domain = true;view.guide_visibility.absorber = true;view._apply_geometry()
	view.scene_layers.sample(0);view.scene_layers.request_iso("density");started = Time.get_ticks_usec()
	if not await view.scene_layers.wait_for_surface():push_error(view.scene_layers.iso_error);quit(1);return
	var first_surface_ms := (Time.get_ticks_usec()-started)/1000.
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var sample_ms: Array = [];var gpu_ms: Array = [];var render_cpu: Array = [];var wall: Array = [];var waits: Array = []
	var previous := Time.get_ticks_usec()
	for i in range(121):
		var t := i/60.;started = Time.get_ticks_usec()
		view.scene_layers.sample(t);sample_ms.append((Time.get_ticks_usec()-started)/1000.)
		started = Time.get_ticks_usec()
		if not await view.scene_layers.wait_for_surface():push_error(view.scene_layers.iso_error);quit(1);return
		waits.append((Time.get_ticks_usec()-started)/1000.)
		await process_frame;await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec();wall.append((now-previous)/1000.);previous = now
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()));render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	var nvidia: Array = [];OS.execute("nvidia-smi",PackedStringArray(["--query-gpu=memory.used","--format=csv,noheader,nounits"]),nvidia)
	var proc: Array = [];OS.execute("/bin/cat",PackedStringArray(["/proc/%d/status" % OS.get_process_id()]),proc)
	var result := {"source":source,"resolution":[root.size.x,root.size.y],"backend":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"open_ms":open_ms,"first_surface_wait_ms":first_surface_ms,"sample_cpu_ms":stats(sample_ms),"gpu_ms":stats(gpu_ms),"render_cpu_ms":stats(render_cpu),"presented_wall_ms":stats(wall),"extraction_barrier_ms":stats(waits),"frames":wall.size(),"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"engine_static_bytes":OS.get_static_memory_usage(),"proc_status":"".join(proc),"device_total_memory_used_mib":nvidia,"layer_gpu_bytes":view.scene_layers.views.density.gpu_bytes+view.scene_layers.views.surface.gpu_bytes+view.scene_layers.iso_node.gpu_bytes,"decoded_cache_bytes":view.generic_reader.cache.used,"worker":view.scene_layers.iso_result}
	Job.write_json(base.path_join("profile-"+source.get_basename().get_file()+".json"),result);print("G3 PROFILE ",source.get_file()," ",result.sample_cpu_ms," gpu ",result.gpu_ms," wall ",result.presented_wall_ms)
	view.free();await process_frame;quit()
