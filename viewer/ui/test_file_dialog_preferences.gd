extends SceneTree
const Viewer = preload("res://main.gd")
var output := ""
var phase := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func settle() -> void:
	for i in 8: await process_frame
func favorite_button(node: Node) -> Button:
	if node is Button and node.tooltip_text == "(Un)favorite current folder.": return node
	for child in node.get_children(true):
		var found := favorite_button(child)
		if found != null: return found
	return null
func overwrite_dialog(node: Node) -> ConfirmationDialog:
	for child in node.get_children(true):
		if child is ConfirmationDialog and not child is FileDialog and child.visible: return child
		var found := overwrite_dialog(child)
		if found != null: return found
	return null
func show_dialog(dialog: FileDialog, directory: String) -> void:
	dialog.current_dir = directory
	dialog.popup_centered_ratio(.7)
	await settle()
func select_path(dialog: FileDialog, path: String) -> void:
	await show_dialog(dialog, path.get_base_dir())
	dialog.current_file = path.get_file()
	dialog.get_ok_button().pressed.emit()
	await settle()
func cancel(dialog: FileDialog) -> void:
	dialog.get_cancel_button().pressed.emit()
	await settle()
func toggle_favorite(dialog: FileDialog, directory: String) -> void:
	await show_dialog(dialog, directory)
	var button := favorite_button(dialog)
	check(button != null, "Built-in Favorite control exists")
	if button != null: button.pressed.emit()
	await cancel(dialog)
func directory(name: String) -> String: return output.path_join(name) + "/"

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	if output.is_empty() or phase.is_empty(): quit(1); return
	create_timer(60).timeout.connect(func(): push_error("File dialog test timed out"); quit(1))
	if phase == "baseline":
		# Exercise unmodified Godot widgets to distinguish engine behavior from ours.
		FileDialog.set_recent_list([])
		for mode in [FileDialog.FILE_MODE_OPEN_FILE, FileDialog.FILE_MODE_SAVE_FILE]:
			var dialog := FileDialog.new()
			dialog.access = FileDialog.ACCESS_FILESYSTEM
			dialog.file_mode = mode
			root.add_child(dialog)
			var path := directory("capture") + "scene.ssc" if mode == FileDialog.FILE_MODE_OPEN_FILE else directory("export") + "baseline.mp4"
			await select_path(dialog, path)
			check(FileDialog.get_recent_list().has(path.get_base_dir()+"/"), "Unmodified Godot records Recent in mode " + str(mode))
			dialog.free()
		finish(); return
	var viewer = Viewer.new()
	viewer.scene_prebuffer_enabled = false
	root.add_child(viewer)
	viewer.set_process(false)
	await settle()
	var capture: FileDialog = viewer.open_dialog
	var video: FileDialog = viewer.video_dialog.save_dialog
	check(capture.title == "Open capture" and not capture.mode_overrides_title, "Capture title")
	check(video.title == "Export video" and not video.mode_overrides_title, "Video title")
	check(not capture.use_native_dialog and not video.use_native_dialog, "Accepted built-in picker implementation retained")
	check(capture.filters == PackedStringArray(["*.ssc ; SimScope scene (SIMSCP4)"]), "Capture filter retained")
	check(video.filters == PackedStringArray(["*.mp4 ; H.264 MP4"]), "Export filter retained")
	check(video.overwrite_warning_enabled, "Overwrite confirmation retained")
	if phase == "capture_add":
		check(FileDialog.get_recent_list().is_empty() and FileDialog.get_favorite_list().is_empty(), "Fresh process starts without navigation history")
		await toggle_favorite(capture, directory("capture"))
		check(FileDialog.get_favorite_list().has(directory("capture")), "Capture Favorite added through built-in button")
		var saved := ConfigFile.new()
		check(saved.load("user://file_dialog_preferences.cfg") == OK and saved.get_value("navigation", "favorites") == FileDialog.get_favorite_list(), "Closing picker persists Favorites before application exit")
		await select_path(capture, directory("capture") + "scene.ssc")
		check(viewer._shell_open_error.is_empty() and viewer.capture_path.ends_with("scene.ssc"), "Representative capture opens")
		check(FileDialog.get_recent_list() == PackedStringArray([directory("capture")]), "Successful capture directory recorded")
		await show_dialog(capture, directory("capture"))
		if DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "forward_plus":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("capture-dialog.png"))
		await cancel(capture)
		var before := FileDialog.get_recent_list()
		await select_path(capture, directory("invalid") + "missing.ssc")
		check(capture.visible and FileDialog.get_recent_list() == before, "Missing file keeps picker usable without false history")
		await cancel(capture)
		await show_dialog(capture, directory("cancelled")); await cancel(capture)
		check(FileDialog.get_recent_list() == before, "Capture cancellation does not add Recent")
		await select_path(capture, directory("invalid") + "invalid.ssc")
		check(not viewer._shell_open_error.is_empty(), "Corrupt capture rejected")
		check(FileDialog.get_recent_list() == before, "Failed capture does not add or reorder Recent")
		viewer.inspection_busy = true
		await select_path(capture, directory("other") + "scene.ssc")
		check(viewer._shell_open_error.contains("busy") and FileDialog.get_recent_list() == before, "Busy open rejected without recording history")
		viewer.inspection_busy = false
		await select_path(capture, directory("other") + "scene.ssc")
		check(viewer._shell_open_error.is_empty() and not viewer.shell.open_error.visible, "Successful retry preserves error recovery")
		check(FileDialog.get_recent_list() == PackedStringArray([directory("other"), directory("capture")]), "Recent is most-recent-first")
		# A typed absolute filename can differ from the browser's current directory.
		await show_dialog(capture, directory("cancelled"))
		capture.get_line_edit().text = directory("capture") + "scene.ssc"
		capture.get_ok_button().pressed.emit(); await settle()
		check(FileDialog.get_recent_list() == PackedStringArray([directory("capture"), directory("other")]), "History uses actual selected directory and deduplicates")
	elif phase == "capture_remove":
		check(FileDialog.get_favorite_list().has(directory("capture")), "Capture Favorite survives process restart")
		check(FileDialog.get_recent_list() == PackedStringArray([directory("capture"), directory("other")]), "Capture Recent survives process restart")
		await toggle_favorite(capture, directory("capture"))
		check(FileDialog.get_favorite_list().is_empty(), "Capture Favorite removal")
	elif phase == "export_add":
		check(FileDialog.get_favorite_list().is_empty(), "Capture Favorite removal survives restart")
		await toggle_favorite(video, directory("export"))
		check(FileDialog.get_favorite_list().has(directory("export")), "Export Favorite added through built-in button")
		await select_path(video, directory("export") + "result.mp4")
		check(viewer.video_dialog.output.text == directory("export") + "result.mp4", "Export destination selection retained")
		check(FileDialog.get_recent_list()[0] == directory("export"), "Godot export Recent retained")
		check(viewer.video_dialog.pid <= 0 and not FileAccess.file_exists(directory("export") + "result.mp4"), "Destination selection does not start export")
		var before := FileDialog.get_recent_list()
		await show_dialog(video, directory("cancelled")); await cancel(video)
		check(FileDialog.get_recent_list() == before, "Export cancellation leaves Recent unchanged")
		await select_path(video, directory("cancelled") + "existing.mp4")
		var overwrite := overwrite_dialog(video)
		check(overwrite != null and FileDialog.get_recent_list() == before, "Existing destination awaits overwrite confirmation without history")
		if overwrite != null: overwrite.get_cancel_button().pressed.emit()
		await cancel(video)
		check(viewer.video_dialog.output.text.ends_with("result.mp4") and FileDialog.get_recent_list() == before, "Cancelling overwrite preserves destination and Recent")
		await show_dialog(video, directory("export"))
		if DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "forward_plus":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("export-dialog.png"))
		await cancel(video)
	elif phase == "export_remove":
		check(FileDialog.get_favorite_list().has(directory("export")), "Export Favorite survives process restart")
		check(FileDialog.get_recent_list()[0] == directory("export"), "Export Recent survives process restart")
		await toggle_favorite(video, directory("export"))
		check(FileDialog.get_favorite_list().is_empty(), "Export Favorite removal")
	elif phase == "stale":
		check(FileDialog.get_favorite_list().is_empty(), "Export Favorite removal survives restart")
		for dialog in [capture, video]:
			var missing := directory("deleted")
			FileDialog.set_favorite_list([missing, directory("capture")])
			FileDialog.set_recent_list([missing, directory("export")])
			await show_dialog(dialog, directory("capture"))
			check(not FileDialog.get_favorite_list().has(missing), "Missing Favorite pruned by Godot: " + dialog.title)
			check(not FileDialog.get_recent_list().has(missing), "Missing Recent pruned by Godot: " + dialog.title)
			check(dialog.visible, "Dialog remains usable with missing directories: " + dialog.title)
			await cancel(dialog)
	elif phase == "stale_reload":
		check(FileDialog.get_favorite_list() == PackedStringArray([directory("capture")]), "Pruned Favorites persist")
		check(FileDialog.get_recent_list() == PackedStringArray([directory("export")]), "Pruned Recent persists")
	# An export renderer must not read/write the interactive user's preferences.
	var config_path := ProjectSettings.globalize_path("user://file_dialog_preferences.cfg")
	viewer.free()
	await settle()
	var before_offline := FileAccess.get_file_as_bytes(config_path)
	var offline = Viewer.new(); offline.offline_instance = true; root.add_child(offline)
	check(offline.file_dialog_preferences == null, "Offline viewer has no preferences service")
	offline.free()
	await settle()
	check(FileAccess.get_file_as_bytes(config_path) == before_offline, "Offline teardown does not write preferences")
	finish()

func finish() -> void:
	var report := {"phase": phase, "checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "display": DisplayServer.get_name()}
	var file := FileAccess.open(output.path_join(phase + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("File dialogs ", phase, ": ", checks, " checks; failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
