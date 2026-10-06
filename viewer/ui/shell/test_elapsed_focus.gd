extends SceneTree
## Rendered focus color across mouse/keyboard Seek dismissal (#277).
const Viewer = preload("res://main.gd")
var viewer
var output := ""
var checks := 0
var failures: Array[String] = []
var samples: Array = []
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message); push_error(message)
func settle():
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
func ready():
	var deadline := Time.get_ticks_msec() + 10000
	while viewer.scene_layers.is_buffering() and Time.get_ticks_msec() < deadline:
		viewer.scene_layers.tick(0); await process_frame
	viewer.shell.transport.refresh()
	check(not viewer.scene_layers.is_buffering(), "Preparation completed")
func click(point: Vector2, double := false):
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true; event.double_click = double; event.position = point; root.push_input(event)
	var release := event.duplicate(); release.pressed = false; release.double_click = false; root.push_input(release)
func key(code: Key, window = root):
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true; event.window_id = window.get_window_id()
	Input.parse_input_event(event)
	var release := event.duplicate(); release.pressed = false; Input.parse_input_event(release)
func border_sample(control: Control) -> Dictionary:
	var image := root.get_texture().get_image()
	var rect := Rect2i(control.get_global_rect())
	var violet := 0; var neutral := 0
	var expected: Color = viewer.shell.style_slice.theme.c(&"focus.ring")
	# Central top edge: omit glyphs, rounded corners and adjacent timeline.
	for y in range(maxi(0, rect.position.y - 7), rect.position.y + 3):
		for x in range(rect.position.x + 8, rect.end.x - 8):
			var c := image.get_pixel(x,y)
			if absf(c.r-expected.r)<.04 and absf(c.g-expected.g)<.04 and absf(c.b-expected.b)<.04: violet += 1
			if minf(c.r,minf(c.g,c.b)) > .65 and maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)) < .04: neutral += 1
	return {"violet_pixels":violet,"neutral_pixels":neutral}
func focused(ui, name: String):
	await settle()
	var measured := border_sample(ui.displayed); measured["state"] = name; samples.append(measured)
	check(ui.displayed.has_focus(), "Elapsed regains focus: " + name)
	check(measured.violet_pixels > 15 and measured.neutral_pixels == 0, "Rendered elapsed border is accepted violet: " + name)
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run():
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); root.add_child(viewer); viewer.set_process(false)
	viewer._open_capture(output.path_join("scene.wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await ready(); await settle()
	var ui = viewer.shell.transport
	var duration_styles: Array = []
	for state in ["normal","hover","pressed","disabled","focus"]: duration_styles.append(ui.duration.get_theme_stylebox(state))
	var font: Font = ui.displayed.get_theme_font("font"); var size: int = ui.displayed.get_theme_font_size("font_size")
	for dimensions in [Vector2i(1440,900),Vector2i(1024,640)]:
		root.size = dimensions; await settle(); viewer.shell.layout(); await settle()
		var width := str(dimensions.x)
		click(ui.displayed.get_global_rect().get_center()); await focused(ui, "mouse-focused-" + width)
		var stable := [ui.get_global_rect(),ui.displayed.get_global_rect(),ui.duration.get_global_rect(),viewer.timeline.get_global_rect()]
		for cycle in 2:
			for path in ["enter","escape","outside"]:
				var before: Dictionary = viewer.committed_sample.duplicate(true)
				click(ui.displayed.get_global_rect().get_center(), true); await settle()
				check(ui.seek_dialog.visible and ui.seek_dialog.editor.has_focus(), "Double-click opens focused editor")
				ui.seek_dialog.editor.text = "00:02" if cycle == 0 else "00:04"
				if path == "enter": key(KEY_ENTER, ui.seek_dialog)
				elif path == "escape": key(KEY_ESCAPE, ui.seek_dialog)
				else: click(Vector2(200,180))
				await settle(); await ready(); await focused(ui, path + "-" + width + "-" + str(cycle))
				check(not ui.seek_dialog.visible, "Seek closes via " + path)
				check(viewer.committed_sample.requested_time == (2.0 if cycle == 0 else 4.0) if path == "enter" else viewer.committed_sample == before, "Commit/cancel semantics retained: " + path)
				check(stable == [ui.get_global_rect(),ui.displayed.get_global_rect(),ui.duration.get_global_rect(),viewer.timeline.get_global_rect()], "Focus cycling preserves layout")
		key(KEY_TAB); await settle(); check(viewer.timeline.has_focus(), "Tab still reaches timeline")
		key(KEY_TAB); await settle(); check(ui.duration.has_focus(), "Tab still reaches duration")
		var unfocused := border_sample(ui.displayed)
		check(unfocused.violet_pixels == 0 and unfocused.neutral_pixels == 0 and not ui.displayed.has_theme_stylebox_override("normal"), "Unfocused elapsed outline clears")
		click(ui.displayed.get_global_rect().get_center()); await focused(ui, "refocused-" + width)
		check(ui.size.y == (64 if dimensions.x == 1440 else 104), "Accepted transport height retained")
		check(ui.displayed.get_theme_font("font") == font and ui.duration.get_theme_font("font") == font and ui.displayed.get_theme_font_size("font_size") == size and ui.duration.get_theme_font_size("font_size") == size, "Shared typography retained")
		check(ui.displayed.get_tooltip().is_empty() and ui.duration.get_tooltip().is_empty(), "Clock tooltips stay absent")
		var time: Dictionary = viewer.committed_sample.duplicate(true)
		click(ui.duration.get_global_rect().get_center()); await settle(); check(ui.show_remaining and ui.duration.text.begins_with("-"), "Remaining toggle retained")
		click(ui.duration.get_global_rect().get_center()); await settle(); check(not ui.show_remaining and viewer.committed_sample == time, "Total toggle leaves time unchanged")
	for i in duration_styles.size(): check(duration_styles[i] == ui.duration.get_theme_stylebox(["normal","hover","pressed","disabled","focus"][i]), "Duration state style unchanged " + str(i))
	viewer.free(); await process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rendered_borders":samples},"\t")); file.close()
	print("ELAPSED FOCUS: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
