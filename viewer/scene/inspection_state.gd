extends RefCounted
const Profile = preload("res://scene/playback_profile.gd")
const Visual = preload("res://scene/visual_state.gd")
const Geometry = preload("res://scene/geometry.gd")
const Normalization = preload("res://scene/normalization.gd")
const VERSION := 2
const MAX_JSON_BYTES := 1048576

static func digest(path: String, extent: int) -> String:
	var started := Profile.begin()
	Profile.count("identity_hash_calls")
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null or extent < 0 or f.get_length() < extent: return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var left := extent
	while left > 0:
		var bytes := f.get_buffer(mini(left,1048576))
		if bytes.is_empty(): return ""
		hash.update(bytes)
		left -= bytes.size()
	var result := hash.finish().hex_encode()
	Profile.end("identity_hash",started)
	Profile.count("identity_bytes",extent)
	return result

static func identity(viewer) -> Dictionary:
	if viewer.generic_reader == null: return {}
	var extent: int = viewer.generic_reader.scan_offset
	return {"path":viewer.capture_path,"committed_bytes":str(extent),"sha256":digest(viewer.capture_path,extent),"format":"SIMSCP4", "complete_frames":viewer.frame_count}

static func snapshot(viewer, source: Dictionary = {}) -> Dictionary:
	if viewer.scene_layers != null and not viewer.scene_layers.ensure_particle_data():return {}
	if viewer.frame_a == null or viewer.committed_sample.is_empty(): return {}
	if viewer.scene_layers != null and viewer.generic_reader != null and viewer.generic_reader.trusted:
		if preload("res://data/source_stamp.gd").read(viewer.capture_path) != viewer.generic_reader.source_stamp: return {}
	var before_stamp: Dictionary = viewer.generic_reader.source_stamp.duplicate() if viewer.scene_layers != null and viewer.generic_reader != null else {}
	var resolved_source: Dictionary = identity(viewer) if source.is_empty() else source.duplicate(true)
	if not before_stamp.is_empty() and preload("res://data/source_stamp.gd").read(viewer.capture_path) != before_stamp: return {}
	var particle_identity := {"available":false,"policy":"anonymous; no correspondence inferred"}
	if viewer._has_particle_ids():
		var preview: Array[String] = []
		for i in range(mini(16,viewer.frame_a.ids.size())): preview.append(str(viewer.frame_a.ids[i]))
		particle_identity = {"available":true,"namespace":viewer.generic_reader.metadata.storage.uuid+"/"+(viewer.scene_layers.particle_id if viewer.scene_layers != null else "particles"),"count":viewer.frame_a.ids.size(),"preview_ids":preview,"preview_only":true}
	var visual := Visual.snapshot(viewer)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var values = viewer._scalar_channels(viewer.frame_a).get(viewer.color_channel,[])
	var valid: bool = is_finite(viewer.range_min) and is_finite(viewer.range_max) and viewer.range_min <= viewer.range_max
	var result := {"kind":"simscope-inspection","version":VERSION,"source":resolved_source,
		"visual":visual,"sample":sample,"frame_index":viewer.current_index,"alpha":viewer.phase,"history_indices":viewer.history.map(func(frame): return frame.source_index),
		"layers":[{"id":"particles","kind":"particles","visible":viewer.particle_layer_visible,"sampling":sample,"identity_policy":"explicit persistent int64 IDs" if viewer._has_particle_ids() else "anonymous; sample-and-hold; no trails or identity selections", "display_lod":"all recorded particles; no downsampling"}],
		"normalization":{"mode":viewer._effective_normalization(),"bounds":[viewer.range_min,viewer.range_max] if valid else null,"statistics":Normalization.statistics(values,Vector2(viewer.range_min,viewer.range_max),viewer.logarithmic),"scalar_policy":"sample-and-hold"},
		"geometry":{"source":"user override" if not viewer.geometry_override.is_empty() else "capture metadata","value":viewer.geometry_metadata},
		"particle_identity":particle_identity,"selections":[],"render":{"backend":RenderingServer.get_current_rendering_method(),"dimensions":[viewer.get_viewport().get_visible_rect().size.x,viewer.get_viewport().get_visible_rect().size.y]}}

	if viewer.scene_layers != null:
		result.version = 2;result.layers = viewer.scene_layers.layer_samples.duplicate(true)
		if not viewer.scene_layers.current.has(viewer.scene_layers.particle_id):result.normalization = null
		if not viewer.scene_layers.iso_result.is_empty():result.sample.isosurface = viewer.scene_layers.iso_result.provenance.duplicate(true)
	return result

static func numeric(value) -> bool: return (value is int or value is float) and is_finite(value)

static func enum_value(value, choices: Array) -> bool:
	return numeric(value) and int(value) == value and int(value) in choices

static func shape(value, model) -> bool:
	if model is bool: return value is bool
	if model is String: return value is String and value.length() < 4096
	if model is int or model is float: return numeric(value)
	if model is Array:
		if not value is Array or value.size() != model.size(): return false
		for i in range(model.size()):
			if not shape(value[i],model[i]): return false
		return true
	if model is Dictionary:
		if not value is Dictionary: return false
		for key in value:
			if not model.has(key) or not shape(value[key],model[key]): return false
		return true
	return false

static func validate_visual(viewer, state: Dictionary, requested_time = null) -> String:
	var model := Visual.snapshot(viewer)
	for key in state:
		if not model.has(key): return "Unsupported visual field: " + key
		if key in ["hidden_types","channel_preferences","geometry_override","range_interval","scene"]: continue
		if not shape(state[key],model[key]): return "Invalid visual field: " + key
	for key in model:
		if key == "custom_orbit": continue # Optional navigation preference; apply defaults to false.
		if not state.has(key): return "Missing visual field: " + key
	if state.color_channel not in ["fixed","visual_color"] and not state.color_channel is String: return "Invalid channel."
	if not viewer.colormaps.has(state.colormap_name): return "Unknown colormap."
	if state.normalization_mode not in Normalization.MODES: return "Unknown normalization mode."
	if state.manual_max < state.manual_min: return "Manual maximum is below minimum."
	if state.cyclic and (state.logarithmic or state.manual_max <= state.manual_min): return "Cyclic mapping requires a nonzero linear period."
	if state.logarithmic and viewer._channel_semantics(state.color_channel) == "signed": return "Signed ordinary log scaling is unsupported."
	if not enum_value(state.mode,[0,1,2]) or not enum_value(state.camera.keep_aspect,[0,1]): return "Unknown camera or reserved display mode."
	if not enum_value(state.viewport.msaa_3d,[0,1,2,3]) or not enum_value(state.viewport.screen_space_aa,[0,1,2]) or state.viewport.scaling_3d_scale <= 0 or state.viewport.scaling_3d_scale > 2: return "Invalid viewport quality."
	if state.gamma <= 0 or state.point_scale <= 0 or state.brightness_scale < 0: return "Invalid display scale."
	if state.panel_width < 290 or state.panel_width > 600: return "Inspector width must be 290–600."
	if not state.camera.has_all(["fov","near","far","keep_aspect"]) or state.camera.fov < 1 or state.camera.fov > 179 or state.camera.near <= 0 or state.camera.far <= state.camera.near: return "Invalid camera settings."
	var basis := Basis(Visual.vector(state.camera_transform[0]),Visual.vector(state.camera_transform[1]),Visual.vector(state.camera_transform[2]))
	if absf(basis.determinant()) < 1e-8: return "Singular camera transform."
	if not state.hidden_types is Array or state.hidden_types.size() > 10000: return "Invalid type filters."
	for n in state.hidden_types:
		if not numeric(n) or n < 0 or n > 4294967295 or int(n) != n: return "Invalid category integer."
	if not state.channel_preferences is Dictionary or state.channel_preferences.size() > 256: return "Invalid channel preferences."
	for channel in state.channel_preferences:
		var pref = state.channel_preferences[channel]
		if not channel is String or not pref is Dictionary: return "Invalid channel preference."
		for key in pref:
			if key not in ["normalization_mode","auto_range","manual_min","manual_max","logarithmic","cyclic","colormap_name","invert_map","clamp_map","range_interval"] or (key != "range_interval" and not shape(pref[key],model[key])): return "Invalid remembered mapping."
	if not state.range_interval is Dictionary: return "Invalid interval provenance."
	for pref in state.channel_preferences.values():
		if pref.has("range_interval") and not pref.range_interval is Dictionary: return "Invalid remembered interval."
		if pref.get("normalization_mode","frame") not in Normalization.MODES or pref.get("colormap_name","viridis") not in viewer.colormaps: return "Unknown remembered mapping."
	if not state.range_interval.is_empty():
		if not state.range_interval.has_all(["start","end","channel","samples"]): return "Missing interval provenance."
		if not numeric(state.range_interval.start) or not numeric(state.range_interval.end) or state.range_interval.end < state.range_interval.start or not state.range_interval.channel is String or not numeric(state.range_interval.samples): return "Invalid range interval."
	if viewer.scene_layers != null:
		var problem: String = viewer.scene_layers.validate_state(state.get("scene"),requested_time)
		if not problem.is_empty():return problem
	return Geometry.validate(state.geometry_override)

static func restore(viewer, recipe: Dictionary) -> String:
	if recipe.get("version") != VERSION: return "Unsupported inspection version; use a native scene recipe."
	return restore_scene(viewer,recipe)

static func restore_scene(viewer, recipe: Dictionary) -> String:
	if viewer.inspection_busy:return "An inspection capture is in progress."
	if viewer.scene_layers == null or recipe.get("kind") != "simscope-inspection":return "Open the SIMSCP4 scene first."
	if not recipe.get("source") is Dictionary or not recipe.get("visual") is Dictionary or not recipe.get("sample") is Dictionary:return "Missing scene inspection state."
	var source: Dictionary = recipe.source
	if preload("res://video/source_identity.gd").is_local(source):
		if not preload("res://video/source_identity.gd").matches(viewer.generic_reader,source):return "Local export source changed; no state applied."
	else:
		if not source.get("committed_bytes") is String or not source.committed_bytes.is_valid_int() or not source.get("sha256") is String or source.get("format") != "SIMSCP4":return "Invalid scene source identity."
		if digest(viewer.capture_path,int(source.committed_bytes)) != source.sha256:return "Scene source identity mismatch; no state applied."
	if not recipe.get("layers") is Array or recipe.layers.size() != viewer.generic_reader.objects.size():return "Scene layer manifest differs."
	var seen := {}
	for layer in recipe.layers:
		if not layer is Dictionary or not viewer.generic_reader.objects.has(layer.get("id")) or seen.has(layer.id) or layer.get("kind") != viewer.generic_reader.objects[layer.id].kind:return "Unknown/duplicate scene layer."
		seen[layer.id] = true
	if recipe.get("selections",[]) != []:return "Selections are not yet supported."
	var time = recipe.sample.get("requested_time")
	if not numeric(time) or not viewer._ensure_timeline() or viewer.shared_timeline.bracket(time).is_empty():return "Scene time unavailable."
	var invalid := validate_visual(viewer,recipe.visual,time)
	if not invalid.is_empty():return invalid
	for id in viewer.generic_reader.objects:
		var point: Dictionary = viewer.generic_reader.bracket(id,time)
		if point.is_empty():continue
		for index in [point.a,point.b]:
			if viewer.generic_reader.samples[id][index].end > int(source.committed_bytes):return "Layer sample outside inspection extent."
			if viewer.generic_reader.read_sample(id,index).is_empty():return "Layer sample unreadable."
	if recipe.visual.trails_enabled:
		var id: String = viewer.scene_layers.particle_id
		if id.is_empty() or viewer.generic_reader.objects[id].identity != "persistent_i8":return "Trails require explicit particle IDs."
	viewer.playing = false;viewer.inspection_paused = true
	Visual.apply(viewer,recipe.visual)
	if viewer.scene_layers.sample(time).is_empty():return viewer.scene_layers.error
	return ""
