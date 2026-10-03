extends SceneTree
# UX1 evidence collector, not a product screen or UX2 component laboratory.
# Run with --path viewer --script ../tools/audit_ux1.gd -- --ux1-output=ABS.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
var out := ""
var view
var observations: Array = []
var checks: Array = []
var inventory: Array = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, description: String) -> void:
	checks.append({"passed":value,"description":description})
	if not value: push_error(description)

func settle() -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw

func controls(parent: Node) -> Array:
	var result: Array = []
	for child in parent.get_children():
		if child is Control: result.append(child)
		result.append_array(controls(child))
	return result

func rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func collect(parent: Node) -> Array:
	var rows: Array = []
	for item in controls(parent):
		var text := ""
		if item is Label or item is BaseButton or item is LineEdit: text = item.text
		var row := {"class":item.get_class(),"path":str(parent.get_path_to(item)),"text":text,"visible_in_tree":item.is_visible_in_tree(),"rect":rect(item.get_global_rect()),"minimum":str(item.get_combined_minimum_size()),"focus_mode":item.focus_mode,"tooltip":item.tooltip_text,"font_size":item.get_theme_font_size("font_size")}
		if item is OptionButton:
			row.options = []
			for i in range(item.item_count): row.options.append(item.get_item_text(i))
		if item is BaseButton: row.disabled = item.disabled
		rows.append(row)
	return rows

func capture(name: String, surface: Viewport = root) -> void:
	await settle()
	var image := surface.get_texture().get_image()
	check(image.save_png(out.path_join(name+".png")) == OK,"Saved "+name)
	observations.append({"name":name,"image_size":str(image.get_size()),"logical_rect":rect(surface.get_visible_rect()),"window_size":str(root.size),"panel_rect":rect(view.overlay_panel.get_global_rect()),"content_height":view.inspector_box.size.y,"scroll":view.shell.scroll.scroll_vertical,"timeline_rect":rect(view.timeline.get_global_rect()),"legend_rect":rect(view.legend.get_global_rect()),"controls":collect(view)})

func show_section(title: String) -> void:
	for key in view.sections: view.sections[key].visible = key == title
	await settle()
	view.shell.scroll.scroll_vertical = int(view.sections[title].position.y)
	await settle()

func wait_jobs() -> void:
	var began := Time.get_ticks_msec()
	while view.selection_controller.jobs.busy() and Time.get_ticks_msec()-began < 20000: await process_frame
	check(not view.selection_controller.jobs.busy(),"Bounded G4 request completed")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ux1-output="): out = arg.trim_prefix("--ux1-output=")
	if out.is_empty() or DisplayServer.get_name() == "headless": quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	view = Viewer.new();view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false);view.set_process_unhandled_input(false)
	await capture("01-empty")
	view._show_open_dialog();await capture("02-open-dialog")
	view.open_dialog.hide()
	view._open_capture(out.path_join("scene.wvz"))
	var began := Time.get_ticks_msec()
	while view.scene_layers.is_buffering() and Time.get_ticks_msec()-began < 15000:
		view.scene_layers.tick(0.0);await process_frame
	check(not view.scene_layers.is_buffering(),"Current particle/mesh/volume preparation completed")
	view._update_hud()
	await capture("03-loaded-default")
	inventory = collect(view)
	for width in [320,560]:
		view.panel_width = width;view.shell.layout()
		await capture("04-width-"+str(width))
	view.panel_width = 340;view.shell.layout()
	await show_section("Rendering");await capture("05-transport")
	await show_section("Capture / Export");await capture("06-export-actions")
	view.video_dialog.open();await capture("07-video-dialog")
	# The export actions stay fixed below the scrolling settings.
	await capture("07-video-actions")
	view.video_dialog.hide()
	view._show_recipe_dialog(true);await capture("08-recipe-dialog")
	view.recipe_dialog.hide()
	view._save_image();await capture("09-screenshot-folder")
	view.screenshot_dialog.canceled.emit();view.screenshot_dialog.hide()
	check(not view.screenshot_pending,"Screenshot folder cancellation clears pending state")
	var control = view.selection_controller
	control.bind_source();await wait_jobs()
	check(control.objects.has("particles"),"G4 source binding exposes particles")
	for i in range(control.target.item_count):
		if control.target.get_item_metadata(i) == "particles": control.target.select(i)
	control.members_input.text = "9007199254740993";control.name_input.text = "Exact ID example"
	control.create_definition();await wait_jobs()
	check(control.state.definitions.size() == 1,"Exact ID selection created through current controller")
	await show_section("Selections");await capture("10-selections")
	var temporal = control.temporal
	temporal.mode.select(2);temporal.full_range();temporal.run_analysis();await wait_jobs()
	check(not temporal.summaries.is_empty(),"Native population analysis produced a named result")
	await show_section("Temporal analysis");await capture("11-temporal")
	view.shell.scroll.ensure_control_visible(temporal.plot)
	await capture("11-temporal-plot")
	check(not temporal.plot.data.is_empty(),"Native result plot contains bounded source observations")
	for title in ["Diagnostics and comparisons","Space-time analysis","Analysis export and state","Matched runs","Geometry / Guides","Camera","Color Mapping"]:
		await show_section(title)
		await capture("panel-"+title.to_lower().replace(" / ","-").replace(" ","-"))
	for id in ["surface","density"]:
		for item in controls(view.scene_layers.panel):
			if item is Button and item.text == "Settings: "+id:
				item.button_pressed = true
				await settle()
				view.shell.scroll.ensure_control_visible(item)
				await capture("layer-"+id)
				item.button_pressed = false
	var expanded: Array = []
	for title in view.sections:
		var panel = view.sections[title]
		panel.visible = true
		for item in controls(panel):
			if item.has_meta("analysis_group"): item.button_pressed = true
		await settle()
		expanded.append({"section":title,"width":panel.size.x,"height":panel.size.y})
	for item in controls(view):
		if item.has_meta("analysis_group"): item.button_pressed = false
	await show_section("Rendering")
	view._toggle_overlay();await capture("12-hidden")
	check(view.shell.recovery.visible,"F1 leaves production mouse recovery reachable")
	view._toggle_overlay()
	var old_size := root.size
	root.size = Vector2i(1280,720);await capture("13-window-1280x720")
	root.size = old_size
	view._toggle_fullscreen();await settle()
	var full := {"mode":DisplayServer.window_get_mode(),"size":str(root.size),"logical_rect":rect(root.get_visible_rect())}
	view._toggle_fullscreen();await settle()
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,"Fullscreen restores windowed mode")
	# Same exact 4K render target / canvas scaling used by existing export UI tests.
	# This is not a claim about a physical 4K monitor or mixed-DPI behavior.
	var high := SubViewport.new();high.size = Vector2i(3840,2160);high.own_world_3d = true
	high.size_2d_override = Vector2i(1440,810);high.size_2d_override_stretch = true
	high.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(high)
	var original = view
	view = Viewer.new();view.capture_path = out.path_join("scene.wvz");view.playing = false;view.orbit_enabled = false;view.scene_prebuffer_enabled = false
	high.add_child(view);view.set_process(false);view.set_process_unhandled_input(false)
	await capture("14-4k-scaled-target",high)
	view.free();high.queue_free();view = original
	var failures := checks.filter(func(row):return not row.passed)
	Job.write_json(out.path_join("audit.json"),{"baseline":"47fef34dc5bdcbbc8db7f562f778deb100a70d5c","godot":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"screen_count":DisplayServer.get_screen_count(),"screen_size":str(DisplayServer.screen_get_size()),"screen_dpi":DisplayServer.screen_get_dpi(),"screen_scale":DisplayServer.screen_get_scale(),"root_content_scale_size":str(root.content_scale_size),"fullscreen":full,"checks":checks,"failures":failures,"sections":expanded,"inventory":inventory,"observations":observations})
	view.free();await process_frame
	print("UX1 AUDIT: ",checks.size()," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
