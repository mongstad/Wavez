extends SceneTree
# The identical script runs in the consolidated G3 archive and current viewer.
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")
class ObservedViewer extends "res://main.gd":
	var measuring := false
	var callbacks: Array = []
	func _process(delta: float) -> void:
		if not measuring:super(delta);return
		var begin := Time.get_ticks_usec();var before: String = scene_layers.particle_key
		super(delta)
		callbacks.append({"duration_ms":(Time.get_ticks_usec()-begin)/1000.0,"delta_ms":delta*1000,"transition":before != scene_layers.particle_key,"time":requested_time,"buffering":scene_layers.playback.buffering})
var job := {}
func _initialize() -> void:run.call_deferred()
func rss(pid: int) -> int:
	var file := FileAccess.open("/proc/%d/status" % pid,FileAccess.READ)
	if file == null:return 0
	for line in file.get_buffer(65536).get_string_from_utf8().split("\n"):
		if line.begins_with("VmRSS:"):return int(line.substr(6).strip_edges().split(" ",false)[0])*1024
	return 0
func wait_jobs(control) -> bool:
	var began := Time.get_ticks_msec()
	while control.jobs.busy() and Time.get_ticks_msec()-began < 30000:await create_timer(.01).timeout
	return not control.jobs.busy() and control.jobs.error.is_empty()
func fail(message: String) -> void:push_error(message);quit(1)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--g4-profile="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--g4-profile=")))
	if job.is_empty() or DisplayServer.get_name() == "headless":fail("Actual renderer/profile job required");return
	create_timer(150).timeout.connect(func():fail("G4 profile timed out"))
	var output := {"backend":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"cases":[]}
	for config in job.cases:
		var view := ObservedViewer.new();view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false;root.add_child(view);view.set_process(false)
		view._set_clean(true);view.particle_layer_visible = config.get("visible",true)
		for id in view.scene_layers.states:
			view.scene_layers.states[id].visible = config.get("fields",false)
			if view.scene_layers.states[id].has("isosurface"):view.scene_layers.states[id].isosurface = false
		for id in view.guide_visibility:view.guide_visibility[id] = false
		view.scene_layers.cancel_iso();view._apply_geometry();view.time_mode = "physical";view.physical_rate = 1
		var control = null;var ready_ms := 0.0;var worker_reply := {};var request := {};var source := {};var export_reply := {};var warm_ready_ms := 0.0
		if config.get("analysis",false) or config.get("stored",false) or config.get("overlay",false) or config.get("export",false):
			control = view.get("selection_controller");var started := Time.get_ticks_usec();control.bind_source()
			if not await wait_jobs(control):fail(control.status.text);return
			var definition: Dictionary = config.get("definition",{"key":"population","object":"p","kind":"roi","selector":{"shape":"box","lower":[-20,-20,-20],"upper":[20,20,20]}})
			control._request("define_selection",definition)
			if not await wait_jobs(control):fail(control.status.text);return
			ready_ms = (Time.get_ticks_usec()-started)/1000.0;control.state.overlay.visible = config.get("overlay",false)
			request = {"selections":control.state.definitions.duplicate(true),"mode":config.get("mode","statistics"),"channels":[{"channel":"value"}],"range":{"axis":"native_time","start":0,"end":job.get("end",40)},"result_bytes":16777216}
			if request.mode == "statistics":request.metrics = ["count","mean","stddev","min","max"]
			source = control.source.duplicate(true)
			control.jobs.background_completed.connect(func(value):
				if value.get("data",{}).has("row_count"):worker_reply.merge(value,true)
				if value.get("data",{}).has("export"):export_reply.merge(value,true))
			started = Time.get_ticks_usec();control._request("resolve_selections",{"selections":control.state.definitions,"time":job.get("start",16)})
			if not await wait_jobs(control):fail(control.status.text);return
			warm_ready_ms = (Time.get_ticks_usec()-started)/1000.0
			if config.get("export",false):
				control.temporal.submit("analyze",request,source,"Prepared export input")
				if not await wait_jobs(control) or not worker_reply.get("ok",false):fail("Export input preparation failed");return
		var playback = view.scene_layers.playback;playback.direction = 1
		if not config.get("cold",false):playback.begin(job.get("start",16.),playback.window_pairs)
		var began := Time.get_ticks_msec()
		while playback.buffering and Time.get_ticks_msec()-began < 30000:playback.pump();await process_frame
		if playback.buffering:fail("Prebuffer did not complete");return
		for i in range(12):await process_frame
		Profile.enabled = true;Profile.reset();Profile.trace_enabled = true
		view.callbacks.clear();var memory_start := rss(OS.get_process_id());var peak_rss := memory_start;var worker_peak := 0
		var enqueue_ms := 0.0;var wall_start := Time.get_ticks_usec()
		if config.get("analysis",false):
			var enqueue_start := Time.get_ticks_usec();control.temporal.submit("analyze",request,source,"100k native statistics");enqueue_ms = (Time.get_ticks_usec()-enqueue_start)/1000.0
		elif config.get("export",false):
			var enqueue_start := Time.get_ticks_usec();control.temporal._launch("export_analysis",{"result":worker_reply.data.result,"destination":job.output.get_base_dir().path_join(config.name+"-csv"),"quota_bytes":16777216},source);enqueue_ms = (Time.get_ticks_usec()-enqueue_start)/1000.0
		view.measuring = true;view.playing = config.get("playing",true);view.set_process(true)
		var seek_calls: Array = [];var seek_cursor := 0;var seeks: Array = config.get("seeks",[])
		while Time.get_ticks_usec()-wall_start < int(config.get("seconds",4)*1000000):
			await create_timer(.1,true,false,true).timeout
			if not seeks.is_empty():
				var seek_start := Time.get_ticks_usec();view._seek_time(seeks[seek_cursor%seeks.size()]);seek_cursor += 1;view.playing = true
				seek_calls.append((Time.get_ticks_usec()-seek_start)/1000.0)
			peak_rss = maxi(peak_rss,rss(OS.get_process_id()))
			if control != null and control.jobs.worker_pid > 0:worker_peak = maxi(worker_peak,rss(control.jobs.worker_pid))
		view.measuring = false;view.set_process(false);view.playing = false
		var report := Profile.report();Profile.enabled = false
		report.config = config;report.callbacks = view.callbacks;report.ready_ms = ready_ms;report.warm_ready_ms = warm_ready_ms;report.enqueue_ms = enqueue_ms;report.seek_calls_ms = seek_calls
		report.viewer_rss_start = memory_start;report.viewer_rss_peak = peak_rss;report.worker_rss_peak = worker_peak;report.memory_static = OS.get_static_memory_usage();report.playback = playback.profile_report()
		report.gpu_buffers = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED);report.gpu_textures = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		if control != null:
			report.overlay_gpu_bytes = control.overlay.gpu_bytes
			if config.get("analysis",false):
				if not await wait_jobs(control):fail(control.temporal.status.text);return
				if not worker_reply.get("ok",false):fail("Full 100k analysis failed: "+control.temporal.status.text);return
				report.analysis = worker_reply
			if config.get("export",false):
				if not await wait_jobs(control) or not export_reply.get("ok",false):fail("Full CSV export failed");return
				report.analysis = export_reply
			var pid: int = control.jobs.worker_pid;var close_start := Time.get_ticks_usec();view.free()
			report.close_ms = (Time.get_ticks_usec()-close_start)/1000.0
			await create_timer(.1).timeout;report.worker_alive_after_close = DirAccess.dir_exists_absolute("/proc/%d" % pid)
		else:view.free()
		output.cases.append(report);Job.write_json(job.output,output)
		print("G4 PROFILE ",config.name," callbacks=",report.callbacks.size()," RSS=",peak_rss)
	quit()
