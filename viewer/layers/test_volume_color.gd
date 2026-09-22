extends SceneTree
const ColorMapping = preload("res://layers/volume_color.gd")
const Job = preload("res://video/render_job.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Hash = preload("res://data/capture_index.gd")
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
func wait_range() -> void:
	var began := Time.get_ticks_msec()
	while viewer.scene_layers.range_thread.is_started() and Time.get_ticks_msec()-began<30000:await process_frame
	check(not viewer.scene_layers.range_thread.is_started(),"range worker completes")
func render(name: String) -> Image:
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image();check(image.save_png(job.output.path_join(name+".png")) == OK,name+" saved")
	return image
func range_equal(a: float, b: float) -> bool:return absf(a-b)<=1e-12*maxf(1.,absf(b))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--color-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--color-job=")))
	if job.is_empty():quit(1);return
	create_timer(160).timeout.connect(func():push_error("Color regression timeout");quit(1))
	vp = SubViewport.new();vp.size = Vector2i(960,640);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	viewer = load("res://main.gd").new();viewer.offline_instance = true;viewer.capture_path = job.capture;vp.add_child(viewer);viewer.set_process(false);viewer.playing = false;viewer.orbit_enabled = false
	viewer._apply_preset("Scientific");viewer.overlay_visible = false;viewer.show_legend = false;viewer.overlay_panel.hide();viewer.shell.prepare_export({});viewer.legend.hide();viewer.colorbar.hide();viewer.particle_layer_visible = false
	var layers = viewer.scene_layers;var id: String = job.field
	var initial: Dictionary = layers.states[id].duplicate(true)
	for channel in job.oracles:
		var oracle: Dictionary = job.oracles[channel]
		layers.states[id] = initial.duplicate(true);layers.states[id].channel = channel
		layers.states[id].opacity_mapping = {"mode":"magnitude","lower":0.,"upper":oracle.bound}
		layers.states[id].colormap = "viridis" if channel == "density" else "coolwarm"
		layers.sample(job.time)
		var grid = layers.views[id]
		check(Hash.digest(grid.data.channels[channel].to_byte_array()) == oracle.sha256,channel+" source hash")
		var point := Vector3(oracle.probe_world[0],oracle.probe_world[1],oracle.probe_world[2])
		var source_probe = grid.probe(point)
		check(source_probe != null and absf(source_probe-oracle.probe_value)<1e-7,channel+" Python source probe")
		var opacity: Dictionary = layers.states[id].opacity_mapping.duplicate()
		for policy in ["symmetric","percentile"]:
			check(layers.request_color_range(id,policy,1.,99.),channel+" requests "+policy)
			await wait_range()
			var state: Dictionary = layers.states[id]
			var expected: Array = [-oracle.bound,oracle.bound] if policy == "symmetric" else oracle.percentiles
			check(range_equal(state.lower,expected[0]) and range_equal(state.upper,expected[1]),channel+" "+policy+" matches NumPy oracle")
			check(state.color_mapping.policy == policy and state.color_mapping.source_channel == channel and state.color_mapping.source_time == job.time,channel+" derivation provenance")
			check(state.opacity_mapping == opacity,channel+" opacity unchanged")
			check(layers.color_controls[id].status.text.contains("fixed across playback") and layers.color_controls[id].status.text.contains("Clipping:"),channel+" frozen/clipping disclosure")
			if policy == "percentile":check(layers.color_controls[id].status.text.contains("COLOR CLIPPING PRESENT") == bool(oracle.percentile_clips),channel+" actual clipping agrees with NumPy")
			check(not layers.color_controls[id].status.visible and layers.color_controls[id].indicator.visible == layers.color_controls[id].status.text.contains("COLOR CLIPPING PRESENT"),channel+" concise warning agrees with detailed clipping diagnostics")
			var mapping: Dictionary = state.color_mapping.duplicate(true);var bounds := [state.lower,state.upper]
			layers.sample(0.);check([layers.states[id].lower,layers.states[id].upper] == bounds and layers.states[id].color_mapping == mapping,channel+" frozen across seek")
			layers.sample(job.time)
			var image := await render(channel+"-"+policy)
			var recipe: Dictionary = Inspection.snapshot(viewer) if job.synthetic else {"visual":Job.snapshot(viewer)}
			layers.states[id].lower = 0.;layers.states[id].upper = 1.;layers.states[id].color_mapping = ColorMapping.DEFAULT.duplicate()
			var parsed: Dictionary = JSON.parse_string(JSON.stringify(recipe,"",true,true))
			var restore_error := Inspection.restore(viewer,parsed) if job.synthetic else Inspection.validate_visual(viewer,parsed.visual)
			if not job.synthetic and restore_error.is_empty():Job.apply(viewer,parsed.visual)
			check(restore_error.is_empty(),channel+" "+policy+" serialized state restores")
			check(range_equal(layers.states[id].lower,bounds[0]) and range_equal(layers.states[id].upper,bounds[1]) and layers.states[id].color_mapping == mapping,channel+" restored exact policy/bounds")
			var replay := await render(channel+"-"+policy+"-replay")
			check(replay.get_data() == image.get_data(),channel+" "+policy+" replay pixels")
			check(grid.probe(point) == source_probe and grid.data.time == job.time and Hash.digest(grid.data.channels[channel].to_byte_array()) == oracle.sha256,channel+" source/probe/time invariant")
			cases.append({"channel":channel,"policy":policy,"bounds":bounds,"mapping":mapping,"opacity":opacity,"probe":source_probe})
			if channel == "density" and policy == "percentile":
				Job.write_json(job.output.path_join("export-state.json"),Job.snapshot(viewer))
				viewer.shell.toggle_dock();viewer.shell.refresh_export();layers.layer_settings_buttons[id].button_pressed = true
				for i in 5:await process_frame
				var scroll: ScrollContainer = viewer.shell.scroll
				scroll.scroll_vertical += int(layers.color_controls[id].mode.global_position.y-scroll.global_position.y)-90
				await render("controls")
				viewer.overlay_visible = false;viewer.overlay_panel.hide();viewer.shell.prepare_export({})
		# Signed source rejects logarithmic display even if the bounds are positive.
		layers.states[id].lower = .01;layers.states[id].upper = oracle.bound;layers.states[id].color_mapping.policy = "manual"
		if channel != "density":check(not layers._set_color_normalization(id,"log"),channel+" log refused on signed source")
		else:
			var permitted: bool = layers._set_color_normalization(id,"log")
			check(permitted == bool(oracle.log_valid),"density log validity agrees with source oracle")
			if permitted:await render("density-log")
		layers.states[id].color_mapping.normalization = "linear"
		layers.color_controls[id].reset.pressed.emit()
		check(layers.states[id].lower == 0. and layers.states[id].upper == 1. and layers.states[id].color_mapping == ColorMapping.DEFAULT and layers.states[id].opacity_mapping == opacity,"reset color only")
	# Refuse malformed mappings before any recipe visual mutation.
	var saved: Dictionary = Inspection.snapshot(viewer) if job.synthetic else {"visual":Job.snapshot(viewer)}
	for bad in [{},{"normalization":"bad"},{"percentile_low":99.,"percentile_high":1.},{"normalization":"log"},{"policy":"symmetric"}]:
		var invalid := saved.duplicate(true)
		if bad.is_empty():invalid.visual.scene.layers[id].color_mapping = {}
		else:
			for key in bad:invalid.visual.scene.layers[id].color_mapping[key] = bad[key]
		check(not Inspection.validate_visual(viewer,invalid.visual).is_empty(),"invalid mapping validation refuses "+str(bad))
		check(Job.snapshot(viewer) == saved.visual,"invalid recipe leaves visual state unchanged")
	var legacy := saved.duplicate(true);legacy.visual.scene.layers[id].erase("color_mapping")
	check(Inspection.validate_visual(viewer,legacy.visual).is_empty(),"legacy state accepted as frozen manual linear")
	Job.apply(viewer,legacy.visual)
	check(layers.states[id].color_mapping == ColorMapping.DEFAULT,"legacy color mapping default migration")
	if job.get("synthetic",false):await synthetic_checks(id)
	layers.states[id].visible = false;layers.resample()
	check(not layers.color_controls[id].status.text.contains("Source finite range"),"hidden layer clears stale source statistics disclosure")
	check(not layers.color_controls[id].indicator.visible,"hidden layer clears stale clipping indicator")
	vp.queue_free();await process_frame
	Job.write_json(job.output.path_join("report.json"),{"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"cases":cases})
	print("VOLUME COLOR: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func synthetic_checks(id: String) -> void:
	var finite_test := PackedFloat64Array([NAN,-2.,0.,4.,INF])
	var finite_hash := Hash.digest(finite_test.to_byte_array())
	var derived := ColorMapping.derive(finite_test,"percentile",25.,75.)
	check(derived == {"lower":-1.,"upper":2.},"percentiles exclude nonfinite values and use linear interpolation")
	check(Hash.digest(finite_test.to_byte_array()) == finite_hash,"percentile sorting leaves source order/bytes unchanged")
	check(ColorMapping.derive(PackedFloat64Array([NAN,INF]),"percentile",1.,99.).has("error"),"invalid-only range refused")
	var stats := ColorMapping.statistics(finite_test)
	check(stats.finite == 3 and stats.nonfinite == 2 and stats.nonpositive == 2,"source statistics count finite/nonpositive values")
	var layers = viewer.scene_layers
	layers.states[id].channel = "ten";layers.states[id].color_mapping = ColorMapping.DEFAULT.duplicate();layers.states[id].lower = 1.;layers.states[id].upper = 100.
	layers.sample(0.)
	check(layers._set_color_normalization(id,"log"),"positive constant accepts log")
	var logarithmic := await render("log-midpoint")
	layers.states[id].color_mapping.normalization = "linear";layers.states[id].lower = 0.;layers.states[id].upper = 20.;layers.resample()
	var linear := await render("linear-midpoint")
	# log(10)/log(100) == 10/20: same LUT coordinate and independent opacity.
	check(linear.get_data() == logarithmic.get_data(),"GPU logarithmic midpoint matches linear oracle")
	var grid = layers.views[id]
	layers.states[id].volume = false;layers.states[id].slice = true;layers.states[id].slice_distance = 0.;layers.resample()
	linear = await render("slice-linear")
	layers.states[id].lower = 1.;layers.states[id].upper = 100.;layers._set_color_normalization(id,"log")
	logarithmic = await render("slice-log")
	check(linear.get_data() == logarithmic.get_data(),"slice uses identical logarithmic color semantics")
	layers.states[id].slice = false;layers.states[id].volume = true;layers.states[id].channel = "future_invalid";layers.sample(0.)
	check(grid.color_error.is_empty(),"positive log sample visible")
	Job.write_json(job.output.path_join("invalid-export-state.json"),Job.snapshot(viewer))
	layers.sample(2.)
	check(not grid.color_error.is_empty() and not grid.quad.visible and layers.color_controls[id].status.text.contains("unavailable"),"nonpositive future sample explicitly unavailable")
	check(layers.color_controls[id].indicator.visible and layers.color_controls[id].indicator.text == "⚠ Color unavailable","invalid color sample has concise exception indicator")
	check(grid.probe(Vector3.ZERO) == 0.,"unavailable log view still probes original zero")
	layers.states[id].color_mapping.normalization = "linear";layers.states[id].channel = "ten";layers.sample(0.)
	var before: Dictionary = layers.snapshot()
	check(layers.request_color_range(id,"percentile"),"constant percentile request")
	await wait_range()
	check(layers.snapshot() == before and viewer.status_label.text.contains("constant"),"constant percentile refuses without invented bounds")
	layers.states[id].channel = "density";layers.sample(0.)
	check(layers.request_color_range(id,"percentile"),"obsolete request starts")
	layers.sample(2.);before = layers.snapshot();await wait_range()
	check(layers.snapshot() == before and viewer.status_label.text.contains("discarded"),"stale sample result discarded")
	check(layers._set_range(id,"lower",.1) and layers.states[id].color_mapping.policy == "manual","manual range remains available")
	check(not layers._set_range(id,"upper",.01),"reversed manual range refused")
