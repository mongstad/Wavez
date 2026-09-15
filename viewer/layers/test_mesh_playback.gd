extends "res://layers/test_scene_playback.gd"
const MeshView = preload("res://layers/mesh_view.gd")
const MeshPrepare = preload("res://layers/mesh_prepare.gd")
class CleanViewer extends "res://main.gd":
	func _build_backdrop(env: Environment) -> void:
		# The focused multi-view harness always renders a plain background; avoid
		# queuing unused sky filtering work across rapid viewport lifecycles.
		env.background_mode = Environment.BG_COLOR
func make_view(path: String, asynchronous: bool):
	var view := CleanViewer.new()
	view.capture_path = path;view.playing = false;view.orbit_enabled = false
	view.scene_prebuffer_enabled = asynchronous;view.scene_hidden_fast_path = asynchronous
	root.add_child(view);view.set_process(false);view._set_clean(true)
	return view
var job := {}
var render_stats: Array = []
func draw() -> Image:
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func gate_ready(worker) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began<10000:
		if worker.status().test_barrier_waiting:return true
		await process_frame
	return false
func compare_mesh(view, reference, label: String) -> void:
	check(view.committed_sample == reference.committed_sample,label+" exact metadata and clocks")
	for id in view.scene_layers.states:
		if not view.scene_layers.views[id] is MeshView:continue
		var actual = view.scene_layers.views[id];var expected = reference.scene_layers.views[id]
		check(view.scene_layers.current[id].a.channels == reference.scene_layers.current[id].a.channels,label+" exact source channels/IDs "+id)
		check(view.scene_layers.current[id].b.channels == reference.scene_layers.current[id].b.channels,label+" exact next source channels "+id)
		check(actual.source_positions == expected.source_positions,label+" exact float32 preview positions "+id)
		check(actual.normal_values == expected.normal_values,label+" exact inspection normals "+id)
		check(actual.transform == expected.transform,label+" affine transform "+id)
		if actual.mesh == null:
			check(expected.mesh == null,label+" empty preview "+id);continue
		var a: Array = actual.mesh.surface_get_arrays(0);var b: Array = expected.mesh.surface_get_arrays(0)
		check(a[Mesh.ARRAY_INDEX] == b[Mesh.ARRAY_INDEX],label+" oriented topology "+id)
		check(a[Mesh.ARRAY_COLOR] == b[Mesh.ARRAY_COLOR],label+" held scalar colors and association "+id)
		if DisplayServer.get_name() != "headless":
			var baked: Array = actual.bake_mesh_from_current_blend_shape_mix().surface_get_arrays(0)
			var max_error := 0.0
			for i in range(baked[Mesh.ARRAY_VERTEX].size()):max_error = maxf(max_error,baked[Mesh.ARRAY_VERTEX][i].distance_to(b[Mesh.ARRAY_VERTEX][i]))
			check(max_error <= 2e-6,label+" rendered morph positions within float32 rounding "+id)
func clean(view, retained: bool) -> void:
	view.overlay_visible = false;view.overlay_panel.visible = false;view.show_panel_button.visible = false;view.resize_handle.visible = false
	view.legend.visible = false;view.colorbar.visible = false;view.show_legend = false
	for id in view.guide_visibility:view.guide_visibility[id] = false
	view._apply_geometry();view._sync_visuals()
	view.camera.near = .001;view.camera.far = 100;view.camera.fov = 42
	var center := Vector3(2,.5,.45) if retained else Vector3(1,.5,.3)
	view.camera.position = center+(Vector3(3.5,-7,3.5) if retained else Vector3(-3.5,-7,3.5));view.camera.look_at(center,Vector3.BACK)
	view.camera_target = center;view.camera_distance = view.camera.position.distance_to(center)
func render_compare(path: String, retained: bool) -> void:
	var view = make_view(path,true);clean(view,retained)
	var id: String = view.scene_layers.states.keys()[0]
	var state: Dictionary = view.scene_layers.states[id]
	state.channel = "surface_cell_von_mises" if retained else "stress";state.lower = 0;state.upper = 500000 if retained else 4
	var stop: float = view.generic_reader.frames[-1].time
	for wire in [false,true]:
		state.wireframe = wire
		for time in [0.0,stop*.371,stop]:
			check(await sample(view,time,true),"image asynchronous sample")
			var asynchronous := await draw();var metadata: Dictionary = view.committed_sample.duplicate(true)
			check(not view.scene_layers.sample(time,false).is_empty(),"image synchronous sample")
			var synchronous := await draw()
			var aa := asynchronous.get_data();var bb := synchronous.get_data();var different := 0;var largest := 0;var visible_pixels := 0
			for i in range(aa.size()):
				if aa[i] != bb[i]:different += 1;largest = maxi(largest,absi(int(aa[i])-int(bb[i])))
			for y in range(synchronous.get_height()):
				for x in range(synchronous.get_width()):
					var c := synchronous.get_pixel(x,y)
					if maxf(c.r,maxf(c.g,c.b)) > .1:visible_pixels += 1
			check(visible_pixels>100,"mesh is visible in render")
			# Predeclared allowance for GPU float32 morph arithmetic at raster edges.
			check(different/float(aa.size())<=.001,"async/sync image disagreement <=0.1 percent of components")
			check(metadata == view.committed_sample,"image metadata unchanged")
			var name := ("04B" if retained else "synthetic")+"-"+str(wire)+"-"+str(time)
			render_stats.append({"name":name,"different_components":different,"total_components":aa.size(),"max_component_error":largest,"visible_pixels":visible_pixels})
			asynchronous.save_png(job.output.get_base_dir().path_join(name+"-async.png"));synchronous.save_png(job.output.get_base_dir().path_join(name+"-sync.png"))
	view.free();await process_frame
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mesh-playback-job="):job = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--mesh-playback-job=")))
	out = job.fixtures
	for name in ["stable","changing","anonymous","mixed","empty"]:
		var view = make_view(out.path_join(name+".ssc"),true);var reference = make_view(out.path_join(name+".ssc"),false)
		check(view.scene_layers.mesh_playback.enabled,"mesh-only/mixed worker enabled "+name)
		for channel in ["","value","stress"]:
			for wire in [false,true]:
				for v in [view,reference]:v.scene_layers.states.surface.channel = channel;v.scene_layers.states.surface.wireframe = wire
				for time in [0.0,.21,.7,1.31,1.9,2.47,3.0,.05]:
					check(await sample(view,time,true),"async sample "+name)
					check(await sample(reference,time,false),"sync sample "+name)
					compare_mesh(view,reference,name+"/"+str(time))
		var controller = view.scene_layers.mesh_playback
		check(controller.worker.status().worker_thread != OS.get_thread_caller_id(),"real private CPU worker")
		check(controller.worker.status().bytes <= controller.cpu_limit,"bounded CPU cache")
		check(controller.staged.size()<=2,"bounded future GPU staging")
		view.free();reference.free();await process_frame
	var view = make_view(out.path_join("stable.ssc"),true)
	var controller = view.scene_layers.mesh_playback;var worker = controller.worker
	check(await sample(view,0.0,true),"startup ready")
	# Freeze publication deterministically; an uncached seek cannot advance source state.
	var gate := Semaphore.new();worker.test_barrier = gate;controller.invalidate();view.scene_layers.views.surface.clear()
	var before: Dictionary = view.committed_sample.duplicate(true)
	check(view.scene_layers.seek(2.3),"seek queued")
	check(await gate_ready(worker),"worker publication barrier reached")
	view.scene_layers.tick(.1)
	check(view.committed_sample==before and view.scene_layers.is_buffering() and view.play_button.disabled,"underflow holds clock and disables Play/analysis")
	check(view.scene_layers.seek(.25),"latest seek supersedes pending")
	view.scene_layers.states.surface.channel = "stress";view.scene_layers.resample()
	worker.test_barrier = null;gate.post()
	check(await sample(view,.25,true),"changed settings and latest seek commit")
	check(worker.status().cancelled>0,"stale worker result cancelled")
	controller.pending_time = 2.3;controller.buffering = true
	view.scene_layers.sample(.7,false);controller.pump()
	check(view.requested_time == .7 and controller.pending_time == null,"scientific sample supersedes pending clock")
	view.scene_layers.states.surface.visible = false
	check(await sample(view,2.0,true) and not view.scene_layers.current.has("surface"),"hidden mesh skips source payload")
	view.scene_layers.states.surface.visible = true
	check(await sample(view,2.0,true),"reveal prepares correct pair")
	var before_uploads: int = controller.uploads
	check(await sample(view,2.1,true),"same pair interpolates")
	check(controller.uploads <= before_uploads+1,"same pair needs no repeated mesh upload (one future stage allowed)")
	view.time_mode = "physical";view.physical_rate = -1;view.scene_loop_playback = true
	check(await sample(view,.05,true),"reverse loop start")
	view.playing = true;view.scene_layers.tick(.1);view.playing = false
	while controller.buffering:controller.pump();await process_frame
	check(is_equal_approx(view.requested_time,2.95),"reverse loop clock exact")
	controller.cpu_limit = 1;controller.request_signature = ""
	check(not view.scene_layers.sample(view.requested_time,true).has("pending"),"resident mesh usable under reduced CPU budget")
	check(controller.staged.is_empty(),"budget refusal releases future GPU stage")
	# A preview refusal must release the surface without dropping source values.
	view.scene_layers.gpu_budget_mib = 0
	check(await sample(view,1.31,true),"GPU refusal still commits scientific sample")
	check(view.scene_layers.views.surface.mesh == null and view.scene_layers.views.surface.gpu_bytes == 0,"GPU budget reduction releases resident surface")
	check(view.scene_layers.layer_samples[0].status == "unavailable" and view.scene_layers.current.surface.a.channels.position is PackedFloat64Array,"GPU refusal keeps source precision and diagnostic")
	view.scene_layers.gpu_budget_mib = 256
	check(await sample(view,1.31,true),"GPU budget increase recovers")
	var bad: Dictionary = view.scene_layers.current.surface.a.duplicate(true)
	bad.channels.position[0] = 1e100
	var refused := MeshPrepare.pair(view.generic_reader.objects.surface,bad,bad,view.scene_layers.states.surface,1048576,view.colormaps.viridis)
	check(refused.has("error") and bad.channels.position[0] == 1e100,"float32 overflow refuses without mutating source")
	view.free();await process_frame
	# Source replacement while a result is waiting must cancel publication and clear display.
	var path := out.path_join("live.ssc");var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(out.path_join("stable.ssc")));file.close()
	view = make_view(path,true);controller = view.scene_layers.mesh_playback;worker = controller.worker
	gate = Semaphore.new();worker.test_barrier = gate;controller.invalidate();view.scene_layers.views.surface.clear()
	view.scene_layers.seek(2.3);check(await gate_ready(worker),"source-change barrier reached")
	file = FileAccess.open(path,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(out.path_join("mixed.ssc")));file.close()
	check(not view.scene_layers.refresh() and view.frame_a == null and view.scene_layers.views.surface.mesh == null,"source replacement clears stale display")
	worker.test_barrier = null;gate.post();view.free();await process_frame
	if job.has("capture"):
		view = make_view(job.capture,true)
		var reference = make_view(job.capture,false)
		var id: String = view.scene_layers.states.keys()[0]
		var times: Array = []
		var entries: Array = view.generic_reader.samples[id]
		for i in range(entries.size()):
			times.append(entries[i].time)
			if i+1 < entries.size():times.append((entries[i].time+entries[i+1].time)*.5)
		for channel in ["displacement_magnitude","surface_cell_von_mises"]:
			for v in [view,reference]:v.scene_layers.states[id].channel = channel;v.scene_layers.states[id].upper = 109664.80083812455 if channel.begins_with("surface") else .07850149502693372
			for time in times:
				check(await sample(view,time,true),"04B asynchronous sample")
				check(await sample(reference,time,false),"04B synchronous reference")
				compare_mesh(view,reference,"04B/"+channel+"/"+str(time))
		view.free();reference.free();await process_frame
	if DisplayServer.get_name() != "headless":
		await render_compare(out.path_join("stable.ssc"),false)
		if job.has("capture"):await render_compare(job.capture,true)
	# Let deferred renderer resource destruction finish before checking process teardown.
	for i in range(4):await process_frame
	if DisplayServer.get_name() != "headless":await RenderingServer.frame_post_draw
	Job.write_json(job.output,{"checks":checks,"failures":failures,"render_comparisons":render_stats})
	print("MESH PLAYBACK: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
