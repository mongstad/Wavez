extends RefCounted
# Scientific values remain untouched. Invalid ranges are represented by ±INF
# internally and null in inspection JSON, never fabricated as valid statistics.
const MODES := ["frame", "symmetric", "manual", "interval"]
const LABELS := ["Automatic • per frame", "Automatic • symmetric ±A", "Fixed • manual", "Fixed • selected interval"]

static func finite_range(values, use_log: bool) -> Vector2:
	var low := INF
	var high := -INF
	for value in values64(values):
		if not is_finite(value) or (use_log and value <= 0): continue
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)

static func resolve(values, mode: String, use_log: bool, low: float, high: float) -> Vector2:
	if mode in ["manual", "interval"]: return Vector2(low, high)
	var bounds := finite_range(values, use_log)
	if mode == "symmetric" and is_finite(bounds.x) and is_finite(bounds.y):
		var amplitude := maxf(absf(bounds.x), absf(bounds.y))
		# ±1 is a DISPLAY fallback only for an exactly all-zero finite channel.
		if amplitude == 0: amplitude = 1.0
		return Vector2(-amplitude, amplitude)
	return bounds

static func normalized(value: float, low: float, high: float, use_log: bool, clamp_values := true, cyclic := false) -> float:
	if not is_finite(value) or not is_finite(low) or not is_finite(high) or high < low: return -1
	if cyclic:
		if high <= low or use_log: return -1
		return fposmod(value-low, high-low)/(high-low)
	if use_log:
		if value <= 0 or low <= 0 or high <= 0: return -1
		value = log(value); low = log(low); high = log(high)
	var t := .5 if high == low else (value-low)/(high-low)
	if not clamp_values and (t < 0 or t > 1): return -1
	return clampf(t, 0, 1)

static func statistics(values, bounds: Vector2, use_log: bool) -> Dictionary:
	var valid := 0
	var excluded := 0
	var clipped := 0
	for value in values64(values):
		if not is_finite(value) or (use_log and value <= 0): excluded += 1
		else:
			valid += 1
			if value < bounds.x or value > bounds.y: clipped += 1
	return {"count":values.size(), "valid":valid, "invalid_or_nonpositive":excluded, "outside_range":clipped}

static func values64(values) -> PackedFloat64Array:
	if values is PackedFloat64Array: return values
	return PackedFloat64Array(Array(values))

# The range/mode are invariant across a frame. Keep the reference normalized()
# scalar API above; prepare once for particle batches with identical semantics.
class Mapping:
	var low: float
	var span: float
	var valid := false
	var use_log := false
	var clamp_values := true
	var cyclic := false
	func sample(value: float) -> float:
		if not valid or not is_finite(value): return -1.0
		if cyclic: return fposmod(value-low,span)/span
		if use_log:
			if value <= 0: return -1.0
			value = log(value)
		var t := .5 if span == 0 else (value-low)/span
		if not clamp_values and (t < 0 or t > 1): return -1.0
		return clampf(t,0,1)

static func prepare(bounds: Vector2, use_log: bool, clamp_values := true, cyclic := false) -> Mapping:
	var m := Mapping.new()
	m.low = bounds.x
	var high: float = bounds.y
	m.use_log = use_log; m.clamp_values = clamp_values; m.cyclic = cyclic
	m.valid = is_finite(m.low) and is_finite(high) and high >= m.low
	if cyclic:
		m.valid = m.valid and high > m.low and not use_log
	elif use_log:
		m.valid = m.valid and m.low > 0 and high > 0
		if m.valid: m.low = log(m.low); high = log(high)
	m.span = high-m.low
	return m
