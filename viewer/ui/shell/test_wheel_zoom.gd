extends Node
## Real wheel route, bounds, custom orbit continuity and scientific-state isolation.
const Viewer = preload("res://main.gd")
const MeshView = preload("res://layers/mesh_view.gd")
var output := ""
var external := ""
var checks := 0
var failures: Array[String] = []
var cases: Dictionary = {}
var layouts: Array = []
@onready var root: Window = get_tree().root
func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 8: await get_tree().process_frame
	RenderingServer.force_draw(false)
func ready(view) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 12000:
		await get_tree().process_frame; view._process(0)
		if not view.scene_layers.is_buffering() and (not view.scene_layers.field_playback.active() or view.scene_layers.field_playback.worker.status().session.get("state") == "ready"): break
	check(not view.scene_layers.is_buffering(),"Scene sample ready")
	await settle()
func wheel(view, inward: bool, factor := 1.0, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if inward else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = pressed; event.factor = factor; event.position = Vector2(600,400)
	view._unhandled_input(event)
func verify(view, label: String) -> void:
	view._focus_activity(); await settle()
	var start: float = view.camera_distance
	var target: Vector3 = view.camera_target
	var basis: Basis = view.camera.basis
	var yaw: float = view.yaw; var pitch: float = view.pitch
	var sample: Dictionary = view.committed_sample.duplicate(true)
	var mesh_points: Dictionary = {}
	for id in view.scene_layers.views:
		var layer = view.scene_layers.views[id]
		if layer is MeshView: mesh_points[id] = layer.source_positions.duplicate()
	wheel(view,true)
	check(is_equal_approx(view.camera_distance,start*.9),label+" one notch is a modest 10% inward change")
	var first: float = view.camera_distance
	wheel(view,false)
	check(is_equal_approx(view.camera_distance,start),label+" reciprocal notch restores radius")
	wheel(view,true,.25)
	check(view.camera_distance < start and view.camera_distance > start*.9,label+" fractional wheel is less than one notch")
	wheel(view,false,.25)
	check(is_equal_approx(view.camera_distance,start),label+" fractional inverse restores radius")
	wheel(view,true,1000)
	check(is_equal_approx(view.camera_distance,start*.9),label+" large event factor cannot eject scene")
	wheel(view,false)
	wheel(view,true,1,false); wheel(view,false,1,false); wheel(view,true,0); wheel(view,false,-1)
	check(is_equal_approx(view.camera_distance,start),label+" releases and nonpositive factors do not zoom")
	# Exercise the actual viewport input dispatch, ensuring one press applies once.
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_WHEEL_UP; event.pressed = true; event.position = Vector2(600,400)
	root.push_input(event,true)
	check(is_equal_approx(view.camera_distance,start*.9),label+" viewport dispatch applies exactly one notch")
	wheel(view,false)
	for i in 4: wheel(view,true)
	for i in 4: wheel(view,false)
	check(is_equal_approx(view.camera_distance,start),label+" reversible repeated scroll inside bounds")
	for i in 120: wheel(view,true)
	var minimum: float = view.camera_distance
	check(is_finite(minimum) and minimum > 0 and minimum >= view.half_extent+view.camera.near,label+" inward stop stays outside framed bounding sphere/near plane")
	for i in 160: wheel(view,false)
	var maximum: float = view.camera_distance
	check(is_finite(maximum) and maximum+view.half_extent <= view.camera.far+.001,label+" outward stop respects far clipping range")
	wheel(view,true)
	check(view.camera_distance < maximum,label+" can recover inward from outward stop")
	view.camera_distance = .0001; view._update_camera(); wheel(view,true)
	check(is_equal_approx(view.camera_distance,.0001),label+" tiny custom radius never snaps to minimum")
	wheel(view,false)
	check(is_equal_approx(view.camera_distance,.0001/.9),label+" tiny custom radius recovers progressively")
	view.camera_distance = view.camera.far*20; view._update_camera(); var custom: float = view.camera_distance
	wheel(view,false)
	check(view.camera_distance == custom,label+" huge custom radius never snaps to maximum")
	wheel(view,true)
	check(is_equal_approx(view.camera_distance,custom*.9),label+" huge custom radius recovers progressively")
	check(view.camera_target == target and view.yaw == yaw and view.pitch == pitch and view.camera.basis.is_equal_approx(basis),label+" wheel preserves center and orientation")
	check(view.committed_sample == sample,label+" wheel preserves scientific sample/clock")
	for id in mesh_points: check(view.scene_layers.views[id].source_positions == mesh_points[id],label+" mesh vertex data unchanged")
	view._focus_activity(); await settle()
	check(is_equal_approx(view.camera_distance,start),label+" scene remains frameable")
	cases[label] = {"framed":start,"first_inward":first,"near":view.camera.near,"far":view.camera.far,"extent":view.half_extent,"minimum":minimum,"maximum":maximum}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zoom-output="): output = arg.trim_prefix("--zoom-output=")
		if arg.begins_with("--zoom-capture="): external = arg.trim_prefix("--zoom-capture=")
	if output.is_empty(): queue_free(); return
	get_tree().create_timer(110).timeout.connect(func(): push_error("Zoom validation timeout"); get_tree().quit(1))
	await get_tree().process_frame
	var view = get_tree().current_scene
	if view == null: view = Viewer.new(); view.scene_prebuffer_enabled = false; root.add_child(view)
	view.set_process(false); view.playing = false; view.orbit_enabled = false; OS.low_processor_usage_mode = false
	await settle()
	for name in ["particles","field","mesh","mixed","small","large"]:
		view._open_capture(output.path_join(name+".ssc")); view.playing = false; view.orbit_enabled = false
		check(view._shell_open_error.is_empty(),name+" capture opens")
		await ready(view); await verify(view,name)
	if not external.is_empty():
		view._open_capture(external); view.playing = false; view.orbit_enabled = false
		check(view._shell_open_error.is_empty(),"Owner cavity-collapse capture opens")
		await ready(view); await verify(view,"cavity-collapse")
		root.get_texture().get_image().save_png(output.path_join("cavity-framed.png"))
		wheel(view,true); await settle(); root.get_texture().get_image().save_png(output.path_join("cavity-one-notch.png")); wheel(view,false)
	for layout in [[Vector2i(1440,900),1.0],[Vector2i(3840,2160),2.0],[Vector2i(3840,2160),2.5]]:
		root.content_scale_factor = layout[1]; root.size = layout[0]; await settle(); root.size = layout[0]; view.shell.layout(); await settle()
		check(root.size == layout[0],"Actual layout "+str(layout[0]))
		layouts.append({"actual":str(root.size),"scale":layout[1]})
		for mode in [Window.MODE_WINDOWED,Window.MODE_MAXIMIZED,Window.MODE_FULLSCREEN,Window.MODE_WINDOWED]:
			root.mode = mode; await settle(); var before: float = view.camera_distance
			wheel(view,true); wheel(view,false)
			check(is_equal_approx(view.camera_distance,before),"Window mode keeps progressive zoom "+str(mode))
		root.get_texture().get_image().save_png(output.path_join("zoom-"+str(layout[0].x)+"-"+str(layout[1])+".png"))
	var report := {"checks":checks,"failures":failures,"cases":cases,"layouts":layouts,"renderer":RenderingServer.get_current_rendering_method(),"display_driver":DisplayServer.get_name(),"packaged":not OS.has_feature("editor")}
	FileAccess.open(output.path_join("zoom-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WHEEL ZOOM: ",checks," checks, ",failures.size()," failures")
	view._reset_inspection_source()
	if view.generic_reader != null: view.generic_reader.close()
	view.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
