extends Node
## One explicitly requested, pinned source analysis using the existing owned worker.
const Exact = preload("res://scene/source_sampling.gd")
const Index = preload("res://data/capture_index.gd")
const Plot = preload("res://analysis/spatial_spectrum_plot.gd")
const Region = preload("res://analysis/spatial_spectrum_region.gd")
var viewer
var jobs
var window: Window
var surface: PanelContainer
var scroller: ScrollContainer
var object_choice: OptionButton
var channel_choice: OptionButton
var sample_index: SpinBox
var start_xyz: Array[SpinBox] = []
var size_xyz: Array[SpinBox] = []
var minimum_frequency: LineEdit
var compute_button: Button
var cancel_button: Button
var status: Label
var context: Label
var support_notice: Label
var detail: Label
var summary: Label
var geometry_detail: Label
var warnings_detail: Label
var plot
var table: RichTextLabel
var region_overlay
var pending_id := ""
var result_data := {}
var result_source := {}
var revision := 0
var requested_time := 0.0
var publication_msec := 0.0
var request_started_usec := 0
var verified_source := {}
var source_fingerprint := ""
var request_context := {}
var geometry := {}
var descriptor := {}
var current_object := ""
var current_channel := ""
var request_selection_revision := -1
var previous_focus: WeakRef
var changing := false
var elapsed := 0.0
var last_cursor := NAN

func setup(scene) -> void:
	viewer = scene; jobs = viewer.selection_controller.jobs
	window = Window.new(); window.title = "Spatial spectrum"; window.transient = true
	window.exclusive = false; window.borderless = true; window.hide()
	window.min_size = Vector2i(520,360); window.size = Vector2i(580,720)
	add_child(window)
	window.close_requested.connect(close)
	window.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close())
	surface = PanelContainer.new(); window.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",8); margin.add_child(body)
	var header := HBoxContainer.new(); body.add_child(header)
	var heading := Label.new(); heading.text = "Spatial spectrum"; heading.theme_type_variation = "PanelTitle"; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	var close_button := Button.new(); close_button.text = "Close"; close_button.pressed.connect(close); header.add_child(close_button)
	header.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not window.is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG): DisplayServer.window_start_drag(window.get_window_id()))
	scroller = ScrollContainer.new(); scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroller.follow_focus = true; body.add_child(scroller)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",5); scroller.add_child(content)
	_label(content,"Derived spatial spectrum, not optical emission or physical energy.")
	var sources := HBoxContainer.new(); content.add_child(sources)
	object_choice = _choice(sources,"Field"); channel_choice = _choice(sources,"Channel")
	object_choice.item_selected.connect(func(index: int): select_object(str(object_choice.get_item_metadata(index))))
	channel_choice.item_selected.connect(func(index: int): select_channel(str(channel_choice.get_item_metadata(index))))
	var sample_row := HBoxContainer.new(); content.add_child(sample_row)
	_label(sample_row,"Native index")
	sample_index = _spin(sample_row,0,1000000,0); sample_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sample_index.value_changed.connect(func(_value):
		if changing: return
		_invalidate("Native sample changed. Compute to verify.")
		var rows := _rows()
		if int(sample_index.value) >= 0 and int(sample_index.value) < rows.size(): requested_time = rows[int(sample_index.value)].time
		_load_sample(false))
	var pin := Button.new(); pin.text = "Use playhead"; pin.pressed.connect(pin_playhead); sample_row.add_child(pin)
	context = _label(content,"")
	start_xyz = _xyz_row(content,"Start index",0)
	size_xyz = _xyz_row(content,"Samples",128)
	for control in start_xyz+size_xyz:
		control.value_changed.connect(func(_value):
			if not changing: _invalidate("Region changed. Compute to verify."); refresh_context())
	var frequency_row := HBoxContainer.new(); content.add_child(frequency_row)
	_label(frequency_row,"Minimum f")
	minimum_frequency = LineEdit.new(); minimum_frequency.placeholder_text = "Optional cycles / source length"; minimum_frequency.size_flags_horizontal = Control.SIZE_EXPAND_FILL; frequency_row.add_child(minimum_frequency)
	minimum_frequency.text_changed.connect(func(_text):
		if not changing: _invalidate("Support criterion changed. Compute to verify."); refresh_context())
	support_notice = _label(content,"")
	plot = Plot.new(); plot.custom_minimum_size = Vector2(290,170); plot.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_child(plot)
	plot.selection_changed.connect(_show_bin)
	var details_toggle := CheckButton.new(); details_toggle.text = "Details and numerical data"; content.add_child(details_toggle)
	var details := VBoxContainer.new(); content.add_child(details); details.hide()
	details_toggle.toggled.connect(func(show_details): details.visible = show_details)
	detail = _label(details,"Click a plotted bin, or focus the plot and use Left / Right.")
	geometry_detail = _label(details,"")
	summary = _label(details,"Periodic Hann in each axis; weighted mean removed. Bin power sums to w²-weighted mean-square residual, not physical energy. Radial reduction loses direction.")
	warnings_detail = _label(details,"")
	var numerical_toggle := CheckButton.new(); numerical_toggle.text = "Show all numerical bins"; details.add_child(numerical_toggle)
	table = RichTextLabel.new(); table.custom_minimum_size.y = 160; table.selection_enabled = true; table.hide(); details.add_child(table)
	numerical_toggle.toggled.connect(func(show_table): table.visible = show_table)
	status = _label(body,"Choose a source field and a complete region.")
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_END; body.add_child(actions)
	compute_button = Button.new(); compute_button.text = "Compute"; compute_button.pressed.connect(compute); actions.add_child(compute_button)
	cancel_button = Button.new(); cancel_button.text = "Cancel"; cancel_button.pressed.connect(cancel); cancel_button.disabled = true; actions.add_child(cancel_button)
	var canvas := CanvasLayer.new(); canvas.layer = 3; add_child(canvas)
	region_overlay = Region.new(); region_overlay.viewer = viewer; canvas.add_child(region_overlay); region_overlay.hide()
	jobs.spatial_spectrum_completed.connect(_completed)
	jobs.spatial_spectrum_failed.connect(_failed)
	jobs.spatial_spectrum_progress.connect(_progress)
	set_process(not viewer.offline_instance)

func _label(parent: Node, text: String) -> Label:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(label); return label

func _choice(parent: Node, title: String) -> OptionButton:
	var column := HBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(column)
	var label := Label.new(); label.text = title; column.add_child(label)
	var choice := OptionButton.new(); choice.fit_to_longest_item = false; choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_child(choice); return choice

func _spin(parent: Node, low: int, high: int, initial: int) -> SpinBox:
	var spin := SpinBox.new(); spin.min_value = low; spin.max_value = high; spin.step = 1; spin.value = initial; spin.rounded = true; spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(spin); return spin

func _xyz_row(parent: Node, title: String, initial: int) -> Array[SpinBox]:
	var row := HBoxContainer.new(); parent.add_child(row)
	var label := Label.new(); label.text = title; label.custom_minimum_size.x = 75; row.add_child(label)
	var controls: Array[SpinBox] = []
	for axis in ["x","y","z"]:
		var name_label := Label.new(); name_label.text = axis; row.add_child(name_label)
		controls.append(_spin(row,0,10000000,initial))
	return controls

func open() -> void:
	viewer._clear_manual_navigation()
	var focus: Control = viewer.get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	if _fingerprint() != source_fingerprint or current_object.is_empty(): _bind_current()
	window.theme = viewer.shell.style_slice.theme
	surface.add_theme_stylebox_override("panel",viewer.shell.style_slice.theme.flat_box(&"surface.1",0,0,0))
	var extent: Vector2i = Vector2i(viewer.get_viewport().get_visible_rect().size)
	window.size = Vector2i(mini(580,maxi(520,extent.x-32)),mini(720,maxi(360,extent.y-40)))
	var offset := Vector2i(maxi(12,extent.x-window.size.x-16),20)
	window.position = offset if window.is_embedded() else viewer.get_window().position+offset
	window.show()
	refresh_context()
	if viewer.session_log != null: viewer.session_log.record("UI","Tools → Spatial spectrum opened")

func close() -> void:
	if not pending_id.is_empty(): cancel()
	window.hide(); region_overlay.hide()
	if previous_focus != null:
		var focus = previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()

func _fingerprint() -> String:
	if viewer.generic_reader == null or viewer.generic_reader.file == null: return ""
	return JSON.stringify([viewer.capture_generation,viewer.capture_path,viewer.generic_reader.generation,viewer.generic_reader.scan_offset,viewer.generic_reader.source_stamp])

func _bind_current() -> void:
	reset_source()
	source_fingerprint = _fingerprint()
	if source_fingerprint.is_empty(): status.text = "Open a capture with a scalar field first."; return
	for oid in viewer.generic_reader.objects:
		if viewer.generic_reader.objects[oid].kind == "volume":
			object_choice.add_item(str(oid)); object_choice.set_item_metadata(object_choice.item_count-1,str(oid))
	if object_choice.item_count == 0: status.text = "This capture has no scalar grid field."; return
	var selected := str(object_choice.get_item_metadata(0))
	if viewer.scene_layers != null:
		var field: String = viewer.scene_layers.selected_objects.get("volume",selected)
		for i in object_choice.item_count:
			if object_choice.get_item_metadata(i) == field: selected = field
	select_object(selected)

func select_object(oid: String) -> void:
	if viewer.generic_reader == null or not viewer.generic_reader.objects.has(oid) or viewer.generic_reader.objects[oid].kind != "volume": return
	_invalidate("Source field changed. Compute to verify.")
	current_object = oid; current_channel = ""
	for i in object_choice.item_count:
		if object_choice.get_item_metadata(i) == oid: object_choice.select(i)
	pin_playhead(true)

func select_channel(channel: String) -> void:
	if changing: return
	_invalidate("Source channel changed. Compute to verify.")
	current_channel = channel
	for i in channel_choice.item_count:
		if channel_choice.get_item_metadata(i) == channel: channel_choice.select(i)
	refresh_context()

func _rows() -> Array:
	if viewer.generic_reader == null: return []
	return viewer.generic_reader.samples.get(current_object,[])

func pin_playhead(default_region := false) -> void:
	if viewer.generic_reader == null or current_object.is_empty(): return
	_invalidate("Playhead sample pinned. Compute to verify.")
	requested_time = float(viewer.requested_time)
	var point: Dictionary = viewer.generic_reader.bracket(current_object,requested_time)
	changing = true; sample_index.value = int(point.get("a",0)); changing = false
	if point.is_empty():
		geometry.clear(); descriptor.clear(); status.text = "No native field sample exists at or before this playhead."; refresh_context(); return
	_load_sample(default_region)

func _load_sample(default_region: bool) -> void:
	var rows := _rows(); var index := int(sample_index.value)
	geometry.clear(); descriptor.clear()
	if index < 0 or index >= rows.size(): status.text = "Native sample index is outside this field's records."; refresh_context(); return
	# Metadata only for the editable draft. Numerical values always come from
	# the worker's verified SourceSnapshot, never this interactive reader.
	descriptor = viewer.generic_reader.describe(current_object,index).duplicate(true)
	if descriptor.is_empty(): status.text = "Source sample metadata is unavailable: "+str(viewer.generic_reader.error); refresh_context(); return
	geometry = descriptor.get("geometry",{}).duplicate(true)
	geometry["data_to_world"] = viewer.generic_reader.objects[current_object].get("data_to_world",[]).duplicate()
	changing = true
	channel_choice.clear()
	for entry in descriptor.get("arrays",[]):
		channel_choice.add_item(str(entry.name)); channel_choice.set_item_metadata(channel_choice.item_count-1,str(entry.name))
	var desired := current_channel
	if desired.is_empty():
		desired = str(channel_choice.get_item_metadata(0)) if channel_choice.item_count > 0 else ""
		for i in channel_choice.item_count:
			if channel_choice.get_item_metadata(i) == "amplitude": desired = "amplitude"
	channel_choice.select(-1)
	for i in channel_choice.item_count:
		if channel_choice.get_item_metadata(i) == desired: channel_choice.select(i)
	current_channel = desired
	if default_region and geometry.get("shape") is Array and geometry.shape.size() == 3:
		for axis in range(3):
			var count := int(geometry.shape[2-axis])
			var length := mini(128,count)
			size_xyz[axis].value = length; start_xyz[axis].value = maxi(0,(count-length)/2)
	changing = false
	refresh_context()

func set_roi_xyz(start: Array, shape: Array) -> void:
	if start.size() != 3 or shape.size() != 3: return
	changing = true
	for axis in range(3): start_xyz[axis].value = start[axis]; size_xyz[axis].value = shape[axis]
	changing = false
	_invalidate("Region changed. Compute to verify."); refresh_context()

func _roi() -> Dictionary:
	if not geometry.get("shape") is Array or geometry.shape.size() != 3: return {}
	var start: Array = []; var end: Array = []; var cells := 1
	for axis in [2,1,0]:
		var first := int(start_xyz[axis].value); var count := int(size_xyz[axis].value)
		if first < 0 or count < 4 or count > 256 or first+count > int(geometry.shape[2-axis]): return {}
		start.append(first); end.append(first+count); cells *= count
	if cells > 192*192*192: return {}
	return {"start":start,"end":end}

func _request_arguments() -> Dictionary:
	var roi := _roi()
	if roi.is_empty() or current_channel.is_empty() or channel_choice.selected < 0: return {}
	var args := {"object":current_object,"channel":current_channel,"time":requested_time,"roi":roi,"bins":256}
	if not minimum_frequency.text.strip_edges().is_empty():
		if not minimum_frequency.text.is_valid_float(): return {}
		var frequency := minimum_frequency.text.to_float()
		if not is_finite(frequency) or frequency <= 0: return {}
		args.minimum_frequency = frequency
	return args

func compute() -> void:
	if _fingerprint() != source_fingerprint:
		_bind_current(); status.text = "Source changed. Review the current field, sample and region before computing."; return
	if jobs.busy() or not jobs.foreground_cancel_id.is_empty(): status.text = "The analysis worker is busy. Wait or cancel its current job in Jobs."; return
	if viewer.scene_layers != null and viewer.scene_layers.iso_pid > 0: status.text = "Wait for surface extraction to finish before source analysis."; return
	var args := _request_arguments()
	if args.is_empty(): status.text = "Choose a recorded channel, a complete region (4–256 per axis; at most 192³ samples), and a positive frequency or leave it blank."; return
	var point: Dictionary = viewer.generic_reader.bracket(current_object,requested_time)
	if point.is_empty() or int(point.a) != int(sample_index.value): status.text = "The pinned native sample does not match the requested time. Choose Use playhead or a sample index again."; return
	_invalidate("")
	request_selection_revision = viewer.selection_controller.state.revision
	var binding := {"path":ProjectSettings.globalize_path(viewer.capture_path),"committed_bytes":str(viewer.generic_reader.scan_offset)}
	if verified_source.has("sha256"): binding.sha256 = verified_source.sha256
	request_context = {"fingerprint":source_fingerprint,"source":binding.duplicate(true),"arguments":args.duplicate(true),"index":int(sample_index.value),"geometry":geometry.duplicate(true),"revision":revision,"selection":request_selection_revision}
	request_started_usec = Time.get_ticks_usec()
	viewer.selection_controller.temporal.update_pins()
	pending_id = jobs.request_background(binding,"spatial_spectrum",args,viewer.capture_generation,request_selection_revision,revision)
	status.text = "Verifying source prefix and native sample… The viewport remains interactive." if not pending_id.is_empty() else jobs.error
	refresh_context()

func cancel() -> void:
	_invalidate("Spatial spectrum cancelled. No result published.")
	refresh_context()

func _invalidate(message: String) -> void:
	if not pending_id.is_empty() and jobs.background_operation == "spatial_spectrum" and jobs.background_id == pending_id: jobs.cancel_background()
	pending_id = ""; revision += 1; request_context.clear(); result_data.clear(); result_source.clear()
	plot.clear(); table.text = ""; region_overlay.clear()
	detail.text = "Click a plotted bin, or focus the plot and use Left / Right."
	geometry_detail.text = ""
	summary.text = "Periodic Hann in each axis; weighted mean removed. Bin power sums to w²-weighted mean-square residual, not physical energy. Radial reduction loses direction."
	if not message.is_empty(): status.text = message

func reset_source() -> void:
	_invalidate("Capture changed. Choose a source field and a complete region.")
	verified_source.clear(); source_fingerprint = ""; geometry.clear(); descriptor.clear()
	current_object = ""; current_channel = ""; object_choice.clear(); channel_choice.clear()
	context.text = "No source field selected."; support_notice.text = ""; region_overlay.hide()
	compute_button.disabled = true; cancel_button.disabled = true

func _progress(value: Dictionary) -> void:
	if pending_id.is_empty() or str(value.get("id","")) != pending_id: return
	status.text = "%s • %s / %s" % [str(value.get("stage","working")).replace("_"," ").capitalize(),value.get("completed",0),value.get("total",0)]

func _failed(message: String) -> void:
	if pending_id.is_empty(): return
	pending_id = ""; request_context.clear(); status.text = message; refresh_context()

func _completed(result: Dictionary) -> void:
	if pending_id.is_empty() or str(result.get("id","")) != pending_id: return
	if request_context.is_empty() or _fingerprint() != request_context.fingerprint or revision != request_context.revision or viewer.selection_controller.state.revision != request_context.selection:
		_invalidate("Superseded spatial spectrum discarded."); refresh_context(); return
	var data = result.get("data")
	var binding = result.get("source")
	var valid := data is Dictionary and binding is Dictionary
	if valid:
		valid = data.get("kind") == "spatial_spectrum" and data.get("object") == current_object and data.get("channel") == current_channel and data.get("roi") is Dictionary and data.get("record") is Dictionary
	if valid:
		# JSON decodes every number as float. Array equality also compares the
		# Variant type, so compare exact numeric values against integer inputs.
		valid = _numeric_array_matches(data.roi.get("start"),request_context.arguments.roi.start) and _numeric_array_matches(data.roi.get("end"),request_context.arguments.roi.end) and _same_number(data.record.get("index"),request_context.index)
	if valid:
		valid = Index.valid_hex(binding.get("sha256"),64) and binding.get("committed_bytes") == request_context.source.committed_bytes and str(binding.get("path","")).simplify_path() == str(request_context.source.path).simplify_path()
		if request_context.source.has("sha256"): valid = valid and binding.sha256 == request_context.source.sha256
	if valid:
		var native := Exact.exact_float(data.record.get("native_time"))
		var requested := Exact.exact_float(data.record.get("requested_time"))
		var rows := _rows()
		valid = not native.is_empty() and not requested.is_empty() and requested.value == requested_time and request_context.index < rows.size() and native.get("value") == rows[request_context.index].time and data.get("geometry") is Dictionary and data.get("df_xyz") is Array and data.df_xyz.size() == 3 and data.get("warnings") is Array and data.get("support") is Dictionary
		if valid:
			for key in ["shape","origin","spacing","data_to_world"]:
				if not _numeric_array_matches(data.geometry.get(key),request_context.geometry.get(key)): valid = false
			valid = valid and data.geometry.get("centering") == request_context.geometry.get("centering")
	if not valid or not plot.publish(data):
		_invalidate("Invalid or oversized spectrum result refused."); refresh_context(); return
	pending_id = ""; result_data = data.duplicate(true); result_source = binding.duplicate(true); verified_source = binding.duplicate(true)
	geometry = data.geometry.duplicate(true)
	publication_msec = (Time.get_ticks_usec()-request_started_usec)/1000.0
	summary.text = "Periodic Hann; mean removed = %s. Total w²-weighted mean-square residual = %s [%s]. Parseval relative error %s.\nRadial shell sums lose direction; power is not physical energy. No unique wavelength is inferred." % [_number(data.mean),_number(data.total_power),data.units.power,_number(data.parseval_relative_error)]
	var provenance: Dictionary = data.get("provenance",{})
	summary.text += "\nWeighted mean and detrending: %s\nPower normalization: %s\nw: separable Hann; N: ROI sample count; m: real-FFT folding multiplicity." % [str(provenance.get("detrending","undeclared")),str(provenance.get("normalization","undeclared"))]
	table.text = "Frequency [%s]    Angular k [rad / %s]    Bin power [%s]\n" % [data.units.frequency,data.units.position,data.units.power]
	for i in data.radial.frequency.size(): table.text += "%s    %s    %s\n" % [_number(data.radial.frequency[i]),_number(TAU*float(data.radial.frequency[i])),_number(data.radial.power[i])]
	status.text = "Verified result ready. Source SHA-256: "+str(binding.sha256).substr(0,16)+"…"
	_show_bin(plot.selected_index); refresh_context()
	scroller.set_deferred("scroll_vertical",0)

func _same_number(left, right) -> bool:
	return (left is int or left is float) and (right is int or right is float) and is_finite(left) and is_finite(right) and float(left) == float(right)

func _numeric_array_matches(left, right) -> bool:
	if not left is Array or not right is Array or left.size() != right.size(): return false
	for i in left.size():
		if not _same_number(left[i],right[i]): return false
	return true

func _show_bin(index: int) -> void:
	if result_data.is_empty() or index < 0 or index >= result_data.radial.frequency.size(): return
	var frequency := float(result_data.radial.frequency[index])
	detail.text = "Bin %d: f = %s [%s]; k = %s [rad / %s]; power = %s [%s]." % [index,_number(frequency),result_data.units.frequency,_number(TAU*frequency),result_data.units.position,_number(result_data.radial.power[index]),result_data.units.power]

func _number(value: float) -> String:
	return JSON.stringify(value,"",true,true)

func _compact(values: Array) -> String:
	var text: Array[String] = []
	for value in values: text.append(plot._tick(float(value)))
	return "["+", ".join(text)+"]"

func refresh_context() -> void:
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or not jobs.background_cancel_id.is_empty()
	cancel_button.disabled = pending_id.is_empty()
	var rows := _rows(); var index := int(sample_index.value)
	if geometry.is_empty() or index < 0 or index >= rows.size(): region_overlay.hide(); return
	var native_time := float(rows[index].time)
	var cursor := float(viewer.requested_time)
	var phase := "Pinned result" if not result_data.is_empty() else "Pinned request" if not pending_id.is_empty() else "Input draft — verification pending"
	context.text = "%s • requested %s → native %s; playhead %s." % [phase,_number(requested_time),_number(native_time),_number(cursor)]
	geometry_detail.text = "%s / %s • native index %d\nSource geometry (shape in z,y,x; origin and spacing in x,y,z): %s\nRegion start and samples are integer source indices in x, y, z. Displayed window lengths and Δf are rounded; this metadata and the numerical bins retain full precision." % [current_object,current_channel,index,JSON.stringify(geometry,"",true,true)]
	if not result_data.is_empty():
		var provenance: Dictionary = result_data.get("provenance",{})
		geometry_detail.text += "\nPinned source path: %s\nCommitted bytes: %s\nSHA-256: %s\nSource dtype: %s; calculation dtype: %s." % [str(result_source.path),str(result_source.committed_bytes),str(result_source.sha256),str(provenance.get("source_dtype","undeclared")),str(provenance.get("calculation_dtype","undeclared"))]
	var roi := _roi()
	if roi.is_empty(): support_notice.text = "Region must be complete: 4–256 samples per axis and no more than 192³ total. No wrapping or filling."; region_overlay.hide(); return
	var lengths: Array = []; var df: Array = []; var cycles: Array = []
	for axis in range(3):
		var length := float(size_xyz[axis].value)*float(geometry.spacing[axis])
		lengths.append(length); df.append(1./length)
		if minimum_frequency.text.is_valid_float(): cycles.append(length*minimum_frequency.text.to_float())
	support_notice.text = "L = %s; Δf = %s cycles / source length." % [_compact(lengths),_compact(df)]
	if cycles.size() == 3:
		support_notice.text += "\nCycles = %s. %s" % [_compact(cycles),"Insufficient support (<2 on an axis)." if cycles.min() < 2 else "Two-cycle heuristic only; no resolution guarantee."]
	else: support_notice.text += "\nSet minimum f to check support; no resolved wavelength claim."
	warnings_detail.text = "L = N·spacing and nominal Δf = 1/L, both in x, y, z order. Finite support and Hann broadening limit resolution; a short window can report leakage from unresolved modes.\nRadial shell sums discard direction and phase."
	if size_xyz.any(func(spin): return spin.value < 128): warnings_detail.text += "\nThis region is smaller than the 128³ exploratory reference; its displayed support determines what is resolvable."
	if not result_data.is_empty():
		for warning in result_data.warnings: warnings_detail.text += "\n"+str(warning)
	_update_region(roi,native_time)

func _update_region(roi: Dictionary, native_time: float) -> void:
	region_overlay.visible = window.visible and not viewer.offline_instance and not viewer.inspection_busy
	var transform_data = geometry.get("data_to_world",[])
	if not transform_data is Array or transform_data.size() != 12: region_overlay.clear(); return
	# First phase supports translation, not a change of spatial metric.
	for i in [0,1,2,4,5,6,8,9,10]:
		if float(transform_data[i]) != (1. if i in [0,5,10] else 0.): region_overlay.clear(); return
	var low := Vector3.ZERO; var high := Vector3.ZERO
	for axis in range(3):
		var offset := float(geometry.origin[axis])+float(transform_data[[3,7,11][axis]])
		low[axis] = offset+float(roi.start[2-axis])*float(geometry.spacing[axis])
		high[axis] = offset+float(roi.end[2-axis]-1)*float(geometry.spacing[axis])
	region_overlay.publish(low,high,("Pinned" if not result_data.is_empty() else "Draft")+" sample-center region • t="+String.num_scientific(native_time),not result_data.is_empty())

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .1: return
	elapsed = 0
	if not source_fingerprint.is_empty() and _fingerprint() != source_fingerprint:
		reset_source(); status.text = "Source changed or closed. Reopen Spatial spectrum to select and verify the current source."; return
	if not pending_id.is_empty() and (viewer.selection_controller.state.revision != request_selection_revision or jobs.background_operation != "spatial_spectrum" or (not jobs.background_pending and jobs.background_id != pending_id)):
		_invalidate("Selection or worker request changed. Spectrum discarded."); refresh_context(); return
	if not result_data.is_empty() and viewer.selection_controller.state.revision != request_selection_revision:
		_invalidate("Selection changed. Compute again to verify this region."); refresh_context(); return
	if not pending_id.is_empty() and jobs.background_id != pending_id:
		_invalidate("Superseded spatial spectrum discarded."); refresh_context(); return
	if window.visible:
		# Labels follow the global cursor; the numerical request/result stays pinned.
		var cursor := float(viewer.requested_time)
		if not is_finite(last_cursor) or cursor != last_cursor:
			last_cursor = cursor; refresh_context()
	compute_button.disabled = current_object.is_empty() or geometry.is_empty() or not pending_id.is_empty() or not jobs.background_cancel_id.is_empty()
	cancel_button.disabled = pending_id.is_empty()
