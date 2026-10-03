extends SceneTree
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var hold_seconds := 5.0
var large := false
var observations: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:run.call_deferred()

func coverage(view) -> Dictionary:
	var layers = view.scene_layers
	return {"particles":layers.playback.worker.status().prepared_pairs if layers.playback.enabled else -1,
		"field":layers.field_playback.worker.status().frames if layers.field_playback.enabled else -1,
		"mesh":layers.mesh_playback.worker.status().frames if layers.mesh_playback.enabled else -1}

func tick_until_ready(view, kinds: Array, timeout_ms := 12000) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < timeout_ms:
		view.scene_layers.tick(.016)
		var current := coverage(view)
		if kinds.all(func(kind):return current[kind] > 0) and not view.scene_layers.is_buffering():return true
		await process_frame
	return false

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--paused-fixture="):output = argument.trim_prefix("--paused-fixture=")
		if argument.begins_with("--hold-seconds="):hold_seconds = float(argument.trim_prefix("--hold-seconds="))
		if argument.begins_with("--large="):large = argument.trim_prefix("--large=") == "1"
	if output.is_empty():push_error("Missing paused fixture directory");quit(1);return
	var names := ["large-field", "large-mesh"] if large else ["particles", "field", "mesh", "mixed"]
	for name in names:
		var kinds: Array = ["particles", "field", "mesh"] if name == "mixed" else [name.trim_prefix("large-")]
		var view = load("res://main.gd").new()
		view.capture_path = output.path_join(name+".wvz")
		view.orbit_enabled = false
		root.add_child(view)
		view.set_process(false)
		check(not view.playing and is_equal_approx(view.requested_time,0.0), name+": opens paused at first recorded time")
		check(view.committed_sample.get("requested_time",-1.0) == 0.0, name+": initial scene is presented")
		check(kinds.all(func(kind):
			return (view.scene_layers.playback.enabled if kind == "particles" else
				(view.scene_layers.field_playback.enabled if kind == "field" else view.scene_layers.mesh_playback.enabled))),
			name+": shared eligible workers are enabled")
		if name == "mixed":
			var particle_worker = view.scene_layers.playback.worker
			var gate := Semaphore.new()
			particle_worker.test_barrier = gate
			view.scene_layers.tick(.016)
			var begun := Time.get_ticks_msec()
			while not particle_worker.status().get("test_barrier_waiting",false) and Time.get_ticks_msec()-begun < 5000:
				await process_frame
			check(particle_worker.status().get("test_barrier_waiting",false),"mixed particle worker reaches a blocked publication")
			begun = Time.get_ticks_msec()
			while Time.get_ticks_msec()-begun < 5000:
				view.scene_layers.tick(.016)
				if view.scene_layers.field_playback.worker.status().frames > 0 and view.scene_layers.mesh_playback.worker.status().frames > 0:break
				await process_frame
			check(view.scene_layers.field_playback.worker.status().frames > 0 and view.scene_layers.mesh_playback.worker.status().frames > 0,
				"mixed field and mesh preparation proceeds while particle publication is blocked")
			particle_worker.test_barrier = null
			gate.post()
		check(await tick_until_ready(view,kinds,60000 if large else 12000),name+": eligible preparations fill while paused")
		var prepared := coverage(view)
		check(kinds.all(func(kind):return prepared[kind] > 0),name+": prepared coverage is actually resident")
		var layers = view.scene_layers
		if layers.playback.enabled:
			var particle_cache: Dictionary = layers.playback.worker.status()
			check(particle_cache.decoded_bytes <= layers.playback.decoded_limit and particle_cache.prepared_bytes <= layers.playback.prepared_limit,name+": particle RAM limits remain enforced")
		if layers.field_playback.enabled:
			check(layers.field_playback.worker.status().bytes <= layers.field_playback.cpu_limit,name+": field RAM limit remains enforced")
		if layers.mesh_playback.enabled:
			check(layers.mesh_playback.worker.status().bytes <= layers.mesh_playback.cpu_limit,name+": mesh RAM limit remains enforced")
		check(not view.playing and is_equal_approx(view.requested_time,0.0),name+": preparation does not advance clock")
		var since := Time.get_ticks_msec()
		var wait_seconds := hold_seconds if name == "mixed" else minf(hold_seconds,2.0)
		while Time.get_ticks_msec()-since < int(wait_seconds*1000):
			view.scene_layers.tick(.016)
			await process_frame
		var retained := coverage(view)
		observations.append({"scene":name,"prepared":prepared,"retained":retained,
			"waited_seconds":(Time.get_ticks_msec()-since)/1000.0,"paused_clock":view.requested_time})
		check(kinds.all(func(kind):return retained[kind] >= prepared[kind]),name+": paused cache survives elapsed wall time")
		check(not view.playing and is_equal_approx(view.requested_time,0.0),name+": clock remains paused after wait")
		view.play_button.pressed.emit()
		check(view.playing,name+": Play explicitly starts playback")
		var began := Time.get_ticks_msec()
		while view.requested_time <= 0.0 and Time.get_ticks_msec()-began < (30000 if large else 12000):
			view.scene_layers.tick(.1)
			await process_frame
		check(view.requested_time > 0.0,name+": Play advances from prepared scene")
		view.play_button.pressed.emit()
		check(not view.playing,name+": Pause restores stopped transport")
		var paused_coverage := coverage(view)
		if name == "mixed":
			since = Time.get_ticks_msec()
			while Time.get_ticks_msec()-since < 2000:
				view.scene_layers.tick(.016)
				await process_frame
			var after_playback_pause := coverage(view)
			check(kinds.all(func(kind):return after_playback_pause[kind] >= paused_coverage[kind]),"post-playback pause retains prepared coverage")
		check(view._seek_time(1.0),name+": paused seek is accepted")
		check(await tick_until_ready(view,kinds,60000 if large else 12000) and is_equal_approx(view.requested_time,1.0),name+": paused seek reaches a prepared scene")
		if name == "mixed":
			var previous = view.scene_layers
			view.play_button.pressed.emit()
			check(view.playing,"replacement begins while old source is playing")
			view._open_capture(output.path_join("field.wvz"))
			check(not view.playing and is_equal_approx(view.requested_time,0.0),"replacement resets playback to paused first sample")
			check(not previous.playback.worker.thread.is_started() and not previous.field_playback.worker.thread.is_started() and previous.mesh_playback.worker.threads.is_empty(),"replacement joins old preparation workers")
		view.free()
		await process_frame
	Job.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,
		"renderer":RenderingServer.get_current_rendering_method(),"packaged":not OS.has_feature("editor"),"observations":observations})
	print("PAUSED PREPARATION: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
