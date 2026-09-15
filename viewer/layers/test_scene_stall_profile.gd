extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Hash = preload("res://data/capture_index.gd")
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func snapshot(view) -> Dictionary:
	return {"requested_time":view.requested_time,"phase":view.phase,"index":view.current_index,"pair":view.scene_layers.particle_key,"sample":view.committed_sample.duplicate(true),"layers":view.scene_layers.layer_samples.duplicate(true),"buffer":Hash.digest(view.current_mm.buffer.to_byte_array()),"slider_max":view.timeline.max_value,"slider_value":view.timeline.value,"tail_poll":view.tail_poll}
func sequence(source: String, mode: int, hidden: bool) -> Array:
	Profile.enabled = false;Profile.trace_enabled = false;Profile.reset()
	var view = load("res://main.gd").new()
	# Fixed-delta profiler equivalence; asynchronous scheduling has its own tests.
	view.scene_prebuffer_enabled = false
	view.capture_path = source;view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false)
	check(view.scene_layers != null and view.frame_a != null,"fixture opens")
	if view.scene_layers == null or view.frame_a == null:view.free();return []
	view._set_clean(true);view.particle_layer_visible = not hidden
	for id in view.scene_layers.states:view.scene_layers.states[id].visible = not hidden
	view.scene_layers.sample(0)
	view.time_mode = "physical";view.physical_rate = .75;view.playing = true
	view.tail_poll = 0;view.display_accum = 0
	Profile.reset();Profile.enabled = mode>0;Profile.trace_enabled = mode==2
	var values: Array = []
	for delta in [.1,.2,.7,.25,.75,.5]:
		view._process(delta);values.append(snapshot(view))
	var report := Profile.report()
	if mode==0:check(report.stages.is_empty() and not report.has("trace"),"disabled instrumentation records nothing")
	elif mode==1:check(not report.stages.is_empty() and not report.has("trace"),"summary preserves the report shape")
	else:
		check(report.trace.events.size()>0 and report.trace.dropped==0,"bounded trace records callbacks")
		check(report.counters.get("g3_tail_polls",0)==2,"one-second delta poll unchanged")
		if hidden:check(report.counters.get("g3_hidden_particle_skips",0)>0 and not report.stages.has("g3_read_sample"),"hidden skips are instrumented without decoding")
		else:check(report.stages.has("g3_read_sample") and report.stages.has("g3_particle_pair_rebuild"),"responsible sample paths instrumented")
	Profile.enabled = false;Profile.trace_enabled = false;view.free()
	return values
func run() -> void:
	var base := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stall-regression="):base = arg.trim_prefix("--stall-regression=")
	if base.is_empty():push_error("Missing regression directory");quit(1);return
	Profile.enabled = true;Profile.trace_enabled = true;Profile.trace_capacity = 2;Profile.reset()
	for i in range(4):Profile.end("bounded",Profile.begin(),{"sample_index":i})
	var report := Profile.report()
	check(report.trace.events.size()==2 and report.trace.dropped==2,"trace cap reports dropped events")
	check(report.stages.bounded.count==4,"trace cap does not stop aggregate measurements")
	check(report.trace.events[0].end_us>=report.trace.events[0].start_us,"monotonic span timestamps")
	check(report.trace.events[0].details.sample_index==0,"source detail retained")
	Profile.reset();check(Profile.trace_rows.is_empty() and Profile.trace_dropped==0,"reset clears bounded trace")
	Profile.trace_capacity = 32768
	for hidden in [true,false]:
		var plain := sequence(base.path_join("fixture.ssc"),0,hidden)
		var summary := sequence(base.path_join("fixture.ssc"),1,hidden)
		var traced := sequence(base.path_join("fixture.ssc"),2,hidden)
		check(plain==summary,"summary leaves all sampled values/times/buffers unchanged hidden="+str(hidden))
		check(plain==traced,"trace leaves all sampled values/times/buffers unchanged hidden="+str(hidden))
	Profile.enabled = false;Profile.trace_enabled = false
	Job.write_json(base.path_join("instrumentation-tests.json"),{"checks":checks,"failures":failures,"scope":"Deterministic callback/sample state equivalence; headless is not rendering acceptance."})
	print("STALL INSTRUMENTATION: ",checks," checks, ",failures.size()," failures")
	quit(1 if not failures.is_empty() else 0)
