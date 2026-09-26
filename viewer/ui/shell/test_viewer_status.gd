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
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()<deadline:
		viewer.scene_layers.tick(0); await process_frame
	check(not viewer.scene_layers.is_buffering(),"Preparation completes")
	viewer.shell.status_ui.refresh()
func picture(name): root.get_texture().get_image().save_png(output.path_join(name+".png"))
func wait_video(video):
	var deadline := Time.get_ticks_msec()+60000
	while video.pid > 0 and Time.get_ticks_msec()<deadline: await create_timer(.05).timeout
	check(video.pid <= 0,"Video worker terminates")
	check(video.start_button.text == "Start Export" and not video.start_button.disabled and video.background_button.disabled,"Terminal export restores Start and disables background action")
func configure_video(viewer, name: String, encoder: String, end_time := .2):
	var video = viewer.video_dialog
	video.open(); video.range_choice.select(2); video.update_range()
	video.start.value = 0; video.end.value = end_time; video.rate.value = 1
	video.width.value = 128; video.height.value = 128; video.fps.value = 30
	video.overlays.button_pressed = false; video.output.text = output.path_join(name+".mp4"); video.ffmpeg = encoder
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
	for stage in ["complete","frames_ready"]:
		snapshot.stage = stage; snapshot.progress.current_frame = 12000
		text = ProgressDetails.format(snapshot,3000)
		check(text.contains("12000 / 12000 frames rendered (100%)") and text.contains("Estimated remaining: 00:00:00"),"Completed frame count and zero remainder for "+stage)
		check(text == ProgressDetails.format(snapshot,999000),"Stable completed time for "+stage)
	check(text.contains("FFmpeg unavailable"),"Frames-ready is distinguished from saved MP4")
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
	viewer.shell.begin_open(); ui.refresh(); check(ui.readiness == "Preparing…","Opening has indeterminate preparation state")
	viewer.shell.finish_open("Test open failure"); ui.refresh()
	check(ui.failures.has("Open capture"),"Open failure survives ending preparation")
	viewer._open_capture(config.source); viewer.playing = false; await ready(viewer)
	check(ui.readiness == "Ready" and ui.failures.has("Open capture"),"Successful open does not acknowledge old failure")
	viewer.status_label.text = "Unrelated information"; ui.refresh()
	check(ui.badge.label.text.contains("Failed"),"Unrelated viewer status does not erase failure badge")
	ui.show_status(); check(viewer.shell.detail_text.text.contains("Test open failure"),"Durable diagnostic reachable")
	viewer.shell.details.hide(); ui.acknowledge(); check(ui.failures.is_empty(),"Explicit acknowledgement clears failure notice")
	var layers = viewer.scene_layers
	var fields = layers.field_playback
	fields.cache_cap_bytes = 1;fields.request(viewer.requested_time,layers.field_budget());ui.refresh()
	check(ui.readiness == "Ready" and ui.badge.label.text.contains("Waiting for memory") and not ui.failures.has("Fields"),"Capacity wait preserves a valid usable scene in the status badge")
	fields.cache_cap_bytes = 0;fields.request(viewer.requested_time,layers.field_budget());ui.refresh()
	check(not ui.badge.label.text.contains("Waiting for memory"),"Memory status recovers without reopening")
	var worker = layers.playback.worker
	var gate := Semaphore.new(); worker.test_barrier = gate
	layers.playback.invalidate(); viewer.manual_max += 1; viewer._seek_time(2.25)
	var deadline := Time.get_ticks_msec()+10000
	while not worker.status().get("test_barrier_waiting",false) and Time.get_ticks_msec()<deadline: await process_frame
	ui.refresh(); check(ui.readiness == "Preparing…","Cold seek reports real preparation")
	viewer._seek_time(3.125); worker.test_barrier = null; gate.post(); await ready(viewer)
	check(ui.readiness == "Ready" and viewer.committed_sample.requested_time == 3.125,"Latest rapid replacement seek becomes ready")
	# Presentation contract injection, not a claimed scientific failure reproduction.
	layers.mesh_playback.error = "Injected unavailable mesh diagnostic"; ui.refresh()
	check(ui.readiness == "Unavailable" and ui.failures.has("Meshes"),"Typed readiness failure is visible and durable")
	layers.mesh_playback.error = ""; ui.refresh(); check(ui.failures.has("Meshes"),"Recovery does not silently acknowledge failure")
	ui.acknowledge()
	var jobs = viewer.selection_controller.jobs
	jobs.background_failed.emit("Injected analysis worker failure"); ui.refresh()
	check(ui.failures.has("Analysis"),"Existing analysis failure signal is durable")
	ui.acknowledge()
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
	for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
		root.size = dimensions; await settle(); viewer.shell.layout(); await settle()
		check(ui.size.y == 40 and ui.get_rect().end.y == dimensions.y,"Status is a 40-pixel bottom line "+str(dimensions))
		check(ui.badge.label.size.x > 100,"Readiness text has visible space")
		check(ui.jobs_button.get_global_rect().end.x <= dimensions.x and ui.jobs_button.size.y == 32,"Jobs stays inside transport with 32px action")
		viewer._toggle_overlay(); check(ui.is_visible_in_tree() and ui.jobs_button.is_visible_in_tree(),"Hidden dock preserves status and Jobs"); viewer._toggle_overlay()
		ui.detail_button.grab_focus(); await settle()
		check(is_equal_approx(ui.detail_button.get_global_rect().get_center().y,ui.get_global_rect().get_center().y),"Details is vertically centered")
		for style_name in ["normal","hover","pressed","focus"]:
			var style: StyleBoxFlat = ui.detail_button.get_theme_stylebox(style_name)
			var drawn: Rect2 = ui.detail_button.get_global_rect().grow_individual(style.expand_margin_left,style.expand_margin_top,style.expand_margin_right,style.expand_margin_bottom)
			check(ui.get_global_rect().encloses(drawn),"Status contains complete "+style_name+" outline "+str(dimensions))
		picture("focus-"+str(dimensions.x))
		var motion := InputEventMouseMotion.new(); motion.position = ui.detail_button.get_global_rect().get_center(); Input.parse_input_event(motion); await settle()
		picture("hover-focus-"+str(dimensions.x))
		ui.detail_button.release_focus()
		picture("loaded-"+str(dimensions.x))
		ui.open_jobs(); await settle(); check(ui.jobs_dialog.size.x <= dimensions.x and ui.jobs_dialog.size.y <= dimensions.y,"Jobs dialog fits desktop")
		picture("jobs-"+str(dimensions.x)); ui.jobs_dialog.hide()
	root.size = Vector2i(1440,900); await settle()
	var video = configure_video(viewer,"complete",config.ffmpeg,6)
	check(video.start_button.text == "Start Export" and not video.start_button.disabled and video.background_button.disabled,"Idle export has one Start action and disabled background action")
	check(video.start_button.get_parent().get_child_count() == 3 and video.close_button.text == "Cancel" and video.background_button.text == "Run in background","Exactly three requested dialog actions")
	video.close_button.pressed.emit()
	check(not video.visible and video.pid <= 0,"Idle Cancel closes without launching work")
	video.open()
	# Presentation-state injection: selection-recipe preparation has no worker yet.
	video.preparing = true; video._sync_action_buttons()
	var preparing_timeline = video.timeline
	video.open()
	check(video.timeline == preparing_timeline and video.start_button.text == "Cancel export" and video.start_button.disabled and not video.background_button.disabled,"Preparation preserves draft and exposes background without unsupported worker cancellation")
	video.preparing = false; video._sync_action_buttons()
	await settle(); video.get_child(0).ensure_control_visible(video.close_button); await settle()
	check(Rect2(Vector2.ZERO,Vector2(video.size)).encloses(video.close_button.get_global_rect()),"Idle action row reachable by scrolling")
	video.get_texture().get_image().save_png(output.path_join("export-idle.png"))
	video.start_button.pressed.emit(); ui.refresh(); var pid: int = video.pid
	check(pid > 0 and ui.active_count == 1,"UI launch is counted as one running video job")
	check(video.start_button.text == "Cancel export" and not video.start_button.disabled and not video.background_button.disabled,"Running export switches primary action and enables background")
	await settle(); video.get_child(0).ensure_control_visible(video.close_button); await settle()
	check(Rect2(Vector2.ZERO,Vector2(video.size)).encloses(video.close_button.get_global_rect()),"Running action row reachable by scrolling")
	video.get_texture().get_image().save_png(output.path_join("export-running.png"))
	video.background_button.pressed.emit()
	check(not video.visible and video.pid == pid and not FileAccess.file_exists(video.active_directory.path_join("cancel")),"Run in background hides without cancellation or restart")
	ui.open_jobs(); ui.reopen_video(); check(video.pid == pid and video.visible,"Jobs reopens original running export without restarting")
	video.close_button.pressed.emit()
	check(not video.visible and video.pid == pid and not FileAccess.file_exists(video.active_directory.path_join("cancel")),"Running Cancel closes only the dialog")
	ui.open_jobs(); ui.job_rows["Video export"].details.pressed.emit()
	var initial_detail: String = viewer.shell.detail_text.text
	deadline = Time.get_ticks_msec()+15000
	while video.pid > 0 and video.last_progress.get("stage", "") != "rendering" and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	check(video.pid > 0 and viewer.shell.detail_text.text != initial_detail and ui.live_details == "Video export","Open active Details updates from real published export progress")
	check(viewer.shell.detail_text.text == ui.job_rows["Video export"].detail,"Details and Jobs overview use the same progress snapshot")
	check(viewer.shell.detail_text.text.begins_with("Rendering frame ") and viewer.shell.detail_text.text.contains("%)\nElapsed: "),"Real worker produces canonical progress and elapsed")
	check(viewer.shell.detail_text.text.count(" / ") == 1 and viewer.shell.detail_text.text.count(video.active_directory) == 1,"Live Details has no duplicate frame count or directory")
	deadline = Time.get_ticks_msec()+15000
	while video.pid > 0 and not viewer.shell.detail_text.text.contains("Estimated remaining: 00:") and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	check(video.pid > 0 and viewer.shell.detail_text.text.contains("Estimated remaining: 00:"),"Live Details acquires a render ETA from real worker progress")
	await settle(); picture("live-details")
	root.mode = Window.MODE_MINIMIZED
	await wait_video(video)
	check(root.mode == Window.MODE_MINIMIZED and video.job_status.stage == "complete","Export completes while main viewer minimized and panel hidden")
	root.mode = Window.MODE_WINDOWED; await settle(); ui.refresh()
	check(ui.live_details.is_empty() and viewer.shell.detail_text.text.begins_with("Complete"),"Details publishes terminal completion and stops following")
	var completed_detail: String = viewer.shell.detail_text.text
	check(completed_detail.contains("(100%)") and completed_detail.contains("Estimated remaining: 00:00:00"),"Real completion reports 100 percent and zero remaining")
	await create_timer(.3).timeout
	check(viewer.shell.detail_text.text == completed_detail,"Terminal detail view remains stable")
	picture("complete-details")
	viewer.shell.details.hide()
	check(ui.active_count == 0 and FileAccess.file_exists(output.path_join("complete.mp4")),"Completion clears active count and retains output")
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
	ui.job_rows["Video export"].cancel.pressed.emit(); await wait_video(video)
	check(video.job_status.stage == "cancelled","Jobs cancel follows worker acknowledgement")
	check(viewer.shell.detail_text.text == completed_detail,"A later export cannot overwrite the terminal Details view")
	viewer.shell.details.hide()
	check(DirAccess.dir_exists_absolute(video.active_directory),"Cancelled intermediates retained")
	video = configure_video(viewer,"primary-cancel",config.ffmpeg,6)
	video.start_button.pressed.emit(); pid = video.pid
	video.start_button.pressed.emit()
	check(video.pid == pid and FileAccess.file_exists(video.active_directory.path_join("cancel")) and video.job_status.stage == "cancelling","Primary running action requests canonical cancellation without starting another job")
	video.hide(); await wait_video(video)
	check(video.job_status.stage == "cancelled","Primary cancellation follows worker acknowledgement")
	video = configure_video(viewer,"missing-ffmpeg",""); video.start_export(); video.hide(); await wait_video(video)
	check(video.job_status.stage == "frames_ready","Missing FFmpeg retains PNG sequence")
	check(FileAccess.file_exists(video.active_directory.path_join("frames/frame00000000.png")),"Recoverable PNG output exists")
	video = configure_video(viewer,"failed-ffmpeg",config.bad_ffmpeg); video.start_export(); video.hide(); await wait_video(video); ui.refresh()
	check(video.job_status.stage == "failed" and ui.failures.has("Video export"),"Encoding failure persists in Jobs and status")
	viewer.status_label.text = "Another information message"; ui.refresh(); check(ui.failures.has("Video export"),"Unrelated update retains export failure")
	ui.open_jobs(); await settle(); picture("jobs-failed"); ui.jobs_dialog.hide(); ui.acknowledge()
	# Parent close requests cancellation through the same existing _exit_tree path.
	video = configure_video(viewer,"parent-close",config.ffmpeg,6); video.start_export()
	var parent_directory: String = video.active_directory
	check(video.pid > 0,"Parent-close scenario starts real worker")
	viewer.free(); await process_frame
	check(FileAccess.file_exists(parent_directory.path_join("cancel")),"Parent teardown requests graceful cancellation")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"timings":timings,"activity":activity,"parent_directory":parent_directory},"\t")); file.close()
	print("STATUS: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
