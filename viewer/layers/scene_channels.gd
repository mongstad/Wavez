extends RefCounted
# Shared source-byte decoder. No scene/GPU state or global profiler on workers.
const Index = preload("res://data/capture_index.gd")
const Hash = preload("res://data/capture_index.gd")
const Codec = preload("res://data/typed_decode.gd")
static func read(source_file: FileAccess, entry: Dictionary, obj: Dictionary, cancel = null, verify_payloads := true) -> Dictionary:
	var channels := {};var components := {};var shapes := {};var associations := {};var statistics := {};var reserve: int = entry.decoded+4096
	var timings := {"file_io":0.0,"stored_hash":0.0,"decompress":0.0,"raw_hash":0.0,"assembly":0.0,"typed_conversion":0.0}
	for a in entry.descriptor.arrays:
		var full := PackedByteArray()
		for p in a.chunks:
			if cancel != null and cancel.stopped():return {}
			var tick := Time.get_ticks_usec()
			source_file.seek(entry.offset+Index.decimal(p.offset));var stored := source_file.get_buffer(Index.decimal(p.stored))
			timings.file_io += (Time.get_ticks_usec()-tick)/1000.0;tick = Time.get_ticks_usec()
			if stored.size() != Index.decimal(p.stored): return {"error":"Stored scene chunk length mismatch."}
			var hash := ""
			if verify_payloads:
				hash = Hash.digest(stored)
				timings.stored_hash += (Time.get_ticks_usec()-tick)/1000.0
				if hash != p.stored_sha256:return {"error":"Stored scene chunk checksum."}
			var decoded := Index.decimal(p.decoded)
			if p.codec == 1 and not Codec.zstd_header(stored,decoded): return {"error":"Invalid bounded Zstandard frame."}
			tick = Time.get_ticks_usec()
			var raw: PackedByteArray = stored if p.codec == 0 else stored.decompress(decoded,FileAccess.COMPRESSION_ZSTD)
			timings.decompress += (Time.get_ticks_usec()-tick)/1000.0;tick = Time.get_ticks_usec()
			if raw.size() != decoded:return {"error":"Scene chunk decode failed or decoded length mismatch."}
			if verify_payloads:
				var raw_hash: String = hash if p.codec == 0 else Hash.digest(raw)
				timings.raw_hash += (Time.get_ticks_usec()-tick)/1000.0
				if raw_hash != p.raw_sha256:return {"error":"Decoded scene chunk checksum."}
			tick = Time.get_ticks_usec()
			full.append_array(raw)
			timings.assembly += (Time.get_ticks_usec()-tick)/1000.0
		var tick := Time.get_ticks_usec()
		timings.assembly += (Time.get_ticks_usec()-tick)/1000.0;tick = Time.get_ticks_usec()
		match a.dtype:
			"f4": channels[a.name] = full.to_float32_array()
			"f8": channels[a.name] = full.to_float64_array()
			"i8": channels[a.name] = full.to_int64_array()
			"u4": channels[a.name] = full.to_int32_array() # mesh indices <=1m; uint categories widen below
		if a.dtype == "u4" and not (obj.kind == "mesh" and a.name == "triangles"):
			var values := PackedFloat64Array();values.resize(full.size()/4)
			for i in range(values.size()): values[i] = full.decode_u32(i*4)
			channels[a.name] = values;reserve += values.size()*4
		timings.typed_conversion += (Time.get_ticks_usec()-tick)/1000.0
		shapes[a.name] = a.shape;components[a.name] = int(a.shape[1]) if a.shape.size() == 2 else 1;associations[a.name] = a.association
		if obj.kind == "volume":statistics[a.name] = preload("res://layers/field_statistics.gd").decode(a.statistics_v1)
	return {"channels":channels,"components":components,"shapes":shapes,"associations":associations,"statistics":statistics,"reserve":reserve,"timings":timings}
