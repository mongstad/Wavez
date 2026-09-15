extends RefCounted
# Pure source-clock/identity policy. Mirrored by analysis/sampling.py golden tests.
const POLICY_VERSION := "g4-source-sampling-1"

static func exact_id(value) -> Dictionary:
	if not value is String or value.length() > 19 or not value.is_valid_int(): return {}
	var number: int = value.to_int()
	if number < 0 or str(number) != value: return {}
	return {"value":number}

static func exact_float(value) -> Dictionary:
	if not value is Dictionary or not value.get("f64_le_hex") is String or value.f64_le_hex.length() != 16: return {}
	var bytes: PackedByteArray = value.f64_le_hex.hex_decode()
	if bytes.size() != 8: return {}
	var number := bytes.decode_double(0)
	return {"value":number} if is_finite(number) else {}

static func bracket(rows: Array, time: float, is_static: bool) -> Dictionary:
	if not is_finite(time) or rows.is_empty() or (not is_static and time < rows[0].time): return {}
	if is_static: return {"a":0,"b":0,"alpha":0.0,"status":"static","time":rows[0].time}
	var lo := 0
	var hi := rows.size()
	while lo < hi:
		var mid := (lo+hi)/2
		if rows[mid].time <= time: lo = mid+1
		else: hi = mid
	var a := maxi(0,lo-1)
	var b := mini(a+1,rows.size()-1)
	if rows[a].time == time: b = a
	return {"a":a,"b":b,"alpha":0.0 if a == b else (time-rows[a].time)/(rows[b].time-rows[a].time),"status":"exact" if time == rows[a].time else "held","time":rows[a].time}

static func mesh_compatible(obj: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	return obj.identity == "stable_topology" and a.channels.has("vertex_id") and b.channels.has("vertex_id") and a.channels.vertex_id == b.channels.vertex_id and a.channels.triangles == b.channels.triangles and a.count == b.count
