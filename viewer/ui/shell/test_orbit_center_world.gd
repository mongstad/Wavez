extends "res://ui/shell/test_orbit_center_view.gd"
## PR #301: compare actual annotation rendering with transformed scientific landmarks.
var records: Array = []
var depth_probes: Array = []
var pixel_probes: Array = []
var click_traces: Array = []
var manifest: Dictionary
var explicit_depth := false
var markers: Control

class LandmarkLabels extends Control:
	var camera: Camera3D
	var points: Array = []
	func _draw() -> void:
		if camera == null: return
		for item in points:
			if camera.is_position_behind(item.world): continue
			var pixel := camera.unproject_position(item.world)
			draw_arc(pixel,10,0,TAU,32,Color("ffd270"),2,true)
			draw_string_outline(ThemeDB.fallback_font,pixel+Vector2(13,-12),"Scientific landmark "+item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,4,Color.BLACK)
			draw_string(ThemeDB.fallback_font,pixel+Vector2(13,-12),"Scientific landmark "+item.name,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ffd270"))

func v3(value: Vector3) -> Array: return [value.x,value.y,value.z]
func v2(value: Vector2) -> Array: return [value.x,value.y]
func transform_record(value: Transform3D) -> Dictionary:
	return {"origin":v3(value.origin),"basis":[v3(value.basis.x),v3(value.basis.y),v3(value.basis.z)]}
func vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func fingerprint(view) -> PackedByteArray:
	var data := {"particles":view.frame_a.positions,"sample":view.committed_sample.duplicate(true)}
	for id in view.scene_layers.views:
		var layer = view.scene_layers.views[id]
		data[id] = [layer.source_positions,layer.mesh.surface_get_arrays(0)] if layer is MeshInstance3D else [layer.data.channels,layer.world_to_grid,layer.material.get_shader_parameter("world_to_grid")]
	return var_to_bytes(data)

func landmarks(view, kind: String) -> Array:
	var result: Array = []
	for item in manifest.landmarks[kind]:
		var position: Vector3
		var source := ""
		if kind == "field":
			var layer = view.scene_layers.views.field
			position = layer.world_to_grid.affine_inverse()*vector(item.grid)
			source = "committed field grid index transformed by inverse shader world_to_grid"
			check(layer.material.get_shader_parameter("world_to_grid") == layer.world_to_grid,"Field landmark uses the actual volume shader transform")
		elif kind == "mesh":
			var layer = view.scene_layers.views.mesh
			position = layer.global_transform*layer.source_positions[int(item.index)]
			source = "committed source mesh vertex transformed by actual mesh global_transform"
		else:
			position = view.current_instance.global_transform*view.frame_a.positions[int(item.index)]
			source = "committed source particle transformed by actual render instance global_transform"
		check(position.distance_to(vector(item.expected_world)) < .0002,kind+": independent fixture and rendered landmark world positions agree")
		result.append({"name":item.name,"world":position,"source":source})
	return result

func restore(view, saved: Dictionary) -> void:
	view.camera_target = saved.target; view.camera_distance = saved.radius; view.camera.transform = saved.pose
	view.yaw = saved.yaw; view.pitch = saved.pitch; view.camera_orbit_basis = saved.basis; view.camera_orbit_basis_active = saved.active
	view.camera_orbit_basis_yaw = saved.basis_yaw; view.camera_orbit_basis_pitch = saved.basis_pitch
	view.orbit_enabled = saved.auto; view.free_camera = saved.free
	if view.shell.orbit_editor.visible: view.shell.orbit_editor.navigation_distance = saved.radius

func aim(view, feature: Vector3, distance: float, navigation: float) -> void:
	view.orbit_enabled = false; view.free_camera = true
	view.camera.near = .05; view.camera.far = 20000
	var orientation := Basis(Vector3.UP,.37)*Basis(Vector3.RIGHT,-.18)*Basis(Vector3.BACK,.09)
	view.camera.transform = Transform3D(orientation,feature+orientation.z*distance)
	view.camera_distance = navigation; view.camera_target = view.camera.position-orientation.z*navigation
	view._adopt_camera_basis()

func sample_record(view, points: Array, label: String) -> Dictionary:
	var editor = view.shell.orbit_editor
	editor.refresh(); markers.queue_redraw()
	var guide = editor.guide
	var projected: Vector2 = view.camera.unproject_position(editor.center)
	var rendered: Vector2 = guide.surface_camera.unproject_position(guide.sphere.global_position)
	# Convert the separate viewport's pixels through the actual texture destination.
	var mapped: Vector2 = rendered*guide.get_viewport_rect().size/Vector2(guide.surface.size)
	var landmark_rows: Array = []
	for item in points:
		landmark_rows.append({"name":item.name,"source":item.source,"world":v3(item.world),
			"scientific_pixel":v2(view.camera.unproject_position(item.world)),
			"annotation_pixel":v2(guide.surface_camera.unproject_position(item.world)),
			"camera_depth":-(view.camera.global_transform.affine_inverse()*item.world).z})
	check(guide.sphere.global_position == editor.center,label+": actual sphere transform matches draft world XYZ")
	check(guide.sphere.scale == Vector3.ONE*editor.radius,label+": actual sphere scale matches draft radius")
	check(mapped.distance_to(projected) < .002,label+": separate rendered viewport maps to scientific camera projection")
	var result := {"label":label,"camera":transform_record(view.camera.global_transform),"target":v3(view.camera_target),
		"navigation_distance":view.camera_distance,"draft_center":v3(editor.center),"draft_radius":editor.radius,
		"gizmo_render_transform":transform_record(guide.sphere.global_transform),
		"surface_camera":transform_record(guide.surface_camera.global_transform),"surface_size":v2(Vector2(guide.surface.size)),
		"gizmo_scientific_pixel":v2(projected),"gizmo_rendered_pixel":v2(mapped),"projection_error_px":mapped.distance_to(projected),
		"distance_to_gizmo":view.camera.global_position.distance_to(editor.center),
		"center_view_depth":-(view.camera.global_transform.affine_inverse()*editor.center).z,
		"placement_depth":editor.get("placement_depth") if explicit_depth else -(view.camera.global_transform.affine_inverse()*editor.center).z,
		"scientific_landmarks":landmark_rows}
	records.append(result); return result

func pixels(view, label: String) -> PackedByteArray:
	if DisplayServer.get_name() == "headless": return PackedByteArray()
	var editor = view.shell.orbit_editor; var guide = editor.guide
	for frame in 3: await process_frame
	RenderingServer.force_draw(false)
	var image: Image = guide.surface.get_texture().get_image()
	var compared := 0; var mismatches := 0; var occupied := 0; var expected_occupied := 0; var mask := PackedByteArray()
	# Independently predict coverage from scientific-camera rays and stored world
	# center/radius, then inspect actual pixels in the separate rendered viewport.
	for y in range(12,image.get_height(),24):
		for x in range(12,image.get_width(),24):
			var pixel: Vector2 = Vector2(x,y)*view.camera.get_viewport().get_visible_rect().size/Vector2(image.get_size())
			var origin: Vector3 = view.camera.project_ray_origin(pixel)
			var direction: Vector3 = view.camera.project_ray_normal(pixel)
			var offset: Vector3 = origin-editor.center
			var b := offset.dot(direction); var c: float = offset.length_squared()-editor.radius*editor.radius
			var discriminant := b*b-c
			if absf(discriminant) < editor.radius*editor.radius*.08: continue # rasterized rim tolerance
			var expected: bool = discriminant > 0 and -b+sqrt(maxf(0,discriminant)) > view.camera.near
			var actual := image.get_pixel(x,y).a > .5
			mask.append(1 if actual else 0)
			compared += 1
			if actual: occupied += 1
			if expected: expected_occupied += 1
			if actual != expected: mismatches += 1
	check(compared > 100 and occupied > 0,label+": actual shaded sphere pixels available")
	var coverage := maxi(1,maxi(occupied,expected_occupied))
	check(mismatches <= 2 and float(mismatches)/coverage < .03,label+": actual shaded pixels agree with scientific-camera ray/sphere intersections")
	pixel_probes.append({"label":label,"samples":compared,"occupied":occupied,"expected_occupied":expected_occupied,"mismatches":mismatches,"mismatch_fraction":float(mismatches)/coverage})
	return mask

func move_key(view, code: int, clear_focus := true) -> void:
	if clear_focus: focus_none()
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); view._move_free_camera(.24)
	event = event.duplicate(); event.pressed = false; Input.parse_input_event(event); Input.flush_buffered_events()

func navigation_point(view) -> Vector2:
	var editor = view.shell.orbit_editor
	for candidate in [Vector2(90,180),Vector2(90,300),Vector2(240,180),Vector2(980,180)]:
		if editor.panel.get_global_rect().has_point(candidate) or not view.shell.edge_reveal.is_viewport_point(candidate): continue
		var available := true
		for axis in 3:
			var handle: Dictionary = editor.guide.handle(axis)
			if not handle.is_empty() and candidate.distance_to(handle.end) < 18: available = false
		if available: return candidate
	check(false,"Unobstructed scientific viewport input point exists")
	return Vector2(90,180)

func lmb(view, movement: Vector2) -> void:
	focus_none(); var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = navigation_point(view)
	root.push_input(press,true)
	var motion := InputEventMouseMotion.new(); motion.position = press.position+movement; root.push_input(motion,true)
	press.pressed = false; root.push_input(press,true)

func focus_record() -> Dictionary:
	var focused := root.gui_get_focus_owner()
	return {"node":str(focused),"text":focused.text if focused is Button or focused is LineEdit else ""}

func click_place(editor) -> void:
	var button: Button
	for node in editor.panel.get_child(0).get_children()[-1].get_children():
		if node is Button and node.text == "Place ahead": button = node
	check(button != null,"Real Place ahead control is present")
	if button == null: return
	var signal_state := {"count":0}
	var callback := func(): signal_state.count += 1
	button.pressed.connect(callback)
	var rect: Rect2 = button.get_global_rect()
	var trace := {"button":str(button),"text":button.text,"button_rect":str(rect),"panel_rect":str(editor.panel.get_global_rect()),"focus_before":focus_record(),"center_before":v3(editor.center)}
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = rect.get_center()
	root.push_input(press,true); trace["focus_after_press"] = focus_record()
	press = press.duplicate(); press.pressed = false; root.push_input(press,true)
	trace["focus_after_release"] = focus_record(); trace["pressed_signal_count"] = signal_state.count
	trace["center_after"] = v3(editor.center); trace["button_rect_after"] = str(button.get_global_rect())
	button.pressed.disconnect(callback); click_traces.append(trace)
	check(signal_state.count == 1,"Real Place ahead pointer press/release emits exactly one pressed signal")

func depth_experiment(view, points: Array) -> void:
	var feature: Vector3 = points[0].world
	for navigation in [60.,360.]:
		aim(view,feature,60.,navigation); var before := state(view)
		view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor; fields(editor,editor.center,34.07)
		await process_frame
		click_place(editor)
		var after_click := state(view)
		var click_focus := root.gui_get_focus_owner()
		move_key(view,KEY_W,false)
		var immediate_travel: float = view.camera.position.distance_to(after_click.pose.origin)
		check(immediate_travel > 0.,"Actual Place ahead click permits immediate W navigation without test focus clearing")
		restore(view,after_click)
		var placed := sample_record(view,points,"depth-history-"+str(navigation)+"-placed")
		placed["focus_after_real_click"] = str(click_focus)
		placed["immediate_W_camera_travel"] = immediate_travel
		var center: Vector3 = editor.center
		move_key(view,KEY_D)
		var side := sample_record(view,points,"depth-history-"+str(navigation)+"-side")
		var separation: float = view.camera.unproject_position(center).distance_to(view.camera.unproject_position(feature))
		depth_probes.append({"prior_navigation_distance":navigation,"feature_distance_at_identical_pose":60.,"placed":placed,"after_lateral_navigation":side,"feature_world_error":center.distance_to(feature),"side_feature_separation_px":separation})
		if navigation == 360.:
			await pixels(view,"ambiguous-depth-before-correction")
			await screenshot("depth-ambiguity-side")
		var frozen_depth: float = editor.get("placement_depth") if explicit_depth else -(view.camera.global_transform.affine_inverse()*editor.center).z
		move_key(view,KEY_W); click_place(editor)
		var actual_depth: float = -(view.camera.global_transform.affine_inverse()*editor.center).z
		if explicit_depth: check(is_equal_approx(actual_depth,frozen_depth),"Place ahead explicit depth remains unchanged by free translation")
		else: check(not is_equal_approx(actual_depth,frozen_depth),"Baseline measured inherited placement depth changes after free translation")
		depth_probes[-1]["depth_before_W"] = frozen_depth; depth_probes[-1]["depth_after_W_and_place"] = actual_depth
		if explicit_depth:
			var old: Vector3 = editor.center; var pose: Transform3D = view.camera.transform
			editor.depth_input.text = "60"; check(editor.read_fields(),"Explicit placement depth accepts numeric input")
			check(editor.center == old and view.camera.transform == pose,"Editing placement depth alone leaves draft and camera untouched")
			click_place(editor)
			check(editor.center.distance_to(view.camera.global_position-view.camera.global_basis.z*60.) < .0001,"Place ahead uses requested depth on the current forward ray")
			check(editor.radius == 34.07 and view.camera.transform == pose,"Explicit Place ahead preserves selected radius and full camera pose")
			explicit_field_contract(view)
			# Restore precisely the earlier pose with the wrong 360-unit navigation
			# history, then explicitly place at the actual feature 60 units ahead.
			restore(view,after_click); editor.depth_input.text = "60"; check(editor.read_fields(),"Set explicit intended-feature depth")
			var feature_pose: Transform3D = view.camera.transform
			editor.depth_input.grab_focus(); move_key(view,KEY_W,false)
			check(view.camera.transform == feature_pose,"Depth text focus protects W while typing before Place ahead")
			click_place(editor)
			check(editor.center.distance_to(feature) < .0002,"Explicit depth reaches real scientific feature despite wrong prior navigation distance")
			var corrected_placed := sample_record(view,points,"explicit-feature-"+str(navigation)+"-placed")
			move_key(view,KEY_D,false)
			var corrected_side := sample_record(view,points,"explicit-feature-"+str(navigation)+"-side")
			var corrected_error: float = view.camera.unproject_position(editor.center).distance_to(view.camera.unproject_position(feature))
			check(corrected_error < .002,"Explicit depth retains intended scientific-feature coincidence after immediate lateral navigation")
			depth_probes[-1]["corrected_placed"] = corrected_placed; depth_probes[-1]["corrected_side"] = corrected_side; depth_probes[-1]["corrected_feature_separation_px"] = corrected_error
			if navigation == 360.:
				await pixels(view,"explicit-feature-corrected-side"); editor.show_details(false); await screenshot("depth-explicit-corrected-side")
		editor.dismiss(); check(state(view) == before,"Depth inspection Cancel restores complete original state")
	check(depth_probes[1].feature_world_error > 250. and depth_probes[1].side_feature_separation_px > 100.,"Reproduction exposes initial pixel coincidence followed by large feature parallax at inherited depth")


func explicit_field_contract(view) -> void:
	var editor = view.shell.orbit_editor
	var center: Vector3 = editor.center; var radius: float = editor.radius; var depth: float = editor.placement_depth; var pose: Transform3D = view.camera.transform
	var original_near: float = view.camera.near; view.camera.near = .125 # exactly representable invalid boundary
	for text in ["", "0", "-1", "nan", "inf", "1e309", "1000000000000001", str(view.camera.near), str(view.camera.near*.5)]:
		editor.depth_input.text = text
		# Simultaneously stage valid XYZ/radius edits; a bad depth rejects the whole draft.
		editor.coordinates[0].text = str(center.x+11.); editor.radius_input.text = str(radius*1.25)
		check(not editor.read_fields(),"Invalid placement depth rejected: "+text)
		editor.show_details(false); check(editor.notice.is_visible_in_tree(),"Invalid depth notice stays visible when controls collapse: "+text); editor.show_details(true)
		editor.place_ahead()
		check(editor.center == center and editor.radius == radius and editor.placement_depth == depth and view.camera.transform == pose,"Invalid depth leaves complete draft and pose unchanged: "+text)
		editor.write_fields()
	editor.show_details(false)
	check(editor.depth_input.is_visible_in_tree(),"Placement depth remains visible with XYZ/radius controls collapsed")
	editor.show_details(true)
	fields(editor,view.camera.global_position+view.camera.global_basis.z*100.,radius*1.25)
	check(editor.placement_depth == depth,"Behind-camera XYZ and radius edits cannot change explicit placement depth")
	editor.place_ahead()
	check(editor.center.distance_to(view.camera.global_position-view.camera.global_basis.z*depth) < .0002,"Behind-camera draft uses visible depth, without hidden navigation-distance fallback")
	check(editor.placement_depth == depth and view.camera.transform == pose,"Behind-camera placement preserves explicit depth and full pose")
	fields(editor,center,radius); view.camera.near = original_near

func exercise_world(view, kind: String, mode: String, distance: float) -> void:
	var points := landmarks(view,kind); markers.points = points; markers.camera = view.camera
	aim(view,points[0].world,distance,distance)
	var original := state(view); var science := world(view); var payload := fingerprint(view)
	view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor
	fields(editor,editor.center,12. if distance == 60. else 34.07)
	await process_frame; click_place(editor); await process_frame
	var fixed: Vector3 = editor.center; var radius: float = editor.radius; var saved := state(view)
	var initial_depth: float = editor.get("placement_depth") if explicit_depth else 0.
	var initial_mask := PackedByteArray()
	var label := kind+"-"+mode+"-"+str(int(distance))
	var initial := sample_record(view,points,label+"-placed")
	check(fixed.distance_to(points[0].world) < .0002,label+": predictable initial ray depth reaches the pre-existing scientific feature")
	if kind == "field" or kind == "mixed": initial_mask = await pixels(view,label+"-placed")
	if kind == "field": await screenshot(label+"-placed")
	if kind == "field" and distance == 360.:
		editor.show_details(false); await screenshot(label+"-placed-compact"); editor.show_details(true); await process_frame
	for action in ["W","A","S","D","Q","E","RMB","LMB","zoom-in","zoom-out","opposite-side"]:
		sample_record(view,points,label+"-before-"+action); await process_frame
		var before: Transform3D = view.camera.transform
		if action.length() == 1: move_key(view,OS.find_keycode_from_string(action))
		elif action == "RMB": steer(view,Vector2(51,-27))
		elif action == "LMB": lmb(view,Vector2(64,28))
		elif action.begins_with("zoom"):
			var event := InputEventMouseButton.new(); event.pressed = true; event.button_index = MOUSE_BUTTON_WHEEL_UP if action == "zoom-in" else MOUSE_BUTTON_WHEEL_DOWN; event.factor = 1.; event.position = navigation_point(view); root.push_input(event,true)
		else: view._orbit_camera_by_drag(Vector2(PI/.005,0),.005)
		if action == "zoom-in" and view.camera_distance < view.half_extent+view.camera.near:
			check(view.camera.transform.is_equal_approx(before),label+": close-up inward zoom respects existing scene-distance bound")
		else: check(not view.camera.transform.is_equal_approx(before),label+": gesture actually moves camera "+action)
		check(editor.center == fixed and editor.radius == radius,label+": navigation leaves exact draft unchanged "+action)
		if explicit_depth: check(editor.placement_depth == initial_depth,label+": navigation retains explicit next-placement depth "+action)
		sample_record(view,points,label+"-after-"+action)
		if (kind == "field" or kind == "mixed") and action in ["D","opposite-side"]:
			await pixels(view,label+"-"+action)
			if kind == "field":
				editor.show_details(false); await screenshot(label+"-"+action); editor.show_details(true); await process_frame
	restore(view,saved)
	var returned := sample_record(view,points,label+"-returned")
	check(initial.camera == returned.camera and initial.gizmo_rendered_pixel == returned.gizmo_rendered_pixel and initial.scientific_landmarks == returned.scientific_landmarks,label+": exact camera-pose round trip reproduces actual gizmo and scientific projections")
	if kind == "field" or kind == "mixed":
		var returned_mask: PackedByteArray = await pixels(view,label+"-returned")
		check(initial_mask == returned_mask,label+": identical camera pose reproduces identical actual shaded sphere mask")
	if kind == "field": await screenshot(label+"-returned")
	for node in science: check(node.transform == science[node],label+": scientific transform unchanged "+node.name)
	check(fingerprint(view) == payload,label+": committed payload, mesh render arrays and field shader transform unchanged")
	editor.dismiss(); check(state(view) == original,label+": Cancel restores complete original camera/navigation state")
	cases.append(label)

func settle_window() -> void:
	# Fullscreen is an asynchronous native configure operation. Clicking a stale
	# fullscreen rect immediately after restore does not reach the visible button.
	var start := Time.get_ticks_msec(); var previous := root.get_visible_rect(); var stable := 0
	while Time.get_ticks_msec()-start < 1500:
		await process_frame
		var current := root.get_visible_rect()
		stable = stable+1 if current == previous else 0; previous = current
		if stable >= 3 and (DisplayServer.get_name() == "headless" or Time.get_ticks_msec()-start >= 150): return
	check(false,"Native window dimensions settle after Fullscreen transition")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--orbit-view-output="): output = arg.trim_prefix("--orbit-view-output=")
		if arg == "--expect-explicit-depth": explicit_depth = true
	if output.is_empty(): quit(1); return
	manifest = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("world-fixtures.json")))
	create_timer(220).timeout.connect(func(): push_error("World anchoring reproduction timed out"); quit(1))
	var view = Viewer.new(); root.add_child(view); view.set_process(false)
	view.environment.glow_enabled = false
	var canvas := CanvasLayer.new(); canvas.layer = 1; root.add_child(canvas)
	markers = LandmarkLabels.new(); markers.mouse_filter = Control.MOUSE_FILTER_IGNORE; canvas.add_child(markers)
	for kind in ["particles","mesh","field","mixed"]:
		view._open_capture(output.path_join("world-"+kind+".wvz")); view.playing = false; await ready(view)
		check(view._shell_open_error.is_empty(),kind+": realistic stationary fixture opens")
		for mode in ["normal","fullscreen"]:
			if mode == "fullscreen": view.shell.enter_immersive(); await settle_window()
			for distance in [60.,360.]: await exercise_world(view,kind,mode,distance)
			if mode == "fullscreen": view.shell.exit_immersive(); await settle_window()
	var points := landmarks(view,"mixed"); markers.points = points
	await depth_experiment(view,points)
	var report := {"checks":checks,"failures":failures,"cases":cases,"renderer":RenderingServer.get_current_rendering_method(),"explicit_depth":explicit_depth,"records":records,"depth_probes":depth_probes,"pixel_probes":pixel_probes,"click_traces":click_traces,"fixture_manifest":manifest}
	var file := FileAccess.open(output.path_join("orbit-world-report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	canvas.queue_free(); view.queue_free(); for frame in 3: await process_frame
	print("ORBIT WORLD: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
