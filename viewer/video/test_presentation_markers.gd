extends SceneTree
const Viewer = preload("res://main.gd")
const Markers = preload("res://video/presentation_markers.gd")
const State = preload("res://selection/selection_state.gd")
var checks: Array = []
var out := ""
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: push_error(label)
func marker(kind: String, object: String, row: int, index := 0) -> Dictionary:
	return {"kind":kind,"object":object,"row":row,"index":index,"show_hidden":false,"color":[1,0,0,1]}
func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	create_timer(30).timeout.connect(func(): push_error("Marker test timed out"); quit(1))
	var viewer := Viewer.new(); viewer.offline_instance = true; viewer.scene_prebuffer_enabled = false
	root.add_child(viewer); viewer._open_capture(out.path_join("fixture.wvz"))
	viewer.playing = false; viewer.orbit_enabled = false
	var control = viewer.selection_controller
	check(control.jobs.worker_pid < 0,"Native presentation starts no scientific worker")
	var particle := marker("particles","p",1); particle.id = "9007199254740993"
	var vertex := marker("mesh","mesh",1); vertex.id = "9007199254740993"
	var grid := marker("volume","field",0); grid.xyz = [2,1,1]
	var face := marker("face","mesh",0); face.weights = [0.2,0.3,0.5]
	var anonymous := marker("particles","p",0)
	for item in [particle,vertex,grid,face,anonymous]:
		check(Markers.validate([item]).is_empty(),"Valid bounded display address: "+item.kind)
	var invalid: Dictionary = particle.duplicate(true); invalid.id = "9007199254740993.0"
	check(not Markers.validate([invalid]).is_empty(),"Rounded/float IDs are refused")
	invalid = grid.duplicate(true); invalid.xyz[0] = 1.5
	check(not Markers.validate([invalid]).is_empty(),"Fractional grid address is refused")
	invalid = particle.duplicate(true); invalid.color[0] = NAN
	check(not Markers.validate([invalid]).is_empty(),"Nonfinite color is refused")
	var too_many: Array = []; too_many.resize(513); too_many.fill(particle)
	check(not Markers.validate(too_many).is_empty(),"Marker count has a finite shared preview ceiling")
	# Independent fixture oracle: field transform scales x by 2, then adds (10,-3,5).
	var point := Markers.locate(grid,viewer)
	check(not point.is_empty() and point.position.is_equal_approx(Vector3(12,-1,8)),"Grid address uses source geometry and affine world transform")
	point = Markers.locate(vertex,viewer)
	check(not point.is_empty() and point.position.is_equal_approx(Vector3(1,0,0)),"Mesh vertex resolves exact int64 source ID")
	point = Markers.locate(face,viewer)
	check(not point.is_empty() and point.position.is_equal_approx(Vector3(.3,.5,0)),"Mesh point follows source face barycentric weights")
	# Create only already drawn presentation data; no definition/membership requests.
	var definition := {"key":"preview","object":"p","kind":"particle_ids","association":"vertex","display":{"visible":true,"color":[1,0,0,1]}}
	var state := State.new(); state.definitions = [definition]
	var token := {"f64_le_hex":PackedFloat64Array([7.]).to_byte_array().hex_encode(),"text":"7"}
	var zero := {"f64_le_hex":PackedFloat64Array([0.]).to_byte_array().hex_encode(),"text":"0"}
	control.overlay.publish([{"key":"preview","sampling":{"a":0},"preview":[{"row":0,"id":"7","position":[token,zero,zero]}]}],state,16*1048576)
	control.overlay.update_time(0,viewer,state)
	var snapshot := Markers.snapshot(viewer)
	check(snapshot.size() == 1 and snapshot[0].id == "7" and not snapshot[0].has("selector"),"Snapshot carries only drawn addresses, no selection definitions")
	control.overlay.layers.preview.visible = false
	check(Markers.snapshot(viewer).is_empty(),"Hidden highlight is not silently activated by export")
	control.overlay.clear()
	var presentation := Markers.new(); viewer.add_child(presentation); presentation.setup([particle,vertex,grid,face,anonymous])
	for time in [0.5,1.0,3.0,4.0]:
		check(not viewer.scene_layers.sample(time).is_empty(),"Native display sample commits at "+str(time))
		presentation.update(viewer)
		if time < 3:
			var frame = viewer.frame_a; var row: int = frame.identity_map.rows[int(particle.id)]
			var expected: Vector3 = frame.positions[row]
			if time == 1: expected = Vector3(96,1,0) # HIGH_ID % 101 == 94; +2*t.
			check(presentation.positions[0] is Vector3 and presentation.positions[0].is_equal_approx(expected),"Marker follows reordered exact ID/held or interpolated display at "+str(time))
		else: check(presentation.positions[0] == null,"Absent persistent ID suppresses marker at "+str(time))
		if time >= 1: check(presentation.positions[2] == null,"Grid native address expires without acquiring new membership")
		check(presentation.positions[4] == null,"Anonymous row never acquires temporal identity")
		if time >= 2: check(presentation.positions[3] == null,"Face/sample address never resurrects after topology changes")
	viewer.scene_layers.sample(0)
	viewer.scene_layers.states.field.clip = true; viewer.scene_layers.states.field.clip_normal = [1,0,0]; viewer.scene_layers.states.field.clip_distance = 0
	check(Markers.locate(grid,viewer).is_empty(),"Source clipping suppresses visual marker")
	grid.show_hidden = true
	check(not Markers.locate(grid,viewer).is_empty(),"Show hidden retains marker display policy")
	viewer.scene_layers.states.field.visible = false
	viewer.scene_layers.states.mesh.visible = false
	viewer.scene_layers.sample(0.5)
	check(not Markers.locate(grid,viewer).is_empty(),"Show hidden grid highlights use admitted native geometry without Analysis")
	vertex.show_hidden = true
	check(not Markers.locate(vertex,viewer).is_empty(),"Show hidden mesh highlights use native source display interpolation")
	viewer.particle_layer_visible = false
	check(Markers.locate(particle,viewer).is_empty(),"Hidden particle layer suppresses ordinary highlights")
	check(control.jobs.worker_pid < 0 and control.source.is_empty(),"All marker updates leave scientific worker/source untouched")
	preload("res://video/render_job.gd").write_json(out.path_join("report.json"),{"checks":checks})
	viewer.queue_free(); await process_frame; await process_frame
	if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
	await create_timer(.1).timeout
	quit(1 if checks.any(func(item): return not item.ok) else 0)
