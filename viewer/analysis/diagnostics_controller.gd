extends Node
const UI = preload("res://analysis/ui_controls.gd")
const Overlay = preload("res://analysis/overlay_plot.gd")
var temporal
var viewer
var panel: VBoxContainer
var status: Label
var csv_path: LineEdit
var csv_time: LineEdit
var csv_units: LineEdit
var csv_columns: LineEdit
var csv_value_units: LineEdit
var csv_dtype: OptionButton
var csv_delimiter: OptionButton
var csv_blanks: CheckButton
var csv_gap: LineEdit
var csv_intervals: LineEdit
var label_input: LineEdit
var time_units: LineEdit
var time_reference: LineEdit
var time_scale: LineEdit
var time_offset: LineEdit
var offset_origin: LineEdit
var value_units: LineEdit
var value_reference: LineEdit
var value_scale: LineEdit
var value_offset: LineEdit
var join: OptionButton
var operation: OptionButton
var schedule_start: LineEdit
var schedule_step: LineEdit
var schedule_count: LineEdit
var left := {}
var right := {}
var bindings: Array = []
var overlay
var period_method: OptionButton
var detrend: OptionButton
var lag_low: LineEdit
var lag_high: LineEdit
var separation: LineEdit
var prominence: LineEdit
var uniform: CheckButton
var hold_cadence: LineEdit
var bookmarks: Array = []
var bookmark_list: OptionButton

func setup(controller) -> void:
	temporal = controller;viewer = temporal.viewer
	panel = viewer._section("Diagnostics and comparisons")
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
	status.text = "Import a diagnostic CSV, compare series, or estimate a period."
	label_input = field("Series / bookmark name","Series")
	csv_path = field("CSV file","")
	viewer._button(panel,"Choose CSV",choose_csv)
	csv_time = field("Time column","time");csv_units = field("Time units","unknown")
	csv_columns = field("Value columns (comma-separated)","value");csv_value_units = field("Value units","unknown")
	csv_dtype = viewer._option(panel,"Number type");csv_dtype.add_item("Float64");csv_dtype.add_item("Exact int64")
	csv_delimiter = viewer._option(panel,"Delimiter")
	for label in ["Comma","Semicolon","Tab","Pipe"]:csv_delimiter.add_item(label)
	csv_blanks = viewer._check(panel,"Skip blank lines",false,func(_v):pass)
	csv_gap = field("Maximum CSV gap","")
	csv_intervals = field("Missing time intervals","")
	viewer._button(panel,"Import diagnostic CSV",import_csv)
	time_units = field("Common time unit","unknown");time_reference = field("Common time reference","")
	time_scale = field("Time scale","1");time_offset = field("Time offset (subtract)","0");offset_origin = field("Reason for time offset","manual zero offset")
	value_units = field("Common value unit","unknown");value_reference = field("Compared quantity","")
	value_scale = field("Source value scale","1");value_offset = field("Value offset (add)","0")
	viewer._button(panel,"Use current series as left",func():bind_side("left"))
	viewer._button(panel,"Use current series as right",func():bind_side("right"))
	viewer._button(panel,"Clear left and right",func():left.clear();right.clear();status.text = "Comparison bindings cleared.")
	operation = viewer._option(panel,"Comparison");operation.add_item("Left minus right");operation.add_item("Left divided by right")
	join = viewer._option(panel,"Comparison times");join.add_item("Exact recorded times");join.add_item("Common schedule")
	schedule_start = field("Schedule start","0");schedule_step = field("Schedule step","0.1");schedule_count = field("Schedule samples","100")
	viewer._button(panel,"Compare left and right",compare)
	viewer._button(panel,"Add current series to shared plot",add_series)
	viewer._button(panel,"Clear shared plot",func():bindings.clear();overlay.clear())
	overlay = Overlay.new();overlay.custom_minimum_size = Vector2(220,260);panel.add_child(overlay)
	period_method = viewer._option(panel,"Period estimate method");period_method.add_item("Observed peak spacing");period_method.add_item("Autocorrelation")
	detrend = viewer._option(panel,"Detrend");detrend.add_item("Mean");detrend.add_item("Linear")
	lag_low = field("Minimum lag","0.1");lag_high = field("Maximum lag","10")
	separation = field("Minimum peak separation","0.1");prominence = field("Minimum peak prominence","0.1")
	uniform = viewer._check(panel,"Use uniform sampling assumption",false,func(_v):pass)
	hold_cadence = field("Hold-resampling step","")
	viewer._button(panel,"Estimate period in selected range",estimate_period)
	bookmark_list = viewer._option(panel,"Manual bookmarks")
	viewer._button(panel,"Save time and camera bookmark",bookmark)
	viewer._button(panel,"Go to bookmark",seek_bookmark)
	viewer._button(panel,"Use bookmark as manual offset",bookmark_offset)
	viewer._button(panel,"Delete bookmark",delete_bookmark)
	UI.hint(csv_intervals,"Missing intervals as start,end pairs separated by semicolons. Imported diagnostics retain a separate clock.")
	UI.hint(csv_gap,"Maximum connected interval in the CSV time units. Blank leaves the maximum undeclared; it does not fill missing observations.")
	UI.hint(prominence,"Minimum peak prominence in the normalized signal, not in the original channel units.")
	UI.hint(join,"Exact times leave unmatched samples missing. A common schedule explicitly evaluates holds or supported position interpolation, retaining both native brackets.")
	UI.hint(time_offset,"Aligned time = raw time × time scale − offset. Record why the offset is appropriate; no event is detected automatically.")
	UI.hint(value_offset,"Compared value = source value × scale + offset. Confirm matching physical quantities and units.")
	UI.hint(uniform,"Declare uniform sampling with relative tolerance 1e-6. Unsupported or irregular inputs refuse this assumption.")
	UI.hint(hold_cadence,"Blank uses recorded samples. A supplied cadence explicitly resamples by holding values; it does not create new observations.")
	UI.group(panel,csv_dtype,csv_intervals,"Advanced • CSV parsing and gaps")
	UI.group(panel,csv_path,UI.button(panel,"Import diagnostic CSV"),"Import CSV", "Supplied diagnostics keep their own recorded clock.",true)
	UI.group(panel,schedule_start,schedule_count,"Common schedule settings")
	UI.group(panel,time_units,overlay,"Compare series","Choose each source series and declare common time and quantity meaning.")
	UI.group(panel,uniform,hold_cadence,"Advanced • Sampling assumptions")
	UI.group(panel,period_method,UI.button(panel,"Estimate period in selected range"),"Estimate a period","Exploratory estimate within the Temporal analysis range, not automatic event detection.")
	UI.group(panel,bookmark_list,UI.button(panel,"Delete bookmark"),"Manual bookmarks")
	UI.fit(panel)
	temporal.jobs.background_completed.connect(completed)
	set_process(true)

func field(label: String, initial: String) -> LineEdit:
	var title := Label.new();title.text = label;panel.add_child(title)
	var edit := LineEdit.new();edit.text = initial;panel.add_child(edit);return edit

func choose_csv() -> void:
	var dialog := FileDialog.new();dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;dialog.access = FileDialog.ACCESS_FILESYSTEM;dialog.filters = PackedStringArray(["*.csv,*.tsv ; Diagnostic data"])
	add_child(dialog);dialog.file_selected.connect(func(path):csv_path.text = path;dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(.7)

func numbers(fields: Array) -> bool:
	for edit in fields:
		if not edit.text.is_valid_float() or not is_finite(edit.text.to_float()):status.text = "Enter finite numerical parameters.";return false
	return true

func import_csv() -> void:
	var values: Array = []
	for column in csv_columns.text.split(",",false):values.append({"column":column.strip_edges(),"units":csv_value_units.text,"dtype":"f8" if csv_dtype.selected == 0 else "i8"})
	var arguments := {"path":csv_path.text,"key":"csv-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()],"name":label_input.text,"time_column":csv_time.text,"time_units":csv_units.text,"values":values,"delimiter":[",",";","\t","|"][csv_delimiter.selected],"blank_lines":"skip" if csv_blanks.button_pressed else "reject"}
	if not csv_gap.text.is_empty():
		if not numbers([csv_gap]):return
		arguments.max_gap = csv_gap.text.to_float()
	if not csv_intervals.text.is_empty():
		arguments.missing_intervals = []
		for pair in csv_intervals.text.split(";",false):
			var ends := pair.split(",",false)
			if ends.size() != 2 or not ends[0].strip_edges().is_valid_float() or not ends[1].strip_edges().is_valid_float():status.text = "Missing intervals need start,end pairs.";return
			arguments.missing_intervals.append([ends[0].to_float(),ends[1].to_float()])
	temporal.submit("import_csv",arguments,temporal.selections.source,"Supplied CSV • "+label_input.text)

func current_binding() -> Dictionary:
	if temporal.current_result.is_empty() or temporal.series_list.selected < 0:status.text = "Choose a completed numerical result and scalar series first.";return {}
	if time_reference.text.is_empty() or value_reference.text.is_empty():status.text = "Declare the common time reference and quantity correspondence explicitly.";return {}
	if not numbers([time_scale,time_offset,value_scale,value_offset]):return {}
	var series: Dictionary = temporal.series_list.get_item_metadata(temporal.series_list.selected).duplicate(true)
	if not temporal.member_address.text.is_empty():series.member_key = temporal.member_address.text.strip_edges()
	return {"source":temporal.current_source.duplicate(true),"result":temporal.current_result.duplicate(true),"series":series,"time":{"units":time_units.text,"reference":time_reference.text,"scale":time_scale.text.to_float(),"offset":time_offset.text.to_float(),"origin":offset_origin.text},"value":{"units":value_units.text,"reference":value_reference.text,"scale":value_scale.text.to_float(),"offset":value_offset.text.to_float(),"origin":"explicit user mapping"}}

func bind_side(side: String) -> void:
	var binding := current_binding()
	if binding.is_empty():return
	if side == "left":left = binding
	else:right = binding
	status.text = "%s bound to %s • %s • %s. Matching IDs across captures have no implicit correspondence." % [side,binding.source.path.get_file(),binding.series.selection_key,binding.series.member_key]

func compare() -> void:
	if left.is_empty() or right.is_empty():status.text = "Bind both comparison inputs explicitly.";return
	var policy := {"mode":"exact"}
	if join.selected == 1:
		if not numbers([schedule_start,schedule_step]) or not schedule_count.text.is_valid_int():status.text = "Enter a finite schedule and integer count.";return
		policy = {"mode":"schedule","start":schedule_start.text.to_float(),"step":schedule_step.text.to_float(),"count":schedule_count.text.to_int()}
	temporal.submit("compare_series",{"left":left,"right":right,"operation":"difference" if operation.selected == 0 else "ratio","join":policy},left.source,"Explicit pair • "+label_input.text)

func add_series() -> void:
	if bindings.size() >= 16:status.text = "Shared plot is limited to 16 separate series.";return
	var binding := current_binding()
	if binding.is_empty():return
	bindings.append({"label":label_input.text,"binding":binding});temporal.revision += 1
	temporal._launch("result_overlay",{"bindings":bindings,"bins":128},binding.source)

func estimate_period() -> void:
	if temporal.current_result.is_empty() or temporal.series_list.selected < 0:status.text = "Choose a completed scalar series first.";return
	if not numbers([temporal.start_time,temporal.end_time,lag_low,lag_high,separation,prominence]):return
	var series: Dictionary = temporal.series_list.get_item_metadata(temporal.series_list.selected).duplicate(true)
	if not temporal.member_address.text.is_empty():series.member_key = temporal.member_address.text.strip_edges()
	var options := {"method":"peak_spacing" if period_method.selected == 0 else "autocorrelation","detrend":"mean" if detrend.selected == 0 else "linear","lag_range":[lag_low.text.to_float(),lag_high.text.to_float()],"min_separation":separation.text.to_float(),"prominence":prominence.text.to_float(),"uniform":uniform.button_pressed}
	if not hold_cadence.text.is_empty():
		if not numbers([hold_cadence]):return
		options.hold_cadence = hold_cadence.text.to_float()
	temporal.submit("estimate_period",{"result":temporal.current_result,"series":series,"window":[temporal.start_time.text.to_float(),temporal.end_time.text.to_float()],"options":options},temporal.current_source,"Exploratory period • "+label_input.text)

func completed(result: Dictionary) -> void:
	if int(result.scene_revision) != viewer.capture_generation or int(result.selection_revision) != temporal.selections.state.revision or int(result.analysis_revision) != temporal.revision:return
	if temporal.jobs.background_operation == "result_overlay":
		status.text = "Shared mapped axes; each series keeps its native clock, count and missing support." if overlay.publish(result.data) else "Oversized or invalid shared plot refused."

func references_result(reference: Dictionary) -> bool:
	for binding in [left,right]:
		if binding.get("result") == reference:return true
	for item in bindings:
		if item.binding.result == reference:return true
	return false

func bookmark() -> void:
	if bookmarks.size() >= 256 or not temporal.selections.source.has("sha256"):status.text = "Bind a source first; at most 256 manual bookmarks.";return
	var raw: float = temporal.selections._time()
	var token := {"text":JSON.stringify(raw,"",true,true),"f64_le_hex":PackedFloat64Array([raw]).to_byte_array().hex_encode()}
	var saved := {"label":label_input.text,"source":temporal.selections.source.duplicate(true),"raw_time":token,"visual":preload("res://scene/visual_state.gd").snapshot(viewer),"origin":"manual bookmark"}
	var charge := JSON.stringify(saved,"",true,true).to_utf8_buffer().size()*8+8192
	if temporal.summary_charge+charge > 24*1048576:status.text = "Saved bookmarks and analysis requests reached the memory budget.";return
	saved.charged_bytes = charge;temporal.summary_charge += charge;bookmarks.append(saved)
	bookmark_list.add_item("%s • %s" % [label_input.text,token.text])

func delete_bookmark() -> void:
	if bookmark_list.selected < 0:return
	temporal.summary_charge -= int(bookmarks[bookmark_list.selected].charged_bytes)
	bookmarks.remove_at(bookmark_list.selected);bookmark_list.remove_item(bookmark_list.selected)

func seek_bookmark() -> void:
	if bookmark_list.selected < 0:return
	var saved: Dictionary = bookmarks[bookmark_list.selected]
	if saved.source != temporal.selections.source:status.text = "Open and bind the bookmark's exact source before seeking.";return
	viewer.playing = false;viewer._seek_time(preload("res://scene/source_sampling.gd").exact_float(saved.raw_time).value)

func bookmark_offset() -> void:
	if bookmark_list.selected < 0:return
	var saved: Dictionary = bookmarks[bookmark_list.selected]
	time_offset.text = saved.raw_time.text;offset_origin.text = "manual bookmark: "+saved.label

func _process(_delta: float) -> void:
	var cursor := NAN
	for item in bindings:
		if item.binding.source == temporal.selections.source:
			cursor = temporal.selections._time()*float(item.binding.time.scale)-float(item.binding.time.offset);break
	if (is_finite(cursor) != is_finite(overlay.cursor)) or (is_finite(cursor) and cursor != overlay.cursor):overlay.cursor = cursor;overlay.queue_redraw()
