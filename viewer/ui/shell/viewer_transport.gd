extends PanelContainer
## Presentation adapter: all sampling and preparation remain in the existing controllers.
const SeekPopover = preload("res://ui/shell/time_seek_popover.gd")
const SPEEDS = [.25, .5, .75, 1.0, 1.5, 2.0, 3.0, 4.0]
const SPEED_LABELS = ["0.25×", "0.5×", "0.75×", "1×", "1.5×", "2×", "3×", "4×"]
const FloatText = preload("res://ui/components/float64_text.gd")
const ResizeProfile = preload("res://ui/shell/resize_profile.gd")
var viewer
var shell
var rows: VBoxContainer
var primary: HBoxContainer
var secondary: HBoxContainer
var options: HBoxContainer
var actions: HBoxContainer
var index_hint: Label
var dragging_index := false
var displayed: Label
var requested: Label
var duration: Button
var show_remaining := false
const REQUESTED_DELAY_MS := 450
var pending_since_ms := -1
var pending_target = null
var pending_generation := -1
const NORMAL_RECORDED_RATE := 1.0
var rate: OptionButton
var loop: CheckButton
var seek_dialog
var source_generation := -1
var compact := false

func setup(owner_shell) -> void:
	shell = owner_shell; viewer = shell.viewer
	name = "ViewerTransport"
	add_theme_stylebox_override("panel", theme_box())
	var margin := MarginContainer.new(); add_child(margin)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 8 if side in ["left","right"] else 4)
	rows = VBoxContainer.new(); rows.alignment = BoxContainer.ALIGNMENT_CENTER; rows.add_theme_constant_override("separation", 8); margin.add_child(rows)
	primary = HBoxContainer.new(); primary.add_theme_constant_override("separation", 12); rows.add_child(primary)
	secondary = HBoxContainer.new(); rows.add_child(secondary); secondary.hide()
	# Construct the canonical transport directly; no hidden inspector transport.
	actions = HBoxContainer.new(); primary.add_child(actions)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shell.button(actions, "Previous sample", viewer._step_frame.bind(-1))
	viewer.play_button = shell.button(actions, "Play", viewer._toggle_playback)
	shell.button(actions, "Next sample", viewer._step_frame.bind(1))
	for pair in [[0,"Previous sample","⏮"],[1,"Play","▶"],[2,"Next sample","⏭"]]:
		var action: Button = actions.get_child(pair[0]); action.text = pair[2]; action.tooltip_text = pair[1]; action.custom_minimum_size = Vector2(40,32)
	var axis := VBoxContainer.new(); axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL; axis.custom_minimum_size.x = 200; axis.add_theme_constant_override("separation", 0); axis.size_flags_vertical = Control.SIZE_SHRINK_CENTER; primary.add_child(axis)
	var progress := HBoxContainer.new(); progress.add_theme_constant_override("separation",4); axis.add_child(progress)
	displayed = label(progress,"—"); displayed.custom_minimum_size.x = 48
	displayed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; displayed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	displayed.mouse_filter = Control.MOUSE_FILTER_STOP
	displayed.focus_mode = Control.FOCUS_ALL
	displayed.focus_entered.connect(func(): displayed.add_theme_stylebox_override("normal", shell.style_slice.theme.focus()))
	displayed.focus_exited.connect(func(): displayed.remove_theme_stylebox_override("normal"))
	displayed.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			open_seek(displayed); displayed.accept_event()
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			open_seek(displayed); displayed.accept_event())
	viewer.timeline = preload("res://ui/shell/prepared_timeline.gd").new(); viewer.timeline.step = 1
	viewer.timeline.value_changed.connect(viewer._timeline_changed)
	viewer.timeline.seek_requested.connect(func(): open_seek(viewer.timeline))
	progress.add_child(viewer.timeline); viewer.timeline.custom_minimum_size.y = 16
	# The endpoint-centred thumb extends half its texture beyond the track.
	progress.add_theme_constant_override("separation",4+ceili(viewer.timeline.get_theme_icon("grabber").get_width()*.5))
	viewer.timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	index_hint = label(self, ""); index_hint.top_level = true; index_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_hint.add_theme_stylebox_override("normal", shell.theme.box(&"surface.1", &"border.subtle", 4, 6, 4))
	index_hint.hide()
	viewer.timeline.drag_started.connect(func(): dragging_index = true; update_index_hint())
	viewer.timeline.drag_ended.connect(func(changed):
		dragging_index = false
		update_index_hint()
		if changed and viewer.session_log != null and viewer.generic_reader != null:
			var index := clampi(int(viewer.timeline.value), 0, viewer.generic_reader.frames.size() - 1)
			var target: float = viewer.generic_reader.frames[index].time
			viewer.session_log.last_seek_target = target
			viewer.session_log.record("PLAYBACK", "Scrub committed: sample=%d t=%.5f" % [index + 1, target], true))
	viewer.timeline.value_changed.connect(func(_value): update_index_hint())
	duration = shell.button(progress,"—",func(): show_remaining = not show_remaining; refresh())
	duration.tooltip_text = ""
	duration.custom_minimum_size = Vector2(48,24); duration.theme_type_variation = "CompactButton"; duration.flat = true
	duration.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal","hover","pressed","disabled"]:
		var style: StyleBox = duration.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 4; style.content_margin_right = 4
		duration.add_theme_stylebox_override(state,style)
	# A readout below the slider must not contribute to container minimum sizes.
	requested = label(viewer.timeline, ""); requested.theme_type_variation = "HelpLabel"
	requested.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	requested.offset_top = 2; requested.offset_bottom = 22; requested.clip_text = true
	requested.mouse_filter = Control.MOUSE_FILTER_STOP
	rate = OptionButton.new(); rate.name = "PlaybackSpeed"
	rate.fit_to_longest_item = false; rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(rate)
	for title in SPEED_LABELS: rate.add_item(title)
	rate.item_selected.connect(func(index):
		viewer.physical_rate = SPEEDS[index] * NORMAL_RECORDED_RATE
		if viewer.session_log != null: viewer.session_log.record("PLAYBACK", "Speed = " + SPEED_LABELS[index], true))
	options = HBoxContainer.new(); options.add_theme_constant_override("separation",8); primary.add_child(options)
	loop = CheckButton.new(); loop.text = "Loop"; loop.tooltip_text = "Loop recorded interval"; loop.size_flags_vertical = Control.SIZE_SHRINK_CENTER; options.add_child(loop)
	loop.toggled.connect(set_loop)
	_build_seek()
	minimum_size_changed.connect(shell.request_layout)
	refresh()

func theme_box() -> StyleBox:
	return shell.theme.box(&"surface.1", &"border.subtle", 0, 0, 0)

func set_loop(value: bool) -> void:
	if viewer.session_log != null: viewer.session_log.record("PLAYBACK", "Loop = " + str(value))
	if viewer.scene_layers != null and viewer.scene_layers.playback.enabled: viewer.scene_layers.playback.set_loop(value)
	else: viewer.scene_loop_playback = value

func toggle_loop() -> void:
	loop.button_pressed = not loop.button_pressed

func label(parent: Node, text: String) -> Label:
	var result := Label.new(); result.text = text; parent.add_child(result); return result

func _build_seek() -> void:
	seek_dialog = SeekPopover.new(); add_child(seek_dialog)
	seek_dialog.confirmed.connect(submit_seek)

func units() -> String:
	if viewer.generic_reader == null: return "Source units"
	var unit = viewer.generic_reader.metadata.get("time_unit","")
	return unit if unit is String and not unit.is_empty() and unit != "unknown" else "Source units"

func open_seek(anchor: Control = null) -> void:
	if viewer.generic_reader == null or viewer.generic_reader.frames.is_empty() or viewer.inspection_busy: return
	if anchor == null: anchor = displayed
	source_generation = viewer.capture_generation
	var frames: Array = viewer.generic_reader.frames
	seek_dialog.configure(float(frames[0].time), float(frames[-1].time), float(viewer.committed_sample.get("requested_time", frames[0].time)), displayed)
	var rect := anchor.get_global_rect()
	if anchor == viewer.timeline:
		var thumb: Rect2 = viewer.timeline.playhead_rect()
		rect = Rect2(viewer.timeline.global_position + thumb.position, thumb.size)
	seek_dialog.open_at(rect)

func submit_seek() -> void:
	if source_generation != viewer.capture_generation:
		if viewer.session_log != null: viewer.session_log.warning("Seek rejected: capture changed")
		seek_dialog.show_error("Capture changed. Reopen seek."); return
	var candidate: Dictionary = seek_dialog.source_target()
	if candidate.has("error"):
		if viewer.session_log != null: viewer.session_log.warning("Seek rejected: " + str(candidate.error))
		seek_dialog.show_error(candidate.error); return
	reset_requested()
	if not viewer._seek_time(candidate.value):
		if viewer.session_log != null: viewer.session_log.warning("Seek unavailable: target=" + str(candidate.value))
		seek_dialog.show_error("Seek unavailable. Check the recorded interval and inspection state."); return
	seek_dialog.hide(); refresh()

func pending_time():
	if viewer.scene_layers == null: return null
	var layers = viewer.scene_layers
	if (layers.playback != null and not layers.playback.readiness_error.is_empty()) or (layers.field_playback != null and not layers.field_playback.error.is_empty()) or (layers.mesh_playback != null and not layers.mesh_playback.error.is_empty()): return null
	for controller in [layers.playback,layers.field_playback,layers.mesh_playback]:
		if controller != null and controller.buffering and controller.pending_time != null: return controller.pending_time
	return null

func _process(_delta: float) -> void:
	# Empty startup has no transport clock or source-dependent state to poll.
	# Repeatedly assigning the same controls marks the Canvas dirty and forces
	# the entire 3D viewport to redraw even in low-processor mode.
	if viewer == null or (viewer.generic_reader == null and not shell.loading): return
	refresh()

func refresh() -> void:
	if viewer == null: return
	var loaded: bool = viewer.generic_reader != null and viewer.frame_count > 0
	var busy: bool = viewer.scene_layers != null and viewer.scene_layers.is_buffering()
	viewer.play_button.text = "Ⅱ" if viewer.playing else "▶"
	viewer.play_button.tooltip_text = "Pause" if viewer.playing else ("Preparing sample; playback will be available when ready" if busy else "Play")
	viewer.play_button.disabled = not loaded or (busy and not viewer.playing) or viewer.inspection_busy
	for index in [0,2]: actions.get_child(index).disabled = not loaded or viewer.inspection_busy
	viewer.timeline.editable = loaded and not viewer.inspection_busy
	viewer.timeline.refresh(viewer)
	rate.disabled = not loaded; loop.disabled = not loaded
	update_index_hint()
	var clock = viewer.committed_sample.get("requested_time")
	var timing := playback_timing()
	displayed.text = format_duration(timing.elapsed) if loaded else "—"
	duration.text = format_duration(timing.remaining,true) if show_remaining else format_duration(timing.total)
	if not loaded: duration.text = "—"
	var pending = pending_time()
	refresh_requested(pending,clock,Time.get_ticks_msec())
	var value: float = viewer.physical_rate
	var selected := SPEEDS.find(value / NORMAL_RECORDED_RATE)
	if rate.selected != selected: rate.select(selected)
	if selected < 0: rate.text = "—×" # Retain arbitrary saved rates without coercion.
	var font := rate.get_theme_font("font")
	var widest := font.get_string_size("0.75×", HORIZONTAL_ALIGNMENT_LEFT, -1, rate.get_theme_font_size("font_size")).x
	rate.custom_minimum_size.x = ceili(widest) + rate.get_theme_icon("arrow").get_width() + 24
	rate.tooltip_text = "Playback speed relative to 1×: 1 recorded unit per playback second. Negative values reverse; zero holds.\nExact controller rate: " + FloatText.format_value(value)
	loop.set_pressed_no_signal(viewer.scene_loop_playback)
	if seek_dialog.visible and source_generation != viewer.capture_generation: seek_dialog.hide()

func reset_requested() -> void:
	pending_since_ms = -1; pending_target = null; pending_generation = -1
	requested.text = ""; requested.tooltip_text = ""; requested.hide()

func refresh_requested(pending, clock, now_ms: int) -> void:
	# Observe published state only; this timer never schedules or delays a seek.
	if pending == null or pending == clock:
		reset_requested(); return
	if pending_since_ms < 0 or pending_target != pending or pending_generation != viewer.capture_generation:
		reset_requested()
		pending_since_ms = now_ms; pending_target = pending; pending_generation = viewer.capture_generation
	if now_ms-pending_since_ms < REQUESTED_DELAY_MS: return
	var first: float = viewer.generic_reader.frames[0].time if viewer.generic_reader != null and not viewer.generic_reader.frames.is_empty() else 0.0
	requested.text = "Requested time " + format_duration(float(pending) - first)
	requested.tooltip_text = "Waiting for the requested elapsed time to become visible."
	requested.show()

func update_index_hint() -> void:
	var index := int(viewer.timeline.value) if dragging_index else int(viewer.current_index)
	var text := "Sample index %d / %d" % [index+1,viewer.frame_count] if viewer.frame_count > 0 else "Sample index — / —"
	viewer.timeline.tooltip_text = "Drag to scrub · Double-click to seek\n"+text+"\nBuffered overlay: blue = selected fields prepared; teal = all visible layers prepared.\nRanges follow recorded source times on this sample-index axis. GPU staging may still briefly wait."
	index_hint.text = text
	index_hint.visible = dragging_index
	if dragging_index:
		index_hint.reset_size()
		var slider_rect: Rect2 = viewer.timeline.get_global_rect()
		index_hint.global_position = Vector2(clampf(get_global_mouse_position().x,slider_rect.position.x,maxf(slider_rect.position.x,slider_rect.end.x-index_hint.size.x)),slider_rect.position.y-index_hint.size.y-6)

static func format_duration(seconds: float, remaining := false) -> String:
	var text := SeekPopover.format_time(seconds)
	return "-"+text if remaining and seconds >= 1 else text

func playback_timing() -> Dictionary:
	# Nominal duration at the normal recorded-time speed, independent of the
	# selected multiplier or buffering. Only the committed clock drives progress.
	if viewer.generic_reader == null or viewer.generic_reader.frames.is_empty(): return {"elapsed":0.0,"total":0.0,"remaining":0.0}
	var frames: Array = viewer.generic_reader.frames
	var start: float = frames[0].time
	var end: float = frames[-1].time
	var time: float = clampf(float(viewer.committed_sample.get("requested_time",start)),start,end)
	var total: float = (end-start)/NORMAL_RECORDED_RATE
	var elapsed: float = (time-start)/NORMAL_RECORDED_RATE
	return {"elapsed":elapsed,"total":total,"remaining":maxf(0,total-elapsed)}

func layout(width: float, bottom: float) -> float:
	var profile_started := ResizeProfile.stamp()
	var narrow := width < 1200
	if options.get_parent() != (secondary if narrow else primary): options.reparent(secondary if narrow else primary)
	secondary.visible = narrow; compact = narrow
	rows.add_theme_constant_override("separation",16 if narrow else 8)
	var height := maxf(104 if narrow else 64, rows.get_combined_minimum_size().y+8)
	position = Vector2(0,bottom-height); size = Vector2(width,height)
	ResizeProfile.record("transport_layout", profile_started)
	return height
