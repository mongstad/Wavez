extends "res://analysis/spatial_spectrum_controller.gd"
## Shared source-clock/metadata helpers, separate request and presentation owner.
const BandPlane = preload("res://analysis/spectral_band_plane.gd")
const OPERATION := "spectral_band_map"
const SEQUENCE_OPERATION := "spectral_band_sequence"
const MAX_SELECTED_TIMES := 8
var support_xyz: Array[SpinBox] = []
var plane_axis: OptionButton
var center_counts: Array[SpinBox] = []
var hop: Array[SpinBox] = []
var band_low: LineEdit
var band_high: LineEdit
var visibility: CheckButton
var reference_visible: CheckButton
var opacity: HSlider
var palette: OptionButton
var plane
var legend: Label
var legend_panel: PanelContainer
var legend_gradient: TextureRect
var row_column_label: Label
var details_toggle: CheckButton
var presentation_suspended := false
var input_signature := ""
var header: HBoxContainer
var header_dragging := false
var window_placed := false
var sequence_start: SpinBox
var sequence_end: SpinBox
var sequence_stride: SpinBox
var sequence_notice: Label
var sequence_prepare_button: Button
var replay_enabled: CheckButton
var sequence_data := {}
var displayed_sequence_index := -1
var pending_operation := OPERATION
var estimate_signature := ""
var sequence_estimate := {}
var sequence_unavailable := ""

func setup(scene) -> void:
	viewer = scene; jobs = viewer.selection_controller.jobs
	window = Window.new(); window.title = "Spectral band map"; window.transient = true
	window.exclusive = false; window.borderless = true; window.hide(); window.min_size = Vector2i(560,380); window.size = Vector2i(620,740); add_child(window)
	window.close_requested.connect(close)
	window.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: header_dragging = false)
	window.focus_exited.connect(func(): header_dragging = false)
	viewer.get_viewport().size_changed.connect(_fit_window)
	surface = PanelContainer.new(); window.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",7); margin.add_child(body)
	header = HBoxContainer.new(); body.add_child(header)
	var title := Label.new(); title.text = "Spectral band map"; title.theme_type_variation = "PanelTitle"; title.mouse_filter = Control.MOUSE_FILTER_IGNORE; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close_button := Button.new(); close_button.text = "Close"; close_button.pressed.connect(close); header.add_child(close_button)
	header.mouse_filter = Control.MOUSE_FILTER_STOP; header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_header_input)
	scroller = ScrollContainer.new(); scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroller.follow_focus = true; body.add_child(scroller)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",5); scroller.add_child(content)
	_label(content,"Derived 3D-window band power, not optical light or physical energy.")
	var sources := HBoxContainer.new(); content.add_child(sources)
	object_choice = _choice(sources,"Field"); channel_choice = _choice(sources,"Channel")
	object_choice.item_selected.connect(func(i): select_object(str(object_choice.get_item_metadata(i))))
	channel_choice.item_selected.connect(func(i): select_channel(str(channel_choice.get_item_metadata(i))))
	var clock_row := HBoxContainer.new(); content.add_child(clock_row); _label(clock_row,"Native index")
	sample_index = _spin(clock_row,0,1000000,0)
	sample_index.value_changed.connect(func(_v):
		if changing: return
		_invalidate("Native sample changed. Compute to verify.")
		var rows := _rows()
		if int(sample_index.value) < rows.size(): requested_time = rows[int(sample_index.value)].time
		_load_sample(false))
	var pin := Button.new(); pin.text = "Use playhead"; pin.pressed.connect(pin_playhead); clock_row.add_child(pin)
	context = _label(content,"")
	_label(content,"Selected native indices (inclusive; at most 8)")
	var sequence_row := HBoxContainer.new(); content.add_child(sequence_row)
	_label(sequence_row,"First"); sequence_start = _spin(sequence_row,0,1000000,0)
	_label(sequence_row,"Last"); sequence_end = _spin(sequence_row,0,1000000,0)
	_label(sequence_row,"Stride"); sequence_stride = _spin(sequence_row,1,1000000,1)
	for control in [sequence_start,sequence_end,sequence_stride]: control.value_changed.connect(_input_changed)
	sequence_notice = _label(content,"")
	replay_enabled = CheckButton.new(); replay_enabled.text = "Replay prepared maps at exact native times"; replay_enabled.button_pressed = true; content.add_child(replay_enabled)
	replay_enabled.toggled.connect(func(_v): _sync_replay(); refresh_context())
	support_xyz = _xyz_row(content,"Support",128); size_xyz = support_xyz
	start_xyz = _xyz_row(content,"First start",0)
	for control in start_xyz: control.min_value = -1000000
	for control in support_xyz+start_xyz: control.value_changed.connect(_input_changed)
	var grid_row := HBoxContainer.new(); content.add_child(grid_row)
	var normal_label := Label.new(); normal_label.text = "Normal"; grid_row.add_child(normal_label)
	plane_axis = OptionButton.new(); grid_row.add_child(plane_axis)
	for axis in ["X","Y","Z"]: plane_axis.add_item(axis)
	plane_axis.select(2); plane_axis.item_selected.connect(_input_changed)
	var count_label := Label.new(); count_label.text = "Centers"; grid_row.add_child(count_label)
	for i in range(2):
		var spin := _spin(grid_row,1,64,5); center_counts.append(spin); spin.value_changed.connect(_input_changed)
	var hop_row := HBoxContainer.new(); content.add_child(hop_row)
	var hop_label := Label.new(); hop_label.text = "Hop (row, column)"; hop_row.add_child(hop_label)
	for i in range(2):
		var spin := _spin(hop_row,1,1000000,32); hop.append(spin); spin.value_changed.connect(_input_changed)
	row_column_label = _label(content,"")
	var band_row := HBoxContainer.new(); content.add_child(band_row)
	_label(band_row,"Band [low, high) cycles / source length")
	band_low = LineEdit.new(); band_low.text = "0.05"; band_low.size_flags_horizontal = Control.SIZE_EXPAND_FILL; band_row.add_child(band_low)
	band_high = LineEdit.new(); band_high.text = "0.15"; band_high.size_flags_horizontal = Control.SIZE_EXPAND_FILL; band_row.add_child(band_high)
	band_low.text_changed.connect(_input_changed); band_high.text_changed.connect(_input_changed)
	support_notice = _label(content,"")
	var visible_row := HBoxContainer.new(); content.add_child(visible_row)
	visibility = CheckButton.new(); visibility.text = "Show map"; visibility.button_pressed = true; visible_row.add_child(visibility)
	visibility.toggled.connect(func(_v): sync_visibility())
	reference_visible = CheckButton.new(); reference_visible.text = "Show source field"; visible_row.add_child(reference_visible)
	reference_visible.toggled.connect(_set_reference_visible)
	var presentation := HBoxContainer.new(); content.add_child(presentation)
	_label(presentation,"Map opacity")
	opacity = HSlider.new(); opacity.min_value = 0.; opacity.max_value = 1.; opacity.step = .01; opacity.value = .8; opacity.custom_minimum_size.x = 100; opacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL; presentation.add_child(opacity)
	opacity.value_changed.connect(func(_v): _presentation_changed())
	palette = OptionButton.new()
	for name in ["Viridis-like","Gray","Warm"]: palette.add_item(name)
	presentation.add_child(palette); palette.item_selected.connect(func(_i): _presentation_changed())
	_label(content,"Dots are measured centers; crosses and hatching are unavailable. Nearest color tiles are display only. Each center uses a full 3D window.")
	details_toggle = CheckButton.new(); details_toggle.text = "Details and numerical data"; content.add_child(details_toggle)
	var details := VBoxContainer.new(); content.add_child(details); details.hide(); details_toggle.toggled.connect(func(v): details.visible = v)
	geometry_detail = _label(details,""); summary = _label(details,""); warnings_detail = _label(details,"")
	table = RichTextLabel.new(); table.custom_minimum_size.y = 210; table.selection_enabled = true; details.add_child(table)
	status = _label(body,"Choose the signed amplitude channel and a bounded plane of window starts.")
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_END; body.add_child(actions)
	compute_button = Button.new(); compute_button.text = "Compute"; compute_button.pressed.connect(compute); actions.add_child(compute_button)
	sequence_prepare_button = Button.new(); sequence_prepare_button.text = "Prepare selected"; sequence_prepare_button.pressed.connect(prepare_sequence); actions.add_child(sequence_prepare_button)
	cancel_button = Button.new(); cancel_button.text = "Cancel"; cancel_button.pressed.connect(cancel); actions.add_child(cancel_button)
	plane = BandPlane.new(); viewer.add_child(plane)
	var canvas := CanvasLayer.new(); canvas.layer = 3; add_child(canvas)
	legend_panel = PanelContainer.new(); legend_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_panel.position = Vector2(18,88); legend_panel.custom_minimum_size = Vector2(310,0); canvas.add_child(legend_panel)
	var legend_margin := MarginContainer.new(); legend_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_panel.add_child(legend_margin)
	for side in ["left","right","top","bottom"]: legend_margin.add_theme_constant_override("margin_"+side,10)
	var legend_body := VBoxContainer.new(); legend_body.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_margin.add_child(legend_body)
	legend = _label(legend_body,""); legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_gradient = TextureRect.new(); legend_gradient.custom_minimum_size = Vector2(0,12); legend_gradient.stretch_mode = TextureRect.STRETCH_SCALE; legend_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; legend_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE; legend_body.add_child(legend_gradient)
	legend_panel.hide()
	jobs.spectral_band_map_completed.connect(_completed); jobs.spectral_band_map_failed.connect(_failed); jobs.spectral_band_map_progress.connect(_progress)
	RenderingServer.frame_pre_draw.connect(sync_visibility)
	_presentation_changed(); set_process(not viewer.offline_instance)

func _input_changed(_unused = null) -> void:
	if changing: return
	_invalidate("Map inputs changed. Compute to verify."); refresh_context()

func open() -> void:
	if viewer.spectral_reconstruction != null:
		viewer.spectral_reconstruction.presentation_enabled.button_pressed = false
	viewer._clear_manual_navigation()
	var focus: Control = viewer.get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	if _fingerprint() != source_fingerprint or current_object.is_empty(): _bind_current()
	window.theme = viewer.shell.style_slice.theme
	var panel_style = viewer.shell.style_slice.theme.flat_box(&"surface.1",0,0,0)
	surface.add_theme_stylebox_override("panel",panel_style); legend_panel.add_theme_stylebox_override("panel",panel_style)
	legend_panel.theme = window.theme
	if not window_placed:
		var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
		var offset := Vector2i(maxi(12,extent.x-window.size.x-16),_menu_bottom())
		window.position = offset if window.is_embedded() else viewer.get_window().position+offset
		window_placed = true
	window.show(); _fit_window(); refresh_context()
	if viewer.session_log != null: viewer.session_log.record("UI","Tools → Spectral band map opened")

func _menu_bottom() -> int:
	# Reserve the shell bar even when immersive edge reveal temporarily hides it.
	return int(ceil(viewer.shell.bar.get_global_rect().end.y))+8

func _fit_window() -> void:
	if window == null or not window.visible: return
	var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
	window.size = Vector2i(mini(620,maxi(560,extent.x-32)),mini(740,maxi(380,extent.y-_menu_bottom()-16)))
	if window.is_embedded(): _clamp_window()

func _clamp_window() -> void:
	var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
	window.position = Vector2i(clampi(window.position.x,8,maxi(8,extent.x-window.size.x-8)),clampi(window.position.y,_menu_bottom(),maxi(_menu_bottom(),extent.y-window.size.y-8)))

func _header_input(event: InputEvent) -> void:
	# Same embedded/native split as About; native movement stays compositor-owned.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		header_dragging = event.pressed
		if event.pressed and not window.is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
			DisplayServer.window_start_drag(window.get_window_id())
	elif event is InputEventMouseMotion and header_dragging and window.is_embedded():
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0: header_dragging = false; return
		window.position += Vector2i(event.relative); _clamp_window()

func close() -> void:
	header_dragging = false
	if not pending_id.is_empty(): cancel()
	window.hide()
	if previous_focus != null:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func _load_sample(default_region: bool) -> void:
	# Absence of signed amplitude is not permission to substitute energy density.
	if current_channel.is_empty(): current_channel = "amplitude"
	super._load_sample(false)
	if geometry.is_empty(): return
	if default_region:
		changing = true
		sequence_start.value = sample_index.value; sequence_end.value = mini(int(sample_index.value)+2,_rows().size()-1); sequence_stride.value = 1
		for axis in range(3): support_xyz[axis].value = 128; start_xyz[axis].value = -32
		var normal := plane_axis.selected
		start_xyz[normal].value = floor((float(geometry.shape[2-normal])-128.)/2.)
		var axes := _plane_axes()
		for i in range(2): hop[i].value = 32; center_counts[i].value = clampi(int(maxf(0.,float(geometry.shape[2-axes[i]])-128.)/32.)+3,1,8)
		changing = false
	if channel_choice.selected < 0: status.text = "Amplitude is absent. Select a recorded channel explicitly; energy is not a substitute for signed amplitude."
	refresh_context()

func set_sequence_range(first: int, last: int, stride := 1) -> void:
	changing = true; sequence_start.value = first; sequence_end.value = last; sequence_stride.value = stride; changing = false
	_input_changed()

func _sequence_arguments() -> Dictionary:
	var args := _request_arguments()
	if args.is_empty() or current_object != "field" or current_channel != "amplitude": return {}
	var first := int(sequence_start.value); var last := int(sequence_end.value); var stride := int(sequence_stride.value)
	if first < 0 or last < first or last >= _rows().size() or stride < 1 or (last-first)/stride+1 > MAX_SELECTED_TIMES: return {}
	args.erase("time"); args.indices = range(first,last+1,stride)
	return args

func _update_sequence_estimate() -> void:
	if sequence_notice == null: return
	var args := _sequence_arguments()
	var signature := source_fingerprint+JSON.stringify(args,"",true,true)
	if signature == estimate_signature: return
	estimate_signature = signature; sequence_estimate.clear()
	if args.is_empty():
		sequence_notice.text = "Select 1–8 native records of field / amplitude and valid map inputs. No automatic all-time preparation."
		return
	var support_cells := 1
	for count in args.support: support_cells *= int(count)
	var max_channel_bytes := 0
	var times: Array[String] = []
	var geometries := {}
	for index in args.indices:
		var description: Dictionary = viewer.generic_reader.describe(current_object,index)
		if description.is_empty() or not description.get("geometry") is Dictionary:
			sequence_notice.text = "Selected native metadata is unavailable. Preparation refused."; return
		var channel_bytes := 0
		for entry in description.get("arrays",[]):
			if entry.get("name") != current_channel: continue
			if entry.get("dtype") not in ["f4","f8"] or not entry.get("shape") is Array: continue
			channel_bytes = 4 if entry.dtype == "f4" else 8
			for count in entry.shape: channel_bytes *= int(count)
		if channel_bytes == 0:
			sequence_notice.text = "Signed amplitude is absent at selected native index %d. Preparation refused." % index; return
		max_channel_bytes = maxi(max_channel_bytes,channel_bytes)
		var native_geometry: Dictionary = description.geometry.duplicate(true)
		native_geometry.data_to_world = viewer.generic_reader.objects[current_object].get("data_to_world",[]).duplicate()
		geometries[index] = native_geometry
		times.append(_number(_rows()[index].time))
	# Metadata-only planning estimate. Worker admission independently verifies
	# descriptors, peak allocations, control size and the shared disk quota.
	var memory := maxi(80*1048576,support_cells*64+max_channel_bytes*3+32*1048576)
	var centers := int(args.grid.count[0])*int(args.grid.count[1])
	sequence_estimate = {"memory_bytes":memory,"selected_times":args.indices.size(),"total_centers":args.indices.size()*centers,"disk_bytes":2*1048576,"geometries":geometries}
	sequence_notice.text = "%d times: %s • %d windows\nEstimate: %.1f MiB worker RAM / %d MiB budget; 2 MiB disk reservation. Cache: at most 8 sequences / 64 MiB. Source verification may take longer than FFTs." % [args.indices.size(),", ".join(times),args.indices.size()*centers,float(memory)/1048576.,jobs.memory_bytes/1048576]
	if memory > jobs.memory_bytes: sequence_notice.text += "\nRequest exceeds the worker budget; reduce centers only affects time, not one-window RAM."

func prepare_sequence() -> void:
	if not _sequence_source_matches():
		var message := _sequence_source_notice("preparation"); reset_source(); status.text = message; return
	if _fingerprint() != source_fingerprint: _bind_current(); status.text = "Source changed. Review the selected records before preparing."; return
	if jobs.busy() or not jobs.foreground_cancel_id.is_empty(): status.text = "The analysis worker is busy. Wait or cancel its current job in Jobs."; return
	if viewer.scene_layers != null and viewer.scene_layers.iso_pid > 0: status.text = "Wait for surface extraction before source analysis."; return
	var args := _sequence_arguments(); _update_sequence_estimate()
	if args.is_empty() or sequence_estimate.is_empty(): status.text = "Choose valid field / amplitude inputs and 1–8 selected native records."; return
	if sequence_estimate.memory_bytes > jobs.memory_bytes: status.text = "Selected map support/source exceeds the estimated worker memory budget."; return
	var geometries: Dictionary = sequence_estimate.geometries.duplicate(true)
	_invalidate(""); pending_operation = SEQUENCE_OPERATION; request_selection_revision = viewer.selection_controller.state.revision
	var binding := {"path":ProjectSettings.globalize_path(viewer.capture_path),"committed_bytes":str(viewer.generic_reader.scan_offset)}
	if verified_source.has("sha256"): binding.sha256 = verified_source.sha256
	request_context = {"fingerprint":source_fingerprint,"source":binding.duplicate(true),"arguments":args.duplicate(true),"geometries":geometries,"revision":revision,"selection":request_selection_revision}
	input_signature = JSON.stringify(args,"",true,true); request_started_usec = Time.get_ticks_usec()
	viewer.selection_controller.temporal.update_pins()
	pending_id = jobs.request_background(binding,SEQUENCE_OPERATION,args,viewer.capture_generation,request_selection_revision,revision)
	status.text = "Verifying source and preparing the selected native maps…" if not pending_id.is_empty() else jobs.error
	if pending_id.is_empty(): sequence_unavailable = "Preparation unavailable: "+jobs.error
	refresh_context()

func _sequence_source_matches() -> bool:
	# The normal reader polls once per second. A fresh boundary check prevents
	# a newly verified worker source from being replayed over its older display
	# during that interval. No file-stat subprocess runs in the playback loop.
	if viewer.generic_reader == null or viewer.generic_reader.file == null: return false
	var reader = viewer.generic_reader
	return not reader.source_stamp.is_empty() and reader._source_stamp_profiled() == reader.source_stamp

func _sequence_source_notice(boundary: String) -> String:
	if viewer.generic_reader == null or viewer.generic_reader.file == null: return "The source is unavailable. Open a capture before preparing selected maps."
	if viewer.generic_reader.source_stamp.is_empty(): return "Selected-time replay needs a stable local file identity. Reopen the capture from a supported local Linux filesystem."
	return "Source bytes changed before %s. Let the capture refresh, then reopen Spectral band map." % boundary

func _plane_axes() -> Array:
	var axes: Array = []
	for axis in [2,1,0]:
		if axis != plane_axis.selected: axes.append(axis)
	return axes

func set_grid_xyz(start: Array, support: Array, axis, counts: Array, steps: Array) -> void:
	if start.size() != 3 or support.size() != 3 or counts.size() != 2 or steps.size() != 2: return
	var normal := "xyz".find(str(axis)) if axis is String else int(axis)
	if normal < 0 or normal > 2: return
	changing = true; plane_axis.select(normal)
	for i in range(3): start_xyz[i].value = start[i]; support_xyz[i].value = support[i]
	for i in range(2): center_counts[i].value = counts[i]; hop[i].value = steps[i]
	changing = false; _input_changed()

func _request_arguments() -> Dictionary:
	if geometry.is_empty() or current_channel.is_empty() or channel_choice.selected < 0: return {}
	var support: Array = []; var cells := 1
	for axis in [2,1,0]:
		var count := int(support_xyz[axis].value)
		if count < 4 or count > 256: return {}
		support.append(count); cells *= count
	if cells > 192*192*192 or int(center_counts[0].value)*int(center_counts[1].value) > 64: return {}
	if not band_low.text.is_valid_float() or not band_high.text.is_valid_float(): return {}
	var low := band_low.text.to_float(); var high := band_high.text.to_float()
	if not is_finite(low) or not is_finite(high) or low < 0 or high <= low: return {}
	var axes := _plane_axes()
	return {"object":current_object,"channel":current_channel,"time":requested_time,"support":support,"band":{"low":low,"high":high},"grid":{"plane_axis":"xyz"[plane_axis.selected],"fixed_start":int(start_xyz[plane_axis.selected].value),"start":[int(start_xyz[axes[0]].value),int(start_xyz[axes[1]].value)],"hop":[int(hop[0].value),int(hop[1].value)],"count":[int(center_counts[0].value),int(center_counts[1].value)]}}

func compute() -> void:
	if _fingerprint() != source_fingerprint: _bind_current(); status.text = "Source changed. Review the new map inputs before computing."; return
	if jobs.busy() or not jobs.foreground_cancel_id.is_empty(): status.text = "The analysis worker is busy. Wait or cancel its current job in Jobs."; return
	if viewer.scene_layers != null and viewer.scene_layers.iso_pid > 0: status.text = "Wait for surface extraction before source analysis."; return
	var args := _request_arguments()
	if args.is_empty(): status.text = "Choose a recorded channel, support 4–256 per axis (at most 192³), at most 64 centers, and finite 0 ≤ low < high."; return
	var point: Dictionary = viewer.generic_reader.bracket(current_object,requested_time)
	if point.is_empty() or int(point.a) != int(sample_index.value): status.text = "Pin a valid native sample using Use playhead or its index."; return
	_invalidate(""); pending_operation = OPERATION; request_selection_revision = viewer.selection_controller.state.revision
	var binding := {"path":ProjectSettings.globalize_path(viewer.capture_path),"committed_bytes":str(viewer.generic_reader.scan_offset)}
	if verified_source.has("sha256"): binding.sha256 = verified_source.sha256
	request_context = {"fingerprint":source_fingerprint,"source":binding.duplicate(true),"arguments":args.duplicate(true),"index":int(sample_index.value),"geometry":geometry.duplicate(true),"revision":revision,"selection":request_selection_revision}
	input_signature = JSON.stringify(args,"",true,true); request_started_usec = Time.get_ticks_usec()
	viewer.selection_controller.temporal.update_pins()
	pending_id = jobs.request_background(binding,OPERATION,args,viewer.capture_generation,request_selection_revision,revision)
	status.text = "Verifying source and computing bounded 3D windows…" if not pending_id.is_empty() else jobs.error
	refresh_context()

func cancel() -> void:
	var was_sequence := pending_operation == SEQUENCE_OPERATION and not pending_id.is_empty()
	_invalidate("Spectral work cancelled. No partial map or sequence published.")
	if was_sequence: sequence_unavailable = "Preparation cancelled; no sequence published."
	refresh_context()

func _failed(message: String) -> void:
	if pending_id.is_empty(): return
	var was_sequence := pending_operation == SEQUENCE_OPERATION
	_invalidate(message)
	if was_sequence: sequence_unavailable = "Preparation unavailable: "+message
	refresh_context()

func _invalidate(message: String) -> void:
	if not pending_id.is_empty() and jobs.background_operation == pending_operation and jobs.background_id == pending_id: jobs.cancel_background()
	pending_id = ""; revision += 1; request_context.clear(); result_data.clear(); result_source.clear(); input_signature = ""
	sequence_data.clear(); displayed_sequence_index = -1; estimate_signature = ""; sequence_estimate.clear()
	sequence_unavailable = ""
	if plane != null: plane.clear()
	if legend_panel != null: legend_panel.hide()
	if table != null: table.text = ""
	if geometry_detail != null: geometry_detail.text = ""
	if summary != null: summary.text = ""
	if warnings_detail != null: warnings_detail.text = ""
	if not message.is_empty() and status != null: status.text = message

func reset_source() -> void:
	_invalidate("Capture changed. Choose a source and map inputs.")
	verified_source.clear(); source_fingerprint = ""; geometry.clear(); descriptor.clear(); current_object = ""; current_channel = ""; object_choice.clear(); channel_choice.clear()
	context.text = "No source field selected."; support_notice.text = ""; compute_button.disabled = true; cancel_button.disabled = true
	if sequence_prepare_button != null: sequence_prepare_button.disabled = true
	if sequence_notice != null: sequence_notice.text = "Choose a source before selecting native records."

func _completed(result: Dictionary) -> void:
	if pending_id.is_empty() or str(result.get("id","")) != pending_id: return
	if pending_operation == SEQUENCE_OPERATION and not _sequence_source_matches():
		var message := _sequence_source_notice("publication"); reset_source(); status.text = message; return
	var current_arguments := _sequence_arguments() if pending_operation == SEQUENCE_OPERATION else _request_arguments()
	if request_context.is_empty() or _fingerprint() != request_context.fingerprint or revision != request_context.revision or viewer.selection_controller.state.revision != request_context.selection or JSON.stringify(current_arguments,"",true,true) != input_signature:
		_invalidate("Superseded spectral map discarded."); refresh_context(); return
	var data = result.get("data"); var binding = result.get("source")
	if pending_operation == SEQUENCE_OPERATION:
		if not _valid_sequence(data,binding): _invalidate("Invalid or oversized prepared sequence refused."); refresh_context(); return
		pending_id = ""; sequence_data = data.duplicate(true); result_source = binding.duplicate(true); verified_source = binding.duplicate(true)
		publication_msec = (Time.get_ticks_usec()-request_started_usec)/1000.
		status.text = "Verified %d-map sequence %s. Exact native times only; missing times hide the map." % [data.maps.size(),"reused from cache" if data.cache.hit else "prepared and cached"]
		_sync_replay(); refresh_context(); _presentation_changed(); return
	if not _valid_result(data,binding): _invalidate("Invalid or oversized spectral map refused."); refresh_context(); return
	if not plane.publish(data): _invalidate(plane.error if not plane.error.is_empty() else "Spectral map presentation allocation refused."); refresh_context(); return
	pending_id = ""; result_data = data.duplicate(true); result_source = binding.duplicate(true); verified_source = binding.duplicate(true)
	publication_msec = (Time.get_ticks_usec()-request_started_usec)/1000.
	_show_numerical_details(data)
	status.text = "Verified map ready: %d / %d centers measured. Pinned while playback moves." % [int(data.coverage.measured),int(data.coverage.total)]
	refresh_context(); _presentation_changed(); scroller.set_deferred("scroll_vertical",0)

func _show_numerical_details(data: Dictionary) -> void:
	var provenance: Dictionary = data.provenance
	summary.text = "Weighted mean / detrending: %s\nPower normalization: %s\nw: separable periodic Hann; N: samples per 3D window; m: real-FFT folding multiplicity. Each value is band-limited w²-weighted mean-square residual, not Hamiltonian energy.\nBand convention: %s. No unique wavelength, direction, phase or optical light is inferred." % [provenance.get("detrending","undeclared"),provenance.get("normalization","undeclared"),data.band.get("convention","[low, high)")]
	table.text = "row, column • center XYZ (data local) • power [%s] • status\n" % data.units.power
	for item in data.measurements: table.text += "%d, %d • %s • %s • %s\n" % [int(item.row),int(item.column),JSON.stringify(item.center_xyz,"",true,true),_number(item.power) if item.status == "measured" else "unavailable",item.status]

func _valid_sequence(data, binding) -> bool:
	if not data is Dictionary or JSON.stringify(data).to_utf8_buffer().size() > 1048576: return false
	if data.get("kind") != SEQUENCE_OPERATION or not _same_number(data.get("schema"),1): return false
	if not data.get("maps") is Array or not data.get("cache") is Dictionary or not data.cache.get("hit") is bool: return false
	if not Index.valid_hex(data.get("request_key"),64) or not _numeric_array_matches(data.get("indices"),request_context.arguments.indices): return false
	if data.maps.size() != data.indices.size() or data.maps.is_empty() or data.maps.size() > MAX_SELECTED_TIMES: return false
	for i in data.maps.size():
		var index := int(data.indices[i])
		if not request_context.geometries.has(index) or not _valid_result(data.maps[i],binding,index,request_context.geometries[index]): return false
	return true

func _valid_result(data, binding, expected_index := -1, expected_geometry: Dictionary = {}) -> bool:
	if not data is Dictionary or not binding is Dictionary or JSON.stringify(data).to_utf8_buffer().size() > 1048576: return false
	if data.get("kind") != OPERATION or data.get("object") != current_object or data.get("channel") != current_channel: return false
	for key in ["record","geometry","support","grid","band","units","provenance","coverage"]:
		if not data.get(key) is Dictionary: return false
	if not data.get("measurements") is Array or not data.get("warnings") is Array: return false
	var args: Dictionary = request_context.arguments
	var sequence := expected_index >= 0
	if not sequence: expected_index = int(request_context.index); expected_geometry = request_context.geometry
	if not _numeric_array_matches(data.support.get("shape"),args.support): return false
	for key in ["start","hop","count"]:
		if not _numeric_array_matches(data.grid.get(key),args.grid[key]): return false
	if data.grid.get("plane_axis") != args.grid.plane_axis or not _same_number(data.grid.get("fixed_start"),args.grid.fixed_start): return false
	if not _same_number(data.band.get("low"),args.band.low) or not _same_number(data.band.get("high"),args.band.high): return false
	for key in ["shape","origin","spacing","data_to_world"]:
		if not _numeric_array_matches(data.geometry.get(key),expected_geometry.get(key)): return false
	if data.geometry.get("centering") != expected_geometry.get("centering"): return false
	if not Index.valid_hex(binding.get("sha256"),64) or binding.get("committed_bytes") != request_context.source.committed_bytes or str(binding.get("path","")).simplify_path() != str(request_context.source.path).simplify_path(): return false
	if request_context.source.has("sha256") and binding.sha256 != request_context.source.sha256: return false
	var native := Exact.exact_float(data.record.get("native_time")); var requested := Exact.exact_float(data.record.get("requested_time"))
	var rows := _rows()
	if native.is_empty() or requested.is_empty() or expected_index >= rows.size() or native.value != rows[expected_index].time or not _same_number(data.record.get("index"),expected_index): return false
	if requested.value != (native.value if sequence else requested_time): return false
	if not _same_number(data.record.get("sequence"),rows[expected_index].get("sequence")): return false
	if not Index.valid_hex(data.get("request_key"),64): return false
	var count := int(args.grid.count[0])*int(args.grid.count[1])
	if count < 1 or count > 64 or data.measurements.size() != count: return false
	var axes := _plane_axes()
	if data.grid.get("row_axis") != "xyz"[axes[0]] or data.grid.get("column_axis") != "xyz"[axes[1]]: return false
	for i in range(count):
		var item = data.measurements[i]
		if not item is Dictionary or not _same_number(item.get("row"),i/int(args.grid.count[1])) or not _same_number(item.get("column"),i%int(args.grid.count[1])): return false
		if not item.get("status") in ["measured","outside_support","nonfinite_samples","numerical_range"]: return false
		if item.status == "measured" and (not (item.get("power") is float or item.get("power") is int) or not is_finite(item.power) or item.power < 0.): return false
		if item.status != "measured" and item.get("power") != null: return false
		for key in ["center_xyz","center_index_xyz","center_world_xyz"]:
			if not item.get(key) is Array or item[key].size() != 3: return false
			for value in item[key]:
				if not (value is int or value is float) or not is_finite(value): return false
	for key in ["position","value","frequency","power"]:
		if not data.units.get(key) is String: return false
	return true

func _fmt(value: float) -> String:
	if value == 0.: return "0"
	var exponent := int(floor(log(absf(value))/log(10.)))
	return String.num_scientific(value) if exponent < -3 or exponent > 3 else String.num(value,maxi(0,3-exponent))

func _values_text(values: Array) -> String:
	var parts: Array[String] = []
	for value in values: parts.append(_fmt(float(value)))
	return "["+", ".join(parts)+"]"

func _sequence_active() -> bool:
	return not sequence_data.is_empty() or not sequence_unavailable.is_empty() or (pending_operation == SEQUENCE_OPERATION and not pending_id.is_empty())

func _replay_match() -> int:
	if sequence_data.is_empty() or not replay_enabled.button_pressed: return -1
	if _fingerprint() != source_fingerprint or viewer.selection_controller.state.revision != request_selection_revision: return -1
	var cursor := float(viewer.requested_time)
	if not _same_number(viewer.committed_sample.get("requested_time"),cursor): return -1
	if viewer.scene_layers != null and viewer.scene_layers.is_buffering(): return -1
	for i in sequence_data.maps.size():
		var native := Exact.exact_float(sequence_data.maps[i].record.native_time)
		if not native.is_empty() and native.value == cursor: return i
	return -1

func _sync_replay() -> void:
	if not _sequence_active(): return
	var match_index := _replay_match()
	var native_index := int(sequence_data.maps[match_index].record.index) if match_index >= 0 else -1
	if displayed_sequence_index != native_index:
		displayed_sequence_index = native_index
		if match_index < 0:
			result_data.clear(); plane.clear(); table.text = ""; summary.text = ""; warnings_detail.text = ""
		else:
			var data: Dictionary = sequence_data.maps[match_index]
			if not plane.publish(data):
				sequence_unavailable = plane.error; displayed_sequence_index = -1; result_data.clear(); sequence_data.clear()
			else:
				result_data = data.duplicate(true); plane.apply_presentation(opacity.value,palette.selected); _show_numerical_details(data)
	_update_legend()

func _update_legend() -> void:
	var cursor := float(viewer.requested_time)
	if not result_data.is_empty():
		var native := Exact.exact_float(result_data.record.native_time)
		var range_text := "Range %s … %s [%s]" % [_fmt(plane.range_min),_fmt(plane.range_max),result_data.units.power] if int(result_data.coverage.measured) > 0 else "Range unavailable — no measured centers"
		var state := "Verified prepared replay" if not sequence_data.is_empty() else "Pinned spectral band power"
		legend.text = "%s • %s / %s\nNative %s; playhead %s\nf ∈ [%s, %s) %s\n%s\n%d / %d measured • %s\nSource SHA-256 %s…\nDots = measured; crosses / hatching = unavailable.\nPer-map colors are display only; not optical light or energy." % [state,current_object,current_channel,_number(native.value),_number(cursor),_fmt(result_data.band.low),_fmt(result_data.band.high),result_data.units.frequency,range_text,int(result_data.coverage.measured),int(result_data.coverage.total),"UNRESOLVED support" if result_data.support.status == "insufficient_support" else "support heuristic only",str(result_source.get("sha256","")).substr(0,12)]
		if not sequence_data.is_empty(): legend.text += "\n%d prepared • %s" % [sequence_data.maps.size(),"verified cache hit" if sequence_data.cache.hit else "computed and cached"]
	elif _sequence_active():
		var reason := "No prepared map at this exact native time."
		if not sequence_unavailable.is_empty(): reason = sequence_unavailable
		elif not pending_id.is_empty(): reason = "Selected maps are being prepared."
		elif not replay_enabled.button_pressed: reason = "Prepared replay is off."
		elif not _same_number(viewer.committed_sample.get("requested_time"),cursor) or (viewer.scene_layers != null and viewer.scene_layers.is_buffering()): reason = "Ordinary scene is preparing."
		var count: int = sequence_data.get("maps",[]).size()
		legend.text = "Spectral map unavailable • playhead %s\n%s\n%d selected maps prepared. Between native times the map is hidden; no interpolation." % [_number(cursor),reason,count]

func refresh_context() -> void:
	if compute_button == null: return
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or not jobs.background_cancel_id.is_empty(); cancel_button.disabled = pending_id.is_empty()
	_update_sequence_estimate()
	sequence_prepare_button.disabled = compute_button.disabled or sequence_estimate.is_empty() or sequence_estimate.get("memory_bytes",0) > jobs.memory_bytes
	var rows := _rows(); var index := int(sample_index.value)
	if geometry.is_empty() or index < 0 or index >= rows.size(): sync_visibility(); return
	context.text = "%s • requested %s → native %s; playhead %s." % ["Pinned result" if not result_data.is_empty() else "Pinned request" if not pending_id.is_empty() else "Input draft",_number(requested_time),_number(rows[index].time),_number(viewer.requested_time)]
	if _sequence_active(): context.text = "Selected native replay • playhead %s • %s." % [_number(viewer.requested_time),"exact prepared map" if displayed_sequence_index >= 0 else "map unavailable"]
	var axes := _plane_axes()
	row_column_label.text = "Counts / hop order: row %s, column %s. Normal %s uses its fixed first-start index. At most 64 centers." % ["XYZ"[axes[0]],"XYZ"[axes[1]],"XYZ"[plane_axis.selected]]
	var lengths: Array = []; var df: Array = []; var cycles: Array = []
	for axis in range(3):
		var length := float(support_xyz[axis].value)*float(geometry.spacing[axis]); lengths.append(length); df.append(1./length if length > 0 else 0.)
		if band_low.text.is_valid_float(): cycles.append(length*band_low.text.to_float())
	support_notice.text = "L = %s; Δf = %s cycles / source length (XYZ)." % [_values_text(lengths),_values_text(df)]
	if cycles.size() == 3: support_notice.text += "\nCycles at low edge = %s. %s" % [_values_text(cycles),"Unresolved: insufficient two-cycle support." if cycles.min() < 2. else "Two-cycle heuristic only; no resolution guarantee."]
	geometry_detail.text = "Source geometry: %s\nThe first window start and 3D support are XYZ source sample indices. Actual centers = start + (support−1)/2; even supports have half-index centers. Plane color is nearest display of center values, not a measurement between them." % JSON.stringify(geometry,"",true,true)
	if not result_data.is_empty():
		geometry_detail.text += "\nPinned source: %s\nCommitted bytes: %s\nSHA-256: %s\nSource dtype: %s; calculation dtype: %s.\nGrid: %s\nSupport: %s\nBand: %s" % [result_source.path,result_source.committed_bytes,result_source.sha256,result_data.provenance.get("source_dtype","undeclared"),result_data.provenance.get("calculation_dtype","undeclared"),JSON.stringify(result_data.grid,"",true,true),JSON.stringify(result_data.support,"",true,true),JSON.stringify(result_data.band,"",true,true)]
		warnings_detail.text = "\n".join(result_data.warnings)
	_update_legend()
	if viewer.scene_layers != null and viewer.scene_layers.states.has(current_object): reference_visible.set_pressed_no_signal(viewer.scene_layers.states[current_object].visible)
	sync_visibility()

func _set_reference_visible(value: bool) -> void:
	if viewer.scene_layers == null or not viewer.scene_layers.panel_controls.has(current_object): return
	# Use the canonical visibility control, including its one-volume guard.
	viewer.scene_layers.panel_controls[current_object].visible.button_pressed = value
	reference_visible.set_pressed_no_signal(viewer.scene_layers.states[current_object].visible)

func _presentation_changed() -> void:
	if plane == null: return
	plane.apply_presentation(opacity.value,palette.selected)
	var colors: PackedColorArray
	match palette.selected:
		1: colors = PackedColorArray([Color.BLACK,Color(.5,.5,.5),Color.WHITE])
		2: colors = PackedColorArray([Color(.12,.04,.25),Color(.85,.22,.12),Color(1.,.93,.55)])
		_: colors = PackedColorArray([Color(.12,.10,.35),Color(.06,.60,.57),Color(.95,.94,.25)])
	# Spatial ALBEDO constants are linear RGB; the UI image is sRGB. Convert
	# every ramp sample, since interpolating converted endpoints is different.
	var image := Image.create(128,1,false,Image.FORMAT_RGBA8)
	for i in range(128):
		var value := float(i)/127.
		var color := colors[0].lerp(colors[1],value*2.) if value <= .5 else colors[1].lerp(colors[2],value*2.-1.)
		image.set_pixel(i,0,color.linear_to_srgb())
	legend_gradient.texture = ImageTexture.create_from_image(image)
	sync_visibility()

func sync_visibility() -> void:
	if plane == null or legend_panel == null: return
	# Recheck at pre-draw too: the ordinary scene may commit after this node's
	# process callback. No stale map is allowed for even one mismatched frame.
	_sync_replay()
	var allowed: bool = visibility.button_pressed and not presentation_suspended and not viewer.offline_instance and not viewer.inspection_busy
	var show: bool = not result_data.is_empty() and allowed
	plane.visible = show; legend_panel.visible = allowed and (show or _sequence_active())
	legend_gradient.visible = show and int(result_data.get("coverage",{}).get("measured",0)) > 0
	if legend_panel.visible:
		# Wrapping may initially measure at a narrow width. Refit height after
		# width/content changes instead of retaining that first tall rectangle.
		legend_panel.size = Vector2(minf(350.,maxf(250.,viewer.get_viewport().get_visible_rect().size.x-36.)),0.)

func suspend_presentation() -> void:
	presentation_suspended = true; sync_visibility()

func restore_presentation() -> void:
	presentation_suspended = false; sync_visibility()

func _process(delta: float) -> void:
	_sync_replay()
	elapsed += delta
	if elapsed < .1: return
	elapsed = 0.
	if not source_fingerprint.is_empty() and _fingerprint() != source_fingerprint: reset_source(); status.text = "Source changed or closed. Reopen Spectral band map to verify the current source."; return
	if not pending_id.is_empty() and (viewer.selection_controller.state.revision != request_selection_revision or jobs.background_operation != pending_operation or jobs.background_id != pending_id):
		_invalidate("Selection or worker request changed. Map discarded."); refresh_context(); return
	var current_arguments := _sequence_arguments() if not sequence_data.is_empty() else _request_arguments()
	if (not result_data.is_empty() or not sequence_data.is_empty()) and (viewer.selection_controller.state.revision != request_selection_revision or JSON.stringify(current_arguments,"",true,true) != input_signature):
		_invalidate("Map inputs or selection changed. Compute again."); refresh_context(); return
	var cursor := float(viewer.requested_time)
	if not is_finite(last_cursor) or cursor != last_cursor: last_cursor = cursor; refresh_context()
	if viewer.scene_layers != null and viewer.scene_layers.states.has(current_object): reference_visible.set_pressed_no_signal(viewer.scene_layers.states[current_object].visible)
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or not jobs.background_cancel_id.is_empty(); cancel_button.disabled = pending_id.is_empty()
	sync_visibility()
