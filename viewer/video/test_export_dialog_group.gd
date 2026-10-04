extends SceneTree
## Focused presentation and range-contract checks for the Video Export dialog.
const Dialog = preload("res://video/export_dialog.gd")
const Job = preload("res://video/render_job.gd")
const StyleSlice = preload("res://ui/shell/violet_style_slice.gd")

class FakeLocations:
	extends RefCounted
	var settings := {"video_dir": ""}
	func ffmpeg_status() -> Dictionary: return {"path": "", "error": "Not found"}

class FakeShell:
	extends RefCounted
	var style_slice = StyleSlice.new()

class FakeViewer:
	extends Node
	var shell = FakeShell.new()
	var file_dialog_preferences = null
	var file_locations = FakeLocations.new()
	var capture_generation := 1
	var frame_count := 3
	var generic_reader := {"frames": [{"time": 1.125}, {"time": 2.25}, {"time": 3.375}]}
	var committed_sample := {"requested_time": 2.25}
	var orbit_speed := 0.08
	var orbit_enabled := false
	var overlay_visible := false
	var trails_enabled := false
	var physical_rate := 1.0
	var capture_path := "/tmp/export-dialog-test.wvz"

var checks := 0
var failures := 0
var output := ""

func _initialize() -> void: run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else: print("PASS: " + description)

func picture(window: Window, name: String) -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw(false)
	check(window.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")

func option_for(rows: GridContainer, label: String) -> OptionButton:
	for i in range(rows.get_child_count() - 1):
		var control := rows.get_child(i)
		if control is Label and control.text == label: return rows.get_child(i + 1)
	return null

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--group-output="): output = arg.trim_prefix("--group-output=")
	var viewer := FakeViewer.new(); root.add_child(viewer)
	var dialog = Dialog.new(); dialog.viewer = viewer; root.add_child(dialog)
	await process_frame
	dialog.open()
	await process_frame
	var scroll: ScrollContainer = dialog.range_group.get_parent().get_parent()
	var group_style: StyleBoxFlat = dialog.range_group.get_theme_stylebox("panel")
	check(group_style.border_width_left > 0 and group_style.border_width_top > 0, "Titled groups have a subtle themed border")
	check(dialog.fields.get_child_count() == 5 and dialog.groups.size() == 6, "Five setting groups and one separate summary group")
	for title in ["Range", "Video", "Camera", "Presentation", "Output", "Export summary"]:
		check(dialog.groups[title].title_label.text == title and dialog.groups[title].theme_type_variation == "TitledGroup", title + " uses the reusable titled group")
	check(dialog.range_fields.get_child_count() == 6 and dialog.range_fields.get_child(0).text == "Mode" and dialog.range_fields.get_child(2).text == "Start" and dialog.range_fields.get_child(4).text == "End", "Mode, Start and End share the titled Range group")
	check(dialog.video_fields.get_child_count() == 12 and dialog.camera_fields.get_child_count() == 4 and dialog.presentation_fields.get_child_count() == 6 and dialog.output_fields.get_child_count() == 10, "Controls remain inside their five functional groups")
	check(dialog.estimate.get_parent() == dialog.summary_group.body and dialog.message.get_parent() == dialog.summary_group.body and dialog.progress.get_parent() == dialog.summary_group.body, "Estimate, status and progress share the lower summary")
	check(dialog.range_choice.get_item_text(0) == "Full" and dialog.range_choice.get_item_text(1) == "Current position to end" and dialog.range_choice.get_item_text(2) == "Custom", "Range labels retain their option indices")
	check(dialog.end.tooltip_text.contains("exclusive"), "End tooltip preserves exclusive-end guidance")
	check(not dialog.estimate.text.contains("Source:") and dialog.estimate.text.contains("Output:") and dialog.estimate.text.contains("Temporary storage:") and not dialog.estimate.text.contains("PNG budget"), "Estimate shows compact output and storage values")
	check(dialog.estimate.text == "Output: 2.267 seconds • 68 frames\nTemporary storage: 0.53 GiB", "Estimate retains frame count and uncompressed storage calculation")
	check(dialog.estimate.visible and not dialog.progress.visible and dialog.summary_group.title_label.text == "Export summary", "Idle summary shows estimate without inactive progress")
	check(dialog.message.text.is_empty(), "Available-state notice does not announce FFmpeg success")
	check(dialog.close_button.tooltip_text.is_empty(), "Idle Cancel has no redundant tooltip")
	picture(dialog, "video-groups-idle")
	for dimensions in [Vector2i(700, 650), Vector2i(560, 360)]:
		dialog.size = dimensions
		await process_frame
		var group_rect: Rect2 = dialog.range_group.get_global_rect()
		var scroll_rect: Rect2 = scroll.get_global_rect()
		check(group_rect.position.y >= scroll_rect.position.y and group_rect.end.x <= scroll_rect.end.x, "Range group stays inside scroll area at " + str(dimensions))
		check(dialog.header_close.get_global_rect().end.y <= group_rect.position.y, "Range group clears title bar at " + str(dimensions))
		check(dialog.summary_group.get_global_rect().end.y <= dialog.start_button.get_global_rect().position.y, "Summary stays above actions at " + str(dimensions))
		if dimensions.y == 360: picture(dialog, "video-groups-compact")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await process_frame
	check(dialog.groups["Output"].get_global_rect().end.y <= scroll.get_global_rect().end.y, "Output group can be reached at minimum dialog size")
	scroll.scroll_vertical = 0
	dialog.range_choice.grab_focus()
	await process_frame
	var tab := InputEventKey.new(); tab.keycode = KEY_TAB; tab.physical_keycode = KEY_TAB; tab.pressed = true
	dialog.push_input(tab)
	await process_frame
	check(dialog.gui_get_focus_owner() != null and dialog.gui_get_focus_owner() != dialog.range_choice, "Tab moves keyboard focus from the first setting")
	dialog.range_choice.select(0); dialog.update_range()
	var full: Dictionary = dialog.settings()
	check(full.start_time == 1.125 and full.end_time == 3.375 and not dialog.start.editable and not dialog.end.editable, "Full range keeps exact source endpoints")
	dialog.range_choice.select(1); dialog.update_range()
	var current: Dictionary = dialog.settings()
	check(current.start_time == 2.25 and current.end_time == 3.375, "Current-position preset keeps its endpoints")
	dialog.range_choice.select(2); dialog.update_range()
	dialog.start.value = 2.25; dialog.end.value = 2.25
	check(dialog.start.editable and dialog.end.editable and Job.frame_total(dialog.settings()) == 1, "Custom still exports one frame")
	dialog.end.value = 2.0
	check(dialog.estimate.text == "End time must be at or after start time.", "Invalid range keeps its validation message")
	dialog.end.value = 3.0
	var resolution := option_for(dialog.video_fields, "Resolution")
	var frame_rate := option_for(dialog.video_fields, "Frame rate")
	resolution.select(2); resolution.item_selected.emit(2)
	frame_rate.select(0); frame_rate.item_selected.emit(0)
	check(dialog.width.value == 3840 and dialog.height.value == 2160 and not dialog.width.editable and not dialog.height.editable and dialog.fps.value == 24 and not dialog.fps.editable, "Resolution and frame-rate presets still update their dependent values")
	resolution.select(3); resolution.item_selected.emit(3)
	frame_rate.select(3); frame_rate.item_selected.emit(3)
	check(dialog.width.editable and dialog.height.editable and dialog.fps.editable, "Custom dimensions and FPS remain editable")
	dialog.camera_mode.select(1); dialog.orbit.value = 0.2
	dialog.quality.select(2); dialog.keep.button_pressed = true; dialog.inspection_sidecars.button_pressed = true
	dialog.output.text = "/tmp/example.mp4"
	var chosen: Dictionary = dialog.settings()
	check(chosen.camera_mode == "orbit" and is_equal_approx(chosen.orbit_speed, 0.2) and chosen.quality == "compact" and chosen.keep_frames and chosen.inspection_sidecars and chosen.output_path == "/tmp/example.mp4", "Camera and output choices retain their job settings")
	dialog.preparing = true; dialog._sync_action_buttons()
	check(dialog.range_choice.disabled and not dialog.start.editable and not dialog.end.editable, "Active export locks grouped range controls")
	check(dialog.quality.disabled and dialog.keep.disabled and not dialog.output.editable and dialog.groups["Export summary"].title_label.text == "Export status" and not dialog.estimate.visible and dialog.progress.visible, "Active export locks output and shows status area")
	dialog.launch_ticks = Time.get_ticks_msec() - 5000
	dialog.progress_ticks = Time.get_ticks_msec()
	dialog.last_progress = {"stage":"rendering", "current_frame":5, "total_frames":30, "elapsed_seconds":5.0}
	dialog.active_output = "/tmp/example.mp4"
	dialog.active_directory = "/tmp/wavez-export-example"
	dialog.publish_job("rendering", "Rendering frame")
	await process_frame
	check(dialog.message.get_parent() == dialog.status_scroll and dialog.message.text.contains("Rendering frame 5 / 30") and dialog.summary_group.get_global_rect().end.y <= dialog.start_button.get_global_rect().position.y, "Active progress remains readable above actions")
	check(scroll.size.y >= 72 and dialog.status_scroll.get_v_scroll_bar().visible, "Minimum-size active dialog retains settings access and scrollable status")
	picture(dialog, "video-groups-active")
	dialog.request_cancel_export()
	for i in 4: await process_frame
	check(dialog.cancel_confirmation.dialog_text == "Cancel video export?" and dialog.cancel_confirmation.get_ok_button().text == "Yes" and dialog.cancel_confirmation.get_cancel_button().text == "No", "Cancel confirmation uses concise question and Yes/No actions")
	check(dialog.cancel_confirmation.get_cancel_button().has_focus(), "No is default focus")
	check(dialog.cancel_confirmation.get_ok_button().size.x >= 96 and dialog.cancel_confirmation.get_cancel_button().size.x >= 96, "Both cancellation actions render at comfortable width")
	picture(dialog.cancel_confirmation, "video-cancel-confirmation")
	dialog.cancel_confirmation.hide()
	dialog.preparing = false; dialog._sync_action_buttons()
	check(not dialog.range_choice.disabled and dialog.start.editable and dialog.end.editable, "Idle export restores grouped range controls")
	dialog.start_export()
	check(dialog.pid <= 0 and dialog.message.text.contains("FFmpeg is required"), "Missing FFmpeg blocks export with an actionable error")
	dialog.hide(); dialog.queue_free(); viewer.queue_free()
	print("Video Export range group: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
