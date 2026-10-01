extends SceneTree
## Uses the real interactive callbacks; no manual tick or forced draw in measurements.
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")
const Hash = preload("res://data/capture_index.gd")
const Grid = preload("res://layers/grid_view.gd")
var view
var output := ""
var hold := 60.0
var report := {"phases":{},"checks":0,"failures":[],"scientific":[]}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	report.checks += 1
	if not ok:report.failures.append(message);push_error(message)
func ready() -> bool:
	if view.scene_layers.is_buffering():return false
	var control = view.scene_layers.field_playback
	return not control.active() or control.worker.status().session.get("state") == "ready"
func picture() -> String:
	return Hash.digest(root.get_texture().get_image().get_data())
func measure(label: String, seconds: float, until_ready := false, full_playback := false) -> void:
	print("PHASE ",label)
	if label == "paused_ready":root.get_texture().get_image().save_png(output.get_base_dir().path_join("paused-ready.png"))
	Profile.reset()
	var started := Time.get_ticks_usec();var frames := Engine.get_frames_drawn();var callbacks := Engine.get_process_frames()
	var next := started;var rows := [];var seen := {};var max_staged := 0;var field_waits := 0;var particle_waits := 0
	var previous_field := false;var previous_particle := false
	var before := picture() if not until_ready and not view.playing else ""
	var initial: Dictionary = view.committed_sample.duplicate(true)
	var camera: Transform3D = view.camera.transform
	while Time.get_ticks_usec()-started < seconds*1000000:
		await process_frame
		var now := Time.get_ticks_usec();var layers = view.scene_layers;var control = layers.field_playback
		max_staged = maxi(max_staged,control.staged.size())
		if control.buffering and not previous_field:field_waits += 1
		if layers.playback.buffering and not previous_particle:particle_waits += 1
		previous_field = control.buffering;previous_particle = layers.playback.buffering
		if layers.views.has("field"):seen[str(layers.views.field.data.get("source_index",-1))] = true
		if now >= next:
			var state: Dictionary = control.worker.status()
			rows.append({"seconds":(now-started)/1000000.0,"draws":Engine.get_frames_drawn()-frames,"callbacks":Engine.get_process_frames()-callbacks,"time":view.committed_sample.get("requested_time"),"session_state":state.session.get("state"),"active_jobs":state.active_jobs,"completed":state.completed,"ready":state.session.get("ready",0),"total":state.session.get("total",0),"cache_bytes":state.bytes,"cache_limit":state.limit,"staged":control.staged.size(),"low_processor":OS.low_processor_usage_mode,"max_fps":Engine.max_fps})
			next = now+1000000
		if until_ready and ready():break
		if full_playback and float(view.committed_sample.get("requested_time",-INF)) >= view.generic_reader.frames[-1].time:break
	var wall := (Time.get_ticks_usec()-started)/1000000.0
	var result := {"wall_seconds":wall,"draws":Engine.get_frames_drawn()-frames,"fps":(Engine.get_frames_drawn()-frames)/wall,"callbacks_per_second":(Engine.get_process_frames()-callbacks)/wall,"profile":Profile.report(),"timeline":rows,"field_waits":field_waits,"particle_waits":particle_waits,"max_staged":max_staged,"observed_field_samples":seen.size(),"committed":view.committed_sample.duplicate(true),"image_before":before}
	if not before.is_empty():
		result.image_after = picture();result.identical_pixels = before == result.image_after
		result.unchanged_sample = initial == view.committed_sample;result.unchanged_camera = camera == view.camera.transform
	if until_ready:check(ready(),label+" reaches preparation readiness")
	if full_playback:check(float(view.committed_sample.get("requested_time",-INF)) >= view.generic_reader.frames[-1].time,"Full playback reaches committed endpoint")
	check(view.scene_layers.error.is_empty() and view.scene_layers.field_playback.error.is_empty(),label+" no scene/field error")
	check(max_staged <= 1,label+" bounded GPU staging")
	report.phases[label] = result
	Job.write_json(output,report)
	print("RESULT ",label," wall=",wall," fps=",result.fps," field_waits=",field_waits," particle_waits=",particle_waits)
func settle() -> void:
	await create_timer(2).timeout
func capture_scientific(label: String) -> void:
	for id in view.scene_layers.views:
		var field = view.scene_layers.views[id]
		if not field is Grid:continue
		var data: Dictionary = field.data;var hashes := {}
		for name in data.get("channels",{}):hashes[name] = Hash.digest(data.channels[name].to_byte_array())
		report.scientific.append({"phase":label,"object":id,"index":data.get("source_index"),"time":data.get("time"),"channel":field.channel,"lod":field.lod,"hashes":hashes})
		check(field.lod == 1,label+" full resolution")
func run() -> void:
	var args := OS.get_cmdline_user_args();output = args[1];hold = float(args[2])
	var actions: bool = args[3] == "true";var full: bool = args[4] == "true"
	var orbit: bool = args[5] == "true";var owner_settings: bool = args[6] == "true"
	var zoom := float(args[7])
	Profile.enabled = true
	view = load("res://main.gd").new();view.capture_path = args[0];view.playing = false;view.orbit_enabled = orbit
	var opened := Time.get_ticks_usec();root.add_child(view)
	root.title = "WAVEZ #118 automated profile — " + output.get_base_dir().get_file()
	report.open_seconds = (Time.get_ticks_usec()-opened)/1000000.0
	if view.generic_reader == null:check(false,"Capture opens");Job.write_json(output,report);quit(1);return
	if owner_settings:
		view.hidden_types.clear();view._choose_color("color_value")
		view.colormap_name = "viridis";view._update_colormap();view._set_normalization("frame")
		view.scene_layers.states.field.channel = "psi_imag"
		view.scene_layers.states.field.opacity_mapping.mode = "magnitude"
		view.scene_layers.resample()
	view.camera_distance *= zoom;view._update_camera()
	report.settings = {"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"window":DisplayServer.window_get_size(),"viewport":root.size,"screen":DisplayServer.screen_get_size(),"refresh_hz":DisplayServer.screen_get_refresh_rate(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"sleep_usec":OS.low_processor_usage_mode_sleep_usec,"preset":view.selected_preset,"orbit":view.orbit_enabled}
	report.settings.merge({"yaw":view.yaw,"pitch":view.pitch,"camera_distance":view.camera_distance,"camera_target":view.camera_target,"particles":view.particle_count,"particle_color":view.color_channel,"point_rendering":view.clean_view,"fields":view.scene_layers.snapshot()})
	report.settings.particle_scalar_shader = view.particle_materials[0].get_shader_parameter("scalar_map")
	await measure("preparation",300,true)
	await settle();capture_scientific("ready")
	await measure("paused_ready",hold)
	if orbit:
		view.orbit_enabled = false;await settle();await measure("stationary_ready",hold)
		view.orbit_enabled = true;await settle()
	view.play_button.pressed.emit()
	check(view.playing,"Play button starts playback")
	await measure("playback",900 if full else 20,false,full)
	if view.playing:view.play_button.pressed.emit()
	await measure("pause_drain",300,true)
	await settle();await measure("paused_again",hold)
	if actions:
		var target: float = view.generic_reader.frames[-1].time*.6
		check(view.scene_layers.seek(target),"Paused distant seek accepted")
		await measure("seek_preparation",300,true);await settle();capture_scientific("seek")
		await measure("paused_seek",hold)
		if view.scene_layers.views.has("field"):
			var choice: OptionButton = view.scene_layers.panel_controls.field.channel
			for channel in ["psi_real","psi_imag","density"]:
				var found := false
				for i in choice.item_count:
					if choice.get_item_metadata(i) != channel:continue
					choice.select(i);choice.item_selected.emit(i);found = true;break
				if not found:continue
				await measure(channel+"_preparation",300,true);await settle();capture_scientific(channel)
				await measure("paused_"+channel,hold)
		view.orbit_enabled = true
		await measure("orbit",5)
		view.orbit_enabled = false
		await settle();await measure("after_orbit",hold)
	view.free();await process_frame
	report.complete = true
	Job.write_json(output,report)
	print("PAUSED RENDERING: ",report.checks," checks, ",report.failures.size()," failures")
	quit(0 if report.failures.is_empty() else 1)
