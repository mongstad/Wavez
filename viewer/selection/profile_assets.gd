extends SceneTree
const Viewer = preload("res://main.gd")
const Profile = preload("res://scene/playback_profile.gd")
var failures: Array[String] = []
var worker_results: Array = []
var out := ""

func _initialize() -> void:call_deferred("run")

func wait_ready(control) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began<30000:
		await create_timer(.01).timeout
		if not control.jobs.pending and control.operation.is_empty():return control.jobs.error.is_empty()
	return false

func check(ok: bool,label: String) -> void:
	if not ok:failures.append(label);push_error(label)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset-profile="):out = arg.trim_prefix("--asset-profile=")
	if out.is_empty():quit(1);return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
	var viewer := Viewer.new();viewer.offline_instance = true;root.add_child(viewer)
	await process_frame
	viewer._open_capture(out.path_join("fixture.wvz"));viewer.playing = false;viewer.orbit_enabled = false
	var control = viewer.selection_controller
	control.jobs.completed.connect(func(result):worker_results.append({"metrics":result.metrics,"memory":result.memory,"memo":result.get("verification_memo",{}),"assets":result.get("member_assets",{})}))
	Profile.reset();Profile.enabled = true;Profile.trace_enabled = true
	var began := Time.get_ticks_usec()
	control.bind_source();check(await wait_ready(control),"source binds")
	control.kind.select(8);control.first_input.text = "-1,-1,-1";control.second_input.text = "200,200,200"
	control.create_definition();check(await wait_ready(control),"whole-population region resolves")
	var region: Dictionary = control.state.find(control.state.active)
	control.pending_edit = "new"
	control._request("freeze_selection",{"selection":region,"time":0,"key":"large-fixed","name":"Exact full cohort"})
	check(await wait_ready(control),"full cohort freezes without large UI payload")
	var elapsed := (Time.get_ticks_usec()-began)/1000.0
	var fixed: Dictionary = control.state.find("large-fixed")
	check(fixed.get("selector",{}).has("ids_asset"),"large exact cohort uses typed member asset")
	if fixed.is_empty():viewer.queue_free();await process_frame;quit(1);return
	check(int(fixed.selector.ids_asset.shape[0])==int(config.count),"asset contains complete requested population")
	check(JSON.stringify(fixed).to_utf8_buffer().size()<4096,"definition publication remains compact")
	for i in range(3):
		viewer.scene_layers.sample(float(i%2));check(await wait_ready(control),"repeat source seek resolves asset members")
		await process_frame;await process_frame
	Profile.enabled = false
	var profiling := Profile.report()
	var stalls: Array = []
	for event in profiling.trace.events:
		if event.name.begins_with("g4_") and event.duration_ms>=50:stalls.append(event)
	check(stalls.is_empty(),"no G4 callback reaches 50 ms on declared cohort")
	var report := {"failures":failures,"count":config.count,"end_to_end_ms":elapsed,"profile":profiling,"worker_results":worker_results,"member_directory":control.jobs.member_directory,"definition":fixed,"preview_gpu_bytes":control.overlay.gpu_bytes,"viewer_memory_static":OS.get_static_memory_usage(),"category":"bounded cohort profile; not G4 idle baseline acceptance"}
	var file := FileAccess.open(out.path_join("profile.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	viewer.queue_free();await process_frame
	print("G4 MEMBER ASSETS: ",config.count," members; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
