extends Window
signal job_changed
# Session-only presentation snapshot; worker lifecycle remains owned here.
var job_status := {}
var active_output := ""

const Job = preload("res://video/render_job.gd")
const Timeline = preload("res://video/offline_timeline.gd")
const ProgressDetails = preload("res://video/progress_details.gd")
const TitledGroup = preload("res://ui/shell/titled_group.gd")
const Disclosure = preload("res://ui/components/disclosure.gd")
var viewer
var timeline
var range_choice: OptionButton
var start: SpinBox
var end: SpinBox
var width: SpinBox
var height: SpinBox
var fps: SpinBox
var rate: SpinBox
var camera_mode: OptionButton
var orbit: SpinBox
var rendering: OptionButton
var overlays: CheckButton
var trails: CheckButton
var inspection_sidecars: CheckButton
var output: LineEdit
var quality: OptionButton
var estimate: Label
var progress: ProgressBar
var message: Label
var status_scroll: ScrollContainer
var start_button: Button
var background_button: Button
var close_button: Button
var can_start := false
var save_dialog: FileDialog
var fields: VBoxContainer
var range_group
var range_fields: GridContainer
var video_fields: GridContainer
var camera_fields: GridContainer
var presentation_fields: GridContainer
var output_fields: GridContainer
var inspection_advanced
var summary_group
var groups: Dictionary = {}
var pid := -1
var active_directory := ""
var active_job_path := ""
var poll := 0.0
var opened_current := 0.0
var ffmpeg := ""
var g4_quota: SpinBox
var preparing := false
var active_selection_aware := false
var preparation_cancelled := false
var last_progress: Dictionary = {}
var launch_ticks := 0
var progress_ticks := 0
var settings_locked := false
var setting_states: Array[Dictionary] = []
var cancel_confirmation: ConfirmationDialog
var pending_cancel_directory := ""
var surface: PanelContainer
var header_close: Button

func _ready() -> void:
	title = "WAVEZ • Export Video"
	visible = false
	borderless = true
	size = Vector2i(700, 650)
	min_size = Vector2i(560, 360)
	close_requested.connect(hide)
	window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: hide())
	surface = PanelContainer.new(); add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); margin.add_child(box)
	var header := HBoxContainer.new(); box.add_child(header)
	var heading := Label.new(); heading.text = "Export Video"; heading.theme_type_variation = "PanelTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.mouse_filter = Control.MOUSE_FILTER_IGNORE; header.add_child(heading)
	header_close = Button.new(); header_close.theme_type_variation = "IconAction"; header_close.tooltip_text = "Close video export"
	header_close.custom_minimum_size = Vector2(32,32); header_close.pressed.connect(hide); header.add_child(header_close)
	header.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
			DisplayServer.window_start_drag(get_window_id()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	fields = VBoxContainer.new(); fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(fields)
	fields.add_theme_constant_override("separation", 8)
	range_group = add_group(fields, "Range")
	range_fields = group_rows(range_group)
	video_fields = group_rows(add_group(fields, "Video"))
	camera_fields = group_rows(add_group(fields, "Camera"))
	presentation_fields = group_rows(add_group(fields, "Presentation"))
	var output_group = add_group(fields, "Output")
	output_fields = group_rows(output_group)
	range_choice = choice("Mode", ["Full", "Current position to end", "Custom"], range_fields)
	start = number("Start", 0, -1e30, 1e30, .0001, range_fields)
	end = number("End", 1, -1e30, 1e30, .0001, range_fields)
	start.tooltip_text = "Recorded capture time."
	end.tooltip_text = "End time is exclusive; a still exports one frame."
	range_choice.item_selected.connect(func(_i: int): update_range())
	var resolution := choice("Resolution", ["1920 × 1080", "2560 × 1440", "3840 × 2160", "Custom"], video_fields)
	width = number("Width", 1920, 64, 8192, 2, video_fields)
	height = number("Height", 1080, 64, 8192, 2, video_fields)
	width.editable = false; height.editable = false
	resolution.item_selected.connect(func(i: int):
		width.editable = i == 3; height.editable = i == 3
		if i < 3:
			width.value = [1920,2560,3840][i]; height.value = [1080,1440,2160][i]
	)
	var fps_choice := choice("Frame rate", ["24 FPS", "30 FPS", "60 FPS", "Custom"], video_fields)
	fps_choice.select(1)
	fps = number("Output FPS", 30, 1, 240, 1, video_fields)
	fps.editable = false
	fps_choice.item_selected.connect(func(i: int):
		fps.editable = i == 3
		if i < 3: fps.value = [24,30,60][i]
	)
	rate = number("Playback rate", 1, .000001, 1e12, .000001, video_fields)
	rate.tooltip_text = "Simulation-time units per exported video second. Lower values play slower and sample time more closely; higher values play faster."
	camera_mode = choice("Camera", ["Current camera locked", "Current camera + orbit"], camera_fields)
	orbit = number("Orbit • radians / video second", .08, -10, 10, .001, camera_fields)
	rendering = choice("Rendering", ["Current state", "Cinematic preset", "Scientific preset"], presentation_fields)
	overlays = check("Overlays", "Include enabled viewport legends", presentation_fields)
	overlays.tooltip_text = "Include enabled particle, field and mesh viewport legends. Application controls are never exported; independent scientific guides and markers retain their settings."
	trails = check("Trails", "Include recorded history", presentation_fields)
	trails.tooltip_text = "Scientific rendering suppresses trails, matching the interactive viewer."
	quality = choice("H.264 quality", ["High • CRF 18", "Balanced • CRF 21", "Compact • CRF 25"], output_fields)
	g4_quota = number("G4 output quota • MiB",1024,1,65536,1, output_fields)
	g4_quota.tooltip_text = "Selection-aware jobs reserve a finite total output ceiling, including PNGs, sidecars, recipe assets and encoding."
	var label := Label.new(); label.text = "Output MP4"; output_fields.add_child(label)
	var row := HBoxContainer.new(); output_fields.add_child(row)
	output = LineEdit.new(); output.placeholder_text = "Choose output .mp4 path"; output.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(output)
	var browse := Button.new(); browse.text = "Browse…"; row.add_child(browse)
	inspection_advanced = Disclosure.new()
	output_group.body.add_child(inspection_advanced)
	var advanced_rows := GridContainer.new(); advanced_rows.columns = 2
	advanced_rows.add_theme_constant_override("h_separation", 16)
	inspection_advanced.configure(&"video.inspection", "Advanced", advanced_rows)
	inspection_advanced.set_expanded(false)
	inspection_sidecars = check("Inspection records", "Save per-frame inspection JSON", advanced_rows)
	inspection_sidecars.tooltip_text = "Optional for ordinary exports. Selection-aware exports always save per-frame inspection records as provenance."
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.use_native_dialog = true
	save_dialog.filters = PackedStringArray(["*.mp4 ; H.264 MP4"])
	save_dialog.mode_overrides_title = false
	save_dialog.title = "Export video"
	if viewer.file_dialog_preferences != null:
		viewer.file_dialog_preferences.attach(save_dialog)
	save_dialog.file_selected.connect(func(path: String):
		if pid <= 0 and not preparing: output.text = path)
	add_child(save_dialog)
	browse.pressed.connect(func():
		if pid <= 0 and not preparing:
			var directory: String = output.text.get_base_dir() if output.text.is_absolute_path() else viewer.file_locations.settings.video_dir
			if not directory.is_empty() and DirAccess.dir_exists_absolute(directory): save_dialog.current_dir = directory
			save_dialog.popup_centered_ratio(.8))
	summary_group = add_group(box, "Export summary")
	estimate = Label.new(); estimate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary_group.body.add_child(estimate)
	message = Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_group.body.add_child(message)
	status_scroll = ScrollContainer.new()
	status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	status_scroll.visible = false
	summary_group.body.add_child(status_scroll)
	progress = ProgressBar.new(); progress.min_value = 0; progress.max_value = 100; summary_group.body.add_child(progress)
	var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_END; box.add_child(buttons)
	start_button = Button.new(); start_button.theme_type_variation = "PrimaryButton"; buttons.add_child(start_button)
	start_button.pressed.connect(func():
		if pid > 0 or preparing: request_cancel_export()
		else: start_export())
	background_button = Button.new(); background_button.text = "Run in background"; background_button.theme_type_variation = "SecondaryButton"; buttons.add_child(background_button)
	background_button.pressed.connect(func():
		if pid > 0 or preparing: hide())
	close_button = Button.new(); close_button.text = "Cancel"; close_button.theme_type_variation = "SecondaryButton"; buttons.add_child(close_button)
	close_button.pressed.connect(hide)
	# The mutually exclusive secondary actions share the same width/position.
	var secondary_width := maxf(background_button.get_combined_minimum_size().x,close_button.get_combined_minimum_size().x)
	background_button.custom_minimum_size.x = maxf(180,secondary_width)
	close_button.custom_minimum_size.x = maxf(180,secondary_width)
	start_button.text = "Cancel export"
	start_button.custom_minimum_size.x = maxf(140,start_button.get_combined_minimum_size().x)
	cancel_confirmation = ConfirmationDialog.new()
	cancel_confirmation.title = ""
	cancel_confirmation.borderless = true
	cancel_confirmation.dialog_text = "Cancel video export?"
	cancel_confirmation.ok_button_text = "Yes"
	cancel_confirmation.cancel_button_text = "No"
	var confirmation_actions: HBoxContainer = cancel_confirmation.get_ok_button().get_parent()
	confirmation_actions.alignment = BoxContainer.ALIGNMENT_END
	confirmation_actions.add_theme_constant_override("separation",16)
	confirmation_actions.custom_minimum_size = Vector2(256, 0)
	for child in confirmation_actions.get_children():
		if child is Button: child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif child is Control: child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cancel_confirmation.get_ok_button().theme_type_variation = "DestructiveButton"
	cancel_confirmation.get_cancel_button().theme_type_variation = "SecondaryButton"
	cancel_confirmation.dialog_hide_on_ok = false
	cancel_confirmation.confirmed.connect(_confirm_cancel_export)
	cancel_confirmation.close_requested.connect(cancel_confirmation.hide)
	cancel_confirmation.visibility_changed.connect(func():
		if not cancel_confirmation.visible: pending_cancel_directory = "")
	visibility_changed.connect(func():
		if not visible: cancel_confirmation.hide())
	size_changed.connect(_layout_status)
	add_child(cancel_confirmation)
	_sync_action_buttons()
	for spin in [start, end, width, height, fps, rate]: spin.value_changed.connect(func(_v: float): update_estimate())

func add_group(parent: VBoxContainer, title: String):
	var group = TitledGroup.new(title)
	parent.add_child(group)
	groups[title] = group
	return group

func group_rows(group) -> GridContainer:
	var rows := GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 16)
	rows.add_theme_constant_override("v_separation", 6)
	group.body.add_child(rows)
	return rows

func choice(label: String, options: Array, target: GridContainer) -> OptionButton:
	var text := Label.new(); text.text = label; target.add_child(text)
	var option := OptionButton.new(); option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in options: option.add_item(item)
	target.add_child(option)
	return option

func number(label: String, initial: float, low: float, high: float, step_value: float, target: GridContainer) -> SpinBox:
	var text := Label.new(); text.text = label; target.add_child(text)
	var spin := SpinBox.new(); spin.min_value = low; spin.max_value = high; spin.step = step_value; spin.value = initial
	target.add_child(spin)
	return spin

func check(label: String, text: String, target: GridContainer) -> CheckButton:
	var name_label := Label.new(); name_label.text = label; target.add_child(name_label)
	var control := CheckButton.new(); control.text = text; target.add_child(control)
	return control

func open() -> void:
	if viewer.shell != null:
		theme = viewer.shell.style_slice.theme
		surface.add_theme_stylebox_override("panel",viewer.shell.style_slice.theme.flat_box(&"surface.1",0,0,0))
		header_close.icon = viewer.shell.style_slice.theme.chrome_icon("close")
		cancel_confirmation.theme = theme
	_sync_inspection_advanced()
	var available: Vector2 = viewer.get_viewport().get_visible_rect().size - Vector2(32,32)
	popup_centered(Vector2i(Vector2(700,650).min(available)))
	if pid > 0 or preparing:
		_sync_action_buttons(); return
	timeline = Timeline.new()
	if not timeline.build(viewer):
		message.text = timeline.error
		can_start = false; _sync_action_buttons()
		return
	if not viewer.committed_sample.has("requested_time"):
		message.text = "No committed scene sample to export."
		can_start = false; _sync_action_buttons()
		return
	can_start = true; _sync_action_buttons()
	# Particle pairs use their own cadence; phase belongs to the union clock.
	# Export starts at the scene actually displayed, including while a seek waits.
	opened_current = float(viewer.committed_sample.requested_time)
	orbit.value = viewer.orbit_speed
	camera_mode.select(1 if viewer.orbit_enabled else 0)
	overlays.button_pressed = viewer.overlay_visible
	trails.button_pressed = viewer.trails_enabled
	# Export is forward-only; initialize from canonical playback speed when positive.
	rate.value = viewer.physical_rate if viewer.physical_rate > 0 else 1.0
	ffmpeg = str(viewer.file_locations.ffmpeg_status().path)
	message.text = ""
	if output.text.is_empty() and not viewer.file_locations.settings.video_dir.is_empty():
		var directory: String = viewer.file_locations.settings.video_dir
		var stem: String = viewer.capture_path.get_file().get_basename()
		var candidate := directory.path_join(stem + ".mp4")
		var suffix := 2
		while FileAccess.file_exists(candidate):
			candidate = directory.path_join("%s-%d.mp4" % [stem, suffix]); suffix += 1
		output.text = candidate
	update_range()

func update_range() -> void:
	start.editable = range_choice.selected == 2
	end.editable = range_choice.selected == 2
	if timeline == null or timeline.times.is_empty(): return
	if range_choice.selected < 2:
		start.value = timeline.times[0] if range_choice.selected == 0 else opened_current
		end.value = timeline.times[-1]
	update_estimate()

func settings() -> Dictionary:
	# Preserve original float64 endpoints for non-custom ranges (no SpinBox rounding).
	var start_time: float = start.value
	var end_time: float = end.value
	if range_choice.selected < 2:
		start_time = timeline.times[0] if range_choice.selected == 0 else opened_current
		end_time = timeline.times[-1]
	return {"version":1, "capture_path":ProjectSettings.globalize_path(viewer.capture_path), "start_time":start_time, "end_time":end_time, "start_frame":timeline.bracket(start_time).get("a",-1), "end_frame":timeline.bracket(end_time).get("a",-1), "fps":int(fps.value), "width":int(width.value), "height":int(height.value), "playback_rate":rate.value, "output_path":output.text, "camera_mode":"orbit" if camera_mode.selected else "locked", "orbit_speed":orbit.value, "quality":["high","balanced","compact"][quality.selected], "keep_frames":false, "inspection_sidecars":inspection_sidecars.button_pressed, "ffmpeg_path":ffmpeg, "rendering_method":RenderingServer.get_current_rendering_method()}

func configured_job() -> Dictionary:
	# The dialog chooses rendering state; the worker chooses the viewport boundary.
	var job := settings()
	job.state = Job.snapshot(viewer)
	if viewer.shell != null: job.presentation = viewer.shell.export_state()
	if rendering.selected > 0:
		var clean := rendering.selected == 2
		job.state.clean_view = clean
		job.state.preset = "Scientific" if clean else "Cinematic"
		job.state.environment.glow_enabled = not clean
		job.state.environment.fog_enabled = not clean
		job.state.environment.background_mode = Environment.BG_COLOR if clean else Environment.BG_SKY
	job.state.overlay_visible = overlays.button_pressed
	job.state.trails_enabled = trails.button_pressed
	return job

func update_estimate() -> void:
	if estimate == null: return
	var start_time: float = start.value
	var end_time: float = end.value
	if timeline != null and not timeline.times.is_empty() and range_choice.selected < 2:
		start_time = timeline.times[0] if range_choice.selected == 0 else opened_current
		end_time = timeline.times[-1]
	if end_time < start_time:
		estimate.text = "End time must be at or after start time."
		return
	var count := Job.frame_total({"start_time":start_time, "end_time":end_time, "fps":fps.value, "playback_rate":rate.value})
	var gib := float(count) * width.value * height.value * 4 / pow(1024, 3)
	estimate.text = "Output: %.3f seconds • %d frames\nTemporary storage: %.2f GiB" % [count/fps.value, count, gib]

func start_export() -> void:
	if pid > 0 or preparing or timeline == null: return
	var availability: Dictionary = viewer.file_locations.ffmpeg_status()
	ffmpeg = str(availability.path)
	if ffmpeg.is_empty():
		message.text = "FFmpeg is required to encode MP4. Open Edit → Preferences → File Locations and choose a usable FFmpeg executable. " + str(availability.error)
		return
	var job := configured_job()
	if job.output_path is String and job.output_path.is_absolute_path():
		var directory_error: String = preload("res://ui/file_locations_preferences.gd").directory_problem(job.output_path.get_base_dir())
		if not directory_error.is_empty():
			message.text = "Video export destination is unavailable. Choose another location: " + directory_error
			return
	var with_selections := _selection_aware()
	active_selection_aware = with_selections
	if with_selections:
		var recipe := preload("res://analysis/inspection_v3.gd").scene_snapshot(viewer.selection_controller.temporal)
		if recipe.is_empty():message.text = "Bind the selection source before export.";return
		job.source = preload("res://analysis/inspection_v3.gd").unpack(recipe.payload).base.source
	else:
		var identity_began := Time.get_ticks_usec()
		job.source = preload("res://video/source_identity.gd").capture(viewer.generic_reader)
		job.source_identity_ms = (Time.get_ticks_usec()-identity_began)/1000.0
		if job.source.is_empty():
			message.text = "Cannot bind export to an unchanged local source. Reopen the capture; reliable high-resolution source stamps are required."
			return
	var invalid := Job.validate(job)
	if invalid.is_empty() and (job.start_time < timeline.times[0] or job.end_time > timeline.times[-1]): invalid = "Range must be within the capture's timestamps."
	if not invalid.is_empty():
		message.text = invalid
		return
	active_output = job.output_path
	last_progress = {}
	launch_ticks = Time.get_ticks_msec()
	progress_ticks = launch_ticks
	var name := ".wavez-export-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	active_directory = job.output_path.get_base_dir().path_join(name)
	active_job_path = active_directory.path_join("job.json")
	if DirAccess.make_dir_recursive_absolute(active_directory) != OK:
		message.text = "Cannot create temporary export directory."
		publish_job("failed", message.text)
		return
	if with_selections:
		preparing = true
		preparation_cancelled = false
		publish_job("preparing", "Verifying the pinned selection recipe")
		var durable = viewer.selection_controller.temporal.durable
		durable.save_to(active_directory.path_join("recipe.inspection"),true,int(g4_quota.value)*1048576)
		message.text = "Verifying the pinned selection recipe before launching the renderer…"
		var began := Time.get_ticks_msec()
		while viewer.selection_controller.jobs.busy() and not preparation_cancelled and Time.get_ticks_msec()-began < 150000:await get_tree().create_timer(.02).timeout
		if viewer.selection_controller.jobs.busy():viewer.selection_controller.jobs.cancel_background()
		preparing = false
		if preparation_cancelled:publish_job("cancelled","Selection recipe preparation cancelled.");return
		if not durable.last_recipe.has("path"):
			message.text = "Selection recipe preparation failed: "+durable.status.text
			publish_job("failed", message.text);return
		job.version = 2;job.inspection_sidecars = true;job.inspection_path = durable.last_recipe.path;job.inspection_sha256 = durable.last_recipe.sha256;job.opened_paths = durable.opened_paths.duplicate();job.output_quota_bytes = str(int(g4_quota.value)*1048576)
		job.exact_state = preload("res://analysis/inspection_v3.gd").pack(job.state)
		job.exact_timing = preload("res://analysis/inspection_v3.gd").pack({"start_time":job.start_time,"end_time":job.end_time,"fps":job.fps,"playback_rate":job.playback_rate})
		invalid = Job.validate(job)
		if not invalid.is_empty():message.text = invalid;publish_job("failed", message.text);return
	if Job.write_json(active_job_path, job) != OK:
		message.text = "Cannot write render job."
		publish_job("failed", message.text)
		return
	var args := Job.launch_arguments(active_job_path, job.fps)
	# Rendering backend must match the interactive appearance.
	args.insert(0, str(job.rendering_method)); args.insert(0, "--rendering-method")
	pid = OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		message.text = "Could not start Godot render process. Job retained: " + active_job_path
		publish_job("failed", message.text)
		return
	launch_ticks = Time.get_ticks_msec()
	progress_ticks = launch_ticks
	last_progress = {}
	progress.value = 0
	message.text = "Starting render process. The normal viewer remains usable."
	publish_job("starting", message.text)

func _sync_action_buttons() -> void:
	var active := pid > 0 or preparing
	start_button.text = "Cancel export" if active else "Start Export"
	start_button.theme_type_variation = "DestructiveButton" if active else "PrimaryButton"
	start_button.disabled = not can_cancel_export() if active else not can_start
	if cancel_confirmation != null and (not can_cancel_export() or pending_cancel_directory != active_directory):
		cancel_confirmation.hide()
	start_button.tooltip_text = ""
	background_button.disabled = not active
	background_button.visible = active
	close_button.visible = not active
	var has_status := active or not job_status.is_empty()
	summary_group.set_title("Export status" if has_status else "Export summary")
	estimate.visible = not has_status
	progress.visible = has_status
	if has_status:
		if message.get_parent() != status_scroll: message.reparent(status_scroll)
		status_scroll.visible = true
		_layout_status()
	else:
		if message.get_parent() != summary_group.body:
			message.reparent(summary_group.body)
			summary_group.body.move_child(message, 1)
		status_scroll.visible = false
	_sync_settings(active)

func _layout_status() -> void:
	if status_scroll != null:
		status_scroll.custom_minimum_size.y = clampf(size.y * 0.22, 72, 140)

func _sync_settings(active: bool) -> void:
	if settings_locked == active:return
	settings_locked = active
	if active:
		save_dialog.hide()
		_lock_fields(fields)
	else:
		# Restore each control's idle policy (e.g. preset dimensions remain read-only).
		for state in setting_states:state.control.set(state.property,state.value)
		setting_states.clear()

func _lock_fields(node: Node) -> void:
	for control in node.get_children():
		var property := ""
		if control is SpinBox or control is LineEdit:property = "editable"
		elif control is BaseButton:property = "disabled"
		if not property.is_empty():
			setting_states.append({"control":control,"property":property,"value":control.get(property)})
			if control is OptionButton:control.get_popup().hide()
			control.set(property,property == "disabled")
		else:_lock_fields(control)

func publish_job(stage: String, detail: String) -> void:
	var now := Time.get_ticks_msec()
	var seconds := maxf(0, (now - launch_ticks) / 1000.0)
	if not last_progress.is_empty():
		seconds = float(last_progress.get("elapsed_seconds", seconds))
		if last_progress.get("stage", "") not in ProgressDetails.TERMINAL:
			seconds += maxf(0, (now - progress_ticks) / 1000.0)
	job_status = {"stage":stage, "detail":detail, "directory":active_directory, "job":active_job_path,
		"output":active_output, "progress":last_progress.duplicate(true),
		"elapsed_seconds":seconds, "snapshot_ticks":now, "progress_ticks":progress_ticks}
	message.text = status_summary()
	_sync_action_buttons()
	job_changed.emit()

func progress_details() -> String:
	return ProgressDetails.format(job_status, Time.get_ticks_msec())

func status_summary() -> String:
	return ProgressDetails.format(job_status, Time.get_ticks_msec(), true)

func _selection_aware() -> bool:
	return viewer.selection_controller != null and not viewer.selection_controller.state.definitions.is_empty()

func _sync_inspection_advanced() -> void:
	if inspection_advanced != null:
		inspection_advanced.visible = not (active_selection_aware if pid > 0 or preparing else _selection_aware())

# User actions share this gate. Shutdown keeps using the cooperative request below.
func can_cancel_export() -> bool:
	if job_status.get("stage","") in ProgressDetails.TERMINAL or job_status.get("stage") == "cancelling":return false
	return preparing or (pid > 0 and OS.is_process_running(pid))

func request_cancel_export() -> void:
	if not can_cancel_export() or cancel_confirmation.visible:return
	if not visible:popup_centered()
	pending_cancel_directory = active_directory
	if viewer.shell != null:cancel_confirmation.theme = viewer.shell.style_slice.theme
	cancel_confirmation.popup_centered()
	cancel_confirmation.get_cancel_button().grab_focus.call_deferred()

func _confirm_cancel_export() -> void:
	var matches := cancel_confirmation.visible and pending_cancel_directory == active_directory
	cancel_confirmation.hide()
	if matches and can_cancel_export():cancel_export()

func cancel_export() -> void:
	if preparing:
		preparation_cancelled = true
		viewer.selection_controller.jobs.cancel_background()
		publish_job("cancelling","Cancelling selection recipe preparation…")
		return
	if pid <= 0: return
	var f := FileAccess.open(active_directory.path_join("cancel"), FileAccess.WRITE)
	if f != null:
		f.close()
		message.text = "Cancelling after the current frame; completed PNGs will be retained."
		publish_job("cancelling", message.text)
	else:
		message.text = "Could not write cancellation request. Stop render process PID %d in the system monitor. Job retained: %s" % [pid, active_directory]
		publish_job("failed", message.text)

func _process(delta: float) -> void:
	if visible: _sync_inspection_advanced()
	if pid <= 0: return
	poll += delta
	if poll < .2: return
	poll = 0
	var path := active_directory.path_join("progress.json")
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			if data != last_progress: progress_ticks = Time.get_ticks_msec()
			last_progress = data
			progress.value = 100.0 * data.current_frame / maxf(1, data.total_frames)
			publish_job("cancelling" if job_status.get("stage") == "cancelling" else str(data.stage), str(data.message))
	if not OS.is_process_running(pid):
		var exit_code := OS.get_process_exit_code(pid)
		pid = -1
		if last_progress.get("stage", "") not in ["complete", "frames_ready", "failed", "cancelled"]:
			message.text = "Render process stopped unexpectedly (exit %d). Intermediates retained: %s" % [exit_code, active_directory]
		publish_job(str(last_progress.get("stage", "failed")) if last_progress.get("stage", "") in ProgressDetails.TERMINAL else "failed", str(last_progress.get("message", "")) if last_progress.get("stage", "") in ProgressDetails.TERMINAL else message.text)
		viewer.status_label.text = message.text
	elif not job_status.is_empty():
		message.text = status_summary()

func _exit_tree() -> void:
	# Closing the parent viewer requests a graceful worker/encoder shutdown.
	if pid > 0 or preparing: cancel_export()
