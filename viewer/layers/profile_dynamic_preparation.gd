extends "res://layers/test_field_session.gd"
const Policy = preload("res://layers/playback_memory.gd")
func run() -> void:
	var args := OS.get_cmdline_user_args();var source := args[0];var output := args[1]
	var speed := float(args[2]);var duration := float(args[3])
	var started := Time.get_ticks_usec();var view = make_view(source,true)
	var control = view.scene_layers.field_playback
	view.physical_rate = speed;view.scene_loop_playback = false;view.playing = true;control.begin_session()
	var report := {"mode":OS.get_environment("SIMSCOPE_FIELD_WORKERS"),"speed":speed,"open_seconds":(Time.get_ticks_usec()-started)/1000000.0,"timeline":[],"scientific":[],"callbacks":[],"draws":[],"playback_draws":[],"advancing_draws":[],"playback_callbacks":[],"field_presentations_ms":[],"cpu_runway_holds":0,"cpu_runway_seconds":0.0,"checks":0,"failures":[]}
	var ready_at := 0;var first_time: float = view.requested_time;var previous := Time.get_ticks_usec();var next_log := previous
	var field_waits := 0;var particle_waits := 0;var field_seconds := 0.0;var particle_seconds := 0.0
	var last_field := false;var last_particle := false;var seen := {};var oracles := {}
	var draw_time := [Time.get_ticks_usec()]
	var draw_state := {"started":false,"advancing":false}
	var last_cpu := false;var last_source := -1;var last_source_us := 0
	var on_draw := func():
		var now := Time.get_ticks_usec();var elapsed: float = (now-draw_time[0])/1000.0
		report.draws.append(elapsed);draw_time[0] = now
		if draw_state.started:report.playback_draws.append(elapsed)
		if draw_state.advancing:report.advancing_draws.append(elapsed)
	RenderingServer.frame_post_draw.connect(on_draw)
	while Time.get_ticks_usec()-started < 900000000:
		await process_frame
		var tick := Time.get_ticks_usec();var delta := (tick-previous)/1000000.0;previous = tick
		if ready_at > 0:
			if last_field:field_seconds += delta
			if last_particle:particle_seconds += delta
			if last_cpu:report.cpu_runway_seconds += delta
		view.scene_layers.tick(delta)
		report.callbacks.append((Time.get_ticks_usec()-tick)/1000.0)
		if ready_at == 0 and not control.session_waiting and not view.scene_layers.is_buffering():
			ready_at = tick;report.ready_seconds = (tick-started)/1000000.0;report.startup = control.startup_report.duplicate(true)
			report.initial_runway = control._demand(control.worker.status(),view.requested_time)
			report.initial_policy = control.concurrency.report()
			print("PHASE play")
		elif ready_at > 0:
			if control.buffering and not last_field:field_waits += 1
			if view.scene_layers.playback.buffering and not last_particle:particle_waits += 1
			if control.session_waiting and not last_cpu:report.cpu_runway_holds += 1
			report.playback_callbacks.append((Time.get_ticks_usec()-tick)/1000.0)
		last_field = control.buffering;last_particle = view.scene_layers.playback.buffering
		last_cpu = control.session_waiting
		draw_state.started = ready_at > 0;draw_state.advancing = ready_at > 0 and not view.scene_layers.is_buffering()
		var field = view.scene_layers.views.field
		if ready_at > 0 and field.data.source_index != last_source:
			if last_source_us > 0:report.field_presentations_ms.append((tick-last_source_us)/1000.0)
			last_source = field.data.source_index;last_source_us = tick
		seen[str(field.data.source_index)] = true
		if field.data.source_index in [0,100,800,1565] and not oracles.has(field.data.source_index):
			oracles[field.data.source_index] = field.data
		if tick >= next_log:
			var state: Dictionary = control.worker.status()
			report.timeline.append({"seconds":(tick-started)/1000000.0,"time":view.requested_time,"started":ready_at > 0,"policy":control.concurrency.report(),"demand":control._demand(state,view.requested_time),"cache_bytes":state.bytes,"limit":state.limit,"completed":state.completed,"evictions":state.evictions,"cancelled":state.cancelled,"active_jobs":state.active_jobs,"in_flight_bytes":state.in_flight_bytes,"pressure_events":state.pressure_events,"memory":Policy.snapshot(),"waiting":control.buffering,"cpu_waiting":control.session_waiting})
			print("PROGRESS ",view.requested_time," lanes=",state.active_limit," rate=",control.concurrency.rate," lead=",control.demand_report.get("ahead_seconds",0)," waits=",field_waits)
			next_log = tick+1000000
		if float(view.committed_sample.get("requested_time",-INF)) >= view.generic_reader.frames[-1].time:break
		if ready_at > 0 and duration > 0 and tick-ready_at >= duration*1000000:break
	view.playing = false;RenderingServer.frame_post_draw.disconnect(on_draw)
	report.wall_seconds = (Time.get_ticks_usec()-started)/1000000.0;report.committed_seconds = float(view.committed_sample.get("requested_time",first_time))-first_time
	report.complete = float(view.committed_sample.get("requested_time",-INF)) >= view.generic_reader.frames[-1].time
	# Let the final committed GPU bindings reach a draw before teardown.
	await process_frame
	report.field_waits = field_waits;report.particle_waits = particle_waits;report.field_wait_seconds = field_seconds;report.particle_wait_seconds = particle_seconds
	report.presented = seen.keys();report.final = control.profile_report()
	check(ready_at > 0,"Playback becomes ready")
	check(control.error.is_empty() and view.scene_layers.error.is_empty(),"No source/playback error")
	# Capacity refresh can shrink the ceiling while a batch is still draining.
	control.worker.cancel(true)
	var drain := Time.get_ticks_msec()
	while (control.worker.status().active or control.worker.status().bytes > control.worker.status().limit) and Time.get_ticks_msec()-drain < 5000:await process_frame
	report.drained = control.worker.status()
	check(not report.drained.active and report.drained.bytes <= report.drained.limit,"Bounded cache after admitted batch drains")
	for index in oracles:
		var data: Dictionary = oracles[index];var hashes := {}
		for name in data.channels:hashes[name] = Hash.digest(data.channels[name].to_byte_array())
		report.scientific.append({"index":index,"time":data.time,"hashes":hashes})
	check(view.scene_layers.views.field.lod == 1,"Full resolution")
	if duration == 0:check(report.complete,"Full recording played")
	view.free();await process_frame
	report.checks = checks;report.failures = failures;Job.write_json(output,report)
	print("DYNAMIC PROFILE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
