extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Requires actual UI layout/rendering");quit(1);return
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var viewer = load("res://main.gd").new()
	viewer.capture_path = ProjectSettings.globalize_path("res://../results/identity-demo.ssc")
	var out := ProjectSettings.globalize_path("res://../results/hud-fix")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-fixture="):viewer.capture_path = arg.trim_prefix("--hud-fixture=")
		if arg.begins_with("--hud-output="):out = arg.trim_prefix("--hud-output=")
	viewer.playing = false;viewer.orbit_enabled = false;viewer.scene_prebuffer_enabled = false
	root.add_child(viewer);viewer.set_process(false)
	var rows: Array = [];var failures := 0
	for width in [290,366,600]:
		viewer.panel_width = width;viewer._layout_inspector(viewer.resize_handle)
		for navigation in ["time","sample"]:
			var heights: Array = [];var controls: Array = []
			for t in [6.9,6.95,7.0,7.05,9.9,9.95,10.0]:
				if navigation == "time": viewer._seek_time(t)
				else:
					viewer._seek_frame(int(round(t*10)))
					viewer._render_current(0.0 if t == floor(t*10)/10 else 0.5);viewer._update_hud()
				await settle()
				heights.append(viewer.hud.size.y);controls.append(viewer.status_label.position.y)
			if heights.max() != heights.min() or controls.max() != controls.min(): failures += 1
			rows.append({"width":width,"navigation":navigation,"hud_heights":heights,"control_positions":controls})
	DirAccess.make_dir_recursive_absolute(out)
	preload("res://video/render_job.gd").write_json(out.path_join("before.json" if baseline else "after.json"),{"cases":rows,"layout_changes":failures})
	root.get_texture().get_image().save_png(out.path_join("before.png" if baseline else "after.png"))
	viewer.free();await process_frame
	print("HUD LAYOUT: %d / 6 cases change height or shift controls" % failures)
	quit(0 if baseline or failures == 0 else 1)
