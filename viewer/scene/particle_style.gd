extends RefCounted
# CPU scalar mapping with frame-invariant decisions prepared once. Source arrays
# stay untouched. This writes the same 3x4 + custom RGBA MultiMesh representation.
static func scalar_buffer(positions: PackedVector3Array, colors: PackedFloat64Array,
		sizes: PackedFloat64Array, brights: PackedFloat64Array, opacity: PackedFloat64Array,
		types: PackedFloat64Array, hidden: Dictionary, color_map, size_map, bright_map,
		direct_size: bool, direct_bright: bool, invert: bool, fade: float) -> Dictionary:
	var count := positions.size()
	var has_color := colors.size() == count
	var has_size := sizes.size() == count
	var has_bright := brights.size() == count
	var has_opacity := opacity.size() == count
	var has_filter := not hidden.is_empty() and types.size() == count
	var valid: bool = color_map.valid
	var low: float = color_map.low
	var span: float = color_map.span
	var use_log: bool = color_map.use_log
	var cyclic: bool = color_map.cyclic
	var clamp_values: bool = color_map.clamp_values
	var buffer := PackedFloat32Array()
	buffer.resize(count*16)
	var output_sizes := PackedFloat32Array()
	output_sizes.resize(count)
	for i in range(count):
		# Fully transparent or filtered particles cannot contribute to either
		# render mode. Leave a zero-scale/zero-alpha display slot; preserve its
		# source index and every scientific channel in FrameData.
		if has_opacity and (not is_finite(opacity[i]) or opacity[i] <= 0): continue
		if has_filter and hidden.has(int(types[i])): continue
		var alpha := fade
		var t := -1.0
		if has_color and valid:
			var value := colors[i]
			if is_finite(value):
				if cyclic: t = fposmod(value-low,span)/span
				elif use_log:
					if value > 0: t = .5 if span == 0 else (log(value)-low)/span
				else: t = .5 if span == 0 else (value-low)/span
				if not clamp_values and not cyclic and (t < 0 or t > 1): t = -1.0
				elif not use_log or value > 0: t = clampf(t,0,1)
		if t < 0: alpha = 0
		if invert: t = 1-t
		var bright := 1.0
		if has_bright:
			var value := brights[i]
			bright = maxf(0,value) if direct_bright else bright_map.sample(value)
			if not is_finite(value) or bright < 0: bright = 0
		var size := .35
		if has_size:
			var value := sizes[i]
			size = maxf(0,value) if direct_size else .07 + .48*size_map.sample(value)
			if not is_finite(value) or size < 0: size = 0
		if has_opacity: alpha *= clampf(opacity[i],0,1) if is_finite(opacity[i]) else 0
		if has_filter and hidden.has(int(types[i])): alpha = 0
		var pos := positions[i]
		if not pos.is_finite(): pos = Vector3.ZERO; alpha = 0
		var offset := i*16
		buffer[offset] = size
		buffer[offset+5] = size
		buffer[offset+10] = size
		buffer[offset+3] = pos.x
		buffer[offset+7] = pos.y
		buffer[offset+11] = pos.z
		buffer[offset+12] = clampf(t,0,1)
		buffer[offset+13] = bright
		buffer[offset+15] = alpha
		output_sizes[i] = size
	return {"buffer":buffer,"sizes":output_sizes}
