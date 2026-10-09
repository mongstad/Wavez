extends SceneTree
const Graph = preload("res://scene/bloom_prototype_graph.gd")
const Job = preload("res://video/render_job.gd")
const Visual = preload("res://scene/visual_state.gd")
var viewer
var graph
var output := ""
var mode := ""
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var benchmarks: Array = []
var target: SubViewport
var transitions: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("FAILED: ",label)
func settle(count := 5) -> void:
	for i in count: await process_frame
	RenderingServer.force_draw(false)
func digest(image: Image) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(image.get_data());return context.finish().hex_encode()
func screen(name: String) -> void:
	await settle()
	hide_ui();RenderingServer.force_draw(false)
	check(target.get_texture().get_image().save_png(output.path_join(mode+"-"+name+".png")) == OK, name+" screenshot")
func hide_ui() -> void:
	viewer.tools_ui.close(false);viewer.shell.hide();viewer.overlay_panel.hide();viewer.legend.hide();viewer.colorbar.hide()
	viewer.shell.bar.hide();viewer.shell.bottom_strip.hide();viewer.shell.dock.hide()
	viewer.show_legend = false;viewer.guide_mesh.hide();viewer.resize_handle.hide()
	for layer in viewer.find_children("*","CanvasLayer",true,false):
		if graph == null or layer != graph.overlay: layer.visible = false
func load_scene(name: String) -> void:
	if graph != null: graph.dispose();graph.free();graph = null
	viewer._open_capture(output.path_join(name+".wvz"))
	check(viewer._shell_open_error.is_empty(),name+" opens")
	viewer._apply_preset("Cinematic");viewer.camera.position = Vector3(0,0,9)
	viewer.camera.look_at(Vector3.ZERO);viewer.camera.fov = 45;viewer._adopt_camera_basis();viewer.camera_target = Vector3.ZERO
	if name == "particles": viewer.camera.position.x = -2.5;viewer.camera.look_at(Vector3(-2.5,0,0));viewer._adopt_camera_basis()
	if viewer.scene_layers != null:
		for id in viewer.scene_layers.states:
			var state: Dictionary = viewer.scene_layers.states[id];state.visible = true
			if state.has("volume"):
				state.lower = 0.0;state.upper = 1.0;state.opacity = .7;state.step = .08
				state.volume = name not in ["slice", "iso"];state.slice = name == "slice"
				if name == "heavy" and id != "f":state.volume = false;state.slice = true
			elif id == "m":state.channel = "value";state.lower = 0.0;state.upper = 1.0
		var committed: Dictionary = viewer.scene_layers.sample(viewer.requested_time,false)
		check(not committed.is_empty() and not committed.get("pending",false),name+" synchronous fixture commit")
		check(viewer.scene_layers.error.is_empty(),name+" committed mixed sample")
		if name == "iso":
			viewer.scene_layers.request_iso("f")
			viewer.scene_layers.sample(viewer.requested_time,false)
			check(await viewer.scene_layers.wait_for_surface(), "canonical derived isosurface completes")
			check(is_instance_valid(viewer.scene_layers.iso_node) and viewer.scene_layers.iso_node.mesh != null, "derived isosurface uploaded")
	hide_ui();await settle()

func make_graph() -> void:
	graph = Graph.new();viewer.add_child(graph);check(graph.attach(viewer),"Forward+ graph attaches")

func set_gains(value: Vector3) -> void:
	var automatic := RenderingServer.render_loop_enabled
	RenderingServer.render_loop_enabled = false
	graph.gains = value;check(graph.sync(), "graph synchronizes "+str(value))
	await process_frame
	hide_ui();RenderingServer.force_draw(false)
	var immediate := digest(target.get_texture().get_image())
	await settle();hide_ui();RenderingServer.force_draw(false)
	check(immediate == digest(target.get_texture().get_image()),"single draw barrier matches settled category composite "+str(value))
	RenderingServer.render_loop_enabled = automatic

func stats(image: Image) -> Dictionary:
	var sum := Vector3.ZERO;var maximum := Vector3.ZERO;var nonzero := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y);var value := Vector3(color.r,color.g,color.b)
			sum += value;maximum = maximum.max(value)
			if value.length_squared() > 1e-12:nonzero += 1
	return {"sum":[sum.x,sum.y,sum.z],"maximum":[maximum.x,maximum.y,maximum.z],"nonzero":nonzero,"sha256":digest(image)}

func source_images(raw: bool) -> Dictionary:
	for category in graph.sources:
		var viewport: SubViewport = graph.sources[category].viewport
		viewport.get_child(0).environment.glow_enabled = not raw
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not raw and graph.tone != null: graph.tone.render_target_update_mode = SubViewport.UPDATE_ONCE
	await settle()
	var result := {}
	for category in graph.sources: result[category] = graph.sources[category].viewport.get_texture().get_image()
	return result

func reconstruction(raw: Dictionary, name: String) -> Dictionary:
	var env: Environment = graph.environment_copy(true);env.glow_enabled = false
	var reference: SubViewport = graph.viewport(false,env)
	graph.copy_camera(reference.get_child(0));reference.get_child(0).cull_mask = graph.original_mask
	await settle()
	var image: Image = reference.get_texture().get_image()
	var maximum := 0.0;var squared := 0.0;var failed := 0;var channels := image.get_width()*image.get_height()*3
	for y in image.get_height():
		for x in image.get_width():
			var summed := Vector3.ZERO
			for category in raw:
				var color: Color = raw[category].get_pixel(x,y);summed += Vector3(color.r,color.g,color.b)
			var color: Color = image.get_pixel(x,y);var expected := Vector3(color.r,color.g,color.b)
			for i in 3:
				var difference := absf(summed[i]-expected[i]);maximum = maxf(maximum,difference);squared += difference*difference
				if difference > maxf(.0002,absf(expected[i])*.01):failed += 1
	graph.release(reference);await settle()
	check(failed == 0,name+" category radiance sum reconstructs accepted visibility within half-float tolerance")
	if failed > 0:
		var images := raw.duplicate();images.reference = image
		for category in images:
			var debug: Image = images[category].duplicate();debug.convert(Image.FORMAT_RGBF)
			var file := FileAccess.open(output.path_join(name+"-debug-"+category+".rgbf"),FileAccess.WRITE);file.store_buffer(debug.get_data());file.close()
	return {"maximum_absolute_error":maximum,"rmse":sqrt(squared/channels),"failed_channels":failed,"tested_channels":channels,"relative_tolerance":.01,"absolute_tolerance":.0002}

func independence(name: String) -> void:
	await load_scene(name)
	await screen(name+"-native-Cinematic")
	var original_camera: Transform3D = viewer.camera.global_transform
	var cache_before: int = viewer.generic_reader.cache.used
	make_graph();await set_gains(Vector3(1.35,1,1))
	var kernels := await source_images(false)
	var raw := await source_images(true)
	var record := {"scene":name,"raw":{},"kernels":{},"inventory":graph.inventory()}
	record.reconstruction = await reconstruction(raw,name)
	for category in kernels:
		record.raw[category] = stats(raw[category]);record.kernels[category] = stats(kernels[category])
		check(raw[category].get_format() in [Image.FORMAT_RGBH,Image.FORMAT_RGBAH],name+" "+category+" HDR float source")
		if name == "occluded" and category != "meshes":check(record.raw[category].nonzero == 0,name+" "+category+" blocked by opaque mesh")
		else:check(record.raw[category].nonzero > 0,name+" "+category+" contributes")
	await source_images(false)
	await screen(name+"-all")
	for index in 3:
		var value := Vector3(1.35,1,1);value[index] = 2
		await set_gains(value)
		var changed := await source_images(false)
		for category in kernels:check(digest(changed[category]) == digest(kernels[category]),name+" gain does not alter "+category+" extracted kernel")
		value[index] = 0;await set_gains(value)
		check(not graph.sources.has(Graph.CATEGORIES[index]),name+" zero deallocates only "+Graph.CATEGORIES[index])
		var remaining := await source_images(false)
		for category in remaining:check(digest(remaining[category]) == digest(kernels[category]),name+" zero preserves "+category+" kernel")
		await screen(name+"-zero-"+Graph.CATEGORIES[index])
	await set_gains(Vector3(1.35,0,0));await screen(name+"-defaults")
	check(viewer.camera.global_transform == original_camera,name+" camera pose unchanged")
	check(viewer.generic_reader.cache.used == cache_before,name+" no duplicated decoded cache")
	# Check committed render resources are shared; no scientific reupload/readers.
	for category in graph.sources:
		for id in graph.sources[category].proxies:
			var original = instance_from_id(id);var proxy = graph.sources[category].proxies[id].proxy
			check(proxy.multimesh == original.multimesh if proxy is MultiMeshInstance3D else proxy.mesh == original.mesh,name+" shared committed GPU geometry")
	viewer._apply_preset("Scientific");check(graph.sync(),name+" Scientific sync");await screen(name+"-Scientific")
	check(graph.inventory().private_viewports == 0,name+" Scientific releases all targets")
	graph.dispose();graph.free();graph = null
	await screen(name+"-native-Scientific")
	viewer._apply_preset("Cinematic");make_graph();await set_gains(Vector3.ZERO)
	check(graph.inventory().private_viewports == 0,name+" all zero has no private passes")
	await screen(name+"-all-zero")
	cases.append(record)

func measure(scene: String, label: String, frames := 90, move := false) -> void:
	var gpu: Array = [];var wall: Array = [];var cpu: Array = []
	await settle(20)
	var began := Time.get_ticks_usec()
	var wall_start := Time.get_unix_time_from_system()
	for i in frames:
		var start := Time.get_ticks_usec()
		if move:
			viewer.scene_layers.sample(float(i%8)/7.0)
			if graph != null: graph.sync()
		if graph != null and not move:graph.invalidate();graph.sync()
		await process_frame;await RenderingServer.frame_post_draw
		wall.append((Time.get_ticks_usec()-start)/1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(target.get_viewport_rid())+(graph.gpu_ms() if graph != null else 0.0))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(target.get_viewport_rid()))
	gpu.sort();wall.sort();cpu.sort()
	benchmarks.append({"scene":scene,"label":label,"resolution":[target.size.x,target.size.y],"frames":frames,"moving_samples":move,
		"unix_start":wall_start,"unix_end":Time.get_unix_time_from_system(),
		"gpu_ms_median":gpu[frames/2],"gpu_ms_p95":gpu[int(frames*.95)],"wall_ms_median":wall[frames/2],"wall_ms_p95":wall[int(frames*.95)],
		"cpu_root_ms_median":cpu[frames/2],"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,
		"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"buffer_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"decoded_cache_bytes":viewer.generic_reader.cache.used,"inventory":graph.inventory() if graph != null else {}})
	print("BENCHMARK ",JSON.stringify(benchmarks[-1]))
	if move:await measure(scene,label+"-render-only",90,false)

func paused_passes() -> void:
	var before: int = graph.generation
	var measured: Dictionary = {}
	for category in graph.sources:measured[category] = RenderingServer.viewport_get_measured_render_time_gpu(graph.sources[category].viewport.get_viewport_rid())
	for i in 10:
		graph.sync();await process_frame
	check(graph.generation == before,"paused unchanged scene does not schedule private passes")
	for category in graph.sources:
		check(RenderingServer.viewport_get_measured_render_time_gpu(graph.sources[category].viewport.get_viewport_rid()) == measured[category],"paused "+category+" pass keeps its last measured draw time")

func transition_checks() -> void:
	await load_scene("heavy");make_graph();graph.gains = Vector3(1.35,1,1)
	var hashes := {}
	for step in [{"label":"initial-1080","size":Vector2i(1920,1080),"time":0.0},{"label":"resize-4K","size":Vector2i(3840,2160),"time":0.0},{"label":"resize-1080","size":Vector2i(1920,1080),"time":0.0},{"label":"seek-025","size":Vector2i(1920,1080),"time":.25},{"label":"seek-075","size":Vector2i(1920,1080),"time":.75},{"label":"seek-025-repeat","size":Vector2i(1920,1080),"time":.25}]:
		RenderingServer.render_loop_enabled = false
		var began := Time.get_ticks_usec()
		target.size = step.size;target.size_2d_override = Vector2i(1440,roundi(1440.0*step.size.y/step.size.x))
		viewer.requested_time = step.time
		check(not viewer.scene_layers.sample(step.time,false).is_empty(),step.label+" sample commits")
		graph.invalidate();check(graph.sync(),step.label+" graph admits")
		await process_frame;hide_ui()
		var drawn := Time.get_ticks_usec();RenderingServer.force_draw(false)
		var image: Image = target.get_texture().get_image();var first := digest(image)
		var ready := Time.get_ticks_usec()
		await settle();RenderingServer.force_draw(false)
		check(first == digest(target.get_texture().get_image()),step.label+" single draw has committed sample")
		check(image.get_size() == step.size,step.label+" exact physical target")
		hashes[step.label] = first
		transitions.append({"label":step.label,"resolution":[step.size.x,step.size.y],"time":step.time,"prepare_and_layout_ms":(drawn-began)/1000.0,"draw_readback_ms":(ready-drawn)/1000.0,"total_ready_ms":(ready-began)/1000.0,"pixel_sha256":first,"inventory":graph.inventory()})
		RenderingServer.render_loop_enabled = true
	check(hashes["initial-1080"] == hashes["resize-1080"],"resize round trip preserves pixels")
	check(hashes["seek-025"] == hashes["seek-025-repeat"],"seek round trip preserves pixels")
	await set_gains(Vector3.ZERO);check(graph.inventory().private_viewports == 0,"transition zero releases all private targets")

func run() -> void:
	output = OS.get_cmdline_user_args()[0];mode = OS.get_cmdline_user_args()[1]
	create_timer(1500).timeout.connect(func():print("prototype timeout");quit(2))
	OS.low_processor_usage_mode = false;Engine.max_fps = 0
	# True physical targets, independent of the desktop compositor's window cap.
	target = SubViewport.new();target.size = Vector2i(960,640);target.own_world_3d = true
	target.size_2d_override = Vector2i(1440,960);target.size_2d_override_stretch = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(target)
	viewer = load("res://main.gd").new();target.add_child(viewer);viewer.set_process(false);viewer.playing = false;viewer.orbit_enabled = false
	viewer.shell.set_process(false);viewer.shell.transport.set_process(false);viewer.shell.status_ui.set_process(false)
	RenderingServer.viewport_set_measure_render_time(target.get_viewport_rid(),true)
	if mode == "transitions":await transition_checks()
	elif mode == "baseline":
		for scene in ["particles","separated","overlap","occluded","slice","iso"]:
			await load_scene(scene);await screen(scene+"-native-Cinematic");viewer._apply_preset("Scientific");await screen(scene+"-native-Scientific")
	else:
		for scene in (["overlap"] if mode == "smoke" else ["separated","overlap","occluded","slice","iso"]):await independence(scene)
		if mode not in ["smoke","isolation"] and failures.is_empty():
			await load_scene("particles");await screen("particles-native-Cinematic");make_graph();await set_gains(Vector3(1.35,0,0));await screen("particles-defaults")
			await paused_passes()
			check(await viewer._capture_inspection_png(output.path_join("prototype-real-image.png"),false) == OK,"real image capture path")
			Job.write_json(output.path_join("video-state.json"),Job.snapshot(viewer))
			graph.dispose();graph.free();graph = null
			viewer.environment.background_mode = Environment.BG_COLOR;viewer.environment.background_color = Color.BLACK;viewer.environment.fog_enabled = false
			await screen("particles-black-native");make_graph();await set_gains(Vector3(1.35,0,0));await screen("particles-black-defaults")
			await load_scene("heavy")
			# Restore the accepted environment after the controlled black calibration.
			viewer.environment.background_mode = Environment.BG_SKY;viewer.environment.fog_enabled = true
			for resolution in [Vector2i(1920,1080),Vector2i(3840,2160)]:
				target.size = resolution;target.size_2d_override = Vector2i(1440,roundi(1440.0*resolution.y/resolution.x));await settle()
				check(Vector2i(target.get_texture().get_size()) == resolution,"benchmark physical target "+str(resolution))
				await measure("heavy","accepted-native",60,true)
				viewer.environment.glow_enabled = false;await measure("heavy","native-no-glow",60,true)
				make_graph();await set_gains(Vector3(1.35,0,0));await measure("heavy","particle-default",60,true)
				await set_gains(Vector3(1.35,1,1));await measure("heavy","all-enabled",60,true)
				await screen("heavy-"+str(resolution.x)+"-all")
				await set_gains(Vector3.ZERO);await measure("heavy","all-zero",60,true)
				viewer._apply_preset("Scientific");graph.sync();await measure("heavy","Scientific-bypass",60,true)
				graph.dispose();graph.free();graph = null;viewer._apply_preset("Cinematic")
	Job.write_json(output.path_join(mode+".json"),{"checks":checks,"failures":failures,"cases":cases,"benchmarks":benchmarks,"transitions":transitions,"renderer":RenderingServer.get_current_rendering_method(),"version":ProjectSettings.get_setting("application/config/version"),"pid":OS.get_process_id()})
	if graph != null:graph.dispose();graph.free();graph = null
	viewer.queue_free();await process_frame
	print("FORWARD BLOOM PROTOTYPE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
