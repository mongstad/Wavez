extends Node
## #329: capture disposal, dependency refusal and independent live exports.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
var exports: Array = []
var view

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--close-output="): output = arg.trim_prefix("--close-output=")
	if not output.is_empty(): run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 4: await get_tree().process_frame
func picture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	# Native Window hide/focus handoff can outlive a few process frames in
	# low-processor mode. Let it settle before taking root texture readback.
	await get_tree().create_timer(.1).timeout
	RenderingServer.force_draw(false)
	check(get_tree().root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK, name+": screenshot")
func close_menu() -> void:
	view.shell.refresh_commands()
	var entry: Dictionary = view.shell.commands.close_file
	entry.popup.id_pressed.emit(entry.index)
func empty_state(label: String) -> void:
	check(view.generic_reader == null and view.capture == null and view.capture_path.is_empty(), label+": reader ownership released")
	check(view.scene_layers == null and view.frame_a == null and view.frame_b == null and view.history.is_empty(), label+": samples and scene gone")
	check(view.current_buffer.is_empty() and view.current_sizes.is_empty() and view.filter_values.is_empty() and view.filter_hidden_types.is_empty() and view.current_mm.instance_count == 0 and view.trail_mms.all(func(mm): return mm.instance_count == 0), label+": CPU/GPU particle allocations empty")
	check(view.identity_pair_a == null and view.identity_pair_b == null and view.identity_matches.is_empty() and view.shared_timeline == null and view.committed_sample.is_empty(), label+": timeline and identity references empty")
	check(not view.playing and not view.orbit_enabled and view.frame_count == 0 and view.current_index == 0 and view.timeline.value == 0 and not view.timeline.editable, label+": transport stopped")
	check(not view.legend.visible and not view.colorbar.visible and view.geometry_meshes.values().all(func(node): return node.mesh == null and not node.visible), label+": capture legends and geometry cleared")
	check(view.selection_controller.state.definitions.is_empty() and view.selection_controller.overlay.gpu_bytes == 0 and view.selection_controller.last_resolution.is_empty(), label+": selections cleared")
	check(view.shell.empty.is_visible_in_tree() and not view.shell.loading and view.shell.workspace == 0 and view.shell.status_ui.readiness == "No capture", label+": ordinary empty shell")
	check(view.shell.commands.close_file.popup.is_item_disabled(view.shell.commands.close_file.index) and not view.shell.commands.open.popup.is_item_disabled(view.shell.commands.open.index), label+": close disabled and open enabled")
	check(not view.video_dialog.can_start and view.video_dialog.timeline == null, label+": stale video draft invalidated")
func wait_jobs() -> bool:
	var deadline := Time.get_ticks_msec()+30000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.02).timeout
		if not view.selection_controller.jobs.busy() and view.selection_controller.operation.is_empty(): return view.selection_controller.jobs.error.is_empty()
	return false
func lifecycle(name: String, playback: bool) -> void:
	view._open_capture(output.path_join(name+".wvz")); await settle()
	check(view.generic_reader != null and view.frame_count > 0, name+": capture opens")
	view.playing = playback
	if playback:
		view.orbit_enabled = true; view.shell.edit_orbit_center()
	view.guide_visibility.data = true; view._apply_geometry()
	view.shell.transport.open_seek()
	var reader = view.generic_reader
	var layers: WeakRef = weakref(view.scene_layers)
	var particle_worker: WeakRef = weakref(view.scene_layers.playback.worker)
	var field_worker: WeakRef = weakref(view.scene_layers.field_playback.worker)
	var mesh_worker: WeakRef = weakref(view.scene_layers.mesh_playback.worker)
	var before := {"capture":name,"playback":playback,"particle_buffer_bytes":view.current_buffer.size()*4,"reader_cache_bytes":reader.cache.used,"reader_metadata_bytes":reader.metadata_reserved,"static_memory":OS.get_static_memory_usage(),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"particles":view.scene_layers.playback.worker.status(),"fields":view.scene_layers.field_playback.worker.status(),"meshes":view.scene_layers.mesh_playback.worker.status()}
	close_menu(); await settle(); view.shell.status_ui.refresh()
	empty_state(name)
	check(reader.file == null and reader.cache.used == 0 and reader.records.is_empty() and reader.metadata_reserved == 0, name+": held reader confirms handle/cache/index cleared")
	check(layers.get_ref() == null and particle_worker.get_ref() == null and field_worker.get_ref() == null and mesh_worker.get_ref() == null, name+": layer/controller/worker ownership reclaimed")
	check(not view.shell.transport.seek_dialog.visible, name+": stale seek dismissed")
	before.after = {"static_memory":OS.get_static_memory_usage(),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"particle_buffer_bytes":view.current_buffer.size()*4,"reader_metadata_bytes":reader.metadata_reserved,"reader_cache_bytes":reader.cache.used,"workers_reclaimed":particle_worker.get_ref() == null and field_worker.get_ref() == null and mesh_worker.get_ref() == null}
	measurements.append(before)
	var generation: int = view.capture_generation
	check(view._close_capture() and view.capture_generation == generation, name+": repeated close is harmless")
func refusal(label: String) -> void:
	var reader = view.generic_reader
	var layers = view.scene_layers
	var sample: Dictionary = view.committed_sample.duplicate(true)
	var generation: int = view.capture_generation
	close_menu()
	check(view.generic_reader == reader and view.scene_layers == layers and view.capture_generation == generation and view.committed_sample == sample, label+": refusal preserves entire session")
	check(view.shell.details.visible and view.shell.details.title == "Close File unavailable" and not view.shell.detail_text.text.is_empty(), label+": refusal explains dependency")
	view.shell.details.hide()
func selection() -> bool:
	var control = view.selection_controller
	control.bind_source(); refusal("Active source selection"); check(await wait_jobs(), "Source selection completes after refusal")
	control.kind.select(0); control.members_input.text = "7,9007199254740993"; control.create_definition()
	check(await wait_jobs(), "Exact source cohort ready")
	return not control.state.definitions.is_empty()
func analysis_export() -> void:
	view._open_capture(output.path_join("mixed.wvz")); await settle()
	if not await selection(): return
	var temporal = view.selection_controller.temporal
	temporal.full_range(); temporal.run_analysis(); refusal("Running temporal analysis")
	check(await wait_jobs(), "Temporal result completes after refusal")
	check(not temporal.current_result.is_empty(), "Numerical result available")
	for label in ["control-data", "refused-data"]:
		temporal.durable.export_to(output.path_join(label))
		check(view.selection_controller.jobs.background_pending, label+": real numerical export started")
		var id: String = view.selection_controller.jobs.background_id
		if label == "refused-data": refusal("Active numerical export")
		check(view.selection_controller.jobs.background_id == id and not FileAccess.file_exists(view.selection_controller.jobs.directory.path_join("background_cancel.json")), label+": job retained without cancellation")
		check(await wait_jobs() and not temporal.durable.last_export.is_empty(), label+": numerical export completes")
	check(view._close_capture(), "Close succeeds after numerical export completion"); await settle(); empty_state("After analysis")
func video_export(label: String, selected: bool, close: bool) -> void:
	view._open_capture(output.path_join("mixed.wvz")); await settle()
	view._reset_camera(); view.orbit_enabled = false; view.playing = false
	if selected:
		if not await selection(): return
		check(await view.selection_controller.await_committed_overlay(), label+": highlights are visibly committed before the snapshot")
	var video = view.video_dialog
	video.open(); video.range_choice.select(2); video.update_range()
	video.set_range_times(0,1); video.rate.value = 1; video.fps.value = 6
	video.width.value = 256; video.height.value = 256; video.overlays.button_pressed = false
	video.trails.button_pressed = false; video.camera_mode.select(0)
	video.inspection_sidecars.button_pressed = true
	video.output.text = output.path_join(label+".mp4")
	video.start_export()
	var deadline := Time.get_ticks_msec()+30000
	check(video.pid > 0, label+": independent renderer launched")
	if video.pid <= 0: return
	video.hide()
	var directory: String = video.active_directory
	var pid: int = video.pid
	var job_hash := FileAccess.get_sha256(video.active_job_path)
	if close:
		check(view._close_capture(), label+": closes during live background export"); await settle(); empty_state(label)
		check(video.pid == pid and not FileAccess.file_exists(directory.path_join("cancel")) and FileAccess.get_sha256(video.active_job_path) == job_hash, label+": live PID/job retained and no cancel sent")
		await picture(label+"-empty")
		view.shell.status_ui.open_jobs(); view.shell.status_ui.job_rows["Video export"].open.pressed.emit()
		check(video.visible and video.pid == pid, label+": Jobs reopens export after close"); video.hide(); await settle()
		view._open_capture(output.path_join("fields.wvz")); await settle()
		check(view.capture_path.ends_with("fields.wvz") and video.active_directory == directory, label+": different capture reopens while export owns original inputs")
	deadline = Time.get_ticks_msec()+120000
	while video.pid > 0 and Time.get_ticks_msec() < deadline: await get_tree().create_timer(.05).timeout
	check(video.pid <= 0 and video.job_status.get("stage") == "complete" and FileAccess.file_exists(output.path_join(label+".mp4")), label+": live export completes")
	check(not FileAccess.file_exists(directory.path_join("cancel")), label+": no cancellation file")
	exports.append({"name":label,"directory":directory,"job_sha256":job_hash,"selected":selected,"closed":close,"status":video.job_status.duplicate(true)})
	check(view._close_capture(), label+": final viewer close"); await settle()
func cancel_after_close() -> void:
	view._open_capture(output.path_join("mixed.wvz")); await settle()
	var video = view.video_dialog
	video.open(); video.range_choice.select(2); video.update_range(); video.set_range_times(0,6)
	video.rate.value = 1; video.fps.value = 30; video.width.value = 256; video.height.value = 256
	video.output.text = output.path_join("explicit-cancel.mp4"); video.start_export(); video.hide()
	check(video.pid > 0, "Cancellation: real renderer started")
	if video.pid <= 0: return
	check(view._close_capture(), "Cancellation: capture closes with worker alive"); await settle()
	view.shell.status_ui.open_jobs(); view.shell.status_ui.job_rows["Video export"].cancel.pressed.emit(); await settle()
	check(video.cancel_confirmation.visible and not FileAccess.file_exists(video.active_directory.path_join("cancel")), "Cancellation: own Jobs control asks before cancelling")
	video.cancel_confirmation.confirmed.emit()
	var deadline := Time.get_ticks_msec()+30000
	while video.pid > 0 and Time.get_ticks_msec() < deadline: await get_tree().create_timer(.05).timeout
	check(video.pid <= 0 and video.job_status.get("stage") == "cancelled" and FileAccess.file_exists(video.active_directory.path_join("cancel")), "Cancellation: explicit own control receives normal acknowledgement after close")
	view.shell.status_ui.jobs_dialog.hide()
func run() -> void:
	view = Viewer.new(); get_tree().root.add_child(view); await settle()
	check(view._close_capture(), "Initial empty close harmless")
	var entry: Dictionary = view.shell.commands.close_file
	check(entry.popup.get_item_text(entry.index) == "Close File" and entry.popup.get_item_tooltip(entry.index).is_empty(), "Close File menu has no tooltip")
	var preferences: Dictionary = view.shell.shortcuts.active.duplicate()
	var locations: Dictionary = view.file_locations.settings.duplicate(true)
	var theme: bool = view.shell.appearance.light
	for cycle in 2:
		view.shell.appearance.select(cycle == 1)
		for name in ["particles", "fields", "meshes", "mixed"]: await lifecycle(name, cycle == 1)
		if cycle == 1: await picture("light-empty")
	view.shell.appearance.select(theme)
	view._open_capture(output.path_join("mixed.wvz")); await settle()
	view.inspection_busy = true; refusal("Image inspection"); view.inspection_busy = false
	view.screenshot_pending = true; refusal("Pending screenshot"); view.screenshot_pending = false
	view.selection_controller.jobs.foreground_cancel_id = "pending-ack"; refusal("Selection cancellation acknowledgement"); view.selection_controller.jobs.foreground_cancel_id = ""
	view.selection_controller.temporal.matched.preparing = true; refusal("Matched preparation"); view.selection_controller.temporal.matched.preparing = false
	view.selection_controller.temporal.matched.pid = 123; refusal("Matched render"); view.selection_controller.temporal.matched.pid = -1
	check(view._close_capture(), "Close after dependency matrix"); await settle()
	await analysis_export()
	if DisplayServer.get_name() != "headless":
		for selected in [false,true]:
			var prefix := "selected" if selected else "ordinary"
			await video_export(prefix+"-control", selected, false)
			await video_export(prefix+"-closed", selected, true)
		await cancel_after_close()
	check(view.shell.shortcuts.active == preferences and view.file_locations.settings == locations and view.shell.appearance.light == theme, "Shell preferences preserved across all close/reopen paths")
	view.shell.refresh_commands(); var file: PopupMenu = view.shell.menus.File.get_popup()
	check(file.get_item_text(file.item_count-1) == "Exit" and file.is_item_separator(file.item_count-2), "Exit remains final command after separator")
	await picture("empty")
	file.popup(); await settle(); await picture("file-menu"); file.hide(); await settle()
	Job.write_json(output.path_join("report.json"), {"checks":checks,"failures":failures,"measurements":measurements,"exports":exports,"renderer":RenderingServer.get_current_rendering_method(),"packaged":not OS.has_feature("editor")})
	view.queue_free(); await settle()
	print("CLOSE FILE: ",checks," checks, ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
