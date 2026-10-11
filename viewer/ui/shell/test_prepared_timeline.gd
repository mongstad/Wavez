extends "res://layers/test_scene_playback.gd"
const Timeline = preload("res://ui/shell/prepared_timeline.gd")
const ThemeSource = preload("res://ui/theme/violet_slice_theme.gd")
var evidence := {}
func contains(ranges: Array, time: float) -> bool:
	return ranges.any(func(span):return span[0] <= time and time < span[1])
func settled(view) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 10000:
		view.scene_layers.tick(0)
		var layers = view.scene_layers
		var ps: Dictionary = layers.playback.worker.status()
		var fs: Dictionary = layers.field_playback.worker.status()
		var ms: Dictionary = layers.mesh_playback.worker.status()
		if not ps.worker_active and ps.desired.all(func(i):return ps.ready_indices.has(i)) and not fs.active and not ms.active and not layers.is_buffering():return true
		await process_frame
	return false
func barrier(worker) -> bool:
	var until := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < until:
		if worker.status().get("test_barrier_waiting",false):return true
		await process_frame
	return false
func snapshot(view) -> Dictionary:
	view.timeline.refresh(view)
	var layers = view.scene_layers
	return {"coverage":view.timeline.coverage.duplicate(true),"particles":layers.playback.worker.status(),"field_keys":layers.field_playback.worker.status().charges.keys(),"mesh_keys":layers.mesh_playback.worker.status().ready_keys,"reason":layers.transport_wait_reason,"time":view.requested_time,"committed":view.committed_sample.get("requested_time")}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-fixture="):out = arg.trim_prefix("--playback-fixture=")
	check(Timeline.spans([{"time":5.}],{},0,40,true).is_empty(),"Missing static sample never advertises pre-first blank coverage")
	check(Timeline.spans([{"time":5.}],{0:true},0,40,true) == [[0.,40.]],"Static source sample is required and reusable over the whole union clock")
	check(Timeline.spans([{"time":5.},{"time":8.}],{},0,40) == [[0.,5.]],"Dynamic layer is absent before its first recorded sample")
	check(Timeline.spans([{"time":0.},{"time":1.},{"time":2.}],{0:true},0,2) == [[0.,1.]],"Prepared pair/sample owns only its source interval")
	for case in ["particles","fields","meshes","static","mixed"]:
		var view = make_view(out.path_join(case+".wvz"),true)
		view.set_process_input(false);view.set_process_unhandled_input(false)
		# Explicit manual window keeps this tiny fixture particle-limited.
		if case == "mixed":view.scene_layers.playback.set_policy("512")
		check(await sample(view,0,true) and await settled(view),case+" paused prebuffer settles")
		view.timeline.refresh(view)
		check(contains(view.timeline.coverage.scene,.1),case+" initial required scene window ready")
		evidence[case] = snapshot(view)
		var layers = view.scene_layers
		var saved_stamp: Dictionary = layers.reader.source_stamp.duplicate()
		layers.reader.source_stamp["timeline_test"] = true;view.timeline.refresh(view)
		check(view.timeline.coverage.scene.is_empty(),case+" source stamp mismatch immediately excludes old residency")
		layers.reader.source_stamp = saved_stamp;view.timeline.refresh(view)
		check(contains(view.timeline.coverage.scene,.1),case+" restoring matching stamp restores resident coverage")
		var before_reads: int = layers.reader.cache.misses
		var p_desired: Array = layers.playback.worker.status().desired
		for i in 20:view.timeline.refresh(view)
		check(layers.reader.cache.misses == before_reads and layers.playback.worker.status().desired == p_desired,case+" refresh does not decode or change particle requests")
		if case == "mixed":
			check(view.timeline.coverage.fields == [[0.,40.]],"Field-ready-to-end precondition")
			check(view.timeline.coverage.scene[0][1] < 40,"Particles limit mixed scene despite full field preparation")
			check(not view.timeline.coverage.end_ready,"Missing terminal particle pair cannot claim the end")
			var old: Dictionary = view.timeline.coverage.duplicate(true)
			view.particle_layer_visible = false;view.timeline.refresh(view)
			check(view.timeline.coverage.scene == [[0.,40.]] and view.timeline.coverage.end_ready,"Visibility changes publish immediately without forced refresh")
			view.particle_layer_visible = true;view.timeline.refresh(view)
			check(view.timeline.coverage.scene == old.scene,"Restoring particles restores the narrow scene intersection")
			var worker = layers.playback.worker;var gate := Semaphore.new();worker.test_barrier = gate
			check(layers.seek(20),"Seek into field-only-ready region accepted")
			check(await barrier(worker),"Real particle publication held before residency")
			view.playing = true;layers.tick(.1)
			view.timeline.refresh(view)
			check(layers.transport_wait_reason == "Required particle content","Particle cache miss is the actual playback hold")
			check(not contains(view.timeline.coverage.scene,20) and view.timeline.coverage.fields == [[0.,40.]],"Held time is never scene-ready when only fields are prepared")
			evidence.underflow = snapshot(view)
			view.playing = false;worker.test_barrier = null;gate.post()
			check(await sample(view,20,true) and await settled(view),"Seek resumes after real particle publication")
			view.timeline.refresh(view)
			check(contains(view.timeline.coverage.scene,20.1),"Published pair makes its real adjacent interval ready")
			view.color_channel = "scalar";view.timeline.refresh(view)
			check(view.timeline.coverage.scene.is_empty(),"Particle configuration changes immediately hide old pairs")
			check(await sample(view,20,true) and await settled(view),"Particle configuration re-prepares")
			var signature: String = layers.playback.context.token
			layers.reader.generation += 1;view.timeline.refresh(view)
			check(view.timeline.coverage.scene.is_empty(),"Source generation changes invalidate all old worker keys before pumping")
			layers.reader.generation -= 1
			check(layers.playback.context.token == signature,"Read-only refresh never modifies particle context")
		if case in ["fields","mixed","static"]:
			layers.states.f.channel = "other";view.timeline.refresh(view)
			check(view.timeline.coverage.scene.is_empty() and view.timeline.coverage.fields.is_empty(),case+" selected channel cannot use old keys")
			check(await sample(view,0,true) and await settled(view),case+" channel replacement settles")
			layers.field_playback.invalidate();view.timeline.refresh(view)
			check(view.timeline.coverage.fields.is_empty(),case+" invalidated generation cannot retain readiness")
			check(await sample(view,0,true) and await settled(view),case+" invalidation recovers")
		if case in ["meshes","static"]:
			layers.states.m.wireframe = true;view.timeline.refresh(view)
			check(view.timeline.coverage.scene.is_empty(),case+" mesh configuration excludes old pair keys")
			check(await sample(view,0,true) and await settled(view),case+" mesh replacement settles")
		# Real cache budget shrink/eviction must remove coverage without force.
		if case == "particles":
			var p = layers.playback;var worker = p.worker
			var before: Dictionary = worker.status()
			check(before.ready_indices.has(30),"Particle-only automatic preparation reaches distant pair")
			var context: Dictionary = p.context.duplicate(true)
			context.full_preload = false;context.prepared_limit = int(worker.get_pair(0,false).bytes)*3;context.decoded_limit = 0
			var desired: Array[int] = [0];worker.request(context,desired)
			var until := Time.get_ticks_msec()+10000
			while worker.status().ready_indices.has(30) and Time.get_ticks_msec()<until:await process_frame
			view.timeline.refresh(view)
			check(not worker.status().ready_indices.has(30) and not contains(view.timeline.coverage.scene,30.1),"Real particle eviction removes distant coverage immediately")
			p.set_policy("adaptive");check(await sample(view,30,true) and await settled(view),"Evicted interval re-prepares after seek")
		# Sustained 1x traversal through actual layer readiness/gates.
		check(await sample(view,2,true) and await settled(view),case+" scrub commits requested source time")
		view.physical_rate = 1;view.playing = true
		var until := Time.get_ticks_msec()+10000
		while view.requested_time < 5 and Time.get_ticks_msec()<until:
			layers.tick(.025);view.timeline.refresh(view);await process_frame
		check(view.requested_time >= 5 and layers.error.is_empty(),case+" sustained 1x gates replenish and advance")
		view.playing = false;view.free();await process_frame
	await visual_checks()
	Job.write_json(out.path_join("prepared-timeline.json"),{"checks":checks,"failures":failures,"evidence":evidence})
	print("PREPARED TIMELINE: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func visual_checks() -> void:
	var host := Control.new();var visual_theme := ThemeSource.new();host.theme = visual_theme;root.add_child(host)
	var background := ColorRect.new();background.size = Vector2(1440,900);background.mouse_filter = Control.MOUSE_FILTER_IGNORE;host.add_child(background)
	var slider := Timeline.new();host.add_child(slider);slider.position = Vector2(32,100);slider.size = Vector2(600,16)
	slider.frames = [{"time":0.},{"time":14400.}];slider.max_value = 1;slider.step = .001;slider.value = .5
	slider.coverage = {"fields":[[0.,14400.]],"scene":[],"end_ready":false}
	check(slider.coverage_geometry().is_empty(),"Field-only full-length readiness produces no drawable band or cue")
	slider.coverage.scene = [[1.,1.1]]
	check(slider.coverage_geometry()[0].right-slider.coverage_geometry()[0].left < .01 and slider.coverage_geometry()[0].presence,"Four-hour timeline retains truthful subpixel duration plus presence cue")
	slider.coverage.scene = [[0.,14400.]]
	check(slider.coverage_geometry()[0].right < slider.size.x,"Missing exact terminal sample leaves the endpoint uncolored")
	slider.coverage.end_ready = true
	check(slider.coverage_geometry()[0].right == slider.size.x,"Ready terminal sample fills the endpoint exactly")
	if DisplayServer.get_name() != "headless":
		for light in [false,true]:
			visual_theme.set_light(light);background.color = visual_theme.c(&"surface.0")
			for factor in [1.,2.]:
				host.scale = Vector2.ONE*factor
				for case in ["field-only","short","full"]:
					slider.coverage.scene = [] if case == "field-only" else ([[1.,1.1]] if case == "short" else [[0.,14400.]])
					slider.overlay.queue_redraw()
					for i in 3:await process_frame
					await RenderingServer.frame_post_draw
					var image := root.get_texture().get_image();var origin: Vector2 = slider.get_global_transform_with_canvas()*Vector2.ZERO
					var point: Vector2 = origin+Vector2(3,-2)*factor
					var pixel := image.get_pixel(roundi(point.x),roundi(point.y))
					var teal: Color = visual_theme.c(&"identity.teal")
					var matches := Vector3(pixel.r,pixel.g,pixel.b).distance_to(Vector3(teal.r,teal.g,teal.b)) < .15
					check(matches == (case == "short"),"Detached short-window cue pixels: "+str([light,factor,case]))
					var track := image.get_pixel(roundi(origin.x+300*factor),roundi(origin.y+8*factor))
					var is_teal := Vector3(track.r,track.g,track.b).distance_to(Vector3(teal.r,teal.g,teal.b)) < .15
					# Move playhead off this measurement pixel for the full band below.
					if case != "full":check(not is_teal,"No field-only or elapsed-progress fill: "+str([light,factor,case]))
					var primary: Color = visual_theme.c(&"accent.primary")
					check(Vector3(track.r,track.g,track.b).distance_to(Vector3(primary.r,primary.g,primary.b)) < .15,"Native playhead dominates every overlay state: "+str([light,factor,case]))
					if case == "full":
						var band := image.get_pixel(roundi(origin.x+150*factor),roundi(origin.y+8*factor))
						check(Vector3(band.r,band.g,band.b).distance_to(Vector3(teal.r,teal.g,teal.b)) < .15,"Full scene duration pixels: "+str([light,factor]))
					image.get_region(Rect2i(int(origin.x)-8,int(origin.y)-20,int(620*factor),int(48*factor))).save_png(out.path_join("timeline-"+str(light)+"-"+str(factor)+"-"+case+".png"))
		host.scale = Vector2.ONE
	host.free()
