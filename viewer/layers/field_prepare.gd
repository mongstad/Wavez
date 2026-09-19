extends RefCounted
const Reader = preload("res://layers/scene_reader.gd")
static func prepare(obj: Dictionary, sample: Dictionary, selected: String, budget: int, cancel = null) -> Dictionary:
	if not sample.channels.has(selected): return {"error":"Scalar channel unavailable."}
	var geometry: Dictionary = sample.geometry
	var grid_to_world: Transform3D = Reader.transform_of(obj.data_to_world)*Transform3D(Basis.from_scale(Reader.vec(geometry.spacing)),Reader.vec(geometry.origin))
	var determinant := grid_to_world.basis.determinant()
	if not grid_to_world.origin.is_finite() or not is_finite(determinant) or determinant == 0:
		return {"error":"Grid transform exceeds display coordinate range; source unchanged."}
	var shape: Array = sample.shapes[selected];var dims := Vector3i(int(shape[2]),int(shape[1]),int(shape[0]));var reduced := dims;var lod := 1
	while reduced.x*reduced.y*reduced.z*4 > budget and mini(reduced.x,mini(reduced.y,reduced.z)) > 2:
		lod *= 2;reduced = Vector3i(maxi(2,ceili(dims.x/float(lod))),maxi(2,ceili(dims.y/float(lod))),maxi(2,ceili(dims.z/float(lod))))
	var gpu_bytes := reduced.x*reduced.y*reduced.z*4
	if gpu_bytes > budget: return {"error":"Volume texture budget exhausted; preview released."}
	var values = sample.channels[selected]
	var color_stats := preload("res://layers/volume_color.gd").statistics(values,cancel)
	if color_stats.is_empty():return {}
	if lod == 1 and values is PackedFloat64Array:
		var display := PackedFloat32Array();display.resize(values.size())
		for i in range(values.size()):
			if i % 16384 == 0 and cancel != null and cancel.stopped():return {}
			display[i] = values[i]
			if is_finite(values[i]) and not is_finite(display[i]):return {"error":"Field exceeds float32 display range; source unchanged."}
		values = display
	var planes: Array[Image] = []
	if lod == 1:
		var raw: PackedByteArray = values.to_byte_array();var length := dims.x*dims.y*4
		for z in range(dims.z): planes.append(Image.create_from_data(dims.x,dims.y,false,Image.FORMAT_RF,raw.slice(z*length,(z+1)*length)))
	else:
		for z in range(reduced.z):
			if cancel != null and cancel.stopped():return {}
			var plane := PackedFloat32Array();plane.resize(reduced.x*reduced.y)
			var iz := roundi(z*float(dims.z-1)/(reduced.z-1))
			for y in range(reduced.y):
				var iy := roundi(y*float(dims.y-1)/(reduced.y-1))
				for x in range(reduced.x):
					var ix := roundi(x*float(dims.x-1)/(reduced.x-1));plane[y*reduced.x+x] = values[(iz*dims.y+iy)*dims.x+ix]
					if is_finite(values[(iz*dims.y+iy)*dims.x+ix]) and not is_finite(plane[y*reduced.x+x]):return {"error":"Field exceeds float32 display range; source unchanged."}
			planes.append(Image.create_from_data(reduced.x,reduced.y,false,Image.FORMAT_RF,plane.to_byte_array()))
	return {"color_stats":color_stats,"planes":planes,"dims":dims,"reduced":reduced,"lod":lod,"gpu_bytes":gpu_bytes,"grid_to_world":grid_to_world,"sample":sample,"object":obj,"channel":selected}
