extends SceneTree
## Production dialog audit and accepted-baseline presentation contracts.
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
const TITLES = ["Selection", "Temporal", "Space time", "Diagnostics", "Compare", "Matched runs", "Period", "Bookmarks", "Results", "Mapping", "Derive range", "Slice", "Clipping", "Isosurface", "Source probe", "Performance", "Geometry", "Image", "Data", "Save analysis", "Load analysis", "Camera", "Global effects"]
var viewer
var output := ""
var baseline := false
var checks := 0
var failures: Array[String] = []
var contracts := {}
var inventory := {}
var states := {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	for i in 6: await process_frame
	RenderingServer.force_draw(false)
func style(value: StyleBox) -> Dictionary:
	var result := {"class":value.get_class(), "minimum":str(value.get_minimum_size())}
	for property in value.get_property_list():
		var key: String = property.name
		if key.begins_with("content_margin_") or key.begins_with("border_width_") or key.begins_with("corner_radius_") or key.begins_with("expand_margin_") or key in ["bg_color","border_color","draw_center","anti_aliasing","shadow_color","shadow_size","shadow_offset"]:
			result[key] = str(value.get(key))
	return result
func record(button: Button) -> Dictionary:
	var role: String = button.theme_type_variation
	var original := role.trim_prefix("Dialog") if role.begins_with("Dialog") else role
	if original == "": original = "Button"
	var result := {"text":button.text,"role":original,"size":str(button.size) if button.is_visible_in_tree() else "hidden","in_tree_visible":button.is_visible_in_tree(),"font":button.get_theme_font("font").get_font_name(),"minimum":str(button.get_combined_minimum_size()),"custom_minimum":str(button.custom_minimum_size),"focus_mode":button.focus_mode,"focus_next":str(button.focus_next),"focus_previous":str(button.focus_previous),"disabled":button.disabled,"visible":button.visible,"tooltip":button.tooltip_text,"font_size":button.get_theme_font_size("font_size"),"styles":{},"colors":{}}
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]: result.styles[state] = style(button.get_theme_stylebox(state))
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color","icon_disabled_color"]: result.colors[state] = str(button.get_theme_color(state))
	return result
func audit(node: Node, context: String, path := "") -> void:
	if node is AcceptDialog:
		audit(node.get_ok_button(),context,path + "/ok")
		if node is ConfirmationDialog: audit(node.get_cancel_button(),context,path + "/cancel")
	if node.get_class() == "Button":
		var id := context + ":" + path
		contracts[id] = record(node)
		var role: String = node.theme_type_variation
		if not context.contains("-excluded-") and role in ["","Button","SecondaryButton","DialogButton","DialogSecondaryButton"]:
			if not inventory.has(context): inventory[context] = []
			inventory[context].append(node.text)
			if not baseline:
				check(role.begins_with("Dialog"), "Dialog action opted in: " + id + " " + node.text)
				var normal: StyleBoxFlat = node.get_theme_stylebox("normal")
				check(normal.bg_color.a == 1, "Opaque resting surface: " + id)
				check(normal.border_width_left == 1 and normal.border_width_top == 1 and normal.border_width_right == 1 and normal.border_width_bottom == 1, "Resting outline: " + id)
	for i in node.get_child_count():
		var child := node.get_child(i)
		if not child is Window: audit(child, context, path + "/" + str(i))
func picture(surface: Window, name: String) -> void:
	check(surface.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "Saved " + name)
func motion(window: Window, point: Vector2) -> void:
	var event := InputEventMouseMotion.new(); event.position = point
	if window.is_embedded(): event.position += Vector2(window.position); root.push_input(event)
	else: window.push_input(event)
func click(window: Window, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new(); event.position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	if window.is_embedded(): event.position += Vector2(window.position); root.push_input(event)
	else: window.push_input(event)
func key(window: Window, code: Key, reverse := false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.shift_pressed = reverse; event.pressed = true; event.window_id = window.get_window_id()
	Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func target_picture(video, button: Button, name: String) -> void:
	video.get_texture().get_image().get_region(Rect2i(button.get_global_rect().grow(4))).save_png(output.path_join(name + "-target.png"))
func video_states(video, name: String) -> void:
	var button: Button = video.background_button
	video.gui_release_focus(); motion(video, Vector2(1,1)); await settle()
	check(not button.has_focus() and not button.is_hovered(), "Unfocused/unhovered target " + name)
	states[name] = record(button)
	picture(video,name + "-normal"); target_picture(video,button,name + "-normal")
	motion(video,button.get_global_rect().get_center()); await settle()
	check(button.is_hovered(), "Actual hover " + name); picture(video,name + "-hover"); target_picture(video,button,name + "-hover")
	motion(video,Vector2(1,1)); button.grab_focus(); await settle()
	check(button.has_focus(), "Keyboard focus " + name); picture(video,name + "-focus"); target_picture(video,button,name + "-focus")
	video.gui_release_focus(); motion(video,button.get_global_rect().get_center())
	click(video,button.get_global_rect().get_center(),true); await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_PRESSED, "Actual pressed state " + name); picture(video,name + "-pressed"); target_picture(video,button,name + "-pressed")
	var status: Dictionary = video.job_status.duplicate(true)
	click(video,button.get_global_rect().get_center(),false); await settle()
	check(not video.visible and video.preparing and video.job_status == status, "Background dismiss preserves active job " + name)
	video.popup_centered(); button.disabled = true; motion(video,Vector2(1,1)); await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_DISABLED, "Disabled state " + name); picture(video,name + "-disabled"); target_picture(video,button,name + "-disabled")
	button.disabled = false
	video.start_button.grab_focus(); key(video,KEY_TAB); await settle()
	check(button.has_focus(), "Tab reaches background action " + name)
	key(video,KEY_TAB,true); await settle()
	check(video.start_button.has_focus(), "Shift-Tab returns to cancellation action " + name)
	key(video,KEY_TAB); key(video,KEY_ENTER); await settle()
	check(not video.visible and video.preparing and video.job_status == status,"Keyboard activation backgrounds same job " + name)
	video.popup_centered(); await settle()

func run() -> void:
	var args := OS.get_cmdline_user_args(); output = args[0]; baseline = args.size() > 1 and args[1] == "baseline"
	create_timer(180).timeout.connect(func(): push_error("Dialog actions timeout"); quit(1))
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer.shell.edge_reveal.set_process(false)
	viewer._open_capture(output.get_base_dir().path_join("mixed.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	var shell = viewer.shell
	var video = viewer.video_dialog
	video.set_process(false)
	for light in [false,true]:
		shell.appearance.light = light; shell.appearance.apply(); await settle()
		var palette := "light" if light else "dark"
		# Excluded application surfaces resolve exactly the accepted button styles.
		audit(shell.bar,palette + "-excluded-bar"); audit(shell.transport,palette + "-excluded-transport"); audit(shell.dock,palette + "-excluded-dock")
		for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
			root.size = dimensions; await settle()
			var context := palette + "-" + str(dimensions.x)
			for title in TITLES:
				viewer.tools_ui.open(title); await settle()
				audit(viewer.tools_ui.window,context + "-" + title)
				check(viewer.tools_ui.window.size.x <= dimensions.x and viewer.tools_ui.window.size.y <= dimensions.y, "Tool fits " + context + title)
				if title in ["Mapping","Diagnostics","Image"]: picture(viewer.tools_ui.window, context + "-" + title.to_lower())
				viewer.tools_ui.done_button.pressed.emit(); check(not viewer.tools_ui.window.visible, "Tool Close " + title)
			shell.show_source(); await settle(); audit(shell.details,context + "-details"); picture(shell.details,context + "-details"); shell.details.hide()
			shell.status_ui.open_jobs(); await settle(); audit(shell.status_ui.jobs_dialog,context + "-jobs"); picture(shell.status_ui.jobs_dialog,context + "-jobs")
			shell.status_ui.jobs_footer_close.pressed.emit(); await settle(); check(not shell.status_ui.jobs_dialog.visible and shell.status_ui.jobs_button.has_focus(), "Jobs Close restores focus")
			shell.about.open(); await settle(); audit(shell.about,context + "-about"); picture(shell.about,context + "-about")
			shell.about.licenses.pressed.emit(); await settle(); check(shell.about.license_page.visible and not shell.about.overview.visible,"About license navigation"); shell.about.hide()
			shell.edit_file_locations(); await settle(); audit(shell.file_locations_dialog,context + "-locations"); picture(shell.file_locations_dialog,context + "-locations")
			var preferences: Dictionary = viewer.file_locations.snapshot(); shell.file_locations_dialog.reset_button.pressed.emit(); shell.file_locations_dialog.dismiss()
			check(viewer.file_locations.snapshot() == preferences,"File Locations Cancel discards draft")
			shell.edit_shortcuts(); await settle(); audit(shell.shortcuts_editor,context + "-shortcuts"); picture(root,context + "-shortcuts")
			var bindings: Dictionary = shell.shortcuts.active.duplicate(); shell.shortcuts_editor.start_capture("reset_camera"); await settle()
			check(shell.shortcuts_editor.rows.reset_camera.key.theme_type_variation == "SelectedButton", "Shortcut listening retains selected style")
			shell.shortcuts_editor.clear_binding("reset_camera"); shell.shortcuts_editor.cancel.pressed.emit()
			check(shell.shortcuts.active == bindings and not shell.shortcuts_editor.visible,"Shortcut Cancel discards draft")
			video.open(); await settle(); audit(video,context + "-video-idle")
			var settings: Dictionary = video.settings(); video.close_button.pressed.emit(); check(not video.visible and video.settings() == settings,"Idle Video Cancel preserves range")
			video.open(); video.preparing = true; video.publish_job("preparing","Verifying the pinned selection recipe"); await settle()
			video.size = Vector2i(700,650) if dimensions.x == 1440 else Vector2i(560,360); video.popup_centered(video.size); await settle()
			audit(video,context + "-video-active"); await video_states(video,context + "-video")
			video.cancel_confirmation.popup_centered(); await settle(); audit(video.cancel_confirmation,context + "-cancel-export"); picture(video.cancel_confirmation,context + "-cancel-export")
			key(video.cancel_confirmation,KEY_ESCAPE); await settle(); check(not video.cancel_confirmation.visible and video.preparing,"Cancellation Escape leaves job running")
			var exit_dialog = preload("res://ui/shell/exit_confirmation.gd").new(); shell.add_child(exit_dialog); exit_dialog.setup(shell); exit_dialog.open(); await settle()
			audit(exit_dialog,context + "-exit"); picture(exit_dialog,context + "-exit"); exit_dialog.cancel_button.pressed.emit(); check(not exit_dialog.visible and video.preparing,"Exit Cancel leaves job running"); exit_dialog.queue_free()
			video.preparing = false; video.job_status = {}; video._sync_action_buttons(); video.hide(); await settle()
	# Theme round-trip must continue to resolve the resting surface on old dialogs.
	shell.appearance.light = false; shell.appearance.apply(); video.open(); await settle()
	check(video.background_button.get_theme_stylebox("normal").bg_color == shell.style_slice.theme.c(&"surface.1" if baseline else &"surface.2"),"Light-to-Dark dialog role round trip")
	var report := {"checks":checks,"failures":failures,"contracts":contracts,"inventory":inventory,"states":states,"standalone":not OS.has_feature("editor")}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	viewer.free(); await process_frame; RenderingServer.force_draw(false); await process_frame
	print("DIALOG ACTIONS: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
