extends SceneTree
const Viewer = preload("res://main.gd")
var viewer
var output: String
func _initialize(): run.call_deferred()
func settle():
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
func picture(name: String): root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run():
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer.shell.edge_reveal.set_process(false)
	await settle()
	viewer._open_capture(OS.get_cmdline_user_args()[1]); viewer.playing = false; viewer.orbit_enabled = false
	var deadline := Time.get_ticks_msec() + 15000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	assert(not viewer.scene_layers.is_buffering())
	viewer._sync_control_state(); viewer.shell.refresh(); await settle()
	viewer.shell.appearance.select(false); await settle()
	viewer.shell.status_ui.show_status(); await settle(); picture("details-dark"); viewer.shell.details.hide()
	viewer.open_dialog.use_native_dialog = false
	viewer.open_dialog.current_dir = OS.get_cmdline_user_args()[1].get_base_dir()
	viewer.open_dialog.popup_centered(Vector2i(900,600)); await settle(); picture("file-picker-dark"); viewer.open_dialog.hide()
	viewer.shell.appearance.select(true); await settle()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(3840,2160)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	await settle(); viewer.shell.layout(); await settle()
	assert(root.get_texture().get_image().get_size() == Vector2i(3840,2160))
	picture("light-3840x2160")
	viewer.queue_free(); await process_frame; quit()
