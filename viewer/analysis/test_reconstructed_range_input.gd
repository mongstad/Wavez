extends SceneTree
## Presentation-only regression: preserve exact bounds while exposing their sign.
const Controller = preload("res://analysis/spectral_reconstruction_controller.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func run() -> void:
	var controller := Controller.new()
	controller.lower_range = SpinBox.new(); controller.upper_range = SpinBox.new()
	for spin in [controller.lower_range,controller.upper_range]:
		spin.min_value = -1e30; spin.max_value = 1e30; spin.step = 0.; spin.size = Vector2(140,42)
		spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_LEFT; root.add_child(spin)
		spin.get_line_edit().focus_exited.connect(func(): controller._reveal_range_starts.call_deferred())
	controller.upper_range.position.y = 50
	var bound := 2.0287075740689637
	controller.result_data = {"common_range":[-bound,bound]}
	controller._reset_range()
	await process_frame; await process_frame
	for spin in [controller.lower_range,controller.upper_range]:
		var editor: LineEdit = spin.get_line_edit()
		check(editor.caret_column == 0 and editor.get_scroll_offset() == 0.,"Unfocused exact range exposes its sign and leading digits")
	check(controller.lower_range.value == -bound and controller.upper_range.value == bound,"Presentation preserves the complete double bounds")
	var editor: LineEdit = controller.lower_range.get_line_edit()
	editor.grab_focus(); editor.caret_column = editor.text.length(); var caret := editor.caret_column
	controller._reveal_range_starts()
	check(editor.has_focus() and editor.caret_column == caret,"Focused precision editing retains its caret")
	editor.release_focus(); await process_frame; await process_frame
	check(editor.caret_column == 0 and editor.get_scroll_offset() == 0.,"Unfocused input returns to its leading sign")
	check(controller.lower_range.value == -bound and controller.upper_range.value == bound,"Focus changes preserve numerical values")
	if DisplayServer.get_name() != "headless":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--range-output="):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(arg.trim_prefix("--range-output="))
	controller.free()
	print("Reconstructed range presentation: 6 checks, %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
