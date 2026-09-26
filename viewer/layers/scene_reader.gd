extends RefCounted
const Stamp = preload("res://data/source_stamp.gd")
const Index = preload("res://data/capture_index.gd")
const Hash = preload("res://data/capture_index.gd")
const Codec = preload("res://data/typed_decode.gd")
const Cache = preload("res://data/byte_cache.gd")
const Identity = preload("res://data/particle_identity.gd")
const Profile = preload("res://scene/playback_profile.gd")
const MAX_SAMPLE := 256*1024*1024
var file: FileAccess
var source_path := ""
var source_stamp := {}
var header := {}
var metadata := {}
var objects := {}
var samples := {}
var observed_arrays := {}
var records: Array[Dictionary] = []
var frames: Array[Dictionary] = [] # union clock; never scientific particle samples
var cache := Cache.new()
var cache_dir := ""
var format := "SIMSCP3"
var generation := 0
var scan_offset := 0
var trusted := false
var error := ""
var index_valid := false
var index_state := ""
var last_index_ms := 0.0
func stopped() -> bool: return false
static func transform_of(value: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(value[0],value[4],value[8]),Vector3(value[1],value[5],value[9]),Vector3(value[2],value[6],value[10])),Vector3(value[3],value[7],value[11]))
static func vec(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func fail(message: String) -> bool:
	error = message;return false
func close() -> void:
	file = null;cache.clear()
func configure_cache(bytes: int, _prefetch: bool) -> void: cache.configure(bytes)
func status() -> String: return "Synchronous layer reads • %s • %.1f / %.0f MiB • %d hits • last index %.0f ms" % [index_state,cache.used/1048576.0,cache.limit/1048576.0,cache.hits,last_index_ms]
func open(path: String) -> bool:
	source_path = ProjectSettings.globalize_path(path).simplify_path()
	trusted = Stamp.supported(source_path)
	cache_dir = ProjectSettings.globalize_path("res://../.simscope-cache")
	return reload_source()
func refresh() -> bool:
	var started := Profile.begin()
	var previous_generation := generation
	var result := _refresh_profiled()
	Profile.end("g3_reader_refresh",started,{"generation_before":previous_generation,"generation_after":generation,"ok":result})
	return result
func _source_stamp_profiled() -> Dictionary:
	var started := Profile.begin()
	var result := Stamp.read(source_path)
	Profile.end("g3_source_stamp",started)
	return result
func _refresh_profiled() -> bool:
	if file == null: return fail("Scene is closed.")
	if trusted and _source_stamp_profiled() == source_stamp: return index_valid
	return reload_source()
func reload_source() -> bool:
	var wall_started := Time.get_ticks_usec()
	var started := Profile.begin()
	var result := _reload_source_profiled()
	last_index_ms = (Time.get_ticks_usec()-wall_started)/1000.0
	Profile.end("g3_reload_source",started)
	return result
func _reload_source_profiled() -> bool:
	index_valid = false;generation += 1;cache.clear();records.clear();frames.clear();samples.clear();observed_arrays.clear();objects.clear();error = ""
	var metadata_started := Profile.begin()
	var before := _source_stamp_profiled()
	file = FileAccess.open(source_path,FileAccess.READ)
	if file == null or file.get_length() < 16: return fail("Incomplete scene prefix.")
	var prefix := file.get_buffer(16);var size := prefix.decode_u32(12)
	if prefix.slice(0,8) != "SIMSCP3".to_utf8_buffer()+PackedByteArray([0]) or prefix.decode_u32(8) != 3 or size > 1048576 or size > file.get_length()-16: return fail("Unsupported scene version/header.")
	var raw := file.get_buffer(size);var parsed = Hash.parse_json(raw.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("version") != 3 or not Index.valid_hex(parsed.get("uuid"),32) or not parsed.get("objects") is Array or parsed.objects.is_empty() or parsed.objects.size() > 16: return fail("Invalid scene metadata/object table.")
	metadata = parsed
	var pattern := RegEx.new();pattern.compile("^[a-z][a-z0-9_]*$")
	var particle_objects := 0
	for obj in metadata.objects:
		if not obj is Dictionary or not obj.get("id") is String or pattern.search(obj.id) == null or objects.has(obj.id) or obj.get("kind") not in ["particles","mesh","volume"]: return fail("Unknown/duplicate required object.")
		if obj.get("space") != "viewer_world" or not obj.get("units") is String or not obj.get("static") is bool: return fail("Object units/space/static required.")
		var tx = obj.get("data_to_world")
		if not tx is Array or tx.size() != 12: return fail("Affine transform requires 12 values.")
		for v in tx:
			if not (v is float or v is int) or not is_finite(v): return fail("Nonfinite transform.")
		if absf(transform_of(tx).basis.determinant()) < 1e-12: return fail("Singular data transform.")
		if obj.kind == "particles":
			particle_objects += 1
			if obj.get("identity") not in ["anonymous","persistent_i8"] or transform_of(tx) != Transform3D.IDENTITY: return fail("Explicit particle identity and viewer-world positions required.")
		if obj.kind == "mesh" and obj.get("identity") not in ["none","stable_topology"]: return fail("Mesh vertex identity policy required.")
		objects[obj.id] = obj;samples[obj.id] = []
	if particle_objects > 1: return fail("One particle object supported.")
	# Compatibility metadata for particle mapping; UUID remains the actual scene UUID.
	metadata.storage = {"uuid":metadata.uuid}
	prefix.append_array(raw);header = {"sha256":Hash.digest(prefix),"metadata":metadata}
	Profile.end("g3_index_metadata",metadata_started)
	var scan_started := Profile.begin()
	var offset := 16+size;var end := file.get_length();var index_bytes := 0;var times := {}
	while offset < end:
		if end-offset < 80: break
		file.seek(offset);var h := file.get_buffer(80)
		var dlen := h.decode_u32(4);var stored := h.decode_u64(8);var decoded := h.decode_u64(16);var time := h.decode_double(24);var oi := h.decode_u32(32);var n := h.decode_u32(36);var seq := h.decode_u64(40)
		if h.slice(0,4).get_string_from_ascii() != "FRM3" or dlen > 4*1048576 or stored < 0 or stored > MAX_SAMPLE+64*1048576 or decoded < 0 or decoded > MAX_SAMPLE or oi >= metadata.objects.size() or seq != records.size() or seq >= 1000000 or n < 1 or n > 256 or not is_finite(time): return fail("Scene header/allocation ceiling.")
		if 128+dlen+stored > end-offset: break
		index_bytes += 128+dlen
		if index_bytes > Hash.MAX_INDEX: return fail("Scene index metadata exceeds 32 MiB.")
		var obj: Dictionary = metadata.objects[oi];var prior: Array = samples[obj.id]
		if not prior.is_empty() and (obj.static or time <= prior[-1].time): return fail("Object timestamps/static violation.")
		# Only fixed-size headers are needed to locate records and build the clock.
		# Descriptor parsing, proofs and payload checks belong to requested reads.
		var record := {"time":time,"object":obj.id,"offset":offset+80+dlen,"end":offset+128+dlen+stored,"decoded":decoded,"descriptor":{},"sequence":seq,"index":prior.size(),"header_offset":offset,"raw_header":h,"stored":stored,"descriptor_length":dlen,"array_count":n,"kind":obj.kind,"identity":obj.get("identity","")}
		records.append(record);samples[obj.id].append(record);times[time] = true
		offset = record.end
	Profile.end("g3_index_scan_inclusive",scan_started)
	if trusted and _source_stamp_profiled() != before: return fail("Scene changed while indexing.")
	var timestamps_started := Profile.begin()
	var ordered: Array = times.keys();ordered.sort()
	for time in ordered: frames.append({"time":time,"offset":0,"bytes":offset,"end":offset})
	scan_offset = offset;source_stamp = before;index_state = "lazy record index"
	Profile.end("g3_timestamp_index",timestamps_started)
	index_valid = true
	return true
static func record_error(entry: Dictionary, message: String) -> String:
	return "%s sample %d (record %d): %s Reopen or re-export the capture." % [entry.get("object","Scene"),int(entry.get("index",-1)),int(entry.get("sequence",-1)),message]
static func materialize(source: FileAccess, entry: Dictionary, obj: Dictionary) -> Dictionary:
	if not entry.descriptor.is_empty():return entry
	if source == null:return {"error":record_error(entry,"Cannot open source.")}
	# Header bounds were checked at index construction; check again on this handle.
	if entry.header_offset < 16 or entry.end > source.get_length() or entry.offset < entry.header_offset+80:return {"error":record_error(entry,"Record outside source bounds.")}
	source.seek(entry.header_offset)
	var h := source.get_buffer(80)
	if h != entry.raw_header:return {"error":record_error(entry,"Record header changed.")}
	var d := source.get_buffer(entry.descriptor_length)
	if Hash.digest(d) != h.slice(48).hex_encode():return {"error":record_error(entry,"Descriptor checksum mismatch.")}
	var desc = Hash.parse_json(d.get_string_from_utf8())
	var problem := validate_sample(obj,desc,entry.stored,entry.decoded)
	if not problem.is_empty():return {"error":record_error(entry,problem)}
	if desc.arrays.size() != entry.array_count:return {"error":record_error(entry,"Array count mismatch.")}
	source.seek(entry.end-48);var trailer := source.get_buffer(48);var proof := h.duplicate();proof.append_array(d)
	if trailer.slice(0,8) != "COMMIT3".to_utf8_buffer()+PackedByteArray([0]) or trailer.decode_u64(8) != entry.sequence or trailer.slice(16).hex_encode() != Hash.digest(proof):return {"error":record_error(entry,"Commit checksum mismatch.")}
	var result := entry.duplicate();result.descriptor = desc
	return result
func describe(id: String, index: int) -> Dictionary:
	if not samples.has(id) or index < 0 or index >= samples[id].size():return {}
	var entry: Dictionary = samples[id][index]
	var started := Profile.begin()
	var result := materialize(file,entry,objects[id])
	Profile.end("g3_requested_descriptor",started)
	if result.has("error"):fail(result.error);return {}
	entry.descriptor = result.descriptor
	return entry.descriptor
func known_arrays(id: String) -> Array:
	var result: Array = [];var names := {}
	for a in observed_arrays.get(id,{}).values():names[a.name] = true;result.append(a)
	for entry in samples.get(id,[]):
		for a in entry.descriptor.get("arrays",[]):
			if not names.has(a.name):names[a.name] = true;result.append(a)
	return result
func note_channels(id: String, data: Dictionary) -> void:
	if not observed_arrays.has(id):observed_arrays[id] = {}
	for name in data.channels:
		observed_arrays[id][name] = {"name":name,"shape":data.shapes[name].duplicate()}
static func dimensions_equal(a, b) -> bool:
	if not a is Array or not b is Array or a.size() != b.size(): return false
	for i in range(a.size()):
		if not Index.whole(a[i]) or int(a[i]) != int(b[i]): return false
	return true
static func validate_sample(obj: Dictionary, desc, stored: int, decoded: int) -> String:
	if not desc is Dictionary or not desc.get("arrays") is Array or desc.arrays.is_empty() or desc.arrays.size() > 256 or not desc.get("geometry") is Dictionary: return "Invalid array/geometry table."
	var specs := {};var offset := 0;var total := 0
	var pattern := RegEx.new();pattern.compile("^[a-z][a-z0-9_]*$")
	for a in desc.arrays:
		if not a is Dictionary or not a.get("name") is String or pattern.search(a.name) == null or specs.has(a.name) or not Index.TYPES.has(a.get("dtype")): return "Unknown required array/dtype."
		if not a.get("shape") is Array or a.shape.is_empty() or a.shape.size() > 3 or not a.get("association") is String: return "Invalid shape/association."
		var bytes: int = Index.TYPES[a.dtype]
		for dim in a.shape:
			if not Index.whole(dim) or dim > 10000000 or (dim > 0 and bytes > MAX_SAMPLE/int(dim)): return "Shape allocation ceiling."
			bytes *= int(dim)
		total += bytes
		if total > MAX_SAMPLE: return "Sample allocation ceiling."
		if not a.get("chunks") is Array or a.chunks.size() > 4096: return "Chunk table ceiling."
		var expected: Array = []
		if obj.kind == "volume":
			if a.shape.size() != 3: return "Grid requires zyx shape."
			for dim in a.shape:
				if dim < 2 or dim > 512: return "Grid dimension ceiling."
			for z in range(0,int(a.shape[0]),32):
				for y in range(0,int(a.shape[1]),32):
					for x in range(0,int(a.shape[2]),32): expected.append({"origin":[z,y,x],"shape":[mini(32,int(a.shape[0])-z),mini(32,int(a.shape[1])-y),mini(32,int(a.shape[2])-x)]})
			if a.chunks.size() != expected.size(): return "Brick coverage mismatch."
		var length := 0
		for i in range(a.chunks.size()):
			var p = a.chunks[i]
			if not p is Dictionary: return "Invalid chunk."
			var off := Index.decimal(p.get("offset"));var s := Index.decimal(p.get("stored"));var d := Index.decimal(p.get("decoded"))
			if off != offset or d <= 0 or d > Index.MAX_CHUNK or s <= 0 or s > d+65536 or not Index.whole(p.get("codec")) or int(p.codec) not in [0,1]: return "Chunk bounds/codec."
			if p.codec == 0 and s != d: return "None size mismatch."
			if not Index.valid_hex(p.get("raw_sha256"),64) or not Index.valid_hex(p.get("stored_sha256"),64): return "Missing chunk checksum."
			if not expected.is_empty():
				var e: Dictionary = expected[i]
				if not dimensions_equal(p.get("origin"),e.origin) or not dimensions_equal(p.get("shape"),e.shape) or d != e.shape[0]*e.shape[1]*e.shape[2]*int(Index.TYPES[a.dtype]): return "Invalid brick shape/coverage."
			offset += s;length += d
		if bytes != length: return "Decoded array length mismatch."
		specs[a.name] = a
	if offset != stored or total != decoded: return "Byte totals mismatch."
	var g: Dictionary = desc.geometry
	if obj.kind == "volume":
		if not g.get("shape") is Array or not g.get("origin") is Array or not g.get("spacing") is Array or g.origin.size() != 3 or g.spacing.size() != 3 or g.get("centering") not in ["node","cell"]: return "Grid geometry missing."
		for i in range(3):
			if not (g.origin[i] is float or g.origin[i] is int) or not is_finite(g.origin[i]) or not (g.spacing[i] is float or g.spacing[i] is int) or not is_finite(g.spacing[i]) or g.spacing[i] <= 0: return "Invalid grid origin/spacing."
		for a in desc.arrays:
			if a.shape != g.shape or a.dtype not in ["f4","f8"] or a.association != "sample": return "Grid scalar/geometry mismatch."
	else:
		if not specs.has("position"): return "Missing positions."
		var p: Dictionary = specs.position
		if p.dtype not in ["f4","f8"] or p.shape.size() != 2 or p.shape[1] != 3 or p.association != "vertex": return "Float xyz vertices required."
		var n: int = p.shape[0]
		if obj.kind == "mesh":
			if not specs.has("triangles"): return "Missing triangle topology."
			var t: Dictionary = specs.triangles
			if t.dtype != "u4" or t.shape.size() != 2 or t.shape[1] != 3 or t.association != "topology" or t.shape[0] > 2000000 or n > 1000000: return "Invalid/oversized topology."
			if specs.has("vertex_id") != (obj.identity == "stable_topology"):return "Stable topology requires explicit vertex_id."
			if specs.has("vertex_id") and (specs.vertex_id.dtype != "i8" or not dimensions_equal(specs.vertex_id.shape,[n])):return "Exact vertex IDs required."
			if specs.has("normal") and (specs.normal.dtype not in ["f4","f8"] or not dimensions_equal(specs.normal.shape,[n,3])):return "Invalid vertex normals."
			for a in desc.arrays:
				if a.name in ["position","triangles"]: continue
				if a.association not in ["vertex","face"] or a.shape[0] != (n if a.association == "vertex" else t.shape[0]): return "Mesh association mismatch."
		else:
			if n > 10000000 or specs.has("particle_id") != (obj.identity == "persistent_i8"): return "Particle identity/shape mismatch."
			for a in desc.arrays:
				if a.shape[0] != n or a.association != "vertex": return "Particle array shape mismatch."
			if specs.has("particle_id") and (specs.particle_id.dtype != "i8" or not dimensions_equal(specs.particle_id.shape,[n]) or n > 1000000): return "Exact int64 identities required."
	return ""
func bracket(id: String, time: float) -> Dictionary:
	return preload("res://scene/source_sampling.gd").bracket(samples[id],time,objects[id].static)
func read_sample(id: String, index: int) -> Dictionary:
	var started := Profile.begin()
	var result := _read_sample_profiled(id,index)
	Profile.end("g3_read_sample",started,{"object":id,"sample_index":index,"source_time":result.get("time"),"ok":not result.is_empty()})
	return result
func _read_sample_profiled(id: String, index: int) -> Dictionary:
	if not refresh() or not samples.has(id) or index < 0 or index >= samples[id].size(): fail("Sample unavailable.");return {}
	var cache_started := Profile.begin()
	var entry: Dictionary = samples[id][index];var hit := cache.get_frame(entry.sequence) if trusted else {}
	Profile.end("g3_cache_lookup",cache_started,{"hit":not hit.is_empty(),"object":id,"sample_index":index})
	if not hit.is_empty(): return hit
	if describe(id,index).is_empty():return {}
	Profile.count("g3_sample_cache_misses")
	var decode_started := Profile.begin()
	var decoded := preload("res://layers/scene_channels.gd").read(file,entry,objects[id])
	if decoded.has("error") or decoded.is_empty():fail(record_error(entry,decoded.get("error","Scene decode cancelled.")));return {}
	var channels: Dictionary = decoded.channels;var components: Dictionary = decoded.components;var shapes: Dictionary = decoded.shapes;var associations: Dictionary = decoded.associations;var reserve: int = decoded.reserve
	Profile.end("g3_channel_decode",decode_started,{"object":id,"sample_index":index,"decoded_bytes":entry.decoded})
	var count: int = int(shapes.position[0]) if objects[id].kind != "volume" and shapes.has("position") else 0;var has_ids: bool = objects[id].kind == "particles" and channels.has("particle_id");var map
	if has_ids:
		var identity_started := Profile.begin()
		var result := Identity.build(channels.particle_id,self)
		Profile.end("g3_identity_build",identity_started,{"particles":count})
		if result.is_empty() or result.has("error"): fail(record_error(entry,result.get("error","ID decode failed.")));return {}
		map = result.map;reserve += count*160
	if objects[id].kind == "mesh" and channels.has("vertex_id"):
		var vertex_ids := Identity.build(channels.vertex_id,self)
		if vertex_ids.is_empty() or vertex_ids.has("error"):fail(record_error(entry,"Invalid vertex IDs."));return {}
	if objects[id].kind == "mesh" and channels.has("triangles"):
		for i in channels.triangles:
			if i < 0 or i >= count: fail(record_error(entry,"Triangle index outside vertices."));return {}
	var data := {"time":entry.time,"count":count,"channels":channels,"components":components,"shapes":shapes,"associations":associations,"geometry":entry.descriptor.geometry,"has_ids":has_ids,"identity_map":map,"source_index":index,"sequence":entry.sequence,"decoded_bytes":reserve}
	if trusted and _source_stamp_profiled() != source_stamp: fail("Source changed during sample decode.");return {}
	var publish_started := Profile.begin()
	if trusted: cache.put(entry.sequence,data,reserve)
	var result := data.duplicate(true)
	Profile.end("g3_cache_publish",publish_started)
	return result

func pin_extent(extent: int) -> bool:
	if extent > scan_offset or extent < 16:return false
	var retained: Array[Dictionary] = []
	for row in records:
		if row.end <= extent:retained.append(row)
	if retained.is_empty() or retained[-1].end != extent:return false
	records = retained;frames.clear()
	for id in samples:samples[id] = []
	var times := {}
	for row in records:samples[row.object].append(row);times[row.time] = true
	var ordered: Array = times.keys();ordered.sort()
	for time in ordered:frames.append({"time":time,"offset":0,"bytes":extent,"end":extent})
	scan_offset = extent;cache.clear();return true
