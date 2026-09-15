extends RefCounted
# One private CPU thread; immutable publication, independent file handle, finite LRU.
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/mesh_prepare.gd")
const Stamp = preload("res://data/source_stamp.gd")
const Memory = preload("res://layers/playback_buffer.gd")
var thread := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var closing := false
var token := ""
var working_token := ""
var working_key := ""
var jobs: Array = []
var prepared := {}
var order: Array[String] = []
var used := 0
var limit := 128*Memory.MIB
var error := ""
var completed := 0
var cancelled := 0
var evictions := 0
var worker_ms := 0.0
var worker_thread := -1
var test_barrier: Semaphore
var at_barrier := false
func start() -> Error:return thread.start(_run,Thread.PRIORITY_LOW)
func close() -> void:
	mutex.lock();closing = true;mutex.unlock();wake.post()
	if thread.is_started():thread.wait_to_finish()
func request(next_token: String, next_jobs: Array, bytes: int) -> void:
	mutex.lock();token = next_token;jobs = next_jobs;limit = bytes;error = "";mutex.unlock();wake.post()
func cancel() -> void:
	mutex.lock();token += "!";jobs = [];mutex.unlock();wake.post()
func stopped() -> bool:
	mutex.lock();var stop := closing or token != working_token or not jobs.any(func(job):return job.key == working_key);mutex.unlock();return stop
func get_frame(key: String) -> Dictionary:
	mutex.lock();var value: Dictionary = prepared.get(key,{})
	if value.get("token") != token:value = {}
	elif not value.is_empty():order.erase(key);order.append(key)
	mutex.unlock();return value
func status() -> Dictionary:
	mutex.lock()
	var result := {"bytes":used,"limit":limit,"frames":prepared.size(),"completed":completed,"cancelled":cancelled,"evictions":evictions,"worker_ms":worker_ms,"worker_thread":worker_thread,"active":not working_key.is_empty(),"error":error,"test_barrier_waiting":at_barrier}
	mutex.unlock();return result
func _prune(incoming: int, key: String) -> bool:
	var retired: Array = []
	mutex.lock()
	for old in order.duplicate():
		if prepared[old].token != token or not jobs.any(func(job):return job.key == old):
			retired.append(prepared[old]);used -= int(prepared[old].bytes);prepared.erase(old);order.erase(old)
	while used+incoming > limit and not order.is_empty():
		var old: String = order.pop_front()
		retired.append(prepared[old]);used -= int(prepared[old].bytes);prepared.erase(old);evictions += 1
	var fits := used+incoming <= limit and not prepared.has(key)
	mutex.unlock();retired.clear();return fits
func _next() -> Dictionary:
	mutex.lock();var next := {}
	if not closing:
		for job in jobs:
			if not prepared.has(job.key) or prepared[job.key].token != token:
				next = job;working_key = job.key;working_token = token;break
	mutex.unlock();return next
func _run() -> void:
	mutex.lock();worker_thread = OS.get_thread_caller_id();mutex.unlock()
	while true:
		wake.wait()
		mutex.lock();var done := closing;mutex.unlock()
		if done:break
		_prune(0,"")
		while true:
			var job := _next()
			if job.is_empty():break
			var began := Time.get_ticks_usec();var result := {};var memory := Memory.memory_headroom()
			if memory.available_physical < memory.reserve+job.charge*3:
				result = {"error":"Mesh preparation paused to preserve physical RAM headroom."}
			elif Stamp.read(job.path) != job.stamp:result = {"error":"Mesh source changed; waiting for refresh."}
			elif not _prune(job.charge,job.key):result = {"error":"Mesh frame exceeds the preparation budget."}
			else:
				var file := FileAccess.open(job.path,FileAccess.READ)
				if file == null:result = {"error":"Cannot open mesh source."}
				else:
					var a := _decode(file,job.entry,job.object)
					var b := a if job.entry.sequence == job.next.sequence else _decode(file,job.next,job.object)
					if a.is_empty() or b.is_empty():result = {}
					elif a.has("error"):result = a
					elif b.has("error"):result = b
					else:
						result = Prepare.pair(job.object,a,b,job.state,job.budget,job.colors,self)
						if result.has("error"):
							# A display refusal preserves valid scientific source samples.
							result = {"a":a,"b":b,"empty":true,"gpu_bytes":0,"preview_error":result.error}
			var gate := test_barrier
			if gate != null:
				mutex.lock();at_barrier = true;mutex.unlock();gate.wait();mutex.lock();at_barrier = false;mutex.unlock()
			if not result.is_empty() and not result.has("error") and Stamp.read(job.path) != job.stamp:result = {"error":"Mesh source changed during preparation."}
			var obsolete := stopped()
			mutex.lock()
			if obsolete or token != working_token or closing:cancelled += 1
			elif result.has("error"):error = result.error;jobs = []
			elif not result.is_empty():
				result.token = working_token;result.bytes = job.charge;prepared[job.key] = result;order.append(job.key);used += job.charge;completed += 1
			worker_ms += (Time.get_ticks_usec()-began)/1000.0;working_key = ""
			var failed := not error.is_empty()
			mutex.unlock();result = {}
			if failed:break
	prepared.clear();order.clear()

func _decode(file: FileAccess, entry: Dictionary, obj: Dictionary) -> Dictionary:
	var decoded := Channels.read(file,entry,obj,self)
	if decoded.is_empty() or decoded.has("error"):return decoded
	var count: int = int(decoded.shapes.position[0])
	if decoded.channels.has("vertex_id"):
		var ids := preload("res://data/particle_identity.gd").build(decoded.channels.vertex_id,self)
		if ids.is_empty():return {}
		if ids.has("error"):return {"error":"Invalid vertex IDs."}
	var indices: PackedInt32Array = decoded.channels.triangles
	for i in range(indices.size()):
		if i % 4096 == 0 and stopped():return {}
		if indices[i] < 0 or indices[i] >= count:return {"error":"Triangle index outside vertices."}
	return {"time":entry.time,"count":count,"channels":decoded.channels,"components":decoded.components,"shapes":decoded.shapes,"associations":decoded.associations,"geometry":entry.descriptor.geometry,"has_ids":false,"identity_map":null,"source_index":entry.index,"sequence":entry.sequence,"decoded_bytes":decoded.reserve}
