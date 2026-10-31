extends RefCounted
## Bounded, job-owned display snapshot. This is visual export provenance, never
## a new source channel or a time-dependent spectral computation.
const Adapter = preload("res://analysis/reconstructed_field.gd")
const Index = preload("res://data/capture_index.gd")
const Reader = preload("res://layers/scene_reader.gd")
const Stamp = preload("res://data/source_stamp.gd")
const Exact = preload("res://scene/source_sampling.gd")
const Codec = preload("res://analysis/inspection_v3.gd")
const MAX_BYTES := 192*192*192*4
const MANIFEST_LIMIT := 1048576
const FIELD_FILE := "spectral/field.f4"
const MANIFEST_FILE := "spectral/manifest.json"
const BANDS := ["original","low","intermediate","high"]
const BINDING_KEYS := ["version","kind","source","source_stamp","object","channel","record","geometry","edges","boundary","units","common_range","artifacts","metrics","algorithm","support"]

static func numeric(value) -> bool:
	return (value is int or value is float) and is_finite(value)

static func encode(snapshot: Dictionary) -> Dictionary:
	if snapshot.get("numeric_encoding") == "f64-le": return snapshot.duplicate(true)
	var wire := snapshot.duplicate(true)
	wire.data = Codec.pack(snapshot.data); wire.display = Codec.pack(snapshot.display)
	wire.numeric_encoding = "f64-le"
	return wire

static func decode(snapshot: Dictionary) -> Dictionary:
	if not snapshot.has("numeric_encoding"): return snapshot
	if snapshot.numeric_encoding != "f64-le": return {}
	var decoded := snapshot.duplicate(true)
	decoded.data = Codec.unpack(snapshot.get("data")); decoded.display = Codec.unpack(snapshot.get("display"))
	decoded.erase("numeric_encoding")
	return decoded

static func validate(value) -> String:
	if not value is Dictionary or value.get("version") != 1 or value.get("kind") != "spectral_reconstruction": return "Invalid pinned spectral presentation."
	if value.get("selected_band") not in BANDS: return "Unknown pinned reconstruction selection."
	var data = value.get("data"); var source = value.get("source")
	if not data is Dictionary or data.get("kind") != "spectral_reconstruction" or data.get("version") != 1 or data.get("boundary") != "periodic" or data.get("object") != "field" or data.get("channel") != "amplitude": return "Invalid reconstructed-field provenance."
	if not data.get("units") is Dictionary or not data.get("algorithm") is String or data.algorithm.is_empty() or not data.get("metrics") is Dictionary or not data.get("support") is Dictionary: return "Missing reconstruction algorithm, units or support provenance."
	if not data.get("common_range") is Array or data.common_range.size() != 2 or not numeric(data.common_range[0]) or not numeric(data.common_range[1]) or data.common_range[0] != -data.common_range[1] or data.common_range[1] < 0: return "Invalid common signed reconstruction range."
	if not source is Dictionary or not data.get("source") is Dictionary or source != data.source: return "Reconstruction source bindings differ."
	if source.get("format") != "WVZ1" or not source.get("path") is String or not source.path.is_absolute_path() or not Index.valid_hex(source.get("sha256"),64) or Index.decimal(source.get("committed_bytes")) < 16: return "Invalid verified reconstruction source."
	if not data.get("source_stamp") is Dictionary or not data.get("record") is Dictionary or not Index.whole(data.record.get("index")) or not Index.whole(data.record.get("sequence")) or Exact.exact_float(data.record.get("native_time")).is_empty(): return "Invalid pinned native reconstruction sample."
	if not data.get("edges") is Array or data.edges.size() != 2 or not numeric(data.edges[0]) or not numeric(data.edges[1]) or data.edges[0] <= 0 or data.edges[1] <= data.edges[0]: return "Invalid spectral frequency boundaries."
	var geometry = data.get("geometry")
	if not geometry is Dictionary or not geometry.get("shape") is Array or geometry.shape.size() != 3 or geometry.get("centering") not in ["node","cell"]: return "Invalid reconstructed volume geometry."
	var cells := 1
	for count in geometry.shape:
		if not Index.whole(count) or count < 2 or count > 192: return "Reconstructed export dimensions must remain full-resolution 2–192."
		cells *= int(count)
	for key in ["origin","spacing","data_to_world"]:
		if not geometry.get(key) is Array or geometry[key].size() != (12 if key == "data_to_world" else 3): return "Invalid reconstructed geometry " + key
		for component in geometry[key]:
			if not numeric(component) or (key == "spacing" and component <= 0): return "Invalid reconstructed geometry value."
	var identity := [1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.,0.]
	for i in 12:
		if float(geometry.data_to_world[i]) != identity[i]: return "Reconstructed export requires the supported identity transform."
	if not data.get("artifacts") is Dictionary or not data.artifacts.get(value.selected_band) is Dictionary: return "Reconstructed display artifact is missing."
	var artifact: Dictionary = data.artifacts[value.selected_band]
	if artifact.get("dtype") != "f4" or artifact.get("bytes") != cells*4 or artifact.get("shape_zyx") != geometry.shape or not Index.valid_hex(artifact.get("sha256"),64) or not artifact.get("path") is String: return "Invalid full-resolution reconstructed display artifact."
	if not artifact.get("scientific") is Dictionary or artifact.scientific.get("dtype") != "f8" or artifact.scientific.get("bytes") != cells*8 or not Index.valid_hex(artifact.scientific.get("sha256"),64): return "Float64 reconstruction provenance is missing."
	if not data.get("manifest") is Dictionary or not Index.valid_hex(data.manifest.get("sha256"),64) or not data.manifest.get("path") is String: return "Invalid reconstruction manifest."
	var display = value.get("display")
	if not display is Dictionary or not display.has_all(["lower","upper"]): return "Frozen spectral display settings are missing."
	var problem := preload("res://layers/volume_color.gd").validate(display)
	if not problem.is_empty(): return problem
	var span := PackedFloat32Array([float(display.upper)-float(display.lower)])[0]
	if not is_finite(span) or span < 1e-38: return "Spectral display range is not representable in the GPU field."
	problem = preload("res://layers/volume_opacity.gd").validate(display.get("opacity_mapping"))
	if not problem.is_empty(): return problem
	for key in ["visible","volume","slice","clip"]:
		if not display.get(key) is bool: return "Invalid spectral visibility/clipping setting."
	for key in ["opacity","step","clip_distance","slice_distance"]:
		if not numeric(display.get(key)): return "Invalid spectral display " + key
	if display.opacity < 0 or display.opacity > 5 or display.step <= 0: return "Invalid spectral opacity or ray step."
	for key in ["clip_normal","slice_normal"]:
		if not display.get(key) is Array or display[key].size() != 3: return "Invalid spectral plane normal."
		for component in display[key]:
			if not numeric(component): return "Invalid spectral plane component."
		if Reader.vec(display[key]).length_squared() < 1e-20: return "Spectral plane normal must be nonzero."
	var lut = value.get("lut")
	if not lut is Dictionary or lut.get("format") != "rgb8" or lut.get("width") != 256 or lut.get("height") != 1 or not Index.valid_hex(lut.get("pixels_hex"),1536): return "Invalid exact spectral colormap pixels."
	var legend = value.get("legend")
	if not legend is Dictionary or not legend.get("visible") is bool or not legend.get("text") is String or legend.text.length() > 16384: return "Invalid spectral legend."
	if value.has("artifact") and (not value.artifact is Dictionary or value.artifact.get("file") != FIELD_FILE or value.artifact.get("sha256") != artifact.sha256 or value.artifact.get("bytes") != artifact.bytes): return "Job-owned spectral artifact differs from its verified provenance."
	if value.has("manifest") and (not value.manifest is Dictionary or value.manifest.get("file") != MANIFEST_FILE or value.manifest.get("sha256") != data.manifest.sha256 or not Index.whole(value.manifest.get("bytes")) or value.manifest.bytes < 2 or value.manifest.bytes > MANIFEST_LIMIT): return "Job-owned spectral manifest differs from its verified provenance."
	return ""

static func stamp_matches(data: Dictionary, stamp: Dictionary) -> bool:
	var expected = data.get("source_stamp")
	if not expected is Dictionary or stamp.is_empty(): return false
	for key in ["device","inode","size"]:
		if expected.get(key) != stamp.get(key): return false
	for key in ["mtime","ctime"]:
		var ns := str(expected.get(key+"_ns",""))
		if not ns.is_valid_int() or ns.length() < 10 or ns.substr(0,ns.length()-9)+"."+ns.right(9) != stamp.get(key): return false
	return true

static func binding_problem(snapshot: Dictionary, capture_path: String, identity: Dictionary) -> String:
	if snapshot.source.path.simplify_path() != capture_path.simplify_path() or snapshot.source.committed_bytes != identity.get("committed_bytes") or snapshot.source.get("uuid") != identity.get("uuid") or not stamp_matches(snapshot.data,identity.get("stamp",{})): return "Pinned reconstruction and video source identity/extent differ; recompute before exporting."
	return ""

static func _regular(path: String) -> bool:
	var access := DirAccess.open(path.get_base_dir())
	return access != null and not access.is_link(path.get_file()) and FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path)

static func _copy_verified(source: String, destination: String, expected: int, sha256: String) -> String:
	if not _regular(source): return "Reconstructed export input is missing or linked."
	var input := FileAccess.open(source,FileAccess.READ)
	if input == null or input.get_length() != expected: return "Reconstructed export input length changed."
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination): return "Spectral export destination already exists."
	var output := FileAccess.open(destination+".part",FileAccess.WRITE)
	if output == null: return "Cannot create owned spectral export artifact."
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	var remaining := expected
	while remaining > 0:
		var data := input.get_buffer(mini(1048576,remaining))
		if data.is_empty(): output.close(); DirAccess.remove_absolute(destination+".part"); return "Spectral export copy was truncated."
		digest.update(data); output.store_buffer(data); remaining -= data.size()
		if output.get_error() != OK: output.close(); DirAccess.remove_absolute(destination+".part"); return "Cannot write spectral export snapshot; check disk space."
	output.flush()
	var write_error := output.get_error(); output.close(); input.close()
	if write_error != OK: DirAccess.remove_absolute(destination+".part"); return "Cannot finish spectral export snapshot; check disk space."
	if digest.finish().hex_encode() != sha256: DirAccess.remove_absolute(destination+".part"); return "Spectral artifact changed during export snapshot."
	if DirAccess.rename_absolute(destination+".part",destination) != OK: DirAccess.remove_absolute(destination+".part"); return "Cannot publish owned spectral export artifact."
	return ""

static func stage(snapshot: Dictionary, directory: String) -> Dictionary:
	var problem := validate(snapshot)
	if not problem.is_empty(): return {"ok":false,"error":problem}
	var result := snapshot.duplicate(true); var artifact: Dictionary = result.data.artifacts[result.selected_band]
	var worker := str(result.get("worker_directory",""))
	if not Adapter.owned_path(artifact.path,worker,result.selected_band+".f4") or not Adapter.owned_path(result.data.manifest.path,worker,"manifest.json"): return {"ok":false,"error":"Spectral snapshot does not belong to the active analysis worker."}
	if not stamp_matches(result.data,Stamp.read(result.source.path)): return {"ok":false,"error":"Source changed before spectral export snapshot."}
	var manifest_file := FileAccess.open(result.data.manifest.path,FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() < 2 or manifest_file.get_length() > MANIFEST_LIMIT: return {"ok":false,"error":"Spectral manifest size changed."}
	var manifest_bytes := manifest_file.get_length(); manifest_file.close()
	var owned := directory.path_join("spectral"); var access := DirAccess.open(directory)
	if access == null or access.get_space_left() < int(artifact.bytes)+MANIFEST_LIMIT+268435456: return {"ok":false,"error":"Insufficient free-space headroom for the bounded spectral video snapshot."}
	if DirAccess.dir_exists_absolute(owned) or FileAccess.file_exists(owned) or DirAccess.make_dir_absolute(owned) != OK: return {"ok":false,"error":"Cannot create a new private spectral export directory."}
	problem = _copy_verified(result.data.manifest.path,directory.path_join(MANIFEST_FILE),manifest_bytes,result.data.manifest.sha256)
	if problem.is_empty(): problem = _copy_verified(artifact.path,directory.path_join(FIELD_FILE),int(artifact.bytes),artifact.sha256)
	if problem.is_empty() and not stamp_matches(result.data,Stamp.read(result.source.path)): problem = "Source changed while freezing the spectral export."
	if not problem.is_empty(): cleanup(directory); return {"ok":false,"error":problem}
	result.artifact = {"file":FIELD_FILE,"bytes":artifact.bytes,"sha256":artifact.sha256}
	result.manifest = {"file":MANIFEST_FILE,"bytes":manifest_bytes,"sha256":result.data.manifest.sha256}
	result.erase("worker_directory")
	return {"ok":true,"error":"","snapshot":result}

static func owned_path(directory: String, relative: String) -> String:
	if relative not in [FIELD_FILE,MANIFEST_FILE]: return ""
	var access := DirAccess.open(directory)
	if access == null or access.is_link("spectral"): return ""
	var path := directory.path_join(relative)
	return path if _regular(path) else ""

static func cleanup(directory: String) -> void:
	var access := DirAccess.open(directory)
	if access == null or access.is_link("spectral"): return
	var owned := directory.path_join("spectral"); access = DirAccess.open(owned)
	if access == null: return
	for name in ["field.f4","field.f4.part","manifest.json","manifest.json.part"]:
		if not access.is_link(name) and FileAccess.file_exists(owned.path_join(name)): DirAccess.remove_absolute(owned.path_join(name))
	if access.get_files().is_empty() and access.get_directories().is_empty(): DirAccess.remove_absolute(owned)

static func native_problem(snapshot: Dictionary, reader) -> String:
	var data: Dictionary = snapshot.data; var rows: Array = reader.samples.get(data.object,[])
	var index := int(data.record.index)
	if index >= rows.size() or rows[index].sequence != data.record.sequence or rows[index].time != Exact.exact_float(data.record.native_time).value: return "Pinned reconstruction native record differs from the video source."
	var descriptor: Dictionary = reader.describe(data.object,index)
	if descriptor.is_empty() or not descriptor.get("geometry") is Dictionary: return "Cannot verify pinned reconstruction native geometry."
	var geometry: Dictionary = descriptor.geometry.duplicate(true); geometry.data_to_world = reader.objects[data.object].data_to_world
	if geometry != data.geometry: return "Pinned reconstruction geometry differs from the native source."
	return ""

static func prepare(snapshot: Dictionary, directory: String, tree: SceneTree, cancelled: Callable) -> Dictionary:
	snapshot = decode(snapshot)
	var problem := validate(snapshot)
	if not problem.is_empty(): return {"error":problem}
	if not snapshot.has("artifact") or not snapshot.has("manifest"): return {"error":"Video job has no owned reconstructed display snapshot; original substitution is refused."}
	var path := owned_path(directory,MANIFEST_FILE)
	var file := FileAccess.open(path,FileAccess.READ) if not path.is_empty() else null
	if file == null or file.get_length() != snapshot.manifest.bytes or file.get_length() > MANIFEST_LIMIT: return {"error":"Owned spectral manifest is unavailable."}
	var raw := file.get_buffer(file.get_length()); file.close()
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(raw)
	if digest.finish().hex_encode() != snapshot.manifest.sha256: return {"error":"Owned spectral manifest hash mismatch."}
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if not data is Dictionary: return {"error":"Owned spectral manifest is invalid."}
	for key in BINDING_KEYS:
		if not data.has(key) or data[key] != snapshot.data.get(key): return {"error":"Owned spectral manifest binding mismatch: "+key}
	path = owned_path(directory,FIELD_FILE); file = FileAccess.open(path,FileAccess.READ) if not path.is_empty() else null
	if file == null or file.get_length() != snapshot.artifact.bytes or file.get_length() > MAX_BYTES: return {"error":"Owned reconstructed display bytes are unavailable."}
	var geometry: Dictionary = snapshot.data.geometry; var shape: Array = geometry.shape
	var dims := Vector3i(int(shape[2]),int(shape[1]),int(shape[0])); var planes: Array[Image] = []
	digest = HashingContext.new(); digest.start(HashingContext.HASH_SHA256)
	var minimum := INF; var maximum := -INF
	for z in dims.z:
		if cancelled.call(): return {"error":"Spectral display preparation cancelled."}
		raw = file.get_buffer(dims.x*dims.y*4)
		if raw.size() != dims.x*dims.y*4: return {"error":"Owned reconstructed field was truncated."}
		digest.update(raw)
		for value in raw.to_float32_array():
			if not is_finite(value): return {"error":"Nonfinite reconstructed export sample refused."}
			minimum = minf(minimum,value); maximum = maxf(maximum,value)
		planes.append(Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RF,raw))
		if z%8 == 0: await tree.process_frame
	file.close()
	if digest.finish().hex_encode() != snapshot.artifact.sha256: return {"error":"Owned reconstructed display hash mismatch."}
	var transform := Reader.transform_of(geometry.data_to_world)*Transform3D(Basis.from_scale(Reader.vec(geometry.spacing)),Reader.vec(geometry.origin))
	return {"planes":planes,"dims":dims,"reduced":dims,"lod":1,"gpu_bytes":int(snapshot.artifact.bytes),"grid_to_world":transform,"color_stats":{"minimum":minimum,"maximum":maximum,"finite":dims.x*dims.y*dims.z,"nonfinite":0}}

static func provenance(snapshot: Dictionary) -> Dictionary:
	var data: Dictionary = snapshot.data; var artifact: Dictionary = data.artifacts[snapshot.selected_band]
	return {"kind":"pinned_spectral_reconstruction","version":1,"selected_band":snapshot.selected_band,"native_record":data.record.duplicate(true),"time_policy":"Pinned native sample; video time does not recompute or animate the spectral field","source":snapshot.source.duplicate(true),"geometry":data.geometry.duplicate(true),"frequency_edges":data.edges.duplicate(),"boundary":data.boundary,"units":data.units.duplicate(true),"algorithm":data.get("algorithm",""),"scientific_dtype":"f8","scientific_sha256":artifact.scientific.sha256,"display_dtype":"f4","display_sha256":artifact.sha256,"display":snapshot.display.duplicate(true),"lut":snapshot.lut.duplicate(true),"legend":snapshot.legend.duplicate(true)}
