extends SceneTree
const Viewer = preload("res://ui/test_file_locations_viewer.gd")
const Locations = preload("res://ui/file_locations_preferences.gd")
var output := ""
var source := ""
var encoder := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func wait_screenshot(viewer, expected_count: int) -> void:
	for _frame in range(180):
		if viewer.screenshot_count >= expected_count and not viewer.screenshot_saving: return
		await process_frame

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--locations-output="): output = arg.trim_prefix("--locations-output=")
		if arg.begins_with("--locations-source="): source = arg.trim_prefix("--locations-source=")
		if arg.begins_with("--locations-ffmpeg="): encoder = arg.trim_prefix("--locations-ffmpeg=")
	if output.is_empty() or source.is_empty() or encoder.is_empty(): quit(1); return
	var viewer = Viewer.new(); root.add_child(viewer)
	await process_frame
	var locations = viewer.file_locations
	check(locations.snapshot() == Locations.defaults(), "fresh profile uses default modes and folders")
	check(not locations.ffmpeg_status().path.is_empty(), "PATH FFmpeg resolves in Auto-detect")
	viewer.shell.invoke_shortcut_command("file_locations")
	var dialog = viewer.shell.file_locations_dialog
	if dialog == null: check(false, "File Locations command is available without a capture"); quit(1); return
	check(dialog.visible and dialog.title.contains("File Locations"), "Preferences route opens File Locations")
	await process_frame
	dialog.ffmpeg_path.grab_focus(); await process_frame
	check(dialog.size.y >= 390, "File Locations has room for all rows and a notice")
	check(dialog.ffmpeg_path.get_global_rect().position.y >= dialog.content_scroll.get_global_rect().position.y + 4, "FFmpeg focus border is inset from the scroll edge")
	check(not dialog.content_scroll.get_v_scroll_bar().visible and dialog.fields.log_dir.get_global_rect().end.y <= dialog.content_scroll.get_global_rect().end.y, "all normal rows fit without a vertical scrollbar")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		dialog.get_texture().get_image().save_png(output.path_join("file-locations.png"))
	check(dialog.pickers.size() == 4 and dialog.pickers.ffmpeg.file_mode == FileDialog.FILE_MODE_OPEN_FILE, "FFmpeg Browse opens a file picker")
	for key in ["ffmpeg", "video_dir", "image_dir", "log_dir"]:
		check(dialog.pickers[key].use_native_dialog and dialog.pickers[key].access == FileDialog.ACCESS_FILESYSTEM, key + " uses native filesystem picker")
	for key in ["video_dir", "image_dir", "log_dir"]:
		check(dialog.pickers[key].file_mode == FileDialog.FILE_MODE_OPEN_DIR, key + " chooses a directory")
	check(viewer.shell.commands.has("keyboard_shortcuts"), "Keyboard Shortcuts command remains available")
	dialog.pickers.ffmpeg.file_selected.emit(encoder)
	check(dialog.draft.ffmpeg_mode == "custom" and dialog.draft.ffmpeg_path == encoder, "Browse stages custom FFmpeg")
	dialog.commit()
	check(locations.settings.ffmpeg_mode == "custom" and locations.ffmpeg_status().path == encoder, "custom FFmpeg is validated and active")
	locations.reload()
	check(locations.settings.ffmpeg_mode == "custom" and locations.ffmpeg_status().path == encoder, "custom FFmpeg survives settings reload and wins over PATH")
	var config := ConfigFile.new(); check(config.load(locations.storage_path) == OK, "one settings file is written")
	check(config.get_value("file_locations", "ffmpeg_mode") == "custom" and config.get_value("file_locations", "ffmpeg_path") == encoder, "custom mode and path persist")
	dialog.mode_choice.select(0); dialog.mode_choice.item_selected.emit(0); dialog.commit()
	check(locations.settings.ffmpeg_mode == "auto" and locations.settings.ffmpeg_path.is_empty(), "Auto-detect clears custom path")
	config.load(locations.storage_path)
	check(config.get_value("file_locations", "ffmpeg_mode") == "auto" and config.get_value("file_locations", "ffmpeg_path") == "", "discovered executable path is not persisted")
	var video_dir: String = output.path_join("Video exports Å")
	var image_dir: String = output.path_join("Image exports Å")
	var log_dir: String = output.path_join("Log files Å")
	for entry in [["video_dir",video_dir],["image_dir",image_dir],["log_dir",log_dir]]:
		dialog._selected_directory(entry[1], entry[0])
	dialog.commit()
	check(locations.settings.video_dir == video_dir and locations.settings.image_dir == image_dir and locations.settings.log_dir == log_dir, "three directories save together")
	check(DirAccess.dir_exists_absolute(video_dir) and DirAccess.dir_exists_absolute(image_dir) and DirAccess.dir_exists_absolute(log_dir), "selected directories are created")
	dialog.draft.video_dir = output.path_join("Unapplied")
	dialog.dismiss(); dialog.open()
	check(dialog.draft.video_dir == video_dir, "Cancel discards uncommitted edits")
	dialog.reset_button.pressed.emit()
	check(dialog.draft == Locations.defaults() and locations.settings.video_dir == video_dir, "Reset Defaults stages changes until Apply")
	dialog.dismiss()
	viewer.queue_free(); await process_frame
	RenderingServer.force_draw(false); await process_frame
	viewer = Viewer.new(); root.add_child(viewer); await process_frame
	locations = viewer.file_locations
	check(locations.settings.video_dir == video_dir and locations.settings.image_dir == image_dir and locations.settings.log_dir == log_dir, "directories survive viewer restart")
	check(viewer.session_log.path.get_base_dir() == log_dir and FileAccess.file_exists(viewer.session_log.path), "new session log uses chosen directory")
	viewer._open_capture(source)
	check(viewer.generic_reader != null, "small WVZ1 capture opens")
	viewer.video_dialog.open()
	var video = viewer.video_dialog
	check(video.output.text.get_base_dir() == video_dir and video.output.text.ends_with(".mp4"), "video uses preferred directory with a proposed filename")
	check(video.save_dialog.use_native_dialog and video.save_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE, "per-export native save picker remains")
	check(not video.message.text.contains("FFmpeg found"), "available FFmpeg adds no success chatter")
	var explicit: String = output.path_join("manual destination.mp4")
	video.output.text = explicit; video.hide(); video.open()
	check(video.output.text == explicit, "explicit per-export output is retained")
	video.hide(); await process_frame
	viewer._dispatch_shortcut("save_image"); await wait_screenshot(viewer, 1)
	check(viewer.screenshot_count == 1 and not viewer.screenshot_pending and viewer.screenshot_dialog == null and viewer.screenshot_directory.is_empty(), "Save Image shortcut writes directly when an image default is configured")
	check(DirAccess.get_files_at(image_dir).size() == 1 and viewer.status_label.text.contains(image_dir), "default image directory receives the PNG without becoming a session-only choice")
	var moved_image_dir := image_dir + "-moved"
	check(DirAccess.rename_absolute(image_dir, moved_image_dir) == OK, "configured image folder can be made unavailable for the test")
	viewer._dispatch_shortcut("save_image"); await process_frame
	check(viewer.screenshot_count == 1 and not viewer.screenshot_pending and viewer.screenshot_directory.is_empty() and viewer.status_label.text.contains("Edit → Preferences → File Locations"), "unavailable image preference fails clearly without a picker or session fallback")
	var no_image_default: Dictionary = locations.snapshot(); no_image_default.image_dir = ""
	check(locations.save(no_image_default).is_empty(), "Image Exports preference can be cleared without changing other locations")
	viewer._dispatch_shortcut("save_image"); await process_frame
	check(viewer.screenshot_pending and viewer.screenshot_dialog.use_native_dialog and viewer.screenshot_count == 1, "unset image default opens the existing native folder picker")
	viewer.screenshot_dialog.canceled.emit(); viewer.screenshot_dialog.hide()
	check(not viewer.screenshot_pending and viewer.screenshot_directory.is_empty() and viewer.screenshot_count == 1, "cancelled folder choice writes nothing and remembers nothing")
	viewer._dispatch_shortcut("save_image"); await process_frame
	check(viewer.screenshot_pending and viewer.screenshot_dialog.visible, "next Save Image request opens the picker again after Cancel")
	var session_dir := output.path_join("Session images Å")
	DirAccess.make_dir_recursive_absolute(session_dir)
	viewer.screenshot_dialog.hide(); await viewer._screenshot_directory_selected(session_dir)
	check(viewer.screenshot_count == 2 and viewer.screenshot_directory == session_dir and DirAccess.get_files_at(session_dir).size() == 1, "selected image folder saves and becomes this session's destination")
	viewer._dispatch_shortcut("save_image"); await wait_screenshot(viewer, 3)
	check(viewer.screenshot_count == 3 and not viewer.screenshot_pending and not viewer.screenshot_dialog.visible and DirAccess.get_files_at(session_dir).size() == 2, "later Save Image shortcut reuses the session-only folder")
	config.load(locations.storage_path)
	check(config.get_value("file_locations", "image_dir") == "" and viewer.screenshot_directory == session_dir, "session-only image choice is not stored as a permanent preference")
	locations.settings.ffmpeg_mode = "custom"; locations.settings.ffmpeg_path = output.path_join("missing ffmpeg")
	video.start_export()
	check(video.pid <= 0 and video.active_directory.is_empty(), "missing FFmpeg starts no MP4 worker or temporary directory")
	check(video.message.text.contains("FFmpeg is required") and video.message.text.contains("Edit → Preferences → File Locations"), "missing FFmpeg gives actionable route")
	locations.settings.ffmpeg_mode = "auto"; locations.settings.ffmpeg_path = ""
	viewer.shell.invoke_shortcut_command("file_locations")
	var editor = viewer.shell.file_locations_dialog
	editor._selected_ffmpeg(output.path_join("missing ffmpeg"))
	editor.commit()
	check(editor.notice.visible and locations.settings.ffmpeg_mode == "auto", "invalid custom executable cannot replace saved Auto-detect mode")
	await process_frame
	check(not editor.content_scroll.get_v_scroll_bar().visible and editor.fields.log_dir.get_global_rect().end.y <= editor.content_scroll.get_global_rect().end.y, "error notice leaves every row visible without a vertical scrollbar")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		editor.get_texture().get_image().save_png(output.path_join("file-locations-error.png"))
	editor.dismiss()
	DirAccess.remove_absolute(video_dir)
	video.output.text = video_dir.path_join("result.mp4")
	video.start_export()
	check(video.pid <= 0 and video.message.text.contains("destination is unavailable"), "removed preferred video directory fails before rendering")
	viewer.shell.invoke_shortcut_command("file_locations")
	editor = viewer.shell.file_locations_dialog
	editor.reset_button.pressed.emit(); editor.commit()
	check(locations.snapshot() == Locations.defaults(), "Reset Defaults restores all original location behavior")
	editor.dismiss()
	var report := {"checks":checks, "failures":failures, "video_dir":video_dir, "image_dir":image_dir, "log_dir":log_dir}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ")); file.close()
	viewer.queue_free(); await process_frame
	RenderingServer.force_draw(false); await process_frame
	print("FILE LOCATIONS: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
