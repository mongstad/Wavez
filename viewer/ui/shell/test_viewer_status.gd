extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
const ProgressDetails = preload("res://video/progress_details.gd")
var output := ""
var checks := 0
var failures := []
var timings := {}
func _initialize(): run.call_deferred()
func check(ok: bool, description: String):
	checks += 1
	if not ok: failures.append(description); push_error(description)
func settle():
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
func ready(viewer):
	var deadline := Time.get_ticks_msec()+15000
	viewer.shell.status_ui.refresh()
	while (viewer.scene_layers.is_buffering() or viewer.shell.status_ui.readiness.begins_with("Preparing")) and Time.get_ticks_msec()<deadline:
		viewer.scene_layers.tick(0); await process_frame
		viewer.shell.status_ui.refresh()
	check(not viewer.scene_layers.is_buffering(),"Preparation completes")
	viewer.shell.status_ui.refresh()
func picture(name): root.get_texture().get_image().save_png(output.path_join(name+".png"))
func check_compact_job_rows(ui, context: String):
	for title in ["Video export", "Selections", "Analysis", "Matched views", "Isosurface"]:
		var job: Dictionary = ui.job_rows[title]
		var row: HBoxContainer = job.open.get_parent()
		var heading := row.get_child(0) as Label
		check(row.get_child_count() == 4 and heading != null and heading.text == title and row.get_child(1) == job.open and row.get_child(2) == job.details and row.get_child(3) == job.cancel, context + ": " + title + " has only its heading and three actions")
		var gap: float = job.open.get_global_rect().position.x - heading.get_global_rect().end.x
		check(gap >= 0 and gap <= 16, context + ": " + title + " heading stays close to its actions")
func check_job_header_clearance(ui, context: String):
	var header: HBoxContainer = ui.jobs_header_close.get_parent()
	var scroll: ScrollContainer = ui.jobs_dialog.find_children("*", "ScrollContainer", true, false)[0]
	var first: Button = ui.job_rows["Video export"].open
	check(first.get_global_rect().position.y - header.get_global_rect().end.y >= 20, context + ": first action clears the title row")
	check(first.get_global_rect().position.y >= scroll.get_global_rect().position.y and first.get_global_rect().end.x <= scroll.get_global_rect().end.x - 8, context + ": first action stays inside the row viewport")
func locked_fields(node: Node) -> bool:
	for child in node.get_children():
		if child is SpinBox or child is LineEdit:
			if child.editable:return false
		elif child is BaseButton:
			if not child.disabled:return false
		elif not locked_fields(child):return false
	return true
func setting_choice(video, label: String) -> OptionButton:
	for i in range(video.video_fields.get_child_count()-1):
		var node = video.video_fields.get_child(i)
		if node is Label and node.text == label:return video.video_fields.get_child(i+1)
	return null
func check_active_export(video, label: String):
	check(locked_fields(video.fields),label+": every setting, including Browse, is locked")
	check(not video.close_button.visible and video.background_button.visible and not video.background_button.disabled,label+": only background dismiss action is visible")
func check_idle_export(video, label: String):
	check(video.output.editable and video.rate.editable and not video.range_choice.disabled and not video.quality.disabled and not video.inspection_sidecars.disabled and video.g4_quota.editable,label+": settings editable again")
	check(video.start.editable and video.end.editable and not video.width.editable and not video.height.editable and not video.fps.editable,label+": custom range and preset dimension/FPS policies restored")
	check(video.close_button.visible and not video.background_button.visible,label+": dismiss restored, background hidden")
func wait_video(video):
	var deadline := Time.get_ticks_msec()+60000
	while video.pid > 0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(video.pid <= 0,"Video worker terminates")
	check(video.start_button.text == "Start Export" and not video.start_button.disabled and video.background_button.disabled,"Terminal export restores Start and disables background action")
	check_idle_export(video,"Terminal "+str(video.job_status.stage))
func configure_video(viewer, name: String, encoder: String, end_time := .2):
	var video = viewer.video_dialog
	video.open(); video.range_choice.select(2); video.update_range()
	video.start.value = 0; video.end.value = end_time; video.rate.value = 1
	video.width.value = 128; video.height.value = 128; video.fps.value = 30
	video.overlays.button_pressed = false; video.output.text = output.path_join(name+".mp4"); video.ffmpeg = encoder
	viewer.file_locations.settings.ffmpeg_mode = "custom"
	viewer.file_locations.settings.ffmpeg_path = encoder
	return video

func check_video_details():
	var snapshot := {"stage":"rendering", "snapshot_ticks":1000, "progress_ticks":1000,
		"elapsed_seconds":100.0, "progress":{"current_frame":3000.0,"total_frames":12000.0,"elapsed_seconds":100.0},
		"output":"/exports/movie.mp4", "directory":"/exports/job"}
	var text := ProgressDetails.format(snapshot,1000)
	check(text.begins_with("Rendering frame 3000 / 12000 (25%)\n"),"One integer frame count and actual percentage")
	check(text.contains("Elapsed: 00:01:40\nEstimated remaining: 00:05:00\n"),"Elapsed and estimated remaining use separate hh:mm:ss lines")
	check(text.count("3000 / 12000") == 1 and text.count("/exports/movie.mp4") == 1 and text.count("/exports/job") == 1,"No duplicate progress or equivalent paths")
	check(text.contains("Output: /exports/movie.mp4") and text.contains("Temporary files: /exports/job"),"Both paths are labeled")
	var dialog_text := ProgressDetails.format(snapshot,1000,true)
	check(dialog_text.begins_with("Rendering frame 3000 / 12000") and not dialog_text.contains("/exports/movie.mp4") and not dialog_text.contains("/exports/job"),"Dialog rendering status omits destination and working-directory paths")
	text = ProgressDetails.format(snapshot,3000)
	check(text.contains("Elapsed: 00:01:42") and text.contains("Estimated remaining: 00:05:06"),"Published snapshot advances elapsed and ETA between worker updates")
	text = ProgressDetails.format(snapshot,12000)
	check(text.contains("Estimated remaining: Unavailable — no recent frame progress"),"No stale ETA after a prolonged gap in frame progress")
	for stage in ["starting","loading","cancelling","encoding","failed","cancelled"]:
		snapshot.stage = stage
		snapshot.detail = "Diagnostic retained in /exports/job"
		text = ProgressDetails.format(snapshot,3000)
		check(not text.contains("approximate") and text.contains("Estimated remaining: Unavailable"),"No rendering ETA for "+stage)
		if stage in ["failed","cancelled"]:
			check(text == ProgressDetails.format(snapshot,999000),"Terminal time is frozen for "+stage)
			check(text.contains("Diagnostic retained in [Temporary files]") and text.count("/exports/job") == 1,"Terminal diagnostic preserved with one labeled directory")
			check(ProgressDetails.format(snapshot,3000,true).contains("Temporary files: /exports/job") and not ProgressDetails.format(snapshot,3000,true).contains("Output: /exports/movie.mp4"),"Dialog "+stage+" status retains actionable working-directory path only")
	for stage in ["complete","frames_ready"]:
		snapshot.stage = stage; snapshot.progress.current_frame = 12000
		text = ProgressDetails.format(snapshot,3000)
		check(text.contains("12000 / 12000 frames rendered (100%)") and text.contains("Estimated remaining: 00:00:00"),"Completed frame count and zero remainder for "+stage)
		check(text == ProgressDetails.format(snapshot,999000),"Stable completed time for "+stage)
	check(text.contains("FFmpeg unavailable"),"Frames-ready is distinguished from saved MP4")
	check(ProgressDetails.format(snapshot,3000,true).contains("Temporary files: /exports/job") and not ProgressDetails.format(snapshot,3000,true).contains("Output: /exports/movie.mp4"),"Dialog FFmpeg recovery status retains working-directory path only")
	snapshot.stage = "complete"
	check(not ProgressDetails.format(snapshot,3000,true).contains("/exports/"),"Dialog successful status omits completed output and temporary paths")
	snapshot.stage = "rendering"; snapshot.elapsed_seconds = 0
	for count in [0,1]:
		snapshot.progress.current_frame = count
		check(ProgressDetails.format(snapshot,1000).contains("Waiting for render progress"),"Initial render waits for sufficient progress "+str(count))
	for counts in [[0,0],[-1,10],[11,10],[0,-10],[0,NAN],[INF,10],[1.5,10]]:
		snapshot.progress.current_frame = counts[0]; snapshot.progress.total_frames = counts[1]
		text = ProgressDetails.format(snapshot,1000)
		check(text.begins_with("Rendering — frame count unavailable") and not text.contains("%"),"Invalid counts have no fabricated percent "+str(counts))
	snapshot.stage = "failed"; snapshot.progress = {"current_frame":3,"total_frames":12}
	check(ProgressDetails.format(snapshot,1000).begins_with("Failed — 3 / 12 frames rendered (25%)"),"Failure preserves actual partial progress rather than reporting completion")
	check(ProgressDetails.duration(360005) == "100:00:05","Long exports retain hours beyond 24")

func run():
	check_video_details()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--status-output="): output = arg.trim_prefix("--status-output=")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("config.json")))
	var viewer = Viewer.new(); root.add_child(viewer); await settle()
	check(viewer.video_dialog.start_button.disabled and viewer.video_dialog.background_button.disabled,"Unconfigured export cannot start or run in background")
	var ui = viewer.shell.status_ui
	ui.refresh(); check(ui.readiness == "No capture" and ui.active_count == 0,"Empty status and Jobs are persistent")
	ui.open_jobs(); await settle()
	check(ui.job_rows["Video export"].open.disabled and not ui.job_rows["Video export"].open.has_focus() and ui.job_rows["Selections"].open.has_focus(), "Empty Jobs focuses an enabled row action")
	check_job_header_clearance(ui, "Empty Jobs")
	for title in ["Video export", "Selections", "Analysis", "Matched views", "Isosurface"]:
		var job: Dictionary = ui.job_rows[title]
		check(job.open.tooltip_text.is_empty() and job.details.tooltip_text.is_empty() and job.cancel.tooltip_text.is_empty(), title + " actions do not cover the title with redundant tooltips")
	picture("jobs-empty"); ui.jobs_dialog.hide()
	viewer.shell.begin_open(); ui.refresh(); check(ui.readiness == "Preparing…","Opening has indeterminate preparation state")
	viewer.shell.finish_open("Test open failure"); ui.refresh()
	check(ui.failures.has("Open file"),"Open failure survives ending preparation")
	viewer._open_capture(config.source); viewer.playing = false; await ready(viewer)
	check(ui.readiness == "Ready" and not ui.failures.has("Open file"),"Successful open clears its load failure as accepted in #134")
	viewer.status_label.text = "Unrelated information"; ui.refresh()
	check(not ui.badge.label.text.contains("Failed"),"Unrelated status does not resurrect cleared load failure")
	ui.show_status(); check(not viewer.shell.detail_text.text.contains("Test open failure") and not viewer.shell.detail_failure_action.visible,"Recovered load diagnostic and its acknowledgement action are cleared")
	viewer.shell.details.hide(); ui.acknowledge(); check(ui.failures.is_empty(),"Explicit acknowledgement clears failure notice")
	var layers = viewer.scene_layers
	var fields = layers.field_playback
	fields.cache_cap_bytes = 1;fields.request(viewer.requested_time,layers.field_budget());ui.refresh()
	check(ui.readiness == "Preparing…" and ui.readiness_detail.contains("memory") and not ui.failures.has("Fields"),"Capacity wait preserves current display while continuous playback waits safely")
	fields.cache_cap_bytes = 0;fields.request(viewer.requested_time,layers.field_budget());ui.refresh()
	check(not ui.badge.label.text.contains("Waiting for memory"),"Memory status recovers without reopening")
	var worker = layers.playback.worker
	var was_processing: bool = viewer.is_processing();viewer.set_process(false)
	var gate := Semaphore.new(); worker.test_barrier = gate
	layers.playback.invalidate(); viewer.manual_max += 1; viewer._seek_time(2.25)
	var deadline := Time.get_ticks_msec()+10000
	while not worker.status().get("test_barrier_waiting",false) and Time.get_ticks_msec()<deadline: await process_frame
	ui.refresh(); check(ui.readiness == "Preparing…","Cold seek reports real preparation")
	viewer.playing = true;var particle_clock = viewer.committed_sample.get("requested_time")
	layers.tick(.05);await create_timer(.45).timeout;layers.tick(.05);ui.refresh()
	check(ui.readiness == "Buffering" and viewer.committed_sample.get("requested_time") == particle_clock,"Required particle worker stall holds the committed clock")
	viewer.playing = false
	viewer._seek_time(3.125); worker.test_barrier = null; gate.post(); await ready(viewer)
	check(ui.readiness == "Ready" and viewer.committed_sample.requested_time == 3.125,"Latest rapid replacement seek becomes ready")
	var mesh_worker = layers.mesh_playback.worker
	gate = Semaphore.new();mesh_worker.test_barrier = gate;layers.mesh_playback.invalidate();layers.views.mesh.clear()
	layers.states.mesh.wireframe = not layers.states.mesh.wireframe
	viewer._seek_time(2.5)
	deadline = Time.get_ticks_msec()+10000
	while not mesh_worker.status().test_barrier_waiting and Time.get_ticks_msec()<deadline:layers.tick(0);await process_frame
	check(mesh_worker.status().test_barrier_waiting,"Required mesh preparation reaches the real worker barrier")
	viewer.playing = true;var mesh_clock = viewer.committed_sample.get("requested_time")
	layers.tick(.05);await create_timer(.45).timeout;ui.refresh()
	check(ui.readiness == "Buffering" and viewer.committed_sample.get("requested_time") == mesh_clock,"Required mesh worker stall holds the committed clock")
	mesh_worker.test_barrier = null;gate.post();await ready(viewer);ui.refresh()
	check(ui.readiness == "Playing","Mesh recovery returns directly to Playing")
	viewer.playing = false;await ready(viewer)
	viewer.set_process(was_processing)
	# Presentation contract injection, not a claimed scientific failure reproduction.
	layers.mesh_playback.error = "Injected unavailable mesh diagnostic"; ui.refresh()
	check(ui.readiness == "Unavailable" and ui.failures.has("Meshes"),"Typed readiness failure is visible and durable")
	layers.mesh_playback.error = ""; ui.refresh(); check(ui.failures.has("Meshes"),"Recovery does not silently acknowledge failure")
	ui.open_jobs(); await settle()
	check(ui.jobs_dialog.visible, "Jobs can open while a retained failure is present")
	var failure_button_in_jobs := false
	for control in ui.jobs_dialog.find_children("*", "Button", true, false):
		failure_button_in_jobs = failure_button_in_jobs or control.text == "Failure details…"
	check(not failure_button_in_jobs and ui.jobs_button.text.contains("!"), "Retained failure is signalled without a misleading Jobs details button")
	ui.jobs_dialog.hide()
	viewer.shell.commands.details.popup.id_pressed.emit(viewer.shell.commands.details.index)
	check(viewer.shell.detail_failure_action.visible and viewer.shell.detail_text.text.begins_with("Retained failures\nMeshes — Failed\nInjected unavailable mesh diagnostic"), "File Details leads with the retained failure and its acknowledgement action")
	await settle(); check(viewer.shell.details.visible, "Status details opens for failure review")
	picture("status-failure-details")
	viewer.shell.detail_failure_action.pressed.emit()
	check(ui.failures.is_empty() and not viewer.shell.details.visible and not ui.badge.label.text.contains("Failed"), "Acknowledging in Status details clears retained notices without changing job state")
	var jobs = viewer.selection_controller.jobs
	jobs.background_failed.emit("Injected analysis worker failure"); ui.refresh()
	check(ui.failures.has("Analysis"),"Existing analysis failure signal is durable")
	ui.open_jobs(); ui.job_rows["Analysis"].details.pressed.emit()
	check(not viewer.shell.detail_failure_action.visible, "Job Details does not show the global failure acknowledgement action")
	viewer.shell.details.hide(); ui.acknowledge()
	# Reuse real selection-worker launch, completion and existing cancellation callbacks.
	var selection = viewer.selection_controller
	selection.bind_source(); ui.refresh()
	check(ui.active_count >= 1, "Existing selection query is counted")
	deadline = Time.get_ticks_msec()+15000
	while jobs.pending and Time.get_ticks_msec()<deadline: await process_frame
	check(not selection.source.is_empty() and not jobs.pending, "Selection source worker completes")
	ui.open_jobs(); ui.refresh()
	var serial: int = jobs.serial
	ui.job_rows["Selections"].open.pressed.emit(); await settle()
	check(jobs.serial == serial, "Reopening selection form submits no work")
	selection.bind_source(); ui.refresh(); ui.job_rows["Selections"].cancel.pressed.emit()
	check(selection.operation.is_empty() and selection.status.text == "Selection query cancelled.", "Jobs uses canonical selection cancellation callback")
	var revision: int = selection.temporal.revision
	ui.job_rows["Analysis"].cancel.pressed.emit()
	check(selection.temporal.revision == revision+1 and selection.temporal.status.text.begins_with("Cancellation requested"), "Jobs uses canonical analysis cancellation and revision guard")
	ui.refresh()
	var state: Dictionary = Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	Profile.enabled = true; Profile.reset()
	var started := Time.get_ticks_usec()
	for i in 1000: ui.refresh()
	timings.refresh_1000_ms = (Time.get_ticks_usec()-started)/1000.0
	var activity := Profile.report(); Profile.enabled = false
	check(activity.stages.is_empty() and activity.counters.is_empty(),"1000 status refreshes trigger no scientific work")
	check(Visual.snapshot(viewer)==state and viewer.committed_sample==sample,"Refresh preserves scientific state and committed clock")
	var count: int = ui.refresh_count
	await create_timer(.65).timeout
	check(ui.refresh_count-count <= 4,"Idle status refresh is bounded to five per second")
	await check_playback_status(viewer,config)
	for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
		root.size = dimensions; await settle(); viewer.shell.layout(); await settle()
		check(ui.size.y == 40 and ui.get_rect().end.y == dimensions.y,"Status is a 40-pixel bottom line "+str(dimensions))
		check(ui.badge.label.size.x > 100,"Readiness text has visible space")
		check(ui.jobs_button.get_global_rect().end.x <= dimensions.x and ui.jobs_button.size.y == 32,"Jobs stays inside transport with 32px action")
		viewer._toggle_overlay(); check(ui.is_visible_in_tree() and ui.jobs_button.is_visible_in_tree(),"Hidden dock preserves status and Jobs"); viewer._toggle_overlay()
		check(ui.find_child("CaptureFilename",true,false) == null,"No passive filename in status")
		check(viewer.shell.commands.details.popup == viewer.shell.menus.File.get_popup(),"Details remains discoverable in File")
		viewer.shell.commands.details.popup.id_pressed.emit(viewer.shell.commands.details.index); await settle()
		check(viewer.shell.details.visible and viewer.shell.detail_text.text.contains(viewer.capture_path),"File Details retains source access")
		viewer.shell.details.hide(); await settle()
		picture("loaded-"+str(dimensions.x))
		ui.open_jobs(); await settle(); check(ui.jobs_dialog.size.x <= mini(dimensions.x,520) and ui.jobs_dialog.size.y <= dimensions.y,"Jobs dialog remains narrow and fits desktop")
		check_job_header_clearance(ui, "Loaded Jobs " + str(dimensions))
		check_compact_job_rows(ui, "Idle Jobs " + str(dimensions))
		var has_failure_action := false
		for control in ui.jobs_dialog.find_children("*", "Button", true, false):
			has_failure_action = has_failure_action or control.text in ["Failure details…", "Acknowledge failures"]
		check(not has_failure_action, "Jobs overview has no failure controls outside job Details")
		check(ui.jobs_dialog.borderless and not ui.jobs_dialog.get_ok_button().visible, "Jobs uses one borderless shell with custom close controls")
		check(ui.jobs_header_close.icon != null and ui.jobs_header_close.theme_type_variation == "IconAction" and ui.jobs_footer_close.theme_type_variation == "SecondaryButton", "Jobs header and footer use shell action roles")
		check(ui.job_rows["Video export"].open.has_focus(), "Opening Jobs focuses the first available action")
		picture("jobs-"+str(dimensions.x)); ui.jobs_dialog.hide()
	ui.open_jobs(); ui.jobs_header_close.pressed.emit(); await settle()
	check(not ui.jobs_dialog.visible and ui.jobs_button.has_focus(), "Header close returns keyboard focus to Jobs")
	ui.open_jobs(); ui.jobs_footer_close.pressed.emit(); await settle()
	check(not ui.jobs_dialog.visible and ui.jobs_button.has_focus(), "Footer close returns keyboard focus to Jobs")
	ui.open_jobs(); ui.jobs_dialog.close_requested.emit(); await settle()
	check(not ui.jobs_dialog.visible and ui.jobs_button.has_focus(), "Window close returns keyboard focus to Jobs")
	ui.open_jobs()
	var escape := InputEventKey.new(); escape.pressed = true; escape.keycode = KEY_ESCAPE
	ui.jobs_dialog.window_input.emit(escape); await settle()
	check(not ui.jobs_dialog.visible and ui.jobs_button.has_focus(), "Escape dismisses Jobs and returns keyboard focus")
	var jobs_scroll: ScrollContainer = ui.jobs_dialog.find_children("*", "ScrollContainer", true, false)[0]
	jobs_scroll.custom_minimum_size.y = 100
	ui.jobs_dialog.popup_centered(Vector2i(500,240)); await settle()
	var scrollbar := jobs_scroll.get_v_scroll_bar()
	check(scrollbar.visible, "Compact Jobs rows still scroll when dialog height is constrained")
	var cancel_edge: float = ui.job_rows["Video export"].cancel.get_global_rect().end.x
	var scrollbar_edge: float = scrollbar.get_global_rect().position.x
	var aligned := true
	for title in ["Selections", "Analysis", "Matched views", "Isosurface"]:
		aligned = aligned and is_equal_approx(ui.job_rows[title].cancel.get_global_rect().end.x, cancel_edge)
	check(aligned and scrollbar_edge - cancel_edge >= 8.0, "Cancel column stays aligned with breathing room before a visible scrollbar")
	picture("jobs-scrolled")
	jobs_scroll.scroll_vertical = 40; await settle()
	check(jobs_scroll.scroll_vertical > 0, "Compact Jobs overview retains vertical scrolling")
	ui.jobs_dialog.hide(); jobs_scroll.custom_minimum_size.y = 220
	root.size = Vector2i(1440,900); await settle()
	ui.open_jobs(); ui.job_rows["Matched views"].details.pressed.emit()
	check(viewer.shell.details.visible and viewer.shell.detail_text.text == ui.job_rows["Matched views"].detail, "Matched views explanation remains in Details")
	viewer.shell.details.hide()
	var video = configure_video(viewer,"complete",config.ffmpeg,6)
	check(video.start_button.text == "Start Export" and not video.start_button.disabled and video.background_button.disabled,"Idle export has one Start action and disabled background action")
	check(video.start_button.get_parent().get_child_count() == 3 and video.close_button.text == "Cancel" and video.background_button.text == "Run in background","Exactly three requested dialog actions")
	video.close_button.pressed.emit()
	check(not video.visible and video.pid <= 0,"Idle Cancel closes without launching work")
	video.open()
	check_idle_export(video,"Before export")
	# Presentation-state injection: selection-recipe preparation has no worker yet.
	video.preparing = true; video._sync_action_buttons()
	check_active_export(video,"Preparation")
	var preparing_timeline = video.timeline
	video.open()
	check(video.timeline == preparing_timeline and video.start_button.text == "Cancel export" and not video.start_button.disabled and not video.background_button.disabled,"Preparation preserves draft and exposes background and cooperative cancellation")
	video.start_button.pressed.emit()
	check(video.cancel_confirmation.visible and not video.preparation_cancelled,"Preparation action confirms before background cancellation")
	video.cancel_confirmation.confirmed.emit()
	check(video.preparation_cancelled and video.job_status.stage == "cancelling","Confirmed preparation requests background cancellation")
	video.preparing = false; video._sync_action_buttons()
	check_idle_export(video,"Cancelled preparation")
	var resolution := setting_choice(video,"Resolution")
	var frame_rate := setting_choice(video,"Frame rate")
	resolution.select(3);resolution.item_selected.emit(3)
	frame_rate.select(3);frame_rate.item_selected.emit(3)
	video.range_choice.select(0);video.update_range()
	video.preparing = true;video._sync_action_buttons()
	check_active_export(video,"Custom resolution/FPS preparation")
	video.preparing = false;video._sync_action_buttons()
	check(video.width.editable and video.height.editable and video.fps.editable and not video.start.editable and not video.end.editable,"Custom dimensions/FPS and non-custom range restore their distinct idle policies")
	resolution.select(0);resolution.item_selected.emit(0)
	frame_rate.select(1);frame_rate.item_selected.emit(1)
	video.width.value = 128;video.height.value = 128
	video.range_choice.select(2);video.update_range();video.start.value = 0;video.end.value = 6
	await settle()
	check(Rect2(Vector2.ZERO,Vector2(video.size)).encloses(video.close_button.get_global_rect()),"Idle action row stays visible below scrolling settings")
	video.get_texture().get_image().save_png(output.path_join("export-idle.png"))
	var idle_secondary_x: float = video.close_button.position.x
	var idle_row_width: float = video.close_button.get_parent().size.x
	video.start_button.pressed.emit(); ui.refresh(); var pid: int = video.pid
	check_active_export(video,"Immediate launch")
	var job_hash := FileAccess.get_sha256(video.active_job_path)
	var running_settings: Dictionary = video.settings()
	video.save_dialog.file_selected.emit(output.path_join("late-picker.mp4"))
	check(video.settings() == running_settings,"Late file-picker callback cannot mutate active configuration")
	check(pid > 0 and ui.active_count == 1,"UI launch is counted as one running video job")
	check(video.start_button.text == "Cancel export" and not video.start_button.disabled and not video.background_button.disabled,"Running export switches primary action and enables background")
	await settle()
	check(Rect2(Vector2.ZERO,Vector2(video.size)).encloses(video.background_button.get_global_rect()),"Running action row stays visible below scrolling settings")
	check(video.background_button.position.x == idle_secondary_x and video.background_button.get_parent().size.x == idle_row_width,"Action row keeps secondary position and width across launch")
	video.get_texture().get_image().save_png(output.path_join("export-running.png"))
	video.background_button.pressed.emit()
	check(not video.visible and not video.cancel_confirmation.visible and video.pid == pid and not FileAccess.file_exists(video.active_directory.path_join("cancel")),"Run in background hides without cancellation or restart")
	ui.open_jobs(); ui.reopen_video(); check(video.pid == pid and video.visible,"Jobs reopens original running export without restarting")
	check_active_export(video,"Jobs reopen")
	check(video.settings() == running_settings and FileAccess.get_sha256(video.active_job_path) == job_hash,"Background/reopen and blocked picker preserve visible and worker configuration")
	video.background_button.pressed.emit()
	ui.open_jobs(); await settle(); picture("jobs-active-video")
	check_compact_job_rows(ui, "Active video Jobs")
	ui.job_rows["Video export"].details.pressed.emit()
	var initial_detail: String = viewer.shell.detail_text.text
	deadline = Time.get_ticks_msec()+15000
	while video.pid > 0 and video.last_progress.get("stage", "") != "rendering" and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	check(video.pid > 0 and viewer.shell.detail_text.text != initial_detail and ui.live_details == "Video export","Open active Details updates from real published export progress")
	check(viewer.shell.detail_text.text == ui.job_rows["Video export"].detail,"Details uses the retained progress snapshot")
	check(viewer.shell.detail_text.text.begins_with("Rendering frame ") and viewer.shell.detail_text.text.contains("%)\nElapsed: "),"Real worker produces canonical progress and elapsed")
	check(viewer.shell.detail_text.text.count(" / ") == 1 and viewer.shell.detail_text.text.count(video.active_directory) == 1,"Live Details has no duplicate frame count or directory")
	check(not video.message.text.contains("Output: ") and not video.message.text.contains(video.active_directory),"Dialog rendering status omits paths retained in Jobs Details")
	deadline = Time.get_ticks_msec()+15000
	while video.pid > 0 and not viewer.shell.detail_text.text.contains("Estimated remaining: 00:") and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	check(video.pid > 0 and viewer.shell.detail_text.text.contains("Estimated remaining: 00:"),"Live Details acquires a render ETA from real worker progress")
	await settle(); picture("live-details")
	root.mode = Window.MODE_MINIMIZED
	await wait_video(video)
	check(root.mode == Window.MODE_MINIMIZED and video.job_status.stage == "complete","Export completes while main viewer minimized and panel hidden")
	check(not DirAccess.dir_exists_absolute(video.active_directory.path_join("frames")),"Successful dialog export removes temporary PNG frames")
	root.mode = Window.MODE_WINDOWED; await settle(); ui.refresh()
	check(ui.live_details.is_empty() and viewer.shell.detail_text.text.begins_with("Complete"),"Details publishes terminal completion and stops following")
	var completed_detail: String = viewer.shell.detail_text.text
	check(completed_detail.contains("(100%)") and completed_detail.contains("Estimated remaining: 00:00:00"),"Real completion reports 100 percent and zero remaining")
	await create_timer(.3).timeout
	check(viewer.shell.detail_text.text == completed_detail,"Terminal detail view remains stable")
	picture("complete-details")
	viewer.shell.details.hide()
	check(ui.active_count == 0 and FileAccess.file_exists(output.path_join("complete.mp4")),"Completion clears active count and retains output")
	check(FileAccess.get_sha256(video.active_job_path) == job_hash,"Running job configuration is immutable through completion")
	ui.reopen_video(); await settle()
	video.get_texture().get_image().save_png(output.path_join("export-complete.png"))
	video.close_button.pressed.emit();check(not video.visible,"Successful terminal Cancel dismisses the dialog")
	var terminal: Dictionary = video.job_status.duplicate(true)
	ui.open_jobs(); await settle(); picture("jobs-complete")
	ui.job_rows["Video export"].details.pressed.emit(); await settle()
	check(viewer.shell.details.visible and viewer.shell.detail_text.text.contains(video.active_directory) and viewer.shell.detail_text.text.contains("complete.mp4"),"Jobs details exposes copyable retained output and diagnostics")
	viewer.shell.details.hide(); video.timeline = null; ui.reopen_video()
	check(video.job_status == terminal and video.timeline != null and video.message.text.contains("frames"),"Idle reopen refreshes current capture timeline and preserves terminal diagnostics/output")
	video.hide(); ui.jobs_dialog.hide()
	video = configure_video(viewer,"complete",config.ffmpeg); video.start_export()
	check(video.pid <= 0 and video.message.text.contains("exists"),"Overwrite refusal remains inline; no job starts")
	video.hide()
	ui.open_jobs(); ui.job_rows["Video export"].details.pressed.emit()
	completed_detail = viewer.shell.detail_text.text
	video = configure_video(viewer,"cancel",config.ffmpeg,6); video.start_export(); video.hide(); ui.refresh()
	check(not ui.job_rows["Video export"].cancel.disabled,"Jobs exposes supported cancellation")
	ui.job_rows["Video export"].cancel.pressed.emit()
	check(video.cancel_confirmation.visible,"Jobs cancel opens shared confirmation")
	video.cancel_confirmation.confirmed.emit(); await wait_video(video)
	check(video.job_status.stage == "cancelled","Jobs cancel follows worker acknowledgement")
	check(viewer.shell.detail_text.text == completed_detail,"A later export cannot overwrite the terminal Details view")
	viewer.shell.details.hide()
	check(DirAccess.dir_exists_absolute(video.active_directory),"Cancelled intermediates retained")
	video = configure_video(viewer,"second-success",config.ffmpeg)
	video.start_button.pressed.emit();await wait_video(video)
	check(video.job_status.stage == "complete" and FileAccess.file_exists(output.path_join("second-success.mp4")),"Edited settings launch and complete another export after terminal cleanup")
	video = configure_video(viewer,"primary-cancel",config.ffmpeg,6)
	video.start_button.pressed.emit(); pid = video.pid
	deadline = Time.get_ticks_msec()+15000
	while video.pid > 0 and video.last_progress.get("stage") != "rendering" and Time.get_ticks_msec()<deadline:await create_timer(.02).timeout
	check(video.last_progress.get("stage") == "rendering","Primary cancellation exercises a rendering worker")
	await check_cancel_confirmation(video)
	check(video.pid == pid and FileAccess.file_exists(video.active_directory.path_join("cancel")) and video.job_status.stage == "cancelling","Primary running action requests canonical cancellation without starting another job")
	video.hide(); await wait_video(video)
	check(video.job_status.stage == "cancelled","Primary cancellation follows worker acknowledgement")
	video = configure_video(viewer,"missing-ffmpeg","")
	var prior_directory: String = video.active_directory
	video.start_export()
	check(video.pid <= 0 and video.active_directory == prior_directory,"Missing FFmpeg starts no renderer or temporary directory")
	check(video.message.text.contains("FFmpeg is required") and video.message.text.contains("File Locations"),"Missing FFmpeg gives an actionable preference route")
	video.hide()
	video = configure_video(viewer,"failed-ffmpeg",config.bad_ffmpeg); video.start_export(); video.hide(); await wait_video(video); ui.refresh()
	check(video.job_status.stage == "failed" and ui.failures.has("Video export"),"Encoding failure persists in Jobs and status")
	viewer.status_label.text = "Another information message"; ui.refresh(); check(ui.failures.has("Video export"),"Unrelated update retains export failure")
	ui.open_jobs(); await settle(); picture("jobs-failed")
	ui.job_rows["Video export"].details.pressed.emit()
	check(viewer.shell.detail_text.text == ui.job_rows["Video export"].detail and viewer.shell.detail_text.text.contains("Failed"), "Failed export remains discoverable through Details")
	viewer.shell.details.hide(); ui.acknowledge()
	# Encoding uses real FFmpeg paced at input speed so the confirmation race is observable.
	video = configure_video(viewer,"cancel-encoding",config.slow_ffmpeg,3);video.start_export()
	deadline = Time.get_ticks_msec()+15000
	while video.pid > 0 and video.last_progress.get("stage") != "encoding" and Time.get_ticks_msec()<deadline:await create_timer(.02).timeout
	check(video.last_progress.get("stage") == "encoding","Real worker reaches FFmpeg encoding")
	await check_cancel_confirmation(video);await wait_video(video)
	check(video.job_status.stage == "cancelled" and not FileAccess.file_exists(output.path_join("cancel-encoding.mp4")),"Confirmed encoding cancellation retains protocol and no final MP4")
	for terminal_stage in ["complete","frames_ready","failed","cancelled"]:
		video.job_status.stage = terminal_stage;video.request_cancel_export()
		check(not video.cancel_confirmation.visible,"Terminal job never prompts: "+terminal_stage)
	# Simulate completion publication while the prompt is open, before process cleanup.
	video.preparing = true;video.job_status.stage = "preparing";video.request_cancel_export()
	check(video.cancel_confirmation.visible,"Prompt opens for active preparation")
	video.publish_job("complete","Finished while confirmation was open")
	video.cancel_confirmation.confirmed.emit()
	check(not video.cancel_confirmation.visible and video.job_status.stage == "complete","Completion dismisses stale confirmation and Yes is inert")
	video.preparing = false
	# Parent close requests cancellation through the same existing _exit_tree path.
	video = configure_video(viewer,"parent-close",config.ffmpeg,6); video.start_export()
	var parent_directory: String = video.active_directory
	check(video.pid > 0,"Parent-close scenario starts real worker")
	viewer.free(); await process_frame
	check(FileAccess.file_exists(parent_directory.path_join("cancel")),"Parent teardown requests graceful cancellation")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings,"activity":activity,"parent_directory":parent_directory,"standalone":not OS.has_feature("editor")},"\t")); file.close()
	print("STATUS: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)

func check_playback_status(viewer, config: Dictionary) -> void:
	viewer.set_process(false)
	viewer._open_capture(config.fields);viewer.playing = false
	var ui = viewer.shell.status_ui
	var layers = viewer.scene_layers
	var fields = layers.field_playback
	await ready(viewer)
	check(ui.readiness == "Ready","Paused startup reaches sufficient prepared coverage")
	viewer._toggle_playback();ui.refresh()
	check(ui.readiness == "Playing","Play shows Playing")
	layers.tick(.05);ui.refresh()
	check(ui.readiness == "Playing" and viewer.requested_time > 0,"Advancing playback remains Playing")
	var start_clock: float = viewer.committed_sample.requested_time
	var commits := 0
	viewer.physical_rate = .5
	for i in 24:
		var before: float = viewer.committed_sample.requested_time
		layers.tick(.04)
		if viewer.committed_sample.requested_time != before:commits += 1
		# Inject fluctuating internal flags after real transport ticks. These
		# cannot define a stall when the committed playback keeps progressing.
		var old_buffering: bool = fields.buffering
		var old_waiting: bool = fields.session_waiting
		fields.buffering = i % 2 == 0;fields.session_waiting = i % 3 == 0
		ui.refresh();check(ui.readiness == "Playing","Progressing playback ignores transient preparation/staging flags: "+str(i))
		fields.buffering = old_buffering;fields.session_waiting = old_waiting
		await create_timer(.025).timeout
	check(commits >= 8 and viewer.committed_sample.requested_time > start_clock,"Fluctuation regression advances the real committed clock repeatedly")
	viewer.physical_rate = 1
	viewer._toggle_playback();ui.refresh();check(ui.readiness == "Ready","Pause shows Ready with coverage")
	# Real field publication barrier: hold preparation without changing algorithms.
	var gate := Semaphore.new();fields.worker.test_barrier = gate
	fields.invalidate();viewer._seek_time(.7)
	var deadline := Time.get_ticks_msec()+10000
	while not fields.worker.status().test_barrier_waiting and Time.get_ticks_msec()<deadline:await process_frame
	check(fields.worker.status().test_barrier_waiting,"Cold seek overlaps real field preparation")
	ui.refresh();check(ui.readiness == "Preparing…" and not ui.badge.label.text.contains("Preparing ahead") and not ui.badge.label.text.contains("%"),"Paused cold seek has one indeterminate Automatic status")
	viewer.playing = true;fields.begin_session()
	var held_clock = viewer.committed_sample.get("requested_time")
	layers.tick(.05);ui.refresh()
	check(ui.readiness == "Playing","A transient hold does not flash Buffering")
	await create_timer(.45).timeout;layers.tick(.05);ui.refresh()
	check(viewer.committed_sample.get("requested_time") == held_clock and ui.readiness == "Buffering","Real cold seek holds committed clock and reports Buffering")
	fields.worker.test_barrier = null;gate.post()
	deadline = Time.get_ticks_msec()+15000
	while layers.is_buffering() and Time.get_ticks_msec()<deadline:layers.tick(0);await process_frame
	ui.refresh();check(ui.readiness == "Playing","Preparation recovery returns to Playing")
	# Exhaust the prepared runway while active, with no seek request.
	gate = Semaphore.new();fields.worker.test_barrier = gate;fields.invalidate();fields.begin_session()
	deadline = Time.get_ticks_msec()+10000
	while not fields.worker.status().test_barrier_waiting and Time.get_ticks_msec()<deadline:await process_frame
	held_clock = viewer.committed_sample.requested_time
	layers.tick(.05);await create_timer(.45).timeout;layers.tick(.05);ui.refresh()
	check(ui.readiness == "Buffering" and viewer.committed_sample.requested_time == held_clock,"Exhausted runway holds playback and reports Buffering")
	fields.worker.test_barrier = null;gate.post()
	deadline = Time.get_ticks_msec()+15000
	while layers.is_buffering() and Time.get_ticks_msec()<deadline:layers.tick(0);await process_frame
	ui.refresh();check(ui.readiness == "Playing","Runway recovery returns directly to Playing")
	viewer._toggle_playback();await ready(viewer)
	viewer._seek_time(.8);await ready(viewer);check(ui.readiness == "Ready","Warm seek stays ready")
	for channel in ["density","psi_real","psi_imag"]:
		var choice: OptionButton = layers.panel_controls.field.channel
		for index in choice.item_count:
			if choice.get_item_metadata(index) == channel:choice.select(index);choice.item_selected.emit(index);break
		await ready(viewer)
		check(ui.readiness == "Ready" and layers.views.field.channel == channel,"Channel replacement reaches Ready: "+channel)
	viewer.physical_rate = -1;viewer._seek_time(1.0);await ready(viewer)
	viewer._toggle_playback();layers.tick(.05)
	deadline = Time.get_ticks_msec()+10000
	while viewer.requested_time >= 1.0 and Time.get_ticks_msec()<deadline:await process_frame;layers.tick(.05)
	ui.refresh()
	check(ui.readiness == "Playing" and viewer.requested_time < 1.0,"Reverse playback shows Playing")
	viewer.playing = false;fields.cancel_session();viewer.physical_rate = 1
	var recording_end: float = viewer.generic_reader.frames[-1].time
	viewer._seek_time(recording_end);await ready(viewer);viewer.playing = true;ui.refresh()
	check(ui.readiness == "Ready","Recording end never leaves Playing stale even if transport intent remains set")
	viewer.playing = false;fields.buffering = true;ui.refresh()
	check(ui.readiness == "Preparing…","Paused endpoint still reports a missing required replacement sample")
	fields.buffering = false;viewer.playing = true
	viewer.scene_loop_playback = true;fields.begin_session()
	deadline = Time.get_ticks_msec()+15000
	while layers.is_buffering() and Time.get_ticks_msec()<deadline:layers.tick(0);await process_frame
	layers.tick(.05)
	while layers.is_buffering() and Time.get_ticks_msec()<deadline:layers.tick(0);await process_frame
	ui.refresh()
	check(ui.readiness == "Playing" and viewer.requested_time < recording_end,"Loop wraps and remains Playing")
	viewer.playing = false;fields.cancel_session();viewer.scene_loop_playback = false
	# Controlled presentation snapshots isolate worker activity from readiness.
	await ready(viewer)
	fields.worker.mutex.lock();var saved: Dictionary = fields.worker.session.duplicate();fields.worker.session = {"state":"preparing","automatic":true,"ready":1,"total":20};fields.worker.mutex.unlock()
	viewer.playing = true;fields.buffering = false;fields.session_waiting = false
	ui.refresh();check(ui.readiness == "Playing" and ui.badge.label.text == "Playing","Background work never replaces progressing Playing or adds an adjacent counter")
	viewer.playing = false
	fields.scope_choice.select(1);fields.session_waiting = true;fields.buffering = true
	fields.worker.mutex.lock();fields.worker.session = {"state":"preparing","ready":5,"total":20};fields.worker.mutex.unlock()
	ui.refresh();check(ui.readiness == "Preparing — 25%" and ui.readiness_detail.contains("explicitly requested preparation interval"),"Explicit interval percentage is scoped to prepared samples")
	fields.worker.mutex.lock();fields.worker.session = {"state":"planning","planned":5,"total":20};fields.worker.mutex.unlock()
	ui.refresh();check(not ui.readiness.contains("%"),"Planning does not misrepresent prepared progress")
	fields.worker.mutex.lock();fields.worker.session = saved;fields.worker.mutex.unlock()
	fields.scope_choice.select(0);viewer.playing = false;fields.cancel_session()
	viewer._open_capture(output.path_join("missing.wvz"));ui.refresh()
	check(ui.failures.has("Open file"),"Actual missing-file failure remains available")
	viewer._open_capture(config.source);viewer.playing = false;await ready(viewer)
	check(ui.readiness == "Ready" and not ui.failures.has("Open file"),"Valid open recovers readiness and clears its load failure")
	ui.acknowledge()
	var reader = viewer.generic_reader;viewer.generic_reader = null;ui.refresh()
	check(ui.readiness == "No capture" and ui.badge.label.text == "No capture","No-source presentation cannot retain old playback status")
	viewer.generic_reader = reader;ui.refresh()
	check(ui.readiness == "Ready" and not ui.badge.label.text.contains("%"),"Capture replacement clears prior status")
	viewer.set_process(true)

func check_cancel_confirmation(video):
	var marker: String = video.active_directory.path_join("cancel")
	video.start_button.pressed.emit();await settle()
	var dialog = video.cancel_confirmation
	check(dialog.visible and not FileAccess.file_exists(marker),"Cancel export prompts before writing marker")
	check(dialog.gui_get_focus_owner() == dialog.get_cancel_button(),"No receives default confirmation focus")
	video.request_cancel_export()
	check(video.cancel_confirmation == dialog and dialog.visible,"Repeated request reuses the single prompt")
	dialog.get_cancel_button().pressed.emit();await settle()
	check(not dialog.visible and not FileAccess.file_exists(marker) and video.pid > 0,"No keeps worker running without marker")
	video.request_cancel_export();dialog.close_requested.emit();await settle()
	check(not dialog.visible and not FileAccess.file_exists(marker) and video.pid > 0,"Window dismissal keeps worker running")
	video.request_cancel_export()
	dialog.confirmed.emit()
	check(FileAccess.file_exists(marker) and video.job_status.stage == "cancelling","Yes invokes existing cancellation")
	# A second signal must not invoke the writer again while acknowledgement is pending.
	var file := FileAccess.open(marker,FileAccess.WRITE);file.store_string("request already sent");file.close()
	dialog.confirmed.emit();video.request_cancel_export()
	check(FileAccess.get_file_as_string(marker) == "request already sent" and not dialog.visible,"Repeated Yes/click does not send another request")
