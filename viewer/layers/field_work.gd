extends RefCounted
# One persistent CPU lane. The coordinator transfers exclusive ownership at the
# two semaphore boundaries. No scene tree, shared file cursor or GPU operations.
const Reader = preload("res://layers/scene_reader.gd")
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/field_prepare.gd")
const Stamp = preload("res://data/source_stamp.gd")
var thread := Thread.new()
var wake := Semaphore.new()
var done := Semaphore.new()
var owner_ref: WeakRef
var closing := false
var job := {}
var generation := ""
var reusable := {}
var entry := {}
var result := {}
var stages := {}
var elapsed_ms := 0.0
func start(owner) -> Error:
	owner_ref = weakref(owner)
	return thread.start(_run,Thread.PRIORITY_LOW)
func close() -> void:
	closing = true;wake.post()
	if thread.is_started():thread.wait_to_finish()
func stopped() -> bool:
	var owner = owner_ref.get_ref()
	return owner == null or owner.job_stopped(generation,job.key)
func _run() -> void:
	while true:
		wake.wait()
		if closing:return
		var began := Time.get_ticks_usec()
		result = {};stages = {}
		if not stopped():
			if not reusable.is_empty():
				result = Prepare.prepare(job.object,reusable.sample,job.channel,job.budget,self)
				stages = result.get("timings",{}).duplicate()
			else:
				var file := FileAccess.open(job.path,FileAccess.READ)
				var decoded := Channels.read(file,entry,job.object,self,false) if file != null else {"error":"Cannot open source."}
				if decoded.has("error"):result = {"error":Reader.record_error(job.entry,decoded.error)}
				elif not decoded.is_empty():
					stages = decoded.get("timings",{}).duplicate()
					var sample := {"time":job.entry.time,"count":0,"channels":decoded.channels,"components":decoded.components,"shapes":decoded.shapes,"associations":decoded.associations,"statistics":decoded.get("statistics",{}),"geometry":entry.descriptor.geometry,"has_ids":false,"identity_map":null,"source_index":job.entry.index,"sequence":job.entry.sequence,"decoded_bytes":decoded.reserve}
					result = Prepare.prepare(job.object,sample,job.channel,job.budget,self)
					stages.merge(result.get("timings",{}))
		if not result.is_empty() and not result.has("error") and Stamp.read(job.path) != job.stamp:
			result = {"error":"Field source changed during preparation."}
		elapsed_ms = (Time.get_ticks_usec()-began)/1000.0
		done.post()
