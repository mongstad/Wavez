extends SceneTree
## Production dropdown parity and native interaction across all three categories.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
var comparisons := []
var audited := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	await create_timer(.18).timeout
	await RenderingServer.frame_post_draw
func ready() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	viewer._sync_control_state(); viewer.shell.transport.refresh(); viewer.shell.status_ui.refresh()
	check(not viewer.scene_layers.is_buffering(), "Complete fixture is prepared")
func picture(name: String) -> void:
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func key(code: Key, window = root, shift := false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	event.shift_pressed = shift
	event.window_id = window.get_window_id(); Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true; event.position = point; root.push_input(event)
	var release := event.duplicate(); release.pressed = false; root.push_input(release)

func skin(node: Node, type: String) -> Dictionary:
	# Compare resolved production theme items, including engine fallbacks and local
	# overrides. No expected literal palette/radius or per-category fixture skin.
	var result := {}
	for kind in ["stylebox", "color", "constant", "font", "font_size", "icon"]:
		var names: Array = []
		for source in [ThemeDB.get_default_theme(), viewer.shell.style_slice.theme]:
			for name in source.call("get_" + kind + "_list", type):
				if not names.has(name): names.append(name)
		for name in names: result[kind + "/" + name] = node.call("get_theme_" + kind, name)
	return result
func selectors(node: Node) -> Array:
	if node is FileDialog: return []
	var result := []
	if node is OptionButton: result.append(node)
	for child in node.get_children(): result.append_array(selectors(child))
	return result
func audit(stage: String) -> void:
	var reference := skin(viewer.colormap_option, "OptionButton")
	var popup_reference := skin(viewer.colormap_option.get_popup(), "PopupMenu")
	var choices := selectors(viewer)
	check(choices.size() > 40, stage + " includes real category, analysis, export and target dropdowns")
	for control in choices:
		audited += 1
		check(skin(control, "OptionButton") == reference, stage + " closed/focus/disabled dropdown parity: " + str(control.get_path()))
		check(skin(control.get_popup(), "PopupMenu") == popup_reference, stage + " popup surface/rows/glyphs/disabled parity: " + str(control.get_path()))

func unchanged(before: Dictionary, label: String) -> void:
	check(Visual.snapshot(viewer) == before, label + " preserves all scientific visual state")
func hover_fades() -> void:
	var before := Visual.snapshot(viewer)
	var rest := []; var hover := []
	for control in [viewer.colormap_option, viewer.size_option, viewer.scene_layers.panel_controls.volume0.channel, viewer.scene_layers.panel_controls.mesh0.channel, viewer.tools_ui.target_choices.Slice]:
		control.mouse_entered.emit(); await settle(); hover.append(control.self_modulate)
		check(not control.get_meta("violet_tween").is_running(), "Dropdown hover settles: " + str(control.get_path()))
		control.mouse_exited.emit(); await settle(); rest.append(control.self_modulate)
		check(not control.get_meta("violet_tween").is_running(), "Dropdown release settles: " + str(control.get_path()))
	check(hover.all(func(ink): return ink == hover[0]) and rest.all(func(ink): return ink == rest[0]), "Particle/Advanced/Field/Mesh/Tools dropdowns share visible hover/rest ink")
	unchanged(before, "Bounded shared dropdown fades")
func popup_summary(control: OptionButton) -> Dictionary:
	var popup := control.get_popup()
	var panel: StyleBoxFlat = popup.get_theme_stylebox("panel")
	var hover: StyleBoxFlat = popup.get_theme_stylebox("hover")
	return {"surface":panel.bg_color.to_html(), "border_width":panel.border_width_top,
		"radius":panel.corner_radius_top_left, "padding":[panel.content_margin_left, panel.content_margin_top, panel.content_margin_right, panel.content_margin_bottom],
		"shadow_size":panel.shadow_size, "hover":hover.bg_color.to_html(),
		"row_separation":popup.get_theme_constant("v_separation"), "font_size":popup.get_theme_font_size("font_size"),
		"text":popup.get_theme_color("font_color").to_html(), "selected_text":popup.get_theme_color("font_hover_color").to_html(),
		"disabled_text":popup.get_theme_color("font_disabled_color").to_html(), "embedded":popup.is_embedded()}

func category(index: int, name: String, control: OptionButton) -> void:
	var shell = viewer.shell
	shell.select_workspace(index); shell.scroll.ensure_control_visible(control); await settle()
	var before := Visual.snapshot(viewer)
	var current: int = control.selected
	var popup := control.get_popup()
	var intents := []
	var callback := func(i): intents.append(i)
	control.item_selected.connect(callback)
	control.grab_focus(); await settle()
	check(control.has_focus(), name + " accepts keyboard focus")
	picture(name + "-focus")
	key(KEY_ENTER); await settle()
	check(popup.visible and not viewer.playing, name + " opens through focused Enter without starting playback")
	check(popup.is_item_checked(current), name + " native radio identifies current choice")
	picture(name + "-selected")
	# A genuine popup-local motion exercises hover hit-testing, not a painted mock.
	var row_height: float = maxf(popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size")), popup.get_theme_icon("radio_checked").get_height()) + popup.get_theme_constant("v_separation")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(70, popup.get_theme_stylebox("panel").content_margin_top + row_height * 1.5)
	# PopupMenu ignores zero-relative/zero-velocity motion (including cursor warps).
	motion.relative = Vector2(1, 0); motion.velocity = Vector2(10, 0)
	motion.window_id = root.get_window_id(); motion.position += Vector2(popup.position)
	Input.parse_input_event(motion); await settle()
	check(popup.get_focused_item() == 1, name + " pointer hover reaches the second native row")
	picture(name + "-hover")
	key(KEY_ESCAPE, popup); await settle()
	check(not popup.visible and control.selected == current and intents.is_empty(), name + " Esc cancels without selection intent")
	check(control.has_focus(), name + " popup dismissal returns keyboard focus")
	key(KEY_TAB); await settle()
	check(root.gui_get_focus_owner() != control, name + " Tab reaches the next form control")
	key(KEY_TAB, root, true); await settle()
	check(control.has_focus(), name + " Shift+Tab returns to the dropdown")
	unchanged(before, name + " focus/open/hover/cancel")
	# Disable one existing non-current row temporarily to exercise the actual
	# disabled radio/text and keyboard skip path. Restore it before real selection.
	var was_disabled := control.is_item_disabled(1)
	control.set_item_disabled(1, true)
	click(control.get_global_rect().get_center()); await settle()
	check(popup.visible, name + " opens through pointer click")
	popup.set_focused_item(current); key(KEY_DOWN, popup); await settle()
	check(popup.get_focused_item() == 2, name + " keyboard skips disabled row")
	picture(name + "-disabled-row")
	key(KEY_ESCAPE, popup); await settle(); control.set_item_disabled(1, was_disabled)
	check(intents.is_empty(), name + " disabled-row navigation emits no intent")
	# Exercise the normal controller binding via native popup keyboard dispatch.
	control.grab_focus(); key(KEY_ENTER); await settle()
	popup.set_focused_item(current); key(KEY_DOWN, popup); await settle()
	check(popup.get_focused_item() == 1, name + " Down focuses the next enabled choice")
	key(KEY_ENTER, popup); await ready(); await settle()
	check(not popup.visible and control.selected == 1 and intents == [1], name + " Enter emits exactly one native selection")
	if index == 0:
		check(viewer.colormap_name == control.get_item_text(1), "Particles selection reaches its existing colormap controller")
		check(viewer.scene_layers.states == before.scene.layers, "Particle choice preserves field/mesh state")
	else:
		var id := "volume0" if index == 1 else "mesh0"
		check(viewer.scene_layers.states[id].colormap == control.get_item_text(1), name + " selection reaches its existing object controller")
		var expected: Dictionary = before.duplicate(true)
		expected.scene.layers[id].colormap = control.get_item_text(1)
		unchanged(expected, name + " selection changes only the selected object's colormap")
	comparisons.append({"category":name, "popup":popup_summary(control), "selection_intents":intents.duplicate()})
	control.item_selected.disconnect(callback)
	# Snapshot restore is also the production recipe rebuild route.
	Visual.apply(viewer, before); await ready(); await settle()

func channel(index: int, id: String, name: String) -> void:
	viewer.shell.select_workspace(index)
	var control: OptionButton = viewer.scene_layers.panel_controls[id].channel
	viewer.shell.scroll.ensure_control_visible(control); await settle()
	var before := Visual.snapshot(viewer)
	control.grab_focus(); key(KEY_ENTER); await settle()
	var popup := control.get_popup()
	check(popup.visible, name + " channel popup opens through keyboard")
	picture(name + "-channel")
	popup.set_focused_item(0); key(KEY_DOWN, popup); key(KEY_ENTER, popup); await ready(); await settle()
	var expected: Dictionary = before.duplicate(true)
	expected.scene.layers[id].channel = control.get_item_metadata(1)
	unchanged(expected, name + " native channel selection preserves exact metadata and every other object")
	Visual.apply(viewer, before); await ready(); await settle()

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(110).timeout.connect(func(): push_error("Dropdown test timeout"); quit(1))
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false
	root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("mixed.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	viewer.shell.edge_reveal.set_process(false)
	await ready(); await settle()
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var camera: Transform3D = viewer.camera.transform
	var source: Dictionary = viewer.selection_controller.source.duplicate(true)
	var requests: int = viewer.selection_controller.jobs.serial
	viewer.section_buttons["Color Mapping"].button_pressed = true
	for id in ["volume0", "mesh0"]: viewer.scene_layers.panel_groups[id + "/Color Mapping"].button_pressed = true
	audit("capture")
	await hover_fades()
	await category(0, "particles", viewer.colormap_option)
	await category(1, "fields", viewer.scene_layers.panel_controls.volume0.colormap)
	await category(2, "meshes", viewer.scene_layers.panel_controls.mesh0.colormap)
	await channel(1, "volume0", "fields")
	await channel(2, "mesh0", "meshes")
	audit("recipe rebuild")
	check(comparisons[0].popup == comparisons[1].popup and comparisons[1].popup == comparisons[2].popup, "All category popup measurements match")
	check(viewer.committed_sample == sample and viewer.camera.transform == camera, "Native dropdown interactions preserve precise clock/camera")
	check(viewer.selection_controller.source == source and viewer.selection_controller.jobs.serial == requests, "Dropdown navigation/colormaps preserve analysis source and submit no selection requests")
	check(not viewer.playing, "Dropdown keyboard interactions preserve paused playback")
	# Context navigation is presentation-only; use the real object selector too.
	var before := Visual.snapshot(viewer)
	var context: OptionButton = viewer.scene_layers.object_choices.mesh
	viewer.shell.scroll.ensure_control_visible(context); await settle()
	context.grab_focus(); key(KEY_ENTER); await settle()
	context.get_popup().set_focused_item(0); key(KEY_DOWN, context.get_popup()); key(KEY_ENTER, context.get_popup()); await settle()
	check(viewer.scene_layers.selected_objects.mesh == "mesh1", "Native object dropdown routes to existing scene context")
	unchanged(before, "Object context dropdown")
	viewer._open_capture(output.path_join("particles.wvz")); viewer.playing = false; await ready(); await settle()
	audit("capture replacement")
	for index in [1, 2]:
		viewer.shell.select_workspace(index); await settle()
		var empty: OptionButton = viewer.scene_layers.object_choices["volume" if index == 1 else "mesh"]
		click(empty.get_global_rect().get_center()); await settle()
		check(empty.disabled and not empty.get_popup().visible, "Absent category remains disabled: " + str(index))
		picture("fields-empty" if index == 1 else "meshes-empty")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "audited_selectors":audited,
		"comparisons":comparisons, "renderer":RenderingServer.get_current_rendering_method()}, "\t")); file.close()
	print("VIOLET DROPDOWNS: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
