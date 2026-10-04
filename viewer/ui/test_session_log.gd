extends SceneTree
const Viewer = preload("res://main.gd")
const SessionLog = preload("res://ui/session_log.gd")
var checks := 0
var failures: Array[String] = []
var output := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--session-log-output="): output = arg.trim_prefix("--session-log-output=")
	if output.is_empty(): quit(1); return
	var logs: Array[String] = []
	for kind in ["particles", "volume", "mixed"]:
		var viewer = Viewer.new()
		root.add_child(viewer)
		viewer.set_process(false)
		var source: String = output.path_join(kind + ".wvz")
		viewer._open_capture(source)
		check(viewer.generic_reader != null, kind + " capture opens")
		var log_path: String = viewer.session_log.path
		check(FileAccess.file_exists(log_path), kind + " session log created")
		if kind == "mixed": await exercise_mixed(viewer)
		viewer.queue_free()
		await process_frame
		var content := FileAccess.get_file_as_string(log_path)
		check(content.contains("filename=" + kind + ".wvz") and content.contains("path=" + source), kind + " full source identity logged")
		check(content.contains("Session ended"), kind + " clean exit logged")
		if kind == "mixed":
			for event in ["Tools → Selection opened", "Tools → Analysis → Bookmarks", "Source bound", "Bookmark saved", "Go to bookmark", "Seek:", "Selections: Requested scientific workspace exceeds its memory budget", "analysis_budget_mib=512", "last_seek_target=0.00000", "Selections cancellation requested", "Seek rejected", "Speed =", "Video export starting", "Simulation category = Fields", "Pointer tool = Orbit", "Close capture:"]:
				check(content.contains(event), "mixed event: " + event)
			check(content.count("CONTROL   Viewer → Colormap = turbo") == 1 and not content.contains("MENU      turbo"), "dropdown choice has one labeled control entry")
			check(not content.contains("Draft intermediate"), "uncommitted text is not logged")
			check(not content.contains("per-frame"), "no frame telemetry")
			check(content.split("\n").size() < 120, "mixed workflow remains concise")
			check(content.contains("minimal marker") and not content.contains("filtered verbose marker"), "Minimal policy filters verbose controls")
		logs.append(log_path)
	check(logs[0] != logs[1] and logs[1] != logs[2], "distinct session files")
	var cap_viewer = Viewer.new()
	root.add_child(cap_viewer)
	cap_viewer.set_process(false)
	var cap_logger = cap_viewer.session_log
	var disabled = SessionLog.new()
	disabled.level = SessionLog.DISABLED
	cap_viewer.add_child(disabled)
	disabled.start(cap_viewer)
	check(disabled.file == null and disabled.path.is_empty(), "Disabled policy creates no action log")
	for i in 600: cap_logger.record("CONTROL", "x".repeat(4096))
	check(cap_logger.file == null, "session cap stops further writes")
	var cap_path: String = cap_logger.path
	var cap_bytes: int = SessionLog.MAX_SESSION_BYTES
	cap_viewer.queue_free()
	await process_frame
	var capped := FileAccess.open(cap_path, FileAccess.READ)
	check(capped != null and capped.get_length() <= cap_bytes, "session file stays within 2 MiB")
	if capped != null: capped.close()
	var report := {"checks":checks, "failures":failures, "logs":logs, "capped_log":cap_path}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ")); file.close()
	print("SESSION LOG: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func exercise_mixed(viewer) -> void:
	var logger = viewer.session_log
	var colormap := OptionButton.new()
	colormap.name = "Colormap"
	colormap.add_item("turbo")
	viewer.add_child(colormap)
	logger._observe_tree(colormap)
	colormap.get_popup().id_pressed.emit(0)
	colormap.item_selected.emit(0)
	colormap.queue_free()
	viewer.shell.tab_buttons[1].pressed.emit()
	viewer.shell.tab_buttons[0].pressed.emit()
	viewer.tools_ui.open("Selection")
	viewer.selection_controller.bind_source()
	var jobs = viewer.selection_controller.jobs
	var began := Time.get_ticks_msec()
	while jobs.pending and Time.get_ticks_msec() - began < 10000: await process_frame
	check(not jobs.pending and viewer.selection_controller.source.has("sha256"), "Selection source bound by worker")
	viewer.selection_controller.tool.item_selected.emit(0)
	var diagnostic = viewer.selection_controller.temporal.diagnostics
	var bookmark_command: Dictionary = viewer.shell.commands["tool:Bookmarks"]
	bookmark_command.popup.id_pressed.emit(bookmark_command.index)
	diagnostic.label_input.text = "Draft intermediate"
	diagnostic.label_input.text = "Logging check"
	diagnostic.label_input.text_submitted.emit(diagnostic.label_input.text)
	diagnostic.bookmark()
	check(diagnostic.bookmarks.size() == 1, "bookmark saved")
	diagnostic.bookmark_list.select(0)
	viewer._seek_time(1.0)
	diagnostic.seek_bookmark()
	viewer.shell.transport.rate.item_selected.emit(2)
	viewer.shell.transport.open_seek()
	viewer.shell.transport.seek_dialog.editor.text = "NaN"
	viewer.shell.transport.submit_seek()
	viewer.shell.transport.seek_dialog.hide()
	viewer.shell.status_ui.remember("Selections", "Requested scientific workspace exceeds its memory budget")
	viewer.video_dialog.publish_job("starting", "Synthetic export stage")
	viewer.video_dialog.publish_job("cancelled", "Synthetic cancellation")
	var token: String = jobs.request(viewer.selection_controller.source, "describe", {}, viewer.capture_generation, viewer.selection_controller.state.revision)
	check(not token.is_empty(), "analysis request started")
	jobs.cancel()
	logger.level = logger.MINIMAL
	logger.record("CONTROL", "filtered verbose marker")
	logger.record("JOB", "minimal marker", true)
	logger.level = logger.VERBOSE
	await process_frame
