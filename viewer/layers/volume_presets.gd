extends RefCounted
# Opt-in display recipes, resolved once against a recorded sample. No name is
# persisted: the existing explicit color/opacity fields are authoritative.
const ColorMapping = preload("res://layers/volume_color.gd")
const Opacity = preload("res://layers/volume_opacity.gd")
const IDS := ["dense_core","faint_structure","signed_field"]
static func problem(preset: String, stats: Dictionary) -> String:
	if preset not in IDS:return "Unknown volume display preset."
	if stats.get("finite",0) == 0:return "Show and sample a field with finite values first."
	if preset == "signed_field":
		if stats.minimum >= 0 or stats.maximum <= 0:return "Signed field preset requires both negative and positive values; use manual controls for a one-sided field."
	elif stats.minimum < 0 or stats.maximum <= 0:return "This preset requires a nonnegative field with positive values; use Signed field or manual controls."
	return ""
static func resolve(state: Dictionary, preset: String, bounds: Dictionary, time: float, low: float, high: float) -> Dictionary:
	var candidate := state.duplicate(true)
	candidate.lower = bounds.lower;candidate.upper = bounds.upper
	candidate.color_mapping = ColorMapping.DEFAULT.duplicate()
	candidate.color_mapping.merge({"policy":"symmetric" if preset == "signed_field" else "percentile","source_channel":state.channel,"source_time":time,"percentile_low":low,"percentile_high":high},true)
	candidate.colormap = "coolwarm" if preset == "signed_field" else "viridis"
	candidate.opacity_mapping = {"mode":"magnitude" if preset == "signed_field" else "linear","lower":0.,"upper":bounds.upper}
	var error := ColorMapping.validate(candidate)
	if error.is_empty():error = Opacity.validate(candidate.opacity_mapping)
	return {"error":error} if not error.is_empty() else {"state":candidate}
