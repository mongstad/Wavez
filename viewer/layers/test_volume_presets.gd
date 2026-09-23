extends SceneTree
const Job = preload("res://video/render_job.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Hash = preload("res://data/capture_index.gd")
const Presets = preload("res://layers/volume_presets.gd")
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var viewer
var vp: SubViewport
var job := {}
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func equal(a: float, b: float) -> bool:return absf(a-b)<=1e-12*maxf(1.,absf(b))
func wait_range() -> void:
	var began := Time.get_ticks_msec()
	while viewer.scene_layers.range_thread.is_started() and Time.get_ticks_msec()-began<30000:await process_frame
	check(not viewer.scene_layers.range_thread.is_started(),"preset worker completes")
func render(name: String) -> Image:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	check(image.save_png(job.output.path_join(name+".png")) == OK,name+" image saved")
	return image
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--preset-job=")))
	if job.is_empty():quit(1);return
	create_timer(180).timeout.connect(func():push_error("Preset regression timeout");quit(1))
	vp = SubViewport.new();vp.size = Vector2i(960,640);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	viewer = load("res://main.gd").new();viewer.offline_instance = true;viewer.capture_path = job.capture;vp.add_child(viewer);viewer.set_process(false);viewer.playing = false;viewer.orbit_enabled = false
	viewer._apply_preset("Scientific");viewer.overlay_visible = false;viewer.show_legend = false;viewer.overlay_panel.hide();viewer.shell.prepare_export({});viewer.legend.hide();viewer.colorbar.hide();viewer.particle_layer_visible = false
	var layers = viewer.scene_layers;var id: String = job.field
	var initial: Dictionary = layers.states[id].duplicate(true)
	check(initial.lower == 0. and initial.upper == 1. and initial.opacity_mapping.upper == 1.,"opening defaults unchanged; no automatic preset")
	for channel in job.oracles:
		var oracle: Dictionary = job.oracles[channel]
		layers.states[id] = initial.duplicate(true);layers.states[id].channel = channel
		layers.sample(job.time)
		var grid = layers.views[id]
		var point := Vector3(oracle.probe_world[0],oracle.probe_world[1],oracle.probe_world[2])
		check(equal(grid.probe(point),oracle.probe_value),channel+" independent Python probe oracle")
		var policies := ["dense_core","faint_structure"] if channel == "density" else ["signed_field"]
		for preset in policies:
			var before: Dictionary = Job.snapshot(viewer)
			var bad := "signed_field" if channel == "density" else "dense_core"
			check(not layers.request_volume_preset(id,bad) and Job.snapshot(viewer) == before,"incompatible preset refuses atomically")
			var controls: Dictionary = layers.preset_controls[id]
			var choice: int = Presets.IDS.find(preset)
			controls.choice.select(choice);controls.choice.item_selected.emit(choice)
			check(Job.snapshot(viewer) == before,"choosing an action alone changes no display state")
			check(controls.description.tooltip_text.contains("opacity") and controls.description.tooltip_text.contains("ray step"),"preset changes and preserved controls disclosed before applying")
			if preset == "faint_structure":
				layers.color_controls[id].percentile_low.value = 1.
				layers.color_controls[id].percentile_high.value = 99.
				check(controls.description.tooltip_text.contains("P1.0–P99.0"),"faint action discloses current percentile inputs before Apply")
			controls.apply.pressed.emit();await wait_range()
			var state: Dictionary = layers.states[id]
			var bounds: Array = [oracle.minimum,oracle.maximum] if preset == "dense_core" else (oracle.percentiles if preset == "faint_structure" else [-oracle.bound,oracle.bound])
			check(equal(state.lower,bounds[0]) and equal(state.upper,bounds[1]),preset+" bounds match independent NumPy")
			check(state.color_mapping.normalization == "linear" and state.color_mapping.source_channel == channel and state.color_mapping.source_time == job.time,"explicit linear/frozen provenance")
			check(state.opacity_mapping.mode == ("magnitude" if preset == "signed_field" else "linear") and state.opacity_mapping.lower == 0. and equal(state.opacity_mapping.upper,bounds[1]),"explicit opacity thresholds match oracle")
			check(state.colormap == ("coolwarm" if preset == "signed_field" else "viridis"),"explicit colormap")
			var after: Dictionary = Job.snapshot(viewer)
			for key in ["lower","upper","color_mapping","opacity_mapping","colormap"]:after.scene.layers[id][key] = before.scene.layers[id][key]
			check(after == before,"only five authorized display fields change; camera/step/strength/particles/environment/other layers preserved")
			check(layers.color_controls[id].status.text.contains("COLOR CLIPPING PRESENT") == (oracle.minimum<bounds[0] or oracle.maximum>bounds[1]),"clipping disclosure agrees with source")
			check(layers.color_controls[id].status.text.contains("fixed across playback"),"frozen mapping disclosed")
			var configured: Dictionary = layers.snapshot()
			layers.sample(job.first_time);check(layers.snapshot() == configured,"preset remains frozen across sample changes")
			layers.sample(job.time)
			check(Hash.digest(grid.data.channels[channel].to_byte_array()) == oracle.sha256 and equal(grid.probe(point),oracle.probe_value) and grid.data.time == job.time,"source bytes/probe/timestamp preserved")
			var name: String = channel+"-"+preset
			var image := await render(name)
			Job.write_json(job.output.path_join(name+"-state.json"),Job.snapshot(viewer))
			var recipe: Dictionary = Inspection.snapshot(viewer) if job.synthetic else {"visual":Job.snapshot(viewer)}
			layers.color_controls[id].reset.pressed.emit();layers.opacity_controls[id].reset.pressed.emit()
			var parsed: Dictionary = JSON.parse_string(JSON.stringify(recipe,"",true,true))
			var error := Inspection.restore(viewer,parsed) if job.synthetic else Inspection.validate_visual(viewer,parsed.visual)
			if not job.synthetic and error.is_empty():Job.apply(viewer,parsed.visual)
			check(error.is_empty() and layers.snapshot() == configured,"serialized preset-derived settings restore exactly")
			var replay := await render(name+"-replay")
			check(replay.get_data() == image.get_data(),"recipe reproduces rendered pixels")
			var frozen_opacity: Dictionary = state.opacity_mapping.duplicate()
			check(layers._set_range(id,"upper",bounds[1]*1.1) and layers.states[id].color_mapping.policy == "manual" and layers.states[id].opacity_mapping == frozen_opacity,"manual color remains independent after preset")
			check(layers._set_opacity_mapping(id,"upper",bounds[1]*1.2) and equal(layers.states[id].upper,bounds[1]*1.1),"manual opacity remains independent after preset")
			Job.apply(viewer,parsed.visual)
			cases.append({"channel":channel,"preset":preset,"settings":layers.states[id].duplicate(true)})
	# Explicit percentile input is respected; no hard-coded universal percentile.
	layers.states[id].channel = "density";layers.sample(job.time)
	check(layers.request_volume_preset(id,"faint_structure",5.,95.),"custom percentile preset starts");await wait_range()
	var expected: Array = job.oracles.density.custom_percentiles
	check(equal(layers.states[id].lower,expected[0]) and equal(layers.states[id].upper,expected[1]),"custom percentiles match NumPy")
	var before: Dictionary = layers.snapshot()
	check(not layers.request_volume_preset(id,"faint_structure",99.,1.) and layers.snapshot() == before,"invalid percentile request unchanged")
	check(layers.request_volume_preset(id,"dense_core"),"stale preset request starts")
	layers.sample(job.first_time);before = layers.snapshot();await wait_range()
	check(layers.snapshot() == before and viewer.status_label.text.contains("discarded"),"stale sample result cannot overwrite new state")
	layers.sample(job.time)
	check(layers.request_volume_preset(id,"dense_core"),"edited preset request starts")
	layers.states[id].opacity = .37;before = layers.snapshot();await wait_range()
	check(layers.snapshot() == before and viewer.status_label.text.contains("discarded"),"manual edit while computing invalidates preset")
	# Real particle layer visibility and cinematic environment must survive too.
	viewer._apply_preset("Cinematic");viewer.particle_layer_visible = true;layers.resample()
	var scene_before: Dictionary = Job.snapshot(viewer)
	check(layers.request_volume_preset(id,"dense_core"),"cinematic overlay preset starts");await wait_range()
	var scene_after: Dictionary = Job.snapshot(viewer)
	for key in ["lower","upper","color_mapping","opacity_mapping","colormap"]:scene_after.scene.layers[id][key] = scene_before.scene.layers[id][key]
	check(scene_after == scene_before,"cinematic environment and visible particle layer preserved")
	viewer._apply_preset("Scientific");viewer.particle_layer_visible = false;layers.sample(job.time)
	viewer.shell.toggle_dock();viewer.shell.refresh_export();viewer.shell.select_workspace(1);layers.choose_object("volume",id)
	for i in 5:await process_frame
	var scroll: ScrollContainer = viewer.shell.scroll
	scroll.scroll_vertical += int(layers.preset_controls[id].guide.global_position.y-scroll.global_position.y)-50
	await render("controls")
	layers.preset_controls[id].help.button_pressed = true
	await render("controls-help")
	if job.synthetic:
		layers.states[id].channel = "zero";layers.sample(job.time);before = layers.snapshot()
		for preset in Presets.IDS:check(not layers.request_volume_preset(id,preset) and layers.snapshot() == before,"zero field refuses "+preset)
	vp.queue_free();await process_frame
	Job.write_json(job.output.path_join("report.json"),{"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"cases":cases})
	print("VOLUME PRESETS: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
