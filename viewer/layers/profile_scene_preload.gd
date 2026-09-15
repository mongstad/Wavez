extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")
const Buffer = preload("res://layers/playback_buffer.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preload-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--preload-job=")))
	if job.is_empty():quit(1);return
	var view = load("res://main.gd").new();view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false);view._set_clean(true)
	for id in view.scene_layers.states:view.scene_layers.states[id].visible = false
	var controller = view.scene_layers.playback
	Profile.enabled = true;Profile.reset()
	var before := Buffer.memory_headroom();var started := Time.get_ticks_usec();var minimum_ready_us := 0
	controller.set_policy("full")
	var expected: int = view.generic_reader.samples[view.scene_layers.particle_id].size()
	while Time.get_ticks_usec()-started<120000000:
		controller.pump()
		if not controller.buffering and minimum_ready_us==0:minimum_ready_us = Time.get_ticks_usec()
		var status: Dictionary = controller.worker.status()
		if not status.error.is_empty():push_error(status.error);break
		if status.prepared_pairs == expected:break
		await process_frame
	var stopped := Time.get_ticks_usec()
	var report: Dictionary = controller.profile_report()
	var memory := FileAccess.open("/proc/self/status",FileAccess.READ).get_buffer(65536).get_string_from_utf8()
	var rss := 0
	for line in memory.split("\n"):
		if line.begins_with("VmRSS:"):rss = int(line.substr(6).strip_edges().split(" ",false)[0])*1024
	report.capture = job.capture;report.expected_pairs = expected;report.elapsed_seconds = (stopped-started)/1e6
	report.minimum_ready_seconds = (minimum_ready_us-started)/1e6;report.rss_bytes = rss
	report.memory_static = OS.get_static_memory_usage();report.memory_static_peak = OS.get_static_memory_peak_usage()
	report.memory_before = before;report.memory_after = Buffer.memory_headroom()
	report.particle_gpu_buffer_bytes = view.current_mm.buffer.size()*4
	report.pass = report.cache.prepared_pairs == expected and report.cache.prepared_bytes <= report.prepared_limit and report.cache.decoded_bytes <= report.decoded_limit and report.full_preload
	Job.write_json(job.output,report)
	print("FULL PRELOAD ",report.pass," pairs=",report.cache.prepared_pairs," seconds=",report.elapsed_seconds," RSS=",rss)
	Profile.enabled = false;view.free();quit(0 if report.pass else 1)
