extends "res://layers/test_scene_playback.gd"
const FieldBuffer = preload("res://layers/field_buffer.gd")
func session_ready(view) -> bool:
	var began := Time.get_ticks_msec()
	while view.scene_layers.field_playback.session_waiting and Time.get_ticks_msec()-began < 20000:
		view.scene_layers.tick(0);await process_frame
	return view.scene_layers.field_playback.worker.status().session.get("state") == "ready"
func run() -> void:
	var directory := OS.get_cmdline_user_args()[0]
	var gib := 1024*1024*1024
	for available in [0,2*gib,8*gib,32*gib]:
		var cap := FieldBuffer.session_capacity({"available_physical":available,"reserve":2*gib},0,gib,gib/8)
		check(cap>=0 and cap<=maxi(0,available-3*gib),"Available RAM and combined reservations constrain capacity")
		check(FieldBuffer.session_capacity({"available_physical":available,"reserve":2*gib},gib,gib,gib/8)>=cap,"Resident cache credited once")
	var view = load("res://main.gd").new();view.capture_path = directory.path_join("session.ssc");view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false)
	await process_frame
	var control = view.scene_layers.field_playback
	check(control.worker.status().session.is_empty() and not view.scene_layers.is_buffering(),"Opening remains lazy and interactive")
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
	# The native viewer defaults to autoplay; opening must not bypass Play's gate.
	var autoplay = load("res://main.gd").new();autoplay.capture_path = directory.path_join("session.ssc");autoplay.orbit_enabled = false
	root.add_child(autoplay);autoplay.set_process(false)
	check(autoplay.playing and autoplay.scene_layers.field_playback.session_waiting,"Autoplay requests complete initial preparation")
	var autoplay_start: float = autoplay.requested_time
	autoplay.scene_layers.tick(.5)
	check(autoplay.requested_time == autoplay_start,"Autoplay clock waits for all fields")
	check(await session_ready(autoplay),"Autoplay reaches full readiness")
	autoplay.scene_layers.tick(.1)
	check(autoplay.requested_time > autoplay_start,"Autoplay advances after full readiness")
	autoplay.free();await process_frame
	Job.write_json(directory.path_join("checks.json"),{"checks":checks,"failures":failures,"field":report})
	print("FIELD SESSION: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
