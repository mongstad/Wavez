extends Node3D
# Carry only the already resolved, bounded marker subset. No definitions,
# membership evaluation, scientific results, recipes or worker requests.
const Reader = preload("res://layers/scene_reader.gd")
const Sampling = preload("res://scene/source_sampling.gd")
const MAX_MARKERS := 512
var markers: Array = []
var nodes: Array[MultiMeshInstance3D] = []
var positions: Array = []

static func snapshot(viewer) -> Array:
	var result: Array = []
	var control = viewer.selection_controller
	if control == null or not control.overlay.visible: return result
	for key in control.overlay.points:
		if not control.overlay.layers[key].visible: continue
		var data: Dictionary = control.overlay.points[key]
		var definition: Dictionary = data.definition
		var object: String = definition.object
		var sample: Dictionary = viewer.scene_layers.current.get(object,{}).get("a",{})
		if sample.is_empty() and viewer.generic_reader.objects[object].kind != "particles":
			# Show hidden selection can draw an overlay over an unloaded layer.
			# Use the ordinary reader's admitted native sample, never an analysis job.
			sample = viewer.generic_reader.read_sample(object,int(data.result.sampling.get("a",-1)))
		for i in data.result.preview.size():
			if result.size() >= MAX_MARKERS: return result
			var row: Dictionary = data.result.preview[i]
			var marker := {"object":object,"color":definition.display.color.duplicate(),"show_hidden":control.state.overlay.show_hidden,
				"kind":viewer.generic_reader.objects[object].kind,"index":int(data.result.sampling.get("a",-1)),"row":int(row.get("row",-1))}
			if definition.kind == "probe":
				marker.kind = "location"; marker.position = preload("res://scene/visual_state.gd").vec(data.display_positions[i])
			elif definition.kind == "derived_surface":
				marker.kind = "artifact"; marker.position = preload("res://scene/visual_state.gd").vec(data.display_positions[i]); marker.artifact = definition.selector.artifact_sha256
			elif marker.kind == "volume":
				if sample.is_empty(): continue
				var shape: Array = sample.geometry.shape
				marker.xyz = [marker.row % int(shape[2]), (marker.row / int(shape[2])) % int(shape[1]), marker.row / (int(shape[2])*int(shape[1]))]
			elif marker.kind == "mesh" and definition.association == "face":
				if sample.is_empty(): continue
				marker.kind = "face"
				marker.weights = [1.0/3,1.0/3,1.0/3]
				if definition.kind == "mesh_point":
					marker.weights = definition.selector.barycentric.map(func(v): return Sampling.exact_float(v).value)
			elif row.get("id") is String: marker.id = row.id
			result.append(marker)
	return result

static func validate(value) -> String:
	if not value is Array or value.size() > MAX_MARKERS: return "Invalid presentation marker budget."
	for marker in value:
		if not marker is Dictionary or not marker.get("object") is String or not marker.get("show_hidden") is bool or marker.get("kind") not in ["particles","mesh","face","volume","location","artifact"]: return "Invalid presentation marker."
		if not marker.get("color") is Array or marker.color.size() != 4: return "Invalid marker color."
		for v in marker.color:
			if not (v is float or v is int) or not is_finite(v) or v < 0 or v > 1: return "Invalid marker color."
		for key in ["index","row"]:
			var v = marker.get(key)
			if not (v is float or v is int) or not is_finite(v) or v != floor(v) or v < -1 or v > 2147483647: return "Invalid marker address."
		if marker.has("id") and Sampling.exact_id(marker.id).is_empty(): return "Invalid marker ID."
		for key in ["position","xyz","weights"]:
			if marker.has(key):
				if not marker[key] is Array or marker[key].size() != 3: return "Invalid marker vector."
				for v in marker[key]:
					if not (v is float or v is int) or not is_finite(v): return "Invalid marker vector."
		if marker.kind in ["location","artifact"] and not marker.has("position"): return "Missing marker location."
		if marker.kind == "artifact" and not marker.get("artifact") is String: return "Missing marker artifact."
		if marker.kind == "volume":
			if not marker.has("xyz"): return "Missing grid marker address."
			for v in marker.xyz:
				if v < 0 or v != floor(v): return "Invalid grid marker address."
		if marker.kind == "face":
			if not marker.has("weights"): return "Missing face marker weights."
			for v in marker.weights:
				if v < 0 or v > 1: return "Invalid face marker weights."
			if absf(marker.weights[0]+marker.weights[1]+marker.weights[2]-1) > 1e-6: return "Invalid face marker weights."
	return ""

func setup(value: Array) -> void:
	markers = value.duplicate(true)
	for marker in markers:
		var sphere := SphereMesh.new(); sphere.radius = .2; sphere.height = .4; sphere.radial_segments = 8; sphere.rings = 4
		var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(marker.color[0],marker.color[1],marker.color[2],1); sphere.material = material
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = sphere; mm.instance_count = 1
		var node := MultiMeshInstance3D.new(); node.multimesh = mm; add_child(node); nodes.append(node)

func update(viewer) -> void:
	positions.clear()
	for i in markers.size():
		var point := locate(markers[i],viewer)
		positions.append(point.get("position")); nodes[i].visible = not point.is_empty()
		if point.is_empty(): continue
		var scale_factor: float = maxf(1.,viewer.camera_distance*.003/.2)
		nodes[i].multimesh.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*scale_factor),point.position))

static func locate(marker: Dictionary, viewer) -> Dictionary:
	var layers = viewer.scene_layers
	if layers == null or not viewer.generic_reader.objects.has(marker.object): return {}
	var object: Dictionary = viewer.generic_reader.objects[marker.object]
	var particle: bool = object.kind == "particles"
	var visible: bool = viewer.particle_layer_visible if particle else layers.states[marker.object].visible
	if not marker.show_hidden and not visible: return {}
	var position: Vector3
	if marker.kind in ["location","artifact"]:
		if marker.kind == "artifact" and (layers.iso_result.get("sha256","") != marker.artifact or not is_instance_valid(layers.iso_node) or not layers.iso_node.visible): return {}
		position = Vector3(marker.position[0],marker.position[1],marker.position[2])
	elif particle:
		if not layers.ensure_particle_data(): return {}
		var frame = viewer.frame_a
		var row: int = int(frame.identity_map.rows.get(int(marker.id),-1)) if marker.has("id") and frame.has_ids else (-1 if marker.has("id") or frame.source_index != int(marker.index) else int(marker.row))
		if row < 0 or row >= frame.positions.size(): return {}
		if not marker.show_hidden and (viewer.current_buffer.size() <= row*16+15 or viewer.current_buffer[row*16+15] <= 0 or viewer.current_sizes[row] <= 0): return {}
		position = frame.positions[row]
		var next = viewer.frame_b
		if frame.has_ids and next != null and next.has_ids:
			viewer._prepare_identity_pair(next)
			if viewer.identity_matches[row] >= 0:
				var bracket: Dictionary = viewer.generic_reader.bracket(marker.object,viewer.requested_time)
				position = position.lerp(next.positions[viewer.identity_matches[row]],float(bracket.get("alpha",0)))
	else:
		var sample: Dictionary = layers.current.get(marker.object,{}).get("a",{})
		var bracket: Dictionary = viewer.generic_reader.bracket(marker.object,viewer.requested_time)
		if bracket.is_empty(): return {}
		if sample.is_empty() and marker.show_hidden: sample = viewer.generic_reader.read_sample(marker.object,int(bracket.a))
		if sample.is_empty(): return {}
		if marker.kind == "volume":
			# Native grid addresses are sample-scoped, never temporal identities.
			if sample.source_index != int(marker.index): return {}
			var xyz := Vector3(marker.xyz[0],marker.xyz[1],marker.xyz[2])
			var g: Dictionary = sample.geometry
			if xyz.x >= g.shape[2] or xyz.y >= g.shape[1] or xyz.z >= g.shape[0]: return {}
			var center := 0.5 if g.centering == "cell" else 0.0
			position = Vector3(g.origin[0],g.origin[1],g.origin[2]) + (xyz+Vector3.ONE*center)*Vector3(g.spacing[0],g.spacing[1],g.spacing[2])
		else:
			var mesh = layers.views.get(marker.object)
			var row: int = int(marker.row)
			var vertices: Array = []
			var weights: Array = []
			if marker.kind == "face":
				var triangles: PackedInt32Array = sample.channels.triangles
				if row < 0 or row*3+2 >= triangles.size(): return {}
				if sample.source_index != int(marker.index): return {}
				for j in 3: vertices.append(triangles[row*3+j])
				weights = marker.weights
			else:
				if marker.has("id"):
					if not sample.channels.has("vertex_id"): return {}
					row = sample.channels.vertex_id.find(int(marker.id))
				elif sample.source_index != int(marker.index): return {}
				if row < 0 or row >= sample.count: return {}
				vertices = [row]; weights = [1.0]
			position = Vector3.ZERO
			if mesh != null and not mesh.data.is_empty():
				var points: PackedVector3Array = mesh.source_positions
				for j in vertices.size(): position += points[vertices[j]]*weights[j]
			else:
				# Hidden mesh previews use the same native topology/interpolation rule,
				# converting only the carried display vertices instead of a new mesh.
				var next: Dictionary = viewer.generic_reader.read_sample(marker.object,int(bracket.b))
				var interpolate := not next.is_empty() and Sampling.mesh_compatible(object,sample,next)
				for j in vertices.size():
					var offset: int = vertices[j]*3
					var p := Vector3(sample.channels.position[offset],sample.channels.position[offset+1],sample.channels.position[offset+2])
					if interpolate: p = p.lerp(Vector3(next.channels.position[offset],next.channels.position[offset+1],next.channels.position[offset+2]),float(bracket.alpha))
					position += p*weights[j]
		position = Reader.transform_of(object.data_to_world)*position
	if not position.is_finite(): return {}
	if not marker.show_hidden:
		if particle and viewer.slice_enabled and absf(position.x-viewer.slice_x*viewer.half_extent) > 3: return {}
		if layers.states.has(marker.object):
			var visual: Dictionary = layers.states[marker.object]
			if visual.get("clip",false) and position.dot(Vector3(visual.clip_normal[0],visual.clip_normal[1],visual.clip_normal[2])) > visual.clip_distance: return {}
	return {"position":position}
