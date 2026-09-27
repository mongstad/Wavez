extends SceneTree
# CPU-only scaling experiment. Each thread owns its handle, descriptors and one
# live result; there is no scene access, shared reader or retained sample queue.
const Reader = preload("res://layers/scene_reader.gd")
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/field_prepare.gd")
const Policy = preload("res://layers/playback_memory.gd")
const Job = preload("res://video/render_job.gd")

class Lane:
	extends RefCounted
	var thread := Thread.new()
	var path := ""
	var object := {}
	var entries: Array = []
	var rows: Array = []
	var error := ""
	func run() -> void:
		var file := FileAccess.open(path,FileAccess.READ)
		for entry in entries:
			var start := Time.get_ticks_usec()
			var materialized := Reader.materialize(file,entry,object)
			if materialized.has("error"):error = materialized.error;return
			var descriptor_ms := (Time.get_ticks_usec()-start)/1000.0
			var decoded := Channels.read(file,materialized,object,null,false)
			if decoded.has("error"):error = decoded.error;return
			var sample := {"channels":decoded.channels,"shapes":decoded.shapes,"geometry":materialized.descriptor.geometry,"statistics":decoded.statistics}
			var prepared := Prepare.prepare(object,sample,"density",512*Policy.MIB)
			if prepared.has("error") or prepared.get("lod") != 1:error = str(prepared.get("error","LOD changed"));return
			var stages: Dictionary = decoded.timings.duplicate();stages.merge(prepared.timings);stages.descriptor = descriptor_ms
			rows.append({"index":entry.index,"time":entry.time,"ms":(Time.get_ticks_usec()-start)/1000.0,"stages_ms":stages,"stored":entry.stored})
			prepared.clear();sample.clear();decoded.clear()

func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0];var output := args[1];var workers := int(args[2]);var first := int(args[3]);var count := int(args[4])
	var reader := Reader.new(false)
	if workers < 1 or workers > 4 or not reader.open(path):push_error("Invalid input: "+reader.error);quit(1);return
	var memory := Policy.snapshot();var largest := 0
	for index in range(first,first+count):largest = maxi(largest,int(reader.samples.field[index].decoded)*2+65536)
	if memory.available_physical < memory.reserve+workers*largest*3:push_error("Insufficient parallel transient headroom");quit(1);return
	var lanes: Array = []
	for i in range(workers):
		var lane := Lane.new();lane.path = path;lane.object = reader.objects.field.duplicate(true)
		for index in range(first+i,first+count,workers):lane.entries.append(reader.samples.field[index].duplicate(true))
		lanes.append(lane)
	print("PHASE prepare")
	var started := Time.get_ticks_usec()
	for lane in lanes:
		if lane.thread.start(lane.run,Thread.PRIORITY_LOW) != OK:push_error("Thread start failed");quit(1);return
	for lane in lanes:lane.thread.wait_to_finish()
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	print("PHASE report")
	var rows: Array = [];var stages := {};var failures: Array = [];var stored := 0
	for lane in lanes:
		if not lane.error.is_empty():failures.append(lane.error)
		for row in lane.rows:
			rows.append(row);stored += int(row.stored)
			for stage in row.stages_ms:stages[stage] = stages.get(stage,0.0)+row.stages_ms[stage]
	rows.sort_custom(func(a,b):return a.index < b.index)
	var cadence: float = reader.samples.field[first+1].time-reader.samples.field[first].time
	var report := {"workers":workers,"first":first,"count":count,"completed":rows.size(),"wall_seconds":elapsed,"samples_per_second":count/elapsed,"source_seconds_per_wall_second":count*cadence/elapsed,"stages_ms":stages,"rows":rows,"failures":failures,"stored_bytes":stored,"read_bytes_per_second":stored/elapsed,"memory_before":memory,"memory_after":Policy.snapshot(),"transient_reservation":workers*largest*3}
	Job.write_json(output,report)
	print("SCALING: ",workers," workers, ",report.samples_per_second," samples/s")
	reader.close();quit(0 if failures.is_empty() and rows.size() == count else 1)
