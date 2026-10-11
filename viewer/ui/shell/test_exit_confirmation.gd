extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func key(code: Key, window: Window, reverse := false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	event.window_id = window.get_window_id(); event.shift_pressed = reverse
	Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func science() -> Dictionary:
	var state := Visual.snapshot(viewer); state.erase("overlay_visible"); state.erase("panel_width"); return state
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("scene.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	var deadline := Time.get_ticks_msec()+15000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()<deadline:
		viewer.scene_layers.tick(0); await process_frame
	check(not viewer.scene_layers.is_buffering(), "Synthetic source ready")
	var shell = viewer.shell; var chrome = shell.window_chrome; var status = shell.status_ui
	var jobs = viewer.selection_controller.jobs; var video = viewer.video_dialog; var matched = viewer.selection_controller.temporal.matched
	check(not auto_accept_quit, "Native automatic quit is disabled for the interactive viewer")
	check(not status.has_active_jobs(), "Idle worker/source preparation is not an active Jobs operation")
	for stage in ["complete","frames_ready","failed","cancelled"]:
		video.job_status = {"stage":stage}; check(not status.has_active_jobs(), stage+": terminal video does not prompt")
	video.job_status.clear()
	var original := science(); var sample: Dictionary = viewer.committed_sample.duplicate(true); var camera: Transform3D = viewer.camera.transform
	for kind in ["video","selections","analysis","selection-cancelling","analysis-cancelling","matched-preparing","isosurface","multiple"]:
		video.pid = preload("res://video/test_worker_process.gd").start() if kind in ["video","multiple"] else -1
		jobs.pending = kind in ["selections","multiple"]; jobs.background_pending = kind == "analysis"
		jobs.foreground_cancel_id = "pending-ack" if kind == "selection-cancelling" else ""
		jobs.background_cancel_id = "pending-ack" if kind == "analysis-cancelling" else ""
		matched.preparing = kind == "matched-preparing"
		viewer.scene_layers.iso_pid = OS.get_process_id() if kind == "isosurface" else -1
		check(status.has_active_jobs(), kind+": live shared Jobs row is active")
		for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
			root.size = dimensions; await settle(); shell.layout(); shell.transport.rate.grab_focus()
			chrome.request_close(); await settle(); var dialog = chrome.exit_confirmation
			check(dialog.visible and dialog.cancel_button.has_focus(), kind+": confirmation opens with safe Cancel focus")
			check(dialog.exit_button.text == "Exit WAVEZ" and dialog.cancel_button.text == "Cancel" and shell.focus_navigation.chain(dialog).size() == 2, "Exactly two interactive choices")
			var id: int = dialog.get_instance_id(); chrome.request_close(); chrome.request_close(); await settle()
			check(chrome.exit_confirmation.get_instance_id() == id and dialog.visible, "Repeated closes reuse one confirmation")
			key(KEY_TAB,dialog); await settle(); check(dialog.exit_button.has_focus(), "Tab wraps to Exit inside dialog")
			key(KEY_TAB,dialog,true); await settle(); check(dialog.cancel_button.has_focus(), "Shift+Tab returns to Cancel inside dialog")
			await RenderingServer.frame_post_draw
			if kind in ["video","multiple"]: root.get_texture().get_image().save_png(output.path_join(kind+"-"+str(dimensions.x)+".png"))
			key(KEY_ENTER,dialog); await settle()
			check(not dialog.visible and shell.transport.rate.has_focus(), "Enter on default Cancel dismisses and restores initiator")
			check(status.has_active_jobs(), "Cancel leaves all active owners running")
			chrome.request_close(); await settle(); key(KEY_ESCAPE,dialog); await settle()
			check(not dialog.visible and status.has_active_jobs(), "Escape dismisses without cancelling work")
			chrome.request_close(); await settle(); dialog.close_requested.emit(); await settle()
			check(not dialog.visible and status.has_active_jobs(), "Window dismissal is Cancel")
			check(science() == original and viewer.committed_sample == sample and viewer.camera.transform == camera and not viewer.playing, "Prompt/cancellation leaves science, playback and camera unchanged")
		preload("res://video/test_worker_process.gd").stop(video); video.job_status.clear(); jobs.pending = false; jobs.background_pending = false
		jobs.foreground_cancel_id = ""; jobs.background_cancel_id = ""; matched.preparing = false; viewer.scene_layers.iso_pid = -1
		check(not status.has_active_jobs(), "Terminal/idle owners no longer prompt")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t")); file.close()
	viewer.free(); await process_frame; print("EXIT CONFIRMATION: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
