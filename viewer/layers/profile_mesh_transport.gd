extends SceneTree
## Opt-in, read-only observations of the ordinary interactive loop for #193.
## Run with -- --mesh-transport-job=/absolute/path/job.json; never force ticks.
const Job = preload("res://video/render_job.gd")
const Profile = preload("res://scene/playback_profile.gd")
const Memory = preload("res://layers/playback_buffer.gd")
class DecodeProbe extends "res://layers/mesh_buffer.gd":
	var decode_ms := 0.0
	var decode_calls := 0
	func _decode(file: FileAccess, entry: Dictionary, obj: Dictionary) -> Dictionary:
		var began := Time.get_ticks_usec()
		var result := super._decode(file,entry,obj)
		var elapsed := (Time.get_ticks_usec()-began)/1000.0
		mutex.lock();decode_ms += elapsed;decode_calls += 1;mutex.unlock()
		return result
	func status() -> Dictionary:
		var result := super.status()
		mutex.lock();result.decode_ms = decode_ms;result.decode_calls = decode_calls;mutex.unlock()
		return result
class ObservedViewer extends "res://main.gd":
	var measuring := false
	var tick := {}
	func _process(delta: float) -> void:
		if not measuring:
			super._process(delta);return
		var began := Time.get_ticks_usec()
		var before: float = committed_sample.get("requested_time",requested_time)
		var requested_before := requested_time
		super._process(delta)
		tick = {"wall_us":began,"delta":delta,"callback_ms":(Time.get_ticks_usec()-began)/1000.0,
			"committed_before":before,"requested_before":requested_before}
class Observer extends Node:
	var view
	var rows: Array = []
	var draws: Array = []
	var start_us := 0
	var id := ""
	func draw() -> void:
		if view.measuring:draws.append((Time.get_ticks_usec()-start_us)/1000000.0)
	func _process(_delta: float) -> void:
		if not view.measuring or view.tick.is_empty():return
		var control = view.scene_layers.mesh_playback
		var cache: Dictionary = control.worker.status()
		var layer = view.scene_layers.views[id]
		var ready: Array = []
		for key in cache.ready_keys:ready.append(int(key.split("/")[1]))
		rows.append({"wall_s":(view.tick.wall_us-start_us)/1000000.0,"delta_s":view.tick.delta,
			"callback_ms":view.tick.callback_ms,"requested_before":view.tick.requested_before,
			"committed_before":view.tick.committed_before,"requested":view.requested_time,
			"committed":view.committed_sample.get("requested_time"),"pending":control.pending_time,
			"index":view.current_index,"alpha":layer.display_alpha,"wait":view.scene_layers.transport_wait_reason,
			"buffering":control.buffering,"status":view.shell.status_ui.readiness,
			"timer":view.shell.transport.displayed.text,"slider":view.timeline.value,
			"coverage":view.timeline.coverage.duplicate(true),"coverage_checked_ms":view.timeline.checked_ms,
			"timeline_width":view.timeline.size.x,"grabber_width":view.timeline.get_theme_icon("grabber").get_width(),
			"ready_sequences":ready,"cache_bytes":cache.bytes,"in_flight_bytes":cache.in_flight_bytes,
			"completed":cache.completed,"worker_ms":cache.worker_ms,"active":cache.active,
			"staged":control.staged.size(),"uploads":control.uploads})
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var config := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mesh-transport-job="):config = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--mesh-transport-job=")))
	if config.is_empty():push_error("Missing mesh transport job");quit(1);return
	var view := ObservedViewer.new();view.capture_path = config.capture;view.playing = false;view.orbit_enabled = false
	root.add_child(view)
	if view.scene_layers == null or view.committed_sample.is_empty():push_error("Capture did not open");view.free();quit(1);return
	# Separate attribution run only; default measurements use the product worker.
	if config.get("decode_probe",false):
		var control = view.scene_layers.mesh_playback
		control.worker.close();control.worker = DecodeProbe.new();control.invalidate()
		if control.worker.start() != OK:push_error("Cannot start decode probe");view.free();quit(1);return
	var id: String = view.scene_layers.states.keys()[0]
	var observer := Observer.new();observer.view = view;observer.id = id;observer.process_priority = 100
	root.add_child(observer);RenderingServer.frame_post_draw.connect(observer.draw)
	var report := {"config":config,"version":ProjectSettings.get_setting("application/config/version"),
		"godot":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),
		"device":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"memory":Memory.memory_headroom(),
		"source_samples":view.generic_reader.samples[id].size(),"first":view.generic_reader.frames[0].time,
		"last":view.generic_reader.frames[-1].time,"initial_state":view.scene_layers.states[id].duplicate(true),"cases":[]}
	report.camera = {"active":str(root.get_camera_3d().get_path()),"observed":str(view.camera.get_path()),
		"distance":view.camera_distance,"current_scene":str(current_scene),"root_children":str(root.get_children())}
	for case in config.cases:
		view.playing = false;view.physical_rate = float(case.get("rate",1));view.scene_loop_playback = false
		if case.has("channel"):view.scene_layers.states[id].channel = case.channel
		root.mode = Window.MODE_FULLSCREEN if case.get("fullscreen",false) else Window.MODE_WINDOWED
		var start: float = case.get("start",0)
		view.scene_layers.seek(start)
		var began := Time.get_ticks_usec()
		while view.scene_layers.is_buffering() and Time.get_ticks_usec()-began < 30000000:await process_frame
		if view.scene_layers.is_buffering():push_error("Seek did not settle");view.free();observer.free();quit(1);return
		await create_timer(float(case.get("warmup",3)),true,false,true).timeout
		var before: Dictionary = view.scene_layers.mesh_playback.profile_report()
		if case.has("channel") and not view.scene_layers.current[id].a.channels.has(case.channel):
			push_error("Unknown scalar channel");view.free();observer.free();quit(1);return
		view.display_accum = 0
		observer.rows.clear();observer.draws.clear();observer.start_us = Time.get_ticks_usec()
		Profile.reset();Profile.enabled = bool(config.get("profile",true))
		view.measuring = true;view._toggle_playback()
		await create_timer(float(case.seconds),true,false,true).timeout
		var wall_s := (Time.get_ticks_usec()-observer.start_us)/1000000.0
		view.measuring = false;view.playing = false;Profile.enabled = false
		var result := {"case":case,"wall_s":wall_s,"before":before,"after":view.scene_layers.mesh_playback.profile_report(),
			"profile":Profile.report(),"rows":observer.rows.duplicate(),"draws":observer.draws.duplicate(),
			"errors":[view.scene_layers.error,view.scene_layers.mesh_playback.error],"root_size":[root.size.x,root.size.y],
			"physical_rate":view.physical_rate,"max_fps":Engine.max_fps,"time_scale":Engine.time_scale,
			"memory_after":Memory.memory_headroom()}
		report.cases.append(result)
		Job.write_json(config.output,report)
		print("TRANSPORT CASE ",case.name," wall=",wall_s," committed=",view.committed_sample.requested_time)
		if config.get("screenshots",false) and DisplayServer.get_name() != "headless":
			await process_frame
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(config.output.get_base_dir().path_join(case.name+".png"))
	RenderingServer.frame_post_draw.disconnect(observer.draw)
	view.free();observer.free();await process_frame;quit()
