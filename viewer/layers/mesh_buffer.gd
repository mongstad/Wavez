extends RefCounted
# Persistent CPU lanes, immutable endpoint/pair caches and atomic task admission.
const Prepare = preload("res://layers/mesh_prepare.gd")
const Source = preload("res://layers/mesh_source.gd")
const Stamp = preload("res://data/source_stamp.gd")
const Memory = preload("res://layers/playback_buffer.gd")
class Task extends RefCounted:
	var owner_ref: WeakRef
	var key := ""
	var generation := ""
	var source := false
	var charge := 0
	func stopped() -> bool:
		var owner = owner_ref.get_ref()
		return owner == null or owner.task_stopped(self)
var worker_count := default_worker_count()
var active_limit := 1
var automatic_workers := not OS.get_environment("WAVEZ_MESH_WORKERS") in ["1","2","3","4"]
var threads: Array[Thread] = []
var mutex := Mutex.new()
var barrier_mutex := Mutex.new()
var wake := Semaphore.new()
var closing := false
var token := ""
var jobs: Array = []
var wanted := {}
var wanted_sources := {}
var prepared := {}
var sources := {}
var topology := {}
var in_flight := {}
var used := 0
var source_bytes := 0
var limit := 0
var in_flight_bytes := 0
var peak_in_flight_bytes := 0
var peak_active := 0
var pressure_failures := {}
var error := ""
var failures := {}
var completed := 0
var decoded := 0
var endpoint_hits := 0
var topology_reuses := 0
var cancelled := 0
var evictions := 0
var worker_ms := 0.0
var pipeline_stages := {}
var pair_times: Array = []
var readiness_times: Array = []
var worker_thread := -1
var lane_ms := {}
var test_barrier: Semaphore
var at_barrier := false
static func default_worker_count() -> int:
	var configured := OS.get_environment("WAVEZ_MESH_WORKERS")
	if configured in ["1","2","3","4"]:return int(configured)
	# Use at most four lanes, leaving physical/SMT capacity for render, UI and fields.
	return clampi(OS.get_processor_count()/2-2,1,4)
func start() -> Error:
	worker_count = clampi(worker_count,1,4);active_limit = worker_count
	for i in range(worker_count):
		var thread := Thread.new();var result := thread.start(_run.bind(i),Thread.PRIORITY_LOW)
		if result != OK:close();return result
		threads.append(thread)
	return OK
func _wake() -> void:
	for i in range(worker_count):wake.post()
func close() -> void:
	mutex.lock();closing = true;var gate := test_barrier;test_barrier = null;mutex.unlock()
	if gate != null:gate.post()
	_wake()
	for thread in threads:
		if thread.is_started():thread.wait_to_finish()
	threads.clear();prepared.clear();sources.clear();topology.clear();in_flight.clear()
	used = 0;source_bytes = 0;in_flight_bytes = 0
static func source_key(job: Dictionary, entry: Dictionary) -> String:
	return JSON.stringify([job.path,job.stamp,job.get("generation",0),job.id,entry.sequence])
func request(next_token: String, next_jobs: Array, bytes: int) -> void:
	var desired := {};var endpoints := {}
	for original in next_jobs:
		var job: Dictionary = original.duplicate()
		job.a_key = source_key(job,job.entry);job.b_key = source_key(job,job.next)
		job.topology_key = JSON.stringify([job.path,job.stamp,job.get("generation",0),job.id])
		desired[job.key] = job
		endpoints[job.a_key] = true;endpoints[job.b_key] = true
	mutex.lock()
	if token != next_token:failures.clear();pressure_failures.clear()
	for key in pressure_failures:failures.erase(key)
	pressure_failures.clear()
	for key in desired:desired[key].queued_us = wanted[key].get("queued_us",Time.get_ticks_usec()) if token == next_token and wanted.has(key) else Time.get_ticks_usec()
	token = next_token;jobs = desired.values();wanted = desired;wanted_sources = endpoints;limit = bytes;error = ""
	for old in failures.keys():
		if not wanted.has(old):failures.erase(old)
	mutex.unlock();_wake()
func cancel() -> void:
	mutex.lock();token += "!";jobs = [];wanted.clear();wanted_sources.clear();mutex.unlock();_wake()
func task_stopped(task: Task) -> bool:
	mutex.lock()
	var stopped := closing or task.charge > limit or in_flight_bytes > limit
	stopped = stopped or (not wanted_sources.has(task.key) if task.source else token != task.generation or not wanted.has(task.key))
	mutex.unlock();return stopped
func get_frame(key: String) -> Dictionary:
	mutex.lock();var value: Dictionary = prepared.get(key,{})
	if value.get("token") != token:value = {}
	mutex.unlock();return value
func status(include_samples := false) -> Dictionary:
	mutex.lock()
	var result := {"bytes":used,"limit":limit,"decoded_bytes":source_bytes,"decoded_limit":limit,"decoded_samples":sources.size(),"decoded":decoded,"endpoint_hits":endpoint_hits,"topology_reuses":topology_reuses,"in_flight_bytes":in_flight_bytes,"peak_in_flight_bytes":peak_in_flight_bytes,"requested_jobs":jobs.size(),"pressure_failures":pressure_failures.size(),"frames":prepared.size(),"completed":completed,"cancelled":cancelled,"evictions":evictions,"worker_ms":worker_ms,"worker_thread":worker_thread,"active":not in_flight.is_empty(),"active_jobs":in_flight.size(),"peak_active":peak_active,"worker_count":worker_count,"active_limit":active_limit,"automatic_workers":automatic_workers,"error":error,"failures":failures.duplicate(),"test_barrier_waiting":at_barrier,"pipeline_stages":pipeline_stages.duplicate(),"lane_ms":lane_ms.duplicate()}
	if include_samples:result.pair_times = pair_times.duplicate();result.readiness_times = readiness_times.duplicate()
	result.ready_keys = []
	for key in prepared:
		if prepared[key].token == token:result.ready_keys.append(key)
	mutex.unlock();return result
func _memory_headroom() -> Dictionary:return Memory.memory_headroom()
func _prune() -> void:
	var retired: Array = []
	mutex.lock()
	for key in prepared.keys():
		if prepared[key].token != token or not wanted.has(key) or used > limit:
			retired.append(prepared[key]);used -= int(prepared[key].bytes);prepared.erase(key);evictions += 1
	for key in sources.keys():
		if not wanted_sources.has(key) or source_bytes > limit:
			retired.append(sources[key]);source_bytes -= int(sources[key].bytes);sources.erase(key)
	# Canonical references exist only for the current source scopes, never the full file.
	var scopes := {}
	for job in jobs:scopes[job.topology_key] = true
	for key in topology.keys():
		if not scopes.has(key):retired.append(topology[key]);topology.erase(key)
	mutex.unlock();retired.clear()
func _next(memory: Dictionary) -> Dictionary:
	mutex.lock();var next := {}
	if not closing:
		for job in jobs:
			if failures.has(job.key) or (prepared.has(job.key) and prepared[job.key].token == token):continue
			if job.charge > limit:
				failures[job.key] = "Mesh frame exceeds the CPU preparation cache allowance.";pressure_failures[job.key] = true;continue
			var key: String = job.key;var source := false;var entry := {}
			if not sources.has(job.a_key):key = job.a_key;entry = job.entry;source = true
			elif not sources.has(job.b_key):key = job.b_key;entry = job.next;source = true
			# If the nearest endpoint is decoding, another lane can decode its partner.
			if source and in_flight.has(key) and not sources.has(job.b_key) and not in_flight.has(job.b_key):key = job.b_key;entry = job.next
			if in_flight.has(key):continue
			var safe := maxi(0,int(memory.available_physical)-int(memory.reserve)-int(job.get("other_reservation",0))-limit)
			active_limit = mini(worker_count,maxi(1,safe/maxi(1,int(job.charge)*3)))
			if in_flight.size() >= active_limit or used+in_flight_bytes+int(job.charge) > limit:break
			if safe < (in_flight_bytes+int(job.charge))*3:
				if not in_flight.is_empty():break
				failures[job.key] = "Mesh CPU preparation paused: insufficient physical RAM headroom. Free RAM or hide a mesh layer.";pressure_failures[job.key] = true;break
			var task := Task.new();task.owner_ref = weakref(self);task.key = key;task.generation = token;task.source = source;task.charge = job.charge
			next = {"job":job,"task":task,"entry":entry,"prior":topology.get(job.topology_key,{})}
			if not source:next.a = sources[job.a_key];next.b = sources[job.b_key];endpoint_hits += 2
			in_flight[key] = task;in_flight_bytes += task.charge
			peak_in_flight_bytes = maxi(peak_in_flight_bytes,in_flight_bytes);peak_active = maxi(peak_active,in_flight.size());break
	mutex.unlock();return next
func _barrier() -> void:
	# One opt-in publication gate can stop all lanes; never hold the cache mutex.
	barrier_mutex.lock()
	mutex.lock();var gate := test_barrier
	if gate != null:at_barrier = true
	mutex.unlock()
	if gate != null:gate.wait()
	mutex.lock();at_barrier = false;mutex.unlock();barrier_mutex.unlock()
func _run(lane: int) -> void:
	mutex.lock();worker_thread = OS.get_thread_caller_id();mutex.unlock()
	while true:
		wake.wait()
		mutex.lock();var done := closing;mutex.unlock()
		if done:return
		_prune()
		while true:
			var task_data := _next(_memory_headroom())
			if task_data.is_empty():break
			var task: Task = task_data.task;var job: Dictionary = task_data.job
			var began := Time.get_ticks_usec();var stages := {};var result := {}
			if Stamp.read(job.path) != job.stamp:result = {"error":"Mesh source changed; waiting for refresh."}
			elif task.source:
				var file := FileAccess.open(job.path,FileAccess.READ)
				result = Source.decode(file,task_data.entry,job.object,task,task_data.prior) if file != null else {"error":"Cannot open mesh source."}
				stages = result.get("timings",{})
			else:
				result = Prepare.pair(job.object,task_data.a,task_data.b,job.state,job.budget,job.colors,task,stages,true)
				if result.has("error"):result = {"a":task_data.a,"b":task_data.b,"empty":true,"gpu_bytes":0,"preview_error":result.error}
				_barrier()
			if not result.is_empty() and not result.has("error") and Stamp.read(job.path) != job.stamp:result = {"error":"Mesh source changed during preparation."}
			var obsolete := task.stopped();var elapsed := (Time.get_ticks_usec()-began)/1000.0
			mutex.lock()
			in_flight.erase(task.key);in_flight_bytes -= task.charge
			if obsolete or closing or (not wanted_sources.has(task.key) if task.source else token != task.generation or not wanted.has(task.key)):cancelled += 1
			elif result.has("error"):failures[job.key] = result.error
			elif not result.is_empty():
				if task.source:
					if source_bytes+int(result.bytes) <= limit:
						sources[task.key] = result;source_bytes += int(result.bytes);decoded += 1
						if result.topology_reused:topology_reuses += 1
						topology[job.topology_key] = result.topology
					else:failures[job.key] = "Decoded mesh endpoints exceed the CPU preparation allowance.";pressure_failures[job.key] = true
				elif used+int(job.charge)+in_flight_bytes <= limit:
					result.token = task.generation;result.bytes = job.charge;prepared[job.key] = result;used += int(job.charge);completed += 1
					if pair_times.size() < 4096:
						pair_times.append(elapsed);readiness_times.append((Time.get_ticks_usec()-int(job.queued_us))/1000.0)
			for name in stages:pipeline_stages[name] = pipeline_stages.get(name,0.0)+stages[name]
			worker_ms += elapsed;lane_ms[str(lane)] = lane_ms.get(str(lane),0.0)+elapsed
			mutex.unlock();result = {};task_data = {};_wake();_prune()
