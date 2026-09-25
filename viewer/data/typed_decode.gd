extends RefCounted
const Hash = preload("res://data/capture_index.gd")
const Index = preload("res://data/capture_index.gd")
const Identity = preload("res://data/particle_identity.gd")
# Check standard Zstandard header before native bounded-buffer decompression.
static func zstd_header(bytes: PackedByteArray, expected: int) -> bool:
	if bytes.size() < 6 or bytes.decode_u32(0) != 0xfd2fb528: return false
	var descriptor := int(bytes[4]);var single := (descriptor & 32) != 0
	if descriptor & 24: return false # reserved/unused bits
	var flag := descriptor >> 6;var dict_flag := descriptor & 3;var offset := 5
	if not single:
		var window := int(bytes[offset]);offset += 1
		var base := 1 << (10+(window>>3))
		if base+(base>>3)*(window & 7) > Index.MAX_CHUNK: return false
	var dict_size: int = [0,1,2,4][dict_flag]
	if offset+dict_size > bytes.size(): return false
	for i in range(dict_size):
		if bytes[offset+i] != 0: return false
	offset += dict_size
	var size_bytes: int = [1 if single else 0,2,4,8][flag]
	if size_bytes == 0 or offset+size_bytes > bytes.size(): return false
	var size := 0
	for i in range(size_bytes): size |= int(bytes[offset+i]) << (8*i)
	if size_bytes == 2: size += 256
	if size < 0 or size != expected or (single and size > Index.MAX_CHUNK): return false
	offset += size_bytes
	while true:
		if offset+3 > bytes.size(): return false
		var block := int(bytes[offset]) | (int(bytes[offset+1])<<8) | (int(bytes[offset+2])<<16)
		offset += 3
		var kind := (block>>1)&3;var length := block>>3
		if kind == 3 or length > 128*1024: return false
		offset += 1 if kind == 1 else length
		if offset > bytes.size(): return false
		if block&1: break
	if descriptor&4: offset += 4
	return offset == bytes.size()

static func read(file: FileAccess, entry: Dictionary, worker, identity_reference: Dictionary = {}) -> Dictionary:
	var channels := {};var components := {};var unavailable: Array = [];var used: int = 4096+entry.channels.size()*256
	var id_map
	for d in entry.channels:
		if worker.stopped(): return {}
		var supported: bool = Index.TYPES.has(d.dtype)
		for part in d.chunks:
			if int(part.codec) not in [0,1]: supported = false
		if not supported:
			if d.required: return {"error":"Unsupported required type/codec."}
			unavailable.append(d.name);continue
		var channel_bytes := PackedByteArray()
		for part in d.chunks:
			if worker.stopped(): return {}
			var raw_size := Index.decimal(part.decoded);var stored_size := Index.decimal(part.stored)
			if raw_size < 0 or raw_size > Index.MAX_CHUNK or stored_size < 0 or stored_size > Index.MAX_CHUNK+65536: return {"error":"Chunk allocation ceiling."}
			var tick := Time.get_ticks_usec();file.seek(entry.offset+Index.decimal(part.offset));var stored := file.get_buffer(stored_size)
			observe(worker,"file_io",tick)
			tick = Time.get_ticks_usec()
			var stored_hash := Hash.digest(stored)
			if stored.size() != stored_size or stored_hash != part.stored_sha256: return {"error":"Stored chunk checksum mismatch."}
			observe(worker,"chunk_hash",tick)
			if part.codec == 1 and not zstd_header(stored,raw_size): return {"error":"Unsupported Zstandard window/dictionary/header."}
			tick = Time.get_ticks_usec()
			var raw: PackedByteArray = stored if part.codec == 0 else stored.decompress(raw_size,FileAccess.COMPRESSION_ZSTD)
			observe(worker,"decompress",tick)
			tick = Time.get_ticks_usec()
			# None uses exactly the same bytes for both proofs; avoid hashing them twice.
			var raw_hash: String = stored_hash if part.codec == 0 else Hash.digest(raw)
			if raw.size() != raw_size or raw_hash != part.raw_sha256: return {"error":"Decoded chunk checksum/length mismatch."}
			observe(worker,"chunk_hash",tick)
			if channel_bytes.is_empty(): channel_bytes = raw
			else: channel_bytes.append_array(raw)
		var tick := Time.get_ticks_usec()
		match d.dtype:
			"f4": channels[d.name] = channel_bytes.to_float32_array()
			"f8": channels[d.name] = channel_bytes.to_float64_array()
			"i8": channels[d.name] = channel_bytes.to_int64_array()
			"u4":
				var values := PackedFloat64Array();values.resize(entry.count*int(d.components))
				for first in range(0,values.size(),8192):
					if worker.stopped(): return {}
					for i in range(first,mini(first+8192,values.size())): values[i] = channel_bytes.decode_u32(i*4)
				channels[d.name] = values
		observe(worker,"channel_decode",tick)
		components[d.name] = int(d.components)
		used += entry.count*int(d.components)*(4 if d.dtype == "f4" else 8)
		if d.name == "particle_id":
			tick = Time.get_ticks_usec()
			# Reuse only a resident, validated immutable lookup with exactly the
			# same ordered int64 IDs. Payload checksums above are still verified.
			var previous = identity_reference.get("identity_map")
			var previous_ids = identity_reference.get("channels",{}).get("particle_id")
			if previous is Identity and previous.rows.is_read_only() and previous_ids is PackedInt64Array and previous_ids == channels[d.name]:
				id_map = previous
				observe(worker,"identity_reuse",tick)
			else:
				var validated := Identity.build(channels[d.name],worker)
				if validated.is_empty() or validated.has("error"): return validated
				id_map = validated.map
			# Preserve conservative cache accounting even when maps are shared.
			used += entry.count*160
			observe(worker,"identity_decode",tick)
	return {"time":entry.time,"count":entry.count,"channels":channels,"components":components,"decoded_bytes":used,"has_ids":entry.has_ids,"identity_map":id_map,"unavailable_channels":unavailable}

static func observe(worker, name: String, start: int) -> void:
	worker.timings[name] = worker.timings.get(name,0.0)+(Time.get_ticks_usec()-start)/1000.0
