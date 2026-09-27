extends "res://layers/test_scene_playback.gd"
const Reader = preload("res://layers/scene_reader.gd")
const Buffer = preload("res://layers/field_buffer.gd")
const Prepare = preload("res://layers/field_prepare.gd")
const MIB := 1048576

func jobs_for(reader, channel := "density", indices: Array = []) -> Array:
	var jobs: Array = []
	if indices.is_empty():indices = range(reader.samples.field.size())
	for index in indices:
		var entry: Dictionary = reader.samples.field[index]
		jobs.append({"key":str(index)+channel,"source_key":str(index),"scope":"fixture","entry":entry.duplicate(true),"object":reader.objects.field,"channel":channel,"budget":32*MIB,"charge":entry.decoded*2+65536,"path":reader.source_path,"stamp":reader.source_stamp})
	return jobs
func ready(worker) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 10000:
		var state: Dictionary = worker.status()
		if state.session.get("state") == "ready" and not state.active:return true
		await process_frame
	return false
func barrier(worker) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 5000:
		if worker.status().test_barrier_waiting:return true
		await process_frame
	return false
func release(worker, gate) -> void:worker.test_barrier = null;gate.post()
func accounting(worker) -> void:
	worker.mutex.lock();var charge := 0
	for value in worker.prepared.values():charge += int(value.bytes)
	check(charge == worker.used and charge <= worker.limit,"Exact retained accounting")
	check(worker.order.size() == worker.prepared.size(),"One order entry per cached sample")
	check(worker.in_flight_bytes == 0 and worker.in_flight.is_empty(),"All completed/cancelled reservations released")
	worker.mutex.unlock()
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var reader := Reader.new(false);check(reader.open(out.path_join("session.ssc")),"Fixture opens")
	var oracle: Array = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("oracle.json")))
	var gpu: Array = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("gpu-oracle.json")))
	for count in [1,2,3,4]:
		var worker := Buffer.new();worker.worker_count = count;worker.automatic_workers = false;worker.trace_reads = true
		check(worker.start() == OK,"Start configured pool")
		worker.request("density",jobs_for(reader),32*MIB,true)
		check(await ready(worker),"Concurrent window completes")
		check(worker.status().peak_active == count,"Configured lanes exercised")
		check(worker.read_trace().size() == 20,"Exactly one decode per sample")
		check(worker.order == jobs_for(reader).map(func(job):return job.key),"Publication follows requested timeline order")
		for channel in ["density","signed","exact"]:
			if channel != "density":
				worker.cancel(true);worker.request(channel,jobs_for(reader,channel),32*MIB,true)
				check(await ready(worker),"Channel replacement completes")
			for index in range(20):
				var frame := worker.get_frame(str(index)+channel)
				check(not frame.is_empty(),"Every requested frame remains resident")
				if frame.is_empty():continue
				check(frame.sample.time == reader.samples.field[index].time,"Exact source timestamp")
				check(frame.sample.channels.size() == oracle[index].size(),"All source channels retained")
				for name in oracle[index]:check(Hash.digest(frame.sample.channels[name].to_byte_array()) == oracle[index][name],"Exact f32/f64 source values")
				var planes := PackedByteArray()
				for plane in frame.planes:planes.append_array(plane.get_data())
				check(frame.lod == 1 and Hash.digest(planes) == gpu[index][channel],"Full-resolution plane equality")
			accounting(worker)
		check(worker.read_trace().size() == 20,"Channel reuse never rereads source arrays")
		worker.close();check(worker.status().bytes == 0,"Close releases cache")
	# Deterministic races after all lanes are admitted, before any publication.
	for action in ["generation","seek","shrink","source"]:
		var worker := Buffer.new();worker.worker_count = 4;worker.automatic_workers = false
		var gate := Semaphore.new();worker.test_barrier = gate;worker.start()
		worker.request("old",jobs_for(reader),32*MIB,true)
		check(await barrier(worker),"Race overlaps active batch: "+action)
		check(worker.status().active_jobs == 4 and worker.status().in_flight_bytes > 0,"All in-flight results remain reserved")
		var next := jobs_for(reader,"density",[19,18,17,16])
		if action == "generation":
			worker.cancel(true);worker.request("new",next,32*MIB,true)
		elif action == "seek":worker.request("old",next,32*MIB,true)
		elif action == "shrink":
			next = jobs_for(reader,"density",[0]);worker.request("old",next,800000,true)
		else:
			var file := FileAccess.open(reader.source_path,FileAccess.READ_WRITE);file.seek_end();file.store_8(0);file.close()
		var began := Time.get_ticks_usec();release(worker,gate)
		check(await ready(worker),"Race drains and settles: "+action)
		var state := worker.status()
		if action == "source":
			check(state.failures.size() == 20 and state.frames == 0,"Changed source never publishes")
		else:
			check(state.cancelled >= 4,"Superseded batch rejected")
			check(state.frames == next.size(),"No stale or unwanted frames published")
			check(worker.order == next.map(func(job):return job.key),"Seek/reverse priority preserved")
			for job in next:check(not worker.get_frame(job.key).is_empty(),"Only current requested generation acquired")
		accounting(worker)
		print("RACE ",action," settle_ms=",(Time.get_ticks_usec()-began)/1000.0)
		worker.close();check(worker.status().bytes == 0,"Race close releases cache")
	reader.close()
	Job.write_json(out.path_join("parallel-results.json"),{"checks":checks,"failures":failures})
	print("FIELD PARALLEL: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
