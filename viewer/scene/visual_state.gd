extends RefCounted
# One visual snapshot/apply path. RenderJob retains backward-compatible wrappers.
const STATE_KEYS := ["mode", "observer_scale", "point_scale", "exposure", "intensity_floor", "clean_view", "slice_enabled", "slice_x", "color_channel", "size_channel", "brightness_channel", "colormap_name", "auto_range", "logarithmic", "invert_map", "clamp_map", "manual_min", "manual_max", "show_legend", "brightness_scale", "gamma", "panel_width", "trails_enabled", "orbit_enabled", "orbit_speed", "yaw", "pitch", "camera_distance", "playback_fps", "overlay_visible", "normalization_mode", "cyclic", "range_interval", "channel_preferences", "time_mode", "physical_rate", "particle_layer_visible", "geometry_override", "guide_visibility"]

static func vec(v: Vector3) -> Array: return [v.x, v.y, v.z]
static func vector(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])

static func snapshot(viewer) -> Dictionary:
	var state := {}
	for key in STATE_KEYS: state[key] = viewer.get(key)
	state.camera_target = vec(viewer.camera_target)
	var t: Transform3D = viewer.camera.transform
	state.camera_transform = [vec(t.basis.x), vec(t.basis.y), vec(t.basis.z), vec(t.origin)]
	state.camera = {"fov":viewer.camera.fov, "near":viewer.camera.near, "far":viewer.camera.far, "keep_aspect":viewer.camera.keep_aspect}
	state.hidden_types = viewer.hidden_types.keys()
	state.guide_visible = viewer.guide_mesh.visible
	state.starfield_visible = viewer.starfield.visible
	state.preset = viewer.preset_option.get_item_text(viewer.preset_option.selected)
	state.sliders = {}
	for name in viewer.visual_sliders: state.sliders[name] = viewer.visual_sliders[name].value
	# Existing native scene recipes include this inert field. Keep their state shape
	# readable without recreating the retired spectrum controls.
	state.sliders["Intensity cutoff"] = viewer.intensity_floor
	state.sections = {}
	for name in viewer.sections: state.sections[name] = viewer.sections[name].visible
	state.environment = {}
	for key in ["glow_enabled", "glow_intensity", "glow_strength", "glow_bloom", "fog_enabled", "fog_density", "tonemap_mode", "tonemap_exposure", "tonemap_white", "background_mode"]:
		state.environment[key] = viewer.environment.get(key)
	state.viewport = {}
	for key in ["msaa_3d", "screen_space_aa", "use_taa", "use_debanding", "scaling_3d_scale"]:
		state.viewport[key] = viewer.get_viewport().get(key)
	if viewer.scene_layers != null:state.scene = viewer.scene_layers.snapshot()
	return state.duplicate(true)

static func apply(viewer, state: Dictionary) -> void:
	state = state.duplicate(true)
	viewer._set_clean(state.get("clean_view", false))
	for key in STATE_KEYS:
		if state.has(key): viewer.set(key, state[key])
	viewer.camera_target = vector(state.camera_target)
	var a: Array = state.camera_transform
	viewer.camera.transform = Transform3D(Basis(vector(a[0]), vector(a[1]), vector(a[2])), vector(a[3]))
	for key in state.camera: viewer.camera.set(key, state.camera[key])
	viewer.hidden_types.clear()
	for value in state.get("hidden_types", []): viewer.hidden_types[int(value)] = true
	viewer.guide_mesh.visible = state.get("guide_visible", false)
	viewer.starfield.visible = state.get("starfield_visible", not viewer.clean_view)
	for key in state.get("environment", {}): viewer.environment.set(key, state.environment[key])
	for key in state.get("viewport", {}): viewer.get_viewport().set(key, state.viewport[key])
	for name in state.get("sections", {}):
		if viewer.sections.has(name): viewer.sections[name].visible = state.sections[name]
	viewer.overlay_panel.visible = viewer.overlay_visible
	viewer.show_panel_button.visible = not viewer.overlay_visible and not viewer.offline_instance
	viewer.resize_handle.visible = viewer.overlay_visible and not viewer.offline_instance
	viewer.channel_signature = ""
	viewer._refresh_mapping_options()
	viewer._update_colormap()
	viewer._restyle()
	for i in range(viewer.colormap_option.item_count):
		if viewer.colormap_option.get_item_text(i) == viewer.colormap_name: viewer.colormap_option.select(i)
	for i in range(viewer.preset_option.item_count):
		if viewer.preset_option.get_item_text(i) == state.get("preset", ""): viewer.preset_option.select(i)
	for name in state.get("sliders", {}):
		if viewer.visual_sliders.has(name): viewer.visual_sliders[name].set_value_no_signal(state.sliders[name])
	for i in range(viewer.manual_spins.size()): viewer.manual_spins[i].set_value_no_signal(viewer.manual_min if i == 0 else viewer.manual_max)
	viewer._layout_inspector(viewer.resize_handle)
	viewer._apply_geometry()
	viewer._sync_inspection_controls()
	if viewer.scene_layers != null and state.has("scene"):viewer.scene_layers.apply_state(state.scene)

