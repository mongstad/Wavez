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

func _initialize() -> void: run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else: print("PASS: " + description)

func run() -> void:
	var viewer := FakeViewer.new(); root.add_child(viewer)
	var dialog = Dialog.new(); dialog.viewer = viewer; root.add_child(dialog)
	await process_frame
	dialog.open()
	await process_frame
	var scroll: ScrollContainer = dialog.range_group.get_parent().get_parent()
	var group_style: StyleBoxFlat = dialog.range_group.get_theme_stylebox("panel")
	check(group_style.border_width_left > 0 and group_style.border_width_top > 0, "Range, Start and End have a visible border")
	check(dialog.range_fields.get_child_count() == 6 and dialog.range_fields.get_child(0).text == "Range" and dialog.range_fields.get_child(2).text == "Start" and dialog.range_fields.get_child(4).text == "End", "Range, Start and End share the group")
	check(dialog.range_choice.get_item_text(0) == "Full" and dialog.range_choice.get_item_text(1) == "Current position to end" and dialog.range_choice.get_item_text(2) == "Custom", "Range labels retain their option indices")
	check(dialog.end.tooltip_text.contains("exclusive"), "End tooltip preserves exclusive-end guidance")
	check(not dialog.estimate.text.contains("Source:") and dialog.estimate.text.contains("Output:") and dialog.estimate.text.contains("Temporary storage:") and not dialog.estimate.text.contains("PNG budget"), "Estimate shows compact output and storage values")
	check(dialog.estimate.text == "Output: 2.267 seconds • 68 frames\nTemporary storage: 0.53 GiB", "Estimate retains frame count and uncompressed storage calculation")
	check(dialog.message.text.is_empty(), "Available-state notice does not announce FFmpeg success")
	for dimensions in [Vector2i(700, 650), Vector2i(560, 360)]:
		dialog.size = dimensions
		await process_frame
		var group_rect: Rect2 = dialog.range_group.get_global_rect()
		var scroll_rect: Rect2 = scroll.get_global_rect()
		check(group_rect.position.y >= scroll_rect.position.y and group_rect.end.x <= scroll_rect.end.x, "Range group stays inside scroll area at " + str(dimensions))
		check(dialog.header_close.get_global_rect().end.y <= group_rect.position.y, "Range group clears title bar at " + str(dimensions))
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
	dialog.preparing = true; dialog._sync_action_buttons()
	check(dialog.range_choice.disabled and not dialog.start.editable and not dialog.end.editable, "Active export locks grouped range controls")
	dialog.preparing = false; dialog._sync_action_buttons()
	check(not dialog.range_choice.disabled and dialog.start.editable and dialog.end.editable, "Idle export restores grouped range controls")
	dialog.start_export()
	check(dialog.pid <= 0 and dialog.message.text.contains("FFmpeg is required"), "Missing FFmpeg blocks export with an actionable error")
	dialog.hide(); dialog.queue_free(); viewer.queue_free()
	print("Video Export range group: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
