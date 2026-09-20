extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")
class ObservedViewer extends "res://main.gd":
	var measuring := false
	var callbacks: Array = []
	func _process(delta: float) -> void:
		if not measuring:super(delta);return
		var start := Time.get_ticks_usec();var before: String = scene_layers.particle_key
		var source_before := requested_time
		super(delta)
		var end := Time.get_ticks_usec()
		var controller = scene_layers.get("playback")
		callbacks.append({"start_us":start,"end_us":end,"duration_ms":(end-start)/1000.0,"delta":delta,"pair_before":before,"pair_after":scene_layers.particle_key,"time_before":source_before,"time_after":requested_time,"buffering":controller.buffering if controller != null else false,"buffer_depth":controller._depth(controller.worker.status()) if controller != null and controller.enabled else 0})
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--playback-job=")))
	if job.is_empty() or DisplayServer.get_name()=="headless":push_error("Real renderer and playback job required");quit(1);return
	create_timer(150,true,false,true).timeout.connect(func():push_error("Playback benchmark timeout");quit(1))
	var output := {"capture":job.capture,"main_thread_id":OS.get_thread_caller_id(),"backend":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"cases":[]}
	var view
	for config in job.cases:
		if not config.get("reuse",false):
			if view != null:view.free()
			view = ObservedViewer.new();view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false
			view.set("scene_prebuffer_enabled",job.optimized);view.set("scene_hidden_fast_path",job.optimized)
			root.add_child(view);view.set_process(false)
			view._set_clean(true);view.particle_layer_visible = config.get("visible",true)
			for id in view.scene_layers.states:
				view.scene_layers.states[id].visible = false
				if view.scene_layers.states[id].has("isosurface"):view.scene_layers.states[id].isosurface = false
			for id in view.guide_visibility:view.guide_visibility[id] = false
			view.scene_layers.cancel_iso();view._apply_geometry()
		view.playing = false;view.physical_rate = config.get("rate",1.0)
		view.set("scene_loop_playback",config.get("loop",false))
		var controller = view.scene_layers.get("playback")
		var target: float = config.get("start",16.0)
		var ready_before := false
		if controller != null and controller.enabled:
			ready_before = not controller.worker.get_pair(int(target*2),false).is_empty()
		if config.get("prebuffer",false) and controller != null and controller.enabled:
			controller.direction = 1;controller.begin(target,controller.window_pairs)
			var start := Time.get_ticks_msec()
			while controller.buffering and Time.get_ticks_msec()-start<30000:
				controller.pump();await process_frame
			if controller.buffering:push_error("Prebuffer failed: "+controller.last_ui);view.free();quit(1);return
		elif not config.get("cold",false):
			view.scene_layers.sample(target)
		for i in range(8):await process_frame
		Profile.enabled = true;Profile.reset();Profile.trace_enabled = true;view.callbacks.clear()
		if controller != null:controller.worker_events.clear();controller.worker.trace_enabled = true
		var cache_before: Dictionary = controller.worker.status() if controller != null else {}
		var started := Time.get_ticks_usec();view.measuring = true
		var request_ms := 0.0
		if config.get("cold",false) and controller != null:
			var request_start := Time.get_ticks_usec()
			controller.direction = 1
			if config.name == "uncached_seek":view._seek_time(target)
			else:controller.begin(target,4)
			request_ms = (Time.get_ticks_usec()-request_start)/1000.0
		view.display_accum = 0;view.tail_poll = 0;view.playing = true;view.set_process(true)
		await create_timer(config.get("seconds",4.0),true,false,true).timeout
		view.measuring = false;view.set_process(false);view.playing = false
		var stopped := Time.get_ticks_usec()
		var report := Profile.report();Profile.enabled = false
		report.config = config;report.start_us = started;report.end_us = stopped;report.request_ms = request_ms
		report.cache_before = cache_before
		report.ready_before = ready_before;report.callbacks = view.callbacks.duplicate(true)
		report.playback = controller.profile_report() if controller != null else {}
		report.gpu_buffer_bytes = view.current_mm.buffer.size()*4
		for mm in view.trail_mms:report.gpu_buffer_bytes += mm.buffer.size()*4
		var proc := FileAccess.open("/proc/self/status",FileAccess.READ)
		var memory_text := proc.get_buffer(65536).get_string_from_utf8() if proc != null else ""
		report.rss_bytes = 0
		for line in memory_text.split("\n"):
			if line.begins_with("VmRSS:"):report.rss_bytes = int(line.substr(6).strip_edges().split(" ",false)[0])*1024
		report.gpu_reported_buffer_bytes = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
		report.gpu_reported_texture_bytes = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		report.memory_static = OS.get_static_memory_usage();report.memory_static_peak = OS.get_static_memory_peak_usage()
		output.cases.append(report);Job.write_json(job.output,output)
		print("PLAYBACK PROFILE ",config.name," ",report.stages.get("process_inclusive",{})," time=",view.requested_time)
	if view != null:view.free()
	quit()
