extends Window
signal job_changed
# Session-only presentation snapshot; worker lifecycle remains owned here.
var job_status := {}
var active_output := ""

const Job = preload("res://video/render_job.gd")
const Timeline = preload("res://video/offline_timeline.gd")
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
var keep: CheckButton
var inspection_sidecars: CheckButton
var output: LineEdit
var quality: OptionButton
var estimate: Label
var progress: ProgressBar
var message: Label
var start_button: Button
var cancel_button: Button
var save_dialog: FileDialog
var fields: GridContainer
var pid := -1
var active_directory := ""
var active_job_path := ""
var poll := 0.0
var opened_current := 0.0
var ffmpeg := ""
var g4_quota: SpinBox
var preparing := false
var last_progress: Dictionary = {}
var launch_ticks := 0

func _ready() -> void:
	title = "SimScope • Export Video"
	visible = false
	size = Vector2i(760, 800)
	min_size = Vector2i(600, 500)
	close_requested.connect(hide)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	fields = GridContainer.new()
	fields.columns = 2
	fields.add_theme_constant_override("h_separation", 16)
	box.add_child(fields)
	range_choice = choice("Range", ["Entire capture", "Current position to end", "Custom start/end"])
	start = number("Start • capture time", 0, -1e30, 1e30, .0001)
	end = number("End • capture time (exclusive)", 1, -1e30, 1e30, .0001)
	range_choice.item_selected.connect(func(_i: int): update_range())
	var resolution := choice("Resolution", ["1920 × 1080", "2560 × 1440", "3840 × 2160", "Custom"])
	width = number("Width", 1920, 64, 8192, 2)
	height = number("Height", 1080, 64, 8192, 2)
	width.editable = false; height.editable = false
	resolution.item_selected.connect(func(i: int):
		width.editable = i == 3; height.editable = i == 3
		if i < 3:
			width.value = [1920,2560,3840][i]; height.value = [1080,1440,2160][i]
	)
	var fps_choice := choice("Frame rate", ["24 FPS", "30 FPS", "60 FPS", "Custom"])
	fps_choice.select(1)
	fps = number("Output FPS", 30, 1, 240, 1)
	fps.editable = false
	fps_choice.item_selected.connect(func(i: int):
		fps.editable = i == 3
		if i < 3: fps.value = [24,30,60][i]
	)
	rate = number("Capture time units / video second", 1, .000001, 1e12, .000001)
	rate.tooltip_text = "Uses recorded timestamps, not interactive frames/second. Output n samples start + n / FPS × rate."
	camera_mode = choice("Camera", ["Current camera locked", "Current camera + orbit"])
	orbit = number("Orbit • radians / video second", .08, -10, 10, .001)
	rendering = choice("Rendering", ["Current state", "Cinematic preset", "Scientific preset"])
	overlays = check("Overlays", "Include viewer overlays")
	overlays.tooltip_text = "Include the current shell UI and the enabled particle legend. Independent scientific guides and markers retain their settings; desktop fullscreen is not exported."
	trails = check("Trails", "Include recorded history")
	trails.tooltip_text = "Scientific rendering suppresses trails, matching the interactive viewer."
	quality = choice("H.264 quality", ["High • CRF 18", "Balanced • CRF 21", "Compact • CRF 25"])
	keep = check("Temporary PNGs", "Keep after successful MP4 encoding")
	inspection_sidecars = check("Inspection records", "Save per-frame inspection JSON")
	g4_quota = number("G4 output quota • MiB",1024,1,65536,1)
	g4_quota.tooltip_text = "Selection-aware jobs reserve a finite total output ceiling, including PNGs, sidecars, recipe assets and encoding."
	var label := Label.new(); label.text = "Output MP4"; fields.add_child(label)
	var row := HBoxContainer.new(); fields.add_child(row)
	output = LineEdit.new(); output.placeholder_text = "Choose output .mp4 path"; output.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(output)
	var browse := Button.new(); browse.text = "Browse…"; row.add_child(browse)
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = PackedStringArray(["*.mp4 ; H.264 MP4"])
	save_dialog.file_selected.connect(func(path: String): output.text = path)
	add_child(save_dialog)
	browse.pressed.connect(func(): save_dialog.popup_centered_ratio(.8))
	estimate = Label.new(); estimate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(estimate)
	message = Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(message)
	progress = ProgressBar.new(); progress.min_value = 0; progress.max_value = 100; box.add_child(progress)
	var buttons := HBoxContainer.new(); box.add_child(buttons)
	start_button = Button.new(); start_button.text = "Start Export"; buttons.add_child(start_button)
	start_button.pressed.connect(start_export)
	cancel_button = Button.new(); cancel_button.text = "Cancel export"; cancel_button.disabled = true; buttons.add_child(cancel_button)
	cancel_button.pressed.connect(cancel_export)
	var close_button := Button.new(); close_button.text = "Close panel • continue in background"; buttons.add_child(close_button)
	close_button.pressed.connect(hide)
	for spin in [start, end, width, height, fps, rate]: spin.value_changed.connect(func(_v: float): update_estimate())

func choice(label: String, options: Array) -> OptionButton:
	var text := Label.new(); text.text = label; fields.add_child(text)
	var option := OptionButton.new(); option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in options: option.add_item(item)
	fields.add_child(option)
	return option

func number(label: String, initial: float, low: float, high: float, step_value: float) -> SpinBox:
	var text := Label.new(); text.text = label; fields.add_child(text)
	var spin := SpinBox.new(); spin.min_value = low; spin.max_value = high; spin.step = step_value; spin.value = initial
	fields.add_child(spin)
	return spin

func check(label: String, text: String) -> CheckButton:
	var name_label := Label.new(); name_label.text = label; fields.add_child(name_label)
	var control := CheckButton.new(); control.text = text; fields.add_child(control)
	return control

func open() -> void:
	popup_centered()
	if pid > 0: return
	timeline = Timeline.new()
	if not timeline.build(viewer):
		message.text = timeline.error
		start_button.disabled = true
		return
	start_button.disabled = false
	opened_current = viewer.frame_a.sim_time
	if viewer.frame_b != null:
		opened_current = lerpf(viewer.frame_a.sim_time, viewer.frame_b.sim_time, viewer.phase)
	orbit.value = viewer.orbit_speed
	camera_mode.select(1 if viewer.orbit_enabled else 0)
	overlays.button_pressed = viewer.overlay_visible
	trails.button_pressed = viewer.trails_enabled
	# Export is forward-only; initialize from canonical playback speed when positive.
	rate.value = viewer.physical_rate if viewer.physical_rate > 0 else 1.0
	ffmpeg = Job.find_ffmpeg()
	message.text = "FFmpeg found. Export runs in a separate process." if not ffmpeg.is_empty() else "FFmpeg is missing. Export will retain the complete PNG sequence and encoding instructions."
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
	return {"version":1, "capture_path":ProjectSettings.globalize_path(viewer.capture_path), "start_time":start_time, "end_time":end_time, "start_frame":timeline.bracket(start_time).get("a",-1), "end_frame":timeline.bracket(end_time).get("a",-1), "fps":int(fps.value), "width":int(width.value), "height":int(height.value), "playback_rate":rate.value, "output_path":output.text, "camera_mode":"orbit" if camera_mode.selected else "locked", "orbit_speed":orbit.value, "quality":["high","balanced","compact"][quality.selected], "keep_frames":keep.button_pressed, "inspection_sidecars":inspection_sidecars.button_pressed, "ffmpeg_path":ffmpeg, "rendering_method":RenderingServer.get_current_rendering_method()}

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
	estimate.text = "Source: %d committed samples\nOutput: %.3f seconds • %d frames\nTemporary PNG budget: up to approximately %.2f GiB before compression, plus MP4. End is exclusive; a still exports one frame." % [timeline.times.size() if timeline != null else 0, count/fps.value, count, gib]

func start_export() -> void:
	if pid > 0 or preparing or timeline == null: return
	var job := settings()
	job.state = Job.snapshot(viewer)
	if viewer.shell != null: job.presentation = viewer.shell.export_state()
	var with_selections: bool = viewer.selection_controller != null and not viewer.selection_controller.state.definitions.is_empty()
	if with_selections:
		var recipe := preload("res://analysis/inspection_v3.gd").scene_snapshot(viewer.selection_controller.temporal)
		if recipe.is_empty():message.text = "Bind the selection source before export.";return
		job.source = preload("res://analysis/inspection_v3.gd").unpack(recipe.payload).base.source
	else:job.source = preload("res://scene/inspection_state.gd").identity(viewer)
	if rendering.selected > 0:
		var clean := rendering.selected == 2
		job.state.clean_view = clean
		job.state.preset = "Scientific" if clean else "Cinematic"
		job.state.starfield_visible = not clean
		job.state.environment.glow_enabled = not clean
		job.state.environment.fog_enabled = not clean
		job.state.environment.background_mode = Environment.BG_COLOR if clean else Environment.BG_SKY
	job.state.overlay_visible = overlays.button_pressed
	job.state.trails_enabled = trails.button_pressed
	var invalid := Job.validate(job)
	if invalid.is_empty() and (job.start_time < timeline.times[0] or job.end_time > timeline.times[-1]): invalid = "Range must be within the capture's timestamps."
	if not invalid.is_empty():
		message.text = invalid
		return
	active_output = job.output_path
	last_progress = {}
	var name := ".simscope-export-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	active_directory = job.output_path.get_base_dir().path_join(name)
	active_job_path = active_directory.path_join("job.json")
	if DirAccess.make_dir_recursive_absolute(active_directory) != OK:
		message.text = "Cannot create temporary export directory."
		publish_job("failed", message.text)
		return
	if with_selections:
		preparing = true;start_button.disabled = true
		publish_job("preparing", "Verifying the pinned selection recipe")
		var durable = viewer.selection_controller.temporal.durable
		durable.save_to(active_directory.path_join("recipe.inspection"),true,int(g4_quota.value)*1048576)
		message.text = "Verifying the pinned selection recipe before launching the renderer…"
		var began := Time.get_ticks_msec()
		while viewer.selection_controller.jobs.busy() and Time.get_ticks_msec()-began < 150000:await get_tree().create_timer(.02).timeout
		if viewer.selection_controller.jobs.busy():viewer.selection_controller.jobs.cancel_background()
		preparing = false;start_button.disabled = false
		if not durable.last_recipe.has("path"):
			message.text = "Selection recipe preparation failed: "+durable.status.text
			publish_job("failed", message.text);return
		job.version = 2;job.inspection_path = durable.last_recipe.path;job.inspection_sha256 = durable.last_recipe.sha256;job.opened_paths = durable.opened_paths.duplicate();job.output_quota_bytes = str(int(g4_quota.value)*1048576)
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
	last_progress = {}
	progress.value = 0
	start_button.disabled = true
	cancel_button.disabled = false
	message.text = "Starting render process. The normal viewer remains usable."
	publish_job("starting", message.text)

func publish_job(stage: String, detail: String) -> void:
	job_status = {"stage":stage, "detail":detail, "directory":active_directory, "job":active_job_path,
		"output":active_output, "progress":last_progress.duplicate(true)}
	job_changed.emit()

func cancel_export() -> void:
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
	if pid <= 0: return
	poll += delta
	if poll < .2: return
	poll = 0
	var path := active_directory.path_join("progress.json")
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			last_progress = data
			progress.value = 100.0 * data.current_frame / maxf(1, data.total_frames)
			message.text = "%s\n%d / %d frames • %.1f seconds elapsed\n%s" % [data.message, data.current_frame, data.total_frames, data.elapsed_seconds, active_directory]
			publish_job("cancelling" if job_status.get("stage") == "cancelling" else str(data.stage), message.text)
	if not OS.is_process_running(pid):
		var exit_code := OS.get_process_exit_code(pid)
		pid = -1
		start_button.disabled = false
		cancel_button.disabled = true
		if last_progress.get("stage", "") not in ["complete", "frames_ready", "failed", "cancelled"]:
			message.text = "Render process stopped unexpectedly (exit %d). Intermediates retained: %s" % [exit_code, active_directory]
		publish_job(str(last_progress.get("stage", "failed")) if last_progress.get("stage", "") in ["complete", "frames_ready", "failed", "cancelled"] else "failed", message.text)
		viewer.status_label.text = message.text

func _exit_tree() -> void:
	# Closing the parent viewer requests a graceful worker/encoder shutdown.
	if pid > 0: cancel_export()
