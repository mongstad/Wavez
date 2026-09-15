extends RefCounted
# Immutable lookup shared by decoded snapshots; integer keys never pass through float.
var rows: Dictionary = {}
static func build(ids: PackedInt64Array, worker) -> Dictionary:
	if ids.size() > 1000000: return {"error":"ID allocation ceiling exceeded."}
	var map = load("res://data/particle_identity.gd").new()
	for first in range(0,ids.size(),8192):
		if worker.stopped(): return {}
		for i in range(first,mini(first+8192,ids.size())):
			if ids[i] < 0 or map.rows.has(ids[i]): return {"error":"Negative or duplicate particle ID."}
			map.rows[ids[i]] = i
	map.rows.make_read_only()
	return {"map":map}
