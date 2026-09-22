extends SceneTree
const Visual = preload("res://scene/visual_state.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Exact = preload("res://analysis/inspection_v3.gd")
var checks := 0
var failures: Array[String] = []
var inventory: Array = []
var output := ""

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

# v2 is ordinary JSON: allow formatter/parser rounding, but never coerce booleans.
func same(a, b) -> bool:
	if a is bool or b is bool:return a is bool and b is bool and a == b
	if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b)) <= 1e-12*maxf(1,absf(float(a)))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():return false
		for i in range(a.size()):
			if not same(a[i],b[i]):return false
		return true
	return a == b

func compare(expected: Dictionary, actual: Dictionary, label: String) -> void:
	var changed: Array = []
	for key in expected:
		var matches := actual.has(key) and same(expected[key],actual[key])
		check(matches,label+": "+key)
		if not matches:changed.append(key)
	inventory.append({"case":label,"fields":expected.keys(),"mismatches":changed})

func session(viewer) -> Dictionary:
	var layers = viewer.scene_layers
	var expanded := {}
	for id in layers.layer_settings_buttons:expanded[id] = layers.layer_settings_buttons[id].button_pressed
	return {"screenshot_directory":viewer.screenshot_directory,"screenshot_sidecar":viewer.screenshot_sidecar,
		"free_camera":viewer.free_camera,"loop":viewer.scene_loop_playback,"buffer_policy":layers.playback.policy,
		"probe_values":layers.probe_spins.map(func(spin):return spin.value),"probe_text":layers.probe_label.text,
		"probe_volume":layers.selected_volume,"layer_settings":expanded,
		"draft_name":viewer.selection_controller.name_input.text,
		"draft_exact":viewer.selection_controller.predicate_integer.button_pressed}

func change_session(viewer, value: bool) -> void:
	viewer.screenshot_directory = output.path_join("session-destination" if value else "original-destination")
	viewer.control_checks["PNG inspection JSON sidecar"].button_pressed = value
	viewer.free_camera = value; viewer.orbit_enabled = not value
	viewer.scene_loop_playback = value
	viewer.scene_layers.playback.policy = "512" if value else "adaptive"
	for i in range(3):viewer.scene_layers.probe_spins[i].value = (12+i if value else 2+i)
	viewer.scene_layers.probe_label.text = "last probe remains session state" if value else "original probe"
	for id in viewer.scene_layers.layer_settings_buttons:viewer.scene_layers.layer_settings_buttons[id].button_pressed = value
	viewer.selection_controller.name_input.text = "new draft" if value else "old draft"
	viewer.selection_controller.predicate_integer.button_pressed = value

func configure(viewer, preset: String, active: bool) -> void:
	viewer._apply_preset(preset)
	for name in ["Point rendering","Recorded history  [T]","Invert","Show legend","X slice • ±3 simulation units"]:
		viewer.control_checks[name].button_pressed = active
	viewer.orbit_enabled = active
	viewer.guide_mesh.visible = active
	viewer.guide_visibility.domain = active; viewer.guide_visibility.data = active
	for name in viewer.legacy_sections: viewer.legacy_sections[name] = active
	viewer.particle_layer_visible = not active
	viewer._render_current(viewer.phase)
	for name in viewer.section_buttons:viewer.section_buttons[name].button_pressed = active
	viewer.visual_sliders.Exposure.value = 1.2 if active else .8
	viewer.visual_sliders.Bloom.value = .8 if active else .4
	viewer.scene_layers.states.field.volume = active
	viewer.scene_layers.states.field.clip = active
	viewer.scene_layers.states.field.slice = active
	viewer.scene_layers.states.field.opacity_mapping = {"mode":"magnitude" if active else "linear","lower":.125 if active else -.5,"upper":3.75 if active else 20.0}
	viewer.scene_layers.states.field.color_mapping = preload("res://layers/volume_color.gd").DEFAULT.duplicate()
	viewer.scene_layers.states.field.color_mapping.normalization = "log" if active else "linear"
	viewer.scene_layers.states.field.lower = .1 if active else -.5;viewer.scene_layers.states.field.upper = 30. if active else 20.
	viewer.scene_layers.states.mesh.wireframe = active
	viewer.scene_layers.resample()
	viewer._seek_time(.5 if active else 0)
	var field = viewer.scene_layers.views.field
	var policy := "percentile" if active else "symmetric"
	var bounds := preload("res://layers/volume_color.gd").derive(field.data.channels[field.channel],policy,1.,99.)
	viewer.scene_layers.states.field.lower = bounds.lower;viewer.scene_layers.states.field.upper = bounds.upper
	viewer.scene_layers.states.field.color_mapping.policy = policy
	viewer.scene_layers.states.field.color_mapping.source_channel = field.channel;viewer.scene_layers.states.field.color_mapping.source_time = field.data.time
	viewer.scene_layers.resample()

func check_ui(viewer, visual: Dictionary, label: String) -> void:
	check(viewer.scene_layers.color_controls.field.mode.selected == (1 if visual.scene.layers.field.color_mapping.normalization == "log" else 0),label+" color normalization control")
	var mapping: Dictionary = visual.scene.layers.field.opacity_mapping
	var controls: Dictionary = viewer.scene_layers.opacity_controls.field
	check(controls.mode.selected == (1 if mapping.mode == "magnitude" else 0),label+" opacity mode control")
	check(same(controls.lower.text.to_float(),mapping.lower) and same(controls.upper.text.to_float(),mapping.upper),label+" opacity threshold controls")
	for name in visual.sections:
		if viewer.legacy_sections.has(name):
			check(viewer.legacy_sections[name] == visual.sections[name],label+" legacy section state "+name); continue
		check(viewer.sections[name].visible == visual.sections[name],label+" section body "+name)
		check(viewer.section_buttons[name].button_pressed == visual.sections[name],label+" section button "+name)
	var fields := {"Point rendering":"clean_view","Recorded history  [T]":"trails_enabled","Invert":"invert_map","Show legend":"show_legend","X slice • ±3 simulation units":"slice_enabled"}
	for name in fields:check(viewer.control_checks[name].button_pressed == visual[fields[name]],label+" checkbox "+name)
	check(viewer.particle_layer_visible == visual.particle_layer_visible,label+" particle visibility model state")
	check(viewer.glow_slider.editable == viewer.environment.glow_enabled,label+" Bloom availability")
	check(not viewer.playing and viewer.inspection_paused,label+" intentional playback pause")

func wait_jobs(control) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 20000:
		await create_timer(.01).timeout
		if not control.jobs.busy():return control.jobs.error.is_empty()
	return false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recipe-fixture="):output = arg.trim_prefix("--recipe-fixture=")
	if output.is_empty():quit(1);return
	create_timer(120).timeout.connect(func():push_error("Recipe state regression timed out");quit(1))
	var viewer = load("res://main.gd").new()
	viewer.offline_instance = true;root.add_child(viewer);viewer.set_process(false)
	viewer._open_capture(output.path_join("scene.ssc"));viewer.playing = false
	await process_frame
	var source_hash := FileAccess.get_sha256(viewer.capture_path)
	var canonical := Visual.snapshot(viewer)
	check(not canonical.has("time_mode") and not canonical.has("playback_fps"),"Recipe omits retired playback mode and index rate")
	check(not canonical.sliders.has("Playback • frames / second (index mode)"),"Recipe omits retired index-rate slider")
	check(not canonical.sections.has("Playback") and not canonical.sliders.has("Physical time units / second"),"Snapshots omit removed hidden presentation controls")
	var mode_controls := 0
	for option in viewer.shell.transport.find_children("*","OptionButton",true,false):
		for i in range(option.item_count):
			if option.get_item_text(i) in ["Frame index • union samples","Physical time • recorded timestamps","Recorded time","Sample index"]: mode_controls += 1
	check(mode_controls == 0,"Playback-mode selector is not constructed even in offline viewer")
	for obsolete in ["time_mode","playback_fps"]:
		var rejected := canonical.duplicate(true); rejected[obsolete] = "index" if obsolete == "time_mode" else 12.0
		check(not Inspection.validate_visual(viewer,rejected).is_empty(),"Retired recipe field rejected without migration: "+obsolete)
	for speed in [-0.12345678912345678,0.0,0.5,1.0,2.0]:
		viewer.physical_rate = speed
		var signed_state := Visual.snapshot(viewer)
		check(Inspection.validate_visual(viewer,signed_state).is_empty(),"Signed or zero canonical speed is valid recipe state")
		var exact_state: Dictionary = Exact.unpack(Exact.pack(signed_state))
		viewer.physical_rate = 3
		Visual.apply(viewer,exact_state)
		check(viewer.physical_rate == speed,"Exact recipe packing and restoration preserves canonical speed")
	viewer.physical_rate = 1

	for preset in ["Scientific","Cinematic"]:
		for active in [false,true]:
			change_session(viewer,false)
			configure(viewer,preset,active)
			var path := output.path_join(preset+str(active)+".json")
			check(viewer._save_inspection(path) == OK,"save controlled v2 recipe")
			var saved: Dictionary = viewer._read_small_json(path)
			for cycle in range(3):
				configure(viewer,"Cinematic" if preset == "Scientific" else "Scientific",not active)
				change_session(viewer,true)
				var live := session(viewer)
				var label := "%s/%s/cycle%d" % [preset,active,cycle]
				check(viewer._load_inspection(path).is_empty(),label+" load v2")
				compare(saved.visual,Visual.snapshot(viewer),label+" saved visual")
				compare(live,session(viewer),label+" session untouched")
				check_ui(viewer,saved.visual,label)
				check(same(viewer.committed_sample.requested_time,saved.sample.requested_time),label+" saved sample time")
				check(viewer._save_inspection(path) == OK,label+" resave")
				compare(saved.visual,viewer._read_small_json(path).visual,label+" resaved payload")
		# Partial dictionaries are accepted by the existing recipe schema.
		var partial := Inspection.snapshot(viewer)
		partial.visual.clean_view = preset == "Scientific"
		partial.visual.environment = {"glow_intensity":.6}
		partial.visual.guide_visibility = {"domain":false}
		partial.visual.sections = {}
		viewer.environment.glow_enabled = false;viewer.environment.fog_enabled = false
		viewer.environment.background_mode = Environment.BG_COLOR
		viewer.guide_visibility.data = true
		var before := Visual.snapshot(viewer)
		check(Inspection.restore(viewer,partial).is_empty(),preset+" partial nested fields load")
		var expected_env: Dictionary = before.environment.duplicate();expected_env.glow_intensity = viewer.environment.glow_intensity
		compare(expected_env,Visual.snapshot(viewer).environment,preset+" omitted environment preserved")
		check(is_equal_approx(viewer.environment.glow_intensity,.6),"explicit environment member applied")
		check(viewer.guide_visibility.data and not viewer.guide_visibility.domain,"partial guides preserve omitted fields")
		compare(before.sections,Visual.snapshot(viewer).sections,"omitted section fields preserved")
		var invalid := Inspection.snapshot(viewer);invalid.visual.erase("environment")
		var stable := Visual.snapshot(viewer)
		check(not Inspection.restore(viewer,invalid).is_empty(),"missing required top-level field refused")
		compare(stable,Visual.snapshot(viewer),"invalid recipe changes nothing")
	# Exercise the real worker-backed v3 save/load path, including selection UI.
	var control = viewer.selection_controller
	control.bind_source();check(await wait_jobs(control),"bind v3 source")
	control._request("define_selection",{"key":"known","object":"p","kind":"particle_ids","selector":{"ids":["7"]}})
	check(await wait_jobs(control),"define v3 selection")
	for preset in ["Scientific","Cinematic"]:
		for active in [false,true]:
			configure(viewer,preset,active)
			viewer.control_checks["Show hidden selection"].button_pressed = active
			var bundle := output.path_join(preset+str(active)+".inspection")
			control.temporal.durable.save_to(bundle,true)
			check(await wait_jobs(control) and control.temporal.durable.last_recipe.has("path"),"save v3 "+preset)
			var recipe: Dictionary = viewer._read_small_json(bundle.path_join("inspection.json"))
			var payload: Dictionary = Exact.unpack(recipe.payload)
			for cycle in range(2):
				configure(viewer,"Cinematic" if preset == "Scientific" else "Scientific",not active)
				change_session(viewer,true)
				viewer.control_checks["Show hidden selection"].button_pressed = not active
				var live := session(viewer)
				control.temporal.durable.load_from(bundle.path_join("inspection.json"))
				check(await wait_jobs(control) and control.temporal.durable.last_recipe.get("restored",false),"load v3 "+preset)
				compare(payload.base.visual,Visual.snapshot(viewer),preset+" v3 visual")
				compare(payload.selections,control.state.snapshot(),preset+" v3 selections")
				compare(live,session(viewer),preset+" v3 session untouched")
				check(viewer.control_checks["Show hidden selection"].button_pressed == active,"v3 selection checkbox matches restored state")
				check_ui(viewer,payload.base.visual,preset+" v3")
	var old_recipe := Exact.snapshot(control.temporal,true)
	var old_payload: Dictionary = Exact.unpack(old_recipe.payload)
	old_payload.base.visual.scene.layers.field.erase("opacity_mapping")
	old_payload.base.visual.scene.layers.field.erase("color_mapping")
	old_payload.base.visual.scene.layers.field.lower = -.5;old_payload.base.visual.scene.layers.field.upper = 2.5
	old_recipe.payload = Exact.pack(old_payload)
	var old_path := output.path_join("legacy.inspection.json")
	preload("res://video/render_job.gd").write_json(old_path,old_recipe)
	control.temporal.durable.load_from(old_path)
	check(await wait_jobs(control) and control.temporal.durable.last_recipe.get("restored",false),"load legacy v3 through verified worker")
	compare({"mode":"linear","lower":-.5,"upper":2.5},viewer.scene_layers.states.field.opacity_mapping,"legacy v3 migration")
	check(FileAccess.get_sha256(viewer.capture_path) == source_hash,"capture bytes unchanged")
	if DisplayServer.get_name() != "headless":await process_frame;await RenderingServer.frame_post_draw
	viewer.queue_free();await process_frame
	var report := {"checks":checks,"failures":failures,"inventory":inventory,"renderer":RenderingServer.get_current_rendering_method()}
	preload("res://video/render_job.gd").write_json(output.path_join("recipe-state-report.json"),report)
	print("RECIPE STATE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
