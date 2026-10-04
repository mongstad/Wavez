extends SceneTree
const Memory = preload("res://layers/playback_memory.gd")
func _initialize() -> void:call_deferred("run")
func pick(value: Dictionary, keys: Array) -> Dictionary:
	var result := {}
	for key in keys:result[key] = value.get(key)
	return result
func snapshot(view) -> Dictionary:
	var layers = view.scene_layers;var p = layers.playback;var f = layers.field_playback
	var ps: Dictionary = p.worker.status();var fs: Dictionary = f.worker.status()
	var target: float = p.pending_time if p.pending_time != null else view.requested_time
	var point: Dictionary = layers.reader.bracket(layers.particle_id,target)
	return {"wall":Time.get_ticks_msec()/1000.0,"time":view.requested_time,"committed":view.committed_sample.get("requested_time"),"playing":view.playing,"reason":layers.transport_wait_reason,"error":layers.error,
		"particle":{"target":target,"index":point.get("a"),"last_target":p.last_target,"buffering":p.buffering,"budget_message":p.budget_message,"decoded_limit":p.decoded_limit,"prepared_limit":p.prepared_limit,"largest_estimate":p.estimates.get("largest_pair"),"admitted":p.context.get("admitted"),"state":ps},
		"field":{"buffering":f.buffering,"session_waiting":f.session_waiting,"capacity_wait":f.capacity_wait,"error":f.error,"demand":f._demand(fs,view.requested_time),"startup":f.startup_report,"concurrency":f.concurrency.report(),"budget":f.budget_report,"state":pick(fs,["bytes","resident_bytes","limit","frames","completed","cancelled","evictions","pressure_events","largest_job_charge","worker_count","active_limit","active_jobs","in_flight_bytes","session"])},"memory":Memory.snapshot()}
func run() -> void:
	var args := OS.get_cmdline_user_args();var report := FileAccess.open(args[1],FileAccess.WRITE)
	var started := Time.get_ticks_msec()
	var view = load("res://main.gd").new();view.capture_path = args[0];view.orbit_enabled = false
	root.add_child(view);view.set_process(false);view.set_process_input(false);view.set_process_unhandled_input(false)
	view.physical_rate = float(args[4]) if args.size()>4 else 1.0;view.scene_loop_playback = false
	var began_play := false;var last_time: float = view.requested_time;var last_progress := Time.get_ticks_msec();var settled_since := -1
	var previous := Time.get_ticks_usec();var next_log := 0
	var max_seconds := float(args[2]) if args.size()>2 else 150.0
	var prefill := float(args[3]) if args.size()>3 else 3.0
	while Time.get_ticks_msec()-started < max_seconds*1000:
		await process_frame
		var now := Time.get_ticks_usec();var delta := (now-previous)/1000000.0;previous = now
		view.scene_layers.tick(delta)
		if not began_play:
			var fs: Dictionary = view.scene_layers.field_playback.worker.status()
			var ps: Dictionary = view.scene_layers.playback.worker.status()
			var settled: bool = fs.session.get("state") == "ready" and fs.active_jobs == 0 and not ps.worker_active and ps.desired.all(func(i):return ps.ready_indices.has(i))
			if not settled:settled_since = -1
			elif settled_since < 0:settled_since = Time.get_ticks_msec()
			var start_now: bool = (settled_since >= 0 and Time.get_ticks_msec()-settled_since > 2000) if prefill < 0 else Time.get_ticks_msec()-started > prefill*1000
			if start_now:
				var ready := snapshot(view);ready.event = "cache_filled_before_play";report.store_line(JSON.stringify(ready));report.flush()
				view.play_button.pressed.emit();began_play = view.playing;last_progress = Time.get_ticks_msec()
		if view.requested_time > last_time+.000001:last_time = view.requested_time;last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() >= next_log:
			var row := snapshot(view);report.store_line(JSON.stringify(row));report.flush();next_log = Time.get_ticks_msec()+1000
			print("MIXED time=",row.time," reason=",row.reason," particleMiB=",(row.particle.decoded_limit+row.particle.prepared_limit)/1048576.0," ready=",row.particle.state.prepared_pairs," fieldAhead=",row.field.demand.get("ahead_seconds")," freeGiB=",row.memory.available_physical/1073741824.0)
		if began_play and (not view.playing or view.requested_time >= view.generic_reader.frames[-1].time):break
		if began_play and view.requested_time>1 and Time.get_ticks_msec()-last_progress>45000:break
	report.store_line(JSON.stringify(snapshot(view)));report.close()
	view.free();await process_frame;quit()
