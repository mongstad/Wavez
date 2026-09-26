extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")
const Hash = preload("res://data/capture_index.gd")
const Grid = preload("res://layers/grid_view.gd")
func _initialize() -> void:run.call_deferred()
func memory() -> Dictionary:
	var result := {};var file := FileAccess.open("/proc/self/status",FileAccess.READ)
	if file != null:
		for line in file.get_buffer(65536).get_string_from_utf8().split("\n"):
			for key in ["VmRSS:","VmHWM:","VmSwap:"]:
				if line.begins_with(key):result[key.trim_suffix(":")] = int(line.split(" ",false)[1])*1024
	return result
func settle(view, time: float) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 30000:
		var result: Dictionary = view.scene_layers.sample(time,true)
		if result.is_empty():return false
		if not result.has("pending"):return true
		await process_frame
	return false
func run() -> void:
	var args := OS.get_cmdline_user_args();var path := args[0];var output := args[1]
	Profile.enabled = true;Profile.reset()
	var view = load("res://main.gd").new();view.capture_path = path;view.playing = false;view.orbit_enabled = false
	var began := Time.get_ticks_usec();root.add_child(view);view.set_process(false)
	var report := {"open_ms":(Time.get_ticks_usec()-began)/1000.0,"open_profile":Profile.report(),"open_memory":memory(),"renderer":RenderingServer.get_current_rendering_method()}
	if view.scene_layers == null:push_error("Capture failed to open");quit(1);return
	report.index_state = view.generic_reader.index_state
	report.records = view.generic_reader.records.size();report.objects = {}
	for id in view.generic_reader.objects:
		var entries: Array = view.generic_reader.samples[id]
		report.objects[id] = {"kind":view.generic_reader.objects[id].kind,"samples":entries.size(),"first_decoded_bytes":entries[0].decoded,"geometry":entries[0].descriptor.geometry}
	Job.write_json(output,report);print("OPEN_MS ",report.open_ms)
	await process_frame;await RenderingServer.frame_post_draw
	report.first_draw_ms = (Time.get_ticks_usec()-began)/1000.0
	# Dispatch an actual UI click after layout/draw and let the input loop handle it.
	var button: Rect2 = view.play_button.get_global_rect()
	var click := InputEventMouseButton.new();click.button_index = MOUSE_BUTTON_LEFT;click.position = button.get_center();click.pressed = true
	Input.parse_input_event(click)
	var release := click.duplicate();release.pressed = false;Input.parse_input_event(release)
	await process_frame
	report.controls_responsive = view.playing and not view.play_button.disabled
	report.controls_responsive_ms = (Time.get_ticks_usec()-began)/1000.0
	view.playing = false
	report.ready = report.controls_responsive and not view.committed_sample.is_empty()
	report.ready_ms = report.first_draw_ms
	report.background_progress = []
	Profile.reset()
	var prepare_start := Time.get_ticks_usec()
	for checkpoint in [0.0,250.0,1000.0,2000.0]:
		while (Time.get_ticks_usec()-prepare_start)/1000.0 < checkpoint:
			view.scene_layers.tick(0);await process_frame
		var state: Dictionary = view.scene_layers.playback.worker.status()
		var field: Dictionary = view.scene_layers.field_playback.worker.status()
		report.background_progress.append({"after_first_scene_ms":(Time.get_ticks_usec()-began)/1000.0-report.first_draw_ms,"particle_prepared_pairs":state.prepared_pairs,"particle_requested_pairs":state.desired.size(),"field_prepared_frames":field.frames,"interaction_blocked":view.scene_layers.is_buffering()})
	report.particle = view.scene_layers.playback.profile_report()
	report.background_profile = Profile.report()
	var initial := {}
	for id in view.scene_layers.views:
		var field = view.scene_layers.views[id]
		if not field is Grid:continue
		initial[id] = {"hashes":{},"statistics":field.color_stats,"lod":field.lod,"gpu_bytes":field.gpu_bytes}
		for channel in field.data.channels:initial[id].hashes[channel] = Hash.digest(field.data.channels[channel].to_byte_array())
	report.first_field = initial
	report.memory = memory()
	if "--exercise" in args:
		var checks := {};report.request_latencies = [];var last: float = view.generic_reader.frames[-1].time
		checks.initial = await settle(view,0.0)
		view.play_button.pressed.emit();checks.play = view.playing
		view._process(.2);view.play_button.pressed.emit();checks.pause = not view.playing
		var paused: float = view.requested_time;view._process(.2)
		checks.paused_clock = view.requested_time == paused
		for time in [.1,last*.5,last,0.0]:
			var requested := Time.get_ticks_usec()
			checks["seek_"+str(time)] = await settle(view,time)
			report.request_latencies.append({"time":time,"available_ms":(Time.get_ticks_usec()-requested)/1000.0})
			checks["clock_"+str(time)] = view.committed_sample.requested_time == time
		view.play_button.pressed.emit();checks.resume = view.playing
		view.play_button.pressed.emit()
		var field = view.scene_layers.field_playback
		checks.field_cpu_bound = field.worker.status().bytes <= field.cpu_limit
		checks.field_staging_bound = field.staged.size() <= 1
		var particle = view.scene_layers.playback
		checks.particle_bounds = particle.worker.status().decoded_bytes <= particle.decoded_limit and particle.worker.status().prepared_bytes <= particle.prepared_limit
		report.exercise = checks
		for ok in checks.values():
			if not ok:report.ready = false
	Job.write_json(output,report)
	view.free();await process_frame
	print("LOAD PROFILE COMPLETE ",report.ready_ms);quit(0 if report.ready else 1)
