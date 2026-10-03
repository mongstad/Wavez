extends Node
## Hosts existing controls once. Navigation never creates scientific requests.
const Layout = preload("res://ui/shell/tool_layout.gd")
const UI = preload("res://analysis/ui_controls.gd")
const SECTIONS := {"Data cache":"Performance", "Selections":"Selection", "Temporal analysis":"Temporal", "Space-time analysis":"Space time", "Diagnostics and comparisons":"Diagnostics", "Matched runs":"Matched runs", "Analysis export and state":"Data", "Capture / Export":"Image", "Geometry / Guides":"Geometry", "Camera":"Camera"}
const COPY := {
	"Select by ID or region":"Definition", "Surface and cohort tools":"Surfaces and cohorts", "Selection groups":"Groups", "Create selection":"Create", "Cancel selection query":"Cancel", "Run analysis":"Run", "Cancel analysis":"Cancel", "Run space-time analysis":"Run", "Show space-time plot":"Plot", "Import diagnostic CSV":"Import", "Compare left and right":"Compare", "Estimate period in selected range":"Estimate", "Prepare matched views…":"Prepare", "Render matched views":"Render", "Cancel matched views":"Cancel", "Axis start (xyz)":"Axis start", "Axis end (xyz)":"Axis end", "Aligned end (same = snapshot)":"Aligned end", "Pair output limit (MiB)":"Output limit", "New folder name":"Folder", "Output limit (MiB)":"Output limit", "CPU time limit (seconds)":"CPU limit", "Elapsed time limit (seconds)":"Elapsed limit",
	"Include completed results in recipe":"Include results", "Include selection members":"Include members",
	"Series / bookmark name":"Name", "Value columns (comma-separated)":"Value columns", "Time offset (subtract)":"Time offset", "Value offset (add)":"Value offset",
	"Start (inclusive)":"Start", "End (inclusive)":"End", "Statistics (comma-separated)":"Statistics", "Include finite subtotal (incomplete)":"Finite subtotal",
	"Start / center / lower corner (xyz)":"Start or center", "End / normal / upper corner (xyz)":"End or normal", "Pick through / visible surfaces":"Pick mode",
	"Orbit speed • radians / second":"Orbit speed", "Layer GPU budget • MiB":"GPU budget",
	"X slice • ±3 simulation units":"Enabled", "Slice position • box fraction":"Position", "Clamp out-of-range values":"Clamp",
	"Freeze range from recorded interval":"Freeze", "Cancel range scan":"Cancel", "Lower percentile • display choice":"Lower percentile", "Upper percentile • display choice":"Upper percentile",
	"Freeze symmetric range from sample":"Freeze symmetric", "Freeze percentile range from sample":"Freeze percentile", "Reset color • linear 0–1":"Reset color",
	"Clip at world X plane":"Enabled", "Clip X":"X", "Slice plane distance • world":"Distance", "Isosurface threshold":"Threshold", "Extract isosurface":"Extract", "Remove isosurface":"Remove",
	"Source probe • world xyz":"World coordinates", "Probe selected volume":"Probe",
	"Load geometry override JSON…":"Load override", "Clear geometry override":"Clear override"
}
var viewer
var storage: Control
var surface: PanelContainer
var window: Window
var content: VBoxContainer
var heading: Label
var scroller: ScrollContainer
var close_button: Button
var done_button: Button
var actions_row: HBoxContainer
var forms := {}
var scroll_positions := {}
var current := ""
var context: Label
var previous_focus: WeakRef
var shared_diagnostics: Array = []
var durable_controls := {}
var state_body: VBoxContainer
var footers := {}
var footer: VBoxContainer
var notice: Label
var target_choices := {}
var target_pages := {}
var target_selected := {}
var particle_tools := {}
var shared_request: VBoxContainer
var result_context: VBoxContainer
var shared_slots := {}
var selection_context: VBoxContainer


func setup(owner_viewer, canvas: CanvasLayer) -> void:
	viewer = owner_viewer
	storage = Control.new(); storage.hide(); canvas.add_child(storage)
	window = Window.new(); window.title = "Tools"; window.transient = true; window.borderless = true
	# A plain Window starts visible; hide before entering the tree to prevent a launch popup.
	window.hide()
	window.min_size = Vector2i(320,240); window.size = Vector2i(440,240)
	window.close_requested.connect(close); canvas.add_child(window)
	window.window_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close())
	surface = PanelContainer.new(); window.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",10); margin.add_child(box)
	var header := HBoxContainer.new(); box.add_child(header)
	heading = Label.new(); heading.theme_type_variation = "PanelTitle"; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE; header.add_child(heading)
	close_button = Button.new(); close_button.text = "×"; close_button.tooltip_text = "Close"; close_button.custom_minimum_size = Vector2(32,32)
	close_button.theme_type_variation = "IconAction"; close_button.pressed.connect(close); header.add_child(close_button)
	header.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not window.is_embedded() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
			DisplayServer.window_start_drag(window.get_window_id()))
	context = Label.new(); context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; context.hide(); box.add_child(context)
	scroller = ScrollContainer.new(); scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroller.follow_focus = true
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroller)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroller.add_child(content)
	notice = Label.new(); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; notice.theme_type_variation = "HelpLabel"; notice.hide(); box.add_child(notice)
	footer = VBoxContainer.new(); box.add_child(footer)
	actions_row = HBoxContainer.new(); actions_row.alignment = BoxContainer.ALIGNMENT_END; box.add_child(actions_row)
	done_button = Button.new(); done_button.text = "Close"; done_button.theme_type_variation = "SecondaryButton"; done_button.pressed.connect(close); actions_row.add_child(done_button)

func form(title: String) -> VBoxContainer:
	if not forms.has(title):
		var body := VBoxContainer.new(); body.add_theme_constant_override("separation",8)
		storage.add_child(body); forms[title] = body
	return forms[title]

func close(recover_focus := true) -> void:
	var was_visible := window.visible
	window.hide()
	if recover_focus and was_visible and previous_focus != null:
		var control = previous_focus.get_ref()
		if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus()

func open(title: String) -> void:
	var focused: Control = viewer.get_viewport().gui_get_focus_owner()
	if focused != null: previous_focus = weakref(focused)
	if not current.is_empty(): scroll_positions[current] = content.get_parent().scroll_vertical
	for child in content.get_children(): child.reparent(storage)
	for child in footer.get_children(): child.reparent(storage)
	current = title
	selection_shape();selection_predicate()
	var body := form(title)
	if title in ["Data","Save analysis","Load analysis"]:
		body = state_body
		for key in durable_controls: durable_controls[key].visible = key == title or key == "shared" or (key == "results" and title == "Save analysis") or (key == "members" and title == "Data")
	if title in ["Diagnostics","Compare","Period","Bookmarks"]:
		for control in reversed_shared():
			control.reparent(body); body.move_child(control,0)
	body.reparent(content); body.show()
	if footers.has(title):footers[title].reparent(footer)
	if footers.has(title):
		done_button.reparent(footers[title]); actions_row.hide()
	else:
		done_button.reparent(actions_row); actions_row.show()
	share_analysis(title)
	shorten_copy(body)
	shorten_copy(footer)
	Layout.fit(body)
	Layout.fit(footer)
	for row in footer.get_children():
		for action in row.get_children():
			if action is Button: action.clip_text = false
	content.get_parent().set_deferred("scroll_vertical",scroll_positions.get(title,0))
	window.title = title
	heading.text = title
	refresh_context()
	window.theme = viewer.shell.style_slice.theme
	close_button.icon = viewer.shell.style_slice.theme.chrome_icon("close"); close_button.text = ""
	surface.add_theme_stylebox_override("panel",viewer.shell.style_slice.theme.flat_box(&"surface.1",0,0,0))
	var extent: Vector2 = viewer.get_viewport().get_visible_rect().size
	var width := 440 if title in ["Mapping","Diagnostics","Slice","Clipping","Source probe","Geometry","Camera","Global effects"] else 560
	var content_height := body.get_combined_minimum_size().y
	var footer_height := footer.get_combined_minimum_size().y
	var chrome_height := 32 + 32 + 32 + 30 + footer_height
	var desired := Vector2i(width,clampi(ceili(content_height + chrome_height),240,620))
	window.popup_centered(Vector2i(minf(desired.x,extent.x-32),minf(desired.y,extent.y-32)))
	refresh_context()

func reversed_shared() -> Array:
	var controls := shared_diagnostics.duplicate(); controls.reverse(); return controls

func take_group(parent: Node, title: String, destination: String) -> void:
	var toggle := UI.button(parent,title)
	if toggle == null: return
	var body: Control = toggle.get_meta("analysis_group")
	body.reparent(form(destination)); body.show()
	toggle.get_parent().remove_child(toggle); toggle.queue_free()

func finish_static() -> void:
	var temporal = viewer.selection_controller.temporal
	var diagnostic = temporal.diagnostics
	take_group(diagnostic.panel,"Compare series","Compare")
	take_group(diagnostic.panel,"Estimate a period","Period")
	take_group(diagnostic.panel,"Manual bookmarks","Bookmarks")
	# One shared status/name input, moved between tasks rather than cloned models.
	shared_diagnostics = [diagnostic.label_input.get_parent().get_child(diagnostic.label_input.get_index()-1), diagnostic.label_input]
	var first: int = temporal.result_list.get_index()-1
	for child in temporal.panel.get_children().slice(first): child.reparent(form("Results"))
	viewer._button(form("Results"),"Recompute",temporal.durable.recompute)
	# Resource limits belong only to the separate analysis/data operations.
	state_body = temporal.durable.panel
	var shared := VBoxContainer.new(); state_body.add_child(shared)
	for child in state_body.get_children():
		if child != shared: child.reparent(shared)
	var names := {"Export numerical data…":"Data", "Save inspection recipe…":"Save analysis", "Load inspection recipe…":"Load analysis", "Locate referenced input…":"Resolve input", "Recompute selected analysis":"Recompute"}
	for label in names:
		var button := UI.button(shared,label)
		if names[label] in ["Resolve input","Recompute"]:
			button.get_parent().remove_child(button); button.queue_free()
		else:
			button.reparent(state_body); button.text = {"Data":"Export","Save analysis":"Save","Load analysis":"Load"}[names[label]]; durable_controls[names[label]] = button
	# Unwrap the old disclosure so shared limits stay directly reachable.
	var limits := UI.button(shared,"Advanced • Export limits and members")
	if limits != null:
		var group: Control = limits.get_meta("analysis_group")
		for child in group.get_children(): child.reparent(shared)
		group.free(); limits.free()
	for pair in [["members",temporal.durable.include_members],["results",temporal.durable.bundle_results]]:
		pair[1].reparent(state_body); durable_controls[pair[0]] = pair[1]
	durable_controls.shared = shared
	for title in ["Data","Save analysis","Load analysis"]:
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation",8); storage.add_child(row)
		var action: Button = durable_controls[title]; action.reparent(row)
		action.theme_type_variation = "PrimaryButton"
		footers[title] = row
	for title in ["Mapping","Derive range","Slice","Clipping","Isosurface","Source probe","Performance","Geometry","Camera"]: form(title)

	compose_tasks()
	action_footer("Image",["Save image…"])

func shorten_copy(parent: Node) -> void:
	for child in parent.get_children():
		if (child is Label or child is Button) and not child.has_meta("source_name") and COPY.has(child.text):
			if child.tooltip_text.is_empty(): child.tooltip_text = child.text
			child.text = COPY[child.text]
		shorten_copy(child)

func refresh_context() -> void:
	if not window.visible: return
	# Source identity belongs to Details, Diagnostics, or the export result.
	context.hide()

func action_footer(title: String, labels: Array) -> void:
	var body := form(title); var actions := HBoxContainer.new();actions.add_theme_constant_override("separation",8);storage.add_child(actions)
	for index in labels.size():
		var text: String = labels[index]
		var button := find_button(body,text)
		if button != null:
			button.reparent(actions);button.size_flags_horizontal = Control.SIZE_SHRINK_END
			button.theme_type_variation = "PrimaryButton" if index == 0 else "SecondaryButton"
	actions.alignment = BoxContainer.ALIGNMENT_END
	if actions.get_child_count() > 0:footers[title] = actions
	else:actions.free()

func find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:return child
		var found := find_button(child,text)
		if found != null:return found
	return null

func compose_tasks() -> void:
	var selection = viewer.selection_controller
	# Keep conditional widgets and their original labels, even when moved into pages.
	selection.kind.item_selected.connect(func(_i):selection_shape())
	selection.predicate_operation.item_selected.connect(func(_i):selection_predicate())
	selection_predicate()
	selection_shape()
	# Shared inputs are moved, not copied. These are the same widgets read by both controllers.
	var temporal = selection.temporal
	shared_request = Layout.page(storage)
	for control in [temporal.selection_set,temporal.axis,temporal.start_time,temporal.end_time,temporal.channel,temporal.component,temporal.coordinates,temporal.units,temporal.weighting,temporal.weight_channel,temporal.weight_units,temporal.max_gap]:
		move_input(control,shared_request)
	var full := find_button(temporal.panel,"Use full layer range")
	full.reparent(shared_request)
	result_context = Layout.page(storage)
	Layout.label(result_context,"Selected result")
	move_input(temporal.result_list,result_context);move_input(temporal.series_list,result_context)
	for title in ["Selection","Temporal","Space time","Diagnostics","Compare","Period","Bookmarks","Results","Matched runs"]:
		# Status remains visible independently of the scrolling task section.
		var statuses: Array = []
		for child in form(title).get_children():
			if child is Label and child in [selection.status,selection.temporal.status,selection.temporal.space_time.status,selection.temporal.matched.status,selection.temporal.diagnostics.status]:statuses.append(child)
		for status in statuses:status.reparent(storage)
		action_footer(title,{
			"Selection":["Create selection","Cancel selection query"],"Temporal":["Run analysis","Cancel analysis"],
			"Space time":["Run space-time analysis","Show space-time plot"],"Diagnostics":["Import diagnostic CSV"],
			"Compare":["Compare left and right"],"Period":["Estimate period in selected range"],"Matched runs":["Prepare matched views…","Render matched views","Cancel matched views"]}.get(title,[]))
		Layout.grouped_pages(form(title),{"Selection":"Source and gestures","Temporal":"Request","Matched runs":"Sources and output"}.get(title,"Task"))
	# Diagnostics opens on its actionable import form instead of an empty Task page.
	for child in form("Diagnostics").get_children():
		if child is OptionButton and child.has_meta("tool_pages"):
			for index in child.item_count:
				if child.get_item_text(index).contains("Import CSV"):
					child.select(index); child.item_selected.emit(index); break
	selection_context = Layout.page(storage)
	move_input(selection.name_input,selection_context);selection.selections.reparent(selection_context)
	for child in form("Selection").get_children():
		if child is OptionButton and child.has_meta("tool_pages"):
			child.item_selected.connect(func(index):
				var page: VBoxContainer = child.get_meta("tool_pages")[index]
				selection_context.reparent(page);page.move_child(selection_context,0))
			child.item_selected.emit(child.selected)
	# Split the long two-run form by ownership without changing either side's dictionary.
	var matched = temporal.matched
	var matched_body := form("Matched runs")
	Layout.flatten(matched_body)
	# Its legacy page selector is discarded; actual widgets are gathered by references.
	var left := Layout.page(matched_body);var right := Layout.page(matched_body)
	for i in 2:
		var side: Dictionary = matched.sides[i];var destination: VBoxContainer = left if i == 0 else right
		var button := find_button(matched_body,("Left" if i == 0 else "Right")+" recipe…")
		button.reparent(destination)
		for key in ["keys","object","channel","time_scale","time_offset","value_scale","value_offset","origin"]:move_input(side[key],destination)
	var common := Layout.page(matched_body);var output := Layout.page(matched_body)
	for key in matched.common:move_input(matched.common[key],output if key in ["start_time","end_time","fps","playback_rate","width","height","quota_bytes","folder"] else common)
	for child in matched_body.get_children():
		if child not in [left,right,common,output]:child.free()
	Layout.pages(matched_body,["Left source","Right source","Common meaning","Output"],[left,right,common,output])
	for title in ["Temporal","Space time","Period","Compare"]:
		viewer._button(form(title),"Results",open.bind("Results"))
	viewer._button(form("Period"),"Edit range",open_request)
	viewer._button(form("Bookmarks"),"Time mapping",open.bind("Compare"))
	for title in ["Temporal","Space time"]:
		var parent := form(title);var selector: OptionButton
		for child in parent.get_children():
			if child is OptionButton and child.has_meta("tool_pages"):selector = child
		if selector == null:
			var main := Layout.page(parent)
			for child in parent.get_children():
				if child != main:child.reparent(main)
			selector = Layout.pages(parent,["Task"],[main])
		var slot := Layout.page(parent);slot.hide();shared_slots[title] = slot
		selector.add_item("Shared request");selector.get_meta("tool_pages").append(slot)
	share_analysis("Temporal")
	for title in ["Slice","Derive range"]:
		var body := Layout.page(storage)
		for child in form(title).get_children():child.reparent(body)
		particle_tools[title] = body
	# Performance budgets have distinct ownership; labels are not a process ceiling.
	var cache_title := Layout.label(form("Performance"),"Decoded cache");form("Performance").move_child(cache_title,0)
	for title in ["Mapping","Geometry","Performance"]:Layout.fit(form(title))

func selection_shape() -> void:
	var c = viewer.selection_controller;var k: int = c.kind.selected
	Layout.visibility(c.members_input,k in [0,1,3,4,5,6])
	Layout.visibility(c.coordinate_space,k >= 7)
	Layout.visibility(c.mesh_association,k in [2,8,9,10,11])
	Layout.visibility(c.first_input,k >= 7)
	Layout.visibility(c.second_input,k in [8,10,11])
	Layout.visibility(c.radius_input,k in [9,10])
	for control in [c.width_input,c.height_input,c.thickness_input]:Layout.visibility(control,k == 11)

func configure_layer_tools(layers) -> void:
	# Rebuild only presentation navigation when the authoritative layer UI rebuilds.
	for title in ["Derive range","Slice","Clipping","Isosurface"]:
		if target_choices.has(title) and is_instance_valid(target_choices[title]):
			var choice: Control = target_choices[title];choice.get_parent().remove_child(choice);choice.queue_free()
		var body := form(title);var choice := OptionButton.new();body.add_child(choice);body.move_child(choice,0)
		choice.tooltip_text = "Tool target only. Does not select, show or sample an object."
		target_choices[title] = choice;target_pages[title] = {}
		if particle_tools.has(title):
			particle_tools[title].reparent(body);choice.add_item("Particles");choice.set_item_metadata(0,"particles");target_pages[title].particles = particle_tools[title]
		for id in layers.states:
			var key: String = title+":"+id
			if not layers.tool_bodies.has(key):continue
			choice.add_item(id);choice.set_item_metadata(choice.item_count-1,id)
			target_pages[title][id] = layers.tool_bodies[key]
			var first = layers.tool_bodies[key].get_child(0)
			if first is Label and first.has_meta("source_name"):first.hide()
		choice.disabled = choice.item_count == 0
		choice.item_selected.connect(func(index):select_target(title,str(choice.get_item_metadata(index))))
		var saved: String = target_selected.get(title,"")
		if not target_pages[title].has(saved) and choice.item_count > 0:saved = str(choice.get_item_metadata(0))
		select_target(title,saved)
		Layout.fit(body)

func select_target(title: String, id: String) -> void:
	target_selected[title] = id
	for key in target_pages[title]:target_pages[title][key].visible = key == id
	var choice: OptionButton = target_choices[title]
	for index in choice.item_count:
		if str(choice.get_item_metadata(index)) == id:choice.select(index)

func _process(_delta: float) -> void:
	if not is_instance_valid(window) or not window.visible:return
	refresh_context()
	var selection = viewer.selection_controller
	var temporal = selection.temporal
	var statuses := {"Selection":selection.status,"Temporal":temporal.status,"Space time":temporal.space_time.status,"Matched runs":temporal.matched.status,"Diagnostics":temporal.diagnostics.status,"Compare":temporal.diagnostics.status,"Period":temporal.diagnostics.status,"Bookmarks":temporal.diagnostics.status}
	var status: String = statuses[current].text if statuses.has(current) else ""
	# Empty and introductory copy should not become a permanent duplicate footer.
	var introductory := status.begins_with("Import a diagnostic CSV") or status.begins_with("Choose a selection")
	notice.text = status
	notice.visible = not status.is_empty() and not introductory
	if viewer.scene_layers != null:
		viewer.scene_layers.refresh_probe_stamp()

func move_input(control: Control, destination: Node) -> void:
	var parent := control.get_parent();var index := control.get_index()
	if index > 0 and parent.get_child(index-1) is Label:parent.get_child(index-1).reparent(destination)
	control.reparent(destination)

func share_analysis(title: String) -> void:
	if title in ["Temporal","Space time"]:
		shared_request.reparent(shared_slots[title])
	elif is_instance_valid(shared_request):shared_request.reparent(storage)
	if title in ["Results","Compare","Period"]:
		result_context.reparent(form(title));form(title).move_child(result_context,0)
	else:result_context.reparent(storage)

func selection_predicate() -> void:
	var c = viewer.selection_controller;var mode: int = c.predicate_operation.selected
	for control in [c.predicate_channel,c.predicate_component]:Layout.visibility(control,mode > 0)
	for control in [c.predicate_lower,c.predicate_upper]:Layout.visibility(control,mode == 2)
	c.predicate_integer.visible = mode == 2
	Layout.visibility(c.predicate_members,mode in [3,4])

func open_request() -> void:
	open("Temporal")
	for child in form("Temporal").get_children():
		if child is OptionButton and child.has_meta("tool_pages"):
			child.select(child.item_count-1);child.item_selected.emit(child.selected)
