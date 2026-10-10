extends SceneTree
## Production shell palette, geometry, persistence and scientific isolation audit.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	for i in 5: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func picture(name: String) -> void:
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name+".png"))
func contract(node: Node, result := {}) -> Dictionary:
	if node is Control:
		result[node.get_instance_id()] = [node.position if node.is_visible_in_tree() else Vector2.ZERO, node.size if node.is_visible_in_tree() else Vector2.ZERO, node.custom_minimum_size, node.get_combined_minimum_size() if node.is_visible_in_tree() else Vector2.ZERO, node.tooltip_text, node.focus_mode, node.focus_next, node.focus_previous, node.get_theme_font_size("font_size"), node.get_theme_font("font").get_font_name()]
	elif node is Window:
		result[node.get_instance_id()] = [node.position if node.visible else Vector2i.ZERO, node.size if node.visible else Vector2i.ZERO, node.title, node.min_size]
	for child in node.get_children(): contract(child,result)
	return result
func compare(expected: Dictionary, label: String) -> void:
	var actual := contract(viewer)
	for id in expected:
		if actual.has(id) and actual[id] != expected[id] and failures.size() < 4: print(instance_from_id(id).get_path(), " BEFORE ", expected[id], " AFTER ", actual[id])
		check(actual.has(id) and actual[id] == expected[id], label+" geometry/typography/tooltip/focus "+str(id))
func switch(value: bool) -> void:
	viewer.shell.appearance.light = value; viewer.shell.appearance.apply()
	await settle()
func cycle(label: String) -> void:
	await switch(false)
	var before := contract(viewer)
	var scientific := Visual.snapshot(viewer)
	await switch(true)
	compare(before,label+" Light")
	check(Visual.snapshot(viewer) == scientific,label+" scientific state unchanged")
	picture(label+"-light")
	await switch(false)
	compare(before,label+" Dark restored")
	picture(label+"-dark")
func review_states() -> void:
	# Palette review at actual supported dimensions, including clipped/disabled states.
	var shell = viewer.shell
	for size in [Vector2i(1440,900), Vector2i(970,600)]:
		root.size = size; await settle(); shell.layout(); await settle()
		shell.select_workspace(0)
		for title in viewer.section_buttons: viewer.section_buttons[title].button_pressed = true
		await settle()
		shell.scroll.scroll_vertical = 0; await settle()
		await cycle("expanded-%dx%d" % [size.x,size.y])
		shell.scroll.scroll_vertical = 100000; await settle()
		check(shell.scroll.scroll_vertical > 0, "Expanded controls scroll at " + str(size))
		await cycle("scrolled-%dx%d" % [size.x,size.y])
		for title in viewer.section_buttons: viewer.section_buttons[title].button_pressed = false
		shell.scroll.scroll_vertical = 0
	root.size = Vector2i(1440,900); await settle(); shell.layout(); await settle()
	viewer.tools_ui.open("Global effects"); await settle()
	viewer.glow_slider.grab_focus(); await settle()
	await cycle("global-focused")
	viewer.tools_ui.close(false)
	var popup: PopupMenu = shell.menus["View"].get_popup()
	popup.popup(Rect2i(100,100,0,0)); popup.set_focused_item(0); await settle()
	await cycle("view-menu-selected")
	popup.hide()
	viewer.section_buttons.Rendering.button_pressed = true; await settle()
	var target: Button = viewer.section_buttons.Rendering
	var motion := InputEventMouseMotion.new(); motion.position = target.get_global_rect().get_center()
	root.push_input(motion); await create_timer(.12).timeout; await settle()
	check(target.is_hovered(), "Native pointer highlights Rendering disclosure")
	await cycle("disclosure-hover")
	motion.position = Vector2(50,50); root.push_input(motion); await settle()
	viewer.section_buttons.Rendering.button_pressed = false
	var badge = shell.status_ui.badge
	var status_processing: bool = shell.status_ui.is_processing()
	shell.status_ui.set_process(false)
	for severity in ["success", "warning", "error"]:
		badge.configure(severity, "Palette review: " + severity); await settle()
		await cycle("status-" + severity)
	shell.status_ui.set_process(status_processing)
	shell.status_ui.refresh()

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(180).timeout.connect(func():push_error("Theme audit timeout");quit(1))
	viewer = Viewer.new();viewer.scene_prebuffer_enabled = false;root.add_child(viewer);viewer.set_process(false)
	viewer.shell.edge_reveal.set_process(false)
	await settle()
	var appearance = viewer.shell.appearance
	if OS.get_cmdline_user_args().size() > 1:
		var expected: bool = OS.get_cmdline_user_args()[1] == "Light"
		check(appearance.light == expected,"Fresh process restores selected theme")
		check(viewer.shell.about.logo.texture == (viewer.shell.about.LightLogo if expected else viewer.shell.about.Logo),"Fresh process selects official logo")
		if expected:
			check(viewer.shell.about.github.get_theme_color("font_color") == viewer.shell.about.theme.c(&"accent.primary"),"Light links use readable accent ink")
			check(viewer.shell.about.browser_error.get_theme_color("default_color") == viewer.shell.about.theme.c(&"text.primary"),"Light rich text uses readable primary ink")
		viewer.shell.about.open();await settle()
		picture("restart-"+OS.get_cmdline_user_args()[1])
		appearance.select(not expected)
	else:
		viewer.shell.refresh_commands()
		check(not viewer.shell.commands.theme_light.popup.is_item_disabled(viewer.shell.commands.theme_light.index),"Theme selection available before capture")
		await cycle("empty")
		if not failures.is_empty(): quit(1); return
		viewer._open_capture(output.path_join("mixed.wvz"));viewer.playing = false;viewer.orbit_enabled = false
		var deadline := Time.get_ticks_msec()+15000
		while viewer.scene_layers.is_buffering() and Time.get_ticks_msec()<deadline:
			viewer.scene_layers.tick(0);await process_frame
		check(not viewer.scene_layers.is_buffering(),"Mixed fixture ready")
		# Establish an actual committed sample before palette/scientific pixel comparisons.
		var sample: Dictionary = viewer.scene_layers.sample(viewer.requested_time, false)
		check(not sample.is_empty() and not viewer.scene_layers.current.is_empty(),"Mixed fixture committed for theme comparison")
		viewer._sync_control_state();viewer.shell.refresh();await settle()
		for size in [Vector2i(1440,900),Vector2i(1024,640)]:
			root.size = size;await settle();viewer.shell.layout();await settle()
			for workspace in 3:
				viewer.shell.select_workspace(workspace);await settle()
				await cycle("shell-%dx%d-%d" % [size.x,size.y,workspace])
			viewer.shell.about.open();await settle()
			await cycle("about-%dx%d" % [size.x,size.y])
			await switch(true)
			check(viewer.shell.about.logo.texture == viewer.shell.about.LightLogo,"Light uses official logo")
			viewer.shell.about.hide()
			viewer.shell.about.open();await settle()
			await switch(false)
			check(viewer.shell.about.get_theme_stylebox("panel").bg_color == viewer.shell.style_slice.theme.c(&"surface.3"),"About reopened in Light restores exact dark surface")
			viewer.shell.about.hide()
		root.size = Vector2i(1440,900);await settle()
		for title in ["Mapping","Performance","Global effects","Source probe","Geometry","Data","Selection"]:
			viewer.tools_ui.open(title);await settle();await cycle("tool-"+title.replace(" ","-"));viewer.tools_ui.close(false)
		await review_states()
		viewer.shell.status_ui.open_jobs();await settle();await cycle("jobs");viewer.shell.status_ui.jobs_dialog.hide()
		viewer.shell.edit_shortcuts();await settle();await cycle("shortcuts");viewer.shell.shortcuts_editor.dismiss()
		viewer.shell.edit_file_locations();await settle();await cycle("locations");viewer.shell.file_locations_dialog.dismiss()
		viewer.video_dialog.open();await settle();await cycle("video");viewer.video_dialog.hide()
		viewer.shell.status_ui.show_status();await settle();await cycle("details");viewer.shell.details.hide()
		viewer.open_dialog.use_native_dialog = false
		viewer.open_dialog.popup_centered(Vector2i(900,600));await settle();await cycle("file-picker");viewer.open_dialog.hide()
		await switch(false)
		for side in viewer.shell.edge_reveal.states:
			var pinned: bool = viewer.shell.edge_reveal.states[side].pinned
			viewer.shell.edge_reveal.set_pinned(side,not pinned)
			var state: Dictionary = viewer.shell.edge_reveal.states[side].duplicate(true)
			await switch(true)
			check(viewer.shell.edge_reveal.states[side] == state,"Theme preserves pin/edge state: "+side)
			await switch(false)
			viewer.shell.edge_reveal.set_pinned(side,pinned)
		await settle()
		var count: int = appearance.applications
		for i in 20: await process_frame
		check(appearance.applications == count,"No idle theme rebuild loop")
		var legend_theme = viewer.legend.theme
		var legends_theme = viewer.shell.layer_legends.theme
		viewer.shell.prepare_export({});viewer.shell.dock.hide();viewer.resize_handle.hide();await settle()
		picture("scientific-dark")
		var pixels: PackedByteArray
		if DisplayServer.get_name() != "headless": pixels = root.get_texture().get_image().get_data()
		await switch(true)
		picture("scientific-light")
		check(viewer.legend.theme == legend_theme and viewer.shell.layer_legends.theme == legends_theme,"Scientific legend resources unchanged")
		if DisplayServer.get_name() != "headless":check(root.get_texture().get_image().get_data() == pixels,"Viewport-only scientific pixels unchanged")
		appearance.select(true)
		check(appearance.light,"Light preference saved")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"\t"));file.close()
	viewer.queue_free();await process_frame
	print("APPLICATION THEME: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
