extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var viewer = load("res://main.gd").new();viewer.capture_path = ProjectSettings.globalize_path("res://../results/g3/small.wvz");viewer.playing = false;viewer.orbit_enabled = false
	root.add_child(viewer);viewer.set_process(false)
	if viewer.frame_a == null:push_error(viewer.status_label.text);quit(1);return
	viewer._set_clean(true);viewer.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewer.scene_layers.sample(.5)
	viewer.scene_layers.states.density.slice = true;viewer.scene_layers.resample()
	viewer.scene_layers.request_iso("density")
	if not await viewer.scene_layers.wait_for_surface():push_error(viewer.scene_layers.iso_error);quit(1);return
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../results/g3/initial-render.png"))
	print("G3 INITIAL ",viewer.committed_sample)
	viewer.free();await process_frame;quit()
