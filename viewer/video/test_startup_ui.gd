extends SceneTree
const Job = preload("res://video/render_job.gd")
var view
var out := ""
var config: Dictionary
var began := 0
var last_tick := 0
var max_gap := 0
var ticks := 0
var first_frame_ms := -1
var worker_ready_ms := -1
var cancel_ms := -1
var launch_return_ms := -1
func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	if began > 0:
		var now := Time.get_ticks_msec()
		max_gap = maxi(max_gap,now-last_tick);last_tick = now;ticks += 1
	return false
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	config = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
	view = load("res://main.gd").new();view.capture_path = config.source
	# Use the production viewer/dialog/child launch. Isolate export from unrelated
	# full-timeline interactive prefetch unless the scenario requests it explicitly.
	view.scene_prebuffer_enabled = config.get("interactive_preparation",false)
	view.playing = false;view.orbit_enabled = false
	root.add_child(view)
	await process_frame
	view.scene_layers.sample(config.get("start",20.0))
	view._apply_preset("Scientific")
	for id in view.scene_layers.states:
		if view.generic_reader.objects[id].kind == "volume":view.scene_layers.states[id].channel = config.get("channel","psi_imag")
	view.scene_layers.resample()
	var menu: Dictionary = view.shell.commands.video;menu.popup.id_pressed.emit(menu.index)
	var dialog = view.video_dialog
	dialog.range_choice.select(2);dialog.update_range()
	dialog.start.value = config.get("start",20.0);dialog.end.value = config.get("end",25.0)
	dialog.width.value = config.get("width",2560);dialog.height.value = config.get("height",1440)
	dialog.fps.value = config.get("fps",60);dialog.rate.value = config.get("rate",.25)
	dialog.camera_mode.select(1);dialog.orbit.value = .08;dialog.overlays.button_pressed = false
	dialog.inspection_sidecars.button_pressed = config.get("sidecars",false)
	dialog.output.text = out.path_join("result.mp4")
	await process_frame
	began = Time.get_ticks_msec();last_tick = began
	Job.write_json(out.path_join("clicked.json"),{"ticks":began})
	dialog.start_button.pressed.emit()
	launch_return_ms = Time.get_ticks_msec()-began
	Job.write_json(out.path_join("launched.json"),{"milliseconds":launch_return_ms,"directory":dialog.active_directory,"pid":dialog.pid})
	while dialog.pid > 0 or dialog.preparing:
		var progress: Dictionary = dialog.last_progress
		if progress.get("stage","") in ["ready","rendering","encoding","complete"] and worker_ready_ms < 0:worker_ready_ms = Time.get_ticks_msec()-began
		if progress.get("current_frame",0) > 0 and first_frame_ms < 0:first_frame_ms = Time.get_ticks_msec()-began
		if config.get("cancel_stage","") == progress.get("stage","missing") and cancel_ms < 0:
			cancel_ms = Time.get_ticks_msec();dialog.cancel_export()
		if config.get("stop_after_frames",0) > 0 and progress.get("current_frame",0) >= config.stop_after_frames and cancel_ms < 0:
			cancel_ms = Time.get_ticks_msec();dialog.cancel_export()
		await create_timer(.02).timeout
	var report := {"launch_return_ms":launch_return_ms,"first_frame_ms":first_frame_ms,"worker_ready_ms":worker_ready_ms,"max_ui_tick_gap_ms":max_gap,"ui_ticks":ticks,"cancel_to_exit_ms":Time.get_ticks_msec()-cancel_ms if cancel_ms >= 0 else -1,"directory":dialog.active_directory,"stage":dialog.last_progress.get("stage"),"progress":dialog.last_progress,"message":dialog.message.text}
	if config.get("sidecars",false) and report.stage == "complete":
		var record = JSON.parse_string(FileAccess.get_file_as_string(dialog.active_directory.path_join("inspection-00000000.json")))
		report.restore_error = preload("res://scene/inspection_state.gd").restore(view,record)
	Job.write_json(out.path_join("ui-report.json"),report)
	print(JSON.stringify(report));view.free();await process_frame;quit()
