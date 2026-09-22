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
	# Offline and interactive instances share the canonical controls and state.
	var offline = Viewer.new(); offline.offline_instance = true; root.add_child(offline); offline.set_process(false)
	var initial := science(offline)
	check(offline.shell != null and not offline.shell.transport.is_processing(), "Offline uses production shell without automatic refresh")
	check(not offline.tools_ui.window.visible,"Offline startup does not open Tools")
	offline.free()
	var viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	var shell = viewer.shell
	check(viewer.resize_handle.gui_input.get_connections().size() == 1, "Dock resize has one production event owner")
	check(viewer.play_button.pressed.get_connections().size() == 1, "Play has one controller binding")
	check(not viewer.sections.has("Playback") and not viewer.visual_sliders.has("Physical time units / second"), "Hidden duplicate playback form is absent")
	for group in ["Rendering", "Color Mapping", "Advanced • Size / Brightness", "Particle Filters"]:
		check(viewer.sections.has(group) and viewer.inspector_box.is_ancestor_of(viewer.sections[group]), "Canonical inspector group retained: " + group)
	var advanced: Control = viewer.sections["Advanced • Size / Brightness"]
	check(viewer.section_buttons["Advanced • Size / Brightness"].text == "Advanced" and not viewer.section_buttons.has("Trails") and not viewer.section_buttons.has("Advanced • Post-processing"),"One Advanced expander replaces three disclosures")
	for control in [viewer.size_option,viewer.brightness_option,viewer.control_checks["Recorded history  [T]"],viewer.visual_sliders["Exposure"],viewer.visual_sliders["Gamma"],viewer.glow_slider]:
		check(control.get_parent() == advanced,"Advanced options are direct children without nested expanders")
	check(science(viewer) == initial, "Shell construction preserves scientific visual state and section keys")
	await settle(); shell.layout(); await settle()
	check(shell.empty.visible and not viewer.inspector_box.visible, "Empty shell offers Open without dummy scientific form")
	check(shell.commands.copy.popup.is_item_disabled(shell.commands.copy.index) and shell.commands.video.popup.is_item_disabled(shell.commands.video.index), "Source-dependent menus explain unavailable state")
	check(shell.bar.size.y == 48, "Command bar is 48 logical pixels")
	check(not viewer.tools_ui.window.visible and viewer.tools_ui.current.is_empty(),"Interactive startup leaves Tools closed before any command")
	picture("empty")
	viewer._show_open_dialog(); await settle(); check(viewer.open_dialog.visible, "Canonical Open picker reachable")
	viewer.open_dialog.canceled.emit(); viewer.open_dialog.hide()
	check(viewer.generic_reader == null, "Picker cancel does not open source")
	shell.begin_open(); shell.status_ui.refresh(); check(shell.status_ui.readiness == "Preparing…" and not shell.empty.visible, "Unknown loading progress represented without percentage")
	picture("opening")
	viewer._open_capture(output.path_join("scene.ssc")); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	check(viewer.generic_reader != null and viewer.frame_count > 0, "Current SSC opens in production shell")
	check(not shell.empty.visible and viewer.inspector_box.visible, "Successful open reveals retained inspector")
	check(not viewer.tools_ui.window.visible,"Opening a capture does not open Tools")
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
		for page in 2: shell.select_workspace(page); shell.layout()
		shell.select_workspace(0)
	var activity := Profile.report(); Profile.enabled = false
	check(activity.stages.is_empty() and activity.counters.is_empty(), "Shell layout and navigation trigger no instrumented scientific work")
	check(science(viewer) == before and viewer.committed_sample == prior_sample, "Workspace navigation preserves scientific state, source binding and sample")
	for page in 2:
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
	activate(shell,"Save scene"); await settle()
	check(viewer.tools_ui.window.visible and viewer.tools_ui.current == "Save scene", "State reaches canonical scene save with shared limits")
	activate(shell,"Save analysis"); await settle()
	check(viewer.tools_ui.content.is_ancestor_of(viewer.selection_controller.temporal.durable.quota), "Analysis state retains the existing request limits")
	activate(shell,"data"); await settle()
	check(viewer.tools_ui.current == "Data", "Numerical export routes to existing controller")
	activate(shell,"image"); await settle()
	check(viewer.tools_ui.current == "Image", "Image menu reaches existing sidecar option")
	var save := preload("res://analysis/ui_controls.gd").button(viewer.tools_ui.form("Image"),"Image")
	save.pressed.emit(); await settle()
	check(viewer.screenshot_dialog.visible and viewer.screenshot_pending, "PNG action routes to canonical folder picker")
	viewer.screenshot_dialog.canceled.emit(); viewer.screenshot_dialog.hide(); viewer.tools_ui.close()
	check(not viewer.screenshot_pending and viewer.screenshot_directory.is_empty(), "PNG cancel retains existing session semantics")
	shell.menus.Help.get_popup().id_pressed.emit(0); await settle()
	check(shell.details.visible and shell.detail_text.text.contains("Midnight Scientific"), "Help menu opens focused navigation details")
	shell.details.hide()
	activate(shell,"video"); await settle()
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
	# Execute an existing numerical request and export through the migrated controls.
	var temporal = control.temporal
	temporal.mode.select(2); temporal.start_time.text = "0"; temporal.end_time.text = "1"
	activate(shell,"tool:Temporal")
	preload("res://analysis/ui_controls.gd").button(temporal.panel,"Run analysis").pressed.emit()
	check(await wait_jobs(control) and not temporal.current_result.is_empty(),"Focused Temporal retains numerical request lifecycle")
	activate(shell,"data")
	temporal.durable.folder_name.text = "menu-data"
	viewer.tools_ui.durable_controls.Data.pressed.emit(); await settle()
	var picker: FileDialog
	for child in temporal.durable.get_children():
		if child is FileDialog and child.visible: picker = child
	check(picker != null,"Data action opens existing destination picker")
	if picker != null:
		picker.dir_selected.emit(output); picker.hide()
		check(await wait_jobs(control) and temporal.durable.last_export.has("path"),"Data export completes through canonical worker")
		check(FileAccess.file_exists(output.path_join("menu-data/values.csv")),"Data export retains full values artifact")
	viewer.tools_ui.close()
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
	await menu_checks(viewer)
	await immersive_checks(viewer)
	# Logical geometry at supported factors. No scientific projection/state changes.
	shell.open_error.hide()
	for dimensions in [Vector2i(1440,900), Vector2i(1920,1080), Vector2i(1024,640)]:
		for factor in ([1.0] if dimensions.x >= 1440 else [1.0, 1.25, 1.5, 2.0]):
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
	viewer.scene_prebuffer_enabled = true
	viewer._open_capture(output.path_join("replacement.ssc")); await settle()
	check(viewer.tools_ui.form("Performance").is_ancestor_of(viewer.scene_layers.performance_panel),"Replaced-source budgets live only in Performance")
	for worker in [viewer.scene_layers.field_playback,viewer.scene_layers.mesh_playback]:
		if worker.enabled: check(viewer.scene_layers.performance_panel.is_ancestor_of(worker.label),"Preparation metrics remain in Performance")
	check(viewer.generic_reader != prior_reader and control.state.definitions.is_empty(), "Successful replacement clears prior bound definitions")
	var file := FileAccess.open(output.path_join("shell-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"layouts":layouts,"shell_scientific_activity":activity,"menu_tree":menu_tree(shell),"renderer":RenderingServer.get_current_rendering_method()},"\t")); file.close()
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
		if prior_mode == Window.MODE_WINDOWED: activate(shell,"immersive")
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

func activate(shell, name: String) -> void:
	shell.refresh_commands()
	var command: Dictionary = shell.commands[name]
	command.popup.id_pressed.emit(command.index)

func menu_checks(viewer) -> void:
	var shell = viewer.shell
	var initial_state := science(viewer)
	var initial_sample: Dictionary = viewer.committed_sample.duplicate(true)
	check(not viewer.inspector_box.is_ancestor_of(viewer.hud) and not viewer.inspector_box.is_ancestor_of(viewer.status_label),"Capture and viewer diagnostics do not occupy permanent panel")
	for id in viewer.scene_layers.labels:
		check(not viewer.scene_layers.labels[id].visible,"Verbose layer diagnostics hidden from panel: " + id)
	for id in viewer.scene_layers.color_controls:
		var controls: Dictionary = viewer.scene_layers.color_controls[id]
		check(not controls.status.visible,"Color explanation does not occupy panel: " + id)
		check(controls.indicator.text in ["⚠ Color clipping","⚠ Color unavailable"],"Color exception indicator is concise")
	shell.status_ui.detail_button.pressed.emit()
	check(shell.details.visible and shell.detail_text.text.contains(viewer.hud.text) and shell.detail_text.text.contains("SIMSCP3"),"Existing status Details preserves capture and interpolation information")
	for id in viewer.scene_layers.labels:
		check(shell.detail_text.text.contains(viewer.scene_layers.labels[id].tooltip_text),"Details preserves exact layer metadata: " + id)
	for id in viewer.scene_layers.color_controls:
		check(shell.detail_text.text.contains(viewer.scene_layers.color_controls[id].status.text),"Details preserves full color diagnostics: " + id)
	shell.show_source()
	await settle(); picture("metadata-details")
	shell.details.hide()
	for id in viewer.scene_layers.layer_settings_buttons:
		if viewer.scene_layers.color_controls.has(id): viewer.scene_layers.layer_settings_buttons[id].button_pressed = true
	shell.scroll.scroll_vertical = 0
	await settle(); picture("metadata-field")
	Visual.apply(viewer,initial_state)
	check(science(viewer) == initial_state and viewer.committed_sample == initial_sample,"Opening metadata Details preserves scientific state and committed sample")
	check(shell.menus.keys() == ["File","View","Tools","Help"],"Exact four top menus without duplicate State or Export")
	for title in viewer.tools_ui.SECTIONS:
		check(not viewer.sections.has(title) and not viewer.section_buttons.has(title),"No sidebar action for migrated " + title)
	var snapshot := science(viewer)
	var requests: int = viewer.selection_controller.jobs.serial
	Profile.enabled = true; Profile.reset()
	for name in shell.commands:
		if not name.begins_with("tool:"): continue
		activate(shell,name)
		check(viewer.tools_ui.current == name.trim_prefix("tool:") and viewer.tools_ui.window.visible,"Reachable tool " + name)
		check(viewer.tools_ui.content.get_child_count() == 1,"Only one focused form for " + name)
	var activity := Profile.report(); Profile.enabled = false
	check(activity.stages.is_empty() and activity.counters.is_empty(),"Tool navigation performs no scientific work")
	check(viewer.selection_controller.jobs.serial == requests and science(viewer) == snapshot,"Tool navigation preserves requests and visual state")
	activate(shell,"tool:Performance"); await settle()
	if DisplayServer.get_name() != "headless": viewer.tools_ui.window.get_texture().get_image().save_png(output.path_join("tool-performance.png"))
	activate(shell,"tool:Selection"); await settle()
	if DisplayServer.get_name() != "headless": viewer.tools_ui.window.get_texture().get_image().save_png(output.path_join("tool-selection.png"))
	activate(shell,"tool:Source probe"); await settle()
	if DisplayServer.get_name() != "headless": viewer.tools_ui.window.get_texture().get_image().save_png(output.path_join("tool-probe.png"))
	viewer.tools_ui.close()
	activate(shell,"probe"); check(not viewer.scene_layers.probe_marker_enabled,"View probe marker toggles existing session state")
	activate(shell,"probe"); check(viewer.scene_layers.probe_marker_enabled,"View probe marker restores session state")
	activate(shell,"preset:Scientific"); check(viewer.selected_preset == "Scientific" and not viewer.environment.glow_enabled,"Viewing preset reuses existing environment action")
	Visual.apply(viewer,snapshot)
	check(science(viewer) == snapshot,"Menu changes preserve recipe round trip")
	for name in shell.commands:
		var entry: Dictionary = shell.commands[name]
		var label: String = entry.popup.get_item_text(entry.index)
		for character in ["/", "\\", "*", "(", ")", "_"]: check(not label.contains(character),"Concise menu label " + label)

func menu_tree(shell) -> Array:
	var result: Array = []
	for title in shell.menus:
		result.append(title); result.append_array(menu_children(shell.menus[title].get_popup(),"  "))
	return result

func menu_children(popup: PopupMenu, indent: String) -> Array:
	var result: Array = []
	for i in popup.item_count:
		result.append(indent+popup.get_item_text(i))
		var child := popup.get_item_submenu(i)
		if not child.is_empty(): result.append_array(menu_children(popup.get_node(child),indent+"  "))
	return result
