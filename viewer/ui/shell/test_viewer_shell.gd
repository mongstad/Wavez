extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Profile = preload("res://scene/playback_profile.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var layouts: Array = []

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)
func settle() -> void:
	for i in 6: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func picture(name: String) -> void:
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png(output.path_join(name+".png"))
func science(viewer) -> Dictionary:
	var state := Visual.snapshot(viewer)
	for key in ["panel_width", "overlay_visible"]: state.erase(key)
	return state
func key(viewer, code: Key) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	viewer._unhandled_input(event)
func wait_jobs(control) -> bool:
	for i in 1000:
		await create_timer(.01).timeout
		if not control.jobs.busy(): return control.jobs.error.is_empty()
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shell-output="): output = arg.trim_prefix("--shell-output=")
	if output.is_empty(): quit(1); return
	create_timer(150).timeout.connect(func(): push_error("Shell test timed out"); quit(1))
	# Offline construction is the unchanged legacy presentation/scientific baseline.
	var legacy = Viewer.new(); legacy.offline_instance = true; root.add_child(legacy); legacy.set_process(false)
	var initial := science(legacy)
	check(legacy.shell == null, "Offline worker does not construct production shell")
	legacy.free()
	var viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	var shell = viewer.shell
	check(science(viewer) == initial, "Shell construction preserves scientific visual state and section keys")
	await settle(); shell.layout(); await settle()
	check(shell.empty.visible and not viewer.inspector_box.visible, "Empty shell offers Open without dummy scientific form")
	check(shell.menus.State.disabled and shell.menus.Export.disabled, "Source-dependent menus explain unavailable state")
	check(shell.bar.size.y == 48, "Command bar is 48 logical pixels")
	picture("empty")
	viewer._show_open_dialog(); await settle(); check(viewer.open_dialog.visible, "Canonical Open picker reachable")
	viewer.open_dialog.canceled.emit(); viewer.open_dialog.hide()
	check(viewer.generic_reader == null, "Picker cancel does not open source")
	shell.begin_open(); check(shell.context_detail.text == "Opening capture…" and not shell.empty.visible, "Unknown loading progress represented without percentage")
	picture("opening")
	viewer._open_capture(output.path_join("scene.ssc")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	check(viewer.generic_reader != null and viewer.frame_count > 0, "Current SSC opens in production shell")
	check(not shell.empty.visible and viewer.inspector_box.visible, "Successful open reveals retained inspector")
	var prior_reader = viewer.generic_reader
	var prior_sample: Dictionary = viewer.committed_sample.duplicate(true)
	var before := science(viewer)
	viewer._open_capture(output.path_join("invalid.ssc"))
	check(viewer.generic_reader == prior_reader and viewer.committed_sample == prior_sample and science(viewer) == before, "Failed replacement retains prior usable scene")
	check(shell.open_error.visible and not shell.error_details.is_empty(), "Open error remains reachable outside scroll")
	viewer.status_label.text = "Unrelated later information"; viewer._update_hud()
	check(shell.open_error.visible, "Unrelated status does not erase failed-open error")
	await settle(); picture("failed-open")
	# No source, rendering or scientific controller work may be caused by shell redraw/nav.
	Profile.enabled = true; Profile.reset()
	for repeat in 10:
		for page in 4: shell.select_workspace(page); shell.layout()
		shell.select_workspace(0)
	var activity := Profile.report(); Profile.enabled = false
	check(activity.stages.is_empty() and activity.counters.is_empty(), "Shell layout and navigation trigger no instrumented scientific work")
	check(science(viewer) == before and viewer.committed_sample == prior_sample, "Workspace navigation preserves scientific state, source binding and sample")
	for page in 4:
		shell.select_workspace(page); check(shell.chooser.selected == page, "Workspace choice synchronized " + str(page))
		shell.select_workspace(0)
	var focus: Control = viewer.section_buttons["Rendering"]; focus.grab_focus()
	viewer._toggle_overlay(); await settle()
	check(not viewer.overlay_visible and shell.recovery.visible, "Dock hide leaves mouse recovery")
	check(shell.navigation.is_visible_in_tree(), "Hiding the contextual panel keeps viewport camera controls visible")
	shell.recovery.pressed.emit(); await settle()
	check(viewer.overlay_visible and root.gui_get_focus_owner() == focus, "Dock recovery restores previous focus")
	var camera_before: Transform3D = viewer.camera.transform
	shell.transport.open_seek(); await settle(); shell.transport.target.editor.grab_focus()
	for code in [KEY_R,KEY_SPACE]:
		var typing := InputEventKey.new(); typing.keycode = code; typing.pressed = true; typing.window_id = shell.transport.seek_dialog.get_window_id()
		Input.parse_input_event(typing)
	await settle()
	check(viewer.camera.transform == camera_before and not viewer.playing, "Text entry suppresses viewport shortcuts")
	shell.transport.target.editor.release_focus(); shell.transport.seek_dialog.hide()
	viewer.yaw = 1.7; viewer._update_camera(); key(viewer, KEY_R)
	check(is_equal_approx(viewer.yaw, deg_to_rad(38.0)), "Reset entry uses canonical camera reset")
	viewer._focus_activity(); check(viewer.camera.transform.is_finite(), "Frame scene remains available")
	viewer.dragging = true
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT
	viewer._input(release); check(not viewer.dragging, "Release over chrome ends viewport drag")
	# Menus expose canonical forms, not duplicate save/export models.
	shell.menus.State.get_popup().id_pressed.emit(0); await settle()
	check(viewer.sections["Capture / Export"].visible, "State routes to existing scene recipe controls")
	shell.menus.State.get_popup().id_pressed.emit(1); await settle()
	check(viewer.sections["Analysis export and state"].visible, "State routes to existing analysis recipe controls")
	shell.menus.Export.get_popup().id_pressed.emit(2); await settle()
	check(viewer.sections["Analysis export and state"].visible, "Numerical export routes to existing controller")
	shell.menus.Export.get_popup().id_pressed.emit(0); await settle()
	check(viewer.screenshot_dialog.visible and viewer.screenshot_pending, "PNG menu routes to canonical folder picker")
	viewer.screenshot_dialog.canceled.emit(); viewer.screenshot_dialog.hide()
	check(not viewer.screenshot_pending and viewer.screenshot_directory.is_empty(), "PNG cancel retains existing session semantics")
	shell.menus.Help.get_popup().id_pressed.emit(0); await settle()
	check(shell.details.visible and shell.detail_text.text.contains("Midnight Scientific"), "Help menu opens focused navigation details")
	shell.details.hide()
	shell.menus.Export.get_popup().id_pressed.emit(1); await settle()
	check(viewer.video_dialog.visible, "Video menu reopens canonical export dialog")
	viewer.video_dialog.hide()
	shell.show_source(); await settle()
	check(shell.details.visible and shell.detail_text.text.contains(viewer.capture_path), "Copyable full source details remain accessible")
	shell.details.hide()
	# Existing scene v2 and real worker-backed analysis v3 round trips in production shell.
	check(viewer._save_inspection(output.path_join("scene.json")) == OK, "Production v2 save")
	check(viewer._load_inspection(output.path_join("scene.json")).is_empty(), "Production v2 restore")
	var control = viewer.selection_controller
	control.bind_source(); check(await wait_jobs(control), "Production analysis source bind")
	control._request("define_selection", {"key":"shell-test", "object":"p", "kind":"particle_ids", "selector":{"ids":["7"]}})
	check(await wait_jobs(control), "Production exact-ID selection")
	control.temporal.durable.save_to(output.path_join("analysis.inspection"), true)
	check(await wait_jobs(control) and control.temporal.durable.last_recipe.has("path"), "Production v3 save through canonical worker")
	control.temporal.durable.load_from(output.path_join("analysis.inspection/inspection.json"))
	check(await wait_jobs(control) and control.temporal.durable.last_recipe.get("restored",false), "Production v3 load through canonical worker")
	# Native transitions are asynchronous. Compositor geometry is checked separately on KDE.
	if DisplayServer.get_name() != "headless":
		var fullscreen_state := science(viewer)
		root.mode = Window.MODE_MAXIMIZED
		await create_timer(.5).timeout; shell.refresh(); await settle()
		check(shell.bar.visible and not shell.fullscreen_button.visible, "Maximized retains the command bar")
		for route in ["menu", "F11"]:
			if route == "menu": shell.menus.View.get_popup().id_pressed.emit(1)
			else:
				var event := InputEventKey.new(); event.keycode = KEY_F11; event.pressed = true
				root.push_input(event)
			await create_timer(.5).timeout; shell.refresh(); await settle()
			check(shell.fullscreen_button.visible, route + " exposes mouse exit")
			check(not shell.bar.visible, route + " hides the entire command bar")
			check(shell.dock.position.y == 0 and shell.navigation.is_visible_in_tree(), route + " reclaims bar space and keeps camera controls")
			check(science(viewer) == fullscreen_state, route + " preserves scientific state")
			picture("fullscreen-" + route)
			viewer._toggle_overlay(); await settle()
			check(shell.recovery.visible and shell.fullscreen_button.visible and shell.navigation.is_visible_in_tree(), route + " panel hide retains camera and mouse recovery")
			shell.recovery.pressed.emit(); await settle()
			check(viewer.overlay_visible and not shell.bar.visible, route + " panel recovery keeps command bar hidden")
			shell.fullscreen_button.pressed.emit()
			await create_timer(.5).timeout; shell.refresh(); await settle()
			check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, route + " mouse exits fullscreen")
			check(shell.bar.visible and shell.dock.position.y == 48, route + " restores command bar and layout")
			check(science(viewer) == fullscreen_state, route + " exit preserves scientific state")
	await immersive_checks(viewer)
	# Logical geometry at supported factors. No scientific projection/state changes.
	shell.open_error.hide()
	for dimensions in [Vector2i(1440,900), Vector2i(1024,640)]:
		for factor in ([1.0] if dimensions.x == 1440 else [1.0, 1.25, 1.5, 2.0]):
			root.content_scale_size = Vector2i.ZERO; root.content_scale_factor = factor
			root.size = Vector2i(Vector2(dimensions)*factor)
			await settle(); shell.layout(); await settle()
			check(shell.size.distance_to(Vector2(dimensions)) < 1, "Actual logical size matches requested target %s / %s" % [dimensions,factor])
			check(shell.dock.get_child(0).get_global_rect().end.x <= shell.size.x, "Dock children remain within window %s / %s" % [dimensions,factor])
			check(absf(shell.bar.size.y-48) < .1, "48px bar at %s / %s" % [dimensions,factor])
			check(shell.tabs.visible == (dimensions.x >= 1200) and shell.chooser.visible == (dimensions.x < 1200), "Responsive navigation %s / %s" % [dimensions,factor])
			check(viewer.overlay_panel.position.x >= 640 and viewer.overlay_panel.get_rect().end.x <= shell.size.x+.1, "Dock preserves 640px scene region %s / %s" % [dimensions,factor])
			check(viewer.overlay_panel.size.x <= 560 and shell.scroll.size.y > 100, "Bounded dock with independent scroll %s / %s" % [dimensions,factor])
			layouts.append({"logical":str(dimensions),"scale":factor,"bar":str(shell.bar.size),"dock":str(viewer.overlay_panel.get_rect())})
			if factor == 1.0:
				shell.select_workspace(0); await settle(); shell.scroll.scroll_vertical = 0; await settle(); picture("loaded-"+str(dimensions.x))
				shell.select_workspace(1); await settle(); picture("appearance-"+str(dimensions.x))
	# Below minimum logical space: collapse and a recoverable temporary sheet.
	viewer.color_channel = "value"; viewer._update_particle_legend()
	root.content_scale_factor = 1; root.size = Vector2i(800,640); await settle(); shell.layout(); await settle()
	check(not viewer.overlay_visible and shell.recovery.visible, "Narrow window collapses dock")
	check(not viewer.legend.visible and not viewer.colorbar.visible, "Automatic collapse preserves legend visibility contract")
	shell.recovery.pressed.emit(); await settle()
	check(viewer.overlay_visible, "Narrow window mouse recovery opens temporary sheet")
	check(viewer.legend.visible, "Temporary sheet recovery restores scalar legend")
	viewer._toggle_overlay(); await settle(); check(shell.recovery.visible, "Temporary sheet can be closed")
	root.size = Vector2i(1440,900); await settle(); shell.layout()
	if not viewer.overlay_visible: viewer._toggle_overlay()
	viewer.panel_width = 480; shell.layout(); await settle()
	check(absf(viewer.overlay_panel.size.x-480) < 1, "Dock supports explicit resize")
	var movement := InputEventMouseMotion.new(); movement.relative = Vector2(40,0); viewer.resizing_panel = true
	shell.resize_input(movement); viewer.resizing_panel = false; await settle()
	check(absf(viewer.overlay_panel.size.x-440) < 1, "Right dock splitter drag direction")
	viewer.panel_width = 360; shell.layout()
	# Replacement still invalidates source-bound state through the existing lifecycle.
	viewer._open_capture(output.path_join("replacement.ssc")); await settle()
	check(viewer.generic_reader != prior_reader and control.state.definitions.is_empty(), "Successful replacement clears prior bound definitions")
	var file := FileAccess.open(output.path_join("shell-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"layouts":layouts,"shell_scientific_activity":activity,"renderer":RenderingServer.get_current_rendering_method()},"\t")); file.close()
	viewer.free(); await process_frame
	print("SHELL: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func immersive_checks(viewer) -> void:
	var shell = viewer.shell
	var state := Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var camera: Transform3D = viewer.camera.transform
	var source = viewer.generic_reader
	viewer.playing = true # Clock is stopped by the harness; presentation must not pause it.
	var playing: bool = viewer.playing
	var focus: Control = viewer.section_buttons["Rendering"]
	viewer.colorbar.hide(); viewer.legend.hide()
	shell.enter_immersive(); await create_timer(.5).timeout
	check(not viewer.colorbar.visible and not viewer.legend.visible, "Immersive does not enable hidden scientific overlays")
	shell.exit_immersive(); await create_timer(.5).timeout
	check(not viewer.colorbar.visible and not viewer.legend.visible, "Leaving immersive does not enable hidden scientific overlays")
	viewer.colorbar.show(); viewer.legend.show()
	var editor := LineEdit.new(); shell.add_child(editor); editor.grab_focus()
	var shortcut := InputEventKey.new(); shortcut.keycode = KEY_F11; shortcut.pressed = true; shortcut.shift_pressed = true
	viewer._unhandled_input(shortcut)
	check(not shell.immersive, "Immersive shortcut respects focused text entry")
	editor.release_focus(); editor.free()
	for prior_mode in [Window.MODE_WINDOWED, Window.MODE_FULLSCREEN, Window.MODE_MAXIMIZED]:
		root.mode = prior_mode
		await create_timer(.5).timeout; shell.refresh(); await settle()
		focus.grab_focus()
		Profile.enabled = true; Profile.reset()
		if prior_mode == Window.MODE_WINDOWED: shell.menus.View.get_popup().id_pressed.emit(4)
		else: viewer._unhandled_input(shortcut)
		await create_timer(.5).timeout; await settle()
		check(shell.immersive and root.mode == Window.MODE_FULLSCREEN, "Immersive native entry from " + str(prior_mode))
		check(not shell.is_visible_in_tree() and not shell.dock.visible and not viewer.resize_handle.visible, "Immersive hides shell and dock from " + str(prior_mode))
		check(not shell.transport.is_visible_in_tree() and not shell.status_ui.is_visible_in_tree() and not shell.recovery.is_visible_in_tree(), "Immersive hides transport/status/recovery")
		check(root.gui_get_focus_owner() == null, "Immersive releases hidden control focus")
		check(shell.immersive_hint.visible and shell.immersive_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE and shell.immersive_hint.focus_mode == Control.FOCUS_NONE, "Transient hint is visible and noninteractive")
		check(viewer.colorbar.visible and viewer.legend.visible, "Scientific overlay visibility retained")
		check(Visual.snapshot(viewer) == state and viewer.committed_sample == sample and viewer.camera.transform == camera and viewer.generic_reader == source, "Entry retains recipes sample camera and source")
		check(viewer.playing == playing, "Immersive preserves play/pause state")
		if prior_mode == Window.MODE_WINDOWED:
			picture("immersive-hint")
			await create_timer(3).timeout
			check(not shell.immersive_hint.visible, "Hint disappears automatically after three seconds")
			picture("immersive-clean")
		shell.refresh(); shell.layout(); viewer._toggle_overlay(); await settle()
		check(not shell.dock.visible and not shell.is_visible_in_tree(), "Refresh layout and F1 cannot expose immersive chrome")
		var activity := Profile.report(); Profile.enabled = false
		# Existing selection controller idle callbacks continue across frames.
		for idle in ["g4_overlay_tick", "g4_worker_poll"]: activity.stages.erase(idle)
		check(activity.stages.is_empty() and activity.counters.is_empty(), "Immersive presentation triggers no instrumented scientific work")
		viewer.inspection_busy = true
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
		root.push_input(escape)
		viewer.inspection_busy = false
		await create_timer(.5).timeout; await settle()
		check(not shell.immersive and root.mode == prior_mode, "Esc restores preceding native mode even while inspection is busy")
		check(shell.visible and shell.dock.visible == viewer.overlay_visible and shell.transport.is_visible_in_tree(), "Esc restores shell controls")
		check(root.gui_get_focus_owner() == focus, "Esc restores valid preceding focus")
		check(Visual.snapshot(viewer) == state and viewer.committed_sample == sample and viewer.camera.transform == camera, "Exit retains scientific state")
	viewer.playing = false
	root.mode = Window.MODE_WINDOWED; await create_timer(.5).timeout
	viewer._toggle_overlay(); await settle()
	shell.enter_immersive(); await create_timer(.5).timeout
	shell.exit_immersive(); await create_timer(.5).timeout
	check(not viewer.overlay_visible and not shell.dock.visible and shell.recovery.visible, "Immersive preserves a previously hidden dock")
	viewer._toggle_overlay(); await settle()
	shell.enter_immersive(); await create_timer(3.1).timeout
	check(await viewer._capture_inspection_png(output.path_join("immersive-png.png"), false) == OK, "Canonical PNG capture remains available during immersive")
	viewer._notify_screenshot("Immersive PNG test")
	check(not viewer.screenshot_notice.visible and not shell.visible, "PNG completion does not expose application chrome")
	root.mode = Window.MODE_WINDOWED; await create_timer(.5).timeout
	check(not shell.immersive and shell.visible and shell.bar.visible and shell.transport.is_visible_in_tree(), "Unexpected native fullscreen loss recovers usable shell")
	shell.enter_immersive(); await create_timer(.5).timeout
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true
	viewer._unhandled_input(wheel)
	check(viewer.camera.transform != camera, "Immersive pointer camera controls remain active")
	shell.exit_immersive(); await create_timer(.5).timeout
	viewer._update_camera()
