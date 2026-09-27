extends "res://layers/test_field_session.gd"
const Policy = preload("res://layers/playback_memory.gd")
func settle(view, time: float) -> bool:
	var control = view.scene_layers.field_playback
	var began := Time.get_ticks_msec();var stable := 0;var previous := -1
	while Time.get_ticks_msec()-began < 10000:
		control.request(time,view.scene_layers.field_budget())
		var status: Dictionary = control.worker.status()
		if status.session.get("state") == "ready" and not status.active:
			if previous == status.completed:stable += 1
			else:stable = 0
			previous = status.completed
			if stable >= 2:return true
		await create_timer(.55).timeout
	return false
func window_keys(control) -> Array:
	return control.automatic_jobs.map(func(job):return job.key)
func run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var gib := 1024*Policy.MIB
	for ram in [4,8,16,48,128]:
		var reserve := Policy.system_reserve(ram*gib)+256*Policy.MIB
		var capacity := Policy.capacity({"available_physical":int(ram*gib*.8),"reserve":reserve},0,512*Policy.MIB,108*Policy.MIB)
		check(reserve >= 768*Policy.MIB and reserve <= 2304*Policy.MIB,"System reserve stays modest and bounded: "+str(ram))
		check(capacity > 0 and capacity < ram*gib*.8-reserve,"Capacity preserves explicit headroom: "+str(ram))
		check(Policy.capacity({"available_physical":reserve,"reserve":reserve},0,0,108*Policy.MIB) == 0,"Low physical RAM never borrows swap")
	var memory := Policy.snapshot()
	var swapped := {"available_physical":8*gib,"reserve":gib,"process_swap":gib}
	check(Policy.capacity(swapped,2*gib,0,0) == Policy.capacity({"available_physical":8*gib,"reserve":gib},gib,0,0),"Swapped pages are excluded from owned physical credit")
	check(memory.available_physical > 0 and memory.physical > 0,"Physical capacity detected")
	if OS.get_name() == "Linux":check(memory.process_rss > 0 and memory.process_peak_rss >= memory.process_rss,"Linux process telemetry reads tab-separated status")
	var view = make_view(directory.path_join("session.ssc"),true)
	var control = view.scene_layers.field_playback
	check(control.scope_choice.selected == 0 and control.worker.status().session.get("automatic",false),"Opening starts automatic preparation without Play or Performance")
	# Reinitialize with a small capacity so this short fixture behaves like a long capture.
	control.cache_cap_bytes = 4*(32*32*32*16*2+65536)
	control.invalidate();control.request(0,view.scene_layers.field_budget())
	check(await settle(view,0),"Initial automatic window fills while paused")
	check(control.worker.status().frames < 20 and control.worker.status().frames >= 3,"Window size follows capacity, not duration")
	check(control.partial_initial_window(),"Partial initial coverage asks opening transport to pause")
	check(accounting(control.worker),"Initial allocation is bounded")
	check(not control.session_waiting and not view.play_button.disabled,"Play does not require the whole timeline")
	control.invalidate();view.scene_layers.seek(0);view.playing = true;control.begin_session()
	check(await session_ready(view) and control.worker.status().frames < 20,"Early Play waits only for its admitted window")
	view.playing = false;control.cancel_session()
	check(await settle(view,0),"Pause retains automatic coverage after initial Play")
	var before: Dictionary = control.worker.status();var overlap := window_keys(control)
	check(view.scene_layers.seek(.1),"Overlapping scrub accepted")
	check(await sample(view,.1,true) and await settle(view,.1),"Overlapping window becomes ready")
	var keys := window_keys(control);var missing := 0
	for key in keys:
		if not before.charges.has(key):missing += 1
	check(keys.any(func(key):return overlap.has(key)),"New window overlaps cached samples")
	check(control.worker.status().pipeline_stages.file_io.count-before.pipeline_stages.file_io.count == missing,"Only missing overlapping-window samples read/decode")
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("oracle.json")))
	for time in [1.5,.2,1.8,.6]:
		check(view.scene_layers.seek(time) and await sample(view,time,true),"Distant seek prepares its target automatically: "+str(time))
		var field = view.scene_layers.views.field
		var index: int = view.generic_reader.bracket("field",time).a
		for channel in oracle[index]:check(Hash.digest(field.data.channels[channel].to_byte_array()) == oracle[index][channel],"Exact held source after scrub: "+channel)
		check(field.lod == 1 and field.data.channels.exact is PackedFloat64Array,"Scrub preserves resolution and precision")
	check(await settle(view,.6),"Final scrub window fills")
	before = control.worker.status()
	switch_channel(view,"signed")
	check(await sample(view,.6,true) and await settle(view,.6),"Channel change keeps automatic preparation")
	check(control.worker.status().source_reuses > before.source_reuses,"Channel switch reuses immutable scientific arrays")
	check(accounting(control.worker),"Channel replacement stays bounded")
	# Pressure changes capacity, never source validity; the committed scene survives.
	var committed: float = view.requested_time
	control.cache_cap_bytes = 1;control.request(1.4,view.scene_layers.field_budget())
	await create_timer(.1).timeout
	check(control.capacity_wait and control.worker.status().bytes == 0,"Too-small capacity releases the cache")
	check(control.error.is_empty() and view.scene_layers.error.is_empty() and view.requested_time == committed,"Capacity wait leaves a valid committed scene")
	control.cache_cap_bytes = 4*(32*32*32*16*2+65536)
	check(await sample(view,1.4,true) and await settle(view,1.4),"Capacity recovery retries without reopening")
	view.physical_rate = -4
	check(view.scene_layers.seek(1.2) and await sample(view,1.2,true) and await settle(view,1.2),"Reverse preparation follows playhead")
	var reverse_start: int = view.generic_reader.bracket("field",1.2).a
	check(control.automatic_jobs[0].entry.index == reverse_start and control.automatic_jobs[-1].entry.index < reverse_start,"Reverse queue orders earlier recorded samples")
	view.physical_rate = 4;view.scene_loop_playback = true
	var end: float = view.generic_reader.frames[-1].time
	check(view.scene_layers.seek(end) and await sample(view,end,true) and await settle(view,end),"Loop preparation crosses the recording end")
	check(control.automatic_jobs[0].entry.index == 19 and control.automatic_jobs[1].entry.index == 0,"Loop wraps within the bounded cache")
	for time in [.1,1.5,.8,1.2]:check(view.scene_layers.seek(time),"Rapid seek accepted")
	check(await sample(view,1.2,true) and await settle(view,1.2),"Final rapid seek wins")
	check(view.requested_time == 1.2 and accounting(control.worker),"Rapid seeks preserve clock and accounting")
	control.scope_choice.select(1);control.scope_choice.item_selected.emit(1)
	control.range_start.value = 1.0;control.range_end.value = 1.3
	view.playing = true;control.begin_session()
	check(await session_ready(view) and control.limited_playback(),"Advanced interval remains available after automatic caching")
	control.scope_choice.select(0);control.scope_choice.item_selected.emit(0)
	check(await sample(view,1.2,true) and await settle(view,1.2),"Returning from advanced interval restores automatic preparation")
	check(control.worker.status().session.get("automatic",false) and not control.limited_playback(),"Scope changes clear the previous session contract")
	# Exercise the worker's independent live-headroom refusal, not just planning.
	var isolated = FieldBuffer.new();isolated.start()
	var job: Dictionary = control.automatic_jobs[0].duplicate(true);job.other_reservation = 1 << 50
	isolated.request("pressure",[job],job.charge*2,true)
	var began := Time.get_ticks_msec()
	while isolated.status().session.get("state") != "pressure" and Time.get_ticks_msec()-began < 5000:await process_frame
	check(isolated.status().session.get("state") == "pressure" and isolated.status().failures.is_empty() and isolated.status().bytes == 0,"Worker pressure refuses allocation without a corruption failure")
	job.other_reservation = 0;isolated.request("pressure",[job],job.charge*2,true)
	began = Time.get_ticks_msec()
	while isolated.status().session.get("state") != "ready" and Time.get_ticks_msec()-began < 5000:await process_frame
	check(isolated.status().completed == 1 and isolated.status().failures.is_empty(),"Worker resumes after live capacity returns")
	isolated.close()
	var report: Dictionary = control.profile_report();var worker = control.worker
	view.free();await process_frame
	check(worker.status().bytes == 0,"Closing releases cache ownership")
	Job.write_json(directory.path_join("checks.json"),{"checks":checks,"failures":failures,"field":report,"memory":memory})
	print("ADAPTIVE CACHE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
