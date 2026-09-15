extends Node
const UI = preload("res://analysis/ui_controls.gd")
var temporal
var viewer
var panel: VBoxContainer
var status: Label
var mode: OptionButton
var start: LineEdit
var end: LineEdit
var bins: LineEdit
var units: LineEdit
var space: OptionButton
var restrict_selection: CheckButton
var sampling_population: LineEdit
var plot
var result_source := {}

func setup(controller) -> void:
	temporal = controller;viewer = temporal.viewer
	panel = viewer._section("Space-time analysis")
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
	status.text = "Uses the layer selected in Selections and the range/channel in Temporal analysis."
	mode = viewer._option(panel,"Analysis")
	for label in ["Grid line probes","Grid slab mean","Grid slab integral","Tracer counts","Tracer sample mean","Weighted tracer estimate"]:mode.add_item(label)
	start = field("Axis start (xyz)","0,0,0");end = field("Axis end (xyz)","1,0,0")
	bins = field("Spatial bins","64");units = field("Coordinate units","unknown")
	space = viewer._option(panel,"Coordinate space");space.add_item("World");space.add_item("Object local")
	restrict_selection = viewer._check(panel,"Use active tracer selection",false,func(_v):pass)
	sampling_population = field("Sampling population and weights","")
	viewer._button(panel,"Run space-time analysis",run_analysis)
	viewer._button(panel,"Show space-time plot",func():temporal.revision += 1;temporal._launch("result_heatmap",{"result":temporal.current_result,"width":128,"height":64},temporal.current_source))
	plot = preload("res://analysis/space_time_plot.gd").new();plot.custom_minimum_size = Vector2(220,330);panel.add_child(plot)
	UI.hint(bins,"1–16,384 full spatial bins. Numerical exports retain all requested bins; the plot is a bounded preview.")
	UI.hint(sampling_population,"For weighted tracer estimates, describe the sampled population and meaning of the weight channel chosen in Temporal analysis. Tracer density is not original-grid mass.")
	UI.group(panel,sampling_population,sampling_population,"Advanced • Tracer weighting")
	UI.fit(panel)
	temporal.jobs.background_completed.connect(completed)
	set_process(true)

func field(label: String, initial: String) -> LineEdit:
	var title := Label.new();title.text = label;panel.add_child(title)
	var edit := LineEdit.new();edit.text = initial;panel.add_child(edit);return edit

func xyz(edit: LineEdit) -> Array:
	var parts := edit.text.split(",",false);var result: Array = []
	if parts.size() != 3:return []
	for part in parts:
		if not part.strip_edges().is_valid_float() or not is_finite(part.to_float()):return []
		result.append(part.to_float())
	return result

func run_analysis() -> void:
	var selections = temporal.selections
	if selections.target.selected < 0:status.text = "Bind a capture and select its source layer first.";return
	var a := xyz(start);var b := xyz(end)
	if a.is_empty() or b.is_empty() or not bins.text.is_valid_int() or not temporal._valid_number(temporal.start_time) or not temporal._valid_number(temporal.end_time):status.text = "Enter finite coordinates/range and an integer bin count.";return
	var spatial := {"start":a,"end":b,"bins":bins.text.to_int(),"space":"viewer_world" if space.selected == 0 else "data_local","units":units.text}
	var object: String = selections.target.get_item_metadata(selections.target.selected)
	var definition: Dictionary = selections.state.find(selections.state.active)
	if mode.selected in [1,2]:
		if definition.is_empty() or definition.object != object or definition.kind != "roi" or definition.selector.shape != "slab" or definition.coordinates.space != spatial.space:status.text = "Slab reduction requires an active finite slab ROI on this object in the same coordinate space.";return
		spatial.slab = definition.selector
	var arguments := {"object":object,"mode":"grid_line" if mode.selected == 0 else "grid_slab" if mode.selected < 3 else "tracer_bins","reducer":["probe","mean","integral","count","sample_mean","weighted_estimate"][mode.selected],"range":{"axis":"native_time" if temporal.axis.selected == 0 else "record_index","start":temporal.start_time.text.to_float(),"end":temporal.end_time.text.to_float()},"spatial":spatial}
	if mode.selected != 3:
		arguments.channel = {"channel":temporal.channel.text,"coordinates":"data_local"}
		if not temporal.units.text.is_empty():arguments.channel.override = {"units":temporal.units.text}
		if temporal.component.selected > 0:arguments.channel.component = "magnitude" if temporal.component.selected == 5 else temporal.component.selected-1
	if mode.selected >= 3 and restrict_selection.button_pressed:
		if definition.is_empty():status.text = "Choose the source selection to restrict.";return
		arguments.selection = definition
	if mode.selected == 5:
		arguments.weight = {"channel":temporal.weight_channel.text,"override":{"quantity":"sampling_weight"}};arguments.sampling_population = sampling_population.text
		if not temporal.weight_units.text.is_empty():arguments.weight.override.units = temporal.weight_units.text
	if not temporal.max_gap.text.is_empty():
		if not temporal._valid_number(temporal.max_gap):status.text = "Gap threshold must be finite.";return
		arguments.max_gap = temporal.max_gap.text.to_float()
	temporal.submit("space_time",arguments,selections.source,"Space-time • "+arguments.reducer)

func completed(result: Dictionary) -> void:
	if temporal.jobs.background_operation != "result_heatmap" or int(result.scene_revision) != viewer.capture_generation or int(result.selection_revision) != temporal.selections.state.revision or int(result.analysis_revision) != temporal.revision:return
	if not plot.publish(result.data):status.text = "Invalid or oversized heatmap preview refused.";return
	result_source = result.source;status.text = "%s\nFull bin values: %d • native coordinates, gaps and coverage preserved." % [result.data.value_origin,int(result.data.full_bin_values)]

func _process(_delta: float) -> void:
	var cursor: float = temporal.selections._time() if result_source == temporal.selections.source and not result_source.is_empty() else NAN
	if (is_finite(cursor) != is_finite(plot.cursor)) or (is_finite(cursor) and cursor != plot.cursor):plot.cursor = cursor;plot.queue_redraw()
