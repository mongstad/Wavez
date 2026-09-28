extends "res://layers/test_rolling_cache.gd"
var telemetry: Array = []
var started := 0
var last_observed := -10000
func observe(view, label: String, force := false) -> void:
	if not force and Time.get_ticks_msec()-last_observed < 2000:return
	last_observed = Time.get_ticks_msec()
	var control = view.scene_layers.field_playback
	var status: Dictionary = control.worker.status()
	var time: float = view.committed_sample.get("requested_time",view.requested_time)
	var direction := -1 if view.physical_rate < 0 else 1
	var times: Array = []
	for row in view.generic_reader.samples.field:
		var key: String = control.Grid.sample_key(view.generic_reader.objects.field,row.sequence,view.scene_layers.states.field.channel,view.scene_layers.field_budget())
		if status.charges.has(key):times.append(float(row.time))
	view.timeline.refresh(view,true)
	var row := {"phase":label,"seconds":(Time.get_ticks_msec()-started)/1000.0,"time":time,"direction":direction,"memory":Policy.snapshot(),"cache_bytes":status.bytes,"budget":status.limit,"frames":status.frames,"completed":status.completed,"evictions":status.evictions,"pressure_evictions":status.pressure_evictions,"cancelled":status.cancelled,"reuses":status.source_reuses,"hits":status.cache_hits,"in_flight_bytes":status.in_flight_bytes,"active_limit":status.active_limit,"range":[times.min(),times.max()] if not times.is_empty() else [],"ahead":control._demand(status,time),"history_source_seconds":maxf(0,(time-(float(times.min()) if direction > 0 else float(times.max())))*direction) if not times.is_empty() else 0,"coverage":view.timeline.coverage,"rates":status.rates,"state":status.session.get("state","")}
	telemetry.append(row);print("ROLLING ",JSON.stringify(row))
func fill_at(view, time: float) -> bool:
	var began := Time.get_ticks_msec();var stable := 0;var previous := -1
	while Time.get_ticks_msec()-began < 600000:
		view.scene_layers.sample(time,true);view.scene_layers.tick(0)
		observe(view,"fill")
		var status: Dictionary = view.scene_layers.field_playback.worker.status()
		if status.session.get("state") == "ready" and not status.active:
			if previous == status.completed:stable += 1
			else:stable = 0
			previous = status.completed
			if stable >= 20:return true
		else:stable = 0
		await process_frame
	return false
func traverse(view, destination: float) -> Dictionary:
	var control = view.scene_layers.field_playback
	var first: float = view.requested_time;var previous := Time.get_ticks_usec();var began := previous
	var last_progress := previous;var last_time := first;var holds := 0;var hold_seconds := 0.0;var was_held := false
	var before: Dictionary = control.worker.status()
	view.playing = true;control.begin_session()
	while absf(view.requested_time-destination) > .000001 and Time.get_ticks_usec()-began < 900000000:
		await process_frame
		var now := Time.get_ticks_usec();var delta := (now-previous)/1000000.0;previous = now
		view.scene_layers.tick(delta)
		var held: bool = view.scene_layers.transport_stalled()
		if held:hold_seconds += delta
		if held and not was_held:holds += 1
		was_held = held
		if view.requested_time != last_time:last_progress = now;last_time = view.requested_time
		observe(view,"forward" if view.physical_rate > 0 else "reverse")
		if now-last_progress > 30000000:break
	view.playing = false;control.cancel_session()
	var after: Dictionary = control.worker.status(true)
	check(absf(view.requested_time-destination) <= .000001,"1x traversal reaches recording boundary")
	check(after.evictions > before.evictions,"Sequential playback automatically evicts and extends beyond initial window")
	check(control.error.is_empty() and view.scene_layers.error.is_empty(),"Traversal retains valid full-quality playback")
	return {"from":first,"to":view.requested_time,"wall_seconds":(Time.get_ticks_usec()-began)/1000000.0,"holds":holds,"hold_seconds":hold_seconds,"evictions":after.evictions-before.evictions,"pressure_evictions":after.pressure_evictions-before.pressure_evictions,"prepared":after.completed-before.completed,"eviction_events":after.eviction_events}
func run() -> void:
	var args := OS.get_cmdline_user_args();var source := args[0];var output := args[1]
	started = Time.get_ticks_msec()
	var view = make_view(source,true);var control = view.scene_layers.field_playback
	control.cache_cap_bytes = int(args[2])*Policy.MIB if args.size() > 2 else 0
	control.worker.trace_reads = true
	var report := {"before":Policy.snapshot(),"renderer":RenderingServer.get_current_rendering_method(),"cache_ceiling":control.cache_cap_bytes}
	check(await fill_at(view,0),"Production initial automatic window fills")
	observe(view,"initial",true)
	if DisplayServer.get_name() != "headless":
		for i in range(5):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.get_base_dir().path_join("prepared-timeline.png"))
	view.physical_rate = 1
	report.forward = await traverse(view,float(view.generic_reader.frames[-1].time))
	view.physical_rate = -1
	check(await fill_at(view,view.requested_time),"Reverse automatic window fills")
	report.reverse = await traverse(view,0)
	# A retained source sample is available without a repeated read/decode.
	var retained: Dictionary = control.worker.status();var target := -1.0
	for i in range(1,view.generic_reader.samples.field.size()):
		var job: Dictionary = control._job("field",i,view.scene_layers.field_budget())
		if retained.charges.has(job.key):target = float(job.entry.time);break
	if target >= 0:
		var job: Dictionary = control._job("field",view.generic_reader.bracket("field",target).a,view.scene_layers.field_budget())
		var reads: int = control.worker.read_trace().count(job.key)
		check(view.scene_layers.seek(target) and await sample(view,target,true),"Seek into retained history reuses ready data")
		check(control.worker.read_trace().count(job.key) == reads,"Retained seek does not add another read")
	else:check(false,"Retained history is available after reverse playback")
	check(view.scene_layers.seek(80) and await sample(view,80,true),"Seek beyond retained history explicitly prepares")
	var before: Dictionary = control.worker.status();switch_channel(view,"psi_real")
	check(await sample(view,80,true),"Production channel replacement commits")
	check(control.worker.status().source_reuses > before.source_reuses,"Production channel switch reuses compatible source arrays")
	var field = view.scene_layers.views.field
	report.scientific = {"source_index":field.data.source_index,"lod":field.lod,"hashes":{}}
	for channel in field.data.channels:report.scientific.hashes[channel] = Hash.digest(field.data.channels[channel].to_byte_array())
	check(field.lod == 1 and field.data.channels.size() == 3,"Production full resolution and all channels retained")
	# Exercise real production payloads under a deliberately tighter per-worker
	# observation as well. This is controlled admission, not OS memory pressure.
	report.controlled_pressure_forward = await pressure_case(control,false)
	report.controlled_pressure_reverse = await pressure_case(control,true)
	observe(view,"final",true)
	report.final = control.profile_report();report.telemetry = telemetry;report.checks = checks;report.failures = failures
	Job.write_json(output,report);view.free();await process_frame
	print("PRODUCTION ROLLING: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
