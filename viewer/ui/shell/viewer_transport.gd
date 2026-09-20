extends PanelContainer
## Presentation adapter: all sampling and preparation remain in the existing controllers.
const NumberField = preload("res://ui/components/number_field.gd")
const FloatText = preload("res://ui/components/float64_text.gd")
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
const NORMAL_RECORDED_RATE := 1.0
var seek_button: Button
var rate
var rate_units: Label
var loop: CheckButton
var seek_dialog: AcceptDialog
var target
var seek_units: Label
var seek_error: Label
var source_generation := -1
var legacy: Control
var compact := false

func setup(owner_shell) -> void:
	shell = owner_shell; viewer = shell.viewer
	name = "ViewerTransport"
	add_theme_stylebox_override("panel", theme_box())
	var margin := MarginContainer.new(); add_child(margin)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 8 if side in ["left","right"] else 4)
	rows = VBoxContainer.new(); rows.add_theme_constant_override("separation", 8); margin.add_child(rows)
	primary = HBoxContainer.new(); primary.add_theme_constant_override("separation", 12); rows.add_child(primary)
	secondary = HBoxContainer.new(); rows.add_child(secondary); secondary.hide()
	# Retain legacy recipe/control references, but remove their presentation from the dock.
	legacy = Control.new(); legacy.hide(); add_child(legacy)
	var playback: VBoxContainer = viewer.sections.Playback
	actions = playback.get_child(0)
	actions.reparent(primary); actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for pair in [[0,"Previous sample","⏮"],[1,"Play","▶"],[2,"Next sample","⏭"]]:
		var action: Button = actions.get_child(pair[0]); action.text = pair[2]; action.tooltip_text = pair[1]; action.custom_minimum_size = Vector2(40,32)
	var axis := VBoxContainer.new(); axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL; axis.custom_minimum_size.x = 200; axis.add_theme_constant_override("separation", 0); axis.size_flags_vertical = Control.SIZE_SHRINK_CENTER; primary.add_child(axis)
	var progress := HBoxContainer.new(); progress.add_theme_constant_override("separation",8); axis.add_child(progress)
	displayed = label(progress,"—"); displayed.custom_minimum_size.x = 48
	displayed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	viewer.timeline.reparent(progress); viewer.timeline.custom_minimum_size.y = 16
	viewer.timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	index_hint = label(self, ""); index_hint.top_level = true; index_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	index_hint.add_theme_stylebox_override("normal", shell.theme.box(&"surface.1", &"border.subtle", 4, 6, 4))
	index_hint.hide()
	viewer.timeline.drag_started.connect(func(): dragging_index = true; update_index_hint())
	viewer.timeline.drag_ended.connect(func(_changed): dragging_index = false; update_index_hint())
	viewer.timeline.value_changed.connect(func(_value): update_index_hint())
	duration = shell.button(progress,"—",func(): show_remaining = not show_remaining; refresh())
	duration.custom_minimum_size = Vector2(64,24); duration.theme_type_variation = "CompactButton"; duration.flat = true
	requested = label(axis,""); requested.theme_type_variation = "HelpLabel"
	requested.size_flags_horizontal = Control.SIZE_EXPAND_FILL; requested.clip_text = true
	seek_button = shell.button(primary,"Seek…",open_seek); seek_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options = HBoxContainer.new(); options.add_theme_constant_override("separation",8); primary.add_child(options)
	var rate_box := HBoxContainer.new(); rate_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER; rate_box.add_theme_constant_override("separation",4); options.add_child(rate_box)
	rate_units = label(rate_box,"Playback speed")
	rate = NumberField.new(); rate.custom_minimum_size.x = 140; rate_box.add_child(rate)
	label(rate_box,"×")
	rate.validator = func(value): return "Playback speed is too large." if not is_finite(value*NORMAL_RECORDED_RATE) else ""
	rate.committed.connect(func(value): viewer.physical_rate = value*NORMAL_RECORDED_RATE)
	loop = CheckButton.new(); loop.text = "Loop"; loop.tooltip_text = "Loop recorded interval"; loop.size_flags_vertical = Control.SIZE_SHRINK_CENTER; options.add_child(loop)
	loop.toggled.connect(func(value):
		if viewer.scene_layers != null and viewer.scene_layers.playback.enabled: viewer.scene_layers.playback.set_loop(value)
		else: viewer.scene_loop_playback = value)
	playback.reparent(legacy); viewer.section_buttons.Playback.reparent(legacy)
	_build_seek()
	minimum_size_changed.connect(shell.layout.call_deferred)
	refresh()

func theme_box() -> StyleBox:
	return shell.theme.box(&"surface.1", &"border.subtle", 0, 0, 0)

func label(parent: Node, text: String) -> Label:
	var result := Label.new(); result.text = text; parent.add_child(result); return result

func _build_seek() -> void:
	seek_dialog = AcceptDialog.new(); seek_dialog.title = "Seek time"; seek_dialog.dialog_hide_on_ok = false
	seek_dialog.get_ok_button().text = "Go"; seek_dialog.add_cancel_button("Cancel"); add_child(seek_dialog)
	var form := VBoxContainer.new(); form.custom_minimum_size.x = 420; seek_dialog.add_child(form)
	label(form,"Target")
	target = NumberField.new(); target.custom_minimum_size.x = 420; target.error_label.custom_minimum_size.x = 420; form.add_child(target)
	seek_units = label(form,"Source units")
	seek_error = label(form,""); seek_error.custom_minimum_size.x = 420; seek_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; seek_error.hide()
	target.validator = func(value):
		if viewer.generic_reader == null or viewer.generic_reader.frames.is_empty(): return "Open a capture with recorded samples first."
		if value < viewer.generic_reader.frames[0].time or value > viewer.generic_reader.frames[-1].time: return "Target is outside the recorded interval."
		return ""
	seek_dialog.confirmed.connect(submit_seek)
	seek_dialog.canceled.connect(func(): target.cancel())
	seek_dialog.visibility_changed.connect(func():
		if not seek_dialog.visible: seek_button.grab_focus())

func units() -> String:
	if viewer.generic_reader == null: return "Source units"
	var unit = viewer.generic_reader.metadata.get("time_unit","")
	return unit if unit is String and not unit.is_empty() and unit != "unknown" else "Source units"

func open_seek() -> void:
	if viewer.generic_reader == null or viewer.generic_reader.frames.is_empty(): return
	source_generation = viewer.capture_generation
	target.set_model(float(viewer.committed_sample.get("requested_time",viewer.generic_reader.frames[0].time)))
	seek_units.text = units(); seek_error.hide()
	seek_dialog.popup_centered(Vector2i(480,220)); target.editor.grab_focus()

func submit_seek() -> void:
	if source_generation != viewer.capture_generation:
		seek_error.text = "Capture changed. Close and reopen Seek time."; seek_error.show(); return
	if not target.commit(): return
	# Enter commits a local number-field draft only. Go is the sole submit action.
	if not viewer._seek_time(target.model):
		seek_error.text = "Seek could not be submitted. Check the recorded interval and inspection state."; seek_error.show(); return
	seek_dialog.hide(); refresh()

func pending_time():
	if viewer.scene_layers == null: return null
	for controller in [viewer.scene_layers.playback,viewer.scene_layers.field_playback,viewer.scene_layers.mesh_playback]:
		if controller != null and controller.buffering and controller.pending_time != null: return controller.pending_time
	return null

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if viewer == null: return
	var loaded: bool = viewer.generic_reader != null and viewer.frame_count > 0
	var busy: bool = viewer.scene_layers != null and viewer.scene_layers.is_buffering()
	viewer.play_button.text = "Ⅱ" if viewer.playing else "▶"
	viewer.play_button.tooltip_text = "Preparing sample; playback will be available when ready" if busy else ("Pause" if viewer.playing else "Play")
	viewer.play_button.disabled = not loaded or busy or viewer.inspection_busy
	for index in [0,2]: actions.get_child(index).disabled = not loaded or viewer.inspection_busy
	viewer.timeline.editable = loaded and not viewer.inspection_busy
	seek_button.disabled = not loaded or viewer.inspection_busy
	rate.editor.editable = loaded; loop.disabled = not loaded
	update_index_hint()
	var clock = viewer.committed_sample.get("requested_time")
	var timing := playback_timing()
	displayed.text = "%.1f" % timing.elapsed if loaded else "—"
	displayed.tooltip_text = "Elapsed playback at 1× (nominal seconds).\nDisplayed source time " + (FloatText.format_value(float(clock)) if clock != null else "—") + " " + units()
	duration.text = (("-%.1f" % timing.remaining) if timing.remaining >= .05 else "0.0") if show_remaining else "%.1f" % timing.total
	if not loaded: duration.text = "—"
	duration.tooltip_text = ("Remaining duration; click for total" if show_remaining else "Total duration; click for remaining") + ". Nominal playback seconds at 1×; buffering and speed do not change the interval."
	var pending = pending_time()
	requested.text = "Requested time %.5f" % float(pending) if pending != null and (clock == null or pending != clock) else ""
	requested.visible = not requested.text.is_empty()
	requested.tooltip_text = "Requested time " + FloatText.format_value(float(pending)) + " " + units() if not requested.text.is_empty() else ""
	var value: float = viewer.physical_rate
	if rate.model != value/NORMAL_RECORDED_RATE: rate.set_model(value/NORMAL_RECORDED_RATE)
	rate.tooltip_text = "Playback speed relative to 1×: 1 recorded unit per playback second. Negative values reverse; zero holds.\nExact controller rate: " + FloatText.format_value(value)
	rate.editor.tooltip_text = rate.tooltip_text
	loop.set_pressed_no_signal(viewer.scene_loop_playback)
	if seek_dialog.visible and source_generation != viewer.capture_generation: seek_dialog.hide()

func update_index_hint() -> void:
	var index := int(viewer.timeline.value) if dragging_index else int(viewer.current_index)
	var text := "Sample index %d / %d" % [index+1,viewer.frame_count] if viewer.frame_count > 0 else "Sample index — / —"
	viewer.timeline.tooltip_text = text
	index_hint.text = text
	index_hint.visible = dragging_index
	if dragging_index:
		index_hint.reset_size()
		var slider_rect: Rect2 = viewer.timeline.get_global_rect()
		index_hint.global_position = Vector2(clampf(get_global_mouse_position().x,slider_rect.position.x,maxf(slider_rect.position.x,slider_rect.end.x-index_hint.size.x)),slider_rect.position.y-index_hint.size.y-6)

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
	var narrow := width < 1200
	if options.get_parent() != (secondary if narrow else primary): options.reparent(secondary if narrow else primary)
	secondary.visible = narrow; compact = narrow
	var height := maxf(104 if narrow else 64, rows.get_combined_minimum_size().y+8)
	position = Vector2(0,bottom-height); size = Vector2(width,height)
	return height
