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
				viewer._toggle_overlay()
				check(viewer.overlay_panel.visible == viewer.overlay_visible, label + " panel visibility synchronized")
			# Restore the saved pair after changing both controls.
			viewer.show_legend = not enabled
			Visual.apply(viewer, state)
			check(viewer.show_legend == enabled and viewer.overlay_visible == panels and viewer.legend.is_visible_in_tree() == enabled, label + " recipe restores legend visibility")
			if label == "manual":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("legend-%s-panels-%s.png" % [enabled, panels]))
	# Existing fixed-color modes still have no scalar legend.
	for channel in ["fixed", "visual_color"]:
		viewer.color_channel = channel; viewer.show_legend = true; viewer._update_particle_legend()
		check(not viewer.legend.visible and not viewer.colorbar.visible, label + " non-scalar color excludes legend")
	Visual.apply(viewer, saved)
	await super.checkpoint(label, expected, restore)
