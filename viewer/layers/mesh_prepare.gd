extends RefCounted
# Pure CPU preparation shared by deterministic sampling and the mesh worker.
const Reader = preload("res://layers/scene_reader.gd")
const Sampling = preload("res://scene/source_sampling.gd")
static func prepare(obj: Dictionary, a: Dictionary, b: Dictionary, alpha: float, state: Dictionary, budget: int, colors: Array, cancel = null) -> Dictionary:
	var interpolate: bool = Sampling.mesh_compatible(obj,a,b) and a.sequence != b.sequence
	var status := "interpolated" if interpolate and alpha > 0 else "held"
	var count: int = a.count;var indices: PackedInt32Array = a.channels.triangles
	if count == 0 or indices.is_empty():return {"empty":true,"status":status,"gpu_bytes":0}
	var channel: String = state.channel
	var face_values: bool = not channel.is_empty() and a.associations.get(channel) == "face"
	var estimate := (indices.size() if face_values else count)*40+indices.size()*(8 if state.wireframe else 4)
	if estimate > budget: return {"error":"Mesh GPU budget exceeded; preview released."}
	var p := PackedVector3Array();p.resize(count)
	var values = a.channels.position;var next = b.channels.position
	for i in range(count):
		if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
		p[i] = Vector3(values[i*3],values[i*3+1],values[i*3+2])
		if interpolate: p[i] = p[i].lerp(Vector3(next[i*3],next[i*3+1],next[i*3+2]),alpha)
		if not p[i].is_finite(): return {"error":"Mesh coordinate outside display range."}
	var normals := PackedVector3Array();normals.resize(count)
	for i in range(0,indices.size(),3):
		if i % 4095 == 0 and cancel != null and cancel.stopped():return {}
		var normal := (p[indices[i+1]]-p[indices[i]]).cross(p[indices[i+2]]-p[indices[i]])
		for j in range(3): normals[indices[i+j]] += normal
	for i in range(count):
		if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
		if a.channels.has("normal") and not (interpolate and alpha > 0):
			var supplied = a.channels.normal
			normals[i] = Vector3(supplied[i*3],supplied[i*3+1],supplied[i*3+2])
			if not normals[i].is_finite() or normals[i].length_squared() < 1e-20:return {"error":"Invalid vertex normal."}
		normals[i] = normals[i].normalized()
	var source_positions := p;var normal_values := normals
	var vertex_colors := PackedColorArray();vertex_colors.resize(count)
	for i in range(count):
		if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
		vertex_colors[i] = Color(.25,.65,.85)
	if not channel.is_empty() and not face_values and a.channels.has(channel):
		for i in range(count):
			if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
			vertex_colors[i] = scalar_color(a.channels[channel][i],state,colors)
	if face_values:
		var expanded := PackedVector3Array();var expanded_normals := PackedVector3Array();var expanded_colors := PackedColorArray()
		for i in range(indices.size()):
			if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
			expanded.append(p[indices[i]]);expanded_normals.append(normals[indices[i]]);expanded_colors.append(scalar_color(a.channels[channel][i/3],state,colors))
		p = expanded;normals = expanded_normals;vertex_colors = expanded_colors;indices = PackedInt32Array()
		indices.resize(p.size())
		for i in range(p.size()):
			if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
			indices[i] = i
	# Stored CCW outward topology -> Godot's clockwise front-face convention.
	indices = indices.duplicate()
	if Reader.transform_of(obj.data_to_world).basis.determinant() > 0:
		for i in range(0,indices.size(),3):
			if i % 4095 == 0 and cancel != null and cancel.stopped():return {}
			var swap := indices[i+1];indices[i+1] = indices[i+2];indices[i+2] = swap
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX] = p;arrays[Mesh.ARRAY_NORMAL] = normals;arrays[Mesh.ARRAY_COLOR] = vertex_colors;arrays[Mesh.ARRAY_INDEX] = indices
	var primitive := Mesh.PRIMITIVE_TRIANGLES
	if state.wireframe:
		var lines := PackedInt32Array()
		for i in range(0,indices.size(),3):
			if i % 4095 == 0 and cancel != null and cancel.stopped():return {}
			lines.append_array(PackedInt32Array([indices[i],indices[i+1],indices[i+1],indices[i+2],indices[i+2],indices[i]]))
		arrays[Mesh.ARRAY_INDEX] = lines;primitive = Mesh.PRIMITIVE_LINES
	return {"arrays":arrays,"primitive":primitive,"gpu_bytes":estimate,"source_positions":source_positions,"normal_values":normal_values,"status":status,"transform":Reader.transform_of(obj.data_to_world)}
static func scalar_color(value: float, state: Dictionary, colors: Array) -> Color:
	if not is_finite(value): return Color(.25,.25,.25)
	var t := clampf((value-float(state.lower))/maxf(1e-300,float(state.upper)-float(state.lower)),0,1)
	var c: Array = colors[roundi(t*255)]
	return Color(c[0],c[1],c[2])

static func pair(obj: Dictionary, a: Dictionary, b: Dictionary, state: Dictionary, budget: int, colors: Array, cancel = null) -> Dictionary:
	var result := prepare(obj,a,a,0.0,state,budget,colors,cancel)
	if result.is_empty() or result.has("error"):return result
	result.a = a;result.b = b;result.interpolate = Sampling.mesh_compatible(obj,a,b) and a.sequence != b.sequence
	if result.get("empty",false) or not result.interpolate:return result
	var p: PackedVector3Array = result.source_positions
	var next := PackedVector3Array();next.resize(p.size())
	var low := Vector3(INF,INF,INF);var high := Vector3(-INF,-INF,-INF)
	for i in range(p.size()):
		if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
		next[i] = Vector3(b.channels.position[i*3],b.channels.position[i*3+1],b.channels.position[i*3+2])
		if not next[i].is_finite() or not (next[i]-p[i]).is_finite():return {"error":"Mesh coordinate outside display range."}
		low = low.min(p[i]).min(next[i]);high = high.max(p[i]).max(next[i])
	var rendered: PackedVector3Array = result.arrays[Mesh.ARRAY_VERTEX]
	# Reserve morph input, backend ping-pong/output buffers and motion-vector slack
	# in addition to the base attributes/indices. This is a quota charge, not VRAM telemetry.
	result.gpu_bytes += rendered.size()*128
	if result.gpu_bytes > budget:return {"error":"Mesh GPU budget exceeded; preview released."}
	var delta := PackedVector3Array();delta.resize(rendered.size())
	var face_values: bool = not state.channel.is_empty() and a.associations.get(state.channel) == "face"
	for i in range(delta.size()):
		if i % 4096 == 0 and cancel != null and cancel.stopped():return {}
		var row: int = a.channels.triangles[i] if face_values else i
		delta[i] = next[row]-p[row]
	var blend := [];blend.resize(Mesh.ARRAY_MAX);blend[Mesh.ARRAY_VERTEX] = delta
	var unchanged_normals := PackedVector3Array();unchanged_normals.resize(delta.size());blend[Mesh.ARRAY_NORMAL] = unchanged_normals
	# Rendering remains unshaded. Inspection recomputes exact deformed normals on demand.
	result.blend = blend;result.next_positions = next;result.bounds = AABB(low,high-low)
	return result
