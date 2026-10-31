extends RefCounted
## Read-only, full-resolution display adapter. Float64 worker files remain the
## numerical authority; none of these planes enter the ordinary source cache.
const Reader = preload("res://layers/scene_reader.gd")
const MAX_CELLS := 192*192*192
var mutex := Mutex.new()
var cancelled := false

func cancel() -> void:
	mutex.lock(); cancelled = true; mutex.unlock()

func stopped() -> bool:
	mutex.lock(); var value := cancelled; mutex.unlock(); return value

static func owned_path(path: String, worker_directory: String, filename: String) -> bool:
	var root := worker_directory.simplify_path()+"-reconstruction"
	if not path.is_absolute_path() or path != path.simplify_path(): return false
	if path.get_file() != filename or not path.begins_with(root+"/results/"): return false
	var result_directory := path.get_base_dir()
	if result_directory.get_base_dir() != root.path_join("results"): return false
	var name := result_directory.get_file()
	if not name.begins_with("d-") or not preload("res://data/capture_index.gd").valid_hex(name.substr(2),32): return false
	# Reject links at every worker-owned component, including the payload itself.
	for candidate in [root,root.path_join("results"),result_directory,path]:
		var parent := DirAccess.open(candidate.get_base_dir())
		if parent == null or parent.is_link(candidate.get_file()): return false
	return true

func prepare(data: Dictionary, band: String, worker_directory: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	if band not in ["original","low","intermediate","high"]: return {"error":"Unknown reconstructed band."}
	var manifest = data.get("manifest")
	if not manifest is Dictionary or not manifest.get("path") is String or not owned_path(manifest.path,worker_directory,"manifest.json") or not preload("res://data/capture_index.gd").valid_hex(manifest.get("sha256"),64): return {"error":"Reconstructed manifest path/hash refused."}
	var manifest_file := FileAccess.open(manifest.path,FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() == 0 or manifest_file.get_length() > 1048576: return {"error":"Reconstructed manifest size refused."}
	var manifest_bytes := manifest_file.get_buffer(manifest_file.get_length()); manifest_file.close()
	var manifest_digest := HashingContext.new(); manifest_digest.start(HashingContext.HASH_SHA256); manifest_digest.update(manifest_bytes)
	if manifest_digest.finish().hex_encode() != manifest.sha256: return {"error":"Reconstructed manifest SHA-256 mismatch."}
	var authoritative = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not authoritative is Dictionary: return {"error":"Invalid reconstructed manifest."}
	# Worker-level timing and provenance fields are appended after publication;
	# the scientific identity, geometry, metrics and artifact hashes are immutable.
	for key in ["version","kind","source","source_stamp","object","channel","record","geometry","edges","boundary","units","common_range","artifacts","metrics"]:
		if not authoritative.has(key) or authoritative[key] != data.get(key): return {"error":"Reconstructed manifest binding mismatch: "+key}
	var artifact = data.get("artifacts",{}).get(band)
	var geometry = data.get("geometry")
	if not artifact is Dictionary or not geometry is Dictionary: return {"error":"Missing reconstructed field descriptor."}
	var shape = artifact.get("shape_zyx")
	if not shape is Array or shape.size() != 3 or shape != geometry.get("shape"): return {"error":"Reconstructed field shape mismatch."}
	var cells := 1
	for count in shape:
		if not (count is int or count is float) or not is_finite(count) or int(count) != count or count < 2 or count > 192: return {"error":"Reconstructed field dimensions refused."}
		cells *= int(count)
	if cells > MAX_CELLS or artifact.get("dtype") != "f4" or artifact.get("bytes") != cells*4: return {"error":"Reconstructed field size/type refused; no LOD fallback."}
	var path = artifact.get("path")
	if not path is String or not owned_path(path,worker_directory,band+".f4") or path.get_base_dir() != str(manifest.path).get_base_dir() or not preload("res://data/capture_index.gd").valid_hex(artifact.get("sha256"),64): return {"error":"Reconstructed artifact path/hash refused."}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() != cells*4: return {"error":"Reconstructed artifact has an unexpected byte count."}
	var dims := Vector3i(int(shape[2]),int(shape[1]),int(shape[0]))
	var planes: Array[Image] = []
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	var minimum := INF; var maximum := -INF
	for z in dims.z:
		if stopped(): return {}
		var raw := file.get_buffer(dims.x*dims.y*4)
		if raw.size() != dims.x*dims.y*4: return {"error":"Truncated reconstructed artifact."}
		digest.update(raw)
		var values := raw.to_float32_array()
		for value in values:
			if not is_finite(value): return {"error":"Nonfinite reconstructed display value refused."}
			minimum = minf(minimum,value); maximum = maxf(maximum,value)
		planes.append(Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RF,raw))
	file.close()
	if digest.finish().hex_encode() != artifact.sha256: return {"error":"Reconstructed artifact SHA-256 mismatch."}
	# Geometry is compared against the native descriptor by the controller first.
	var transform: Transform3D = Reader.transform_of(geometry.data_to_world)*Transform3D(Basis.from_scale(Reader.vec(geometry.spacing)),Reader.vec(geometry.origin))
	if not transform.origin.is_finite() or not is_finite(transform.basis.determinant()) or transform.basis.determinant() == 0: return {"error":"Reconstructed display transform refused."}
	return {"planes":planes,"dims":dims,"reduced":dims,"lod":1,"gpu_bytes":cells*4,"grid_to_world":transform,"color_stats":{"minimum":minimum,"maximum":maximum,"finite":cells,"nonfinite":0},"timings":{"transfer_hash_validate_ms":(Time.get_ticks_usec()-started)/1000.0}}
