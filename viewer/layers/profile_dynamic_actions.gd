extends "res://layers/test_field_session.gd"
const Policy = preload("res://layers/playback_memory.gd")
var observations: Array = []
func pump_for(view, seconds: float, label: String) -> void:
	var begin := Time.get_ticks_usec();var previous := begin;var next := begin
	while Time.get_ticks_usec()-begin < seconds*1000000:
		await process_frame
		var now := Time.get_ticks_usec();view.scene_layers.tick((now-previous)/1000000.0);previous = now
		if now >= next:
			var control = view.scene_layers.field_playback
			observations.append({"label":label,"seconds":now/1000000.0,"time":view.requested_time,"policy":control.concurrency.report(),"demand":control.demand_report.duplicate(),"waiting":control.buffering,"memory":Policy.snapshot()})
			next = now+1000000
func run() -> void:
	var args := OS.get_cmdline_user_args();var source := args[0];var output := args[1]
	var view = make_view(source,true);var control = view.scene_layers.field_playback
	var report := {"actions":[],"scientific":[]}
	view.playing = true;control.begin_session();await pump_for(view,12,"startup")
	check(control.worker.status().peak_active >= 3,"Real workload reaches higher concurrency")
	check(control.worker.status().active,"Channel switch overlaps preparation")
	var change := Time.get_ticks_usec();switch_channel(view,"psi_real")
	await pump_for(view,2,"channel_during_preparation")
	check(await sample(view,view.requested_time,true),"Changed channel commits requested source")
	check(view.scene_layers.states.field.channel == "psi_real","Changed channel remains selected")
	check(control.worker.status().source_reuses > 0,"Channel change consumes existing all-channel cache")
	report.actions.append({"action":"channel","seconds":(Time.get_ticks_usec()-change)/1000000.0})
	for time in [view.requested_time+2,view.generic_reader.frames[-1].time*.7]:
		change = Time.get_ticks_usec();check(view.scene_layers.seek(time),"Seek accepted")
		check(await sample(view,time,true),"Seek target prepared")
		await pump_for(view,3,"seek")
		report.actions.append({"action":"seek","target":time,"seconds":(Time.get_ticks_usec()-change)/1000000.0})
	view.playing = false;control.cancel_session()
	var data: Dictionary = view.scene_layers.views.field.data;var hashes := {}
	for name in data.channels:hashes[name] = Hash.digest(data.channels[name].to_byte_array())
	report.scientific.append({"index":data.source_index,"time":data.time,"hashes":hashes})
	var reverse_start: float = view.requested_time
	view.physical_rate = -1;view.playing = true;control.begin_session()
	await pump_for(view,12,"reverse")
	check(view.scene_layers.views.field.lod == 1 and control.error.is_empty(),"Reverse remains full resolution without source error")
	check(view.requested_time < reverse_start-.1,"Reverse advances toward earlier source times")
	# Inject only the policy observation; do not allocate scarce physical RAM.
	var memory := Policy.snapshot();memory.available_physical = memory.reserve
	control.policy_memory_override = memory
	await pump_for(view,2,"low_headroom")
	check(control.worker.status().active_limit == 1,"Low observed headroom backs off to one lane")
	check(control.concurrency.events.any(func(event):return event.reason == "memory_headroom"),"Pressure decision has a reason")
	control.policy_memory_override = {}
	await pump_for(view,13,"headroom_recovery")
	check(control.concurrency.blocked_until < Time.get_ticks_msec()/1000.0,"Recovery cooldown expires")
	view.playing = false;control.cancel_session();view.physical_rate = 1;view.scene_loop_playback = true
	var end: float = view.generic_reader.frames[-1].time
	check(view.scene_layers.seek(end-.2) and await sample(view,end-.2,true),"Loop boundary seek prepared")
	view.playing = true;control.begin_session();await pump_for(view,20,"loop")
	check(view.requested_time < end-1,"Playback wraps recording boundary")
	for speed in [2,4]:
		view.physical_rate = speed;await pump_for(view,5,"speed_"+str(speed))
		check(control.error.is_empty() and view.scene_layers.error.is_empty(),"Live speed change retains valid playback")
	report.final = control.profile_report();report.timeline = observations
	# Ensure closing overlaps a cold native job, rather than depending on how
	# much coverage happened to finish during the preceding speed trial.
	view.playing = false;control.invalidate();control.request(end*.4,view.scene_layers.field_budget())
	var worker = control.worker;var began := Time.get_ticks_msec()
	while worker.status().active_jobs == 0 and Time.get_ticks_msec()-began < 5000:await process_frame
	report.active_before_close = worker.status().active_jobs > 0
	check(report.active_before_close,"Close overlaps active preparation")
	change = Time.get_ticks_usec();view.free();await process_frame
	report.close_ms = (Time.get_ticks_usec()-change)/1000.0
	check(worker.status().bytes == 0 and worker.status().in_flight_bytes == 0,"Close releases all outstanding ownership")
	view = make_view(source,true);check(await sample(view,0,true),"Reopen displays exact first sample")
	check(view.scene_layers.field_playback.worker.status().active_limit <= 2,"Reopen starts a fresh conservative controller")
	view.free();await process_frame
	report.checks = checks;report.failures = failures;Job.write_json(output,report)
	print("DYNAMIC ACTIONS: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
