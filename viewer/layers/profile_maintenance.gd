extends SceneTree
const Job = preload("res://video/render_job.gd")
const Profile = preload("res://scene/playback_profile.gd")
class ObservedViewer extends "res://main.gd":
	var measuring := false
	var observations: Array = []
	func _process(delta: float) -> void:
		var began := Time.get_ticks_usec()
		super._process(delta)
		if measuring:
			var underflow: bool = scene_layers.is_buffering() if scene_layers.has_method("is_buffering") else scene_layers.playback.buffering
			observations.append({"delta_ms":delta*1000,"callback_ms":(Time.get_ticks_usec()-began)/1000.0,"time":committed_sample.get("requested_time",requested_time),"index":current_index,"buffering":underflow})
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--maintenance-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--maintenance-job=")))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var view := ObservedViewer.new();view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false
	var began := Time.get_ticks_usec();root.add_child(view);view.set_process(false)
	var open_ms := (Time.get_ticks_usec()-began)/1000.0
	view._set_clean(true);view.overlay_visible = false;view.overlay_panel.visible = false;view.show_panel_button.visible = false
	view.resize_handle.visible = false;view.legend.visible = false;view.colorbar.visible = false;view.show_legend = false
	for id in view.guide_visibility:view.guide_visibility[id] = false
	view.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR;view.environment.tonemap_exposure = 1
	view.trails_enabled = false;view.size_channel = "fixed";view.brightness_channel = "fixed"
	view._apply_geometry();view._sync_visuals()
	view.generic_reader.configure_cache(int(job.get("cache_mib",256))*1048576,false)
	if job.case == "02B":
		view.point_scale = .2;view.exposure = 1.6;view.brightness_scale = 1;view.gamma = 1
		view.camera_target = Vector3(1.6,0,.3);view.camera.position = Vector3(4.4,-4,3)
		view.camera.look_at(view.camera_target,Vector3(0,0,1))
		view.hidden_types = {1:true,2:true};view.color_channel = "speed";view.colormap_name = "viridis"
		view.normalization_mode = "manual";view.auto_range = false;view.logarithmic = false
		view.manual_min = 0;view.manual_max = 3.7581247442109573;view._update_colormap();view._restyle();view._sync_visuals()
	else:
		var state: Dictionary = view.scene_layers.states.field;state.lower = 0;state.upper = 1;state.opacity = 2;state.step = .05
		view.camera.near = .01;view.camera.far = 150;view.camera.fov = 45
		view.camera_target = Vector3(4,4,2.5);view.camera.position = view.camera_target+Vector3(10,-15,9)
		view.camera.look_at(view.camera_target,Vector3.BACK)
		view.scene_layers.sample(0.)
	view.camera_distance = view.camera.position.distance_to(view.camera_target)
	view.time_mode = "physical";view.physical_rate = 1;view.scene_loop_playback = true
	var controller = view.scene_layers.playback;controller.direction = 1
	controller.begin(0.,controller.window_pairs)
	began = Time.get_ticks_usec()
	while controller.buffering and Time.get_ticks_usec()-began<120000000:controller.pump();await process_frame
	var prebuffer_ms := (Time.get_ticks_usec()-began)/1000.0
	if controller.buffering:push_error("Startup did not complete");quit(1);return
	for i in range(8):await process_frame
	view.requested_time = 0.;view.display_accum = 0.;view.tail_poll = 0.;view.playing = true;view.measuring = true;view.set_process(true)
	Profile.enabled = true;Profile.reset();began = Time.get_ticks_usec()
	await create_timer(float(job.seconds),true,false,true).timeout
	var duration := (Time.get_ticks_usec()-began)/1000000.0
	view.measuring = false;view.playing = false;view.set_process(false);Profile.enabled = false
	var report := {"case":job.case,"cache_mib":job.get("cache_mib",256),"open_ms":open_ms,"prebuffer_ms":prebuffer_ms,"duration_seconds":duration,"callbacks":view.observations,"particle":controller.profile_report(),"profile":Profile.report(),"memory":{},"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name()}
	if view.scene_layers.get("field_playback") != null:report.field = view.scene_layers.field_playback.profile_report()
	var proc := FileAccess.open("/proc/self/status",FileAccess.READ)
	if proc != null:
		for line in proc.get_buffer(65536).get_string_from_utf8().split("\n"):
			if line.begins_with("VmRSS:") or line.begins_with("VmHWM:") or line.begins_with("VmSwap:"):
				var parts := line.split(" ",false);report.memory[parts[0].trim_suffix(":")] = int(parts[1])*1024
	Job.write_json(job.output,report)
	view.free();await process_frame;print("MAINTENANCE PROFILE COMPLETE: ",job.case);quit()
