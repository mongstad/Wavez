extends SceneTree
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
class ObservedViewer extends Viewer:
	var evidence := ""
	var job_directory := ""
	func _exit_tree() -> void:
		super._exit_tree()
		Job.write_json(evidence,{"normal_teardown":true,"job_directory":job_directory,"cancel_requested":not job_directory.is_empty() and FileAccess.file_exists(job_directory.path_join("cancel"))})
var output := ""
func _initialize() -> void: run.call_deferred()
func require(ok: bool, label: String) -> bool:
	if not ok: push_error(label); quit(1)
	return ok
func run() -> void:
	var args := OS.get_cmdline_user_args(); output = args[0]
	create_timer(30).timeout.connect(func(): push_error("Exit timeout"); quit(1))
	var view := ObservedViewer.new(); view.evidence = output.path_join("closed.json")
	view.capture_path = args[1] if args[3] == "active" else output.path_join("no-capture.wvz")
	view.playing = false; view.orbit_enabled = false; root.add_child(view)
	if args[2] == "fullscreen": view._toggle_fullscreen(); view.shell.edge_reveal.states.top.visible = true; view.shell.layout()
	elif args[2] == "maximized": root.mode = Window.MODE_MAXIMIZED
	if args[3] == "active":
		var video = view.video_dialog
		video.open(); video.range_choice.select(2); video.update_range()
		video.start.value = 0; video.end.value = 2; video.rate.value = 1
		video.width.value = 512; video.height.value = 512; video.fps.value = 30
		video.overlays.button_pressed = false; video.output.text = output.path_join("video.mp4"); video.ffmpeg = "/usr/bin/ffmpeg"
		video.start_export(); video.hide()
		if not require(video.pid > 0,"Real export worker started"): return
		view.job_directory = video.active_directory
		var deadline := Time.get_ticks_msec()+10000
		while not FileAccess.file_exists(view.job_directory.path_join("progress.json")) and Time.get_ticks_msec()<deadline: await process_frame
		if not require(video.pid > 0,"Export is active at exit"): return
	view.shell.refresh_commands()
	var file: PopupMenu = view.shell.menus.File.get_popup(); var last := file.item_count-1
	if not require(file.get_item_text(last) == "Exit" and file.is_item_separator(last-1) and not file.is_item_disabled(last),"Exit is enabled and final, after separator"): return
	file.popup()
	for i in 3: await process_frame
	RenderingServer.force_draw(false)
	if args[3] == "idle" and args[2] == "windowed": root.get_texture().get_image().save_png(output.path_join("menu.png"))
	Job.write_json(output.path_join("before.json"),{"mode":args[2],"work":args[3],"job_directory":view.job_directory,"exit_enabled":not file.is_item_disabled(last)})
	file.id_pressed.emit(file.get_item_id(last))
