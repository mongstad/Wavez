extends RefCounted
# Presentation-only extinction weight; color normalization is independent.
const DEFAULT := {"mode":"linear", "lower":0.0, "upper":1.0}
const MODES := ["linear", "magnitude"]

static func resolve(state: Dictionary) -> Dictionary:
	if state.has("opacity_mapping"):return state.opacity_mapping
	# Old recipes/jobs used the color coordinate for extinction. Freeze those
	# saved bounds into an independent mapping to reproduce their original view.
	return {"mode":"linear", "lower":state.lower, "upper":state.upper}

static func validate(value) -> String:
	if not value is Dictionary or value.size() != 3 or not value.has_all(["mode","lower","upper"]):return "Incomplete volume opacity mapping."
	if value.mode not in MODES:return "Unknown volume opacity mapping."
	for key in ["lower","upper"]:
		if not preload("res://scene/inspection_state.gd").numeric(value[key]):return "Opacity thresholds must be finite numbers."
	if value.upper <= value.lower:return "Full-opacity threshold must exceed zero-opacity threshold."
	if value.mode == "magnitude" and value.lower < 0:return "Magnitude opacity requires a non-negative zero-opacity threshold."
	var gpu := PackedFloat32Array([value.lower,value.upper,value.upper-value.lower])
	if not is_finite(gpu[0]) or not is_finite(gpu[1]) or not is_finite(gpu[2]) or gpu[1] <= gpu[0] or gpu[2] < 1e-38:return "Opacity thresholds exceed float32 display precision/range."
	return ""
