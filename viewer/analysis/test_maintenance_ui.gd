extends SceneTree
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
const UI = preload("res://analysis/ui_controls.gd")
var out := ""
var checks := 0
var failures: Array = []
var images: Array = []
var surface: Viewport
var resolution := Vector2i(1440,900)
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func all_controls(parent: Node) -> Array:
	var result: Array = []
	for child in parent.get_children():
		if child is Control:result.append(child)
		result.append_array(all_controls(child))
	return result
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":return
	await process_frame;await RenderingServer.frame_post_draw
	var image := surface.get_texture().get_image()
	check(image.save_png(out.path_join(name+".png")) == OK,"saved "+name)
	images.append({"file":name+".png","width":image.get_width(),"height":image.get_height()})
func settle_style(view) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 10000:
		var result: Dictionary = view.scene_layers.sample(0.0,true)
		if not result.is_empty() and not result.has("pending"):return
		await process_frame
	check(false,"asynchronous particle style completed")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--maintenance-fixture="):out = arg.trim_prefix("--maintenance-fixture=")
		if arg.begins_with("--maintenance-resolution="):
			var dimensions := arg.trim_prefix("--maintenance-resolution=").split("x")
			resolution = Vector2i(int(dimensions[0]),int(dimensions[1]))
	if out.is_empty():quit(1);return
	# Production shell uses available logical size rather than a fixed 1440 canvas.
	root.size = resolution
	surface = root
	# The desktop may clamp windows below 4K. Use the same real GPU SubViewport
	# and canvas scaling as deterministic export, with an exact 4K render target.
	if resolution == Vector2i(3840,2160):
		var viewport := SubViewport.new();viewport.size = resolution;viewport.own_world_3d = true
		viewport.size_2d_override = Vector2i(1440,810);viewport.size_2d_override_stretch = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport);surface = viewport
	var view := Viewer.new();view.capture_path = out.path_join("scene.ssc");view.playing = false;view.orbit_enabled = false;surface.add_child(view);view.set_process(false)
	view._set_clean(true);view.color_channel = "fixed";view._restyle();view._update_hud()
	await settle_style(view)
	check(not view.legend.visible and view.legend.text.is_empty() and not view.colorbar.visible,"fixed color has no orphan legend")
	view._toggle_overlay();view._toggle_overlay()
	check(not view.legend.visible,"F1 does not resurrect fixed label")
	view.color_channel = "visual_color";view._update_particle_legend()
	check(not view.legend.visible and view.legend.text.is_empty(),"direct RGB has no scalar legend")
	view.color_channel = "value";view._restyle()
	await settle_style(view)
	check(view.legend.visible and view.colorbar.visible and "value" in view.legend.text,"scalar legend retained")
	await capture("legend-scalar")
	view.show_legend = false;view._update_particle_legend();check(not view.legend.visible,"show legend preference retained")
	view.show_legend = true;view._toggle_overlay();check(not view.legend.visible,"F1 hides scalar legend")
	view._toggle_overlay();check(view.legend.visible,"F1 restores scalar legend")
	view.color_channel = "fixed";view._restyle()
	await settle_style(view)
	for value in view.sections.values():value.visible = false
	var control = view.selection_controller;var temporal = control.temporal
	var before := Job.snapshot(view);var members: String = control.members_input.text
	for title in ["Selection","Temporal"]:
		view.tools_ui.open(title)
		var found := false
		for item in all_controls(view.tools_ui.form(title)):
			if item is OptionButton and item.has_meta("tool_pages"):
				found = true
				for i in item.item_count:item.select(i);item.item_selected.emit(i)
		check(found,"Task sections replace legacy nested groups: "+title)
		check(view.tools_ui.footers.has(title),"Primary actions stay outside scrolling sections: "+title)
		view.tools_ui.close()
	check(view.tools_ui.durable_controls.has("Data") and view.tools_ui.durable_controls.has("Save analysis"),"Primary export and recipe actions retained")
	check(Job.snapshot(view)==before and control.members_input.text==members,"Switching task sections changes no saved scientific or visual settings")
	check("incomplete" in temporal.finite_subtotal.tooltip_text and not temporal.finite_subtotal.tooltip_text.is_empty(),"incomplete subtotal meaning remains visible")
	check(not temporal.diagnostics.join.tooltip_text.is_empty() and not temporal.matched.common.coordinate_reference.tooltip_text.is_empty(),"clock and coordinate assumptions remain explained")
	check(view.open_dialog.filters[0].begins_with("*.ssc"),"modern capture picker is first")
	await capture("legend-fixed")
	var names := ["Selections","Temporal analysis","Diagnostics and comparisons","Space-time analysis","Analysis export and state","Matched runs"]
	var layouts: Array = []
	for title in names:
		view.tools_ui.open(view.tools_ui.SECTIONS[title])
		var panel: VBoxContainer = view.tools_ui.content.get_child(0)
		await process_frame;await process_frame
		var scroll: ScrollContainer = view.tools_ui.content.get_parent()
		scroll.scroll_vertical = int(panel.position.y)
		await process_frame;await process_frame
		var overflow: Array = []
		for item in all_controls(panel):
			if item.is_visible_in_tree() and item is BaseButton and item.get_global_rect().end.x > panel.get_global_rect().end.x+1:overflow.append(item.text)
		check(overflow.is_empty(),title+" default controls fit the panel width")
		await capture(title.to_lower().replace(" ","-"))
		# Select remaining task sections and verify controls are still reachable.
		for item in all_controls(panel):
			if item is OptionButton and item.has_meta("tool_pages"):item.select(item.item_count-1);item.item_selected.emit(item.selected)
		await process_frame;await process_frame
		overflow.clear()
		for item in all_controls(panel):
			if item.is_visible_in_tree() and item is BaseButton and item.get_global_rect().end.x > panel.get_global_rect().end.x+1:overflow.append(item.text)
		check(overflow.is_empty(),title+" expanded controls fit the panel width")
		layouts.append({"panel":title,"width":panel.size.x,"expanded_height":panel.size.y})
		for item in all_controls(panel):
			if item is OptionButton and item.has_meta("tool_pages"):item.select(0);item.item_selected.emit(0)
		view.tools_ui.close()
	check(control.jobs.worker_pid<0,"UI organization starts no background analysis")
	Job.write_json(out.path_join("ui.json"),{"checks":checks,"failures":failures,"backend":RenderingServer.get_current_rendering_method(),"images":images,"layouts":layouts,"viewport":str(surface.get_visible_rect()),"window":str(root.size),"surface":"GPU SubViewport" if surface != root else "desktop window"})
	view.free();print("MAINTENANCE UI: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
