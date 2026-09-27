extends SceneTree
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var viewer
var output := ""
var layout_evidence := {}
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
	check(viewer.legend.get_theme_font("font") == collection.entries.volume0.label.get_theme_font("font") and viewer.legend.get_theme_font_size("font_size") == collection.entries.volume0.label.get_theme_font_size("font_size"), "All legends share font and size")
	var card: Rect2 = viewer.shell.particle_legend_panel.get_rect()
	check(is_equal_approx(viewer.overlay_panel.position.x-card.end.x,12.0) and is_equal_approx(viewer.shell.transport.position.y-card.end.y,12.0), "Horizontal gap matches unchanged 12-pixel vertical gap")
	check(viewer.shell.particle_legend_panel.visible and viewer.shell.particle_legend_panel.get_rect().encloses(viewer.legend.get_rect()), "Particle text enclosed by visible card")
	check("Object: p" in viewer.legend.text and "plasma" in viewer.legend.text, "Particle identity and mapping")
	check("Object: volume0" in collection.entries.volume0.label.text and "coolwarm" in collection.entries.volume0.label.text and "-1" in collection.entries.volume0.label.text, "Field identity and active range")
	check("Object: mesh1" in collection.entries.mesh1.label.text, "Additional mesh legend")
	for id in collection.entries:
		var text: String = collection.entries[id].label.text
		check(text.contains("Object: "+id) and text.contains("Channel: ") and text.contains("Colormap: ") and text.contains("Color range: ") and text.contains("(linear)"),"Explicit labeled content for "+id)
		check(collection.entries[id].label.get_line_count() == 2 and collection.entries[id].card.size.y <= 80,"Two-row compact card for "+id)
	check(viewer.legend.get_line_count() == 3 and viewer.legend.text.contains("Range policy: Automatic • per frame"),"Particle policy remains distinct in a compact third row")
	check(collection.stack.get_theme_constant("separation") == 6,"Subtle six-pixel card spacing")
	for id in collection.entries:
		check(is_equal_approx(collection.entries[id].card.size.x,card.size.x),"Layer and particle card widths match: "+id)
		check(is_equal_approx(collection.entries[id].card.global_position.x,viewer.shell.particle_legend_panel.global_position.x),"Layer and particle left edges match: "+id)
	layout_evidence.field_card_width = collection.entries.volume0.card.size.x
	layout_evidence.particle_card_width = card.size.x
	layout_evidence.field_card_height = collection.entries.volume0.card.size.y
	layout_evidence.particle_card_height = viewer.shell.particle_legend_panel.size.y
	check(collection.entries.volume0.bar.texture == layers.lut("coolwarm"), "Legend uses layer colormap LUT")
	check(collection.size.y <= viewer.shell.legend_available.y*.4+1, "Collection height bounded")
	collection.ensure_control_visible(collection.entries.mesh1.card); await settle()
	check(collection.scroll_vertical > 0 if collection.stack.size.y > collection.size.y else collection.scroll_vertical == 0, "Compact stack scrolls only when content exceeds available height")
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
	layers.states.volume0.channel = "other";layers.states.volume0.colormap = "plasma"
	layers.states.volume0.color_mapping.normalization = "log";layers.resample();await settle()
	check(collection.entries.volume0.label.text.contains("Channel: other") and collection.entries.volume0.label.text.contains("Colormap: plasma") and collection.entries.volume0.label.text.contains("(log)"),"Valid logarithmic channel and changed colormap update labeled content")
	check(layers.object_choices.volume.get_item_text(0).contains("volume0") and collection.entries.volume0.label.text.contains("Object: volume0"),"Legend object terminology agrees with panel selector")
	layers.states.volume0.channel = "value";layers.states.volume0.colormap = "coolwarm"
	layers.states.volume0.color_mapping.normalization = "linear";layers.resample();await settle()
	for mode in viewer.Normalization.MODES:
		viewer.normalization_mode = mode;viewer.auto_range = mode in ["frame","symmetric"];viewer._update_particle_legend()
		check(viewer.legend.text.contains(viewer.Normalization.LABELS[viewer.Normalization.MODES.find(mode)]),"Particle policy matches panel wording: "+mode)
	viewer.normalization_mode = "frame";viewer.auto_range = true
	viewer.cyclic = true;viewer._update_particle_legend();check(viewer.legend.text.contains("(cyclic)"),"Cyclic mapping is explicit")
	viewer.cyclic = false;viewer._update_particle_legend()
	for dimensions in [Vector2i(1024,640),Vector2i(1440,900)]:
		root.size = dimensions;await settle();viewer.shell.layout();await settle()
		check(collection.get_rect().position.x >= 0 and collection.get_rect().end.x <= viewer.shell.legend_available.x-12+1,"Stack width stays within viewport at "+str(dimensions))
		check(viewer.shell.particle_legend_panel.get_rect().end.y <= viewer.shell.transport.position.y-12+1,"Compact particle card clears transport at "+str(dimensions))
		collection.ensure_control_visible(collection.entries.mesh1.card);await settle()
		check(collection.scroll_vertical > 0,"Overflow is scrollable at "+str(dimensions))
		collection.scroll_vertical = 0
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
	await settle()
	check(is_equal_approx(collection.entries.volume0.card.size.x,viewer.shell.particle_legend_panel.size.x),"Single layer retains matching card width without scrollbar")
	check(collection.entries.size() == 1 and collection.size.y <= 80,"Single field remains a compact two-row card")
	var compact_height: float = collection.size.y
	var compact_bottom: float = collection.get_rect().end.y
	var original: String = collection.entries.volume0.label.text
	collection.entries.volume0.label.text = preload("res://ui/shell/legend_text.gd").content("long_scientific_object_identifier_for_display","long_scientific_channel_identifier_for_display","coolwarm","-123456789.0 → 123456789.0","linear")
	await settle()
	check(collection.size.y > compact_height and is_equal_approx(collection.get_rect().end.y,compact_bottom),"Long content wraps and grows upward from the same bottom edge")
	check(collection.entries.volume0.label.get_visible_line_count() == collection.entries.volume0.label.get_line_count(),"Long labeled values remain visible without truncation")
	collection.entries.volume0.label.text = original;await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("single-field.png"))
	viewer.offline_instance = true; viewer.overlay_visible = false; viewer._update_particle_legend()
	check(not collection.visible and not viewer.legend.visible, "Video overlay-off gate hides legends")
	viewer.overlay_visible = true; viewer._update_particle_legend()
	check(collection.visible, "Video overlay-on gate restores enabled legends")
	viewer.offline_instance = false
	var report := {"checks":checks,"failures":failures,"layout":layout_evidence}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report))
	print("LAYER LEGENDS: ",checks," checks; ",failures.size()," failures")
	viewer.free(); await process_frame; quit(0 if failures.is_empty() else 1)
