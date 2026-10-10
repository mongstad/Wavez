extends Node
## #335 diagnostic probe. Workers skip this autoload; normal Main.tscn stays intact.
var output := ""
var mode := ""
var checks := 0
var failures: Array[String] = []
var snapshots: Array = []
var view

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wavez-render-job="): return
		if arg.begins_with("--signals-output="): output = arg.trim_prefix("--signals-output=")
		if arg.begins_with("--signals-mode="): mode = arg.trim_prefix("--signals-mode=")
	if not output.is_empty(): run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func settle() -> void:
	for i in 4: await get_tree().process_frame

func snapshot(label: String, popup: Popup) -> void:
	var counts := {}
	for signal_name in ["focus_entered", "tree_exited"]:
		counts[signal_name] = get_tree().root.get_signal_connection_list(signal_name).filter(func(connection): return connection.callable.get_object() == popup).size()
	var row := {"phase":label, "popup_class":popup.get_class(), "popup_id":popup.get_instance_id(), "visible":popup.visible, "embedded":popup.is_embedded(), "connections":counts}
	snapshots.append(row)
	print("WINDOW SIGNALS: ", JSON.stringify(row))

func popup_cycles(popup: Popup, cycles: int, label: String) -> void:
	for cycle in cycles:
		popup.popup_centered(Vector2i(300, 180)); await settle()
		check(popup.visible, label+": shown")
		snapshot(label+" shown %d" % cycle, popup)
		popup.hide(); await settle()
		check(not popup.visible, label+": hidden")
		snapshot(label+" hidden %d" % cycle, popup)

func export_video(index: int, close: bool) -> void:
	view._open_capture(output.path_join("mixed.wvz")); await settle()
	var video = view.video_dialog
	video.open(); video.range_choice.select(2); video.update_range(); video.set_range_times(0, 1)
	video.rate.value = 1; video.fps.value = 6; video.width.value = 256; video.height.value = 256
	video.overlays.button_pressed = false; video.output.text = output.path_join("video-%d.mp4" % index)
	video.start_export(); video.hide()
	check(video.pid > 0, "Production export starts")
	if video.pid <= 0: return
	var pid: int = video.pid
	if close:
		var reader = view.generic_reader
		var layer: WeakRef = weakref(view.scene_layers)
		var particle: WeakRef = weakref(view.scene_layers.playback.worker)
		var field: WeakRef = weakref(view.scene_layers.field_playback.worker)
		var mesh: WeakRef = weakref(view.scene_layers.mesh_playback.worker)
		# Exercise the actual Seek popover, then the registered File command.
		view.shell.transport.open_seek(); await settle()
		snapshot("seek shown %d" % index, view.shell.transport.seek_dialog)
		view.shell.refresh_commands()
		var entry: Dictionary = view.shell.commands.close_file
		entry.popup.id_pressed.emit(entry.index); await settle()
		snapshot("seek hidden by Close File %d" % index, view.shell.transport.seek_dialog)
		check(view.generic_reader == null and view.capture_path.is_empty() and view.shell.empty.is_visible_in_tree(), "Close File returns to empty Main scene")
		check(reader.file == null and reader.records.is_empty() and reader.cache.used == 0, "Reader handle/index/cache released")
		check(layer.get_ref() == null and particle.get_ref() == null and field.get_ref() == null and mesh.get_ref() == null, "Capture layer and preparation workers eligible for reclamation")
		check(view.current_buffer.is_empty() and view.current_mm.instance_count == 0, "Capture CPU/GPU particle allocations empty")
		check(video.pid == pid and not FileAccess.file_exists(video.active_directory.path_join("cancel")), "Close File retains background worker without cancelling")
	view.shell.status_ui.open_jobs(); await settle()
	if close:
		view.shell.status_ui.job_rows["Video export"].open.pressed.emit(); await settle()
		check(video.visible and video.pid == pid, "Jobs reopens active export")
		video.hide()
	view.shell.status_ui.jobs_dialog.hide(); await settle()
	if close:
		view._open_capture(output.path_join("fields.wvz")); await settle()
		check(view.capture_path.ends_with("fields.wvz") and video.pid == pid, "Different source opens while worker retains original job")
	var deadline := Time.get_ticks_msec()+120000
	while video.pid > 0 and Time.get_ticks_msec() < deadline: await get_tree().create_timer(.05).timeout
	check(video.pid <= 0 and video.job_status.get("stage") == "complete", "Background export completes before ordinary Exit")

func run() -> void:
	await settle()
	if mode == "minimal":
		# No Wavez viewer, shell, Jobs, capture, or teardown harness is loaded.
		var panel := PopupPanel.new(); add_child(panel)
		await popup_cycles(panel, 8, "standalone seek equivalent")
		var menu := PopupMenu.new(); menu.add_item("Item"); add_child(menu)
		await popup_cycles(menu, 1, "standalone File equivalent")
	else:
		view = get_tree().current_scene
		check(view != null and view.name == "WAVEZ", "Unmodified production Main.tscn is the current scene")
		for cycle in (4 if mode == "baseline-smoke" else 2): await export_video(cycle, mode == "workflow")
		await popup_cycles(view.shell.menus.File.get_popup(), 1, "production File")
	var report := {"mode":mode, "checks":checks, "failures":failures, "snapshots":snapshots, "orphans_before_exit":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), "engine":Engine.get_version_info(), "display_server":DisplayServer.get_name(), "renderer":RenderingServer.get_current_rendering_method(), "editor":OS.has_feature("editor"), "debug":OS.has_feature("debug"), "executable":OS.get_executable_path()}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")+"\n"); file.close()
	print("WINDOW SIGNALS: ", checks, " functional checks, ", failures.size(), " failures; ordinary SceneTree exit follows")
	if mode == "minimal": get_tree().quit(0 if failures.is_empty() else 1)
	else: view.shell.window_chrome.request_close() # No manual viewer free or special shutdown.
