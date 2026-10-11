extends SceneTree
## Exercises the production open/status paths without controlling input devices.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var cases: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
func picture(name: String) -> void:
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Save " + name)
func icon_matches(ui, severity: String) -> bool:
	var expected = ui.shell.theme.icon_named("check" if severity == "success" else severity, StringName("state." + severity))
	return ui.badge.symbol.texture.get_image().get_data() == expected.get_image().get_data()
func failed(view, file: String, label: String) -> String:
	view._open_capture(output.path_join(file)); await settle()
	var shell = view.shell
	var ui = shell.status_ui
	ui.refresh()
	var problem: String = shell.error_details
	check(not problem.is_empty() and shell.open_error.visible, label + ": actionable open failure")
	check(ui.failures.get("Open file") == problem, label + ": failure belongs to open attempt")
	check(not ui.failures.has("Scene"), label + ": no duplicate Scene notice for the open diagnostic")
	check(ui.badge.label.text.contains("Failed") and icon_matches(ui, "error"), label + ": error text/icon remain current")
	ui.show_status()
	check(shell.detail_text.text.contains(problem) and shell.detail_failure_action.visible, label + ": details/acknowledgement available")
	shell.details.hide()
	cases.append({"case":label,"problem":problem,"failures":ui.failures.duplicate(),"badge":ui.badge.label.text})
	return problem
func recovered(view, file: String, problem: String, label: String) -> void:
	view._open_capture(output.path_join(file)); await settle()
	var shell = view.shell
	var ui = shell.status_ui
	ui.refresh()
	check(view.capture_path == output.path_join(file) and not view.committed_sample.is_empty(), label + ": replacement has a committed sample")
	check(not view.playing and view.requested_time == view.generic_reader.frames[0].time, label + ": normal paused-first-sample contract")
	check(not shell.open_error.visible and shell.error_details.is_empty(), label + ": no stale banner/details")
	check(ui.failures.is_empty() and ui.badge.label.text == "Ready", label + ": Ready without retained failure")
	check(icon_matches(ui, "success"), label + ": successful icon replaces red/error icon")
	ui.show_status()
	check(not shell.detail_text.text.contains(problem) and not shell.detail_failure_action.visible, label + ": fresh status details omit stale failure/affordance")
	shell.details.hide()
	for i in 3: ui.refresh()
	check(ui.failures.is_empty(), label + ": repeated refresh does not resurrect failure")
	cases.append({"case":label,"failures":ui.failures.duplicate(),"badge":ui.badge.label.text})
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--load-output="): output = arg.trim_prefix("--load-output=")
	if output.is_empty(): quit(1); return
	create_timer(75).timeout.connect(func(): push_error("Load recovery timed out"); quit(1))
	OS.low_processor_usage_mode = false
	for layout in [{"name":"normal","size":Vector2i(1440,900)}, {"name":"compact","size":Vector2i(1024,640)}]:
		root.size = layout.size
		var view = Viewer.new(); root.add_child(view); view.set_process(false)
		# Keep the tiny fixture deterministic; no unrelated worker/export matrix.
		view.scene_prebuffer_enabled = false; view.orbit_enabled = false
		await settle()
		var shell = view.shell
		var ui = shell.status_ui
		var prefix: String = layout.name + "-"
		var problem: String = await failed(view, "invalid.wvz", prefix + "empty-prefix-failure")
		picture(prefix + "failed-empty")
		await recovered(view, "scene.wvz", problem, prefix + "empty-recovered")
		picture(prefix + "recovered-empty")

		view._seek_frame(1); await settle()
		var reader = view.generic_reader
		var layers = view.scene_layers
		var sample: Dictionary = view.committed_sample.duplicate(true)
		var camera_transform: Transform3D = view.camera.transform
		var world_transform: Transform3D = layers.transform
		var visual: Dictionary = Visual.snapshot(view)
		var cache_limit: int = reader.cache.limit
		problem = await failed(view, "invalid.wvz", prefix + "replacement-failure")
		check(view.generic_reader == reader and view.scene_layers == layers and view.committed_sample == sample, prefix + "failed header replacement retains reader/layers/committed sample")
		check(view.camera.transform == camera_transform and layers.transform == world_transform and Visual.snapshot(view) == visual, prefix + "failed header replacement retains camera/scene/legend presentation")
		check(reader.cache.limit == cache_limit and not layers.current.is_empty(), prefix + "failed header replacement keeps cache and usable layer data")
		view.status_label.text = "Unrelated information"; ui.refresh()
		check(ui.failures.get("Open file") == problem, prefix + "information does not acknowledge current failure")
		view._show_open_dialog(); view.open_dialog.canceled.emit(); view.open_dialog.hide()
		check(ui.failures.get("Open file") == problem and shell.open_error.visible, prefix + "picker cancellation retains failure")
		picture(prefix + "failed-replacement")
		await recovered(view, "replacement.wvz", problem, prefix + "replacement-recovered")
		picture(prefix + "recovered-replacement")

		for file in ["unsupported.txt", "invalid.wvz", "duplicate.wvz"]:
			problem = await failed(view, file, prefix + file)
			if file == "duplicate.wvz":
				check(problem.contains("duplicate particle ID"), prefix + "real initial-sample decode failure reproduced")
				picture(prefix + "failed-sample")
				ui.show_status(); await settle(); picture(prefix + "failed-sample-details"); shell.details.hide()
			await recovered(view, "scene.wvz", problem, prefix + file + "-recovered")
			if file == "duplicate.wvz":
				picture(prefix + "recovered-sample")
				ui.show_status(); await settle(); picture(prefix + "recovered-sample-details"); shell.details.hide()

		# Exercise error ownership independently of loader/workers. Exact-message
		# equality under another owner must not cause that owner's notice to vanish.
		problem = await failed(view, "duplicate.wvz", prefix + "failure-with-unrelated-owners")
		ui.remember("Analysis", problem)
		ui.remember("Video export", "Retained export failure")
		view.scene_layers.error = "Independent earlier scene diagnostic"; ui.refresh()
		var video = view.video_dialog
		var old_job: Dictionary = video.job_status.duplicate(true)
		video.job_status = {"stage":"starting","detail":"Unrelated video launch"}
		video.pid = preload("res://video/test_worker_process.gd").start(); ui.refresh()
		var active_count: int = ui.active_count
		var job: Dictionary = video.job_status.duplicate(true)
		view._open_capture(output.path_join("replacement.wvz")); await settle(); ui.refresh()
		check(not ui.failures.has("Open file") and shell.error_details.is_empty(), prefix + "only superseded open notice clears")
		check(ui.failures == {"Analysis":problem,"Video export":"Retained export failure","Scene":"Independent earlier scene diagnostic"}, prefix + "other owners retain diagnostics, including identical error text")
		check(ui.badge.label.text == "Ready   •   Failed — details" and icon_matches(ui, "error"), prefix + "unrelated failure still owns current error badge")
		check((video.pid > 0) and video.job_status == job and ui.active_count == active_count and ui.job_rows["Video export"].active, prefix + "published active job and Jobs count remain intact")
		ui.show_status()
		check(not shell.detail_text.text.contains("Open file — Failed") and shell.detail_text.text.contains("Independent earlier scene diagnostic") and shell.detail_failure_action.visible, prefix + "details retain only other owners")
		shell.details.hide(); preload("res://video/test_worker_process.gd").stop(video); video.job_status = old_job
		ui.acknowledge(); ui.refresh()
		check(ui.failures.is_empty() and icon_matches(ui, "success"), prefix + "existing acknowledgement still works")
		view.scene_layers.error = problem; ui.refresh()
		check(ui.failures.get("Scene") == problem and not ui.failures.has("Open file"), prefix + "same text outside a failed open remains an independent Scene error")
		view.scene_layers.error = ""; ui.refresh(); ui.acknowledge()
		view.session_log.file.flush()
		var log_text := FileAccess.get_file_as_string(view.session_log.path)
		check(log_text.contains("duplicate particle ID") and log_text.contains("result=failed") and log_text.contains("result=ready"), prefix + "history retains failures and successful opens")
		check(ui.get_global_rect().end.y <= root.size.y + 1 and ui.badge.get_global_rect().end.x <= root.size.x + 1, prefix + "status remains within window")
		view.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"cases":cases,"layouts":["1440x900","1024x640"]}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("Load recovery: ",checks," checks; failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
