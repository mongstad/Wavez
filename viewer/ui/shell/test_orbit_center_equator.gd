extends "res://ui/shell/test_orbit_center_view.gd"
## PR #301: physical camera travel on an Apply-time equator, with fixed axes.
var traces: Array = []
var playback_results: Array = []

func fixed_reference(view) -> Node3D:
	var reference := Node3D.new(); reference.name = "FixedWorldReference"; view.add_child(reference)
	for axis in 3:
		var rod := MeshInstance3D.new(); var box := BoxMesh.new()
		var size := Vector3(.035,.035,.035); size[axis] = 5.0; box.size = size
		rod.mesh = box; rod.position = Vector3(2,1,-1); reference.add_child(rod)
		var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = [Color(1,.12,.12),Color(.12,1,.2),Color(.15,.45,1)][axis]; rod.material_override = material
		var label := Label3D.new(); label.text = "WORLD "+["X","Y","Z"][axis]; label.font_size = 64; label.pixel_size = .004
		label.position = rod.position; label.position[axis] += 2.6; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		reference.add_child(label)
	# An off-axis prism gives the numerical stationary reference a visible asymmetry.
	var marker := MeshInstance3D.new(); var prism := PrismMesh.new(); prism.size = Vector3(.5,1.1,.8)
	marker.mesh = prism; marker.position = Vector3(2.8,1.7,-1.5); reference.add_child(marker)
	var material := StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,.65,.08); marker.material_override = material
	return reference

func fingerprint(view) -> PackedByteArray:
	var data := {"particle_a":view.frame_a.positions,"particle_b":view.frame_b.positions}
	for id in view.scene_layers.views:
		var layer = view.scene_layers.views[id]
		data[id] = layer.source_positions if layer is MeshInstance3D else layer.data.channels
	return var_to_bytes(data)

func place(view, basis: Basis, radius: float) -> void:
	view.orbit_enabled = false
	view.camera.basis = basis; view._adopt_camera_basis()
	view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor
	fields(editor,Vector3(2,1,-1),radius); editor.commit()
	check(view.camera.basis.is_equal_approx(basis) and view.orbit_enabled, "Apply retains full view and starts orbit")

func circular_path(view, label: String, orientation: int, radius: float) -> void:
	view._reset_camera(); view.camera.near = .02; view.camera.far = 1000.
	var basis := Basis(Vector3.UP,.4)*Basis(Vector3.RIGHT,-.75)
	if orientation == 1: basis = basis*Basis(Vector3.BACK,.6)
	if orientation == 2: basis = Basis(Vector3.UP,.4)*Basis(Vector3.RIGHT,-PI/2)
	place(view,basis,radius)
	var center: Vector3 = view.camera_target; var axis: Vector3 = view.camera.basis.y
	var initial: Transform3D = view.camera.transform; var scientific := world(view)
	var reference: Node3D = view.get_node("FixedWorldReference"); scientific[reference] = reference.transform
	for child in reference.get_children(): scientific[child] = child.transform
	var data := fingerprint(view); var samples: Array = []
	# Unequal tick lengths and signed speed verify the phase is time based.
	view.orbit_speed = -1.0 if orientation == 1 else 1.0
	var phase := 0.0
	for step in 24:
		var dt := TAU/24.0*(.4 if step%2 == 0 else 1.6); phase += dt*view.orbit_speed
		view.scene_layers.tick(dt)
		var offset: Vector3 = view.camera.position-center
		check(view.camera_target == center and absf(offset.length()-radius)<radius*.000002, label+": fixed center and physical radius")
		check(absf(offset.dot(axis))<radius*.000002 and view.camera.basis.y.distance_to(axis)<.000002, label+": stable equator and up axis")
		var expected: Vector3 = Basis(axis,phase)*(initial.origin-center)
		check(offset.distance_to(expected)<radius*.000003, label+": camera physically follows circular path")
		check(view.camera.basis.z.dot(offset.normalized())>.999999, label+": camera looks toward chosen lobe")
		check(view.camera.unproject_position(center).distance_to(root.size/2.0)<.01, label+": chosen center stays on screen center")
		var fixed := true
		for node in scientific: fixed = fixed and is_instance_valid(node) and node.transform == scientific[node]
		check(fixed,label+": source objects and reference axes remain fixed throughout the turn")
		samples.append([view.camera.position.x,view.camera.position.y,view.camera.position.z])
		if step in [5,11,17] and orientation == 0:
			await screenshot(label.replace(" / ","-").replace(" ","_")+"-quarter-"+str(step/6+1))
	check(view.camera.position.distance_to(initial.origin)<radius*.000003, label+": full turn returns to Apply position")
	check(Vector3(samples[5][0],samples[5][1],samples[5][2]).distance_to(initial.origin)>radius, label+": quarter turn has substantial travel including polar view")
	check(fingerprint(view) == data, label+": stationary particle/mesh/field arrays unchanged")
	for node in scientific: check(is_instance_valid(node) and node.transform == scientific[node],label+": fixed world transform "+node.name)
	traces.append({"case":label,"orientation":orientation,"radius":radius,"center":[center.x,center.y,center.z],"axis":[axis.x,axis.y,axis.z],"positions":samples})
	view.orbit_enabled = false; cases.append(label)

func transitions(view) -> void:
	place(view,Basis(Vector3.UP,.3)*Basis(Vector3.RIGHT,.7),3.)
	view.scene_layers.tick(.2)
	var axis: Vector3 = view.auto_orbit_axis
	var phase: float = view.auto_orbit_angle
	var pose: Transform3D = view.camera.transform
	view.shell.edit_orbit_center(); steer(view,Vector2(20,30)); view.shell.orbit_editor.dismiss()
	check(view.camera.transform == pose and view.auto_orbit_angle == phase and view.auto_orbit_axis == axis, "Cancel restores original orbit plane and phase")
	view.scene_layers.tick(.1)
	check(view.auto_orbit_axis == axis and is_equal_approx(view.auto_orbit_angle,phase+.1*view.orbit_speed), "Cancelled placement resumes without phase reset")
	var wheel := InputEventMouseButton.new(); wheel.factor = .5; view._zoom_camera(wheel,true)
	view.scene_layers.tick(.1)
	check(view.auto_orbit_axis == axis and view.orbit_enabled, "Wheel changes radius while preserving orbit plane")
	var snapshot: Dictionary = Visual.snapshot(view)
	steer(view,Vector2(35,17)); check(not view.orbit_enabled,"RMB retains immediate manual takeover")
	Visual.apply(view,snapshot); var restored: Transform3D = view.camera.transform
	view.scene_layers.tick(.1)
	check(view.auto_orbit_axis.is_equal_approx(restored.basis.y) and view.camera.position.distance_to(restored.origin)>.01,"Restored full camera state resumes on its view-up equator")
	view.dragging = true; pose = view.camera.transform; view.scene_layers.tick(.1)
	check(view.camera.transform == pose,"Held LMB pauses automatic motion")
	view._orbit_camera_by_drag(Vector2(32,-19),.005); view.dragging = false
	axis = view.camera.basis.y; pose = view.camera.transform; view.scene_layers.tick(.1)
	check(view.orbit_enabled and view.auto_orbit_axis.is_equal_approx(axis) and view.camera.position.distance_to(pose.origin)>.01,"LMB resumes from deliberately changed view on its new equator")
	view.orbit_enabled = false

func evolving(view, kind: String) -> void:
	view._open_capture(output.path_join("equator-"+kind+"-evolving.wvz")); view.playing = false; await ready(view)
	# Use resident tiny fixtures; async preparation is awaited before each tick.
	var endpoints: Array = []
	for automatic in [false,true]:
		view.orbit_enabled = false; check(view._seek_time(0.),kind+": replay starts at recorded time zero"); await ready(view)
		var before := fingerprint(view); var scientific := world(view)
		place(view,Basis(Vector3.UP,.4)*Basis(Vector3.RIGHT,-.75),3.)
		view.orbit_enabled = automatic; view.physical_rate = .5; view.scene_loop_playback = false; view.playing = true
		var initial: Vector3 = view.camera.position
		for tick in 12:
			await ready(view); view.scene_layers.tick(.2); await process_frame
		view.playing = false; await ready(view)
		var time: float = view.committed_sample.requested_time
		check(time>.6 and fingerprint(view)!=before,kind+": recorded scientific content evolves during Auto Orbit "+str(automatic))
		check((view.camera.position.distance_to(initial)>.1) == automatic,kind+": camera travel reflects automatic mode")
		for node in scientific: check(node.transform == scientific[node],kind+": playback retains source world transform "+node.name)
		endpoints.append({"time":time,"data":fingerprint(view),"sample":view.committed_sample.duplicate(true)})
	check(endpoints[0] == endpoints[1],kind+": orbit on/off has identical replay time, scientific sample and arrays")
	playback_results.append({"kind":kind,"without_orbit_time":endpoints[0].time,"with_orbit_time":endpoints[1].time,"identical_scientific_sample":endpoints[0] == endpoints[1]})
	view.orbit_enabled = false

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--orbit-view-output="): output = arg.trim_prefix("--orbit-view-output=")
	if output.is_empty(): quit(1); return
	create_timer(180).timeout.connect(func(): push_error("Equatorial orbit test timed out"); quit(1))
	var view = Viewer.new(); root.add_child(view); view.set_process(false)
	# Keep the fixed reference readable; these are test-only presentation values.
	view.environment.glow_enabled = false
	var reference := fixed_reference(view)
	for kind in ["particles","mesh","field","mixed"]:
		view._open_capture(output.path_join("equator-"+kind+"-stationary.wvz")); view.playing = false; await ready(view)
		for mode in ["normal","fullscreen"]:
			if mode == "fullscreen": view.shell.enter_immersive()
			for orientation in 3:
				for radius in [3.,12.]: await circular_path(view,kind+" / "+mode+" / view "+str(orientation)+" / radius "+str(radius),orientation,radius)
			if mode == "fullscreen": view.shell.exit_immersive()
		transitions(view)
		await evolving(view,kind)
	reference.queue_free()
	var report := {"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"camera_traces":traces,"playback":playback_results}
	var file := FileAccess.open(output.path_join("orbit-view-report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	view.queue_free(); for frame in 3: await process_frame
	print("EQUATOR: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
