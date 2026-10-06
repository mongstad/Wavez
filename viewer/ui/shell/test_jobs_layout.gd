extends SceneTree
const Viewer = preload("res://main.gd")

var output := ""
var checks := 0
var failures: Array[String] = []
const TITLES := ["Video export", "Selections", "Analysis", "Matched views", "Isosurface"]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func settle() -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw(false)

func picture(name: String) -> void:
	if not output.is_empty():
		root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func check_layout(ui, context: String) -> void:
	var header: HBoxContainer = ui.jobs_header_close.get_parent()
	var scroll: ScrollContainer = ui.jobs_dialog.find_children("*", "ScrollContainer", true, false)[0]
	var first_row: HBoxContainer = ui.job_rows["Video export"].open.get_parent()
	var clearance: float = first_row.get_global_rect().position.y - header.get_global_rect().end.y
	check(clearance >= 30 and clearance <= 34, context + ": full first row follows the measured header with 32 px clearance")
	check(first_row.get_global_rect().position.y >= scroll.get_global_rect().position.y, context + ": first row is inside its viewport")
	check((header.get_child(0) as Label).text == "Jobs" and ui.jobs_header_close.is_visible_in_tree(), context + ": title and header close remain visible")
	check(Rect2(Vector2.ZERO, Vector2(ui.jobs_dialog.size)).encloses(ui.jobs_footer_close.get_global_rect()), context + ": footer Close stays inside the dialog")
	var previous_bottom := -INF
	var cancel_edge := -INF
	for title in TITLES:
		var job: Dictionary = ui.job_rows[title]
		var row: HBoxContainer = job.open.get_parent()
		var label: Label = row.get_child(0)
		check(row.get_child_count() == 4 and label.text == title and row.get_child(1) == job.open and row.get_child(2) == job.details and row.get_child(3) == job.cancel, context + ": " + title + " retains its heading and actions")
		check(row.get_global_rect().position.y >= previous_bottom, context + ": " + title + " does not overlap the preceding row")
		previous_bottom = row.get_global_rect().end.y
		for action in [job.open, job.details, job.cancel]:
			check(action.size.x >= 88 and action.get_global_rect().position.y >= row.get_global_rect().position.y, context + ": " + title + " action width and row position")
		if cancel_edge > -INF:
			check(is_equal_approx(job.cancel.get_global_rect().end.x, cancel_edge), context + ": " + title + " Cancel column aligns")
		cancel_edge = job.cancel.get_global_rect().end.x
	check(ui.job_rows["Video export"].cancel.disabled, context + ": idle Video export Cancel remains disabled")
	if scroll.get_v_scroll_bar().visible:
		check(scroll.get_v_scroll_bar().get_global_rect().position.x - cancel_edge >= 8, context + ": Cancel clears the scrollbar")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var viewer = Viewer.new(); root.add_child(viewer); await settle()
	var ui = viewer.shell.status_ui
	for dimensions in [Vector2i(1440,900), Vector2i(1024,640)]:
		root.size = dimensions; await settle(); viewer.shell.layout(); await settle()
		ui.open_jobs(); await settle()
		check_layout(ui, "Idle " + str(dimensions))
		check(ui.job_rows["Selections"].open.has_focus(), "Empty Jobs focuses first enabled action")
		check(ui.jobs_dialog.size.x <= mini(dimensions.x,520) and ui.jobs_dialog.size.y <= dimensions.y, "Jobs fits " + str(dimensions))
		picture("jobs-idle-" + str(dimensions.x))
		ui.jobs_dialog.hide(); await settle()
		ui.open_jobs(); await settle()
		check_layout(ui, "Reopened " + str(dimensions))
		ui.jobs_dialog.hide()
	root.size = Vector2i(1024,640); await settle(); viewer.shell.layout(); await settle()
	var video = viewer.video_dialog
	video.preparing = true; video.job_status = {"stage":"preparing", "detail":"Preparing export"}
	ui.open_jobs(); await settle()
	check(not ui.job_rows["Video export"].open.disabled and not ui.job_rows["Video export"].cancel.disabled and ui.job_rows["Video export"].open.has_focus(), "Preparing video keeps Open, Cancel and first-action focus")
	var header: HBoxContainer = ui.jobs_header_close.get_parent()
	var first: HBoxContainer = ui.job_rows["Video export"].open.get_parent()
	check(first.get_global_rect().position.y - header.get_global_rect().end.y >= 30, "Preparing video row clears the header")
	picture("jobs-preparing-video")
	ui.jobs_dialog.hide(); video.preparing = false; video.job_status.clear(); ui.refresh()
	var scroll: ScrollContainer = ui.jobs_dialog.find_children("*", "ScrollContainer", true, false)[0]
	scroll.custom_minimum_size.y = 100
	ui.jobs_dialog.popup_centered(Vector2i(500,240)); await settle()
	check(scroll.get_v_scroll_bar().visible, "Compact Jobs scrolls")
	check_layout(ui, "Compact")
	picture("jobs-compact")
	scroll.scroll_vertical = 40; await settle()
	check(scroll.scroll_vertical > 0, "Compact Jobs can reveal later rows")
	ui.jobs_dialog.hide(); viewer.queue_free(); await settle()
	print("Jobs layout: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
