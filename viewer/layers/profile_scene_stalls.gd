extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Job = preload("res://video/render_job.gd")

# Test driver: retain the actual viewer callback and its delta unchanged.
class ObservedViewer extends "res://main.gd":
	var measuring := false
	var callback_rows: Array = []
	func _process(delta: float) -> void:
		if not measuring:
			super(delta);return
		var start := Time.get_ticks_usec()
		var before_index := current_index
		var before_time := requested_time
		var before_pair: String = scene_layers.particle_key
		var before_poll := tail_poll
		var before_generation: int = generic_reader.generation
		super(delta)
		var finish := Time.get_ticks_usec()
		if callback_rows.size() < 20000:
			callback_rows.append({"wall_start_us":start,"duration_ms":(finish-start)/1000.0,"engine_delta":delta,"source_index_before":before_index,"source_index_after":current_index,"source_time_before":before_time,"source_time_after":requested_time,"particle_pair_before":before_pair,"particle_pair_after":scene_layers.particle_key,"tail_due":before_poll+delta>=1.0,"tail_accumulator_before":before_poll,"generation_before":before_generation,"generation_after":generic_reader.generation})

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stall-job="):path = arg.trim_prefix("--stall-job=")
	var job = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not job is Dictionary or DisplayServer.get_name()=="headless":push_error("Stall profile requires a job and real renderer.");quit(1);return
	create_timer(180,true,false,true).timeout.connect(func():push_error("Stall profile watchdog");quit(1))
	var view := ObservedViewer.new()
	view.capture_path = job.capture;view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false)
	if view.scene_layers == null or view.frame_a == null:push_error("Native capture did not open: "+view.status_label.text);quit(1);return
	view._set_clean(true);view.particle_layer_visible = false;view.trails_enabled = false
	for id in view.scene_layers.states:
		view.scene_layers.states[id].visible = false
		if view.scene_layers.states[id].has("isosurface"):view.scene_layers.states[id].isosurface = false
	view.scene_layers.cancel_iso()
	for key in view.guide_visibility:view.guide_visibility[key] = false
	view._apply_geometry()
	var result := {"capture":job.capture,"format":view.generic_reader.format,"backend":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"source_frames":view.frame_count,"source_size":view.generic_reader.file.get_length(),"source_stamp":view.generic_reader.source_stamp,"hidden_scientific_rendering":true,"cases":[]}
	for config in job.cases:
		view.inspection_paused = false;view.playing = false
		view.physical_rate = float(config.get("rate",1))
		view.scene_layers.sample(float(config.get("start_time",16)))
		if view.overlay_visible != config.get("inspector",true):view._toggle_overlay()
		for i in range(8):await process_frame
		view.tail_poll = float(config.get("tail_phase",0));view.display_accum = 0
		Profile.enabled = true;Profile.reset();Profile.trace_enabled = job.get("trace",false);view.callback_rows.clear()
		var started := Time.get_ticks_usec();view.measuring = true
		view.playing = config.get("playing",true);view.set_process(true)
		await create_timer(float(config.get("seconds",8)),true,false,true).timeout
		view.measuring = false;view.set_process(false);view.playing = false
		var stopped := Time.get_ticks_usec()
		var report := Profile.report();Profile.enabled = false
		report.config = config;report.wall_start_us = started;report.wall_end_us = stopped;report.callbacks = view.callback_rows.duplicate(true)
		result.cases.append(report)
		Job.write_json(job.output,result)
		print("STALL PROFILE ",config.name," callbacks=",report.callbacks.size()," ",report.stages.get("process_inclusive",{}))
	view.free();quit()
