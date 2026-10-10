extends SceneTree
# Runs the production menu/dialog/Jobs/worker routes in both source and a baked
# release test entry. Child invocations always dispatch through Main.tscn.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
var view
var out := ""
var checks: Array = []
var config: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: push_error(label)
func wait_analysis(control) -> bool:
	var deadline := Time.get_ticks_msec()+30000
	while control.jobs.busy() and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	return not control.jobs.busy() and control.jobs.error.is_empty()
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	config = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
	create_timer(80).timeout.connect(func(): push_error("Packaged export test timed out");quit(1))
	view = Viewer.new();view.capture_path = config.source;view.scene_prebuffer_enabled = false
	view.playing = false;view.orbit_enabled = false;root.add_child(view)
	await process_frame
	check(view.frame_a != null,"Production viewer opens WVZ1")
	check(OS.has_feature("editor") != config.packaged,"Expected source or template executable")
	if config.packaged:check(OS.has_feature("release"),"Release template, with path overrides disabled")
	view.scene_layers.sample(.75);view._apply_preset("Scientific")
	view.color_channel = "color_value";view.show_legend = true;view._restyle()
	for id in view.scene_layers.states:
		if view.generic_reader.objects[id].kind == "volume":
			view.scene_layers.states[id].channel = "psi_imag"
			view.scene_layers.legend_visibility[id] = true
	view.scene_layers.resample()
	if config.get("selection",false):
		var control = view.selection_controller
		control.bind_source();check(await wait_analysis(control),"Analysis binds without repository files")
		control._request("define_selection",{"key":"one","object":"p","kind":"particle_ids","selector":{"ids":["10"]}})
		check(await wait_analysis(control) and control.state.definitions.size() == 1,"Exact persistent-ID selection is available")
		check(not config.packaged or control.jobs.directory.begins_with(ProjectSettings.globalize_path("user://")),"Packaged analysis cache uses writable user data")
	var menu: Dictionary = view.shell.commands.video;menu.popup.id_pressed.emit(menu.index)
	var dialog = view.video_dialog
	check(dialog.visible,"File / Export / Video opens production dialog")
	dialog.range_choice.select(2);dialog.update_range();dialog.set_range_times(.75,1.25)
	dialog.width.value = 320;dialog.height.value = 180;dialog.fps.value = 4;dialog.rate.value = 1
	dialog.overlays.button_pressed = config.get("overlays",false);dialog.inspection_sidecars.button_pressed = true
	dialog.camera_mode.select(1 if config.get("orbit",false) else 0);dialog.orbit.value = .2
	dialog.output.text = out.path_join("result.mp4")
	view.file_locations.settings.ffmpeg_mode = "custom"
	view.file_locations.settings.ffmpeg_path = config.get("ffmpeg","/usr/bin/ffmpeg")
	if config.get("cancel","") in ["rendering","shutdown"]:dialog.set_range_times(dialog.start.timestamp,2);dialog.fps.value = 60;dialog.width.value = 960;dialog.height.value = 540
	if config.get("cancel","") == "encoding":dialog.fps.value = 60
	await process_frame
	var arguments := Job.launch_arguments(out.path_join("job.json"),4)
	check(arguments.has("--path") == OS.has_feature("editor"),"Only development passes a project path override")
	if config.get("startup_failure",false):
		Job.write_json(out.path_join("ready-to-launch.json"),{"executable":OS.get_executable_path()})
		while not FileAccess.file_exists(out.path_join("continue")):await create_timer(.01).timeout
	dialog.start_button.pressed.emit()
	var deadline := Time.get_ticks_msec()+30000
	while dialog.preparing and Time.get_ticks_msec()<deadline:await create_timer(.01).timeout
	if config.get("missing",false):
		check(dialog.pid <= 0 and dialog.active_directory.is_empty() and dialog.message.text.contains("FFmpeg"),"Missing FFmpeg refuses before worker launch")
		finish(dialog);return
	check(dialog.pid > 0,"Start Export launches secondary process")
	if dialog.pid <= 0:finish(dialog);return
	var pid: int = dialog.pid
	var directory: String = dialog.active_directory
	Job.write_json(out.path_join("launched.json"),{"pid":pid,"directory":directory})
	var launch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("launch.json")))
	check(launch.executable == OS.get_executable_path() and launch.packaged == config.packaged,"Launch diagnostics identify the current executable")
	check(launch.arguments.has("--path") != config.packaged and launch.rendering_method == RenderingServer.get_current_rendering_method(),"Correct launch arguments and renderer are retained")
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dialog.active_job_path))
	check(job.capture_path == config.source and job.capture_path.is_absolute_path() and job.output_path.is_absolute_path(),"Absolute source/job/output paths survive launch")
	check(job.version == (2 if config.get("selection",false) else 1),"Requested selection-aware job schema survives launch")
	dialog.background_button.pressed.emit()
	check(not dialog.visible and dialog.pid == pid and not FileAccess.file_exists(directory.path_join("cancel")),"Run in background retains the original worker")
	view.shell.status_ui.open_jobs();view.shell.status_ui.job_rows["Video export"].open.pressed.emit()
	check(dialog.visible and dialog.pid == pid,"Jobs reopens the same export")
	view.shell.status_ui.jobs_dialog.hide()
	var observed: Array = []
	var cancel_sent := false
	deadline = Time.get_ticks_msec()+50000
	while dialog.pid > 0 and Time.get_ticks_msec()<deadline:
		var stage: String = dialog.last_progress.get("stage","")
		if not stage.is_empty() and stage not in observed:observed.append(stage)
		if config.get("cancel","") == "shutdown" and stage == "rendering":
			Job.write_json(out.path_join("report.json"),{"checks":checks,"directory":directory,"pid":pid,"parent_shutdown":true,"observed":observed})
			# Confirmed exit uses the accepted close gate, then normal _exit_tree.
			view.shell.window_chrome.request_close();await process_frame;await process_frame
			view.shell.window_chrome.exit_confirmation.exit_button.pressed.emit();return
		if not cancel_sent and stage == config.get("cancel","none"):
			view.shell.status_ui.open_jobs();view.shell.status_ui.job_rows["Video export"].cancel.pressed.emit()
			check(dialog.cancel_confirmation.visible,"Jobs cancellation uses the accepted confirmation")
			dialog.cancel_confirmation.confirmed.emit();cancel_sent = true
		await create_timer(.01).timeout
	check(dialog.pid <= 0,"Worker terminates within timeout")
	if not config.get("startup_failure",false):check(not dialog.last_progress.is_empty(),"Parent observes worker progress")
	check(dialog.job_status.stage == config.get("expected","complete"),"Expected terminal state")
	check(not config.has("cancel") or cancel_sent,"Requested cancellation stage was observed")
	if config.get("startup_failure",false):
		check(dialog.message.text.contains("stopped unexpectedly") and dialog.message.text.contains(directory),"Early worker failure exposes exit status and retained diagnostics path")
		check(FileAccess.file_exists(directory.path_join("job.json")) and FileAccess.file_exists(directory.path_join("launch.json")),"Early failure retains exact job and launch command")
		finish(dialog);return
	if config.get("expected","complete") == "complete":
		check(FileAccess.file_exists(dialog.output.text),"MP4 is published")
		check(not DirAccess.dir_exists_absolute(directory.path_join("frames")),"Successful export cleans staged PNGs")
	else:
		check(not FileAccess.file_exists(dialog.output.text),"Failed/cancelled export publishes no MP4")
		check(DirAccess.dir_exists_absolute(directory.path_join("frames")),"Failed/cancelled export retains completed frames")
	check(FileAccess.file_exists(directory.path_join("renderer.log")) and FileAccess.file_exists(directory.path_join("metrics.json")),"Worker diagnostics are retained")
	var metrics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("metrics.json")))
	check(metrics.runtime.executable == OS.get_executable_path() and metrics.runtime.packaged == config.packaged,"Child uses the same packaged or development executable")
	check(metrics.runtime.rendering_method == RenderingServer.get_current_rendering_method(),"Child renderer matches parent")
	check(not config.packaged or metrics.runtime.release,"Child uses release resources")
	Job.write_json(out.path_join("observed.json"),{"stages":observed,"worker_pid":pid})
	finish(dialog)
func finish(dialog) -> void:
	Job.write_json(out.path_join("report.json"),{"checks":checks,"directory":dialog.active_directory,"progress":dialog.last_progress,"message":dialog.message.text})
	var failed := checks.any(func(item):return not item.ok)
	view.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
