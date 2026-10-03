extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
const Legacy = preload("res://ui/theme/wavez_theme.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var viewer

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle() -> void:
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
func picture(name: String) -> void:
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return .2126 * linear.r + .7152 * linear.g + .0722 * linear.b
func contrast(foreground: Color, background: Color) -> float:
	return (luminance(foreground) + .05) / (luminance(background) + .05)

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	root.title = "WAVEZ #143 visual slice validation"
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false
	root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("scene.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	var shell = viewer.shell
	var theme = shell.style_slice.theme
	var legacy := Legacy.new()
	var original := Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var camera: Transform3D = viewer.camera.transform
	for group in ["Rendering", "Color Mapping"]:
		shell.viewer.section_buttons[group].button_pressed = true
		check(viewer.sections[group].theme == theme, group + " uses scoped review theme")
	check(viewer.sections["Advanced • Size / Brightness"].theme == null, "Advanced remains outside review slice")
	viewer.tools_ui.open("Mapping")
	check(viewer.tools_ui.window.theme == theme and shell.status_ui.jobs_dialog.theme != theme, "Current Tools surface shares the violet theme; Jobs remains outside the earlier slice")
	viewer.tools_ui.close()
	check(shell.transport.seek_dialog.theme == theme and shell.details.theme == theme and shell.about.theme == theme, "Representative popover and informational dialogs share the slice theme")
	check(viewer.legend.theme == shell.theme, "Scientific legend retains accepted theme")
	check(viewer.timeline.field_color == legacy.c(&"accent.primary") and viewer.timeline.scene_color == legacy.c(&"identity.teal"), "Readiness overlay keeps accepted blue/teal meaning")
	for severity in ["success", "warning", "error", "info"]:
		check(theme.c(StringName("state." + severity)) == legacy.c(StringName("state." + severity)), "Semantic " + severity + " unchanged")
	for surface in [&"surface.1", &"surface.2", &"surface.3", &"surface.hover", &"selection.fill"]:
		check(contrast(theme.c(&"text.primary"), theme.c(surface)) >= 4.5, "Primary text contrast " + String(surface))
		check(contrast(theme.c(&"text.secondary"), theme.c(surface)) >= 4.5, "Secondary text contrast " + String(surface))
	for part in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBoxFlat = theme.get_stylebox(part, "IconAction")
		check(box.border_width_top == 0 and box.border_width_left == 0 and box.border_width_right == 0 and box.border_width_bottom == 0, "Borderless icon state " + part)
	check(theme.get_stylebox("normal", "IconAction").bg_color.a == 0, "Icon rest merges with parent")
	check(theme.get_stylebox("hover", "IconAction").bg_color != theme.get_stylebox("pressed", "IconAction").bg_color, "Hover and active surfaces distinct")
	check(theme.get_stylebox("focus", "IconAction").border_width_top >= 2, "Keyboard focus remains explicit")
	check(theme.get_stylebox("focus", "IconAction").border_color == theme.c(&"focus.ring"), "Focus consumes periwinkle token")
	check(theme.get_color("font_color", "Label") == theme.c(&"text.primary"), "Derived theme retains shared typography")
	check(shell.detail_text.get_theme_color("font_readonly_color") == theme.c(&"text.secondary"), "Informational dialog consumes explicit read-only text color")
	check(contrast(shell.detail_text.get_theme_color("font_readonly_color"), theme.c(&"surface.1")) >= 4.5, "Read-only dialog text contrast")
	for icon in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		check(theme.get_icon(icon, "CheckButton").get_size() == Vector2(32,20), "Compact switch native icon " + icon)
	check(theme.get_icon("checked", "CheckButton").get_image().get_data() != theme.get_icon("unchecked", "CheckButton").get_image().get_data(), "Switch state includes knob position")
	for side in ["top", "right", "bottom"]:
		var pin: Button = shell.edge_reveal.pins[side]
		check(not pin.tooltip_text.is_empty(), side + " pin retains tooltip")
		var pinned = pin.icon
		shell.edge_reveal.set_pinned(side, false)
		check(pin.icon != pinned and not pin.button_pressed, side + " unpinned shape distinct")
		shell.edge_reveal.set_pinned(side, true)
	check(viewer.play_button.pressed.get_connections().size() == 1, "Single accepted Play handler")
	check(shell.transport.loop.toggled.get_connections().size() == 1, "Single accepted Loop handler")
	await settle(); shell.scroll.scroll_vertical = 0; await settle(); picture("slice-1440")
	var pin: Button = shell.edge_reveal.pins.top
	pin.mouse_entered.emit(); await settle()
	check(pin.self_modulate == Color.WHITE, "Hover fade reaches bright endpoint")
	check(not pin.get_meta("violet_tween").is_running(), "Hover tween stops after 80 ms")
	pin.grab_focus(); await settle(); picture("focus-1440")
	pin.mouse_exited.emit(); pin.release_focus(); await settle()
	check(not pin.get_meta("violet_tween").is_running(), "Release tween stops after 80 ms")
	shell.menus.View.get_popup().popup(Rect2i(1120,48,220,0)); await settle(); picture("menu-1440")
	shell.menus.View.get_popup().hide()
	viewer.colormap_option.get_popup().popup(Rect2i(1090,350,300,0)); await settle(); picture("selector-1440")
	viewer.colormap_option.get_popup().hide()
	root.size = Vector2i(1024,640); await settle(); shell.layout(); await settle(); picture("slice-1024")
	check(shell.transport.get_global_rect().end.x <= 1024 and shell.dock.get_global_rect().end.x <= 1024, "Minimum window retains bounded shell")
	check(viewer.committed_sample == sample and viewer.camera.transform == camera, "Presentation preserves committed clock and camera")
	# Disclosure state is session presentation; scientific state stays exact.
	var current := Visual.snapshot(viewer)
	for key in ["sections", "panel_width", "overlay_visible"]:
		original.erase(key); current.erase(key)
	check(current == original, "Visual scientific state unchanged")
	# No event-driven hover tween remains active after the pointer leaves.
	for tween in get_processed_tweens(): check(not tween.is_running(), "No idle animation remains running")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}, "\t")); file.close()
	print("VIOLET SLICE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
