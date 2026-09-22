extends Node
## Hosts existing controls once. Navigation never creates scientific requests.
const UI = preload("res://analysis/ui_controls.gd")
const SECTIONS := {"Data cache":"Performance", "Selections":"Selection", "Temporal analysis":"Temporal", "Space-time analysis":"Space time", "Diagnostics and comparisons":"Diagnostics", "Matched runs":"Matched runs", "Analysis export and state":"Data", "Capture / Export":"Image", "Geometry / Guides":"Geometry", "Camera":"Camera"}
const COPY := {
	"New folder name":"Folder", "Output limit (MiB)":"Output limit", "CPU time limit (seconds)":"CPU limit", "Elapsed time limit (seconds)":"Elapsed limit",
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
	"Volume display preset • optional action":"Preset", "Apply volume display preset from sample":"Apply",
	"Load geometry override JSON…":"Load override", "Clear geometry override":"Clear override"
}
var viewer
var storage: Control
var surface: PanelContainer
var window: Window
var content: VBoxContainer
var forms := {}
var scroll_positions := {}
var current := ""
var context: Label
var previous_focus: WeakRef
var shared_diagnostics: Array = []
var durable_controls := {}
var state_body: VBoxContainer

func setup(owner_viewer, canvas: CanvasLayer) -> void:
	viewer = owner_viewer
	storage = Control.new(); storage.hide(); canvas.add_child(storage)
	window = Window.new(); window.title = "Tools"; window.transient = true
	window.min_size = Vector2i(320,240); window.size = Vector2i(520,600)
	window.close_requested.connect(close); canvas.add_child(window)
	surface = PanelContainer.new(); window.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	var box := VBoxContainer.new(); margin.add_child(box)
	context = Label.new(); context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(context)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)
	var close_button := Button.new(); close_button.text = "Close"; close_button.pressed.connect(close); box.add_child(close_button)

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
	if viewer.shell != null and viewer.shell.immersive: return
	var focused: Control = viewer.get_viewport().gui_get_focus_owner()
	if focused != null: previous_focus = weakref(focused)
	if not current.is_empty(): scroll_positions[current] = content.get_parent().scroll_vertical
	for child in content.get_children(): child.reparent(storage)
	current = title
	var body := form(title)
	if title in ["Data","Save analysis","Save scene","Load scene","Load analysis"]:
		body = state_body
		for key in durable_controls: durable_controls[key].visible = key == title or key == "shared" or (key == "results" and title in ["Save analysis","Save scene"]) or (key == "members" and title == "Data")
	if title in ["Diagnostics","Compare","Period","Bookmarks"]:
		for control in reversed_shared():
			control.reparent(body); body.move_child(control,0)
	body.reparent(content); body.show()
	shorten_copy(body)
	UI.fit(body)
	content.get_parent().set_deferred("scroll_vertical",scroll_positions.get(title,0))
	window.title = title
	refresh_context()
	window.theme = viewer.shell.theme
	surface.add_theme_stylebox_override("panel",viewer.shell.theme.box(&"surface.1", &"border.subtle",0,0,0))
	var extent: Vector2 = viewer.get_viewport().get_visible_rect().size
	window.popup_centered(Vector2i(minf(560,extent.x-32),minf(640,extent.y-64)))
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
	shared_diagnostics = [diagnostic.status, diagnostic.label_input.get_parent().get_child(diagnostic.label_input.get_index()-1), diagnostic.label_input]
	var first: int = temporal.result_list.get_index()-1
	for child in temporal.panel.get_children().slice(first): child.reparent(form("Results"))
	viewer._button(form("Results"),"Recompute",temporal.durable.recompute)
	# Request limits are a single control set consumed by scene/analysis/data operations.
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
	durable_controls["Save scene"] = viewer._button(state_body,"Save",viewer._show_recipe_dialog.bind(true))
	durable_controls["Load scene"] = viewer._button(state_body,"Load",viewer._show_recipe_dialog.bind(false))
	for title in ["Mapping","Quick setup","Derive range","Slice","Clipping","Isosurface","Source probe","Performance","Geometry","Camera"]: form(title)

func shorten_copy(parent: Node) -> void:
	for child in parent.get_children():
		if (child is Label or child is Button) and not child.has_meta("source_name") and COPY.has(child.text):
			if child.tooltip_text.is_empty(): child.tooltip_text = child.text
			child.text = COPY[child.text]
		shorten_copy(child)

func refresh_context() -> void:
	if not window.visible: return
	var source: String = viewer.capture_path.get_file() if viewer.generic_reader != null else "No capture"
	context.text = source
	if current in ["Temporal","Space time","Compare","Period","Results"]:
		var temporal = viewer.selection_controller.temporal
		var target = viewer.selection_controller.target
		var object: String = target.get_item_text(target.selected) if target.selected >= 0 else "Unbound"
		context.text = str(viewer.selection_controller.source.get("path","Unbound source")).get_file() + " · " + object + "\n" + temporal.channel.text + " · " + temporal.start_time.text + " to " + temporal.end_time.text
