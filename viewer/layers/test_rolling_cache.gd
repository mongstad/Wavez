extends "res://layers/test_adaptive_cache.gd"
const Timeline = preload("res://ui/shell/prepared_timeline.gd")
class ConstrainedBuffer extends "res://layers/field_buffer.gd":
	var physical_ceiling := 0
	func _memory_headroom() -> Dictionary:
		var snapshot := super._memory_headroom()
		if physical_ceiling > 0:
			# Only tighten real admission. Model a finite machine without allocating
			# unrelated RAM or changing global OS settings.
			snapshot.available_physical = mini(snapshot.available_physical,maxi(0,physical_ceiling-int(status().bytes)))
		return snapshot

func wait_worker(worker, state := "ready") -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 10000:
		if worker.status().session.get("state") == state and not worker.status().active:return true
		await process_frame
	return false

func pressure_case(control, reverse: bool) -> Dictionary:
	var worker := ConstrainedBuffer.new();worker.worker_count = 1;worker.start();worker.trace_reads = true
	var jobs: Array = []
	for index in range(7):
		var job: Dictionary = control._job("field",19-index if reverse else index,control.layers.field_budget())
		var file := FileAccess.open(job.path,FileAccess.READ)
		var entry: Dictionary = FieldBuffer.Reader.materialize(file,job.entry,job.object)
		job.charge = FieldBuffer.Prepare.charge(entry,job.channel,job.budget).bytes
		jobs.append(job)
	var charge: int = jobs[0].charge
	worker.request("rolling",jobs.slice(0,5),charge*7,true)
	check(await wait_worker(worker),"Pressure setup fills five exact samples")
	var pinned := {jobs[3].key:true,jobs[4].key:true}
	worker.protect(pinned,jobs[3].entry.time,-1 if reverse else 1)
	worker.physical_ceiling = int(Policy.snapshot().reserve)+charge*7 # Five residents leave only two jobs of scratch.
	var before: Dictionary = worker.status()
	worker.request("rolling",jobs.slice(3,7),charge*7,true)
	check(await wait_worker(worker),"Pressure reclaims history and completes ahead without an external retry")
	var after: Dictionary = worker.status(true)
	check(after.pressure_evictions > 0,"Physical pressure explicitly evicts eligible history")
	check(after.charges.has(jobs[3].key) and after.charges.has(jobs[4].key),"Committed and staged source entries stay protected")
	check(after.completed-before.completed == 2,"Resident overlap is not prepared again")
	check(after.bytes+after.in_flight_bytes <= after.limit,"Pressure turnover remains bounded")
	for event in after.eviction_events:
		if event.pressure:check((float(event.time)-float(jobs[3].entry.time))*(-1 if reverse else 1) < 0,"Pressure removes the opposite side of the playhead")
	# Once only protected/wanted data remain, genuine pressure must wait safely.
	worker.physical_ceiling = int(Policy.snapshot().reserve)
	var target: Dictionary = control._job("field",10,control.layers.field_budget())
	worker.request("rolling",[jobs[3],jobs[4],target],charge*7,true)
	check(await wait_worker(worker,"pressure"),"No eligible capacity produces an explicit pressure wait")
	check(worker.status().charges.has(jobs[3].key) and worker.status().failures.is_empty(),"Pressure cannot evict the committed sample or invent corruption")
	worker.physical_ceiling = 0
	worker.request("rolling",[jobs[3],jobs[4],target],charge*7,true)
	check(await wait_worker(worker),"Physical headroom recovery resumes safely")
	worker.close();return after

func shrink_during_publication(control) -> void:
	var worker := FieldBuffer.new();worker.worker_count = 1;worker.trace_reads = true;worker.start()
	var jobs: Array = []
	for index in range(4):
		var job: Dictionary = control._job("field",index,control.layers.field_budget())
		var entry: Dictionary = FieldBuffer.Reader.materialize(FileAccess.open(job.path,FileAccess.READ),job.entry,job.object)
		job.charge = FieldBuffer.Prepare.charge(entry,job.channel,job.budget).bytes;jobs.append(job)
	var charge: int = jobs[0].charge
	worker.request("shrink",jobs.slice(0,3),charge*4,true)
	check(await wait_worker(worker),"Mid-batch shrink starts with three resident samples")
	worker.protect({jobs[2].key:true},jobs[2].entry.time,1)
	var gate := Semaphore.new();worker.test_barrier = gate
	worker.request("shrink",jobs.slice(2,4),charge*4,true)
	var deadline := Time.get_ticks_msec()+5000
	while not worker.status().test_barrier_waiting and Time.get_ticks_msec()<deadline:await process_frame
	check(worker.status().test_barrier_waiting,"Completed incoming sample is held before publication")
	var before: Dictionary = worker.status()
	worker.request("shrink",jobs.slice(2,4),charge*2,true)
	worker.test_barrier = null;gate.post()
	check(await wait_worker(worker),"Shrunken rolling budget reclaims history and publishes the completed sample")
	var after: Dictionary = worker.status()
	check(after.cancelled == before.cancelled and worker.read_trace().count(jobs[3].key) == 1,"Budget shrink does not discard and recompute usable in-flight work")
	check(after.charges.has(jobs[2].key) and after.charges.has(jobs[3].key) and after.evictions == 2,"Publication reclamation preserves current and incoming data")
	check(after.bytes+after.in_flight_bytes <= after.limit,"Publication still respects the reduced hard limit")
	worker.close()

func run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var view = make_view(directory.path_join("session.ssc"),true)
	var control = view.scene_layers.field_playback
	check(await settle(view,0),"Small capture becomes wholly prepared")
	check(control.worker.status().frames == 20,"Whole-run readiness preserved for a fitting capture")
	view.timeline.refresh(view,true)
	if DisplayServer.get_name() != "headless":
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		screenshot.save_png(directory.path_join("full-coverage.png"))
		var rect: Rect2 = view.timeline.get_global_rect()
		var edge := screenshot.get_pixel(int(rect.end.x)-3,int(rect.position.y+rect.size.y*.5))
		var expected: Color = view.timeline.scene_color
		check(absf(edge.r-expected.r)<.03 and absf(edge.g-expected.g)<.03 and absf(edge.b-expected.b)<.03,"Full prepared coverage reaches the track end without a grabber-width gap")
		Job.write_json(directory.path_join("timeline-geometry.json"),{"rect":var_to_str(view.timeline.get_global_rect()),"center_grabber":view.timeline.get_theme_constant("center_grabber"),"icon_width":view.timeline.get_theme_icon("grabber").get_width(),"coverage":view.timeline.coverage})
	var forward := await pressure_case(control,false)
	var reverse := await pressure_case(control,true)
	await shrink_during_publication(control)
	control.cache_cap_bytes = 6*(32*32*32*20+65536)
	control.invalidate()
	check(await sample(view,.5,true) and await settle(view,.5),"Bounded window prepared away from origin")
	var before: Dictionary = control.worker.status()
	var retained_times: Array = []
	for row in view.generic_reader.samples.field:
		if before.charges.has(control._job("field",row.index,view.scene_layers.field_budget()).key):retained_times.append(float(row.time))
	var retained_time: float = retained_times[-2] # Current/next exist, but later runway does not.
	var gate := Semaphore.new();control.worker.test_barrier = gate
	view.scene_layers.seek(retained_time)
	check(await sample(view,retained_time,true),"Seek inside prepared region commits")
	var deadline := Time.get_ticks_msec()+5000
	while not control.worker.status().test_barrier_waiting and Time.get_ticks_msec()<deadline:await process_frame
	check(control.worker.status().test_barrier_waiting,"Missing future runway reaches the real publication barrier")
	view.playing = true;control.begin_session()
	check(control.session_waiting,"Minimal retained coverage waits for adaptive runway while new fill is blocked")
	for frame in range(5):view.scene_layers.tick(.05);await process_frame
	check(control.session_waiting and view.committed_sample.requested_time == retained_time,"Intentional runway wait holds the committed clock despite a ready current/next pair")
	control.worker.test_barrier = null;gate.post()
	check(await session_ready(view) and not control.session_waiting,"Rebuilt admitted runway releases the latched wait")
	view.playing = false;control.cancel_session()
	check(await settle(view,retained_time),"Background fill resumes")
	view.playing = true;control.begin_session()
	check(not control.session_waiting,"Completed admitted runway resumes without recomputing resident overlap")
	view.playing = false;control.cancel_session()
	check(control.worker.status().completed-before.completed < control.worker.status().frames,"Overlapping seek reuses preparations")
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("oracle.json")))
	for i in range(28):
		var time: float = [.1,1.7,.8,1.2][i%4]
		view.physical_rate = -1 if i%2 else 1
		view.scene_layers.seek(time)
		if i%4 == 3:
			check(await sample(view,time,true),"Repeated seek/reverse final target commits")
			var field = view.scene_layers.views.field
			var index: int = field.data.source_index
			for channel in oracle[index]:check(Hash.digest(field.data.channels[channel].to_byte_array()) == oracle[index][channel],"Stress preserves exact "+channel)
	check(await settle(view,1.2),"Stress queue drains")
	check(accounting(control.worker),"Stress cache ownership remains bounded")
	before = control.worker.status();switch_channel(view,"signed")
	check(await sample(view,1.2,true) and await settle(view,1.2),"Selected channel replacement prepares")
	check(control.worker.status().source_reuses > before.source_reuses,"Channel replacement reuses all-channel source arrays")
	var timeline = view.timeline;timeline.refresh(view,true)
	check(not timeline.coverage.fields.is_empty() and timeline.coverage.fields == timeline.coverage.scene,"Field-only timeline reflects actual selected-channel readiness")
	var actual := {}
	for job in control.automatic_jobs:
		if control.worker.status().charges.has(job.key):actual[int(job.entry.index)] = true
	check(Timeline.axis_position(1,[{"time":0.0},{"time":1.0},{"time":100.0}]) == .5,"Irregular source time maps to the true union-index location")
	check(Timeline.spans([{"time":0.0},{"time":1.0},{"time":9.0},{"time":10.0}],{0:true,2:true},0,10) == [[0.0,1.0],[9.0,10.0]],"Prepared islands keep actual time bounds and gaps")
	check(Timeline.intersect([[0.0,10.0]],[[1.0,2.0],[8.0,9.0]]) == [[1.0,2.0],[8.0,9.0]],"Whole-scene coverage is restricted by other layers")
	var final: Dictionary = control.profile_report()
	var worker = control.worker;view.free();await process_frame
	check(worker.status().bytes == 0 and worker.status().in_flight_bytes == 0,"Teardown releases prepared and active ownership")
	var mixed = make_view(directory.path_join("mixed.ssc"),true)
	check(await sample(mixed,0,true) and await settle(mixed,0),"Mixed independent clocks become ready")
	mixed.timeline.refresh(mixed,true)
	check(mixed.timeline.coverage.fields == [[0.0,2.0]],"Small field timeline is fully prepared")
	check(not mixed.timeline.coverage.scene.is_empty() and mixed.timeline.coverage.scene[0][1] < 2.0,"Particle pair readiness limits the all-layer line even with all fields prepared")
	mixed.particle_layer_visible = false;mixed.timeline.refresh(mixed,true)
	check(mixed.timeline.coverage.scene == mixed.timeline.coverage.fields,"Hidden particle layer does not restrict visible coverage")
	mixed.particle_layer_visible = true;mixed.color_channel = "velocity_magnitude";mixed.timeline.refresh(mixed,true)
	check(mixed.timeline.coverage.scene.is_empty(),"Changed particle display settings cannot advertise obsolete readiness")
	mixed.free();await process_frame
	Job.write_json(directory.path_join("checks.json"),{"checks":checks,"failures":failures,"forward_pressure":forward,"reverse_pressure":reverse,"final":final})
	print("ROLLING CACHE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
