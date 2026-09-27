extends RefCounted
## Shared presentation only; callers supply their existing effective display range.
const WIDTH := 460.0
const COLUMN := 176.0
static func content(object_id: String, channel: String, colormap: String, bounds: String, mapping: String, policy := "") -> String:
	var text := "Object: %s\tChannel: %s\nColormap: %s\tColor range: %s (%s)" % [object_id,channel,colormap,bounds,mapping]
	if not policy.is_empty():text += "\nRange policy: "+policy
	return text
static func configure(label: Label) -> void:
	label.tab_stops = PackedFloat32Array([COLUMN])
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
