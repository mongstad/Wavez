extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var shell
var nav
var output := ""
var checks := 0
var failures: Array[String] = []
var walks: Array = []
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	for i in 4: await process_frame
func ready():
	var deadline := Time.get_ticks_msec() + 15000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	check(not viewer.scene_layers.is_buffering(), "Source ready")
	shell.transport.refresh(); await settle()
func key(code: Key, reverse := false, window = root):
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; event.shift_pressed = reverse; event.window_id = window.get_window_id()
	Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func click(point: Vector2, double := false):
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.position = point; event.pressed = true; event.double_click = double;root.push_input(event)
	var release := event.duplicate();release.pressed = false;release.double_click = false;root.push_input(release)
func category(control: Control) -> String:
	if control == null:return "null"
	for pair in [[shell.bar,"top"],[shell.dock,"right"],[shell.transport,"playback"],[shell.status_ui,"status"]]:
		if pair[0] == control or pair[0].is_ancestor_of(control): return pair[1]
	return "other"
func label(control: Control) -> String:
	if control == null: return "null"
	return str(control.get_path()) + " " + (control.text if control is BaseButton or control is Label else control.get_class())
func science() -> Dictionary:
	var state := Visual.snapshot(viewer); state.erase("overlay_visible");state.erase("panel_width");return state
func first_in(region: Node) -> Control:
	for control in nav.chain(root):
		if region == control or region.is_ancestor_of(control): return control
	return null
func walk(name: String, window = root):
	var state := science(); var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var pose: Transform3D = viewer.camera.transform; var playing: bool = viewer.playing
	var available: Array = nav.chain(window)
	check(not available.is_empty(), name + ": interactive controls exist")
	if available.is_empty(): return
	available[0].grab_focus(); await settle()
	var seen: Array = [window.gui_get_focus_owner()]
	for i in available.size():
		key(KEY_TAB, false, window); await settle()
		var control: Control = window.gui_get_focus_owner()
		check(nav.eligible(control,window), name + ": Tab never reaches hidden/disabled control")
		if control == seen[0]: break
		check(not control in seen, name + ": no premature repeated focus")
		seen.append(control)
	check(seen.size() == available.size(), name + ": all eligible controls reachable once")
	for i in seen.size():
		key(KEY_TAB,true,window); await settle()
		check(window.gui_get_focus_owner() == seen[posmod(seen.size()-1-i,seen.size())], name + ": Shift+Tab exactly reverses forward order")
	var order: Array = []
	for control in seen:order.append(label(control))
	walks.append({"state":name,"order":order})
	check(science() == state and sample == viewer.committed_sample and pose == viewer.camera.transform and playing == viewer.playing,name+": traversal preserves scientific state, sample, camera and playback")
	if window == root and nav.active_overlay() == null:
		var ranks := {"top":0,"other":1,"right":2,"playback":3,"status":4};var previous := -1
		for control in seen:
			var rank: int = ranks[category(control)];check(rank >= previous,name+": global visual region order");previous = rank
func hide_side(side: String):
	shell.edge_reveal.states[side].visible = false;shell.layout();await settle()
func show_side(side: String):
	shell.edge_reveal.states[side].visible = true;shell.layout();await settle()
func dialog_walk(window: Window, name: String):
	await settle();check(nav.active_window() == window,name+": active scope selected")
	await walk(name,window)
	check(window.gui_get_focus_owner() != null and window.is_ancestor_of(window.gui_get_focus_owner()),name+": focus contained")
func run():
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new();root.add_child(viewer);viewer.set_process(false)
	shell = viewer.shell;nav = shell.focus_navigation;shell.edge_reveal.set_process(false)
	viewer._open_capture(output.path_join("scene.wvz"));viewer.playing = false;viewer.orbit_enabled = false;await ready()
	var original := science();var sample: Dictionary = viewer.committed_sample.duplicate(true);var camera: Transform3D = viewer.camera.transform
	for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
		root.size = dimensions;await settle();shell.layout();await settle()
		await walk("baseline-"+str(dimensions.x))
	check(science() == original and viewer.committed_sample == sample and viewer.camera.transform == camera and not viewer.playing,"Traversal leaves science, camera and playback unchanged")
	for menu in shell.menus.values(): check(menu in nav.chain(root),"Top menu is keyboard reachable: "+menu.text)
	check(shell.navigation.get_child(2) in nav.chain(root),"Navigate menu is keyboard reachable")
	for action in shell.window_chrome.actions.get_children():check(action in nav.chain(root),"Window action is keyboard reachable")
	var view_menu: MenuButton = shell.menus.View;view_menu.grab_focus();key(KEY_ENTER);await settle()
	check(view_menu.get_popup().visible,"Enter opens focused menu")
	key(KEY_ESCAPE,false,view_menu.get_popup());await settle();check(not view_menu.get_popup().visible,"Native menu Escape remains available")
	for side in ["top","right","bottom"]:
		var region: Control = {"top":shell.bar,"right":shell.dock,"bottom":shell.bottom_strip}[side]
		first_in(region).grab_focus();await settle();await hide_side(side)
		var expected: Control = {"top":shell.edge_reveal.pins.right,"right":shell.transport.actions.get_child(0),"bottom":shell.navigation.get_child(0)}[side]
		check(root.gui_get_focus_owner() == expected,side+": handoff advances beyond entire hidden region")
		await walk(side+"-hidden")
		var prior := root.gui_get_focus_owner();await show_side(side)
		check(root.gui_get_focus_owner() == prior,side+": reveal does not pull focus back")
	shell.transport.rate.grab_focus();await hide_side("right");await show_side("right")
	key(KEY_TAB);await settle();check(root.gui_get_focus_owner() == shell.transport.loop,"Reappearing panel preserves next logical bottom control")
	for side in ["top","right","bottom"]:
		shell.edge_reveal.set_pinned(side,false)
		shell.edge_reveal.keyboard_navigation = false;first_in(shell.edge_reveal.controls(side)[0]).grab_focus()
		shell.edge_reveal.tick(.36,Vector2(100,200),false,false);await settle()
		check(not shell.edge_reveal.states[side].visible,side+": auto-hide timing unchanged")
		check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(),side+": auto-hide rehomes focus")
		var point: Vector2 = {"top":Vector2(500,1),"right":Vector2(root.size.x-1,300),"bottom":Vector2(500,root.size.y-1)}[side]
		var prior := root.gui_get_focus_owner();shell.edge_reveal.tick(.49,point,true,false);check(not shell.edge_reveal.states[side].visible,side+": dwell not early")
		shell.edge_reveal.tick(.02,point,true,false);await settle();check(shell.edge_reveal.states[side].visible and root.gui_get_focus_owner() == prior,side+": edge reveal enters order without stealing focus")
		shell.edge_reveal.set_pinned(side,true)
	for side in ["top","right","bottom"]:shell.edge_reveal.set_pinned(side,false)
	shell.edge_reveal.keyboard_navigation = false;shell.edge_reveal.tick(.36,Vector2(100,200),false,false);await settle()
	check(nav.chain(root).is_empty() and root.gui_get_focus_owner() == null,"All hidden: no hidden focus or focus trap")
	key(KEY_TAB);await settle();check(root.gui_get_focus_owner() == null,"No eligible control: Tab safely leaves viewport focus")
	await show_side("right");check(root.gui_get_focus_owner() == null,"First reveal alone does not reset focus")
	key(KEY_TAB);await settle();check(category(root.gui_get_focus_owner()) == "right","Revealed controls are keyboard reachable")
	for side in ["top","right","bottom"]:shell.edge_reveal.set_pinned(side,true)
	await settle()
	shell.select_workspace(0);var body: Control = viewer.sections["Rendering"];body.show();await settle()
	var child := first_in(body);check(child != null,"Expanded section has interactive child")
	child.grab_focus();await settle();body.hide();await settle()
	check(root.gui_get_focus_owner() != null and not body.is_ancestor_of(root.gui_get_focus_owner()) and root.gui_get_focus_owner().is_visible_in_tree(),"Collapse rehomes beyond entire body")
	check(first_in(body) == null,"Collapsed controls absent")
	var prior := root.gui_get_focus_owner();viewer.section_buttons["Rendering"].grab_focus();key(KEY_SPACE);await settle();check(body.visible,"Keyboard opens disclosure")
	key(KEY_SPACE);await settle();check(not body.visible,"Keyboard closes disclosure")
	prior.grab_focus();body.show();await settle();check(root.gui_get_focus_owner() == prior,"Expanding does not steal focus")
	for index in [1,2,0]:
		var old := first_in(shell.scroll)
		if old != null:old.grab_focus()
		shell.select_workspace(index);await settle()
		check(root.gui_get_focus_owner() == null or root.gui_get_focus_owner().is_visible_in_tree(),"Category change never strands stale focus")
		await walk("category-"+str(index))
	shell.select_workspace(2);await settle();first_in(shell.scroll).grab_focus();await settle()
	viewer._open_capture(output.path_join("replacement.wvz"));viewer.playing = false;await ready()
	check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(),"Source rebuild recovers removed-control focus")
	viewer._open_capture(output.path_join("multi.wvz"));viewer.playing = false;await ready()
	for kind in ["volume","mesh"]:
		shell.select_workspace(1 if kind == "volume" else 2);viewer.scene_layers.choose_object(kind,kind+"0");await settle()
		var old_body: Control = viewer.scene_layers.object_bodies[kind+"0"]
		first_in(old_body).grab_focus();await settle();viewer.scene_layers.choose_object(kind,kind+"1");await settle()
		check(first_in(old_body) == null and root.gui_get_focus_owner() != null and root.gui_get_focus_owner().is_visible_in_tree(),kind+": selected-object switch excludes old body and rehomes focus")
		await walk(kind+"-second-object")
	viewer._open_capture(output.path_join("fields.wvz"));viewer.playing = false;await ready();shell.select_workspace(2);await settle()
	check(not viewer.scene_layers.object_choices.mesh in nav.chain(root),"Unavailable mesh selector is skipped")
	await walk("fields-source-empty-mesh-category")
	viewer._open_capture(output.path_join("scene.wvz"));viewer.playing = false;await ready()
	shell.transport.set_process(false);viewer.play_button.disabled = true;shell.transport.actions.get_child(0).grab_focus();key(KEY_TAB);await settle()
	check(root.gui_get_focus_owner() == shell.transport.actions.get_child(2),"Disabled Play skipped")
	viewer.play_button.disabled = false;var current := root.gui_get_focus_owner();await settle();check(root.gui_get_focus_owner() == current,"Enabling Play does not steal focus")
	key(KEY_TAB,true);await settle();check(root.gui_get_focus_owner() == viewer.play_button,"Reenabled Play enters reverse order")
	viewer.play_button.disabled = true;await settle();key(KEY_TAB);await settle()
	check(root.gui_get_focus_owner() == shell.transport.actions.get_child(2),"Unavailable focused Play advances to next eligible action")
	viewer.play_button.disabled = false
	shell.transport.set_process(true);shell.transport.refresh()
	shell.transport.rate.grab_focus();shell.enter_immersive();await settle()
	check(nav.chain(root).is_empty() and root.gui_get_focus_owner() == null,"Fullscreen excludes hidden chrome")
	await show_side("bottom");key(KEY_TAB);await settle();check(category(root.gui_get_focus_owner()) in ["playback","status"],"Fullscreen revealed bottom is eligible")
	var fullscreen_focus := root.gui_get_focus_owner();shell.exit_immersive();await settle()
	check(root.gui_get_focus_owner() == fullscreen_focus,"Fullscreen exit retains current visible focus")
	var ui = shell.transport;ui.displayed.grab_focus();click(ui.displayed.get_global_rect().get_center(),true);await settle()
	await dialog_walk(ui.seek_dialog,"seek");ui.seek_dialog.editor.text = "00:02";key(KEY_ENTER,false,ui.seek_dialog);await settle();await ready()
	check(not ui.seek_dialog.visible and viewer.committed_sample.requested_time == 2 and root.gui_get_focus_owner() == ui.displayed,"Seek Enter preserves commit and initiator focus")
	ui.open_seek();await settle();ui.seek_dialog.editor.text = "00:04";key(KEY_ESCAPE,false,ui.seek_dialog);await settle();check(viewer.committed_sample.requested_time == 2 and root.gui_get_focus_owner() == ui.displayed,"Seek Escape cancels and restores")
	ui.open_seek();await settle();await hide_side("bottom");click(Vector2(200,180));await settle()
	check(not ui.seek_dialog.visible and root.gui_get_focus_owner() != null and category(root.gui_get_focus_owner()) == "top","Hidden seek initiator advances past bottom")
	await show_side("bottom")
	ui.rate.grab_focus();shell.about.open();await dialog_walk(shell.about,"about");shell.about.hide();await settle();check(root.gui_get_focus_owner() == ui.rate,"About restores initiator")
	ui.rate.grab_focus();viewer.tools_ui.open("Performance");await dialog_walk(viewer.tools_ui.window,"performance");viewer.tools_ui.close();await settle();check(root.gui_get_focus_owner() == ui.rate,"Tools restores initiator")
	shell.status_ui.jobs_button.grab_focus();shell.status_ui.open_jobs();await dialog_walk(shell.status_ui.jobs_dialog,"jobs");shell.status_ui.jobs_dialog.hide();await settle();check(root.gui_get_focus_owner() == shell.status_ui.jobs_button,"Jobs restores initiator")
	shell.navigation.get_child(0).grab_focus();shell.edit_orbit_center();await settle();await walk("orbit-overlay");shell.orbit_editor.dismiss();await settle();check(root.gui_get_focus_owner() == shell.navigation.get_child(0),"Orbit overlay restores initiator")
	ui.rate.grab_focus();shell.edit_file_locations();await dialog_walk(shell.file_locations_dialog,"file-locations")
	check(not shell.file_locations_dialog.ffmpeg_path in nav.chain(shell.file_locations_dialog),"Read-only FFmpeg path is excluded")
	shell.file_locations_dialog.dismiss();await settle();check(root.gui_get_focus_owner() == ui.rate,"File Locations Cancel restores initiator")
	var bindings: Dictionary = shell.shortcuts.active.duplicate();ui.rate.grab_focus();shell.edit_shortcuts();await settle();await walk("shortcuts-overlay")
	check(shell.shortcuts_editor.is_ancestor_of(root.gui_get_focus_owner()),"Shortcut overlay contains focus")
	shell.shortcuts_editor.start_capture("reset_camera");var captured := root.gui_get_focus_owner();key(KEY_TAB);await settle()
	check(shell.shortcuts_editor.listening == "reset_camera" and root.gui_get_focus_owner() == captured,"Reserved Tab preserves active shortcut capture without traversing")
	key(KEY_ESCAPE);await settle();check(shell.shortcuts_editor.visible and shell.shortcuts_editor.listening.is_empty(),"First Escape cancels shortcut capture")
	shell.shortcuts_editor.clear_binding("reset_camera");key(KEY_ESCAPE);await settle();check(not shell.shortcuts_editor.visible and shell.shortcuts.active == bindings and root.gui_get_focus_owner() == ui.rate,"Shortcut Escape discards unapplied binding and restores initiator")
	ui.rate.grab_focus();viewer.video_dialog.open();await settle()
	viewer.video_dialog.close_button.grab_focus();viewer.video_dialog.cancel_confirmation.popup_centered();await dialog_walk(viewer.video_dialog.cancel_confirmation,"nested-confirmation")
	viewer.video_dialog.cancel_confirmation.hide();await settle();check(viewer.video_dialog.gui_get_focus_owner() == viewer.video_dialog.close_button,"Confirmation restores parent-dialog initiator")
	viewer.video_dialog.hide();await settle();check(root.gui_get_focus_owner() == ui.rate,"Nested dialog dismissal restores root initiator")
	check(not nav.is_processing() and not nav.queued,"Focus manager has no continuous processing")
	var events: int = nav.reconciliations;await create_timer(.3).timeout;check(nav.reconciliations == events,"Idle focus policy performs no polling or repeated reconciliation")
	root.get_texture().get_image().save_png(output.path_join("focus-review.png"))
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"walks":walks},"\t"));file.close()
	viewer.free();await process_frame;print("FOCUS NAVIGATION: %d checks, %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
