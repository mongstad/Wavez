extends "res://layers/test_scene_playback.gd"
func policy_checks() -> void:
	var charge := 108*1024*1024+65536
	var Policy = preload("res://layers/field_playback.gd")
	var roomy := {"safe_cache_bytes":8*1024*1024*1024}
	var plan = Policy.preparation_budget(charge,5*charge,roomy,1024*1024*1024)
	check(plan.cpu_limit == 5*charge,"Roomy host remains workload bounded")
	check(plan.cpu_limit >= plan.required_bytes,"192 cubed admitted with sufficient RAM")
	plan = Policy.preparation_budget(2*charge,10*charge,roomy,0)
	check(plan.required_bytes == 4*charge and plan.cpu_limit >= plan.required_bytes,"Multiple visible targets aggregate")
	plan = Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":8*charge},4*charge)
	check(plan.cpu_limit == charge and plan.cpu_limit < plan.required_bytes,"Other reservations force safe refusal")
	plan = Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":0},0)
	check(plan.cpu_limit == 0,"Unknown or exhausted headroom refuses")
	plan = Policy.preparation_budget(0,0,roomy,0)
	check(plan.cpu_limit == 0,"Hidden fields reserve no cache")
func run() -> void:
	policy_checks()
	var directory := OS.get_cmdline_user_args()[0]
	var view = make_view(directory.path_join("large.wvz"),true)
	var playback = view.scene_layers.field_playback
	var targets: Array = playback.request(1.0,view.scene_layers.field_budget())
	var report := {"memory":playback.Memory.memory_headroom(),"targets":targets.map(func(j):return {"charge":j.charge,"decoded":j.entry.decoded,"preview_budget":j.budget}),"cpu_limit":playback.cpu_limit,"error":playback.error}
	if "--baseline" in OS.get_cmdline_user_args():
		check(not playback.error.is_empty(),"Baseline rejects 192 cubed field")
	else:
		check(playback.error.is_empty(),"192 cubed admitted")
		var particles = view.scene_layers.playback
		var limits := [particles.decoded_limit,particles.prepared_limit]
		particles.prepared_limit = 1 << 50 # Simulated reservation, no allocation.
		playback.automatic_checked = -1000;playback.request(1.0,view.scene_layers.field_budget())
		check(playback.cpu_limit == 0 and playback.capacity_wait and playback.error.is_empty(),"Constrained capacity waits without invalidating the capture")
		particles.prepared_limit = limits[1]
		playback.automatic_checked = -1000;playback.request(1.0,view.scene_layers.field_budget())
		check(playback.error.is_empty(),"Admission recovers when reservation is released")
		var oracle = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("oracle.json")))
		for t in [1.0,2.0,0.0]:
			check(await sample(view,t,true),"Async sample/seek " + str(t))
			var field = view.scene_layers.views.field
			for channel in oracle[int(t)]:
				check(Hash.digest(field.data.channels[channel].to_byte_array()) == oracle[int(t)][channel],"Scientific bytes " + channel)
			check(field.data.channels.density is PackedFloat32Array,"Source stays float32")
			check(playback.staged.size() <= 1,"One future texture")
			var gpu = playback.profile_report()
			check(gpu.current_gpu_bytes+gpu.staged_gpu_bytes <= 2*192*192*192*4,"Current plus staged GPU bytes bounded")
			playback.worker.mutex.lock()
			var queued: int = playback.worker.jobs.size()
			playback.worker.mutex.unlock()
			check(queued <= 3,"Automatic queue remains bounded by this recording")
			var before_uploads: int = playback.uploads
			playback.request(t,view.scene_layers.field_budget())
			playback.request(t,view.scene_layers.field_budget())
			check(playback.uploads-before_uploads <= 1,"At most one GPU upload per process frame")
			check(playback.worker.status().bytes <= playback.cpu_limit,"CPU cache bounded")
			check([particles.decoded_limit,particles.prepared_limit] == limits,"Field work leaves particle limits unchanged")
			check(field.lod == 1,"192 cubed preview remains full resolution")
			var prepared = playback.worker.get_frame(field.key)
			if not prepared.is_empty():
				var raw := PackedByteArray()
				for plane in prepared.planes:raw.append_array(plane.get_data())
				check(raw.size() == 192*192*192*4 and Hash.digest(raw) == oracle[int(t)].density,"Preview bytes match exact float32 oracle")
			report["final"] = playback.profile_report()
		view.playing = true;view.scene_layers.tick(.5);view.playing = false
		check(await sample(view,.5,true),"Playback tick and held interval commit")
		check(view.scene_layers.views.field.data.time == 0.0,"Field holds earlier recorded sample")
		# Reducing a limit during decoding cannot publish over the new limit.
		var isolated = playback.Buffer.new();var gate := Semaphore.new()
		isolated.test_barrier = gate;isolated.start()
		isolated.request("shrink",[targets[0]],targets[0].charge*2)
		var began := Time.get_ticks_msec()
		while not isolated.status().test_barrier_waiting and Time.get_ticks_msec()-began<10000:await process_frame
		check(isolated.status().test_barrier_waiting,"Budget shrink reaches in-flight publication")
		isolated.request("shrink",[targets[0]],0)
		isolated.test_barrier = null;gate.post()
		began = Time.get_ticks_msec()
		while isolated.status().active and Time.get_ticks_msec()-began<10000:await process_frame
		check(isolated.status().bytes == 0 and isolated.status().cancelled > 0,"Reduced budget cancels in-flight allocation publication")
		isolated.close()
		var multi = make_view(directory.path_join("multiple.wvz"),true)
		for state in multi.scene_layers.states.values():state.visible = true;state.volume = false;state.slice = true
		var fields = multi.scene_layers.field_playback
		var combined: Array = fields.request(1.0,multi.scene_layers.field_budget())
		check(combined.size() == 2,"Two visible field targets requested")
		var total := 0
		for job in combined:total += job.charge
		check(fields.budget_report.required_bytes == total,"Visible fields charged together")
		check(await sample(multi,1.0,true),"Two visible slices prepare together")
		multi.scene_layers.reader.cache.limit = 1 << 50
		fields.automatic_checked = -1000;fields.request(0.0,multi.scene_layers.field_budget())
		check(fields.cpu_limit == 0 and fields.capacity_wait and fields.error.is_empty(),"Aggregate fields wait under constrained headroom")
		multi.free();await process_frame
	report.checks = checks;report.failures = failures
	Job.write_json(directory.path_join("baseline.json" if "--baseline" in OS.get_cmdline_user_args() else "result.json"),report)
	view.free();await process_frame
	print("FIELD BUDGET: ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
