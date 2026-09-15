extends RefCounted
# Pure CPU preparation. No scene nodes, textures, MultiMeshes or shared profiler state.
const Normalization = preload("res://scene/normalization.gd")
const Style = preload("res://scene/particle_style.gd")

static func frame(data: Dictionary, worker) -> Dictionary:
	var started := Time.get_ticks_usec()
	var xyz = data.channels.position
	var positions := PackedVector3Array()
	if xyz is PackedFloat32Array and PackedVector3Array([Vector3.ZERO]).to_byte_array().size() == 12:
		positions = xyz.to_byte_array().to_vector3_array()
	else:
		positions.resize(data.count)
		for first in range(0,data.count,8192):
			if worker.stopped(): return {}
			for i in range(first,mini(first+8192,data.count)):
				positions[i] = Vector3(xyz[i*3],xyz[i*3+1],xyz[i*3+2])
				if not positions[i].is_finite(): return {"error":"Position exceeds the viewer coordinate range; source values remain unchanged."}
	var intensity := PackedFloat32Array();intensity.resize(data.count);intensity.fill(1.0)
	var scalars := {}
	for name in data.channels:
		if data.components[name] == 1 and name != "particle_id":scalars[name] = data.channels[name]
	if data.components.get("velocity",0) == 3:
		var values := Normalization.values64(data.channels.velocity)
		var magnitude := PackedFloat32Array();magnitude.resize(data.count)
		for first in range(0,data.count,8192):
			if worker.stopped(): return {}
			for i in range(first,mini(first+8192,data.count)): magnitude[i] = Vector3(values[i*3],values[i*3+1],values[i*3+2]).length()
		scalars.velocity_magnitude = magnitude
	data._display_positions = positions;data._display_intensity = intensity;data._display_scalars = scalars
	data.decoded_bytes += data.count*(20 if scalars.has("velocity_magnitude") else 16)+1024
	worker.observe("frame_conversion",started)
	return data

static func style(fr: Dictionary, config: Dictionary, fade: float, worker) -> Dictionary:
	var started := Time.get_ticks_usec()
	var positions: PackedVector3Array = fr._display_positions
	var scalars: Dictionary = fr._display_scalars
	var color_channel: String = config.color_channel
	var size_channel: String = config.size_channel
	var brightness_channel: String = config.brightness_channel
	var c: int = fr.components.get("visual_color",0)
	# Same per-frame channel fallback as the main-thread mapping controls.
	if color_channel != "fixed" and not scalars.has(color_channel) and not (color_channel == "visual_color" and c in [3,4]): color_channel = "fixed"
	if not scalars.has(size_channel):size_channel = "fixed"
	if not scalars.has(brightness_channel):brightness_channel = "fixed"
	var color_values := Normalization.values64(scalars.get(color_channel,PackedFloat64Array()))
	var sizes := Normalization.values64(scalars.get(size_channel,PackedFloat64Array()))
	var brights := Normalization.values64(scalars.get(brightness_channel,PackedFloat64Array()))
	var opacity := Normalization.values64(scalars.get("opacity",PackedFloat64Array()))
	var types := Normalization.values64(scalars.get("particle_type",PackedFloat64Array()))
	var rgb := Normalization.values64(fr.channels.get("visual_color",PackedFloat64Array()))
	var scalar_color := color_channel not in ["fixed","visual_color"]
	var direct_color := color_channel == "visual_color" and c in [3,4]
	var direct_size := size_channel == "visual_size"
	var direct_bright := brightness_channel == "visual_brightness"
	var hidden_types: Dictionary = config.hidden_types
	var count := positions.size()
	var has_size := sizes.size() == count
	var has_bright := brights.size() == count
	var has_opacity := opacity.size() == count
	var has_filter := not hidden_types.is_empty() and types.size() == count
	var color_range := Normalization.resolve(color_values,config.normalization,config.logarithmic,config.manual_min,config.manual_max)
	var size_range := Normalization.finite_range(sizes,false) if has_size and not direct_size else Vector2.ZERO
	var bright_range := Normalization.finite_range(brights,false) if has_bright and not direct_bright else Vector2.ZERO
	var color_mapping := Normalization.prepare(color_range,config.logarithmic,config.clamp_map,config.cyclic)
	var size_mapping := Normalization.prepare(size_range,false)
	var bright_mapping := Normalization.prepare(bright_range,false)
	var buffer := PackedFloat32Array()
	var output_sizes := PackedFloat32Array()
	if scalar_color:
		# Bound cancellation latency without modifying the shared particle packer.
		for first in range(0,count,8192):
			if worker.stopped(): return {}
			var last := mini(count,first+8192)
			var part := Style.scalar_buffer(positions.slice(first,last),color_values.slice(first,last),sizes.slice(first,last),brights.slice(first,last),opacity.slice(first,last),types.slice(first,last),hidden_types,color_mapping,size_mapping,bright_mapping,direct_size,direct_bright,config.invert_map,fade)
			buffer.append_array(part.buffer);output_sizes.append_array(part.sizes)
		worker.observe("style",started)
		return {"buffer":buffer,"sizes":output_sizes,"range":color_range}
	buffer.resize(count*16);output_sizes.resize(count)
	for first in range(0,count,8192):
		if worker.stopped(): return {}
		for i in range(first,mini(first+8192,count)):
			var alpha := fade
			var col := Color.WHITE
			if direct_color:
				col = Color(rgb[i*c], rgb[i*c+1], rgb[i*c+2], rgb[i*c+3] if c == 4 else 1.0)
				if not is_finite(col.r) or not is_finite(col.g) or not is_finite(col.b) or not is_finite(col.a): alpha = 0
				alpha *= clampf(col.a, 0, 1) if is_finite(col.a) else 0
			var bright := 1.0
			if has_bright:
				bright = maxf(0, brights[i]) if direct_bright else bright_mapping.sample(brights[i])
				if not is_finite(brights[i]) or bright < 0: bright = 0
			var size := .35
			if has_size:
				size = maxf(0, sizes[i]) if direct_size else .07 + .48 * size_mapping.sample(sizes[i])
				if not is_finite(sizes[i]) or size < 0: size = 0
			if has_opacity: alpha *= clampf(opacity[i], 0, 1) if is_finite(opacity[i]) else 0
			if has_filter and hidden_types.has(int(types[i])): alpha = 0
			var pos := positions[i]
			if not pos.is_finite(): pos = Vector3.ZERO; alpha = 0
			if not is_finite(col.r) or not is_finite(col.g) or not is_finite(col.b): col = Color.BLACK
			col *= bright
			var offset := i*16
			buffer[offset] = size
			buffer[offset+5] = size
			buffer[offset+10] = size
			buffer[offset+3] = pos.x
			buffer[offset+7] = pos.y
			buffer[offset+11] = pos.z
			buffer[offset+12] = col.r
			buffer[offset+13] = col.g
			buffer[offset+14] = col.b
			buffer[offset+15] = alpha
			output_sizes[i] = size
	worker.observe("style",started)
	return {"buffer":buffer,"sizes":output_sizes,"range":color_range}

static func pair(a: Dictionary, b: Dictionary, history: Array, config: Dictionary, worker) -> Dictionary:
	var started := Time.get_ticks_usec()
	var styled := style(a,config,1.0,worker)
	if styled.is_empty(): return {}
	var matched := PackedInt32Array();var exact := PackedInt32Array()
	var ids: PackedInt64Array = a.channels.get("particle_id",PackedInt64Array())
	var matching: bool = a.has_ids and b.has_ids
	var tick := Time.get_ticks_usec()
	if matching:
		matched.resize(ids.size());exact.resize(ids.size())
		for first in range(0,ids.size(),8192):
			if worker.stopped():return {}
			for i in range(first,mini(first+8192,ids.size())):
				matched[i] = int(b.identity_map.rows.get(ids[i],-1));exact[i] = i
	worker.observe("id_matching",tick)
	tick = Time.get_ticks_usec()
	var trails: Array = []
	if config.trails and a.has_ids:
		var active: Dictionary = a.identity_map.rows.duplicate()
		for layer in range(history.size()):
			if worker.stopped():return {}
			var fr: Dictionary = history[layer]
			if active.is_empty():trails.append({});continue
			if not fr.has_ids or fr.source_index != a.source_index-layer-1:
				active.clear();trails.append({});continue
			for id in active.keys():
				if not fr.identity_map.rows.has(id):active.erase(id)
			var trail := style(fr,config,.3/float(layer+1),worker)
			if trail.is_empty():return {}
			var buffer: PackedFloat32Array = trail.buffer
			var old_ids: PackedInt64Array = fr.channels.particle_id
			for first in range(0,old_ids.size(),8192):
				if worker.stopped():return {}
				for i in range(first,mini(first+8192,old_ids.size())):
					if not active.has(old_ids[i]):buffer[i*16+15] = 0
			trails.append({"buffer":buffer,"count":fr.count})
	worker.observe("trails",tick)
	# Conservative retained footprint: count referenced decoded samples in each
	# pair too. Separate cache limits therefore overcount shared immutable arrays.
	var bytes: int = a.decoded_bytes+(b.decoded_bytes if a.source_index != b.source_index else 0)+styled.buffer.size()*4+styled.sizes.size()*4+(matched.size()+exact.size())*4+8192
	for i in range(history.size()):
		bytes += int(history[i].decoded_bytes)
		if i < trails.size() and not trails[i].is_empty():bytes += trails[i].buffer.size()*4
	worker.observe("pair_preparation",started)
	return {"a":a,"b":b,"history":history,"styled":styled,"trails":trails,"matches":matched,"exact_matches":exact,"bytes":bytes}
