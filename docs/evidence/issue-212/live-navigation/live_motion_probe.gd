extends "res://ui/shell/test_orbit_center_view.gd"
# Diagnostic only: no direct movement, camera update, editor refresh or forced draw
# occurs between initial Place ahead and the final captured rendered frame.
var rows: Array = []
var history: Array[Transform3D] = []
var local_rays: Array[Vector3] = []
var pixels: Array[Vector2i] = []
var native_view
var fixed_center := Vector3.ZERO
var fixed_radius := 18.0
var phase := "setup"
var output_path := ""
var prior_tick := 0
var source_path := "/tmp/wavez-212-world-candidate-forward-final/world-field.wvz"
var actual_field
var landmark_a := Vector3(24,20,16)
var landmark_b := Vector3(36,27,12)
var events: Array = []
var total_frames := 0

func vv(v: Vector3) -> Array: return [v.x,v.y,v.z]
func pp(v: Vector2) -> Array: return [v.x,v.y]
func tx(t: Transform3D) -> Dictionary:
	return {"origin":vv(t.origin),"basis":[vv(t.basis.x),vv(t.basis.y),vv(t.basis.z)]}
func focus_info() -> String:
	var node := root.gui_get_focus_owner()
	return str(node)+(" text="+node.text if node is Button or node is LineEdit else "")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()

func measure(view, label: String, save := false) -> void:
	# Called immediately after a genuinely rendered frame, never after force_draw.
	var editor = view.shell.orbit_editor; var guide = editor.guide
	var now := Time.get_ticks_usec()
	var image: Image = guide.surface.get_texture().get_image()
	var pose: Transform3D = view.camera.global_transform
	history.push_front(pose)
	if history.size()>4: history.pop_back()
	var actual := PackedByteArray(); actual.resize(pixels.size())
	var occupied := 0; var centroid := Vector2.ZERO
	for i in pixels.size():
		var p := pixels[i]
		actual[i] = 1 if image.get_pixel(p.x,p.y).a > .5 else 0
		if actual[i] == 1: occupied += 1; centroid += Vector2(p)
	if occupied > 0: centroid /= occupied
	var comparisons: Array = []
	for delay in history.size():
		var camera_center: Vector3 = history[delay].affine_inverse()*fixed_center
		var offset := -camera_center; var c := offset.length_squared()-fixed_radius*fixed_radius
		var mismatch := 0; var expected_occupied := 0; var compared := 0
		for i in pixels.size():
			var b := offset.dot(local_rays[i]); var discriminant := b*b-c
			if absf(discriminant) < fixed_radius*fixed_radius*.025: continue
			var predicted: bool = discriminant > 0. and -b+sqrt(maxf(0.,discriminant)) > view.camera.near
			if predicted: expected_occupied += 1
			if predicted != (actual[i] == 1): mismatch += 1
			compared += 1
		comparisons.append({"camera_frames_old":delay,"mismatches":mismatch,"occupied":expected_occupied,"compared":compared,"fraction_of_sphere":float(mismatch)/maxi(1,expected_occupied)})
	var field = actual_field
	var a: Vector3 = field.world_to_grid.affine_inverse()*landmark_a
	var b: Vector3 = field.world_to_grid.affine_inverse()*landmark_b
	rows.append({"phase":label,"frame_drawn":Engine.get_frames_drawn(),"process_frame":Engine.get_process_frames(),"tick_usec":now,"elapsed_usec":now-prior_tick,
		"camera":tx(pose),"surface_camera":tx(guide.surface_camera.global_transform),"sphere":tx(guide.sphere.global_transform),
		"target":vv(view.camera_target),"navigation_distance":view.camera_distance,"draft_center":vv(editor.center),"draft_radius":editor.radius,
		"surface_camera_position_error":view.camera.global_position.distance_to(guide.surface_camera.global_position),
		"camera_surface_projection_error":view.camera.unproject_position(fixed_center).distance_to(guide.surface_camera.unproject_position(fixed_center)),
		"gizmo_projection":pp(view.camera.unproject_position(fixed_center)),"sphere_alpha_centroid":pp(centroid),"sphere_occupied_samples":occupied,
		"landmark_A_world":vv(a),"landmark_A_pixel":pp(view.camera.unproject_position(a)),"landmark_B_world":vv(b),"landmark_B_pixel":pp(view.camera.unproject_position(b)),
		"main_process":view.is_processing(),"editor_process":editor.is_processing(),"main_priority":view.process_priority,"editor_priority":editor.process_priority,
		"surface_update_mode":guide.surface.render_target_update_mode,"focus":focus_info(),"comparisons":comparisons})
	prior_tick = now
	root.get_texture().get_image().save_png(output_path.path_join("frame-%04d.png" % total_frames))
	if save:
		image.save_png(output_path.path_join(label+"-annotation.png"))
		root.get_texture().get_image().save_png(output_path.path_join(label+"-main.png"))

func rendered_frame() -> void:
	total_frames += 1
	measure(native_view,phase+"-"+str(total_frames),total_frames%5==0)

func phase_start(name: String) -> void:
	phase = name
	events.append({"phase":name,"start_usec":Time.get_ticks_usec(),"frame_drawn":Engine.get_frames_drawn(),"camera":tx(native_view.camera.global_transform),"focus":focus_info()})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--live-output="): output_path = arg.trim_prefix("--live-output=")
		if arg.begins_with("--capture="): source_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--live-radius="): fixed_radius = arg.trim_prefix("--live-radius=").to_float()
	if output_path.is_empty(): quit(2); return
	create_timer(240).timeout.connect(func(): push_error("Live diagnostic timed out"); quit(2))
	var view = Viewer.new(); root.add_child(view); native_view = view; view.set_process(false)
	view._open_capture(source_path); view.playing = false; await ready(view)
	view.environment.glow_enabled = false
	for layer in view.scene_layers.views.values():
		if not layer is MeshInstance3D: actual_field = layer; break
	var field = actual_field
	if source_path.contains("frozen-t30.5"):
		landmark_a = ((field.grid_size-Vector3.ONE)*.5).floor()
		landmark_b = ((field.grid_size-Vector3.ONE)*Vector3(.65,.4,.4)).floor()
	fixed_center = field.world_to_grid.affine_inverse()*landmark_a
	var source_before: PackedByteArray = var_to_bytes([field.data.channels,field.world_to_grid,field.material.get_shader_parameter("world_to_grid")])
	view.orbit_enabled = false; view.free_camera = true; view.free_camera_speed_scale = .7
	view.camera.near = .05; view.camera.far = 20000
	view.camera.basis = Basis.IDENTITY; view.camera.position = fixed_center+Vector3(0,0,120)
	view.camera_distance = 120.; view.camera_target = fixed_center; view._adopt_camera_basis()
	view.shell.edit_orbit_center(); var editor = view.shell.orbit_editor
	fields(editor,fixed_center,fixed_radius); editor.depth_input.text = "120"; editor.read_fields()
	for frame in 8: await process_frame
	var button: Button
	for child in editor.panel.get_child(0).get_children()[-1].get_children():
		if child is Button and child.text == "Place ahead": button = child
	var signal_count := {"count":0}; button.pressed.connect(func(): signal_count.count += 1)
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = button.get_global_rect().get_center()
	root.push_input(press,true); press.pressed = false; root.push_input(press,true)
	# All setup edits end here. Live app process and actual held keys own motion.
	view.set_process(true)
	for y in range(4,root.size.y,8):
		for x in range(4,root.size.x,8):
			pixels.append(Vector2i(x,y)); local_rays.append(view.camera.global_basis.inverse()*view.camera.project_ray_normal(Vector2(x,y)))
	RenderingServer.frame_post_draw.connect(rendered_frame)
	phase_start("initial-idle"); await create_timer(.2).timeout
	for code in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_Q,KEY_E]:
		var name := OS.get_keycode_string(code)
		phase_start(name+"-held"); key(code,true)
		await create_timer(.35).timeout
		phase_start(name+"-released"); key(code,false)
		await create_timer(.2).timeout
	RenderingServer.frame_post_draw.disconnect(rendered_frame)
	var source_after: PackedByteArray = var_to_bytes([field.data.channels,field.world_to_grid,field.material.get_shader_parameter("world_to_grid")])
	var report := {"rows":rows,"events":events,"source":source_path,"landmark_A_grid":vv(landmark_a),"landmark_B_grid":vv(landmark_b),"real_place_pressed_count":signal_count.count,"source_unchanged":source_before==source_after,"renderer":RenderingServer.get_current_rendering_method(),"initial_center":vv(fixed_center),"radius":fixed_radius,"direct_camera_updates_during_measurements":false,"manual_editor_refresh_during_measurements":false,"force_draw_during_measurements":false}
	var file := FileAccess.open(output_path.path_join("live-motion-report.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	view.set_process(false); view.queue_free(); for frame in 3: await process_frame
	print("LIVE MOTION DIAGNOSTIC: "+str(rows.size())+" rendered frames"); quit(0)
