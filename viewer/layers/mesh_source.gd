extends RefCounted
## Immutable endpoint preparation; no shared file cursor, scene tree or GPU calls.
const Reader = preload("res://layers/scene_reader.gd")
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/mesh_prepare.gd")
const Identity = preload("res://data/particle_identity.gd")
static func decode(file: FileAccess, entry: Dictionary, obj: Dictionary, cancel, prior: Dictionary) -> Dictionary:
	var tick := Time.get_ticks_usec();var stages := {}
	entry = Reader.materialize(file,entry,obj)
	tick = Prepare.stage(stages,"descriptor_commit_validation",tick)
	if entry.has("error"):return entry
	var decoded := Channels.read(file,entry,obj,cancel,false)
	if decoded.has("error"):return {"error":Reader.record_error(entry,decoded.error)}
	if decoded.is_empty():return {}
	stages.merge(decoded.timings);tick = Time.get_ticks_usec()
	var count: int = int(decoded.shapes.position[0])
	var ids: PackedInt64Array = decoded.channels.get("vertex_id",PackedInt64Array())
	var triangles: PackedInt32Array = decoded.channels.triangles
	# Exact packed-array equality proves reuse; a declared identity alone does not.
	var reuse: bool = obj.identity == "stable_topology" and not prior.is_empty() and prior.count == count and prior.ids == ids and prior.triangles == triangles
	tick = Prepare.stage(stages,"topology_comparison",tick)
	var topology := prior if reuse else {}
	if not reuse:
		if decoded.channels.has("vertex_id"):
			var checked := Identity.build(ids,cancel)
			if checked.is_empty():return {}
			if checked.has("error"):return {"error":Reader.record_error(entry,"Invalid vertex IDs.")}
		tick = Prepare.stage(stages,"stable_id_validation",tick)
		for i in range(triangles.size()):
			if i % 4096 == 0 and cancel.stopped():return {}
			if triangles[i] < 0 or triangles[i] >= count:return {"error":Reader.record_error(entry,"Triangle index outside vertices.")}
		tick = Prepare.stage(stages,"topology_validation",tick)
		var indices := triangles.duplicate()
		if Reader.transform_of(obj.data_to_world).basis.determinant() > 0:
			for i in range(0,indices.size(),3):
				if i % 4095 == 0 and cancel.stopped():return {}
				var swap := indices[i+1];indices[i+1] = indices[i+2];indices[i+2] = swap
		var lines := PackedInt32Array();lines.resize(indices.size()*2)
		for i in range(0,indices.size(),3):
			if i % 4095 == 0 and cancel.stopped():return {}
			var j := i*2
			lines[j] = indices[i];lines[j+1] = indices[i+1];lines[j+2] = indices[i+1]
			lines[j+3] = indices[i+2];lines[j+4] = indices[i+2];lines[j+5] = indices[i]
		topology = {"count":count,"ids":ids,"triangles":triangles,"indices":indices,"lines":lines}
		topology.make_read_only()
		Prepare.stage(stages,"index_packing",tick)
	var sample := {"time":entry.time,"count":count,"channels":decoded.channels,"components":decoded.components,"shapes":decoded.shapes,"associations":decoded.associations,"geometry":entry.descriptor.geometry,"has_ids":false,"identity_map":null,"source_index":entry.index,"sequence":entry.sequence,"decoded_bytes":decoded.reserve,"topology":topology}
	var geometry := Prepare.prepare(obj,sample,sample,0.0,{"channel":"","wireframe":false},1<<60,[],cancel,stages,true)
	if geometry.is_empty():return {}
	if geometry.has("error"):
		sample.display_error = geometry.error
		sample.bytes = int(decoded.reserve)+triangles.size()*16+ids.size()*8+16384
		sample.timings = stages;sample.topology_reused = reuse
		return sample
	tick = Time.get_ticks_usec()
	var low := Vector3(INF,INF,INF);var high := Vector3(-INF,-INF,-INF)
	var positions: PackedVector3Array = geometry.get("source_positions",PackedVector3Array())
	for i in range(positions.size()):
		if i % 4096 == 0 and cancel.stopped():return {}
		low = low.min(positions[i]);high = high.max(positions[i])
	Prepare.stage(stages,"endpoint_bounds",tick)
	sample.display = geometry;sample.low = low;sample.high = high
	# Account endpoint-owned geometry plus canonical arrays conservatively per endpoint.
	sample.bytes = int(decoded.reserve)+count*40+triangles.size()*16+ids.size()*8+16384
	sample.timings = stages;sample.topology_reused = reuse
	return sample
