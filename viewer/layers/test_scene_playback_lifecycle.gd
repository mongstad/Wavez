extends "res://layers/test_scene_playback.gd"
func write_source(path: String, raw: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(raw);file.close()
func await_ready(view) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 10000:
		if view.scene_layers.playback.pump():return true
		await process_frame
	return false
func await_gate(worker) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 10000:
		if worker.status().get("test_barrier_waiting",false):return true
		await process_frame
	return false
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-fixture="):out = arg.trim_prefix("--playback-fixture=")
	if out.is_empty():push_error("Missing fixture");quit(1);return
	var view = make_view(out.path_join("ids.ssc"),true)
	check(view.play_button.disabled,"style change waits only for its newly requested pair")
	check(await await_ready(view),"automatic startup completes safe preparation")
	check(not view.play_button.disabled and view.requested_time==0,"startup enables Play with unchanged source time")
	check(view.scene_layers.playback.worker.status().desired.size()<=8,"bounded startup lookahead")
	# Pre-retirement native v2 recipes serialized this hidden visual value.
	var native_recipe := preload("res://scene/inspection_state.gd").snapshot(view)
	native_recipe.visual.intensity_floor = .125
	native_recipe.visual.sliders["Intensity cutoff"] = .125
	check(preload("res://scene/inspection_state.gd").restore(view,native_recipe).is_empty() and view.requested_time==0,"existing native recipe fields restore after obsolete controls are removed")
	view.scene_layers.playback.set_policy("full")
	check(await await_ready(view),"legacy full setting requires only current pair")
	var start := Time.get_ticks_msec()
	while view.scene_layers.playback.worker.status().prepared_pairs<control_window(view) and Time.get_ticks_msec()-start<10000:await process_frame
	check(view.scene_layers.playback.worker.status().prepared_pairs<=8 and not view.scene_layers.playback.full_preload,"legacy full policy uses bounded rolling preparation")
	check(view.current_mm.instance_count==3,"rolling cache does not create extra GPU particle instances")
	var control = view.scene_layers.playback
	var entry: Dictionary = control.context.entries[0].duplicate(true)
	entry.decoded = 256*1048576
	for array in entry.descriptor.arrays:array.shape[0] = 1000000
	var fake: Array = []
	for i in range(40):fake.append(entry)
	control._budgets(fake,control.settings())
	check(not control.full_preload and control.window_pairs <= 8,"large estimates never enable exhaustive preload")
	control.set_policy("adaptive");check(await await_ready(view),"adaptive mode recovers after estimate-only refusal")
	view.playing = true;view.physical_rate = -.5
	check(await sample(view,2.125,true),"reverse playback starting pair")
	view.scene_layers.tick(.1)
	if view.scene_layers.is_buffering():await await_ready(view)
	check(control.direction == -1 and view.requested_time<2.125,"reverse physical playback builds backward window")
	view.scene_layers.tick(.2)
	if view.scene_layers.is_buffering():await await_ready(view)
	check(view.phase>=0 and view.phase<=1,"reverse recorded-time playback keeps valid union phase")
	view.playing = false;check(view.scene_layers.seek(0),"replay seek to start")
	check(await await_ready(view) and view.requested_time==0,"replay commits source start")
	view.scene_loop_playback = true;view.physical_rate = 1
	check(await sample(view,3.9,true),"loop starting sample")
	view.playing = true;view.scene_layers.tick(.2)
	if view.scene_layers.is_buffering():await await_ready(view)
	check(is_equal_approx(view.requested_time,.1),"physical loop wraps within recorded source time")
	check(control.worker.status().desired.has(0),"loop prefetch includes start of capture")
	view.playing = false;view.scene_loop_playback = false
	view.scene_layers.playback.begin(2.25,4)
	check(view.play_button.disabled,"replacement begins with pending particle preparation")
	var retained_reader = view.generic_reader
	var retained_generation: int = view.capture_generation
	for magic in ["VBCOSM1","SIMSCP1","SIMSCP2"]:
		var retired := FileAccess.get_file_as_bytes(out.path_join("ids.ssc"))
		for i in range(7):retired[i] = magic.unicode_at(i)
		write_source(out.path_join("unsupported.ssc"),retired)
		view._open_capture(out.path_join("unsupported.ssc"))
		check(view.generic_reader==retained_reader and view.capture_generation==retained_generation and view.play_button.disabled,"unsupported magic cannot replace or cancel a buffering scene: "+magic)
		check("Unsupported scene" in view.status_label.text,"unsupported magic reports a format error: "+magic)
	view._open_capture(out.path_join("missing.ssc"))
	check(view.generic_reader==retained_reader and view.capture_generation==retained_generation,"missing source preserves the open scene")
	var replaced_worker = view.scene_layers.playback.worker
	var old_generation: int = view.capture_generation
	view._open_capture(out.path_join("replacement.ssc"));view.set_process(false)
	check(not replaced_worker.thread.is_started(),"scene replacement joins the previous preparation worker")
	check(not view.play_button.disabled and view.scene_layers!=null and view.scene_layers.particle_id.is_empty(),"opening supported field scene during buffering restores Play")
	check(view.capture_generation>old_generation and view.requested_time==0 and view.current_mm.instance_count==0,"replacement commits only the new source generation")
	check(await sample(view,.5,true),"replacement field scene remains seekable")
	view.playing = true;view.physical_rate = .5;view.scene_layers.tick(.2)
	if view.scene_layers.is_buffering():await await_ready(view)
	check(is_equal_approx(view.requested_time,.6),"replacement field scene resumes playback")
	view.free()
	view = make_view(out.path_join("delayed.ssc"),true)
	check(view._seek_time(.25),"UI seek accepts union time before particles exist")
	check(await await_ready(view) and view.requested_time==.25,"unavailable particle seek retains requested layer time")
	check(await sample(view,.75,true),"layers can sample before particles exist")
	view.playing = true;view.physical_rate = 1
	view.scene_layers.tick(.1)
	check(is_equal_approx(view.requested_time,.85),"unavailable particles do not gate the union clock")
	view.scene_layers.tick(.3)
	check(await await_ready(view) and is_equal_approx(view.requested_time,1.15),"first available particle pair prepares and commits")
	view.free()
	var full := FileAccess.get_file_as_bytes(out.path_join("ids.ssc"))
	var config = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("live-config.json")))
	var live := out.path_join("lifecycle-live.ssc")
	write_source(live,full.slice(0,config.initial_end))
	view = make_view(live,true);check(await await_ready(view),"live prefix prepares")
	write_source(live,full.slice(0,int(config.initial_end)+40))
	check(await sample(view,.25,true) and view.frame_count==2,"incomplete append cannot publish a source timestamp")
	write_source(live,full)
	check(await sample(view,1.25,true) and view.frame_count==11,"committed append rebuilds independent union clock")
	check(view.timeline.max_value==10 and view.timeline.ratio<1,"live append preserves slider extent fix")
	var worker = view.scene_layers.playback.worker
	var gate := Semaphore.new();worker.test_barrier = gate
	view.manual_max += 1 # New style epoch guarantees a worker publication to gate.
	check(view.scene_layers.seek(3.125),"request cancellable pair")
	var at_gate := await await_gate(worker);check(at_gate,"real worker reached publication barrier")
	check(view.scene_layers.seek(.125),"new seek replaces obsolete window immediately")
	worker.test_barrier = null;gate.post()
	check(await await_ready(view) and is_equal_approx(view.requested_time,.125),"only latest seek commits after cancellation")
	check(worker.status().cancelled>0,"obsolete pair work was cancelled")
	gate = Semaphore.new();worker.test_barrier = gate;view.manual_max += 1
	check(view.scene_layers.seek(3.125),"prepare across pending replacement")
	at_gate = await await_gate(worker);check(at_gate,"replacement test reached worker barrier")
	write_source(live,FileAccess.get_file_as_bytes(out.path_join("anonymous.ssc")))
	check(not view.scene_layers.refresh(),"changed capture header requires reopen")
	check(view.frame_a==null and view.current_mm.instance_count==0,"replacement clears prior scientific display")
	worker.test_barrier = null;gate.post()
	start = Time.get_ticks_msec()
	while worker.status().worker_active and Time.get_ticks_msec()-start<10000:await process_frame
	check(worker.status().prepared_pairs==0,"obsolete source cannot publish a prepared pair")
	view._open_capture(live);view.set_process(false)
	check(await await_ready(view) and not view.frame_a.has_ids,"reopening replacement uses its identity policy")
	view.free();await process_frame
	Job.write_json(out.path_join("lifecycle-results.json"),{"checks":checks,"failures":failures})
	print("G3 PLAYBACK LIFECYCLE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func control_window(view) -> int:return view.scene_layers.playback.window_pairs
