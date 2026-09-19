extends RefCounted
# Resolved bounds remain in the layer's lower/upper fields. All policies are frozen.
const DEFAULT := {"normalization":"linear","policy":"manual","percentile_low":1.0,"percentile_high":99.0,"source_channel":"","source_time":0.0}
const MAX_VALUES := 8*1024*1024 # At most 64 MiB for the sorted float64 copy.
static func numeric(v) -> bool:return (v is float or v is int) and is_finite(v)
static func resolve(state: Dictionary) -> Dictionary:return state.get("color_mapping",DEFAULT)
static func validate(state: Dictionary) -> String:
	var m = state.get("color_mapping")
	if not m is Dictionary or m.size() != DEFAULT.size() or not m.has_all(DEFAULT.keys()):return "Incomplete volume color mapping."
	if m.normalization not in ["linear","log"] or m.policy not in ["manual","symmetric","percentile"]:return "Unknown volume normalization/range policy."
	if not numeric(m.percentile_low) or not numeric(m.percentile_high) or m.percentile_low < 0 or m.percentile_high > 100 or m.percentile_low >= m.percentile_high:return "Percentiles must satisfy 0 <= lower < upper <= 100."
	if not m.source_channel is String or m.source_channel.length()>4096 or not numeric(m.source_time):return "Invalid frozen-range provenance."
	if not numeric(state.lower) or not numeric(state.upper) or state.lower >= state.upper:return "Color maximum must exceed minimum."
	if m.policy == "symmetric" and state.lower != -state.upper:return "Symmetric range must be centered on zero."
	if m.normalization == "log" and (state.lower <= 0 or m.policy == "symmetric"):return "Log color requires positive bounds and a non-symmetric range."
	var gpu := PackedFloat32Array([state.lower,state.upper])
	if not is_finite(gpu[0]) or not is_finite(gpu[1]) or gpu[1] <= gpu[0]:return "Color bounds exceed float32 display precision/range."
	if m.normalization == "log" and gpu[0] <= 0:return "Log color bounds must stay positive in float32."
	if m.normalization == "log":
		var logs := PackedFloat32Array([log(gpu[0]),log(gpu[1])])
		if gpu[0] < 1e-38 or logs[1] <= logs[0]:return "Log color bounds exceed float32 logarithm precision/range."
	return ""
static func statistics(values, cancel = null) -> Dictionary:
	var low := INF;var high := -INF;var finite := 0;var nonpositive := 0
	for i in values.size():
		if i%16384 == 0 and cancel != null and cancel.stopped():return {}
		var v: float = values[i]
		if not is_finite(v):continue
		low = minf(low,v);high = maxf(high,v);finite += 1
		if v<=0:nonpositive += 1
	return {"minimum":low if finite else null,"maximum":high if finite else null,"finite":finite,"nonpositive":nonpositive,"nonfinite":values.size()-finite}
static func sample_problem(state: Dictionary, stats: Dictionary) -> String:
	if resolve(state).normalization != "log":return ""
	if stats.get("finite",0) == 0 or stats.get("nonpositive",0)>0:return "Log color unavailable: source sample contains nonpositive values or no finite values. Choose Linear."
	var gpu := PackedFloat32Array([stats.minimum])
	if gpu[0] < 1e-38:return "Log color unavailable: positive source values underflow the float32 preview. Choose Linear."
	return ""
static func derive(values, policy: String, low_percent: float, high_percent: float) -> Dictionary:
	if values.size() > MAX_VALUES:return {"error":"Range calculation exceeds 8 million source values; use manual bounds."}
	var sorted := PackedFloat64Array()
	for v in values:
		if is_finite(v):sorted.append(v)
	if sorted.is_empty():return {"error":"No finite source values for a range."}
	sorted.sort()
	var low := sorted[0];var high := sorted[-1]
	if policy == "symmetric":
		var bound := maxf(absf(low),absf(high))
		if bound == 0:return {"error":"All finite values are zero; choose manual symmetric bounds."}
		low = -bound;high = bound
	elif policy == "percentile":
		low = quantile(sorted,low_percent/100.);high = quantile(sorted,high_percent/100.)
	else:return {"error":"Unknown derived range policy."}
	if high <= low:return {"error":"Derived range is constant; choose manual bounds."}
	return {"lower":low,"upper":high}
static func quantile(sorted: PackedFloat64Array, fraction: float) -> float:
	var position := fraction*(sorted.size()-1);var index := int(floor(position))
	return lerpf(sorted[index],sorted[mini(index+1,sorted.size()-1)],position-index)
