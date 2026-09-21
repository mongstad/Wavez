extends SceneTree
const Reader = preload("res://layers/scene_reader.gd")
const Grid = preload("res://layers/grid_view.gd")
const Hash = preload("res://data/capture_index.gd")
const Opacity = preload("res://layers/volume_opacity.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures: Array[String] = []
var results: Array = []
var output := ""
var vp: SubViewport
var grid
var state := {"visible":true,"volume":true,"slice":false,"lower":-1.,"upper":1.,"opacity":.25,"step":.125,"clip":false,"clip_normal":[1.,0.,0.],"clip_distance":0.,"slice_normal":[0.,0.,1.],"slice_distance":0.,"opacity_mapping":{"mode":"magnitude","lower":0.,"upper":1.}}
var lut: Texture2D
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func shot(label: String) -> Image:
	grid.apply(state,lut)
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png")) == OK,label+" image saved")
	return image
func alpha_case(reader, sample: Dictionary, channel: String, weight: float, label: String) -> Image:
	check(grid.load_sample(reader.objects.field,sample,channel,16777216),label+" source loaded")
	var image := await shot(label)
	# Orthographic central ray crosses the entire 33-cell domain (33/8 units).
	var expected := 1-exp(-state.opacity*weight*33./8.)
	var actual := image.get_pixel(160,160).a
	check(absf(actual-expected) < .012,label+" analytic Beer-Lambert alpha")
	results.append({"case":label,"alpha":actual,"expected":expected})
	return image
func run() -> void:
	var job := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opacity-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--opacity-job=")))
	if job.is_empty():quit(1);return
	output = job.output
	create_timer(150).timeout.connect(func():push_error("Opacity regression timeout");quit(1))
	var reader := Reader.new();check(reader.open(job.capture),"synthetic capture opens")
	var sample := reader.read_sample("field",1)
	vp = SubViewport.new();vp.size = Vector2i(320,320);vp.own_world_3d = true;vp.transparent_bg = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var camera := Camera3D.new();camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = 6.;camera.position = Vector3(0,0,10);vp.add_child(camera)
	grid = Grid.new();vp.add_child(grid);grid.setup(camera)
	var white := Image.create(256,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE);lut = ImageTexture.create_from_image(white)
	await alpha_case(reader,sample,"zero",0.,"zero-symmetric")
	await alpha_case(reader,sample,"positive",.5,"magnitude-positive")
	await alpha_case(reader,sample,"negative",.5,"magnitude-negative")
	await alpha_case(reader,sample,"large",1.,"saturated-weight")
	state.opacity_mapping.lower = .01
	await alpha_case(reader,sample,"nearzero",0.,"nearzero-dead-zone")
	state.opacity_mapping = {"mode":"linear","lower":0.,"upper":1.}
	await alpha_case(reader,sample,"negative",0.,"linear-negative-transparent")
	var baseline := await alpha_case(reader,sample,"positive",.5,"density-default")
	state.lower = -.01;state.upper = .01
	var recolored := await alpha_case(reader,sample,"positive",.5,"color-range-independent")
	check(baseline.get_data() == recolored.get_data(),"white LUT image/alpha independent of color range")
	state.step = 1.
	await alpha_case(reader,sample,"positive",.5,"constant-field-step-one")
	state.step = .125;state.lower = -.5;state.upper = 1.5;state.erase("opacity_mapping")
	var legacy := await alpha_case(reader,sample,"positive",.5,"legacy-range")
	state.opacity_mapping = {"mode":"linear","lower":-.5,"upper":1.5}
	var migrated := await alpha_case(reader,sample,"positive",.5,"migrated-range")
	check(legacy.get_data() == migrated.get_data(),"old job and migrated mapping identical pixels")
	for channel in sample.channels:
		check(Hash.digest(sample.channels[channel].to_byte_array()) == job.hashes[channel],channel+" original float64 array hash unchanged")
	check(sample.time == 2. and grid.probe(Vector3.ZERO) == .5,"source time and original numerical probe unchanged")
	grid.queue_free();vp.queue_free();reader.close();await process_frame
	# Exercise actual layer controls, recipes, job apply and signed color images.
	vp = SubViewport.new();vp.size = Vector2i(960,640);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var viewer = load("res://main.gd").new();viewer.offline_instance = true;viewer.capture_path = job.capture;vp.add_child(viewer);viewer.set_process(false);viewer.playing = false;viewer.orbit_enabled = false
	viewer._apply_preset("Scientific");viewer.overlay_visible = false;viewer.show_legend = false;viewer.overlay_panel.hide();viewer.shell.prepare_export({});viewer.legend.hide();viewer.colorbar.hide()
	viewer.camera_target = Vector3.ZERO;viewer.camera_distance = 8.;viewer.yaw = 0.;viewer.pitch = 0.;viewer._update_camera()
	var layers = viewer.scene_layers
	check(layers.states.field.opacity_mapping == Opacity.DEFAULT,"fresh default is independent linear 0–1")
	var controls: Dictionary = layers.opacity_controls.field
	controls.mode.select(1);controls.mode.item_selected.emit(1)
	controls.lower.text = "1e-2";controls.lower.text_submitted.emit(controls.lower.text)
	controls.upper.text = "0.8";controls.upper.text_submitted.emit(controls.upper.text)
	check(layers.states.field.opacity_mapping == {"mode":"magnitude","lower":.01,"upper":.8},"UI selects explicit magnitude/dead-zone thresholds")
	controls.lower.text = "0.9";controls.lower.text_submitted.emit(controls.lower.text)
	check(layers.states.field.opacity_mapping.lower == .01 and controls.lower.text.to_float() == .01,"invalid UI threshold refused and editor restored")
	for channel in ["psi_real","psi_imag","density"]:
		layers.states.field.channel = channel;layers.states.field.lower = -1. if channel != "density" else 0.;layers.states.field.upper = 1.;layers.states.field.colormap = "coolwarm" if channel != "density" else "viridis"
		check(not layers.sample(2.).is_empty(),channel+" samples source timestamp")
		grid = layers.views.field
		check(Hash.digest(grid.data.channels[channel].to_byte_array()) == job.hashes[channel],channel+" viewer source invariant")
		check(grid.probe(Vector3(1,0,0)) != null,channel+" numerical probe available")
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image();image.save_png(output.path_join(channel+".png"))
		if channel != "density":
			var blue := 0;var red := 0
			for y in range(0,image.get_height(),4):
				for x in range(0,image.get_width(),4):
					var pixel := image.get_pixel(x,y)
					if pixel.r > pixel.b*1.4 and pixel.r > .08:red += 1
					if pixel.b > pixel.r*1.4 and pixel.b > .08:blue += 1
			check(red > 20 and blue > 20,channel+" positive and negative lobes distinguishable")
		var saved := Inspection.snapshot(viewer)
		if channel == "psi_real":Job.write_json(output.path_join("export-state.json"),saved.visual)
		layers.states.field.opacity_mapping = Opacity.DEFAULT.duplicate()
		check(Inspection.restore(viewer,JSON.parse_string(JSON.stringify(saved,"",true,true))).is_empty(),channel+" serialized v2 mapping restored")
		check(layers.states.field.opacity_mapping == saved.visual.scene.layers.field.opacity_mapping,channel+" exact chosen mapping reproduced")
		check(layers.opacity_controls.field.mode.selected == 1 and layers.opacity_controls.field.lower.text.to_float() == .01,channel+" restored UI reflects mapping")
		check(viewer.committed_sample.requested_time == 2.,channel+" restore keeps timestamp")
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		var restored_image := vp.get_texture().get_image();restored_image.save_png(output.path_join(channel+"-restored.png"))
		check(restored_image.get_data() == image.get_data(),channel+" recipe reproduces pixels")
	# Bad mappings must be refused before any visual mutation.
	var saved := Inspection.snapshot(viewer)
	for bad in [{}, {"mode":"gamma","lower":0.,"upper":1.}, {"mode":"linear","lower":1.,"upper":1.}, {"mode":"magnitude","lower":-.1,"upper":1.}, {"mode":"linear","lower":0.,"upper":INF}, {"mode":"linear","lower":false,"upper":1.}, {"mode":"linear","lower":1e100,"upper":1e101}, {"mode":"linear","lower":0.,"upper":1e-100}, {"mode":"linear","lower":0.,"upper":1.,"extra":1}]:
		var invalid := saved.duplicate(true);invalid.visual.scene.layers.field.opacity_mapping = bad
		check(not Inspection.restore(viewer,invalid).is_empty(),"invalid opacity recipe refused "+str(bad))
		check(Job.snapshot(viewer) == saved.visual,"invalid opacity recipe mutates nothing")
	var old := saved.duplicate(true);old.visual.scene.layers.field.erase("opacity_mapping");old.visual.scene.layers.field.lower = -.7;old.visual.scene.layers.field.upper = 1.3
	check(Inspection.restore(viewer,old).is_empty(),"legacy v2 recipe accepted")
	check(layers.states.field.opacity_mapping == {"mode":"linear","lower":-.7,"upper":1.3},"legacy color bounds frozen into separate opacity mapping")
	layers._set_range("field","lower",-.9)
	check(layers.states.field.opacity_mapping.lower == -.7,"editing migrated color range leaves opacity unchanged")
	Job.apply(viewer,old.visual)
	check(layers.states.field.opacity_mapping.lower == -.7,"legacy render-job apply migrates identically")
	var color_bounds := [layers.states.field.lower,layers.states.field.upper]
	layers.opacity_controls.field.reset.pressed.emit()
	check(layers.states.field.opacity_mapping == Opacity.DEFAULT and [layers.states.field.lower,layers.states.field.upper] == color_bounds,"mapping reset preserves color range")
	check(layers.opacity_controls.field.lower.text.to_float() == 0. and layers.opacity_controls.field.mode.selected == 0,"reset controls synchronized")
	viewer.shell.toggle_dock();viewer.shell.refresh_export();layers.layer_settings_buttons.field.button_pressed = true
	for i in 5:await process_frame
	var scroll: ScrollContainer = viewer.shell.scroll
	scroll.scroll_vertical += int(layers.opacity_controls.field.mode.global_position.y-scroll.global_position.y)-190
	for i in 5:await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(output.path_join("opacity-controls.png"))
	vp.queue_free();await process_frame
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"alpha_cases":results})
	print("VOLUME OPACITY: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
