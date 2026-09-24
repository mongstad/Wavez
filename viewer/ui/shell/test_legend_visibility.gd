extends "res://ui/shell/test_fullscreen_restore.gd"
## Repeat the legend/recipe matrix at every native window restoration stage.

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
