extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	root.push_input(event)
func science() -> Dictionary:
	var state := Visual.snapshot(viewer)
	state.erase("overlay_visible"); state.erase("panel_width")
	return state
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--edge-output="): output = arg.trim_prefix("--edge-output=")
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("scene.ssc")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	var shell = viewer.shell
	var edge = shell.edge_reveal
	edge.set_process(false) # Deterministic dwell increments; native GUI input is checked below.
	var original := science()
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var camera: Transform3D = viewer.camera.transform
	check(viewer.frame_a != null,"Synthetic mixed capture opened")
	var fullscreen_key := InputEventKey.new(); fullscreen_key.keycode = KEY_F11; fullscreen_key.pressed = true
	edge._input(fullscreen_key)
	check(not edge.keyboard_navigation,"Fullscreen shortcut does not turn old mouse focus into a keyboard edit")
	check(not shell.commands.has("panels") and not shell.commands.has("immersive"),"No duplicate visibility or immersive menu commands")
	check(shell.commands.fullscreen.popup.name == "Window","Fullscreen lives under View / Window")
	check(shell.bottom_strip.is_ancestor_of(shell.transport) and shell.bottom_strip.is_ancestor_of(shell.status_ui),"One parent controls complete bottom strip")
	for side in ["top","right","bottom"]:
		var point: Vector2 = {"top":Vector2(500,1),"right":Vector2(root.size.x-1,300),"bottom":Vector2(500,root.size.y-1)}[side]
		edge.tick(10,Vector2(100,200),false,false)
		check(edge.states[side].visible,side+" pinned persists")
		var pinned_icon = edge.pins[side].icon
		edge.pins[side].button_pressed = false
		check(edge.states[side].visible,side+" unpin does not hide during click")
		check(pinned_icon != edge.pins[side].icon,side+" pin icon visibly changes")
		edge.tick(.34,Vector2(100,200),false,false)
		check(edge.states[side].visible,side+" grace avoids immediate hide")
		edge.tick(.02,Vector2(100,200),false,false)
		check(not edge.states[side].visible,side+" active auto-hide")
		for i in 10:
			edge.tick(.2,point,true,false)
			edge.tick(.01,Vector2(100,200),true,false)
		check(not edge.states[side].visible,side+" rapid edge passes do not accumulate")
		edge.tick(.49,point,true,false)
		check(not edge.states[side].visible,side+" dwell not early")
		edge.tick(.02,point,true,false)
		check(edge.states[side].visible and not edge.states[side].pinned,side+" dwell reveals without pinning")
		await settle()
		var surface: Control = edge.controls(side)[0]
		edge.tick(2,surface.get_global_rect().get_center(),true,false)
		check(edge.states[side].visible,side+" hover retains surface")
		edge.tick(2,Vector2(100,200),false,true)
		check(edge.states[side].visible,side+" active drag or popup retains surface")
		var editor := LineEdit.new(); surface.add_child(editor); editor.grab_focus()
		edge.tick(2,Vector2(100,200),false,false)
		check(edge.states[side].visible,side+" focused text edit retained")
		editor.release_focus(); editor.free()
		var keyboard := InputEventKey.new(); keyboard.keycode = KEY_TAB; keyboard.pressed = true
		edge._input(keyboard); edge.pins[side].grab_focus()
		edge.tick(2,Vector2(100,200),false,false)
		check(edge.states[side].visible,side+" keyboard navigation keeps controls available")
		edge.pins[side].release_focus(); edge.keyboard_navigation = false
		edge.tick(.36,Vector2(100,200),false,false)
		check(not edge.states[side].visible,side+" ends interaction cleanly")
		edge.set_pinned(side,true)
		check(edge.states[side].visible and edge.pins[side].button_pressed,side+" pin immediately persists")
		check(science() == original and viewer.committed_sample == sample,side+" preserves scientific state and clock")
	# Owner review: all three edges accept 10px, with deliberate dwell retained.
	for side in ["top","bottom","right"]:
		var extent := root.get_visible_rect().size
		var width := 10.0
		var inside_point: Vector2 = {"top":Vector2(500,width),"bottom":Vector2(500,extent.y-width),"right":Vector2(extent.x-width,300)}[side]
		var outside_point: Vector2 = inside_point + {"top":Vector2(0,1),"bottom":Vector2(0,-1),"right":Vector2(-1,0)}[side]
		edge.set_pinned(side,false)
		edge.tick(.36,Vector2(100,200),false,false)
		edge.tick(.6,outside_point,true,false)
		check(not edge.states[side].visible,side+" does not reveal beyond configured zone")
		edge.tick(.49,inside_point,true,false)
		check(not edge.states[side].visible,side+" widened boundary still requires dwell")
		edge.tick(.02,inside_point,true,false)
		check(edge.states[side].visible,side+" reveals at configured boundary")
		edge.set_pinned(side,true)
	check(shell.transport.visible == shell.status_ui.visible,"Bottom child visibility never diverges")
	# A clicked slider can retain focus after release without trapping its strip open.
	edge.set_pinned("bottom",false); viewer.timeline.grab_focus()
	edge.tick(.36,Vector2(100,200),false,false)
	check(not edge.states.bottom.visible,"Idle slider focus does not strand bottom strip")
	edge.set_pinned("bottom",true); viewer.timeline.release_focus()
	var playing_before: bool = viewer.playing
	viewer.playing = true
	var jobs_before: Dictionary = shell.status_ui.job_rows.duplicate()
	for side in edge.states: edge.set_pinned(side,false)
	edge.tick(.36,Vector2(100,200),false,false)
	check(viewer.playing and shell.status_ui.job_rows == jobs_before and viewer.committed_sample == sample,"Hide preserves active playback and existing Jobs state")
	for side in edge.states: edge.set_pinned(side,true)
	viewer.playing = playing_before

	# Real popups and native GUI dispatch, independent of timer injection.
	shell.menus.View.get_popup().popup(Rect2i(400,200,200,200)); await settle()
	check(edge.popup_active(viewer),"Open menu detected as active interaction")
	check(not edge.is_viewport_point(Vector2(200,200)),"Menu blocks fullscreen gesture")
	shell.menus.View.get_popup().hide()
	shell.status_ui.open_jobs(); await settle()
	check(edge.popup_active(viewer),"Jobs dialog detected as active interaction")
	shell.status_ui.jobs_dialog.hide()
	shell.transport.open_seek(); await settle()
	check(edge.popup_active(viewer),"Seek dialog detected as active interaction")
	shell.transport.seek_dialog.hide()
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
	viewer.show_legend = true; viewer.color_channel = "value"; viewer._update_particle_legend(); await settle()
	check(not edge.is_viewport_point(shell.particle_legend_panel.get_global_rect().get_center()),"Legend excludes fullscreen double click")
	viewer.show_legend = false; viewer._update_particle_legend()
	original = science()
	for side in edge.states:
		check(not edge.is_viewport_point(edge.controls(side)[0].get_global_rect().get_center()),side+" chrome excludes fullscreen double click")
	for mask in 8:
		for i in 3:
			var side: String = ["top","right","bottom"][i]
			edge.set_pinned(side,(mask & (1<<i)) != 0)
		edge.tick(.36,Vector2(100,200),false,false)
		var before: Dictionary = edge.states.duplicate(true)
		viewer._toggle_fullscreen(); await create_timer(.25).timeout
		check(shell.immersive and not shell.visible and not shell.dock.visible and not shell.transport.is_visible_in_tree() and not shell.status_ui.is_visible_in_tree(),"Fullscreen hides every surface mask "+str(mask))
		edge.tick(10,Vector2(1,1),true,false)
		check(edge.states == before,"Fullscreen freezes edge states mask "+str(mask))
		viewer.inspection_busy = true; key(KEY_ESCAPE); viewer.inspection_busy = false
		await create_timer(.25).timeout
		check(not shell.immersive and edge.states == before,"Esc restores exact pin visibility and timers mask "+str(mask))
		check(shell.transport.is_visible_in_tree() == shell.status_ui.is_visible_in_tree(),"Bottom strip restores together mask "+str(mask))
		check(science() == original and viewer.committed_sample == sample and viewer.camera.transform == camera,"Fullscreen preserves science mask "+str(mask))
	# Temporarily revealed unpinned surfaces must also restore visible.
	for side in edge.states: edge.set_pinned(side,false)
	var revealed: Dictionary = edge.states.duplicate(true)
	viewer._toggle_fullscreen(); await create_timer(.25).timeout; key(KEY_ESCAPE); await create_timer(.25).timeout
	check(edge.states == revealed,"Temporarily revealed unpinned surfaces restore exactly")
	for side in edge.states: edge.set_pinned(side,true)
	await settle()
	var dbl := InputEventMouseButton.new(); dbl.button_index = MOUSE_BUTTON_LEFT; dbl.pressed = true; dbl.double_click = true; dbl.position = Vector2(300,300)
	root.push_input(dbl); await create_timer(.25).timeout
	check(shell.immersive,"Actual viewport double click enters Fullscreen")
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false; release.position = dbl.position; root.push_input(release)
	root.push_input(dbl); await create_timer(.25).timeout; root.push_input(release)
	check(not shell.immersive and not viewer.dragging,"Actual viewport double click exits without camera drag")
	# Deterministic export ignores desktop pin choices.
	for side in edge.states: edge.set_pinned(side,false)
	edge.tick(.36,Vector2(100,200),false,false)
	check(not shell.export_state().has("pins"),"Pins excluded from export state")
	for side in edge.states: edge.set_pinned(side,true)
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("pins.png"))
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"dwell_seconds":edge.DWELL,"hide_grace_seconds":edge.GRACE,"top_bottom_zone_pixels":edge.VERTICAL_EDGE,"right_zone_pixels":edge.RIGHT_EDGE}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EDGE: ",checks," checks; ",failures.size()," failures")
	viewer.free(); await process_frame; quit(0 if failures.is_empty() else 1)
