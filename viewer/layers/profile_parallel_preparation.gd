extends "res://layers/profile_payload_integrity.gd"
const Buffer = preload("res://layers/field_buffer.gd")
const Stamp = preload("res://data/source_stamp.gd")

func run() -> void:
	var args := OS.get_cmdline_user_args();var source := args[0];var output := args[1]
	var count := int(args[2]);var first := int(args[3]);var cache_mib := int(args[4]);var seconds := float(args[5])
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"worker_count":Buffer.default_worker_count(),"memory_before":Policy.snapshot(),"playback":[],"scientific":[]}
	var reader := Reader.new(false);check(reader.open(source),"Production source opens")
	if not failures.is_empty():quit(1);return
	var jobs: Array = [];var charge := 0
	for index in range(first,first+count):
		var entry: Dictionary = reader.samples.field[index]
		var bytes: int = entry.decoded*2+65536;charge += bytes
		jobs.append({"key":str(index),"source_key":str(index),"scope":"profile","entry":entry.duplicate(true),"object":reader.objects.field,"channel":"density","budget":512*Policy.MIB,"charge":bytes,"path":source,"stamp":reader.source_stamp})
	var worker := Buffer.new();worker.trace_reads = true;check(worker.start() == OK,"Pool starts")
	phase("prepare");var wall := Time.get_ticks_usec()
	worker.request("profile",jobs,charge,true)
	while worker.status().session.get("state") != "ready" and Time.get_ticks_usec()-wall < 120000000:
		await process_frame
	var elapsed := (Time.get_ticks_usec()-wall)/1000000.0;var status := worker.status()
	check(status.completed == count and status.failures.is_empty(),"Every requested sample published once")
	check(worker.read_trace().size() == count,"No duplicate source preparation")
	check(status.bytes <= status.limit and status.peak_active <= worker.worker_count,"Bounded pool and cache")
	var cadence: float = reader.samples.field[first+1].time-reader.samples.field[first].time
	report.preparation = {"first":first,"count":count,"wall_seconds":elapsed,"samples_per_second":count/elapsed,"source_seconds_per_wall_second":count*cadence/elapsed,"publication_rate":status.completed/elapsed,"status":status}
	phase("oracle")
	for index in ([first,first+count/2,first+count-1] if count > 0 else []):
		var prepared := worker.get_frame(str(index));check(not prepared.is_empty(),"Oracle sample resident")
		if prepared.is_empty():continue
		var hashes := {};var planes := PackedByteArray()
		for name in prepared.sample.channels:hashes[name] = Hash.digest(prepared.sample.channels[name].to_byte_array())
		for plane in prepared.planes:planes.append_array(plane.get_data())
		check(Hash.digest(planes) == hashes.density and prepared.lod == 1,"LOD 1 plane equality")
		report.scientific.append({"index":index,"time":prepared.sample.time,"hashes":hashes})
	worker.close();reader.close()
	var speeds: Array = JSON.parse_string(args[6]) if args.size() > 6 else [1,2,4]
	for speed in speeds:
		phase("fill_"+str(speed));var start := Time.get_ticks_usec();var view = make_view(source,true)
		var control = view.scene_layers.field_playback;control.cache_cap_bytes = cache_mib*Policy.MIB
		check(await fill(view),"Initial bounded window ready")
		var row := {"speed":speed,"fill_seconds":(Time.get_ticks_usec()-start)/1000000.0,"initial":control.worker.status(),"cache_cap_mib":cache_mib}
		phase("play_"+str(speed));view.playing = true;view.physical_rate = speed;view.scene_loop_playback = false
		var callbacks: Array = [];var frames: Array = [];var field_waits := 0;var particle_waits := 0;var field_wait_us := 0;var particle_wait_us := 0
		var field_events := 0;var particle_events := 0;var field_before := false;var particle_before := false
		var draws: Array = [];var last_draw := [Time.get_ticks_usec()];var seen := {}
		var on_draw := func():
			var now := Time.get_ticks_usec()
			draws.append({"ms":(now-last_draw[0])/1000.0,"field_wait":control.buffering,"particle_wait":view.scene_layers.playback.buffering})
			last_draw[0] = now
		RenderingServer.frame_post_draw.connect(on_draw)
		var play_start: float = view.requested_time;var play_wall := Time.get_ticks_usec();var previous := play_wall
		var limit := seconds if seconds > 0 else 600.0;var next_log := play_wall+1000000
		while Time.get_ticks_usec()-play_wall < limit*1000000:
			await process_frame
			var tick := Time.get_ticks_usec();var delta := tick-previous;frames.append(delta/1000.0)
			if control.buffering:field_wait_us += delta
			if view.scene_layers.playback.buffering:particle_wait_us += delta
			view.scene_layers.tick(delta/1000000.0);previous = tick;callbacks.append((Time.get_ticks_usec()-tick)/1000.0)
			if control.buffering:field_waits += 1
			if view.scene_layers.playback.buffering:particle_waits += 1
			if control.buffering and not field_before:field_events += 1
			if view.scene_layers.playback.buffering and not particle_before:particle_events += 1
			field_before = control.buffering;particle_before = view.scene_layers.playback.buffering
			seen[str(view.scene_layers.views.field.data.source_index)] = true
			if tick >= next_log:print("PROGRESS ",speed," ",view.requested_time," field=",field_events," particle=",particle_events);next_log = tick+5000000
			if view.requested_time >= view.generic_reader.frames[-1].time:break
		view.playing = false
		RenderingServer.frame_post_draw.disconnect(on_draw)
		row.wall_seconds = (Time.get_ticks_usec()-play_wall)/1000000.0;row.committed_seconds = view.requested_time-play_start
		row.complete = view.requested_time >= view.generic_reader.frames[-1].time
		row.field_waits = field_waits;row.particle_waits = particle_waits;row.field_wait_seconds = field_wait_us/1000000.0;row.particle_wait_seconds = particle_wait_us/1000000.0
		row.field_wait_events = field_events;row.particle_wait_events = particle_events
		row.callbacks = callbacks;row.process_frame_intervals = frames;row.final = control.worker.status();row.memory = Policy.snapshot()
		row.draw_intervals = draws;row.field_samples_presented = seen.keys()
		check(row.final.bytes <= row.final.limit and (cache_mib == 0 or row.final.limit <= cache_mib*Policy.MIB),"Bounded field cache")
		check(view.scene_layers.error.is_empty() and control.error.is_empty(),"No playback errors")
		check(view.scene_layers.views.field.lod == 1,"Playback full resolution")
		if seconds <= 0:check(row.complete,"Full committed extent played")
		report.playback.append(row);view.free();await process_frame
		Job.write_json(output,report)
	report.checks = checks;report.failures = failures;Job.write_json(output,report)
	print("PARALLEL PROFILE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
