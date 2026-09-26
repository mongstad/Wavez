extends "res://layers/test_scene_playback.gd"
const Policy = preload("res://layers/playback_memory.gd")
var telemetry: Array = []
var started := 0
func observe(control) -> void:
	var status: Dictionary = control.worker.status()
	var row := {"seconds":(Time.get_ticks_msec()-started)/1000.0,"memory":Policy.snapshot(),"bytes":status.bytes,"limit":status.limit,"frames":status.frames,"completed":status.completed,"state":status.session,"window_start":control.automatic_anchor,"window_end":control.automatic_end}
	telemetry.append(row);print("CACHE ",JSON.stringify(row))
func fill(view, time: float, seconds := 600) -> bool:
	var control = view.scene_layers.field_playback
	control.worker.trace_reads = true
	var began := Time.get_ticks_msec();var observed := -10000;var stable := 0;var count := -1
	while Time.get_ticks_msec()-began < seconds*1000:
		view.scene_layers.sample(time,true);view.scene_layers.tick(0)
		if Time.get_ticks_msec()-observed > 2000:
			observe(control);observed = Time.get_ticks_msec()
			var status: Dictionary = control.worker.status()
			if status.session.get("state") == "ready" and status.completed == count:stable += 1
			else:stable = 0
			count = status.completed
			if stable >= 2:return true
			if not control.error.is_empty() or not view.scene_layers.error.is_empty():return false
		await process_frame
	return false
func run() -> void:
	var args := OS.get_cmdline_user_args();var source := args[0];var output := args[1]
	started = Time.get_ticks_msec()
	var report := {"before":Policy.snapshot(),"renderer":RenderingServer.get_current_rendering_method()}
	var view = make_view(source,true)
	var control = view.scene_layers.field_playback
	if args.size() > 2:control.cache_cap_bytes = int(args[2])*Policy.MIB
	check(not view.committed_sample.is_empty(),"Real capture opens")
	report.open_seconds = (Time.get_ticks_msec()-started)/1000.0
	report.records = view.generic_reader.records.size()
	report.ready = await fill(view,0)
	check(report.ready,"Real capture fills automatic window")
	report.filled_seconds = (Time.get_ticks_msec()-started)/1000.0
	report.filled = control.profile_report()
	var before: Dictionary = control.worker.status()
	var trace_before: int = control.worker.read_trace().size()
	var time: float = view.generic_reader.samples.field[10].time
	var began := Time.get_ticks_msec()
	check(view.scene_layers.seek(time) and await sample(view,time,true),"Overlapping real-capture scrub commits")
	report.overlap_target_ms = Time.get_ticks_msec()-began
	check(await fill(view,time),"Overlapping real-capture window fills")
	var missing := 0
	for job in control.automatic_jobs:
		if not before.charges.has(job.key):missing += 1
	var reread := 0
	for key in control.worker.read_trace().slice(trace_before):
		if before.charges.has(key):reread += 1
	report.overlap = {"missing_in_final_window":missing,"new_reads":control.worker.status().pipeline_stages.stored_hash.count-before.pipeline_stages.stored_hash.count,"cached_samples_reread":reread,"before_frames":before.frames,"after_frames":control.worker.status().frames}
	check(reread == 0,"Overlapping real-capture window reads only missing samples")
	# Use actual elapsed time: uncapped renderer callbacks are not a 60 Hz clock.
	view.playing = true;view.physical_rate = 4;var buffered := 0;var callbacks: Array = []
	var field_waits := 0;var particle_waits := 0
	var play_start: float = view.requested_time
	var play_wall := Time.get_ticks_usec();var previous := play_wall
	while Time.get_ticks_usec()-play_wall < 4000000:
		await process_frame
		var tick_start := Time.get_ticks_usec();view.scene_layers.tick((tick_start-previous)/1000000.0);previous = tick_start
		callbacks.append((Time.get_ticks_usec()-tick_start)/1000.0)
		if view.scene_layers.is_buffering():buffered += 1
		if control.buffering:field_waits += 1
		if view.scene_layers.playback.buffering:particle_waits += 1
	view.playing = false
	report.playback = {"speed":4,"callbacks":callbacks,"buffered_callbacks":buffered,"field_waits":field_waits,"particle_waits":particle_waits,"wall_seconds":(Time.get_ticks_usec()-play_wall)/1000000.0,"committed_seconds":view.requested_time-play_start}
	var field = view.scene_layers.views.field
	report.scientific = {"time":field.data.time,"source_index":field.data.source_index,"lod":field.lod,"hashes":{}}
	for channel in field.data.channels:report.scientific.hashes[channel] = Hash.digest(field.data.channels[channel].to_byte_array())
	check(field.lod == 1 and field.data.channels.size() == 3,"Real capture retains full grid and all channels")
	# A distant request must become usable without an interval control.
	began = Time.get_ticks_msec()
	check(view.scene_layers.seek(120) and await sample(view,120,true),"Distant real-capture scrub commits automatically")
	report.distant_target_ms = Time.get_ticks_msec()-began
	report.final = control.profile_report();report.final_memory = Policy.snapshot()
	report.telemetry = telemetry;report.checks = checks;report.failures = failures
	Job.write_json(output,report)
	view.free();await process_frame
	print("REAL ADAPTIVE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
