extends SceneTree
const Viewer=preload("res://main.gd")
var view
var editor
var rows: Array=[]
var output="/tmp/issue212-volume-live"
var feature=Vector3(12,-9,6)
func _initialize(): run.call_deferred()
func vec(v):return [v.x,v.y,v.z]
func hide_ui(node):
	if node is CanvasLayer:node.visible=false
	for child in node.get_children():hide_ui(child)
func center(im: Image, alpha := false) -> Dictionary:
	var total:=0.;var weighted:=Vector2.ZERO;var occupied:=0
	for y in range(0,im.get_height(),2):
		for x in range(0,im.get_width(),2):
			var color:=im.get_pixel(x,y)
			var w:float=color.a if alpha else color.r
			if w<.03:continue
			weighted+=Vector2(x+.5,y+.5)*w;total+=w;occupied+=1
	return {"point":weighted/maxf(total,.001),"mass":total,"samples":occupied}
func sample(label: String, save:=false):
	var actual:=center(root.get_texture().get_image())
	var sphere:=center(editor.guide.surface.get_texture().get_image(),true)
	var predicted:Vector2=view.camera.unproject_position(feature)
	var projected:Vector2=editor.guide.surface_camera.unproject_position(editor.center)
	var rec={"label":label,"camera":str(view.camera.global_transform),"annotation_camera":str(editor.guide.surface_camera.global_transform),"draft":str(editor.center),"feature":str(feature),"feature_projected":str(predicted),"actual_volume_centroid":str(actual.point),"volume_error_px":actual.point.distance_to(predicted),"volume_samples":actual.samples,"sphere_projected":str(projected),"actual_sphere_centroid":str(sphere.point),"sphere_error_px":sphere.point.distance_to(projected),"camera_error":view.camera.global_position.distance_to(editor.guide.surface_camera.global_position)}
	rows.append(rec)
	if save:
		root.get_texture().get_image().save_png(output.path_join(label+"-main.png"))
		editor.guide.surface.get_texture().get_image().save_png(output.path_join(label+"-annotation.png"))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	create_timer(90).timeout.connect(func():push_error("Live volume probe timeout");quit(2))
	view=Viewer.new();root.add_child(view);view.set_process(false)
	view._open_capture("/tmp/issue212-volume-live/gaussian.wvz");view.playing=false
	for i in 300:
		await process_frame;view._process(0)
		if not view.scene_layers.is_buffering():break
	view.environment.background_mode=Environment.BG_COLOR;view.environment.background_color=Color.BLACK;view.environment.background_energy_multiplier=1.
	view.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;view.environment.glow_enabled=false;view.environment.fog_enabled=false
	var layer=view.scene_layers.views.field
	var white:=Image.create(256,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE)
	layer.material.set_shader_parameter("transfer",ImageTexture.create_from_image(white));layer.material.set_shader_parameter("opacity",.15);layer.material.set_shader_parameter("step_world",.1)
	view.camera_target=feature;view.camera_distance=130.;view.yaw=.35;view.pitch=.17;view.camera_orbit_basis_active=false;view._update_camera()
	view.camera.near=.05;view.camera.far=2000.;view.orbit_enabled=false;view.free_camera=true;view.free_camera_speed_scale=.08
	view.shell.edit_orbit_center();editor=view.shell.orbit_editor;editor.center=feature;editor.radius=3.;editor.write_fields();editor.refresh()
	hide_ui(view)
	view.set_process(true)
	for i in 4:await process_frame
	RenderingServer.force_draw(false) # Initial still image only; no forced draws during movement.
	sample("initial",true)
	for keycode in [KEY_A,KEY_D,KEY_Q,KEY_E,KEY_W,KEY_S]:
		var key:=InputEventKey.new();key.physical_keycode=keycode;key.pressed=true;Input.parse_input_event(key);Input.flush_buffered_events()
		for i in 8:
			await RenderingServer.frame_post_draw
			sample(OS.get_keycode_string(keycode)+"-"+str(i),i==7)
		key=key.duplicate();key.pressed=false;Input.parse_input_event(key);Input.flush_buffered_events()
	view.set_process(false)
	var file=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"rows":rows},"\t"));file.close()
	view.queue_free();for i in 3:await process_frame
	print("VOLUME LIVE ",rows.size()," records");quit()
