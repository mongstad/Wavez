extends RefCounted
# Local export binding, not a whole-file integrity certificate or a trust cache.
const Stamp = preload("res://data/source_stamp.gd")
const Profile = preload("res://scene/playback_profile.gd")
const KIND := "simscope-export-source"
static func is_local(value: Dictionary) -> bool: return value.get("kind") == KIND
static func capture(reader) -> Dictionary:
	if reader == null or not reader.index_valid or not reader.trusted or reader.source_stamp.is_empty():return {}
	if Stamp.read(reader.source_path) != reader.source_stamp:return {}
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for record in reader.records:hash.update(record.raw_header)
	Profile.count("video_identity_header_bytes",reader.records.size()*80)
	var result := {"kind":KIND,"version":1,"format":"SIMSCP4","path":reader.source_path,
		"uuid":reader.metadata.uuid,"header_sha256":reader.header.sha256,"record_headers_sha256":hash.finish().hex_encode(),
		"committed_bytes":str(reader.scan_offset),"complete_records":reader.records.size(),"complete_frames":reader.frames.size(),
		"stamp":reader.source_stamp.duplicate()}
	return result if unchanged(reader.source_path,result) else {}
static func unchanged(path: String, identity: Dictionary) -> bool:
	# The stamp is accepted only on the same local filesystems as SceneReader.
	# Nanosecond timestamps stay strings; device/inode reject path replacement.
	return identity.get("stamp") is Dictionary and not identity.stamp.is_empty() and Stamp.read(path) == identity.stamp
static func matches(reader, identity: Dictionary) -> bool:
	if not is_local(identity) or not (identity.get("version") is int or identity.get("version") is float) or identity.version != 1:return false
	var actual := capture(reader)
	if actual.is_empty():return false
	# Paths locate input; they never establish identity. Equivalent local aliases
	# may refer to the same inode, but copies or appends require a new launch.
	actual.erase("path")
	var expected := identity.duplicate();expected.erase("path")
	for key in ["version","complete_records","complete_frames"]:
		var value = expected.get(key)
		if not (value is int or value is float) or not is_finite(value) or value < 0 or value > 1000000 or value != floor(value):return false
		expected[key] = int(value)
	return actual == expected
