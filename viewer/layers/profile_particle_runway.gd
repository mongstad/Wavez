extends SceneTree
## Read-only 1x replay. Run identical instrumentation against either viewer root.
const Memory = preload("res://layers/playback_memory.gd")
const Timeline = preload("res://ui/shell/prepared_timeline.gd")
const Profile = preload("res://scene/playback_profile.gd")
var holds: Array = []
var frames_ms: Array = []
var ticks_ms: Array = []
func _initialize() -> void:run.call_deferred()
func ahead(spans: Array, time: float) -> float:
	for span in spans:
		if span[0] <= time and time <= span[1]:return maxf(0,span[1]-time)
	return 0.
func snapshot(view) -> Dictionary:
	var layers = view.scene_layers;var p = layers.playback;var f = layers.field_playback
	var ps: Dictionary = p.worker.status();var fs: Dictionary = f.worker.status()
	view.timeline.refresh(view,true)
	var ready := {}
	for index in ps.ready_indices:ready[index] = true
	var samples: Array = layers.reader.samples.get(layers.particle_id,[])
	var spans := Timeline.spans(samples,ready,view.generic_reader.frames[0].time,view.generic_reader.frames[-1].time) if not samples.is_empty() else []
	return {"wall":Time.get_ticks_msec()/1000.,"time":view.requested_time,"committed":view.committed_sample.get("requested_time"),"playing":view.playing,"reason":layers.transport_wait_reason,"error":layers.error,"memory":Memory.snapshot(),
		"particle_ahead":ahead(spans,view.requested_time),"field_ahead":ahead(view.timeline.coverage.fields,view.requested_time),"scene_ahead":ahead(view.timeline.coverage.scene,view.requested_time),"coverage":view.timeline.coverage.duplicate(true),
		"particle":{"state":ps,"window":p.window_pairs,"decoded_limit":p.decoded_limit,"prepared_limit":p.prepared_limit,"largest_estimate":p.estimates.get("largest_pair"),"admitted":p.context.get("admitted"),"target":p.last_target},
		"field":{"budget":f.budget_report,"concurrency":f.concurrency.report(),"demand":f._demand(fs,view.requested_time),"state":{"bytes":fs.get("bytes"),"resident_bytes":fs.get("resident_bytes"),"limit":fs.get("limit"),"completed":fs.get("completed"),"evictions":fs.get("evictions"),"active_jobs":fs.get("active_jobs"),"session":fs.get("session")},"error":f.error}}
func timing(samples: Array) -> Dictionary:
	if samples.is_empty():return {}
	samples.sort();var total := 0.
	for value in samples:total += value
	return {"count":samples.size(),"mean_ms":total/samples.size(),"p95_ms":samples[mini(samples.size()-1,ceili(samples.size()*.95)-1)],"max_ms":samples[-1]}
func run() -> void:
	var args := OS.get_cmdline_user_args();var report := FileAccess.open(args[1],FileAccess.WRITE)
	Profile.enabled = true;Profile.reset()
	var view = load("res://main.gd").new();view.capture_path = args[0];view.orbit_enabled = false
	root.add_child(view);view.set_process(false);view.set_process_input(false);view.set_process_unhandled_input(false)
	view.physical_rate = 1.;view.scene_loop_playback = false
	var started := Time.get_ticks_msec();var previous := Time.get_ticks_usec();var next_log := 0
	var began_play := false;var settled_since := -1;var last_reason := "";var play_started := 0
	var max_seconds := float(args[2]);var ended := false
	var capture_end: float = view.generic_reader.frames[-1].time
	var target_end: float = minf(capture_end,view.generic_reader.frames[0].time+float(args[4])) if args.size()>4 and float(args[4])>0 else capture_end
	while Time.get_ticks_msec()-started < max_seconds*1000:
		await process_frame
		var now := Time.get_ticks_usec();var delta := (now-previous)/1000000.;previous = now
		var tick_started := Time.get_ticks_usec();view.scene_layers.tick(delta)
		if began_play:
			frames_ms.append(delta*1000.);ticks_ms.append((Time.get_ticks_usec()-tick_started)/1000.)
		if not began_play:
			var ps: Dictionary = view.scene_layers.playback.worker.status();var fs: Dictionary = view.scene_layers.field_playback.worker.status()
			var field_ready: bool = not view.scene_layers.field_playback.active() or (fs.session.get("state") == "ready" and fs.active_jobs == 0)
			var particle_ready: bool = not view.scene_layers.playback.enabled or (not ps.worker_active and ps.desired.all(func(i):return ps.ready_indices.has(i)))
			if not field_ready or not particle_ready:settled_since = -1
			elif settled_since < 0:settled_since = Time.get_ticks_msec()
			if settled_since >= 0 and Time.get_ticks_msec()-settled_since > 2000:
				var row := snapshot(view);row.event = "paused_filled";report.store_line(JSON.stringify(row));report.flush()
				view.play_button.pressed.emit();began_play = view.playing;play_started = Time.get_ticks_msec()
		if began_play:
			var reason: String = view.scene_layers.transport_wait_reason
			if reason != last_reason:
				if not last_reason.is_empty():holds[-1].end_wall = Time.get_ticks_msec()/1000.
				if not reason.is_empty():
					var hold := snapshot(view);hold.event = "hold_start";report.store_line(JSON.stringify(hold));holds.append({"reason":reason,"time":view.requested_time,"start_wall":hold.wall})
				last_reason = reason
		if Time.get_ticks_msec() >= next_log:
			var row := snapshot(view);report.store_line(JSON.stringify(row));report.flush();next_log = Time.get_ticks_msec()+1000
			print("RUNWAY time=",row.time," particle=",row.particle_ahead," field=",row.field_ahead," scene=",row.scene_ahead," reason=",row.reason)
		if began_play and (not view.playing or view.requested_time >= target_end):ended = view.requested_time >= target_end;break
	var final := snapshot(view);final.event = "playback_final";final.reached_end = view.requested_time >= capture_end;final.criterion_met = ended;final.target_end = target_end;report.store_line(JSON.stringify(final))
	if not last_reason.is_empty():holds[-1].end_wall = final.wall
	var scrub := []
	var play_seconds := (Time.get_ticks_msec()-play_started)/1000. if began_play else 0.
	if args.size()>3 and args[3] == "--scrub" and ended:
		view.playing = false
		for fraction in [.5,0.,.9,.25]:
			var target: float = lerpf(view.generic_reader.frames[0].time,view.generic_reader.frames[-1].time,fraction)
			var begin := Time.get_ticks_msec();var accepted: bool = view._seek_time(target)
			while accepted and Time.get_ticks_msec()-begin < 30000:
				view.scene_layers.tick(0);await process_frame
				if not view.scene_layers.is_buffering() and is_equal_approx(float(view.committed_sample.get("requested_time",-1)),target):break
			var row := snapshot(view);row.event = "scrub";row.seek_ms = Time.get_ticks_msec()-begin;row.accepted = accepted;row.target_time = target
			scrub.append(row);report.store_line(JSON.stringify(row));report.flush()
	var events: Array = view.scene_layers.playback.worker_events.duplicate(true)
	var metrics := {"event":"metrics","holds":holds,"frame_wall":timing(frames_ms),"tick_cpu":timing(ticks_ms),"profile":Profile.report(),"particle_jobs":events,"scrubs":scrub,"play_seconds":play_seconds}
	report.store_line(JSON.stringify(metrics));report.close();view.free();await process_frame;quit()
