extends "res://ui/shell/test_orbit_center_view.gd"
## Owner review refinement: draft anchor independent of every camera gesture.
var shading: Array = []

func tumble(view, movement: Vector2) -> void:
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = Vector2(80,180)
	root.push_input(press,true)
	var motion := InputEventMouseMotion.new(); motion.position = press.position+movement; root.push_input(motion,true)
	press.pressed = false; root.push_input(press,true)

func movement_keys(view, label: String) -> void:
	for keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_Q,KEY_E]:
		focus_none()
		var before: Transform3D = view.camera.transform
		var event := InputEventKey.new(); event.physical_keycode = keycode; event.pressed = true
		Input.parse_input_event(event); Input.flush_buffered_events(); view._move_free_camera(.002)
		event = event.duplicate(); event.pressed = false; Input.parse_input_event(event); Input.flush_buffered_events()
		check(view.camera.position != before.origin and view.camera.basis == before.basis,label+": Free Camera key translates without rotating "+str(keycode))

func lock_exercise(view, label: String, scale: float) -> void:
	focus_none(); view._reset_camera(); view.orbit_enabled = false; view.free_camera = true
	view.camera_target = Vector3(.12,-.08,.04)*scale; view.camera_distance = 7.2*scale
	view.camera.near = minf(.05,scale*.01); view.camera.far = maxf(1000,scale*100)
	view._update_camera(); view._orbit_camera_by_drag(Vector2(121,77),.006)
	var prior := state(view); var scientific := world(view); var sample: Dictionary = view.committed_sample.duplicate(true)
	view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor
	await process_frame
	var reference: Basis = editor.edit_basis
	var draft: Vector3 = editor.center; var radius: float = editor.radius
	steer(view,Vector2(14,-9))
	check(view.camera_target != draft and editor.center == draft and editor.radius == radius,label+": steering moves navigation target, not draft")
	var pose: Transform3D = view.camera.transform; var snapshot: Dictionary = Visual.snapshot(view)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = editor.lock_position.get_global_rect().get_center()
	root.push_input(press,true); press.pressed = false; root.push_input(press,true)
	check(editor.position_locked and view.camera.transform == pose,label+": actual Lock Position click anchors without camera snap")
	check(Visual.snapshot(view) == snapshot,label+": lock does not enter serialized presentation state")
	var offset: Vector3 = view.camera.position-draft; var basis: Basis = view.camera.basis
	tumble(view,Vector2(52,-31))
	check(view.camera.basis != basis,label+": routed LMB actually navigates")
	check((view.camera.position-draft).is_equal_approx((view.camera.basis*basis.inverse())*offset),label+": LMB rotates actual camera offset about locked draft")
	check(is_equal_approx(view.camera.position.distance_to(draft),offset.length()),label+": LMB retains distance to locked center after steering")
	pose = view.camera.transform; var navigation_radius: float = view.camera_distance
	steer(view,Vector2(-35,19))
	check(view.camera.position == pose.origin and view.camera_distance == navigation_radius,label+": locked RMB remains in-place steering")
	offset = view.camera.position-draft; var up: Vector3 = view.camera.basis.y; pose = view.camera.transform
	orbit(view,.23)
	check(view.camera.position != pose.origin,label+": held orbit actually navigates")
	check(is_equal_approx(view.camera.position.distance_to(draft),offset.length()) and view.camera.basis.y.is_equal_approx(up),label+": held orbit anchors to draft with captured screen-up")
	var wheel := InputEventMouseButton.new(); wheel.pressed = true; wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.factor = .5; wheel.position = Vector2(80,180)
	offset = view.camera.position-draft; root.push_input(wheel,true)
	check(view.camera_distance != navigation_radius,label+": routed wheel actually zooms")
	check((view.camera.position-draft).is_equal_approx(offset*(view.camera_distance/navigation_radius)),label+": wheel zooms about locked center")
	movement_keys(view,label)
	check(editor.center == draft and editor.radius == radius,label+": all navigation retains exact locked XYZ and draft radius")
	check(editor.edit_basis == reference,label+": navigation retains captured view handle frame")
	# Return by free translation to a view with all handles inside the viewport.
	view.camera_target = draft; view._update_camera(); await process_frame
	editor.show_details(false); await process_frame
	for axis in 3: handle_drag(view,axis,reference,label+" locked")
	check(editor.position_locked,label+": handles remain enabled while locked")
	pose = view.camera.transform
	fields(editor,Vector3(.25,-.15,.07)*scale,1.8*scale)
	check(editor.position_locked and view.camera.transform == pose,label+": world XYZ and radius remain editable without moving camera")
	draft = editor.center; radius = editor.radius; offset = view.camera.position-draft
	tumble(view,Vector2(-27,14))
	check(is_equal_approx(view.camera.position.distance_to(draft),offset.length()),label+": edited world center becomes the locked anchor")
	check(editor.radius == radius,label+": camera navigation never rewrites edited draft radius")
	editor.show_details(false); await process_frame
	check(editor.position_readout.is_visible_in_tree() and editor.position_readout.text.contains(str(draft.x)) and editor.lock_position.is_visible_in_tree(),label+": world XYZ/radius and lock remain visible with controls hidden")
	pose = view.camera.transform; editor.set_position_locked(false); view._update_camera()
	check(view.camera.transform.is_equal_approx(pose),label+": unlock and next update retain placement pose")
	editor.set_position_locked(true); editor.place_ahead()
	check(editor.position_locked and editor.center.is_equal_approx(view.camera.position-view.camera.basis.z*radius),label+": Place ahead remains an explicit draft edit while locked")
	draft = editor.center; basis = view.camera.basis; editor.commit()
	check(view.camera_target == draft and view.camera_distance == radius and view.camera.basis == basis and view.orbit_enabled,label+": locked Apply retains current basis and commits exact draft radius")
	check(not editor.visible and editor.guide.surface.render_target_update_mode == SubViewport.UPDATE_DISABLED,label+": Apply disables transient shading viewport")
	view.orbit_enabled = false
	for repeat in 3:
		var saved := state(view); view.shell.edit_orbit_center(); editor.set_position_locked(true)
		fields(editor,draft+Vector3(.1,.2,-.3)*scale,radius*1.3)
		steer(view,Vector2(9,-7)); tumble(view,Vector2(20,-11)); movement_keys(view,label+" cancel"); editor.dismiss()
		check(state(view) == saved and not editor.position_locked,label+": Cancel restores full state and clears lock "+str(repeat))
	for node in scientific: check(node.transform == scientific[node],label+": scientific transform unchanged "+node.name)
	check(view.committed_sample == sample,label+": scientific sample unchanged")
	cases.append(label)

func dense_views(view, mode: String) -> void:
	view._open_capture(output.path_join("dense-field.wvz")); view.playing = false; await ready(view)
	view.scene_layers.states.field.opacity = 10.; view.scene_layers.resample()
	view._reset_camera(); view.orbit_enabled = false; view.camera_target = Vector3.ZERO; view.camera_distance = 4.2
	view.yaw = .22; view.pitch = -.15; view.camera_orbit_basis_active = false; view._update_camera()
	var before := state(view); var scientific := world(view)
	view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor
	fields(editor,Vector3(.1,.1,.1),1.45); editor.set_position_locked(true); editor.show_details(true)
	await screenshot("dense-close-"+mode)
	if DisplayServer.get_name() != "headless":
		var image: Image = editor.guide.surface.get_texture().get_image()
		var opaque := 0; var colors := {}
		for y in range(0,image.get_height(),8):
			for x in range(0,image.get_width(),8):
				var color: Color = image.get_pixel(x,y)
				if color.a > .95: opaque += 1; colors[color.to_html()] = true
		check(opaque > 200 and colors.size() > 30,"Dense "+mode+": opaque shaded sphere has area and distinct lighting shades")
		shading.append({"mode":mode,"opaque_sampled_pixels":opaque,"distinct_shades":colors.size()})
	var center: Vector3 = editor.center; var radius: float = editor.radius
	focus_none(); var pose: Transform3D = view.camera.transform
	orbit(view,.75); await screenshot("dense-side-"+mode)
	check(view.camera.position != pose.origin,"Dense "+mode+": side viewpoint actually moves camera")
	check(editor.center == center and editor.radius == radius,"Dense "+mode+": multiple viewpoint orbit retains exact draft")
	editor.show_details(false); await process_frame
	for axis in 3: handle_drag(view,axis,editor.edit_basis,"Dense "+mode+" side viewpoint locked")
	fields(editor,center,radius); await screenshot("dense-compact-"+mode)
	fields(editor,center,12.)
	check(view.camera.position.distance_to(editor.center) < editor.radius,"Dense "+mode+": large-radius case puts camera inside guide")
	await screenshot("dense-large-radius-"+mode)
	check(editor.guide.sphere.scale == Vector3.ONE*12. and editor.guide.surface_camera.transform == view.camera.global_transform,"Dense "+mode+": large shaded radius and camera projection stay synchronized")
	view.camera_target += view.camera.basis.z*28.; view._update_camera(); await process_frame
	check(view.camera.position.distance_to(center) > editor.radius and editor.center == center and editor.radius == 12.,"Dense "+mode+": Free Camera leaves large radius without changing draft")
	await screenshot("dense-large-exterior-"+mode)
	editor.dismiss(); check(state(view) == before,"Dense "+mode+": Cancel restores pre-edit pose")
	for node in scientific: check(node.transform == scientific[node],"Dense "+mode+": scientific transform unchanged "+node.name)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--orbit-view-output="): output = arg.trim_prefix("--orbit-view-output=")
	if output.is_empty(): quit(1); return
	create_timer(180).timeout.connect(func(): push_error("Locked orbit placement test timed out"); quit(1))
	var view = Viewer.new(); root.add_child(view); view.set_process(false)
	view.shell.shortcuts.active.orbit_camera_left = KEY_F6; view.shell.shortcuts.active.orbit_camera_right = KEY_F7
	for mode in ["normal","fullscreen"]:
		if mode == "fullscreen": view.shell.enter_immersive()
		for kind in ["particles","field","mesh","mixed"]:
			for scale_name in ["small","large"]:
				view._open_capture(output.path_join(kind+"-"+scale_name+".wvz")); view.playing = false; await ready(view)
				await lock_exercise(view,kind+" / "+scale_name+" / "+mode,.01 if scale_name == "small" else 1000.)
		await dense_views(view,mode)
		if mode == "fullscreen": view.shell.exit_immersive()
	for frame in 3: await process_frame
	var report := {"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"refinement":"locked placement","shading":shading}
	var file := FileAccess.open(output.path_join("orbit-view-report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	view.queue_free(); await process_frame
	print("ORBIT CENTER LOCK: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
