extends SceneTree
const Sampling = preload("res://scene/source_sampling.gd")
const Jobs = preload("res://analysis/analysis_jobs.gd")
var checks := 0
var failures: Array[String] = []
var out := ""
var request_ms := 0.0
var worker_metrics := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);push_error(label)

func _initialize() -> void:
	call_deferred("run")

func wait_result(jobs) -> bool:
	var start := Time.get_ticks_msec()
	while jobs.pending and Time.get_ticks_msec()-start < 10000:
		await create_timer(.01).timeout
	return not jobs.pending and jobs.error.is_empty()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--foundation="):out = arg.trim_prefix("--foundation=")
	if out.is_empty(): quit(1);return
	var golden = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("golden.json")))
	for case in golden.cases:
		var rows: Array = []
		for time in case.times:rows.append({"time":Sampling.exact_float(time).value})
		var point := Sampling.bracket(rows,Sampling.exact_float(case.time).value,case.static)
		if case.expected.status == "unavailable":check(point.is_empty(),"unavailable source bracket")
		else:
			for key in ["a","b","status","alpha","time"]:
				check(point[key] == case.expected[key],"Python/Godot bracket "+key)
	for text in golden.ids:
		var parsed := Sampling.exact_id(text)
		check(not parsed.is_empty() and str(parsed.value)==text,"exact ID "+text)
	for bad in ["01","-1","9223372036854775808","1e3",1.0]:
		check(Sampling.exact_id(bad).is_empty(),"invalid ID refused")
	var a := {"count":3,"channels":{"vertex_id":PackedInt64Array([7,9,11]),"triangles":PackedInt32Array([0,1,2])}}
	var b := a.duplicate(true)
	check(Sampling.mesh_compatible({"identity":"stable_topology"},a,b),"ordered topology is compatible")
	b.channels.vertex_id = PackedInt64Array([9,7,11])
	check(not Sampling.mesh_compatible({"identity":"stable_topology"},a,b),"reordered mesh holds")
	b = a.duplicate(true);b.channels.triangles = PackedInt32Array([0,2,1])
	check(not Sampling.mesh_compatible({"identity":"stable_topology"},a,b),"changed mesh holds")
	var jobs := Jobs.new();root.add_child(jobs)
	check(jobs.start(out.path_join("workers")),"worker starts within headroom")
	var source := {"path":out.path_join("fixture.wvz")}
	var began := Time.get_ticks_usec()
	var token := jobs.request(source,"describe",{},1,1)
	request_ms = (Time.get_ticks_usec()-began)/1000.0
	check(not token.is_empty() and request_ms < 50.,"request callback does not scan/hash/decode")
	check(await wait_result(jobs),"worker describes source asynchronously")
	if jobs.last_result.get("ok",false):
		check(jobs.last_result.data.objects[0].samples == 4,"worker uses native particle clock")
		worker_metrics = {"memory":jobs.last_result.memory,"guard":jobs.last_result.guard,"metrics":jobs.last_result.metrics}
	var old := jobs.request(source,"describe",{},1,1)
	var newer := jobs.request(source,"probe",{"object":"field","time":.75,"coordinate":[10.5,-2,6.5],"channel":"value"},2,3)
	check(old != newer,"requests have distinct revisions")
	check(await wait_result(jobs),"latest request completes")
	check(jobs.last_result.get("id")==newer and jobs.last_result.get("scene_revision")==2 and jobs.last_result.get("selection_revision")==3,"old result cannot replace latest state")
	jobs.request(source,"describe",{},3,3);jobs.cancel()
	check(not jobs.pending and jobs.current_id.is_empty(),"cancel clears active publication target")
	var pid: int = jobs.worker_pid
	jobs.shutdown()
	await create_timer(.1).timeout
	# OS.kill reaps the child; querying it again logs an engine error on Unix.
	check(not DirAccess.dir_exists_absolute("/proc/%d" % pid),"close leaves no worker process")
	jobs.queue_free()
	await process_frame
	var stuck := Jobs.new();root.add_child(stuck)
	stuck.directory = out.path_join("stuck-worker");DirAccess.make_dir_recursive_absolute(stuck.directory)
	stuck.worker_pid = OS.create_process("/bin/sleep",PackedStringArray(["10"]));stuck.worker_ready = true
	stuck.pending = true;stuck.current_id = "stuck";stuck.set_process(true)
	var stuck_pid: int = stuck.worker_pid;var cancel_started := Time.get_ticks_usec();stuck.cancel()
	check((Time.get_ticks_usec()-cancel_started)/1000.0 < 50.,"stuck-worker cancellation acknowledges without joining")
	while stuck.worker_pid > 0 and Time.get_ticks_usec()-cancel_started < 3000000:await create_timer(.05).timeout
	check(stuck.worker_pid < 0 and not DirAccess.dir_exists_absolute("/proc/%d" % stuck_pid),"stuck foreground child terminated within cancellation grace")
	check(stuck.error.contains("cancellation grace"),"forced cancellation remains explicitly reported")
	stuck.queue_free();await process_frame
	var report := {"checks":checks,"failures":failures,"request_callback_ms":request_ms,"worker":worker_metrics,"category":"headless source/protocol; not rendered acceptance"}
	var file := FileAccess.open(out.path_join("godot.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("G4 FOUNDATION: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
