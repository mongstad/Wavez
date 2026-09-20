extends Node
const UI = preload("res://analysis/ui_controls.gd")
const State = preload("res://selection/selection_state.gd")
const Overlay = preload("res://selection/selection_overlay.gd")
const Jobs = preload("res://analysis/analysis_jobs.gd")
const Profile = preload("res://scene/playback_profile.gd")
var viewer
var state := State.new()
var jobs := Jobs.new()
var overlay := Overlay.new()
var source := {}
var objects := {}
var operation := ""
var overlay_key := ""
var requested_overlay_key := ""
var failed_overlay_key := ""
var last_resolution: Array = []
var serial := 0
var pick_points: Array = []
var drag_start := Vector2.ZERO
var selecting := false
var gesture
var gesture_context := {}
var pending_edit := "new"
var panel: VBoxContainer
var status: Label
var target: OptionButton
var tool: OptionButton
var edits: OptionButton
var occlusion: OptionButton
var kind: OptionButton
var name_input: LineEdit
var members_input: LineEdit
var first_input: LineEdit
var second_input: LineEdit
var radius_input: SpinBox
var width_input: SpinBox
var height_input: SpinBox
var thickness_input: SpinBox
var selections: ItemList
var group_list: OptionButton
var coordinate_space: OptionButton
var mesh_association: OptionButton
var predicate_channel: LineEdit
var predicate_operation: OptionButton
var predicate_component: OptionButton
var predicate_integer: CheckButton
var predicate_lower: LineEdit
var predicate_upper: LineEdit
var predicate_members: LineEdit
var copy_type_filter: CheckButton
var temporal

func setup(scene) -> void:
	viewer = scene;jobs.playback_owner = viewer;add_child(jobs);viewer.add_child(overlay)
	var canvas := CanvasLayer.new();canvas.layer = 3;add_child(canvas)
	gesture = preload("res://selection/selection_gesture.gd").new();canvas.add_child(gesture)
	jobs.completed.connect(_completed)
	jobs.failed.connect(func(message):
		if operation == "resolve_selections":failed_overlay_key = requested_overlay_key;overlay.clear()
		operation = "";status.text = message)
	panel = viewer._section("Selections")
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Selections use source data, independent of display settings.";panel.add_child(status)
	viewer._button(panel,"Use current capture",bind_source)
	target = viewer._option(panel,"Source layer")
	tool = viewer._option(panel,"Pointer tool")
	for item in ["Orbit","Click","Rectangle","Lasso","Mesh face","Mesh point","Mesh vertex","Slice probe","Derived face","Derived point","Field probe on surface"]:tool.add_item(item)
	tool.item_selected.connect(func(i):
		if i>0:viewer.playing = false;viewer.orbit_enabled = false
		selecting = false;pick_points.clear();gesture.show_polygon([]);gesture_context.clear())
	edits = viewer._option(panel,"Selection edit")
	for item in ["New selection","Replace active","Add to active","Subtract from active","Toggle in active"]:edits.add_item(item)
	occlusion = viewer._option(panel,"Pick through / visible surfaces")
	occlusion.add_item("Through chosen layer");occlusion.add_item("Opaque meshes / slices")
	name_input = _text("Name","Selection")
	selections = ItemList.new();selections.custom_minimum_size.y = 110
	selections.select_mode = ItemList.SELECT_MULTI;panel.add_child(selections)
	selections.item_selected.connect(func(index):
		state.active = selections.get_item_metadata(index)
		if temporal != null:temporal.selection_changed())
	viewer._button(panel,"Rename selection",func():
		if state.rename_active(name_input.text):_changed())
	viewer._button(panel,"Duplicate selection",func():
		var d := state.find(state.active).duplicate(true)
		if d.is_empty():return
		d.key = _key();d.name = name_input.text;d.revision = 1
		if state.put(d):_changed())
	viewer._button(panel,"Delete selection",func():state.remove(state.active);_changed())
	viewer._button(panel,"Toggle highlight",func():
		var d := state.find(state.active).duplicate(true)
		if not d.is_empty():d.display.visible = not d.display.visible;d.revision += 1;state.put(d);_changed())
	viewer._check(panel,"Show hidden selection",false,func(value):state.overlay.show_hidden = value;state.revision += 1;_changed())
	kind = viewer._option(panel,"Selection type")
	for item in ["Persistent IDs","Rows in one sample","Mesh object","Mesh vertex IDs","Mesh vertex rows","Mesh faces","Grid sample addresses","Probe","Box ROI","Sphere ROI","Cylinder ROI","Slab ROI"]:kind.add_item(item)
	members_input = _text("IDs or sample addresses","7")
	coordinate_space = viewer._option(panel,"Coordinate space")
	coordinate_space.add_item("World");coordinate_space.add_item("Object local")
	mesh_association = viewer._option(panel,"Mesh elements")
	mesh_association.add_item("Source vertices");mesh_association.add_item("Source faces")
	first_input = _text("Start / center / lower corner (xyz)","0,0,0")
	second_input = _text("End / normal / upper corner (xyz)","1,1,1")
	radius_input = viewer._inspection_number(panel,"Radius",1)
	width_input = viewer._inspection_number(panel,"Slab width",2)
	height_input = viewer._inspection_number(panel,"Slab height",2)
	thickness_input = viewer._inspection_number(panel,"Slab thickness",1)
	predicate_channel = _text("Filter channel","")
	predicate_operation = viewer._option(panel,"Value filter")
	for item in ["None","Finite values","Inclusive numeric range","Integer membership","Exclude integer membership"]:predicate_operation.add_item(item)
	predicate_component = viewer._option(panel,"Filter component")
	for item in ["Scalar","Component 0 / x","Component 1 / y","Component 2 / z","Component 3 / w"]:predicate_component.add_item(item)
	predicate_integer = viewer._check(panel,"Exact integer range bounds",false,func(_v):pass)
	predicate_lower = _text("Lower bound","0");predicate_upper = _text("Upper bound","1")
	predicate_members = _text("Integer values","0")
	copy_type_filter = viewer._check(panel,"Copy current particle type exclusions",false,func(_v):pass)
	viewer._button(panel,"Create selection",create_definition)
	viewer._button(panel,"Select generated surface",func():_select_artifact("object",{}))
	viewer._button(panel,"Save current members as cohort",func():
		var d := state.find(state.active)
		if not d.is_empty():pending_edit = "new";_request("freeze_selection",{"selection":d,"time":_time(),"key":_key(),"name":name_input.text}))
	viewer._button(panel,"Group selected entries",func():
		var members: Array = []
		for i in selections.get_selected_items():members.append(selections.get_item_metadata(i))
		if state.group(name_input.text,members):_changed()
		else:status.text = state.error)
	group_list = viewer._option(panel,"Named groups")
	viewer._button(panel,"Rename group",func():
		if state.rename_group(group_list.selected,name_input.text):_changed())
	viewer._button(panel,"Delete group",func():state.remove_group(group_list.selected);_changed())
	viewer._button(panel,"Save group union",func():_group_reduce("union"))
	viewer._button(panel,"Save group intersection",func():_group_reduce("intersection"))
	viewer._button(panel,"Cancel selection query",cancel_query)
	UI.hint(members_input,"IDs or rows: comma-separated. Grid addresses: x,y,z triples separated by semicolons. IDs remain exact decimal integers.")
	UI.hint(coordinate_space,"World coordinates include the object's declared transform. Object-local coordinates are before that transform.")
	UI.hint(copy_type_filter,"Copy current type exclusions into this selection. Later display-filter changes do not change membership.")
	UI.group(panel,predicate_channel,copy_type_filter,"Advanced • Value filters","Filters change scientific membership and are saved with the selection.")
	UI.group(panel,kind,UI.button(panel,"Create selection"),"Select by ID or region")
	UI.group(panel,UI.button(panel,"Rename selection"),UI.button(panel,"Show hidden selection"),"Edit selection")
	UI.group(panel,UI.button(panel,"Select generated surface"),UI.button(panel,"Save current members as cohort"),"Surface and cohort tools","Generated surfaces have no persistent physical identity. A frozen cohort differs from a spatial region.")
	UI.group(panel,UI.button(panel,"Group selected entries"),UI.button(panel,"Save group intersection"),"Selection groups")
	UI.fit(panel)

	temporal = preload("res://analysis/temporal_controller.gd").new();add_child(temporal);temporal.setup(self)
	set_process(false)

func cancel_query() -> void:
	jobs.cancel();operation = "";failed_overlay_key = _current_key();status.text = "Selection query cancelled."

func _text(label: String, initial: String) -> LineEdit:
	var title := Label.new();title.text = label;panel.add_child(title)
	var entry := LineEdit.new();entry.text = initial;panel.add_child(entry);return entry

func _key() -> String:
	serial += 1;return "selection-%d-%d" % [OS.get_process_id(),serial]

func _time() -> float:
	return float(viewer.committed_sample.get("requested_time",viewer.requested_time))

func reset_source() -> void:
	if temporal != null:temporal.reset()
	jobs.shutdown();source = {};objects.clear();state = State.new();overlay.clear()
	selecting = false;gesture.show_polygon([]);gesture_context.clear()
	operation = "";overlay_key = "";failed_overlay_key = "";tool.select(0);target.clear();selections.clear();group_list.clear()
	status.text = "Choose Use current capture to begin.";set_process(false)

func bind_source() -> void:
	if viewer.capture_path.is_empty() or viewer.frame_count == 0:status.text = "Open a capture with complete records first.";return
	viewer.playing = false
	var extent: int = viewer.generic_reader.scan_offset
	if not state.definitions.is_empty() and source.get("committed_bytes") != str(extent):
		status.text = "Selections reference an earlier capture snapshot. Save or delete them before using newer samples.";return
	source = {"path":ProjectSettings.globalize_path(viewer.capture_path),"committed_bytes":str(extent)}
	temporal.durable.remember_path(source.path)
	_request("describe",{})

func _request(name: String, arguments: Dictionary) -> void:
	var started := Profile.begin()
	_request_profiled(name,arguments)
	Profile.end("g4_request",started,{"operation":name})

func _request_profiled(name: String, arguments: Dictionary) -> void:
	if source.is_empty():status.text = "Use current capture before making a selection.";return
	if viewer.scene_layers != null and viewer.scene_layers.iso_pid > 0:
		failed_overlay_key = _current_key();status.text = "Source analysis waits until isosurface extraction finishes. Repeat the query when ready.";return
	operation = name;set_process(true)
	var pins := {}
	for definition in state.definitions:
		for field in ["ids_asset","rows_asset","xyz_asset"]:
			if definition.selector.has(field):pins[definition.selector[field].sha256] = definition.selector[field]
	jobs.member_pins = pins.values()
	if temporal != null:temporal.update_pins()
	var token := jobs.request(source,name,arguments,viewer.capture_generation,state.revision)
	if token.is_empty():operation = "";status.text = jobs.error
	else:status.text = "Resolving source data… scene remains interactive."

func _completed(result: Dictionary) -> void:
	var started := Profile.begin()
	_completed_profiled(result)
	Profile.end("g4_result_commit",started)

func _completed_profiled(result: Dictionary) -> void:
	var completed_operation := operation;operation = ""
	if int(result.scene_revision) != viewer.capture_generation or int(result.selection_revision) != state.revision:
		status.text = "Superseded selection result ignored.";return
	if completed_operation == "result_page":temporal.receive_page(result);return
	if completed_operation == "describe":
		source = result.source;target.clear();objects.clear()
		for item in result.data.objects:
			objects[item.object.id] = item;target.add_item(item.object.id+" • "+item.object.kind)
			target.set_item_metadata(target.item_count-1,item.object.id)
		status.text = "Capture snapshot ready. Pick in the view or select by ID or region."
	elif completed_operation == "resolve_selections":
		if requested_overlay_key != _current_key():overlay.clear();return
		var used := 0
		if viewer.scene_layers != null:
			for view in viewer.scene_layers.views.values():used += view.gpu_bytes
			if is_instance_valid(viewer.scene_layers.iso_node):used += viewer.scene_layers.iso_node.gpu_bytes
		var budget: int = 16*1048576 if viewer.scene_layers == null else maxi(0,viewer.scene_layers.gpu_budget_mib*1048576-used)
		if not overlay.publish(result.data.results,state,budget):status.text = "Selection highlight exceeds remaining GPU budget.";return
		overlay.visible = state.overlay.visible
		overlay.update_time(_time(),viewer,state)
		last_resolution = result.data.results
		overlay_key = requested_overlay_key
		var selected := 0;var present := 0;var shown := 0
		for r in result.data.results:selected += int(r.selected);present += int(r.present);shown += r.preview.size()
		status.text = "%d selections • %d selected members\n%d present • %d highlights\nCounts include overlaps; highlights may show a subset." % [result.data.results.size(),selected,present,shown]
	elif completed_operation == "edit_selection":
		if state.put(result.data):_changed()
		else:status.text = state.error
	else:
		var definition: Dictionary = result.data if completed_operation == "define_selection" else result.data.selection
		if pending_edit != "new" and not state.find(state.active).is_empty():
			_request("edit_selection",{"selection":state.find(state.active),"incoming":definition,"mode":pending_edit});return
		if state.put(definition):_changed()
		else:status.text = state.error

func _changed() -> void:
	viewer.control_checks["Show hidden selection"].set_pressed_no_signal(state.overlay.show_hidden)
	last_resolution = []
	if temporal != null:temporal.selection_changed()
	jobs.cancel();operation = "";overlay_key = "";failed_overlay_key = "";overlay.clear();set_process(true)
	selections.clear()
	for d in state.definitions:
		selections.add_item(d.name+" • "+d.kind.replace("_"," "));selections.set_item_metadata(selections.item_count-1,d.key)
		if d.key == state.active:selections.select(selections.item_count-1)
	group_list.clear()
	for group in state.groups:group_list.add_item(group.name)

func _current_key() -> String:
	if viewer.committed_sample.is_empty():return ""
	var parts: Array = [viewer.capture_generation,state.revision]
	parts.append(_visual())
	if viewer.scene_layers != null:parts.append(viewer.scene_layers.iso_result.get("sha256",""))
	for d in state.definitions:
		if not d.display.visible:continue
		if viewer.scene_layers != null:
			var p: Dictionary = viewer.generic_reader.bracket(d.object,_time())
			parts.append([d.key,p.get("a",-1),p.get("b",-1),_layer_visible(d.object)])
		else:parts.append([d.key,viewer.committed_sample.get("source_indices",[]),viewer.particle_layer_visible])
	return JSON.stringify(parts)

func _layer_visible(oid: String) -> bool:
	if viewer.scene_layers != null and viewer.scene_layers.states.has(oid):return viewer.scene_layers.states[oid].visible
	return viewer.particle_layer_visible

func _definition_visible(definition: Dictionary) -> bool:
	if definition.kind == "derived_surface":
		return viewer.scene_layers != null and is_instance_valid(viewer.scene_layers.iso_node) and viewer.scene_layers.iso_node.visible and viewer.scene_layers.iso_result.get("sha256","") == definition.selector.artifact_sha256
	return _layer_visible(definition.object)

func _process(_delta: float) -> void:
	var started := Profile.begin()
	_process_profiled()
	Profile.end("g4_overlay_tick",started)

func _process_profiled() -> void:
	if source.is_empty() or state.definitions.is_empty():return
	if not state.overlay.visible:overlay.clear();overlay_key = _current_key();return
	var extent: int = viewer.generic_reader.scan_offset
	if source.get("committed_bytes") != str(extent):
		overlay.visible = false;jobs.cancel();operation = ""
		status.text = "Capture changed. Selections retain their saved snapshot; current highlights are unavailable.";return
	var key := _current_key()
	if key.is_empty():overlay.clear();return
	if key != overlay_key:
		overlay.visible = false
		if key == failed_overlay_key:return
		if operation.is_empty() or (operation == "resolve_selections" and key != requested_overlay_key):
			var definitions: Array = []
			for d in state.definitions:
				if d.display.visible and (_definition_visible(d) or state.overlay.show_hidden):definitions.append(d)
			if definitions.is_empty():overlay.clear();overlay_key = key;return
			requested_overlay_key = key
			var args := {"selections":definitions,"time":_time(),"limit":int(state.overlay.maximum),"visual":_visual()}
			if viewer.scene_layers == null and viewer.time_mode == "index":args.erase("time");args.index = viewer.current_index
			_request("resolve_selections",args)
	else:
		overlay.visible = true;overlay.update_time(_time(),viewer,state)

func await_committed_overlay(timeout_ms := 150000, cancelled_callback: Callable = Callable()) -> bool:
	# Export forces a query at this exact time, even within a cached pair. The
	# interactive pair cache may reuse endpoints, but frame evidence must not.
	var expected_scene: int = viewer.capture_generation;var expected_revision: int = state.revision;var expected_time := _time()
	var definitions: Array = []
	if state.overlay.visible:
		for definition in state.definitions:
			if definition.display.visible and (_definition_visible(definition) or state.overlay.show_hidden):definitions.append(definition)
	if definitions.is_empty():overlay.clear();last_resolution = [];overlay_key = _current_key();return true
	if not source.has("sha256"):return false
	jobs.cancel();operation = "";last_resolution = [];failed_overlay_key = "";overlay_key = "";requested_overlay_key = _current_key()
	var arguments := {"selections":definitions,"time":expected_time,"limit":int(state.overlay.maximum),"visual":_visual()}
	if viewer.scene_layers == null and viewer.time_mode == "index":arguments.erase("time");arguments.index = viewer.current_index
	_request("resolve_selections",arguments)
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < timeout_ms:
		if cancelled_callback.is_valid() and cancelled_callback.call():jobs.cancel();return false
		if expected_scene != viewer.capture_generation or expected_revision != state.revision or expected_time != _time():return false
		if not jobs.pending:
			if not jobs.error.is_empty() or overlay_key != _current_key():return false
			overlay.update_time(expected_time,viewer,state);return true
		await get_tree().create_timer(.01).timeout
	jobs.cancel();return false

func frame_evidence() -> Dictionary:
	return {"version":1,"source":source,"selection_revision":state.revision,"requested_time":_time(),"quality":state.overlay.duplicate(true),"results":last_resolution,"drawn_markers":overlay.drawn,"gpu_bytes":overlay.gpu_bytes,"preview_only":true,"membership_policy":"source selections; display eligibility changes markers only"}

func _numbers(text: String, count := 3) -> Array:
	var parts := text.split(",",false);var values: Array = []
	if parts.size() != count:return []
	for part in parts:
		if not part.strip_edges().is_valid_float():return []
		var value := part.to_float()
		if not is_finite(value):return []
		values.append(value)
	return values

func _index(oid: String) -> int:
	if viewer.scene_layers != null:return int(viewer.generic_reader.bracket(oid,_time()).get("a",-1))
	return viewer.current_index

func create_definition() -> void:
	if target.item_count == 0:return
	var oid: String = target.get_item_metadata(target.selected)
	var index := _index(oid);var selection_kind := "";var selector := {}
	var members: Array = []
	for text in members_input.text.split(",",false):members.append(text.strip_edges())
	match kind.selected:
		0,3:selection_kind = "particle_ids" if kind.selected == 0 else "mesh_vertices";selector.ids = members
		1,4,5:
			selection_kind = "sample_rows" if kind.selected == 1 else ("mesh_faces" if kind.selected == 5 else "mesh_vertices")
			var rows: Array = []
			for member in members:
				if not member.is_valid_int():status.text = "Rows must be integer source addresses.";return
				rows.append(member.to_int())
			selector = {"index":index,"rows":rows}
		2:selection_kind = "mesh_object"
		6:
			selection_kind = "grid_samples";var xyz: Array = []
			for triple in members_input.text.split(";",false):
				var p := _numbers(triple)
				if p.is_empty() or p.any(func(v):return v != floor(v)):status.text = "Grid addresses require integer x,y,z triples.";return
				xyz.append(p.map(func(v):return int(v)))
			selector = {"index":index,"xyz":xyz}
		7:selection_kind = "probe";selector.coordinate = _numbers(first_input.text)
		8:selection_kind = "roi";selector = {"shape":"box","lower":_numbers(first_input.text),"upper":_numbers(second_input.text)}
		9:selection_kind = "roi";selector = {"shape":"sphere","center":_numbers(first_input.text),"radius":radius_input.value}
		10:selection_kind = "roi";selector = {"shape":"cylinder","start":_numbers(first_input.text),"end":_numbers(second_input.text),"radius":radius_input.value}
		11:
			selection_kind = "roi";var normal := _numbers(second_input.text)
			if normal.is_empty():status.text = "Slab normal requires three finite components.";return
			# Keep scientific form coordinates as doubles; the worker normalizes.
			var tangent: Array = [-normal[2],0.0,normal[0]] if normal[0] != 0 or normal[2] != 0 else [0.0,normal[2],-normal[1]]
			selector = {"shape":"slab","center":_numbers(first_input.text),"normal":normal,"tangent":tangent,"width":width_input.value,"height":height_input.value,"thickness":thickness_input.value}
	pending_edit = ["new","replace","add","subtract","toggle"][edits.selected]
	var clauses: Array = []
	if predicate_operation.selected > 0:
		var clause := {"channel":predicate_channel.text.strip_edges(),"component":null if predicate_component.selected == 0 else predicate_component.selected-1,"op":["","finite","range","in","not_in"][predicate_operation.selected]}
		if clause.op == "range":
			if predicate_integer.button_pressed:
				clause.lower = predicate_lower.text.strip_edges();clause.upper = predicate_upper.text.strip_edges()
			else:
				var values := _numbers(predicate_lower.text+","+predicate_upper.text,2)
				if values.is_empty():status.text = "Range bounds must be finite numbers.";return
				clause.lower = values[0];clause.upper = values[1]
		if clause.op in ["in","not_in"]:
			clause.values = []
			for value in predicate_members.text.split(",",false):clause.values.append(value.strip_edges())
		clauses.append(clause)
	if copy_type_filter.button_pressed:
		if objects[oid].object.kind != "particles":status.text = "Particle type exclusions require a particle target.";return
		clauses.append({"channel":"particle_type","op":"not_in","values":viewer.hidden_types.keys().map(func(v):return str(v))})
	var units: String = "unknown"
	if viewer.scene_layers != null:units = viewer.generic_reader.metadata.get("position_unit",objects[oid].object.get("units","unknown"))
	var arguments := {"key":_key(),"name":name_input.text,"object":oid,"kind":selection_kind,"selector":selector,"predicate":clauses,"coordinates":{"space":"viewer_world" if coordinate_space.selected == 0 else "data_local","units":units}}
	if objects[oid].object.kind == "mesh":arguments.association = "face" if selection_kind == "mesh_faces" or selection_kind in ["mesh_object","roi"] and mesh_association.selected == 1 else "vertex"
	_request("define_selection",arguments)

func _group_reduce(mode: String) -> void:
	if group_list.selected < 0:return
	var members: Array = state.groups[group_list.selected].members
	var definitions: Array = []
	for member in members:definitions.append(state.find(member.key))
	if definitions.is_empty():return
	pending_edit = "new"
	_request("combine_selections",{"selection":definitions[0],"other":definitions.slice(1),"operation":mode,"time":_time(),"key":_key(),"name":name_input.text})

func handle_input(event: InputEvent) -> bool:
	if tool.selected == 0 or source.is_empty():return false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if viewer.scene_layers != null and viewer.scene_layers.is_buffering():status.text = "Wait for the requested sample to finish loading before picking.";return true
			viewer.playing = false;viewer.orbit_enabled = false
			selecting = true;drag_start = event.position;pick_points = [[event.position.x,event.position.y]]
			gesture_context = {"time":_time(),"generation":viewer.capture_generation,"camera":_camera()}
		elif selecting:
			selecting = false;gesture.show_polygon([]);_pick(event.position)
		return true
	if event is InputEventMouseMotion and selecting:
		if tool.selected == 2:gesture.show_polygon([[drag_start.x,drag_start.y],[event.position.x,drag_start.y],[event.position.x,event.position.y],[drag_start.x,event.position.y]])
		if tool.selected == 3 and pick_points.size() < 256:
			var last: Array = pick_points[-1]
			if event.position.distance_to(Vector2(last[0],last[1]))>=3:pick_points.append([event.position.x,event.position.y])
			gesture.show_polygon(pick_points)
		return true
	return false

func _input(event: InputEvent) -> void:
	# Retain an in-progress gesture when its pointer crosses an inspector control.
	if selecting and (event is InputEventMouseMotion or event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		if handle_input(event):get_viewport().set_input_as_handled()

func _camera() -> Dictionary:
	var transform: Transform3D = viewer.camera.global_transform.affine_inverse()
	var projection: Projection = viewer.camera.get_camera_projection()
	var view: Array = [];var proj: Array = []
	for row in range(3):
		for col in range(3):view.append(transform.basis[col][row])
		view.append(transform.origin[row])
	for row in range(4):
		for col in range(4):proj.append(projection[col][row])
	var size: Vector2 = viewer.get_viewport().get_visible_rect().size
	var origin: Vector3 = viewer.camera.global_position
	return {"view":view,"projection":proj,"viewport":[size.x,size.y],"near":viewer.camera.near,"far":viewer.camera.far,"origin":[origin.x,origin.y,origin.z],"orthographic":viewer.camera.projection == Camera3D.PROJECTION_ORTHOGONAL}

func _particle_style() -> Dictionary:
	return {"visible":viewer.particle_layer_visible,"color":viewer.color_channel,"size":viewer.size_channel,"brightness":viewer.brightness_channel,"hidden_types":viewer.hidden_types.keys().map(func(v):return str(v)),"color_bounds":[viewer.range_min,viewer.range_max] if is_finite(viewer.range_min) and is_finite(viewer.range_max) else null,"log":viewer.logarithmic,"cyclic":viewer.cyclic,"clamp":viewer.clamp_map}

func _visual() -> Dictionary:
	if state.overlay.show_hidden:return {}
	var oid: String = viewer.scene_layers.particle_id if viewer.scene_layers != null else "particles"
	return {oid:_particle_style()} if not oid.is_empty() else {}

func _pick(pixel: Vector2) -> void:
	if target.item_count == 0:return
	if not gesture_context.is_empty():
		var context := gesture_context;gesture_context = {}
		if context.generation != viewer.capture_generation or context.time != _time() or context.camera != _camera():
			status.text = "Scene or camera changed during the gesture; repeat the pick on the current view.";return
	var oid: String = target.get_item_metadata(target.selected)
	var mode: String = ["","click","polygon","polygon","mesh_face","mesh_point","mesh_vertex","probe","face","point","source_probe"][tool.selected]
	var arguments := {"object":oid,"mode":mode,"time":_time(),"camera":_camera(),"point":[pixel.x,pixel.y],"radius":8,"occlusion":"opaque" if occlusion.selected == 1 else "through","key":_key(),"name":name_input.text}
	if viewer.scene_layers == null and viewer.time_mode == "index":arguments.erase("time");arguments.index = viewer.current_index
	if tool.selected == 2:arguments.polygon = [[drag_start.x,drag_start.y],[pixel.x,drag_start.y],[pixel.x,pixel.y],[drag_start.x,pixel.y]]
	if tool.selected == 3:arguments.polygon = pick_points
	if tool.selected in [4,5,7,8,9,10]:
		var origin: Vector3 = viewer.camera.project_ray_origin(pixel)
		var direction: Vector3 = viewer.camera.project_ray_normal(pixel)
		arguments.ray = {"origin":[origin.x,origin.y,origin.z],"direction":[direction.x,direction.y,direction.z]}
	arguments.style = {"visible":_layer_visible(oid)}
	if objects[oid].object.kind == "particles":
		arguments.style = _particle_style()
		if viewer.slice_enabled:arguments.clip = {"normal":[1,0,0],"distance":viewer.slice_x*viewer.half_extent,"half_width":3}
	if mode == "probe":
		if viewer.scene_layers == null or not viewer.scene_layers.states.has(oid) or not viewer.scene_layers.states[oid].get("slice",false):status.text = "Enable a slice on this volume, or create a typed probe coordinate.";return
		var s: Dictionary = viewer.scene_layers.states[oid]
		arguments.plane = {"normal":s.slice_normal,"distance":s.slice_distance,"channel":s.channel}
	arguments.occluders = []
	if viewer.scene_layers != null:
		for id in viewer.scene_layers.states:
			if id == oid:continue
			var s: Dictionary = viewer.scene_layers.states[id]
			var entry := {"object":id,"visible":s.visible,"wireframe":s.get("wireframe",false)}
			if s.has("slice"):entry.merge({"slice":s.slice,"opacity":s.opacity,"channel":s.channel,"normal":s.slice_normal,"distance":s.slice_distance,"clip":s.clip,"clip_normal":s.clip_normal,"clip_distance":s.clip_distance})
			arguments.occluders.append(entry)
	pending_edit = ["new","replace","add","subtract","toggle"][edits.selected]
	if tool.selected >= 8:_select_artifact(mode,arguments);return
	_request("pick",arguments)

func _select_artifact(mode: String, pick: Dictionary) -> void:
	if target.selected < 0 or viewer.scene_layers == null:return
	var oid: String = target.get_item_metadata(target.selected)
	var result: Dictionary = viewer.scene_layers.iso_result
	if result.is_empty() or viewer.scene_layers.iso_id != oid or not is_instance_valid(viewer.scene_layers.iso_node) or not viewer.scene_layers.iso_node.visible:
		status.text = "Extract a surface on the chosen source grid first.";return
	var args := {"object":oid,"index":_index(oid),"mode":mode,"artifact":{"path":result.path,"sha256":result.sha256,"signature":result.signature},"key":_key(),"name":name_input.text}
	temporal.durable.remember_path(result.path)
	for field in ["ray","camera","occlusion","occluders"]:
		if pick.has(field):args[field] = pick[field]
	pending_edit = "new";_request("inspect_derived",args)

func _exit_tree() -> void:
	jobs.shutdown()
