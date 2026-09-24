extends "res://ui/shell/test_fullscreen_restore.gd"
## Repeat the legend/recipe matrix at every native window restoration stage.

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-capture="): capture = arg.trim_prefix("--review-capture=")
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	await create_timer(.5).timeout
	var dock_rect: Rect2 = viewer.overlay_panel.get_rect()
	var transport_rect: Rect2 = viewer.shell.transport.get_rect()
	viewer._open_capture(capture)
	viewer.color_channel = "value"; viewer.show_legend = true; viewer._update_particle_legend()
	await create_timer(.5).timeout
	check(viewer.legend.is_visible_in_tree(), "First open shows scalar legend")
	check(viewer.legend.get_rect().end.y <= viewer.shell.transport.position.y-12, "First open legend clears playback")
	# A longer channel/range description can wrap only after Godot shapes the text.
	viewer.legend.text = "Scalar channel with a longer scientific description • viridis\n0.00000 → 1.70219 • auto per frame • linear"
	await create_timer(.2).timeout
	check(viewer.legend.get_rect().end.y <= viewer.shell.transport.position.y-12, "Late text growth clears playback without panel toggles")
	check(viewer.overlay_panel.get_rect() == dock_rect and viewer.shell.transport.get_rect() == transport_rect, "First open preserves panel geometry")
	print("FIRST OPEN GEOMETRY: ", JSON.stringify({"screen":root.current_screen,
		"screen_position":str(DisplayServer.screen_get_position(root.current_screen)),
		"screen_size":str(DisplayServer.screen_get_size(root.current_screen)),
		"legend_clearance":viewer.shell.transport.position.y-viewer.legend.get_rect().end.y,
		"panels_unchanged":viewer.overlay_panel.get_rect() == dock_rect and viewer.shell.transport.get_rect() == transport_rect}))
	viewer.free(); await process_frame
	if "--first-open-only" in OS.get_cmdline_user_args():
		print("FIRST OPEN: ", checks, " checks; ", failures.size(), " failures")
		quit(0 if failures.is_empty() else 1); return
	await super.run()

func checkpoint(label: String, expected: int, restore := "") -> void:
	await create_timer(.7).timeout
	var saved := Visual.snapshot(viewer)
	for enabled in [true, false]:
		for panels in [true, false]:
			var state := saved.duplicate(true)
			state["color_channel"] = "value"
			state["show_legend"] = enabled
			state["overlay_visible"] = panels
			Visual.apply(viewer, state)
			check(viewer.show_legend == enabled and viewer.overlay_visible == panels, label + " recipe restores independent values")
			for repeat in 3:
				check(viewer.legend.is_visible_in_tree() == enabled and viewer.colorbar.is_visible_in_tree() == enabled, label + " legend and colorbar follow preference")
				check(viewer.show_legend == enabled, label + " panel toggle preserves preference")
				var edge: float = viewer.overlay_panel.position.x-8 if viewer.overlay_visible else root.size.x
				check(absf(viewer.colorbar.position.x+viewer.colorbar.size.x-(edge-12)) < 1, label + " legend tracks right panel boundary")
				viewer._toggle_overlay()
				check(viewer.overlay_panel.visible == viewer.overlay_visible, label + " panel visibility synchronized")
			# Restore the saved pair after changing both controls.
			viewer.show_legend = not enabled
			Visual.apply(viewer, state)
			check(viewer.show_legend == enabled and viewer.overlay_visible == panels and viewer.legend.is_visible_in_tree() == enabled, label + " recipe restores legend visibility")
			if label == "manual":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("legend-%s-panels-%s.png" % [enabled, panels]))
	if label == "manual" or label == "maximized":
		viewer.color_channel = "value"; viewer.show_legend = true; viewer._update_particle_legend()
		viewer.shell.enter_immersive()
		await create_timer(.8).timeout
		check(viewer.legend.is_visible_in_tree(), label + " immersive legend visible")
		check(absf(viewer.colorbar.position.x+viewer.colorbar.size.x-(root.size.x-12)) < 1, label + " immersive right margin")
		check(absf(viewer.legend.position.y+viewer.legend.size.y-(root.size.y-12)) < 1, label + " immersive bottom margin")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(label+"-immersive-legend.png"))
		viewer.shell.exit_immersive()
		await create_timer(.8).timeout
	# Existing fixed-color modes still have no scalar legend.
	for channel in ["fixed", "visual_color"]:
		viewer.color_channel = channel; viewer.show_legend = true; viewer._update_particle_legend()
		check(not viewer.legend.visible and not viewer.colorbar.visible, label + " non-scalar color excludes legend")
	Visual.apply(viewer, saved)
	await super.checkpoint(label, expected, restore)
