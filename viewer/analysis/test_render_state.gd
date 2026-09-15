extends SceneTree
const Viewer = preload("res://main.gd")
var out := ""
var sidecar := ""
var show_particles := false
func _initialize() -> void:run.call_deferred()
func wait_jobs(control) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 20000:
		await create_timer(.01).timeout
		if not control.jobs.busy():return control.jobs.error.is_empty()
	return false
func run() -> void:
	create_timer(45).timeout.connect(func():push_error("G4 render-state setup timed out");quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--g4-render-fixture="):out = arg.trim_prefix("--g4-render-fixture=")
		if arg.begins_with("--verify-sidecar="):sidecar = arg.trim_prefix("--verify-sidecar=")
		if arg == "--g4-render-visible":show_particles = true
	if out.is_empty():quit(1);return
	if not sidecar.is_empty():root.content_scale_size = Vector2i(1440,810);root.size = Vector2i(640,360)
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer);await process_frame
	viewer._open_capture(out.path_join("pulse.ssc"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller
	control.bind_source()
	if not await wait_jobs(control):push_error(control.status.text);quit(1);return
	if not sidecar.is_empty():
		control.temporal.durable.load_from(sidecar)
		if not await wait_jobs(control) or not control.temporal.durable.last_recipe.get("restored",false):push_error("Frame restore: "+control.temporal.status.text+" / "+control.temporal.durable.status.text);quit(1);return
		if control._time() != .25 or control.state.definitions.size()!=1:push_error("Frame time/selection did not restore");quit(1);return
		if await viewer._capture_inspection_png(out.path_join("replayed.png"),true) != OK:push_error("PNG capture: "+control.temporal.durable.status.text);quit(1);return
		viewer.queue_free();await process_frame;quit();return
	control._request("define_selection",{"key":"endpoints","object":"p","kind":"particle_ids","selector":{"ids":["0","40"]}})
	if not await wait_jobs(control):push_error(control.status.text);quit(1);return
	control.state.overlay.show_hidden = true
	viewer.scene_layers.states.field.visible = false;viewer.particle_layer_visible = show_particles;viewer.scene_layers.resample()
	viewer._set_clean(true);viewer.overlay_visible = false;viewer.overlay_panel.visible = false;viewer.show_legend = false
	viewer.camera_target = Vector3(1,0,0);viewer.camera_distance = 8;viewer.camera.position = Vector3(1,0,8);viewer.camera.look_at(viewer.camera_target)
	viewer.camera.fov = 45;viewer.camera.near = .01;viewer.camera.far = 100
	viewer.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR;viewer.environment.tonemap_exposure = 1
	control.temporal.durable.save_to(out.path_join("recipe.inspection"),true)
	if not await wait_jobs(control) or not control.temporal.durable.last_recipe.has("path"):push_error(control.temporal.status.text+" / "+control.temporal.durable.status.text);quit(1);return
	var file := FileAccess.open(out.path_join("setup.json"),FileAccess.WRITE);file.store_string(JSON.stringify(control.temporal.durable.last_recipe));file.close()
	viewer.queue_free();await process_frame;quit()
