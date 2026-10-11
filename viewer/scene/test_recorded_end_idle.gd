extends SceneTree
const Viewer = preload("res://main.gd")
const Profile = preload("res://scene/playback_profile.gd")
const Hash = preload("res://data/capture_index.gd")
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures := []
var observations := {}
var directory := ""
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func wait_time(view, time: float) -> bool:
	var until := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<until:
		await process_frame
		if is_equal_approx(float(view.committed_sample.get("requested_time",NAN)),time) and not view.scene_layers.is_buffering():return true
	return false
func ready(view) -> void:
	var until := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<until:
		await process_frame
		var p: Dictionary = view.scene_layers.playback.worker.status();var f: Dictionary = view.scene_layers.field_playback.worker.status()
		if not view.scene_layers.is_buffering() and not p.worker_active and p.desired.all(func(i):return p.ready_indices.has(i)) and (not view.scene_layers.field_playback.active() or f.session.get("state") == "ready"):break
func buffer_hash(view) -> String:
	var bytes: PackedByteArray = view.current_mm.buffer.to_byte_array()
	return "" if bytes.is_empty() else Hash.digest(bytes)
func pixels() -> String:return Hash.digest(root.get_texture().get_image().get_data())
func idle(view, label: String) -> void:
	await create_timer(.5).timeout
	var draws := Engine.get_frames_drawn();var callbacks := Engine.get_process_frames()
	var sample: Dictionary = view.committed_sample.duplicate(true);var camera: Transform3D = view.camera.transform
	var buffer := buffer_hash(view);var uploads: int = view.scene_layers.field_playback.uploads
	Profile.reset()
	var image := pixels() if DisplayServer.get_name() != "headless" else ""
	await create_timer(1.2).timeout
	observations[label] = {"draws":Engine.get_frames_drawn()-draws,"callbacks":Engine.get_process_frames()-callbacks,"display_samples":Profile.counters.get("g3_display_samples",0),"low_processor":OS.low_processor_usage_mode,"playing":view.playing,"time":view.requested_time}
	check(view.playing and view.scene_layers.holding_recorded_boundary(),label+" preserves held Play/live-follow state")
	check(sample == view.committed_sample and camera == view.camera.transform,label+" committed scientific clock and camera remain fixed")
	check(buffer_hash(view) == buffer and view.scene_layers.field_playback.uploads == uploads,label+" no repeated particle/field GPU submission")
	check(Profile.counters.get("g3_display_samples",0) == 0,label+" no duplicate display sample")
	check(OS.low_processor_usage_mode and observations[label].callbacks >= 20,label+" idle rendering retains responsive process callbacks")
	if not image.is_empty():
		check(observations[label].draws <= 4,label+" no continuous redraws")
		check(image == pixels(),label+" held presentation pixels unchanged")
		RenderingServer.force_draw(false)
		check(image == pixels(),label+" retained pixels match full-quality fresh draw")
func run() -> void:
	directory = OS.get_cmdline_user_args()[0]
	Profile.enabled = true;OS.low_processor_usage_mode = false;Engine.max_fps = 0
	for kind in ["particles","field","mesh","mixed"]:
		var view = Viewer.new();view.capture_path = directory.path_join(kind+".wvz");view.orbit_enabled = false
		root.add_child(view);view.set_process_input(false);view.set_process_unhandled_input(false)
		await ready(view)
		view.physical_rate = 4.;view.play_button.pressed.emit()
		check(await wait_time(view,2),kind+" actual callbacks reach the committed last sample")
		await idle(view,kind+"_end")
		view.physical_rate = -4.
		check(await wait_time(view,0),kind+" reversing from held end resumes without toggling Play")
		await idle(view,kind+"_start")
		view.physical_rate = 1.;view.scene_loop_playback = true
		await create_timer(2.3).timeout
		check(view.playing and not view.scene_layers.holding_recorded_boundary() and view.requested_time>0 and view.requested_time<2,kind+" Loop keeps advancing across its endpoint")
		check(not OS.low_processor_usage_mode,kind+" Loop retains active render pacing")
		view.scene_loop_playback = false;check(view._seek_time(2),kind+" scrub to recorded end accepted")
		check(await wait_time(view,2) and not view.playing,kind+" terminal UI scrub commits and preserves its Pause behavior")
		view.play_button.pressed.emit()
		await idle(view,kind+"_scrub_end")
		check(view._seek_time(1),kind+" UI scrub away accepted")
		check(await wait_time(view,1) and not view.playing,kind+" UI scrub away pauses at its exact target")
		view.play_button.pressed.emit();await create_timer(.3).timeout
		check(view.requested_time>1 and not view.scene_layers.holding_recorded_boundary() and not OS.low_processor_usage_mode,kind+" scrub away restores progression and active pacing")
		check(await wait_time(view,2),kind+" traversal returns to recorded end")
		view.orbit_enabled = true;var camera: Transform3D = view.camera.transform
		await create_timer(.4).timeout
		check(view.camera.transform != camera and not OS.low_processor_usage_mode and Engine.max_fps == 60,kind+" held-end Auto Orbit keeps its camera motion and 60 FPS cap")
		view.orbit_enabled = false
		view.free_camera = true
		var focus := root.gui_get_focus_owner()
		if focus != null:focus.release_focus()
		camera = view.camera.transform
		var motion := InputEventKey.new();motion.keycode = KEY_W;motion.physical_keycode = KEY_W;motion.pressed = true
		Input.parse_input_event(motion);Input.flush_buffered_events();await create_timer(.15).timeout
		motion.pressed = false;Input.parse_input_event(motion);Input.flush_buffered_events()
		check(view.camera.transform != camera,kind+" held-end free-camera movement remains responsive")
		await idle(view,kind+"_after_movement")
		check(view._close_capture() and view.generic_reader == null,kind+" close releases capture from held Play state")
		await create_timer(.4).timeout
		check(OS.low_processor_usage_mode,kind+" empty scene uses idle pacing")
		view.free();await process_frame
	# Growing captures retain Play at the edge and resume on newly committed data.
	var raw := FileAccess.get_file_as_bytes(directory.path_join("particles.wvz"))
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("live.json")))
	var path := directory.path_join("live.wvz");var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(raw.slice(0,int(config.prefix_end)));file.close()
	var live = Viewer.new();live.capture_path = path;root.add_child(live);await ready(live)
	live.physical_rate = 4.;live.play_button.pressed.emit();check(await wait_time(live,1),"live prefix reaches its recorded edge")
	await idle(live,"live_prefix")
	file = FileAccess.open(path,FileAccess.WRITE);file.store_buffer(raw);file.close()
	check(await wait_time(live,2) and live.playing,"source-tail polling resumes held Play when appended samples commit")
	live.free();await process_frame
	# Existing advanced field interval still pauses at its selected boundary.
	var advanced = Viewer.new();advanced.capture_path = directory.path_join("field.wvz");root.add_child(advanced);await ready(advanced)
	var field = advanced.scene_layers.field_playback
	field.scope_choice.select(1);field.range_start.value = .5;field.range_end.value = 1.5
	advanced.physical_rate = 4.;advanced.play_button.pressed.emit()
	var until := Time.get_ticks_msec()+15000
	while advanced.playing and Time.get_ticks_msec()<until:await process_frame
	check(not advanced.playing and advanced.requested_time == 1.5,"advanced selected interval preserves automatic Pause at its own boundary")
	advanced.free();await process_frame
	# Endpoint preparation must commit before the held condition becomes true.
	var gated = Viewer.new();gated.capture_path = directory.path_join("field.wvz");root.add_child(gated);await ready(gated)
	gated._seek_time(1);check(await wait_time(gated,1),"gated test starts at interior sample")
	field = gated.scene_layers.field_playback;var gate := Semaphore.new();field.worker.test_barrier = gate
	gated.scene_layers.states.field.channel = "psi_real";field.invalidate();gated.scene_layers.views.field.key = ""
	gated.playing = true;gated.physical_rate = 1.;gated.scene_layers.seek(2)
	until = Time.get_ticks_msec()+10000
	while not field.worker.status().test_barrier_waiting and Time.get_ticks_msec()<until:await process_frame
	check(field.worker.status().test_barrier_waiting and gated.committed_sample.requested_time == 1 and not gated.scene_layers.holding_recorded_boundary(),"missing terminal preparation retains the earlier scene and remains active")
	field.worker.test_barrier = null;gate.post()
	check(await wait_time(gated,2),"terminal preparation publishes before held idle")
	gated.offline_instance = true
	check(not gated.scene_layers.holding_recorded_boundary(),"offline rendering is excluded from the idle hold optimization")
	gated.offline_instance = false;gated.free();await process_frame
	Job.write_json(directory.path_join("end-idle.json"),{"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"packaged":not OS.has_feature("editor")})
	print("RECORDED END IDLE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
