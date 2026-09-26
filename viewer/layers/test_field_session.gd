extends "res://layers/test_scene_playback.gd"
const FieldBuffer = preload("res://layers/field_buffer.gd")
func session_ready(view) -> bool:
	var began := Time.get_ticks_msec()
	while view.scene_layers.field_playback.session_waiting and Time.get_ticks_msec()-began < 20000:
		view.scene_layers.tick(0);await process_frame
	return view.scene_layers.field_playback.worker.status().session.get("state") == "ready"
func accounting(worker) -> bool:
	worker.mutex.lock()
	var total := 0;var keys := {}
	for key in worker.prepared:total += int(worker.prepared[key].bytes)
	for key in worker.order:keys[key] = true
	var correct: bool = total == worker.used and total <= worker.limit and keys.size() == worker.order.size() and keys.size() == worker.prepared.size()
	worker.mutex.unlock();return correct
func switch_channel(view, channel: String) -> void:
	var choice: OptionButton = view.scene_layers.panel_controls.field.channel
	for index in choice.item_count:
		if choice.get_item_metadata(index) == channel:
			choice.select(index);choice.item_selected.emit(index);return
func repeated_switches(view, oracle: Array, gpu_oracle: Array) -> void:
	var control = view.scene_layers.field_playback
	view.physical_rate = 2.0
	# Allow the worker to run between the UI channel change and Play. Discarding
	# the whole allocation here loses admission credit even if malloc keeps its
	# pages resident. Exercise both scalar channels, including signed values.
	for other in ["signed","exact"]:
		for channel in ["density",other,"density",other,"density"]:
			view.playing = false;control.cancel_session()
			var before: Dictionary = control.worker.status()
			var previous_key: String = view.scene_layers.views.field.key
			var previous_channel: String = view.scene_layers.states.field.channel
			switch_channel(view,channel)
			await create_timer(.15).timeout
			check(control.worker.status().bytes >= int(before.bytes*.75),"Channel switch retains the bounded allocation until replacements need it")
			if previous_channel != channel:check(control.worker.get_frame(previous_key).is_empty(),"Old channel preparation cannot be acquired in the new generation")
			check(accounting(control.worker),"Repeated switch cache charges and LRU membership agree")
			view.play_button.pressed.emit()
			# The real button may be disabled until the new visible sample arrives.
			if not view.playing:
				check(await sample(view,.5,true),"Paused replacement sample arrives")
				view.play_button.pressed.emit()
			check(await session_ready(view),"Repeated channel switch prepares every sample")
			check(control.worker.status().pipeline_stages.stored_hash.count == before.pipeline_stages.stored_hash.count,"Prepared channel changes do not reread, hash or decode resident source channels: %s %s -> %s" % [channel,before.pipeline_stages.stored_hash.count,control.worker.status().pipeline_stages.stored_hash.count])
			check(control.worker.status().session.get("resident_credit",0) >= int(before.bytes*.7),"Replacement admission credits the still-owned allocation")
			check(await sample(view,.5,true),"Replacement source sample commits")
			var field = view.scene_layers.views.field
			check(field.channel == channel and field.lod == 1,"Replacement publishes the selected channel at full resolution")
			for source_channel in oracle[5]:check(Hash.digest(field.data.channels[source_channel].to_byte_array()) == oracle[5][source_channel],"Repeated switch retains exact "+source_channel)
			var prepared_pixels := PackedByteArray()
			for plane in control.worker.get_frame(field.key).get("planes",[]):prepared_pixels.append_array(plane.get_data())
			check(Hash.digest(prepared_pixels) == gpu_oracle[5][channel],"Replacement planes contain the selected scalar values")
			# Compatibility's Godot 4.7.2 readback clips/quantizes float 3D textures
			# even in an isolated upload without SimScope. It is not a byte oracle.
			if DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "forward_plus":
				var pixels := PackedByteArray()
				for plane in field.texture.get_data():pixels.append_array(plane.get_data())
				check(Hash.digest(pixels) == gpu_oracle[5][channel],"Replacement GPU texture contains the selected scalar values")
			check(control.error.is_empty() and view.scene_layers.error.is_empty() and control.staged.size() <= 1,"Switching preserves playback and bounded GPU staging")
	# Hold publication while multiple new plans replace each other. Releasing
	# the old worker result must neither publish it nor lose the cache credit.
	var gate := Semaphore.new();control.worker.test_barrier = gate
	switch_channel(view,"exact")
	var began := Time.get_ticks_msec()
	while not control.worker.status().test_barrier_waiting and Time.get_ticks_msec()-began < 5000:
		view.scene_layers.tick(0);await process_frame
	check(control.worker.status().test_barrier_waiting,"Switch cancellation overlaps an unfinished preparation")
	for channel in ["density","signed","density","exact","density"]:
		switch_channel(view,channel);view.scene_layers.tick(0)
	control.worker.test_barrier = null;gate.post()
	check(await session_ready(view),"Repeated cancellation reaches full readiness for the final channel")
	check(await sample(view,.5,true),"Final channel commits after stale work completes")
	check(view.scene_layers.views.field.channel == "density" and accounting(control.worker),"Stale completion preserves selected channel and exact accounting")
func run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var Reader = preload("res://layers/scene_reader.gd")
	var unsupported = Reader.new()
	check(not unsupported.open(directory.path_join("unsupported-v3.ssc")) and unsupported.error.contains("Unsupported scene version"),"SIMSCP3 prefix refuses without a fallback parser")
	unsupported.close()
	var required = Reader.new();check(required.open(directory.path_join("session.ssc")),"SIMSCP4 opens")
	var description: Dictionary = required.describe("field",0).duplicate(true)
	var record: Dictionary = required.samples.field[0]
	description.arrays[0].erase("statistics_v1")
	check(Reader.validate_sample(required.objects.field,description,record.stored,record.decoded).contains("statistics_v1"),"Missing mandatory volume statistics refuses")
	description = required.describe("field",0).duplicate(true);description.arrays[0].chunks[0].origin = [0,0,0]
	check(Reader.validate_sample(required.objects.field,description,record.stored,record.decoded).contains("contiguous"),"Legacy brick descriptors refuse")
	for shape in [[32,32],[1,32,32],[513,2,2]]:
		description = required.describe("field",0).duplicate(true);description.arrays[0].shape = shape
		check(Reader.validate_sample(required.objects.field,description,record.stored,record.decoded).begins_with("Grid"),"Volume dimensional bounds refuse before decode: "+str(shape))
	required.close()
	var summary := {"minimum":PackedFloat64Array([-1.0]).to_byte_array().hex_encode(),"maximum":"010000000000f03f","finite":5,"nonfinite":3,"nonpositive":3}
	var Statistics = preload("res://layers/field_statistics.gd")
	check(Statistics.valid(summary,8),"Binary statistics accepts finite counts and extrema")
	var decoded: Dictionary = Statistics.decode(summary)
	check(decoded.maximum == "010000000000f03f".hex_decode().decode_double(0),"Binary summary preserves float64 extrema exactly")
	check(decoded == preload("res://layers/volume_color.gd").statistics(PackedFloat64Array([NAN,INF,-INF,-1.,0.,-0.,1.,decoded.maximum])),"Summary equals authoritative nonfinite and signed-zero source statistics")
	for key in ["minimum","maximum","finite","nonfinite","nonpositive"]:
		var bad: Dictionary = summary.duplicate();bad[key] = -1
		check(not Statistics.valid(bad,8),"Malformed recognized summary refuses: "+key)
	var gib := 1024*1024*1024
	for available in [0,2*gib,8*gib,32*gib]:
		var cap := FieldBuffer.session_capacity({"available_physical":available,"reserve":2*gib},0,gib,gib/8)
		check(cap>=0 and cap<=maxi(0,available-3*gib),"Available RAM and combined reservations constrain capacity")
		check(FieldBuffer.session_capacity({"available_physical":available,"reserve":2*gib},gib,gib,gib/8)>=cap,"Resident cache credited once")
	var view = load("res://main.gd").new();view.capture_path = directory.path_join("session.ssc");view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false)
	await process_frame
	var control = view.scene_layers.field_playback
	check(control.worker.status().session.get("automatic",false) and not view.scene_layers.is_buffering(),"Opening prepares ahead and remains interactive")
	control.scope_choice.select(1) # Retain full-interval regression coverage as an advanced choice.
	view.play_button.pressed.emit()
	check(view.playing and control.session_waiting,"Play starts explicit initial preparation")
	var initial: float = view.requested_time
	view.scene_layers.tick(.5)
	check(view.requested_time == initial,"Preparation does not advance the simulation clock")
	view.play_button.pressed.emit()
	check(not view.playing and not control.session_waiting,"Pause cancels preparation without waiting on worker")
	view.play_button.pressed.emit()
	check(view.scene_layers.seek(1.2),"Seek is accepted during initial preparation")
	check(await session_ready(view),"Resume prepares all fields")
	check(view.committed_sample.requested_time == 1.2,"Seek target published while continuous preparation stays gated")
	var state: Dictionary = control.worker.status();var evictions: int = state.evictions
	check(state.session.ready == 20 and state.frames == 20,"Readiness includes the entire file")
	check(state.bytes <= state.limit and state.limit == state.session.required_bytes,"Validated full allocation remains bounded")
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("oracle.json")))
	var gpu_oracle = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("gpu-oracle.json")))
	for i in range(20):
		check(await sample(view,i*.1,true),"Prepared sample "+str(i))
		var field = view.scene_layers.views.field
		for channel in oracle[i]:check(Hash.digest(field.data.channels[channel].to_byte_array()) == oracle[i][channel],"Exact retained source "+channel)
		check(field.lod == 1 and field.data.channels.exact is PackedFloat64Array,"Full resolution and source precision")
		check(control.staged.size() <= 1,"GPU staging stays bounded independently of full RAM cache")
	check(control.worker.status().evictions == evictions,"No full-cache eviction/rebuild during complete traversal")
	view.play_button.pressed.emit();view.play_button.pressed.emit()
	check(await session_ready(view),"Prepared repeat run resumes")
	check(control.worker.status().completed == state.completed,"Repeat reuses preparations")
	if DisplayServer.get_name() != "headless":
		for child in view.get_children():
			if child is CanvasLayer:child.visible = false
		check(await sample(view,.5,true),"Full-cache image target")
		for i in range(5):await process_frame
		await RenderingServer.frame_post_draw
		var prepared_pixels := root.get_texture().get_image().get_data()
		view.scene_layers.views.field.clear();view.scene_layers.sample(.5,false)
		for i in range(5):await process_frame
		await RenderingServer.frame_post_draw
		check(prepared_pixels == root.get_texture().get_image().get_data(),"Full-cache and synchronous pixels are identical")
	# A changed channel invalidates the CPU/GPU generation and is planned again.
	view.scene_layers.states.field.channel = "exact"
	view.scene_layers.resample();view.scene_layers.tick(0)
	check(await session_ready(view),"Channel change reparses/prepares its new generation")
	await repeated_switches(view,oracle,gpu_oracle)
	view.playing = false;control.cancel_session()
	var prior_decode_count: int = control.worker.status().pipeline_stages.stored_hash.count
	control.scope_choice.select(1);control.range_start.value = .65;control.range_end.value = 1.05
	view.playing = true;control.begin_session()
	check(await session_ready(view),"Selected interval reaches readiness")
	check(control.worker.status().session.total == 5,"Interval prepares only its held start through end samples")
	check(control.worker.status().pipeline_stages.stored_hash.count == prior_decode_count,"Narrowing an admitted timeline retains selected source samples without rereading")
	check(control.playback_range() == [.65,1.05],"Prepared interval is explicit")
	check(await sample(view,1.05,true),"Interval end is available")
	view.scene_layers.tick(.1)
	check(not view.playing and view.requested_time == 1.05,"Interval playback pauses exactly at its end")
	view.scene_loop_playback = true;view.playing = true;control.begin_session()
	check(await session_ready(view),"Prepared interval resumes for looping")
	check(await sample(view,1.0,true),"Loop boundary target arrives")
	await process_frame
	var loop_jobs: Array = control.request(1.0,view.scene_layers.field_budget())
	control.worker.mutex.lock()
	var bounded := true
	for job in control.worker.jobs:bounded = bounded and job.entry.index >= 6 and job.entry.index <= 10
	control.worker.mutex.unlock()
	check(bounded and loop_jobs.size() == 1,"Interval lookahead and loop wrap stay inside admitted samples")
	check(control.staged.has("field") and control.staged.field.sample.source_index == 6,"GPU lookahead stages the interval's first held sample at the loop boundary")
	view.scene_layers.tick(.1)
	check(await sample(view,.8,true),"Loop wrap uses the prepared interval")
	check(view.playing,"Interval loop remains playing")
	view.scene_loop_playback = false
	check(view.scene_layers.seek(1.8),"Seek outside prepared interval remains available")
	check(await sample(view,1.8,true),"Outside-interval seek uses bounded preparation")
	check(not view.playing and control.prepared_range.is_empty(),"Outside seek exits interval playback")
	control.scope_choice.select(2);control.forward_duration.value = .4
	check(await sample(view,.85,true),"Forward-window start is available")
	view.playing = true;control.begin_session()
	check(await session_ready(view),"Current-position-forward window prepares")
	check(control.worker.status().session.total == 5 and is_equal_approx(control.playback_range()[1],1.25),"Forward window has bounded coverage")
	view.playing = false;control.cancel_session();control.invalidate();view.physical_rate = -2.0
	check(await sample(view,.85,true),"Reverse-window start arrives")
	view.playing = true;control.begin_session()
	check(await session_ready(view),"Current-position reverse window prepares")
	check(control.worker.status().session.total == 5 and is_equal_approx(control.playback_range()[0],.45),"Reverse window follows playback direction")
	view.physical_rate = 2.0
	view.playing = false;control.cancel_session();control.invalidate()
	control.scope_choice.select(1);control.range_start.value = 1.05;control.range_end.value = .65
	view.playing = true;control.begin_session()
	check(not view.playing and control.worker.status().session.is_empty(),"Inverted interval refuses without preparing")
	control.scope_choice.select(1);control.range_start.value = 0;control.range_end.value = 1.9
	view.playing = false;control.cancel_session();control.invalidate()
	view.scene_layers.reader.cache.limit = 1 << 50
	view.playing = true;control.begin_session()
	await session_ready(view)
	check(control.worker.status().session.get("state") == "blocked" and not view.playing,"Constrained admission never reports a short window ready")
	view.scene_layers.reader.cache.limit = 256*1024*1024
	view.playing = true;control.begin_session()
	check(await session_ready(view),"Retry recovers after reservation pressure")
	var report: Dictionary = control.profile_report();var worker = control.worker
	view.free();await process_frame
	check(worker.status().bytes == 0 and worker.status().frames == 0,"Closing releases all retained CPU preparations")
	# Small-capture autoplay waits for its admitted automatic window.
	var autoplay = load("res://main.gd").new();autoplay.capture_path = directory.path_join("session.ssc");autoplay.orbit_enabled = false
	root.add_child(autoplay);autoplay.set_process(false)
	check(autoplay.playing and autoplay.scene_layers.field_playback.worker.status().session.get("automatic",false),"Autoplay uses automatic preparation")
	check(await session_ready(autoplay),"Autoplay waits for its admitted cache, without explicit interval planning")
	check(await sample(autoplay,.1,true),"Automatic target is ready")
	autoplay.free();await process_frame
	var late = load("res://main.gd").new();late.capture_path = directory.path_join("late.ssc");late.playing = false;late.orbit_enabled = false
	root.add_child(late);late.set_process(false);await process_frame
	var late_control = late.scene_layers.field_playback
	late_control.range_start.value = 1e-9
	check(late_control.range_start.value == 1e-9,"Preparation input does not quantize small scientific times")
	late_control.scope_choice.select(1);late_control.range_start.value = .2;late_control.range_end.value = 1.0
	late.playing = true;late_control.begin_session()
	check(await session_ready(late),"Interval can begin before a field's independent clock")
	check(late_control.worker.status().session.total == 2,"Late field prepares only samples within the interval")
	check(await sample(late,.8,true),"Late field appears with its recorded source sample")
	late.free();await process_frame
	Job.write_json(directory.path_join("checks.json"),{"checks":checks,"failures":failures,"field":report})
	print("FIELD SESSION: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
