extends "res://layers/test_scene_playback.gd"
# Same bounded workload before/after #107. Oracle hashes are outside stage timers.
const Reader = preload("res://layers/scene_reader.gd")
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/field_prepare.gd")
const Policy = preload("res://layers/playback_memory.gd")

func phase(name: String) -> void:print("PHASE ",name)

func fill(view) -> bool:
	var began := Time.get_ticks_msec();var stable_since := began;var completed := -1
	while Time.get_ticks_msec()-began < 120000:
		view.scene_layers.tick(0)
		var control = view.scene_layers.field_playback
		var status: Dictionary = control.worker.status()
		if status.session.get("state") != "ready" or status.active or status.completed != completed:stable_since = Time.get_ticks_msec()
		completed = status.completed
		# Allow the existing one-second adaptive planner to expand conservative
		# cold charges. Equal cache caps must start with equal useful coverage.
		if Time.get_ticks_msec()-stable_since >= 2000:return true
		if not control.error.is_empty() or not view.scene_layers.error.is_empty():return false
		await process_frame
	return false

func run() -> void:
	var args := OS.get_cmdline_user_args();var source := args[0];var output := args[1]
	var count := int(args[2]);var first := int(args[3]);var cache_mib := int(args[4]);var seconds := float(args[5])
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"memory_before":Policy.snapshot(),"sequential":{},"playback":[],"scientific":[]}
	phase("sequential")
	var reader := Reader.new(false)
	check(reader.open(source),"Production source opens")
	if not failures.is_empty():quit(1);return
	report.records = reader.records.size();report.samples = reader.samples.field.size()
	var rows: Array = [];var stages := {};var wall := Time.get_ticks_usec()
	for index in range(first,first+count):
		var tick := Time.get_ticks_usec();var desc := reader.describe("field",index)
		check(not desc.is_empty(),"Descriptor admitted")
		var descriptor_ms := (Time.get_ticks_usec()-tick)/1000.0
		var entry: Dictionary = reader.samples.field[index]
		var decoded := Channels.read(reader.file,entry,reader.objects.field,null,false)
		if decoded.is_empty() or decoded.has("error"):check(false,str(decoded.get("error","Cancelled")));quit(1);return
		var sample_data := {"channels":decoded.channels,"shapes":decoded.shapes,"geometry":desc.geometry,"statistics":decoded.statistics}
		var prepared := Prepare.prepare(reader.objects.field,sample_data,"density",512*Policy.MIB)
		check(not prepared.is_empty() and not prepared.has("error") and prepared.lod == 1,"Full-resolution preparation")
		var timings: Dictionary = decoded.timings.duplicate();timings.merge(prepared.timings);timings.descriptor = descriptor_ms
		for key in timings:stages[key] = stages.get(key,0.0)+timings[key]
		rows.append({"index":index,"time":entry.time,"ms":(Time.get_ticks_usec()-tick)/1000.0})
		# Release each sample before decoding the next; includes destruction in wall time.
		prepared.clear();sample_data.clear();decoded.clear()
	var elapsed := (Time.get_ticks_usec()-wall)/1000000.0
	var cadence: float = reader.samples.field[first+1].time-reader.samples.field[first].time
	report.sequential = {"first":first,"count":count,"wall_seconds":elapsed,"samples_per_second":count/elapsed,"source_seconds_per_wall_second":count*cadence/elapsed,"cadence":cadence,"stages_ms":stages,"rows":rows}
	phase("oracle")
	for index in [first,first+count/2,first+count-1]:
		var data := reader.read_sample("field",index);var hashes := {}
		for name in data.channels:hashes[name] = Hash.digest(data.channels[name].to_byte_array())
		report.scientific.append({"index":index,"time":data.time,"hashes":hashes})
	reader.close()
	for speed in [1,2,4]:
		phase("fill_"+str(speed))
		var start := Time.get_ticks_usec();var view = make_view(source,true)
		var control = view.scene_layers.field_playback
		control.cache_cap_bytes = cache_mib*Policy.MIB
		check(await fill(view),"Initial bounded window ready")
		var initial: Dictionary = control.worker.status()
		var row := {"speed":speed,"fill_seconds":(Time.get_ticks_usec()-start)/1000000.0,"initial":initial,"cache_cap_mib":cache_mib}
		phase("play_"+str(speed))
		view.playing = true;view.physical_rate = speed
		var callbacks: Array = [];var field_waits := 0;var particle_waits := 0;var field_wait_us := 0;var particle_wait_us := 0
		var play_start: float = view.requested_time;var play_wall := Time.get_ticks_usec();var previous := play_wall
		while Time.get_ticks_usec()-play_wall < seconds*1000000:
			await process_frame
			var tick := Time.get_ticks_usec();var delta := tick-previous
			if control.buffering:field_wait_us += delta
			if view.scene_layers.playback.buffering:particle_wait_us += delta
			view.scene_layers.tick(delta/1000000.0);previous = tick
			callbacks.append((Time.get_ticks_usec()-tick)/1000.0)
			if control.buffering:field_waits += 1
			if view.scene_layers.playback.buffering:particle_waits += 1
		view.playing = false
		row.wall_seconds = (Time.get_ticks_usec()-play_wall)/1000000.0;row.committed_seconds = view.requested_time-play_start
		row.field_waits = field_waits;row.particle_waits = particle_waits;row.field_wait_seconds = field_wait_us/1000000.0;row.particle_wait_seconds = particle_wait_us/1000000.0
		row.callbacks = callbacks;row.final = control.worker.status();row.memory = Policy.snapshot()
		check(row.final.bytes <= row.final.limit and row.final.limit <= cache_mib*Policy.MIB,"Bounded field cache")
		check(view.scene_layers.error.is_empty() and control.error.is_empty(),"No playback errors")
		check(view.scene_layers.views.field.lod == 1,"Playback full resolution")
		report.playback.append(row)
		view.free();await process_frame
	report.checks = checks;report.failures = failures
	Job.write_json(output,report)
	print("INTEGRITY PROFILE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
