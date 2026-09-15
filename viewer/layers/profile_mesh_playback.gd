extends SceneTree
const Job = preload("res://video/render_job.gd")
const Profile = preload("res://scene/playback_profile.gd")
class ObservedViewer extends "res://main.gd":
	var measuring := false
	var observations: Array = []
	func _process(delta: float) -> void:
		var began := Time.get_ticks_usec()
		super._process(delta)
		if measuring:observations.append({"delta_ms":delta*1000,"callback_ms":(Time.get_ticks_usec()-began)/1000.0,"time":committed_sample.get("requested_time",requested_time),"index":current_index,"buffering":scene_layers.is_buffering()})
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mesh-profile-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--mesh-profile-job=")))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var view := ObservedViewer.new();view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false
	var began := Time.get_ticks_usec();root.add_child(view);view.set_process(false)
	var open_ms := (Time.get_ticks_usec()-began)/1000.0
	view._set_clean(true);view.overlay_visible = false;view.overlay_panel.visible = false;view.show_panel_button.visible = false
	view.resize_handle.visible = false;view.legend.visible = false;view.colorbar.visible = false;view.show_legend = false
	for id in view.guide_visibility:view.guide_visibility[id] = false
	view._apply_geometry();view._sync_visuals()
	view.generic_reader.configure_cache(int(job.cache_mib)*1048576,false)
	var id: String = view.scene_layers.states.keys()[0]
	var state: Dictionary = view.scene_layers.states[id]
	state.channel = "surface_cell_von_mises";state.lower = 0;state.upper = 109664.80083812455;state.wireframe = job.wireframe
	view.camera.near = .001;view.camera.far = 100;view.camera.fov = 42
	view.camera_target = Vector3(2,.5,.45);view.camera.position = view.camera_target+Vector3(3.5,-7,3.5)
	view.camera.look_at(view.camera_target,Vector3.BACK);view.camera_distance = view.camera.position.distance_to(view.camera_target)
	view.time_mode = "physical";view.physical_rate = job.rate;view.scene_loop_playback = true
	var target: float = .99 if job.rate < 0 else 0.0
	began = Time.get_ticks_usec()
	while Time.get_ticks_usec()-began < 30000000:
		var result: Dictionary = view.scene_layers.sample(target,true)
		if result.is_empty():push_error(view.scene_layers.error);quit(1);return
		if not result.has("pending"):break
		await process_frame
	var prebuffer_ms := (Time.get_ticks_usec()-began)/1000.0
	var controller = view.scene_layers.get("mesh_playback")
	# Fixed warm-up for both revisions; future meshes prepare without moving time.
	var warmup := Time.get_ticks_usec()
	while Time.get_ticks_usec()-warmup < 500000:
		if controller != null:controller.pump()
		await process_frame
	view.requested_time = target;view.display_accum = 0;view.tail_poll = 0;view.playing = true;view.measuring = true;view.set_process(true)
	Profile.enabled = true;Profile.reset();began = Time.get_ticks_usec()
	await create_timer(float(job.seconds),true,false,true).timeout
	var duration := (Time.get_ticks_usec()-began)/1000000.0
	view.measuring = false;view.playing = false;view.set_process(false);Profile.enabled = false
	var report := {"config":job,"open_ms":open_ms,"prebuffer_ms":prebuffer_ms,"duration_seconds":duration,"callbacks":view.observations,"profile":Profile.report(),"memory":{},"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"main_thread":OS.get_thread_caller_id(),"decoded_cache_bytes":view.generic_reader.cache.used,"mesh_gpu_bytes":view.scene_layers.views[id].gpu_bytes}
	if controller != null:report.mesh = controller.profile_report()
	var proc := FileAccess.open("/proc/self/status",FileAccess.READ)
	if proc != null:
		for line in proc.get_buffer(65536).get_string_from_utf8().split("\n"):
			if line.begins_with("VmRSS:") or line.begins_with("VmHWM:") or line.begins_with("VmSwap:"):
				var parts := line.split(" ",false);report.memory[parts[0].strip_edges().trim_suffix(":")] = int(parts[1])*1024
	Job.write_json(job.output,report)
	view.free();await process_frame;print("MESH PROFILE COMPLETE");quit()
