extends SceneTree
const Viewer = preload("res://main.gd")
const Marker = preload("res://layers/probe_marker.gd")
const Geometry = preload("res://scene/geometry.gd")
const Job = preload("res://video/render_job.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var viewer
var viewport: SubViewport
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)
func shot(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(output.path_join(name+".png")) == OK,name+" saved")
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	create_timer(120).timeout.connect(func():push_error("Probe visibility test timeout");quit(1))
	viewport = SubViewport.new();viewport.size = Vector2i(960,640);viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	viewer = Viewer.new();viewer.offline_instance = true;viewer.capture_path = output.path_join("dense.wvz")
	viewport.add_child(viewer);viewer.set_process(false);viewer.playing = false;viewer.orbit_enabled = false
	viewer._apply_preset("Scientific");viewer.overlay_visible = false;viewer.show_legend = false
	viewer.overlay_panel.hide();viewer.shell.prepare_export({});viewer.legend.hide();viewer.colorbar.hide()
	viewer.camera_target = Vector3.ZERO;viewer.camera_distance = 8.;viewer.yaw = .35;viewer.pitch = .25;viewer._update_camera()
	var layers = viewer.scene_layers
	var configs := [
		{"name":"empty","particles":0,"volume":false},
		{"name":"sparse","particles":80,"volume":false},
		{"name":"dense-white","particles":20000,"volume":false},
		{"name":"viridis-dark","map":"viridis","upper":8.},
		{"name":"viridis-bright","map":"viridis","upper":1.},
		{"name":"plasma-mid","map":"plasma","upper":2.},
		{"name":"coolwarm-blue","map":"coolwarm","upper":8.},
		{"name":"coolwarm-white","map":"coolwarm","upper":2.},
		{"name":"coolwarm-red","map":"coolwarm","upper":1.1},
		{"name":"turbo-structure","map":"turbo","upper":1.,"channel":"wave","particles":20000},
		{"name":"cinematic-dense","map":"turbo","upper":1.,"channel":"wave","particles":20000,"preset":"Cinematic"}]
	for config in configs:
		var name: String = config.name
		viewer._apply_preset(config.get("preset","Scientific"))
		layers.states.field.channel = config.get("channel","constant")
		layers.states.field.lower = 0.;layers.states.field.upper = config.get("upper",1.)
		layers.states.field.colormap = config.get("map","viridis")
		layers.states.field.opacity = 3.;layers.states.field.step = .125
		layers.sample(0.)
		viewer.current_mm.visible_instance_count = config.get("particles",0)
		layers.views.field.quad.visible = config.get("volume",true)
		layers.probe_channel = "constant";layers.probe_selected_volume()
		check(layers.probe_marker_valid and layers.views.field.probe(Vector3.ZERO,"constant") == 1.,name+" source oracle")
		var scientific: Dictionary = Job.snapshot(viewer)
		var sample: Dictionary = viewer.committed_sample.duplicate(true)
		var source = layers.views.field.data.channels.constant.duplicate()
		var stamp: Dictionary = layers.probe_stamp.duplicate(true)
		layers.set_probe_marker_enabled(false);await shot(name+"-hidden")
		var lines := PackedVector3Array()
		for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:lines.append_array([axis*-.35,axis*.35])
		var legacy := MeshInstance3D.new();legacy.mesh = Geometry.lines(lines,Color.WHITE);layers.add_child(legacy)
		await shot(name+"-legacy");legacy.free()
		layers.set_probe_marker_enabled(true)
		await shot(name+"-orchid")
		for alternate in [{"name":"cyan","color":Color("6de3ff")},{"name":"gold","color":Color("ffe082")}]:
			layers.probe_marker.ink.color = alternate.color;await shot(name+"-"+alternate.name)
		layers.probe_marker.ink.color = Marker.CORE
		check(Job.snapshot(viewer) == scientific and viewer.committed_sample == sample,name+" presentation leaves render/scientific state unchanged")
		check(layers.probe_stamp == stamp and layers.views.field.data.channels.constant == source,name+" presentation leaves probe/source unchanged")
		layers.set_probe_marker_enabled(false);await shot(name+"-hidden-after")
		cases.append({"name":name,"particles":config.get("particles",0),"viewport":[960,640]})
	# Consume the production visibility command, including its checked state.
	viewer.shell.refresh_commands()
	var command: Dictionary = viewer.shell.commands.probe
	command.popup.id_pressed.emit(command.index);viewer.shell.refresh_commands()
	check(layers.probe_marker_enabled and layers.probe_marker.visible and command.popup.is_item_checked(command.index),"View Probe marker shows the existing session marker")
	command.popup.id_pressed.emit(command.index);viewer.shell.refresh_commands()
	check(not layers.probe_marker_enabled and not layers.probe_marker.visible and not command.popup.is_item_checked(command.index),"View Probe marker hides the existing session marker")
	# Geometry follows the explicit probe, independent of camera motion and depth.
	viewer._apply_preset("Scientific")
	layers.probe_spins[0].value = 1.;layers.probe_selected_volume()
	check(layers.probe_marker.position.is_equal_approx(Vector3(1,0,0)),"Marker centered on updated world probe")
	var vertices: PackedVector3Array = layers.probe_marker.vertices.duplicate()
	var stamp: Dictionary = layers.probe_stamp.duplicate(true)
	viewer.camera_distance = 20.;viewer.yaw = 0.;viewer.pitch = 0.;viewer._update_camera()
	check(layers.probe_marker.vertices == vertices and layers.probe_stamp == stamp,"Camera motion does not move or resample marker")
	layers.probe_spins[0].value = 0.;layers.probe_selected_volume();viewer.current_mm.visible_instance_count = 0
	layers.views.field.quad.visible = false
	layers.set_probe_marker_enabled(true)
	await shot("axis-aligned-far-orchid")
	viewport.size = Vector2i(640,480);await shot("compact-orchid")
	check(not layers.probe_marker.is_processing(),"Marker has no process loop")
	var projected: PackedVector2Array = layers.probe_marker.ink.points.duplicate()
	for i in 4: await process_frame
	check(layers.probe_marker.ink.points == projected,"Stationary camera retains projected geometry")
	viewer.camera.position = Vector3(0,0,.2);layers.probe_marker.update_projection()
	check(layers.probe_marker.ink.points.size() >= 4,"Near-plane crossing retains front-facing arms")
	var finite := true
	for point in layers.probe_marker.ink.points: finite = finite and point.is_finite()
	check(finite,"Near-plane projection stays finite")
	viewer.camera.position = Vector3(0,0,-1);layers.probe_marker.update_projection()
	check(layers.probe_marker.ink.points.is_empty(),"Behind-camera probe has no phantom cross")
	Job.write_json(output.path_join("visibility-report.json"),{"checks":checks,"failures":failures,"cases":cases})
	viewer.free();viewport.queue_free();await process_frame
	print("PROBE VISIBILITY: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
