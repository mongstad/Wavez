extends "res://analysis/spatial_spectrum_controller.gd"
## Shared source-clock/metadata helpers, separate request and presentation owner.
const BandPlane = preload("res://analysis/spectral_band_plane.gd")
const OPERATION := "spectral_band_map"
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

func setup(scene) -> void:
	viewer = scene; jobs = viewer.selection_controller.jobs
	window = Window.new(); window.title = "Spectral band map"; window.transient = true
	window.exclusive = false; window.borderless = true; window.hide(); window.min_size = Vector2i(560,380); window.size = Vector2i(620,740); add_child(window)
	window.close_requested.connect(close)
	window.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close())
	surface = PanelContainer.new(); window.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",7); margin.add_child(body)
	var header := HBoxContainer.new(); body.add_child(header)
	var title := Label.new(); title.text = "Spectral band map"; title.theme_type_variation = "PanelTitle"; title.mouse_filter = Control.MOUSE_FILTER_IGNORE; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close_button := Button.new(); close_button.text = "Close"; close_button.pressed.connect(close); header.add_child(close_button)
	header.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not window.is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG): DisplayServer.window_start_drag(window.get_window_id()))
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
	viewer._clear_manual_navigation()
	var focus: Control = viewer.get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	if _fingerprint() != source_fingerprint or current_object.is_empty(): _bind_current()
	window.theme = viewer.shell.style_slice.theme
	var panel_style = viewer.shell.style_slice.theme.flat_box(&"surface.1",0,0,0)
	surface.add_theme_stylebox_override("panel",panel_style); legend_panel.add_theme_stylebox_override("panel",panel_style)
	legend_panel.theme = window.theme
	var extent := Vector2i(viewer.get_viewport().get_visible_rect().size)
	window.size = Vector2i(mini(620,maxi(560,extent.x-32)),mini(740,maxi(380,extent.y-40)))
	var offset := Vector2i(maxi(12,extent.x-window.size.x-16),20)
	window.position = offset if window.is_embedded() else viewer.get_window().position+offset
	window.show(); refresh_context()
	if viewer.session_log != null: viewer.session_log.record("UI","Tools → Spectral band map opened")

func close() -> void:
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
		for axis in range(3): support_xyz[axis].value = 128; start_xyz[axis].value = -32
		var normal := plane_axis.selected
		start_xyz[normal].value = floor((float(geometry.shape[2-normal])-128.)/2.)
		var axes := _plane_axes()
		for i in range(2): hop[i].value = 32; center_counts[i].value = clampi(int(maxf(0.,float(geometry.shape[2-axes[i]])-128.)/32.)+3,1,8)
		changing = false
	if channel_choice.selected < 0: status.text = "Amplitude is absent. Select a recorded channel explicitly; energy is not a substitute for signed amplitude."
	refresh_context()

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
	_invalidate(""); request_selection_revision = viewer.selection_controller.state.revision
	var binding := {"path":ProjectSettings.globalize_path(viewer.capture_path),"committed_bytes":str(viewer.generic_reader.scan_offset)}
	if verified_source.has("sha256"): binding.sha256 = verified_source.sha256
	request_context = {"fingerprint":source_fingerprint,"source":binding.duplicate(true),"arguments":args.duplicate(true),"index":int(sample_index.value),"geometry":geometry.duplicate(true),"revision":revision,"selection":request_selection_revision}
	input_signature = JSON.stringify(args,"",true,true); request_started_usec = Time.get_ticks_usec()
	viewer.selection_controller.temporal.update_pins()
	pending_id = jobs.request_background(binding,OPERATION,args,viewer.capture_generation,request_selection_revision,revision)
	status.text = "Verifying source and computing bounded 3D windows…" if not pending_id.is_empty() else jobs.error
	refresh_context()

func cancel() -> void:
	_invalidate("Spectral band map cancelled. No partial map published."); refresh_context()

func _invalidate(message: String) -> void:
	if not pending_id.is_empty() and jobs.background_operation == OPERATION and jobs.background_id == pending_id: jobs.cancel_background()
	pending_id = ""; revision += 1; request_context.clear(); result_data.clear(); result_source.clear(); input_signature = ""
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

func _completed(result: Dictionary) -> void:
	if pending_id.is_empty() or str(result.get("id","")) != pending_id: return
	if request_context.is_empty() or _fingerprint() != request_context.fingerprint or revision != request_context.revision or viewer.selection_controller.state.revision != request_context.selection or JSON.stringify(_request_arguments(),"",true,true) != input_signature:
		_invalidate("Superseded spectral map discarded."); refresh_context(); return
	var data = result.get("data"); var binding = result.get("source")
	if not _valid_result(data,binding): _invalidate("Invalid or oversized spectral map refused."); refresh_context(); return
	if not plane.publish(data): _invalidate(plane.error if not plane.error.is_empty() else "Spectral map presentation allocation refused."); refresh_context(); return
	pending_id = ""; result_data = data.duplicate(true); result_source = binding.duplicate(true); verified_source = binding.duplicate(true)
	publication_msec = (Time.get_ticks_usec()-request_started_usec)/1000.
	var provenance: Dictionary = data.provenance
	summary.text = "Weighted mean / detrending: %s\nPower normalization: %s\nw: separable periodic Hann; N: samples per 3D window; m: real-FFT folding multiplicity. Each value is band-limited w²-weighted mean-square residual, not Hamiltonian energy.\nBand convention: %s. No unique wavelength, direction, phase or optical light is inferred." % [provenance.get("detrending","undeclared"),provenance.get("normalization","undeclared"),data.band.get("convention","[low, high)")]
	table.text = "row, column • center XYZ (data local) • power [%s] • status\n" % data.units.power
	for item in data.measurements: table.text += "%d, %d • %s • %s • %s\n" % [int(item.row),int(item.column),JSON.stringify(item.center_xyz,"",true,true),_number(item.power) if item.status == "measured" else "unavailable",item.status]
	status.text = "Verified map ready: %d / %d centers measured. Pinned while playback moves." % [int(data.coverage.measured),int(data.coverage.total)]
	refresh_context(); _presentation_changed(); scroller.set_deferred("scroll_vertical",0)

func _valid_result(data, binding) -> bool:
	if not data is Dictionary or not binding is Dictionary or JSON.stringify(data).to_utf8_buffer().size() > 1048576: return false
	if data.get("kind") != OPERATION or data.get("object") != current_object or data.get("channel") != current_channel: return false
	for key in ["record","geometry","support","grid","band","units","provenance","coverage"]:
		if not data.get(key) is Dictionary: return false
	if not data.get("measurements") is Array or not data.get("warnings") is Array: return false
	var args: Dictionary = request_context.arguments
	if not _numeric_array_matches(data.support.get("shape"),args.support): return false
	for key in ["start","hop","count"]:
		if not _numeric_array_matches(data.grid.get(key),args.grid[key]): return false
	if data.grid.get("plane_axis") != args.grid.plane_axis or not _same_number(data.grid.get("fixed_start"),args.grid.fixed_start): return false
	if not _same_number(data.band.get("low"),args.band.low) or not _same_number(data.band.get("high"),args.band.high): return false
	for key in ["shape","origin","spacing","data_to_world"]:
		if not _numeric_array_matches(data.geometry.get(key),request_context.geometry.get(key)): return false
	if data.geometry.get("centering") != request_context.geometry.get("centering"): return false
	if not Index.valid_hex(binding.get("sha256"),64) or binding.get("committed_bytes") != request_context.source.committed_bytes or str(binding.get("path","")).simplify_path() != str(request_context.source.path).simplify_path(): return false
	if request_context.source.has("sha256") and binding.sha256 != request_context.source.sha256: return false
	var native := Exact.exact_float(data.record.get("native_time")); var requested := Exact.exact_float(data.record.get("requested_time"))
	var rows := _rows()
	if native.is_empty() or requested.is_empty() or requested.value != requested_time or request_context.index >= rows.size() or native.value != rows[request_context.index].time or not _same_number(data.record.get("index"),request_context.index): return false
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

func refresh_context() -> void:
	if compute_button == null: return
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or not jobs.background_cancel_id.is_empty(); cancel_button.disabled = pending_id.is_empty()
	var rows := _rows(); var index := int(sample_index.value)
	if geometry.is_empty() or index < 0 or index >= rows.size(): sync_visibility(); return
	context.text = "%s • requested %s → native %s; playhead %s." % ["Pinned result" if not result_data.is_empty() else "Pinned request" if not pending_id.is_empty() else "Input draft",_number(requested_time),_number(rows[index].time),_number(viewer.requested_time)]
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
		var range_text := "Range %s … %s [%s]" % [_fmt(plane.range_min),_fmt(plane.range_max),result_data.units.power] if int(result_data.coverage.measured) > 0 else "Range unavailable — no measured centers"
		legend.text = "Pinned spectral band power • %s / %s\nNative %s; current playhead %s\nf ∈ [%s, %s) %s\n%s\n%d / %d measured • %s\nDots = measured; crosses / hatching = unavailable.\nNearest tiles are display only; not optical light or energy." % [current_object,current_channel,_number(rows[index].time),_number(viewer.requested_time),_fmt(result_data.band.low),_fmt(result_data.band.high),result_data.units.frequency,range_text,int(result_data.coverage.measured),int(result_data.coverage.total),"UNRESOLVED support" if result_data.support.status == "insufficient_support" else "support heuristic only"]
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
	var show: bool = not result_data.is_empty() and visibility.button_pressed and not presentation_suspended and not viewer.offline_instance and not viewer.inspection_busy
	plane.visible = show; legend_panel.visible = show
	legend_gradient.visible = show and int(result_data.get("coverage",{}).get("measured",0)) > 0
	if show:
		# Wrapping may initially measure at a narrow width. Refit height after
		# width/content changes instead of retaining that first tall rectangle.
		legend_panel.size = Vector2(minf(350.,maxf(250.,viewer.get_viewport().get_visible_rect().size.x-36.)),0.)

func suspend_presentation() -> void:
	presentation_suspended = true; sync_visibility()

func restore_presentation() -> void:
	presentation_suspended = false; sync_visibility()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .1: return
	elapsed = 0.
	if not source_fingerprint.is_empty() and _fingerprint() != source_fingerprint: reset_source(); status.text = "Source changed or closed. Reopen Spectral band map to verify the current source."; return
	if not pending_id.is_empty() and (viewer.selection_controller.state.revision != request_selection_revision or jobs.background_operation != OPERATION or jobs.background_id != pending_id):
		_invalidate("Selection or worker request changed. Map discarded."); refresh_context(); return
	if not result_data.is_empty() and (viewer.selection_controller.state.revision != request_selection_revision or JSON.stringify(_request_arguments(),"",true,true) != input_signature):
		_invalidate("Map inputs or selection changed. Compute again."); refresh_context(); return
	var cursor := float(viewer.requested_time)
	if not is_finite(last_cursor) or cursor != last_cursor: last_cursor = cursor; refresh_context()
	if viewer.scene_layers != null and viewer.scene_layers.states.has(current_object): reference_visible.set_pressed_no_signal(viewer.scene_layers.states[current_object].visible)
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or not jobs.background_cancel_id.is_empty(); cancel_button.disabled = pending_id.is_empty()
	sync_visibility()
