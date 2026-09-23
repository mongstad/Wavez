extends PanelContainer
## Read-only shell composition of existing controllers; no worker polling or file I/O.
var shell
var viewer
var badge
var detail_button: Button
var jobs_button: Button
var jobs_dialog: AcceptDialog
var job_rows := {}
var failures := {} # Latest unacknowledged diagnostic per existing owner, not a job engine.
var observed := {}
var analysis_progress := ""
var analysis_request := ""
var analysis_result := "No analysis job in this session."
var selection_result := "No selection job in this session."
var elapsed := 0.0
var active_count := 0
var readiness := "No capture"
var readiness_detail := "Open a capture to begin."
var source_generation := -1
var refresh_count := 0
var live_details := ""
var live_identity := ""

func setup(owner_shell) -> void:
	shell = owner_shell; viewer = shell.viewer; name = "ViewerStatus"
	add_theme_stylebox_override("panel", shell.theme.box(&"surface.1", &"border.subtle", 0, 0, 0))
	var margin := MarginContainer.new(); add_child(margin)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,8)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,6)
	var row := HBoxContainer.new(); margin.add_child(row)
	badge = preload("res://ui/components/status_badge.gd").new(); row.add_child(badge)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.symbol.custom_minimum_size = Vector2(16,16)
	badge.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_button = Button.new(); detail_button.text = "Details…"; detail_button.flat = true; detail_button.theme_type_variation = "CompactButton"
	detail_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_button.pressed.connect(show_status); row.add_child(detail_button)
	jobs_button = shell.button(shell.transport.options, "Jobs (0)", open_jobs, "export")
	jobs_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	jobs_dialog = AcceptDialog.new(); jobs_dialog.title = "Jobs"; jobs_dialog.get_ok_button().text = "Close"; add_child(jobs_dialog)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(600,360); jobs_dialog.add_child(scroll)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)
	add_job(content,"Video export", reopen_video, func(): viewer.video_dialog.cancel_export())
	add_job(content,"Selections", func(): shell.show_section("Selections"), func(): viewer.selection_controller.cancel_query(); selection_result = "Cancelled. Completed selections remain available.")
	add_job(content,"Analysis", reopen_analysis, func(): viewer.selection_controller.temporal.cancel_analysis(); analysis_result = "Cancellation requested. Completed named results remain available.")
	add_job(content,"Matched views", func(): shell.show_section("Matched runs"), func(): viewer.selection_controller.temporal.matched.cancel())
	add_job(content,"Isosurface", func(): viewer.tools_ui.open("Isosurface"), func():
		if viewer.scene_layers != null: viewer.scene_layers.cancel_iso())
	var actions := HBoxContainer.new(); content.add_child(actions)
	shell.button(actions,"Failure details…",show_status,"warning")
	shell.button(actions,"Acknowledge failures",acknowledge,"close")
	jobs_dialog.visibility_changed.connect(func():
		if not jobs_dialog.visible: jobs_button.grab_focus())
	shell.details.visibility_changed.connect(func():
		if not shell.details.visible: live_details = "")
	viewer.video_dialog.job_changed.connect(video_changed)
	viewer.selection_controller.temporal.matched.job_failed.connect(func(message): remember("Matched views",message))
	var jobs = viewer.selection_controller.jobs
	jobs.failed.connect(func(message): selection_result = message; remember("Selections",message))
	jobs.background_failed.connect(func(message): analysis_result = message; remember("Analysis",message))
	jobs.completed.connect(func(_result): selection_result = "Complete. See Selections for the current result.")
	jobs.background_completed.connect(func(_result): analysis_result = "Complete. Open the owning form for results and output details.")
	jobs.background_progress.connect(func(value): analysis_progress = "%s: %s / %s" % [str(value.get("stage","Working")).replace("_"," "),value.get("completed",0),value.get("total",0)])
	refresh()

func add_job(parent: Node, title: String, reopen: Callable, cancel: Callable) -> void:
	var box := VBoxContainer.new(); parent.add_child(box)
	var row := HBoxContainer.new(); box.add_child(row)
	var label := Label.new(); label.text = title; label.theme_type_variation = "SectionTitle"; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	var open_button: Button = shell.button(row,"Open…",func(): jobs_dialog.hide(); reopen.call())
	var details_button: Button = shell.button(row,"Details…",open_job_details.bind(title))
	var cancel_button: Button = shell.button(row,"Cancel",cancel)
	var text := Label.new(); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text.custom_minimum_size.x = 550; box.add_child(text)
	job_rows[title] = {"text":text,"cancel":cancel_button,"open":open_button,"details":details_button,"detail":"","active":false,"identity":""}

func open_job_details(title: String) -> void:
	refresh(); jobs_dialog.hide()
	shell.show_details(title,job_rows[title].detail)
	live_details = title if job_rows[title].active else ""
	live_identity = job_rows[title].identity

func refresh_job_details() -> void:
	if live_details.is_empty(): return
	if not shell.details.visible or shell.details.title != live_details:
		live_details = ""; return
	var row: Dictionary = job_rows[live_details]
	# Do not let a replacement job take over a detail view for an earlier job.
	if not live_identity.is_empty() and not row.identity.is_empty() and row.identity != live_identity:
		live_details = ""; return
	var text: TextEdit = shell.detail_text
	if text.text != row.detail:
		var vertical := text.scroll_vertical
		var horizontal := text.scroll_horizontal
		text.text = row.detail
		text.scroll_vertical = vertical; text.scroll_horizontal = horizontal
	# Publish the final state once, then leave a stable terminal record on screen.
	if not row.active: live_details = ""

func reopen_video() -> void:
	var video = viewer.video_dialog
	# Preserve preparation ownership; otherwise use the canonical open path so an
	# idle draft follows the current capture. Retain terminal diagnostics separately.
	if video.preparing: video.popup_centered(); return
	video.open()
	if video.pid <= 0 and not video.start_button.disabled and not video.job_status.is_empty(): video.message.text = str(video.job_status.detail)

func reopen_analysis() -> void:
	var operation: String = viewer.selection_controller.jobs.background_operation
	var task := "Temporal"
	if operation == "save_recipe": task = "Save analysis"
	elif operation == "load_recipe": task = "Load analysis"
	elif operation == "export_analysis": task = "Data"
	elif operation == "import_csv": task = "Diagnostics"
	elif operation in ["compare_series","result_overlay"]: task = "Compare"
	elif operation == "estimate_period": task = "Period"
	elif operation == "prepare_matched_render": task = "Matched runs"
	elif operation in ["space_time","result_heatmap"]: task = "Space time"
	elif operation in ["result_series","result_plot","result_page"]: task = "Results"
	viewer.tools_ui.open(task)

func open_jobs() -> void:
	jobs_dialog.popup_centered(Vector2i(640,440)); refresh()

func remember(owner: String, message: String) -> void:
	if not message.is_empty(): failures[owner] = message

func observe(owner: String, message: String) -> void:
	if observed.get(owner,"") != message:
		observed[owner] = message
		remember(owner,message)

func acknowledge() -> void:
	failures.clear()
	shell.open_error.hide()
	refresh()

func video_changed() -> void:
	var job: Dictionary = viewer.video_dialog.job_status
	if job.get("stage") == "failed": remember("Video export", str(job.get("detail","Export failed"))+"\n"+str(job.get("directory","")))
	refresh()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .2: return
	elapsed = 0
	refresh()

func refresh() -> void:
	if viewer == null: return
	refresh_count += 1
	if source_generation != viewer.capture_generation:
		source_generation = viewer.capture_generation
		for key in ["Particles","Fields","Meshes","Scene","Isosurface"]: observed.erase(key)
	readiness = "No capture"; readiness_detail = "Open a capture to begin."
	var layers = viewer.scene_layers
	if shell.loading:
		readiness = "Preparing…"; readiness_detail = "Opening capture; no percentage available."
	elif viewer.generic_reader != null:
		readiness = "Ready"; readiness_detail = "The committed visible sample is ready."
		if viewer.frame_count == 0:
			readiness = "Unavailable"; readiness_detail = "Waiting for a complete recorded sample."
		if layers != null:
			if layers.is_buffering(): readiness = "Preparing…"; readiness_detail = "Preparing the requested sample; the displayed clock remains committed."
			var errors := []
			for pair in [["Scene",layers.error],["Particles",layers.playback.readiness_error],["Fields",layers.field_playback.error],["Meshes",layers.mesh_playback.error]]:
				observe(pair[0],pair[1])
				if not str(pair[1]).is_empty(): errors.append(pair[0]+": "+pair[1])
			if not errors.is_empty(): readiness = "Unavailable"; readiness_detail = "\n".join(errors)
			for sample in layers.layer_samples:
				if sample.get("visible",false) and sample.get("status") == "unavailable":
					readiness = "Unavailable"; readiness_detail += "\n"+str(sample.id)+": "+str(sample.get("reason","No sample available at the displayed time."))
	update_jobs()
	var summary: String = readiness + ("   •   Failed — details" if not failures.is_empty() else "")
	if badge.label.text != summary: badge.configure("error" if not failures.is_empty() else ("success" if readiness == "Ready" else "info"), summary)
	tooltip_text = readiness_detail

func update_row(title: String, text: String, active: bool, cancellable: bool, available := true, identity := "") -> void:
	if active: active_count += 1
	var row: Dictionary = job_rows[title]
	row.detail = text
	row.active = active or cancellable; row.identity = identity
	var concise: String = text.get_slice("\n",0)
	if jobs_dialog.visible and row.text.text != concise: row.text.text = concise
	row.text.tooltip_text = text
	row.cancel.disabled = not cancellable; row.open.disabled = not available

func update_jobs() -> void:
	active_count = 0
	var video = viewer.video_dialog
	var state: Dictionary = video.job_status
	var text: String = str(state.get("stage","No video export in this session.")).replace("_"," ").capitalize()
	if video.pid > 0 and not video.last_progress.is_empty(): text += " — %s / %s frames" % [video.last_progress.get("current_frame",0),video.last_progress.get("total_frames",0)]
	if not state.is_empty(): text += "\n"+str(state.get("detail",""))+"\nOutput: "+str(state.get("output",""))+"\nJob, intermediates and diagnostics: "+str(state.get("directory",""))
	update_row("Video export",text,video.pid > 0 or video.preparing,video.pid > 0, not state.is_empty() or viewer.generic_reader != null,video.active_job_path)
	if state.get("stage") in ["complete","frames_ready","failed","cancelled"]: job_rows["Video export"].active = false
	var selections = viewer.selection_controller
	var jobs = selections.jobs
	if analysis_request != jobs.background_id:
		analysis_request = jobs.background_id; analysis_progress = "Preparing…"
	update_row("Selections", "Resolving source data…" if jobs.pending else ("Cancelling…" if not jobs.foreground_cancel_id.is_empty() else selection_result), jobs.pending or not jobs.foreground_cancel_id.is_empty(),jobs.pending,true,jobs.current_id if jobs.pending else jobs.foreground_cancel_id)
	var analysis_active: bool = jobs.background_pending or not jobs.background_cancel_id.is_empty()
	var analysis_text: String = jobs.background_operation.replace("_"," ").capitalize()+"\n"+analysis_progress if jobs.background_pending else ("Cancelling…" if analysis_active else analysis_result)
	update_row("Analysis",analysis_text+"\n"+jobs.directory,analysis_active and not video.preparing,jobs.background_pending,true,jobs.background_id if jobs.background_pending else jobs.background_cancel_id)
	var matched = selections.temporal.matched
	update_row("Matched views",matched.status.text,matched.pid > 0,matched.pid > 0 or matched.preparing,true,str(matched.prepared.get("path","")))
	var layers = viewer.scene_layers
	if layers != null:
		observe("Isosurface",layers.iso_error)
		update_row("Isosurface", (layers.iso_status.text if is_instance_valid(layers.iso_status) else "No extraction in this session.")+"\n"+layers.iso_directory,layers.iso_pid > 0,layers.iso_pid > 0,true,layers.iso_directory)
	else: update_row("Isosurface","Open a capture first.",false,false,false)
	refresh_job_details()
	var caption := "Jobs (%d)" % active_count
	if not failures.is_empty(): caption += " !"
	if jobs_button.text != caption: jobs_button.text = caption
	jobs_button.tooltip_text = "Reopen jobs, progress, cancellation and retained output details" + ("\nVideo export: "+str(state.get("stage","Preparing")) if video.pid > 0 or video.preparing else "")

func show_status() -> void:
	live_details = ""
	jobs_dialog.hide()
	var lines := [readiness,readiness_detail]
	for owner in failures: lines.append("\n"+owner+" — Failed\n"+str(failures[owner]))
	var layers = viewer.scene_layers
	if layers != null:
		for controller in [layers.playback,layers.field_playback,layers.mesh_playback]:
			if is_instance_valid(controller.label): lines.append(controller.label.text)
	lines.append("\nUse Jobs → Acknowledge failures to dismiss retained notices.\n\n"+shell.source_details())
	shell.show_details("Status details", "\n".join(lines))

func layout(width: float, bottom: float) -> float:
	var height := maxf(40,get_combined_minimum_size().y)
	position = Vector2(0,bottom-height); size = Vector2(width,height)
	return height
