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
var index_label: Label
var displayed: Label
var requested: Label
var seek_button: Button
var rate
var rate_units: Label
var loop: CheckButton
var seek_dialog: AcceptDialog
var target
var seek_units: Label
var seek_error: Label
var source_generation := -1
var rate_mode := ""
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
	var axis := VBoxContainer.new(); axis.size_flags_horizontal = Control.SIZE_EXPAND_FILL; axis.custom_minimum_size.x = 200; axis.add_theme_constant_override("separation", 0); primary.add_child(axis)
	var caption := HBoxContainer.new(); axis.add_child(caption)
	label(caption,"Sample index").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	index_label = label(caption,"— / —")
	viewer.timeline.reparent(axis); viewer.timeline.custom_minimum_size.y = 16
	viewer.timeline.tooltip_text = "Union of recorded samples; equally spaced indices are not equal physical-time intervals."
	label(axis,"Union of recorded samples").theme_type_variation = "HelpLabel"
	var clock := VBoxContainer.new(); clock.custom_minimum_size.x = 230; clock.add_theme_constant_override("separation",0); primary.add_child(clock)
	displayed = label(clock,"Displayed time —"); requested = label(clock,"")
	for readout in [displayed,requested]:
		readout.clip_text = true; readout.custom_minimum_size.y = 20
	seek_button = shell.button(primary,"Seek…",open_seek); seek_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options = HBoxContainer.new(); options.add_theme_constant_override("separation",8); primary.add_child(options)
	viewer.time_option.fit_to_longest_item = true; viewer.time_option.clip_text = false
	viewer.time_option.reparent(options); viewer.time_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	viewer.time_option.set_item_text(0,"Sample index"); viewer.time_option.set_item_text(1,"Recorded time")
	viewer.time_option.tooltip_text = "Time mode; the timeline always uses union sample indices"
	var rate_box := HBoxContainer.new(); rate_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER; rate_box.add_theme_constant_override("separation",4); options.add_child(rate_box)
	rate_units = label(rate_box,"Rate")
	rate = NumberField.new(); rate.custom_minimum_size.x = 140; rate_box.add_child(rate)
	rate.committed.connect(func(value):
		if viewer.time_mode == "physical": viewer.physical_rate = value
		else: viewer.playback_fps = value)
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
	viewer.time_option.disabled = not loaded or viewer.inspection_busy
	rate.editor.editable = loaded; loop.disabled = not loaded
	index_label.text = "%d / %d" % [viewer.current_index+1,viewer.frame_count] if loaded else "— / —"
	var clock = viewer.committed_sample.get("requested_time")
	displayed.text = "Displayed time " + ("%.5f" % float(clock) if clock != null else "—")
	displayed.tooltip_text = "Displayed time " + (FloatText.format_value(float(clock)) if clock != null else "—") + " " + units()
	var pending = pending_time()
	requested.text = "Requested time %.5f" % float(pending) if pending != null and (clock == null or pending != clock) else ""
	requested.tooltip_text = "Requested time " + FloatText.format_value(float(pending)) + " " + units() if not requested.text.is_empty() else ""
	var value: float = viewer.physical_rate if viewer.time_mode == "physical" else viewer.playback_fps
	if rate_mode != viewer.time_mode or rate.model != value:
		rate.set_model(value); rate_mode = viewer.time_mode
	rate_units.text = "Rate · units/s" if viewer.time_mode == "physical" else "Rate · samples/s"
	rate.tooltip_text = "Recorded units per playback second" if viewer.time_mode == "physical" else "Samples per playback second"
	viewer.time_option.select(1 if viewer.time_mode == "physical" else 0)
	loop.set_pressed_no_signal(viewer.scene_loop_playback)
	if seek_dialog.visible and source_generation != viewer.capture_generation: seek_dialog.hide()

func layout(width: float, bottom: float) -> float:
	var narrow := width < 1200
	if options.get_parent() != (secondary if narrow else primary): options.reparent(secondary if narrow else primary)
	secondary.visible = narrow; compact = narrow
	var height := maxf(104 if narrow else 64, rows.get_combined_minimum_size().y+8)
	position = Vector2(0,bottom-height); size = Vector2(width,height)
	return height
