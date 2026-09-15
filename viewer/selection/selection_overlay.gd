extends Node3D
# Bounded, separate display geometry. Never writes particle buffers or channels.
const Exact = preload("res://scene/source_sampling.gd")
var layers := {}
var points := {}
var gpu_bytes := 0
var drawn := 0
var marker_radius := .2

static func position(values: Array) -> Vector3:
	return Vector3(Exact.exact_float(values[0]).value,Exact.exact_float(values[1]).value,Exact.exact_float(values[2]).value)

func clear() -> void:
	for child in get_children():remove_child(child);child.queue_free()
	layers.clear();points.clear();gpu_bytes = 0;drawn = 0

func publish(results: Array, state, budget: int) -> bool:
	var count := 0
	for result in results:count += result.preview.size()
	# Fixed low-poly spheres + MultiMesh transforms/colors, with conservative overhead.
	var charge := count*128+results.size()*4096
	if charge > mini(budget,16*1048576):clear();return false
	clear();gpu_bytes = charge
	for result in results:
		var definition: Dictionary = state.find(result.key)
		if definition.is_empty():continue
		var mesh := SphereMesh.new();mesh.radius = marker_radius;mesh.height = marker_radius*2
		mesh.radial_segments = 8;mesh.rings = 4
		var mat := StandardMaterial3D.new();mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var color: Array = definition.display.color
		mat.albedo_color = Color(color[0],color[1],color[2],1);mesh.material = mat
		var mm := MultiMesh.new();mm.transform_format = MultiMesh.TRANSFORM_3D;mm.mesh = mesh
		mm.instance_count = result.preview.size()
		var node := MultiMeshInstance3D.new();node.multimesh = mm;add_child(node)
		layers[result.key] = node
		var pairs: Array = []
		for row in result.preview:
			pairs.append([position(row.get("position_a",row.position)),position(row.get("position_b",row.position))])
		points[result.key] = {"pairs":pairs,"result":result,"definition":definition,"display_positions":PackedVector3Array()}
	return true

func update_time(time: float, viewer, state) -> void:
	drawn = 0
	for key in layers:
		var data: Dictionary = points[key]
		var d: Dictionary = state.find(key)
		if d.is_empty():layers[key].visible = false;continue
		var layer_visible: bool = viewer.particle_layer_visible
		if viewer.scene_layers != null and viewer.scene_layers.states.has(d.object):layer_visible = viewer.scene_layers.states[d.object].visible
		if d.kind == "derived_surface":layer_visible = viewer.selection_controller._definition_visible(d)
		var visible: bool = state.overlay.visible and d.display.visible and (layer_visible or state.overlay.show_hidden)
		layers[key].visible = visible
		if not visible:continue
		var sample: Dictionary = data.result.sampling
		var source_times: Array = sample.get("source_times",[])
		var alpha := 0.0
		if source_times.size() == 2:
			var a: float = Exact.exact_float(source_times[0]).value
			var b: float = Exact.exact_float(source_times[1]).value
			if b > a:alpha = clampf((time-a)/(b-a),0,1)
		var particle: bool = viewer.scene_layers == null or d.object == viewer.scene_layers.particle_id
		var displayed := PackedVector3Array();displayed.resize(data.pairs.size())
		# Visible marker size is an overlay convention, never a source radius.
		var scale_factor: float = maxf(1.,viewer.camera_distance*.003/marker_radius)
		for i in range(data.pairs.size()):
			var p: Vector3 = data.pairs[i][0].lerp(data.pairs[i][1],alpha)
			displayed[i] = p
			var show := true
			if not state.overlay.show_hidden and particle and viewer.slice_enabled:show = absf(p.x-viewer.slice_x*viewer.half_extent) <= 3
			if not state.overlay.show_hidden and viewer.scene_layers != null and viewer.scene_layers.states.has(d.object):
				var visual: Dictionary = viewer.scene_layers.states[d.object]
				if visual.get("clip",false):show = p.dot(Vector3(visual.clip_normal[0],visual.clip_normal[1],visual.clip_normal[2])) <= visual.clip_distance
			layers[key].multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*scale_factor if show else Vector3.ZERO),p))
			if show:drawn += 1
		data.display_positions = displayed
