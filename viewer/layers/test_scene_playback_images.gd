extends SceneTree
const Inspection = preload("res://scene/inspection_state.gd")
const Job = preload("res://video/render_job.gd")
var base := ""
var checks: Array = []
func check(ok: bool, name: String) -> void:
	checks.append({"name":name,"ok":ok})
	if not ok:push_error(name)
func _initialize() -> void:run.call_deferred()
func render(asynchronous: bool, vp: SubViewport) -> Dictionary:
	var view = load("res://main.gd").new()
	view.capture_path = base.path_join("ids.ssc");view.scene_prebuffer_enabled = asynchronous;view.scene_hidden_fast_path = asynchronous
	view.playing = false;view.orbit_enabled = false
	vp.add_child(view);view.set_process(false)
	view._set_clean(false);view.environment.glow_enabled = false;view.environment.fog_enabled = false;view.starfield.visible = false
	view.overlay_panel.visible = false;view.show_panel_button.visible = false;view.resize_handle.visible = false;view.show_legend = false
	view.color_channel = "scalar";view.size_channel = "visual_size";view.brightness_channel = "visual_brightness"
	view.trails_enabled = true;view.normalization_mode = "symmetric";view.auto_range = true;view._update_colormap()
	view.scene_layers.states.field.visible = false;view.scene_layers.particle_key = ""
	var start := Time.get_ticks_msec()
	while true:
		var result: Dictionary = view.scene_layers.sample(1.25,asynchronous)
		if not result.has("pending"):break
		if Time.get_ticks_msec()-start>10000:push_error("Image pair timeout");break
		await process_frame
	view.camera.position = Vector3(5,3,7);view.camera.look_at(Vector3(1.5,-.5,.3));view.point_scale = 4;view._sync_visuals()
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var state := Inspection.snapshot(view)
	if asynchronous:
		state.visual.overlay_visible = false
		var job := {"version":1,"capture_path":view.capture_path,"source":state.source,"state":state.visual,"start_time":1.25,"end_time":1.75,"fps":8,"playback_rate":1.0,"width":512,"height":384,"output_path":base.path_join("placeholder.mp4"),"camera_mode":"locked","orbit_speed":0.0,"quality":"high","keep_frames":true,"inspection_sidecars":true,"ffmpeg_path":"/usr/bin/ffmpeg"}
		Job.write_json(base.path_join("video-job.json"),job)
	view.free();await process_frame
	return {"image":image,"sample":state.sample,"identity":state.particle_identity}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-fixture="):base = arg.trim_prefix("--playback-fixture=")
	if base.is_empty() or DisplayServer.get_name()=="headless":push_error("Requires fixture and real GPU");quit(1);return
	var vp := SubViewport.new();vp.size = Vector2i(512,384);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED;vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED;vp.use_taa = false;vp.use_debanding = false
	root.add_child(vp)
	var reference := await render(false,vp)
	var prepared := await render(true,vp)
	var backend := RenderingServer.get_current_rendering_method()
	reference.image.save_png(base.path_join("synchronous-"+backend+".png"));prepared.image.save_png(base.path_join("prepared-"+backend+".png"))
	check(reference.image.get_data()==prepared.image.get_data(),"prepared and synchronous rendered pixels identical")
	check(reference.sample==prepared.sample,"image source clocks and interpolation metadata identical")
	check(reference.identity==prepared.identity,"image inspection preserves persistent identity")
	var lit := 0
	for y in range(reference.image.get_height()):
		for x in range(reference.image.get_width()):
			var color: Color = reference.image.get_pixel(x,y)
			if maxf(color.r,maxf(color.g,color.b))>.06:lit += 1
	check(lit>10,"render contains nontrivial image values")
	Job.write_json(base.path_join("images-"+backend+".json"),{"checks":checks,"backend":backend})
	vp.queue_free();await process_frame
	print("G3 PLAYBACK IMAGES ",checks)
	quit(0 if checks.all(func(c):return c.ok) else 1)
