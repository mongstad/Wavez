extends SceneTree
## Saturated rolling-window production benchmark, separate from interactive rate.
const Viewer = preload("res://main.gd")
const Buffer = preload("res://layers/mesh_buffer.gd")
const Job = preload("res://video/render_job.gd")
const Memory = preload("res://layers/playback_buffer.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var config := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mesh-pipeline-job="):config = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--mesh-pipeline-job=")))
	if not config.has("capture") or not config.has("output"):push_error("Missing mesh pipeline job");quit(1);return
	var view = Viewer.new();view.capture_path = config.capture;view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false)
	if view.scene_layers == null or view.committed_sample.is_empty():push_error("Capture did not open");view.free();quit(1);return
	var control = view.scene_layers.mesh_playback
	control.worker.close();control.worker = Buffer.new();control.worker.start();control.invalidate()
	var id: String = view.scene_layers.states.keys()[0]
	if view.generic_reader.objects[id].kind != "mesh":push_error("Pipeline benchmark expects a mesh capture");view.free();quit(1);return
	view.scene_layers.states[id].channel = config.get("channel","")
	var count := int(config.get("pairs",100));var first := int(config.get("first",100))
	if count < 1 or first < 0 or first+count > view.generic_reader.samples[id].size():push_error("Pair interval outside capture");view.free();quit(1);return
	var began := Time.get_ticks_usec();var consumed := 0;var max_bytes := 0;var max_flight := 0
	var samples: Array = [];var sampled_second := -1;var max_decoded := 0;var max_endpoints := 0
	var limit_s := float(config.get("timeout",180))
	while consumed < count and (Time.get_ticks_usec()-began)/1000000.0 < limit_s:
		var time: float = view.generic_reader.samples[id][first+consumed].time+.00000001
		var plan: Dictionary = control.update_budget(time,view.scene_layers.mesh_budget())
		if control.request_signature != plan.targets[0].key:
			control.worker.request(plan.signature,plan.jobs,control.cpu_limit);control.request_signature = plan.targets[0].key
		while not control.worker.get_frame(plan.targets[0].key).is_empty():
			consumed += 1;break
		var status: Dictionary = control.worker.status()
		max_bytes = maxi(max_bytes,int(status.bytes));max_flight = maxi(max_flight,int(status.in_flight_bytes))
		max_decoded = maxi(max_decoded,int(status.decoded_bytes));max_endpoints = maxi(max_endpoints,int(status.decoded_samples))
		var elapsed := (Time.get_ticks_usec()-began)/1000000.0
		if int(elapsed) != sampled_second:
			sampled_second = int(elapsed);samples.append({"seconds":elapsed,"consumed":consumed,"memory":Memory.memory_headroom()})
		await process_frame
	var seconds := (Time.get_ticks_usec()-began)/1000000.0
	var report := {"config":config,"seconds":seconds,"consumed":consumed,"pairs_per_second":consumed/seconds,
		"cache":control.worker.status(true),"max_bytes":max_bytes,"max_in_flight":max_flight,"cpu_limit":control.cpu_limit,
		"max_decoded_bytes":max_decoded,"max_endpoints":max_endpoints,"samples":samples}
	Job.write_json(config.output,report);print("PIPELINE ",consumed," pairs / ",seconds," s = ",consumed/seconds," pairs/s")
	view.free();await process_frame;quit(0 if consumed == count else 1)
