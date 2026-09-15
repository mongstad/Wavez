extends Node
const UI = preload("res://analysis/ui_controls.gd")
const Plot = preload("res://analysis/native_plot.gd")
const MODES := ["trace","statistics","population","integral","interval_velocity","centroid","area"]
var selections
var viewer
var jobs
var revision := 0
var panel: VBoxContainer
var status: Label
var selection_set: OptionButton
var mode: OptionButton
var axis: OptionButton
var start_time: LineEdit
var end_time: LineEdit
var channel: LineEdit
var component: OptionButton
var coordinates: OptionButton
var units: LineEdit
var metrics: LineEdit
var weighting: OptionButton
var weight_channel: LineEdit
var weight_units: LineEdit
var quantity: OptionButton
var mass_units: LineEdit
var length_units: LineEdit
var scale: LineEdit
var max_gap: LineEdit
var finite_subtotal: CheckButton
var result_list: OptionButton
var series_list: OptionButton
var member_address: LineEdit
var table: RichTextLabel
var plot: Control
var summaries: Array = []
var summary_charge := 0
var request_charge := 0
var current_result := {}
var request_state := {}
var page_offset := 0
var last_cursor := NAN
var current_source := {}
var request_label := ""
var diagnostics
var space_time
var durable
var matched

func setup(controller) -> void:
	selections = controller;viewer = controller.viewer;jobs = controller.jobs
	panel = viewer._section("Temporal analysis")
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
	status.text = "Choose a selection, channel and recorded time range."
	selection_set = viewer._option(panel,"Selections to analyze")
	for label in ["Active selection","Selected list entries","Group (separate series)"]:selection_set.add_item(label)
	mode = viewer._option(panel,"Analysis")
	for label in ["Value trace","Channel statistics","Population counts","Grid integral (whole cells)","Velocity from position intervals","Centroid","Mesh area"]:mode.add_item(label)
	axis = viewer._option(panel,"Range axis")
	axis.add_item("Recorded time");axis.add_item("Sample index")
	start_time = _text("Start (inclusive)","0");end_time = _text("End (inclusive)","1")
	viewer._button(panel,"Use full layer range",full_range)
	channel = _text("Source channel","value")
	component = viewer._option(panel,"Component")
	for label in ["Scalar","x / 0","y / 1","z / 2","w / 3","Vector magnitude"]:component.add_item(label)
	coordinates = viewer._option(panel,"Position trace coordinates")
	coordinates.add_item("Object local");coordinates.add_item("World")
	units = _text("Override channel units","")
	metrics = _text("Statistics (comma-separated)","count,min,max,mean,stddev")
	weighting = viewer._option(panel,"Weighting")
	for label in ["Unweighted","Source channel","Mesh face area (world)"]:weighting.add_item(label)
	weight_channel = _text("Weight channel","");weight_units = _text("Weight units override","")
	quantity = viewer._option(panel,"Physical mass declaration")
	for label in ["No physical mass claim","Actual particle mass","Original-grid mass density"]:quantity.add_item(label)
	mass_units = _text("Declared mass unit","");length_units = _text("Length unit for mass calculation","");scale = _text("Physical value scale","1")
	max_gap = _text("Maximum gap","")
	finite_subtotal = viewer._check(panel,"Include finite subtotal (incomplete)",false,func(_v):pass)
	viewer._button(panel,"Run analysis",run_analysis)
	viewer._button(panel,"Cancel analysis",func():jobs.cancel_background();revision += 1;status.text = "Cancellation requested; completed named results remain available.")
	result_list = viewer._option(panel,"Results")
	result_list.item_selected.connect(_select_result)
	viewer._button(panel,"Remove result",forget_result)
	series_list = viewer._option(panel,"Plot series")
	series_list.item_selected.connect(func(_i):show_plot())
	member_address = _text("Member address","")
	viewer._button(panel,"Show plot",show_plot)
	plot = Plot.new();plot.custom_minimum_size = Vector2(220,190);panel.add_child(plot)
	table = RichTextLabel.new();table.custom_minimum_size.y = 150;table.selection_enabled = true;panel.add_child(table)
	viewer._button(panel,"First data page",func():page_offset = 0;request_page())
	viewer._button(panel,"Next data page",request_page)
	UI.hint(units,"Blank keeps the source declaration. An override records your interpretation; it does not alter source values.")
	UI.hint(max_gap,"Maximum time gap to connect. Blank leaves gap length undeclared; missing samples remain explicit.")
	UI.hint(finite_subtotal,"Report only the finite part of an incomplete grid integral, labeled incomplete. It is not a complete physical mass.")
	UI.hint(member_address,"Exact member address, for example id:9007199254740993. Use this to inspect members outside the first 16 listed series.")
	UI.group(panel,coordinates,finite_subtotal,"Advanced • Scientific options","Coordinates, weights, units, physical mass declarations and missing-support policies.")
	UI.group(panel,member_address,member_address,"Advanced • Member lookup")
	UI.fit(panel)
	jobs.background_completed.connect(_completed)
	jobs.background_failed.connect(func(message):status.text = message)
	jobs.background_progress.connect(func(value):status.text = "%s • %s / %s" % [str(value.get("stage","")).replace("_"," ").capitalize(),value.get("completed",0),value.get("total",0)])
	diagnostics = preload("res://analysis/diagnostics_controller.gd").new();add_child(diagnostics);diagnostics.setup(self)
	space_time = preload("res://analysis/space_time_controller.gd").new();add_child(space_time);space_time.setup(self)
	durable = preload("res://analysis/durable_controller.gd").new();add_child(durable);durable.setup(self)
	matched = preload("res://analysis/matched_controller.gd").new();add_child(matched);matched.setup(self)
	set_process(false)

func _text(label: String, initial: String) -> LineEdit:
	var title := Label.new();title.text = label;panel.add_child(title)
	var field := LineEdit.new();field.text = initial;panel.add_child(field);return field

func selected_definitions() -> Array:
	var result: Array = []
	if selection_set.selected == 0:
		var active: Dictionary = selections.state.find(selections.state.active)
		if not active.is_empty():result.append(active)
	elif selection_set.selected == 1:
		for index in selections.selections.get_selected_items():result.append(selections.state.find(selections.selections.get_item_metadata(index)))
	elif selections.group_list.selected >= 0 and selections.group_list.selected < selections.state.groups.size():
		for reference in selections.state.groups[selections.group_list.selected].members:result.append(selections.state.find(reference.key))
	return result

func full_range() -> void:
	var definitions := selected_definitions()
	if definitions.is_empty():status.text = "Choose a source selection first.";return
	var object: Dictionary = selections.objects.get(definitions[0].object,{})
	if object.is_empty() or object.get("samples",0) == 0:return
	if axis.selected == 0:
		start_time.text = str(object.first_time.text);end_time.text = str(object.last_time.text)
	else:start_time.text = "0";end_time.text = str(int(object.samples)-1)

func _valid_number(field: LineEdit) -> bool:
	return field.text.is_valid_float() and is_finite(field.text.to_float())

func run_analysis() -> void:
	var definitions := selected_definitions()
	if definitions.is_empty() or definitions.size() > 16:status.text = "Choose 1–16 source selections.";return
	if not _valid_number(start_time) or not _valid_number(end_time):status.text = "Range endpoints must be finite numbers.";return
	if axis.selected == 1 and (not start_time.text.is_valid_int() or not end_time.text.is_valid_int()):status.text = "Record range endpoints must be integers.";return
	var arguments := {"selections":definitions.duplicate(true),"mode":MODES[mode.selected],"range":{"axis":"native_time" if axis.selected == 0 else "record_index","start":start_time.text.to_float(),"end":end_time.text.to_float()}}
	if mode.selected in [0,1,3]:
		var spec := {"channel":channel.text.strip_edges(),"coordinates":"data_local" if coordinates.selected == 0 else "viewer_world"}
		if component.selected > 0:spec.component = "magnitude" if component.selected == 5 else component.selected-1
		var override := {}
		if not units.text.is_empty():override.units = units.text
		if quantity.selected > 0:
			if not _valid_number(scale) or mass_units.text.is_empty():status.text = "Physical mass needs an explicit unit and finite positive scale.";return
			override.quantity = "actual_particle_mass" if quantity.selected == 1 else "mass_density"
			override.physical = {"mass_unit":mass_units.text,"scale":scale.text.to_float()}
			if quantity.selected == 2:override.physical.length_unit = length_units.text
			arguments.physical_mass = true
			if not length_units.text.is_empty():arguments.position_units = length_units.text
		if not override.is_empty():spec.override = override
		arguments.channels = [spec]
	if mode.selected == 1:arguments.metrics = Array(metrics.text.replace(" ","").split(",",false))
	if mode.selected == 3:arguments.finite_subtotal = finite_subtotal.button_pressed
	if weighting.selected == 1 and mode.selected in [1,5]:
		arguments.weight = {"channel":weight_channel.text.strip_edges()}
		if not weight_units.text.is_empty():arguments.weight.override = {"units":weight_units.text}
	elif weighting.selected == 2 and mode.selected in [1,5]:arguments.weight = {"geometric":"face_area"}
	if not max_gap.text.is_empty():
		if not _valid_number(max_gap):status.text = "Gap threshold must be finite and positive.";return
		arguments.max_gap = max_gap.text.to_float()
	submit("analyze",arguments,selections.source,MODES[mode.selected])

func submit(operation: String, arguments: Dictionary, binding: Dictionary, label: String) -> void:
	durable.remember_path(binding.get("path",""))
	if operation == "import_csv":durable.remember_path(arguments.get("path",""))
	if summaries.size() >= 64:status.text = "64 named results reached; save or clear results before another interval.";return
	request_charge = JSON.stringify(arguments).to_utf8_buffer().size()*8+8192
	if summary_charge+request_charge > 24*1048576:status.text = "Saved analysis requests reached the viewer memory budget.";return
	request_state = arguments;request_label = label;revision += 1;plot.clear();_launch(operation,arguments,binding)

func _launch(operation: String, arguments: Dictionary, binding: Dictionary = {}, budget: Dictionary = {}) -> void:
	var source: Dictionary = binding if not binding.is_empty() else current_source if operation.begins_with("result_") else selections.source
	if not source.has("sha256"):status.text = "Use current capture in Selections to pin the source first.";return
	if viewer.scene_layers != null and viewer.scene_layers.iso_pid > 0:status.text = "Wait for the current surface extraction to finish.";return
	update_pins()
	if jobs.request_background(source,operation,arguments,viewer.capture_generation,selections.state.revision,revision,budget).is_empty():status.text = jobs.error
	else:status.text = "Analysis queued. You can continue using the timeline."

func update_pins() -> void:
	var pins := {}
	var definitions: Array = selections.state.definitions.duplicate()
	for summary in summaries:
		definitions.append_array(summary.request.get("selections",[]))
		if summary.request.has("selection"):definitions.append(summary.request.selection)
	definitions.append_array(request_state.get("selections",[]))
	if request_state.has("selection"):definitions.append(request_state.selection)
	for definition in definitions:
		for field in ["ids_asset","rows_asset","xyz_asset"]:
			if definition.selector.has(field):pins[definition.selector[field].sha256] = definition.selector[field]
	jobs.member_pins = pins.values();jobs.result_pins = []
	for result in summaries:jobs.result_pins.append(result.result)

func _completed(result: Dictionary) -> void:
	if int(result.scene_revision) != viewer.capture_generation:return
	var operation: String = jobs.background_operation
	if operation in ["analyze","import_csv","estimate_period","compare_series","space_time"]:
		var summary := {"result":result.data.result,"request":request_state.duplicate(true),"operation":operation,"label":request_label,"source":result.source,"rows":result.data.row_count,"selection_revision":result.selection_revision,"charged_bytes":request_charge}
		summary_charge += request_charge
		summaries.append(summary);result_list.add_item("%d • %s • %d rows" % [summaries.size(),summary.label,int(summary.rows)])
		jobs.result_pins.append(summary.result)
		if int(result.selection_revision) != selections.state.revision or int(result.analysis_revision) != revision:
			status.text = "Fixed range completed as a named result. Selection changed; choose it explicitly to inspect.";return
		result_list.select(summaries.size()-1);_select_result(summaries.size()-1);return
	if int(result.analysis_revision) != revision or int(result.selection_revision) != selections.state.revision:return
	if operation == "result_series":
		series_list.clear()
		for item in result.data.series:
			var spec: Dictionary = item.series
			series_list.add_item("%s • %s[%s] • %s • %s" % [spec.selection_key,spec.channel,spec.component,spec.statistic,spec.member_key])
			series_list.set_item_metadata(series_list.item_count-1,spec)
		status.text = "Showing the first 16 series. Use Advanced member lookup for another member." if result.data.more else "Choose a native source series."
		if series_list.item_count > 0:show_plot()
	elif operation == "result_plot":
		if not plot.publish(result.data):status.text = "Invalid or oversized plot preview refused.";return
		status.text = "%d native rows • %d finite • %d missing\n%s • %s\nPlot shows extrema and gaps; complete values are available below." % [int(result.data.count),int(result.data.finite),int(result.data.missing),str(result.data.units),str(result.data.y_range)]
		set_process(true)

func _select_result(index: int) -> void:
	if index < 0 or index >= summaries.size():return
	current_result = summaries[index].result;current_source = summaries[index].source;page_offset = 0;revision += 1;plot.clear();table.text = ""
	if summaries[index].get("operation") == "space_time":
		series_list.clear();_launch("result_heatmap",{"result":current_result,"width":128,"height":64});return
	_launch("result_series",{"result":current_result})

func forget_result() -> void:
	var index := result_list.selected
	if index < 0 or index >= summaries.size():return
	if diagnostics.references_result(summaries[index].result):status.text = "Clear this result's linked plot/comparison binding before forgetting it.";return
	jobs.cancel_background();revision += 1;summary_charge -= int(summaries[index].charged_bytes);summaries.remove_at(index);result_list.remove_item(index)
	current_result = {};series_list.clear();plot.clear();table.text = "";jobs.result_pins = []
	for result in summaries:jobs.result_pins.append(result.result)
	status.text = "Result removed. Unused cached files can now be cleared."

func show_plot() -> void:
	if current_result.is_empty() or series_list.selected < 0:return
	var spec: Dictionary = series_list.get_item_metadata(series_list.selected).duplicate(true)
	if not member_address.text.is_empty():spec.member_key = member_address.text.strip_edges()
	revision += 1;_launch("result_plot",{"result":current_result,"series":spec,"bins":512})

func request_page() -> void:
	if current_result.is_empty():return
	update_pins();selections.operation = "result_page"
	jobs.request(current_source,"result_page",{"result":current_result,"offset":page_offset,"limit":64},viewer.capture_generation,selections.state.revision,revision)

func receive_page(result: Dictionary) -> void:
	if result.data.result != current_result:return
	page_offset = int(result.data.next_offset);table.text = "Data rows %d–%d of %d\n" % [int(result.data.offset),page_offset,int(result.data.total)]
	for row in result.data.rows:table.text += "%s  %s  %s[%s] %s = %s %s  %s %s\n" % [row.time,row.member_key,row.channel,row.component,row.statistic,row.value,row.units,row.value_status,row.reason]

func selection_changed() -> void:
	revision += 1;plot.clear();set_process(false)

func reset() -> void:
	revision += 1;request_charge = 0;current_result = {};current_source = {};request_state = {}
	series_list.clear();plot.clear();table.text = "";set_process(false)
	status.text = "Capture changed. Completed results retain their explicit source bindings; choose one to inspect."

func _process(_delta: float) -> void:
	var cursor: float = selections._time()
	if cursor != last_cursor:
		last_cursor = cursor;plot.cursor = cursor if current_source == selections.source else NAN;plot.queue_redraw()
