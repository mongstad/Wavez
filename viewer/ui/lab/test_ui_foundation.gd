extends SceneTree
const Lab = preload("res://ui/lab/ui_laboratory.gd")
const Number = preload("res://ui/components/number_field.gd")
const ThemeFactory = preload("res://ui/theme/simscope_theme.gd")
const T = preload("res://ui/theme/simscope_tokens.tres")
const Scale = preload("res://ui/theme/ui_scale.gd")
var out := ""
var checks: Array = []
var metrics: Array = []
var contrasts: Array = []
var images: Array = []
var native_parser_mismatches: Array = []
var commits: Array = []
var intents: Array = []
var lab
var input_completed := false
var scaling_completed := false
var numeric_completed := false

func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	checks.append({"passed": value, "description": description})
	if not value: push_error(description)
func settle() -> void:
	for index in 4: await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func key(code: Key, shift: bool = false) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = true; event.shift_pressed = shift
	root.push_input(event); event = event.duplicate(); event.pressed = false; root.push_input(event)
func screenshot(viewport: Viewport, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	var img := viewport.get_texture().get_image()
	var path := out.path_join(name + ".png")
	check(img.save_png(path) == OK, "Screenshot " + name)
	images.append({"file": name + ".png", "size": [img.get_width(), img.get_height()], "sha256": FileAccess.get_sha256(path)})
func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * .2126 + linear.g * .7152 + linear.b * .0722
func contrast(foreground: Color, background: Color, target: float, name: String) -> void:
	var a := luminance(foreground); var b := luminance(background)
	var ratio := (maxf(a, b) + .05) / (minf(a, b) + .05)
	contrasts.append({"name": name, "foreground": foreground.to_html(), "background": background.to_html(), "ratio": ratio, "target": target})
	check(ratio >= target, "Contrast " + name)

func numeric_tests() -> void:
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("../float64-oracle.json")))
	for entry in oracle:
		var parsed := Number.FloatText.parse(entry.text)
		check(not parsed.has("error"), "Oracle accepted: " + entry.text)
		if parsed.has("error"): continue
		var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0, parsed.value)
		var native_bytes := PackedByteArray(); native_bytes.resize(8); native_bytes.encode_double(0, entry.text.to_float())
		if native_bytes.hex_encode() != entry.little_endian_hex: native_parser_mismatches.append({"text": entry.text, "expected": entry.little_endian_hex, "native": native_bytes.hex_encode()})
		check(bytes.hex_encode() == entry.little_endian_hex, "Independent binary64 reference: " + entry.text)
		var round_trip := Number.FloatText.parse(Number.FloatText.format_value(parsed.value))
		bytes.encode_double(0, round_trip.value)
		check(bytes.hex_encode() == entry.little_endian_hex, "Full-precision text round trip: " + entry.text)
	var field = Number.new(); root.add_child(field)
	field.committed.connect(func(value): commits.append(value))
	for value in [0.0, -0.0, 0.1, 1.2345678901234567, 1.2345678901234567e-19, 2.2250738585072014e-308, 4.9406564584124654e-324, 1.7976931348623157e308]:
		field.set_model(value)
		var bits := PackedByteArray(); bits.resize(8); bits.encode_double(0, value)
		check(field.commit(), "Unchanged float commit accepted: " + field.committed_text)
		var after := PackedByteArray(); after.resize(8); after.encode_double(0, field.model)
		check(bits == after, "Unchanged float64 bits preserved")
		# Verify displayed full-precision text parses back, allowing JSON's -0 rendering.
		after.encode_double(0, Number.FloatText.parse(field.editor.text).value)
		check(bits == after or value == 0.0, "Displayed float64 round trip")
	check(commits.is_empty(), "Refresh/unchanged commit emits no numeric intent")
	field.set_model(1.25)
	for text in ["", "abc", "nan", "inf", "1e999", "1e-999", "1.2.3"]:
		field.editor.text = text; check(not field.commit() and field.model == 1.25 and field.editor.text == text, "Reject and retain invalid draft: " + text)
	field.minimum = 0.0; field.maximum = 2.0
	field.editor.text = "-0.1"; check(not field.commit(), "Scientific range refusal")
	field.editor.text = "1.2345678901234567e-19"; check(field.commit() and field.model == Number.FloatText.parse("1.2345678901234567e-19").value, "Scientific notation commit")
	check(commits.size() == 1, "Changed numeric commit emits one intent")
	field.editor.text = "bad"; field.cancel(); check(field.editor.text == field.committed_text and commits.size() == 1, "Cancel silently restores last valid text")
	field.validator = func(value): return "Needs a positive value." if value <= 0 else ""
	field.editor.text = "0"; check(not field.commit(), "Caller-provided validation")
	field.queue_free()
	var integer = Number.new(); integer.kind = Number.Kind.EXACT_INTEGER; root.add_child(integer)
	for value in [-9223372036854775807 - 1, -9007199254740993, 0, 9007199254740993, 9223372036854775807]:
		integer.set_model(value); integer.editor.text = " " + str(value) + " "
		check(integer.commit() and integer.model is int and integer.model == value, "Exact int64 round trip: " + str(value))
	for text in ["9223372036854775808", "-9223372036854775809", "9007199254740993.0", "9e15", "--1", "", "+", "１２"]:
		integer.editor.text = text; check(not integer.commit(), "Exact integer refuses " + text)
	integer.editor.text = "+0009007199254740993"; check(integer.commit() and integer.model == 9007199254740993, "Exact decimal normalization")
	integer.queue_free()
	numeric_completed = true

func theme_tests() -> void:
	var theme := ThemeFactory.new()
	for background in ["surface.0", "surface.1", "surface.2", "surface.3"]:
		for text in ["text.primary", "text.secondary", "text.muted"]: contrast(T.color(text), T.color(background), 4.5, text + "/" + background)
		for color in ["focus.ring", "state.success", "state.warning", "state.error", "state.info"]: contrast(T.color(color), T.color(background), 3.0, color + "/" + background)
	for type in ["Button", "PrimaryButton", "DestructiveButton", "SelectedButton", "CompactButton", "OptionButton", "LineEdit"]:
		for state in ["normal", "hover", "pressed"]:
			if type == "LineEdit" and state != "normal": continue
			var style: StyleBoxFlat = theme.get_stylebox(state, type)
			var key: String = "font_color" if state == "normal" else "font_" + state + "_color"
			contrast(theme.get_color(key, type), style.bg_color, 4.5, type + "/" + state + "/text")
			# Solid primary fill is itself the boundary against the parent, not its inset pressed border.
			if type != "PrimaryButton": contrast(style.border_color, style.bg_color, 3.0, type + "/" + state + "/boundary")
	contrast(theme.get_color("font_uneditable_color", "LineEdit"), theme.get_stylebox("read_only", "LineEdit").bg_color, 4.5, "read-only value remains legible")
	contrast(theme.get_color("title_color", "Window"), theme.get_stylebox("embedded_border", "Window").bg_color, 4.5, "embedded dialog title text")
	contrast(T.color(&"accent.primary"), T.color(&"surface.1"), 3.0, "primary filled boundary")
	contrast(T.color(&"selection.text"), T.color(&"selection.fill"), 4.5, "selected rows/menu text")
	check(theme.icon_named("check") is DPITexture, "SVG icons use exportable per-viewport DPITexture resources")
	var mono: Font = theme.get_font("font", "NumericValue")
	var widths: Array = []
	for digit in "0123456789": widths.append(mono.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, T.numeric_size).x)
	check(widths.max() == widths.min(), "Numeric font has identical digit advances")
	check(mono.get_font_name() == "DejaVu Sans Mono", "Numeric font resolves bundled DejaVu Sans Mono")
	for code in [0x00b5, 0x0394, 0x00d7, 0x2212, 0x00b3]: check(mono.has_char(code), "Numeric glyph coverage U+%04X" % code)
	metrics.append({"numeric_font": mono.get_font_name(), "digit_widths": widths, "sans_height_14": theme.default_font.get_height(14), "mono_height_13": mono.get_height(13)})

func input_tests() -> void:
	var button: Button = lab.specimens.open.button
	button.grab_focus(); await settle()
	check(button.has_focus(), "Native button receives keyboard focus")
	check(lab.specimens.play_icon.button.size == Vector2(32, 32), "Icon action has a 32 by 32 logical target")
	check(lab.tabs.size.y > 600, "Header leaves more than 600 logical pixels for specimens at default size")
	lab.specimens.open.invoked.connect(func(id): intents.append(id))
	key(KEY_SPACE); await settle(); check(intents == [&"open"], "Space invokes focused action exactly once")
	key(KEY_TAB); await settle(); check(lab.specimens.save.button.has_focus(), "Tab traverses to the next action")
	key(KEY_TAB, true); await settle(); check(button.has_focus(), "Shift-Tab returns to previous action")
	var motion := InputEventMouseMotion.new(); motion.position = button.get_global_rect().get_center(); root.push_input(motion); await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_HOVER, "Native pointer hover state")
	await screenshot(root, "01-controls-focus-hover")
	var press := InputEventMouseButton.new(); press.position = button.get_global_rect().get_center(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
	root.push_input(press); await settle()
	check(button.get_draw_mode() == BaseButton.DRAW_PRESSED, "Native pointer press state")
	press = press.duplicate(); press.pressed = false; root.push_input(press); await settle()
	check(intents == [&"open", &"open"], "Pointer release invokes action exactly once")
	motion = InputEventMouseMotion.new(); motion.position = Vector2(2, 2); root.push_input(motion)
	check(button.has_focus(), "Focus persists after pointer leaves")
	check(lab.specimens.unavailable.button.disabled and lab.specimens.unavailable.reason.visible, "Disabled action has a durable visible explanation")
	check(lab.specimens.selected.button.get_draw_mode() == BaseButton.DRAW_PRESSED, "Selected native toggle has a pressed state")
	lab.specimens.enum.selection_requested.connect(func(id): intents.append(id))
	lab.specimens.enum.set_options([{"id": &"temperature", "label": "Temperature"}, {"id": &"rho", "label": "Renamed density"}], &"rho")
	check(lab.specimens.enum.selector.selected == 1 and intents.size() == 2, "Enum refresh preserves ID across reorder/rename without intent")
	lab.tabs.current_tab = 1; await settle()
	var number = lab.specimens.scientific
	number.editor.grab_focus(); number.editor.text = "invalid"; key(KEY_ENTER); await settle()
	check(number.error_label.visible and number.model == Number.FloatText.parse("1.2345678901234567e-19").value, "Enter refuses invalid native editor draft")
	key(KEY_ESCAPE); await settle(); check(number.editor.text == number.committed_text and not number.error_label.visible, "Escape restores draft through native key input")
	number.editor.text = "3e-18"; key(KEY_TAB); await settle()
	check(number.editor.text == "3e-18" and number.model == Number.FloatText.parse("1.2345678901234567e-19").value, "Focus loss retains draft without committing")
	number.cancel()
	await screenshot(root, "02-numbers")
	lab.tabs.current_tab = 2; await screenshot(root, "03-feedback")
	lab.tabs.current_tab = 3; await screenshot(root, "04-tokens")
	lab.tabs.current_tab = 0; await settle()
	lab.specimens.scalar.slider.grab_focus(); check(lab.specimens.scalar.slider.has_focus(), "Slider retains native keyboard focus plus shared ring"); await screenshot(root, "05-slider-focus")
	lab.specimens.menu.show_popup(); await screenshot(root, "06-menu")
	lab.specimens.menu.get_popup().hide()
	lab.tabs.current_tab = 2; await settle()
	lab.specimens.dialog.button.grab_focus(); lab.show_dialog(); await settle()
	var action_position: Vector2 = lab.dialog.actions.position
	lab.dialog.scroll.scroll_vertical = 250; await settle()
	check(lab.dialog.actions.position == action_position, "Dialog action row stays fixed while body scrolls")
	lab.dialog.scroll.scroll_vertical = 0
	check(lab.dialog.theme == lab.theme, "Independent dialog receives explicit shared theme")
	check(lab.dialog.actions.get_global_rect().end.y <= lab.dialog.get_visible_rect().size.y, "Dialog actions fit below scrollable body")
	await screenshot(root, "07-dialog")
	lab.dialog.dismiss(); await settle()
	check(lab.specimens.dialog.button.has_focus(), "Dialog close restores invoking focus")
	input_completed = true

func controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control: result.append(node)
	for child in node.get_children(): result.append_array(controls(child))
	return result

func scaling_tests() -> void:
	if DisplayServer.get_name() == "headless": return
	# Real offscreen Godot controls at all 16 physical-size/scale combinations.
	for resolution in [Vector2i(1024, 640), Vector2i(1440, 900), Vector2i(2560, 1440), Vector2i(3840, 2160)]:
		for factor in T.scales:
			var viewport := SubViewport.new(); viewport.size = resolution
			viewport.size_2d_override = Vector2i(Vector2(resolution) / factor); viewport.size_2d_override_stretch = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
			var specimen = Lab.new(); specimen.manage_window = false; viewport.add_child(specimen)
			specimen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			specimen.scale_picker.select(T.scales.find(factor))
			await settle()
			var data := {"physical": [resolution.x, resolution.y], "scale": factor, "logical": [viewport.size_2d_override.x, viewport.size_2d_override.y], "pages": [], "button_height": specimen.specimens.open.button.size.y, "compact_height": specimen.specimens.compact.button.size.y}
			check(specimen.specimens.open.button.size.y == 32, "32 px native action height at %s/%s" % [resolution, factor])
			check(specimen.specimens.compact.button.size.y == 28, "28 px compact action height at %s/%s" % [resolution, factor])
			for page in 4:
				specimen.tabs.current_tab = page; await settle()
				var scroll: ScrollContainer = specimen.tabs.get_child(page)
				var grid := scroll.get_child(0)
				var fit: bool = grid.size.x <= scroll.size.x
				check(fit, "No horizontal page overflow %s/%s/page%d" % [resolution, factor, page])
				data.pages.append({"page": page, "scroll_size": [scroll.size.x, scroll.size.y], "content_size": [grid.size.x, grid.size.y], "fits_width": fit})
			if (resolution == Vector2i(1440, 900) and factor in [1.0, 1.25, 1.5, 2.0]) or (resolution == Vector2i(3840, 2160) and factor == 2.0) or (resolution == Vector2i(1024, 640) and factor == 2.0):
				specimen.tabs.current_tab = 0; await screenshot(viewport, "scale-%dx%d-%d" % [resolution.x, resolution.y, roundi(factor * 100)])
			metrics.append(data)
			viewport.queue_free(); await process_frame
	# Root Window is a separate scale boundary from these SubViewports.
	for factor in T.scales:
		Scale.apply(root, factor); await settle()
		check(lab.specimens.open.button.get_theme_font_size("font_size") == 14 and lab.specimens.open.button.size.y == 32, "Root window scales logical metrics exactly once: " + str(factor))
		lab.show_dialog(); await settle()
		check(lab.dialog.content_scale_factor == factor, "Dialog inherits scale exactly once: " + str(factor))
		check(lab.dialog.size.x <= root.size.x * .9 + 1 and lab.dialog.size.y <= root.size.y * .9 + 1, "Dialog respects 90 percent physical bounds: " + str(factor))
		lab.dialog.dismiss()
	Scale.apply(root, 1.0)
	scaling_completed = true

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ux2-output="): out = arg.trim_prefix("--ux2-output=")
	if out.is_empty(): push_error("Supply --ux2-output=ABS"); quit(1); return
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(180).timeout.connect(func(): push_error("UX2 validator timed out"); quit(1))
	numeric_tests(); theme_tests()
	lab = Lab.new(); root.add_child(lab); lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	if DisplayServer.get_name() != "headless": await input_tests(); await scaling_tests()
	if DisplayServer.get_name() != "headless": check(input_completed and scaling_completed, "All native validation stages completed")
	check(numeric_completed, "All numeric validation stages completed")
	var failures := checks.filter(func(item): return not item.passed)
	var file := FileAccess.open(out.path_join("validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "checks": checks, "failures": failures, "metrics": metrics, "native_parser_mismatches": native_parser_mismatches, "contrast": contrasts, "images": images}, "\t")); file.close()
	lab.queue_free(); await process_frame
	print("UX2: %d checks, %d failures" % [checks.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
