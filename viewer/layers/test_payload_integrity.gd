extends "res://layers/test_scene_playback.gd"
const Reader = preload("res://layers/scene_reader.gd")
const MeshSource = preload("res://layers/mesh_source.gd")
class NeverCancelled extends RefCounted:
	func stopped() -> bool:return false

func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("fixtures.json")))
	for fixture in fixtures.oracles:
		var reader := Reader.new(false);check(reader.open(out.path_join(fixture.file)),"Valid source opens")
		for i in range(fixture.rows.size()):
			var data := reader.read_sample("object",i)
			check(not data.is_empty() and data.time == fixture.rows[i].time,"Exact source time")
			check(data.channels.size() == fixture.rows[i].channels.size(),"All channels retained")
			for name in fixture.rows[i].channels:
				check(Hash.digest(data.channels[name].to_byte_array()) == fixture.rows[i].channels[name],"Exact typed scientific bytes: "+name)
		check(reader.cache.used <= reader.cache.limit,"Decoded cache bounded")
		if fixture.kind == "mesh":
			var source := FileAccess.open(out.path_join(fixture.file),FileAccess.READ)
			var first := MeshSource.decode(source,reader.samples.object[0],reader.objects.object,NeverCancelled.new(),{})
			var next := MeshSource.decode(source,reader.samples.object[1],reader.objects.object,NeverCancelled.new(),first.topology)
			check(next.get("topology_reused",false),"Exact validated topology is reused for adjacent mesh endpoints")
		reader.close()
	for row in fixtures.cases:
		var reader := Reader.new(false);var opened := reader.open(out.path_join(row.file))
		check(opened != (row.fault == "header"),"Header allocation guard: "+row.file)
		if not opened:reader.close();continue
		check(not reader.read_sample("object",0).is_empty(),"Valid prefix readable")
		var data := reader.read_sample("object",3)
		check((not data.is_empty()) == row.readable,"Fast corruption semantics: "+row.file)
		if not row.readable:check(reader.error.contains("object sample 3 (record 3)"),"Contextual failure: "+row.file)
		if row.kind == "mesh" and row.fault in ["bad_id","triangle"]:
			var source := FileAccess.open(out.path_join(row.file),FileAccess.READ)
			var valid := MeshSource.decode(source,reader.samples.object[0],reader.objects.object,NeverCancelled.new(),{})
			var invalid := MeshSource.decode(source,reader.samples.object[3],reader.objects.object,NeverCancelled.new(),valid.topology)
			check(invalid.has("error") and invalid.error.contains("object sample 3 (record 3)"),"Cached topology cannot bypass changed ID/index validation: "+row.file)
		reader.close()
		if row.readable:
			var strict := Reader.new()
			check(strict.open(out.path_join(row.file)),"Strict native reader opens lazy index")
			check(strict.read_sample("object",3).is_empty() and strict.error.contains("checksum"),"Strict native reader rejects hash-only corruption")
			strict.close()
		# Exercise actual field, particle and mesh workers, not only synchronous reads.
		if row.fault not in ["sha_only","offset","decode","bad_id","triangle"]:continue
		var view = make_view(out.path_join(row.file),true)
		view.scene_layers.seek(.31)
		var began := Time.get_ticks_msec()
		while view.scene_layers.error.is_empty() and view.requested_time != .31 and Time.get_ticks_msec()-began < 5000:
			view.scene_layers.tick(0);await process_frame
		var result: bool = view.requested_time == .31
		check(result == row.readable,"Worker corruption semantics: "+row.file)
		if row.readable:check(view.committed_sample.requested_time == .31,"Readable changed bytes are never repaired")
		else:check(view.scene_layers.error.contains("object sample 3 (record 3)"),"Worker contextual refusal: "+row.file+" "+view.scene_layers.error)
		view.free();await process_frame
	var reader := Reader.new(false)
	check(not reader.open(out.path_join("bad-metadata.ssc")),"Malformed metadata rejected")
	check(reader.open(out.path_join("moved/renamed.data")),"Renamed capture does not need a trust entry")
	check(not reader.read_sample("object",3).is_empty(),"Renamed valid content reads")
	reader.close()
	var offline = load("res://main.gd").new()
	offline.offline_instance = true;offline.playing = false;offline.capture_path = out.path_join("volume-none-sha_only.ssc")
	root.add_child(offline);offline.set_process(false)
	check(not offline.scene_layers.use_async(),"Offline rendering keeps synchronous strict reads")
	check(offline.scene_layers.sample(.31).is_empty() and offline.scene_layers.error.contains("checksum"),"Offline rendering rejects payload-only corruption")
	await process_frame
	if DisplayServer.get_name() != "headless":await RenderingServer.frame_post_draw
	offline.free();await process_frame
	var working := out.path_join("working.ssc")
	check(reader.open(working),"Mutable disposable source opens")
	var before := reader.read_sample("object",3);var generation := reader.generation
	var file := FileAccess.open(working,FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(out.path_join("volume-none-sha_only.ssc")));file.close()
	var after := reader.read_sample("object",3)
	check(reader.generation > generation and not after.is_empty(),"Same-path mutation invalidates cached source generation")
	check(before.channels.rho.to_byte_array() != after.channels.rho.to_byte_array(),"Same path does not preserve old cached content")
	reader.close()
	# Hold a field worker just before publication, mutate the source and ensure it refuses.
	file = FileAccess.open(working,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(out.path_join("volume-none.ssc")));file.close()
	var view = make_view(working,true);var control = view.scene_layers.field_playback
	control.request(.31,view.scene_layers.field_budget())
	var job: Dictionary = control.automatic_jobs[0].duplicate(true)
	control.worker.cancel()
	# A fresh worker isolates publication from already resident startup samples.
	var worker = preload("res://layers/field_buffer.gd").new()
	var gate := Semaphore.new();worker.test_barrier = gate;worker.start()
	worker.request("mutation",[job],job.charge*2,true)
	var began := Time.get_ticks_msec()
	while not worker.status().test_barrier_waiting and Time.get_ticks_msec()-began < 5000:await process_frame
	check(worker.status().test_barrier_waiting,"Mutation overlaps in-flight preparation")
	file = FileAccess.open(working,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(out.path_join("volume-none-sha_only.ssc")));file.close()
	worker.test_barrier = null;gate.post()
	began = Time.get_ticks_msec()
	while worker.status().failures.is_empty() and Time.get_ticks_msec()-began < 5000:await process_frame
	check(not worker.status().failures.is_empty(),"Changed source refuses stale worker publication")
	check(worker.status().frames == 0 and worker.status().completed == 0,"No stale sample published in the current generation")
	worker.close()
	view.free();await process_frame
	# Complete queued GPU frees before tearing down Compatibility's renderer.
	for i in range(5):await process_frame
	if DisplayServer.get_name() != "headless":await RenderingServer.frame_post_draw
	Job.write_json(out.path_join("checks.json"),{"checks":checks,"failures":failures})
	print("PAYLOAD INTEGRITY: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
