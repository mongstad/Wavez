extends SceneTree
## #212: edit Auto Orbit's world-space center through the current view.
const Viewer = preload("res://main.gd")
const Visual = preload("res://scene/visual_state.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var cases: Array[String] = []
var baseline_probe := false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func state(view) -> Dictionary:
	return {"pose":view.camera.transform, "target":view.camera_target, "radius":view.camera_distance,
		"yaw":view.yaw, "pitch":view.pitch, "basis":view.camera_orbit_basis,
		"active":view.camera_orbit_basis_active, "basis_yaw":view.camera_orbit_basis_yaw,
		"basis_pitch":view.camera_orbit_basis_pitch, "auto":view.orbit_enabled, "free":view.free_camera}
func world(view) -> Dictionary:
	var result := {view:view.transform, view.scene_layers:view.scene_layers.transform, view.current_instance:view.current_instance.transform}
	for node in view.scene_layers.views.values(): result[node] = node.transform
	for node in view.trail_instances: result[node] = node.transform
	return result
func focus_none() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
func steer(view, movement: Vector2) -> void:
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = Vector2(400,300)
	view._unhandled_input(press)
	var motion := InputEventMouseMotion.new(); motion.position = press.position+movement; view._input(motion)
	press.pressed = false; view._input(press)
func orbit(view, seconds: float) -> void:
	var event: InputEventKey = view.shell.shortcuts.event_for("orbit_camera_left"); event.pressed = true
	view._unhandled_input(event); view._update_manual_orbit(seconds)
	event.pressed = false; view._input(event)
func ready(view) -> void:
	var start := Time.get_ticks_msec()
	while view.scene_layers.is_buffering() and Time.get_ticks_msec()-start < 15000:
		await process_frame; view._process(0)
	check(not view.scene_layers.is_buffering(), "Fixture reaches committed sample")
func fields(editor, center: Vector3, radius: float) -> void:
	for axis in 3: editor.coordinates[axis].text = str(center[axis])
	editor.radius_input.text = str(radius)
	check(editor.read_fields(), "World numeric fields accept finite values")
func handle_drag(view, axis: int, basis: Basis, label: String) -> void:
	var editor = view.shell.orbit_editor
	var handle: Dictionary = editor.guide.handle(axis)
	check(not handle.is_empty(), label+": view handle available "+str(axis))
	if handle.is_empty(): return
	var start: Vector3 = editor.center
	var before: Transform3D = view.camera.transform
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = handle.end
	root.push_input(press,true)
	check(editor.drag_axis == axis and not view.dragging, label+": guide receives drag exclusively")
	var motion := InputEventMouseMotion.new(); motion.position = handle.end+handle.direction*24.0; root.push_input(motion,true)
	press.pressed = false; press.position = editor.panel.global_position+Vector2(10,10); root.push_input(press,true)
	var delta: Vector3 = editor.center-start
	var expected: Vector3 = basis[axis]*24.0*handle.units
	check(delta.distance_to(expected) <= maxf(.000001, expected.length()*.00005), label+": drag follows captured view axis "+str(axis))
	check(view.camera.transform == before and editor.drag_axis == -1, label+": draft drag leaves camera unchanged and releases over controls")
func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 3: await process_frame
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK, "Screenshot "+name)

func exercise(view, label: String, scale: float, navigation: int) -> void:
	focus_none(); view._reset_camera(); view.orbit_enabled = false; view.free_camera = true
	view.camera_target = Vector3(1.23456789,-.87654321,2.34567891)*scale
	view.camera_distance = 19.123456789*scale
	view.camera.near = minf(.05,scale*.01); view.camera.far = maxf(1000,scale*100)
	view._update_camera()
	view._orbit_camera_by_drag(Vector2(173,211),.005)
	if navigation >= 1: steer(view,Vector2(93,-67))
	if navigation == 2: view._orbit_camera_by_drag(Vector2(-79,113),.005)
	if navigation == 3:
		orbit(view,.17)
		view.camera_target += view.camera.basis*Vector3(.2,-.1,-.5)*scale; view._update_camera()
		var wheel := InputEventMouseButton.new(); wheel.factor = .5; view._zoom_camera(wheel,true)
	var scientific := world(view)
	var sample: Dictionary = view.committed_sample.duplicate(true)
	view.orbit_enabled = true
	var prior := state(view)
	var reference: Basis = view.camera.basis
	view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor
	await process_frame; editor.refresh()
	check(view.camera.transform == prior.pose and not view.orbit_enabled, label+": opening suspends Auto Orbit without changing pose")
	var accepted: Dictionary = Visual.snapshot(view)
	for axis in 3: handle_drag(view,axis,reference,label)
	check(view.camera_target == prior.target and view.camera_distance == prior.radius, label+": handles only change draft parameters")
	check(Visual.snapshot(view) == accepted, label+": serialization excludes the draft")
	if baseline_probe:
		editor.dismiss(); view.shell.edit_orbit_center(); editor.commit()
		check(view.camera_target == prior.target and view.camera_distance == prior.radius and view.camera.transform == prior.pose, label+": unchanged Apply retains exact pose/values")
		view.orbit_enabled = false; return
	# The reference axes stay fixed even if the user navigates during placement.
	steer(view,Vector2(-47,29))
	# Bring the draft back into the usable viewport after the three preceding
	# drags/steering; hidden/covered endpoints are intentionally not clickable.
	editor.place_ahead()
	handle_drag(view,0,reference,label+" after placement steering")
	var chosen: Vector3 = editor.center
	var current: Basis = view.camera.basis
	editor.commit()
	check(view.camera_target == chosen and view.camera_distance == prior.radius, label+": Apply commits world center and preserves untouched radius")
	check(view.camera.basis == current and view.orbit_enabled, label+": Apply retains full current orientation and starts Auto Orbit")
	check(view.camera.position.is_equal_approx(chosen+current.z*prior.radius), label+": camera follows the new center at its existing radius")
	var applied: Transform3D = view.camera.transform
	view.scene_layers.tick(.02)
	check(view.camera_target == chosen and view.camera_distance == prior.radius and view.camera.position != applied.origin, label+": accepted Auto Orbit continues around the new center")
	view.orbit_enabled = false
	# Current #258 steering remains in-place; held orbit uses resulting screen-up.
	var position: Vector3 = view.camera.position; var radius: float = view.camera_distance
	steer(view,Vector2(41,-23))
	check(view.camera.position == position and view.camera_distance == radius and not view.orbit_enabled, label+": RMB retains current in-place steering")
	var target: Vector3 = view.camera_target; var up: Vector3 = view.camera.basis.y
	orbit(view,.13)
	check(view.camera_target == target and view.camera_distance == radius and view.camera.basis.y.is_equal_approx(up), label+": held orbit derives current screen-up and keeps target/radius")
	# Repeated unchanged Apply and Cancel must not parse rounded text into drift.
	for repeat in 5:
		var pose: Transform3D = view.camera.transform; target = view.camera_target; radius = view.camera_distance
		view.shell.edit_orbit_center(); editor.commit()
		check(view.camera.transform == pose and view.camera_target == target and view.camera_distance == radius, label+": unchanged Apply has no drift "+str(repeat))
		view.orbit_enabled = false
		var saved := state(view); view.shell.edit_orbit_center()
		fields(editor,target+Vector3(3,-2,1)*scale,radius*.73)
		steer(view,Vector2(11,7)); editor.dismiss()
		check(state(view) == saved, label+": Cancel restores complete pre-edit state "+str(repeat))
	# Editing just one world coordinate preserves the exact other values.
	var exact := state(view); view.shell.edit_orbit_center()
	editor.coordinates[0].text = str(exact.target.x+scale)
	editor.commit()
	check(view.camera_target.y == exact.target.y and view.camera_target.z == exact.target.z and view.camera_distance == exact.radius, label+": untouched numeric fields preserve exact values")
	view.orbit_enabled = false
	var center: Vector3 = view.camera_target; current = view.camera.basis
	view.shell.edit_orbit_center(); editor.radius_input.text = str(view.camera_distance*.8); editor.commit()
	check(view.camera_target == center and view.camera.basis == current, label+": radius-only Apply keeps exact center and orientation")
	# Directly edited XYZ retain absolute scientific/world semantics.
	view.orbit_enabled = false; view.shell.edit_orbit_center(); fields(editor,Vector3(3,-2,1)*scale,13*scale); editor.commit()
	check(view.camera_target.is_equal_approx(Vector3(3,-2,1)*scale) and is_equal_approx(view.camera_distance,13*scale), label+": numeric XYZ remain world coordinates")
	view.orbit_enabled = false
	for node in scientific: check(is_instance_valid(node) and node.transform == scientific[node], label+": scientific transform unchanged "+node.name)
	check(view.committed_sample == sample, label+": committed scientific sample unchanged")
	cases.append(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--orbit-view-output="): output = arg.trim_prefix("--orbit-view-output=")
		if arg == "--baseline-probe": baseline_probe = true
	if output.is_empty(): quit(1); return
	create_timer(180).timeout.connect(func(): push_error("Orbit-center view test timed out"); quit(1))
	var view = Viewer.new(); root.add_child(view); view.set_process(false)
	view.shell.shortcuts.active.orbit_camera_left = KEY_F6
	view.shell.shortcuts.active.orbit_camera_right = KEY_F7
	for kind in ["particles","field","mesh","mixed"]:
		for scale_name in ["small","large"]:
			view._open_capture(output.path_join(kind+"-"+scale_name+".wvz")); view.playing = false; await ready(view)
			check(view._shell_open_error.is_empty(), kind+" "+scale_name+": capture opened")
			for mode in ["normal","fullscreen"]:
				if mode == "fullscreen": view.shell.enter_immersive()
				for navigation in range(1 if baseline_probe else 4):
					await exercise(view,kind+" / "+scale_name+" / "+mode+" / navigation "+str(navigation),.01 if scale_name == "small" else 1000.0,navigation)
				if not baseline_probe and kind == "mixed" and scale_name == "small":
					view.shell.edit_orbit_center(); view.shell.orbit_editor.show_details(true)
					await screenshot("editor-"+mode); view.shell.orbit_editor.dismiss()
				if mode == "fullscreen": view.shell.exit_immersive()
	if DisplayServer.get_name() != "headless":
		for frame in 3: await process_frame
	var report := {"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"baseline_probe":baseline_probe}
	var file := FileAccess.open(output.path_join("orbit-view-report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	view.queue_free(); await process_frame
	print("ORBIT CENTER VIEW: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
