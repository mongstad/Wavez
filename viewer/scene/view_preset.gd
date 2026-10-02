extends RefCounted
## Portable presentation only. Never resolves a source, sample, selection or result.
const KIND := "simscope-view-preset"
const VERSION := 1
const MAX_BYTES := 65536
const Visual = preload("res://scene/visual_state.gd")
# bool, finite numeric interval, enum, or fixed-size vector/transform.
const VIEW := {
	"point_scale":[0.1,8.0], "exposure":[0.05,3.0], "clean_view":true,
	"brightness_scale":[0.0,5.0], "gamma":[0.2,3.0],
	"orbit_enabled":true, "orbit_speed":[-0.5,0.5], "free_camera":true,
	"yaw":[-1e9,1e9], "pitch":[-1e9,1e9], "camera_distance":[0.000001,1e15],
	"camera_target":"vec3", "camera_transform":"transform"
}
const PARTICLES := {
	"colormap_name":"colormap", "normalization_mode":["frame","symmetric","manual"],
	"manual_min":[-1e30,1e30], "manual_max":[-1e30,1e30], "logarithmic":true,
	"cyclic":true, "invert_map":true, "clamp_map":true, "show_legend":true
}
const ENVIRONMENT := {
	"glow_enabled":true,"glow_intensity":[0.0,2.0],"glow_strength":[0.0,16.0],"glow_bloom":[0.0,1.0],
	"fog_enabled":true,"fog_density":[0.0,1.0],"tonemap_mode":[0,1,2,3,4],
	"tonemap_exposure":[0.0,16.0],"tonemap_white":[0.001,16.0],"background_mode":[0,1,2],
	"background_color":"color"
}
const CAMERA := {"fov":[1.0,179.0],"near":[0.000001,1e12],"far":[0.00001,1e15],"keep_aspect":[0,1]}
const QUALITY := {"msaa_3d":[0,1,2,3],"screen_space_aa":[0,1],"use_taa":true,"use_debanding":true,"scaling_3d_scale":[0.25,2.0]}
const LAYER := {"colormap":"colormap","lower":[-1e30,1e30],"upper":[-1e30,1e30],"legend":true}
const VOLUME := {"opacity":[0.0,10.0],"step":[0.05,10.0],"normalization":["linear","log"],"opacity_mode":["linear","magnitude"],"opacity_lower":[-1e30,1e30],"opacity_upper":[-1e30,1e30]}

static func schemas() -> Dictionary:
	var volume := LAYER.duplicate();volume.merge(VOLUME)
	var mesh := LAYER.duplicate();mesh.wireframe = true
	return {"view":VIEW,"particles":PARTICLES,"environment":ENVIRONMENT,"camera":CAMERA,"quality":QUALITY,"volume":volume,"mesh":mesh}

static func selected(viewer, kind: String) -> String:
	if viewer.scene_layers == null:return ""
	return viewer.scene_layers.selected_objects.get(kind,"")

static func snapshot(viewer) -> Dictionary:
	var groups := {"view":{},"particles":{},"environment":{},"camera":{},"quality":{}}
	for key in VIEW:
		match key:
			"camera_target":groups.view[key] = Visual.vec(viewer.camera_target)
			"camera_transform":
				var t: Transform3D = viewer.camera.transform
				groups.view[key] = [Visual.vec(t.basis.x),Visual.vec(t.basis.y),Visual.vec(t.basis.z),Visual.vec(t.origin)]
			_:groups.view[key] = viewer.get(key)
	for key in PARTICLES:groups.particles[key] = viewer.get(key)
	# An interval's resolved numeric bounds are portable; its source/time provenance is not.
	if groups.particles.normalization_mode == "interval":groups.particles.normalization_mode = "manual"
	for key in ENVIRONMENT:
		var value = viewer.environment.get(key)
		groups.environment[key] = [value.r,value.g,value.b,value.a] if value is Color else value
	for key in CAMERA:groups.camera[key] = viewer.camera.get(key)
	for key in QUALITY:groups.quality[key] = viewer.get_viewport().get(key)
	for kind in ["volume","mesh"]:
		var id := selected(viewer,kind)
		if id.is_empty():continue
		var layers = viewer.scene_layers
		var state: Dictionary = layers.states[id]
		var data := {"colormap":state.colormap,"lower":state.lower,"upper":state.upper,"legend":layers.legend_visibility.get(id,false)}
		if kind == "mesh":data.wireframe = state.wireframe
		else:
			data.merge({"opacity":state.opacity,"step":state.step,"normalization":state.color_mapping.normalization,
				"opacity_mode":state.opacity_mapping.mode,"opacity_lower":state.opacity_mapping.lower,"opacity_upper":state.opacity_mapping.upper})
		groups[kind] = data
	return {"kind":KIND,"version":VERSION,"settings":groups}

static func numeric(value) -> bool:return (value is int or value is float) and is_finite(value)
static func valid(value, rule, viewer) -> bool:
	if rule is bool:return value is bool
	if rule is Array:
		if rule.size() == 2 and rule[0] is float:return numeric(value) and value >= rule[0] and value <= rule[1]
		return (value is String and value in rule) or (numeric(value) and value == int(value) and int(value) in rule)
	if rule == "colormap":return value is String and viewer.colormaps.has(value)
	if rule == "transform":
		if not value is Array or value.size() != 4:return false
		for row in value:
			if not valid(row,"vec3",viewer):return false
		var determinant := Basis(Visual.vector(value[0]),Visual.vector(value[1]),Visual.vector(value[2])).determinant()
		return is_finite(determinant) and absf(determinant) > 1e-8
	if rule in ["vec3","color"]:
		if not value is Array or value.size() != (3 if rule == "vec3" else 4):return false
		for v in value:
			if not numeric(v) or absf(v)>1e15 or (rule == "color" and (v<0 or v>1)):return false
		return true
	return false

static func prepare(viewer, recipe) -> Dictionary:
	var result := {"error":"","skipped":[],"settings":{}}
	if not recipe is Dictionary or recipe.get("kind") != KIND or recipe.get("version") != VERSION or not recipe.get("settings") is Dictionary:
		result.error = "Choose a WAVEZ view preset (version 1). Inspection bundles are not view presets.";return result
	var rules := schemas()
	var model: Dictionary = snapshot(viewer).settings
	# Validate every known value before changing any live state, even for absent layers.
	for group in recipe.settings:
		if not rules.has(group):result.skipped.append(str(group));continue
		var incoming = recipe.settings[group]
		if not incoming is Dictionary:result.error = "Invalid settings group: "+group;return result
		var values: Dictionary = model.get(group,{})
		for key in incoming:
			if not rules[group].has(key):result.skipped.append(group+"."+str(key));continue
			if rules[group][key] is String and rules[group][key] == "colormap" and incoming[key] is String and not viewer.colormaps.has(incoming[key]):
				result.skipped.append(group+"."+key+" (colormap unavailable)");continue
			if not valid(incoming[key],rules[group][key],viewer):result.error = "Invalid preset value: "+group+"."+key;return result
			values[key] = incoming[key]
		# Unavailable optional kinds are skipped, never mapped to a similarly named object.
		if group in ["volume","mesh"] and selected(viewer,group).is_empty():result.skipped.append(group+" (no selected compatible object)");continue
		if group == "particles" and (viewer.scene_layers == null or viewer.scene_layers.particle_id.is_empty()):result.skipped.append("particles (not available)");continue
		if group == "camera" and values.far <= values.near:result.error = "Camera far must exceed near.";return result
		if group == "particles":
			if values.manual_max < values.manual_min or (values.cyclic and (values.logarithmic or values.manual_max <= values.manual_min)):
				result.error = "Invalid particle range or cyclic mapping.";return result
			if values.logarithmic and (viewer._channel_semantics(viewer.color_channel) == "signed" or values.normalization_mode == "symmetric"):
				values.logarithmic = false;result.skipped.append("particle log (current channel incompatible)")
		if group in ["volume","mesh"]:
			if values.upper <= values.lower:result.error = "Layer upper bound must exceed lower bound.";return result
			if group == "volume":
				var candidate: Dictionary = viewer.scene_layers.states[selected(viewer,group)].duplicate(true)
				candidate.lower = values.lower;candidate.upper = values.upper
				candidate.color_mapping = preload("res://layers/volume_color.gd").DEFAULT.duplicate();candidate.color_mapping.normalization = values.normalization
				var problem := preload("res://layers/volume_color.gd").validate(candidate)
				if problem.is_empty():problem = preload("res://layers/volume_opacity.gd").validate({"mode":values.opacity_mode,"lower":values.opacity_lower,"upper":values.opacity_upper})
				if not problem.is_empty():result.error = problem;return result
				var view = viewer.scene_layers.views[selected(viewer,group)]
				if not preload("res://layers/volume_color.gd").sample_problem(candidate,view.color_stats).is_empty():
					values.normalization = "linear";result.skipped.append("volume log (current sample incompatible)")
		result.settings[group] = values
	return result

static func apply(viewer, recipe) -> Dictionary:
	var plan := prepare(viewer,recipe)
	if not plan.error.is_empty():return plan
	var s: Dictionary = plan.settings
	for key in s.get("view",{}):
		var value = s.view[key]
		match key:
			"camera_target":viewer.camera_target = Visual.vector(value)
			"camera_transform":viewer.camera.transform = Transform3D(Basis(Visual.vector(value[0]),Visual.vector(value[1]),Visual.vector(value[2])),Visual.vector(value[3]))
			_:viewer.set(key,value)
	for key in s.get("particles",{}):viewer.set(key,s.particles[key])
	if s.has("particles"):
		viewer.auto_range = viewer.normalization_mode in ["frame","symmetric"]
		viewer.range_interval.clear()
	for key in s.get("environment",{}):
		var v = s.environment[key];viewer.environment.set(key,Color(v[0],v[1],v[2],v[3]) if key == "background_color" else v)
	for key in s.get("camera",{}):viewer.camera.set(key,s.camera[key])
	for key in s.get("quality",{}):
		if RenderingServer.get_current_rendering_method() == "gl_compatibility" and key in ["use_taa","use_debanding"]:
			plan.skipped.append("quality."+key+" (renderer unsupported)");continue
		viewer.get_viewport().set(key,s.quality[key])
	var layers = viewer.scene_layers
	for kind in ["volume","mesh"]:
		if not s.has(kind):continue
		var id := selected(viewer,kind);var data: Dictionary = s[kind];var state: Dictionary = layers.states[id]
		for key in ["lower","upper","colormap"]:state[key] = data[key]
		layers.legend_visibility[id] = data.legend
		if kind == "mesh":state.wireframe = data.wireframe
		else:
			state.opacity = data.opacity;state.step = data.step
			state.color_mapping = preload("res://layers/volume_color.gd").DEFAULT.duplicate();state.color_mapping.normalization = data.normalization
			state.opacity_mapping = {"mode":data.opacity_mode,"lower":data.opacity_lower,"upper":data.opacity_upper}
		layers.sync_preset_controls(id)
	viewer.glow_slider.editable = viewer.environment.glow_enabled
	viewer._update_colormap();viewer._restyle()
	var sliders := {"Exposure":"exposure","Particle size":"point_scale","Brightness":"brightness_scale","Gamma":"gamma","Orbit speed • radians / second":"orbit_speed"}
	for title in sliders:
		if viewer.visual_sliders.has(title):viewer.visual_sliders[title].set_value_no_signal(viewer.get(sliders[title]))
	viewer.glow_slider.set_value_no_signal(viewer.environment.glow_intensity)
	for i in viewer.colormap_option.item_count:
		if viewer.colormap_option.get_item_text(i) == viewer.colormap_name:viewer.colormap_option.select(i)
	for i in viewer.manual_spins.size():viewer.manual_spins[i].set_value_no_signal(viewer.manual_min if i == 0 else viewer.manual_max)
	return plan
