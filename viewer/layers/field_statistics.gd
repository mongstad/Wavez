extends RefCounted
# Required source summaries; descriptor/commit proofs and payload checks still apply.
const Index = preload("res://data/capture_index.gd")
static func valid(s, count: int) -> bool:
	if not s is Dictionary or s.size() != 5 or not s.has_all(["minimum","maximum","finite","nonfinite","nonpositive"]):return false
	for key in ["finite","nonfinite","nonpositive"]:
		if not Index.whole(s[key]) or s[key] > count:return false
	if s.finite+s.nonfinite != count or s.nonpositive > s.finite:return false
	if s.finite == 0:return s.minimum == null and s.maximum == null
	if not Index.valid_hex(s.minimum,16) or not Index.valid_hex(s.maximum,16):return false
	var low: float = s.minimum.hex_decode().decode_double(0)
	var high: float = s.maximum.hex_decode().decode_double(0)
	return is_finite(low) and is_finite(high) and low <= high and (low > 0) == (s.nonpositive == 0) and (high <= 0) == (s.nonpositive == s.finite)
static func decode(s: Dictionary) -> Dictionary:
	var result := s.duplicate()
	for key in ["minimum","maximum"]:
		if result[key] != null:result[key] = result[key].hex_decode().decode_double(0)
	return result
