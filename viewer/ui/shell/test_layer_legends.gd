extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var viewer
var output := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 5: await process_frame
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	viewer = Viewer.new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); viewer.set_process(false)
	await settle()
	viewer._open_capture(output.path_join("mixed.ssc")); viewer.playing = false; viewer.orbit_enabled = false
	var layers = viewer.scene_layers
	viewer.color_channel = "value"; viewer.colormap_name = "plasma"; viewer._update_colormap(); viewer._restyle()
	for id in ["mesh0","mesh1"]: layers.states[id].channel = "value"
	layers.states.volume0.colormap = "coolwarm"
	layers.states.volume0.lower = -1.0; layers.states.volume0.upper = 1.0
	layers.states.volume1.volume = false; layers.states.volume1.slice = true; layers.states.volume1.visible = true
	layers.resample(); await settle()
	var collection = viewer.shell.layer_legends
	check(collection.entries.size() == 4 and viewer.legend.visible, "Particles, two fields and two meshes coexist")
	check(viewer.shell.particle_legend_panel.visible and viewer.shell.particle_legend_panel.get_rect().encloses(viewer.legend.get_rect()), "Particle text enclosed by visible card")
	check("Particles • p" in viewer.legend.text and "plasma" in viewer.legend.text, "Particle identity and mapping")
	check("Field • volume0" in collection.entries.volume0.label.text and "coolwarm" in collection.entries.volume0.label.text and "-1" in collection.entries.volume0.label.text, "Field identity and active range")
	check("Mesh • mesh1" in collection.entries.mesh1.label.text, "Additional mesh legend")
	check(collection.entries.volume0.bar.texture == layers.lut("coolwarm"), "Legend uses layer colormap LUT")
	check(collection.size.y <= viewer.shell.legend_available.y*.4+1, "Collection height bounded")
	collection.ensure_control_visible(collection.entries.mesh1.card); await settle()
	check(collection.scroll_vertical > 0, "Overflow legends remain reachable by scrolling")
	collection.scroll_vertical = 0
	check(collection.get_rect().end.y <= viewer.colorbar.position.y-12+1, "Collection clears particle legend")
	check(viewer.legend.get_rect().end.y <= viewer.shell.transport.position.y-12+1, "Initial particle legend clears playback")
	var state: Dictionary = layers.states.duplicate(true)
	var sample: Dictionary = viewer.committed_sample.duplicate(true)
	var keys := {}; for id in layers.views: keys[id] = layers.views[id].key
	layers.panel_controls.volume0.legend.button_pressed = false
	check(not collection.entries.has("volume0") and collection.entries.size() == 3 and viewer.legend.visible, "Field toggle independent")
	check(layers.states == state and viewer.committed_sample == sample, "Legend toggle changes no render settings or sample")
	for id in keys: check(layers.views[id].key == keys[id], "Legend toggle preserves prepared layer " + id)
	var saved := Visual.snapshot(viewer)
	FileAccess.open(output.path_join("state.json"),FileAccess.WRITE).store_string(JSON.stringify(saved))
	layers.panel_controls.volume0.legend.button_pressed = true
	viewer.show_legend = false; viewer._update_particle_legend()
	check(not viewer.legend.visible and collection.entries.size() == 4, "Particle toggle independent")
	check(not viewer.shell.particle_legend_panel.visible, "Particle card follows legend visibility")
	Visual.apply(viewer,JSON.parse_string(FileAccess.get_file_as_string(output.path_join("state.json"))))
	await settle()
	check(viewer.legend.visible and not collection.entries.has("volume0"), "JSON state roundtrip restores independent preferences")
	check(not layers.panel_controls.volume0.legend.button_pressed, "Restored control synchronized")
	var legacy: Dictionary = saved.scene.duplicate(true); legacy.erase("legend_visibility")
	check(layers.validate_state(legacy).is_empty(), "Older recipes accepted")
	layers.apply_state(legacy); await settle()
	check(collection.entries.has("volume0"), "Older recipes default eligible field legends on")
	var invalid: Dictionary = layers.snapshot(); invalid.legend_visibility = {"volume0":"yes"}
	check(not layers.validate_state(invalid).is_empty(), "Malformed legend preferences rejected")
	layers.states.volume0.lower = .1; layers.states.volume0.upper = 2.0
	layers.states.volume0.color_mapping.normalization = "log"; layers.resample(); await settle()
	check(not collection.entries.has("volume0"), "Unavailable logarithmic field has no misleading legend")
	layers.states.volume0.color_mapping.normalization = "linear"; layers.resample(); await settle()
	check("0.1 → 2.0" in collection.entries.volume0.label.text, "Legend follows changed active display bounds")
	for panels in [false,true]:
		if viewer.overlay_visible != panels: viewer._toggle_overlay()
		await settle()
		check(collection.visible and viewer.legend.visible, "Panel visibility independent")
		check(collection.get_rect().end.x <= viewer.shell.legend_available.x-12+1, "Collection clears right edge")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("multiple-legends.png"))
	viewer.shell.enter_immersive(); await create_timer(.8).timeout
	check(collection.visible and viewer.legend.visible, "Immersive preserves legends")
	check(collection.get_rect().end.x <= root.size.x-12+1 and viewer.legend.get_rect().end.y <= root.size.y-12+1, "Immersive margins")
	viewer.shell.exit_immersive(); await create_timer(.8).timeout
	# Ineligible layers do not leave stale cards.
	layers.states.mesh0.channel = ""; layers.states.mesh1.visible = false
	layers.states.volume1.slice = false; layers.resample(); await settle()
	check(collection.entries.keys() == ["volume0"], "Only eligible visible color-mapped layers remain")
	viewer.particle_layer_visible = false; viewer._update_particle_legend()
	check(not viewer.legend.visible and collection.entries.has("volume0"), "Hidden particle layer has no legend")
	viewer.offline_instance = true; viewer.overlay_visible = false; viewer._update_particle_legend()
	check(not collection.visible and not viewer.legend.visible, "Video overlay-off gate hides legends")
	viewer.overlay_visible = true; viewer._update_particle_legend()
	check(collection.visible, "Video overlay-on gate restores enabled legends")
	viewer.offline_instance = false
	var report := {"checks":checks,"failures":failures}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	print("LAYER LEGENDS: ",checks," checks; ",failures.size()," failures")
	viewer.free(); await process_frame; quit(0 if failures.is_empty() else 1)
