extends RefCounted
# One CPU worker owns decoding and reclamation. Published pairs are immutable;
# the main thread holds references and creates/updates GPU resources itself.
const Cache = preload("res://data/byte_cache.gd")
const Typed = preload("res://data/typed_decode.gd")
const Stamp = preload("res://data/source_stamp.gd")
const Reader = preload("res://layers/scene_reader.gd")
const Prepare = preload("res://layers/particle_prepare.gd")
const MIB := 1048576
var mutex := Mutex.new()
var wake := Semaphore.new()
var thread := Thread.new()
var closing := false
var context := {}
var desired: Array[int] = []
var token := ""
var working_token := ""
var working_index := -1
var failures := {} # Only requested-window failures; future failures do not gate a resident pair.
var pinned := -1
var prior_pin := -1
var prepared := {}
var order: Array[int] = []
var prepared_used := 0
var decoded := Cache.new() # Worker-only, including eviction/destruction.
var decoded_source := ""
var timings := {} # Worker-only; never write the global main-thread profiler.
var trace_enabled := false
var events: Array = []
var events_dropped := 0
var metrics := {"prepared_hits":0,"prepared_misses":0,"prepared_evictions":0,"cancelled":0,"completed":0,"decoded_hits":0,"decoded_misses":0,"decoded_bytes":0,"prepared_bytes":0,"decoded_samples":0,"worker_active":false,"error":""}
var test_barrier: Semaphore

static func memory_headroom() -> Dictionary:
	# OS.get_memory_info().available can include swap. Linux MemAvailable does not.
	var info := OS.get_memory_info()
	var physical: int = maxi(0,info.get("physical",0))
	var available: int = maxi(0,info.get("free",0))
	if OS.get_name() == "Linux":
		var proc := FileAccess.open("/proc/meminfo",FileAccess.READ)
		var text := proc.get_buffer(65536).get_string_from_utf8() if proc != null else ""
		for line in text.split("\n"):
			var parts := line.split(" ",false)
			if parts.size() >= 2:
				if parts[0] == "MemTotal:":physical = int(parts[1])*1024
				if parts[0] == "MemAvailable:":available = int(parts[1])*1024
	var reserve := maxi(2*1024*MIB,int(physical*.15))
	# Includes an extra 1 GiB reserve for renderer/layers/transient preparation.
	var safe := maxi(0,mini(int(physical*.4),available-reserve-1024*MIB))
	return {"physical":physical,"available_physical":available,"reserve":reserve+1024*MIB,"safe_cache_bytes":safe}

static func estimate(entries: Array, trails: bool) -> Dictionary:
	var samples: Array[int] = []
	for entry in entries:
		var ids: bool = entry.get("identity","") == "persistent_i8"
		var count := mini(1000000 if ids else 10000000,int(entry.decoded)/(20 if ids else 12));var scalars: int = entry.get("array_count",256) if entry.descriptor.is_empty() else 0
		for array in entry.descriptor.get("arrays",[]):
			if array.name == "position":count = int(array.shape[0])
			if array.name == "particle_id":ids = true
			scalars += 1
		# f8/u4 conversion, immutable identity table and display arrays included.
		samples.append(int(entry.decoded)*2+count*(180 if ids else 20)+8192+scalars*512)
	var pairs: Array[int] = []
	for i in range(entries.size()):
		var count := mini(10000000,int(entries[i].decoded)/12)
		for array in entries[i].descriptor.get("arrays",[]):
			if array.name == "position":count = int(array.shape[0])
		var cost := samples[i]+(samples[i+1] if i+1<samples.size() else 0)+count*76+16384
		if trails:
			for j in range(maxi(0,i-5),i):cost += samples[j]+count*64
		pairs.append(cost)
	var decoded_total := 0;var prepared_total := 0;var largest := 0
	for bytes in samples:decoded_total += bytes
	for bytes in pairs:prepared_total += bytes;largest = maxi(largest,bytes)
	return {"decoded_total":decoded_total,"prepared_total":prepared_total,"total":decoded_total+prepared_total,"largest_pair":largest,"sample_estimates":samples,"pair_estimates":pairs}

func start() -> Error:
	return thread.start(_run,Thread.PRIORITY_LOW)
func close() -> void:
	mutex.lock();closing = true;mutex.unlock();wake.post()
	if thread.is_started():thread.wait_to_finish()
func request(next_context: Dictionary, indices: Array[int]) -> void:
	mutex.lock()
	if token != next_context.token:failures.clear()
	context = next_context;token = context.token;desired = indices
	for old in failures.keys():
		if not indices.has(old):failures.erase(old)
	metrics.error = ""
	mutex.unlock();wake.post()
func cancel() -> void:
	mutex.lock();desired = [];mutex.unlock();wake.post()
func stopped() -> bool:
	mutex.lock()
	var stop := closing or working_token != token or not desired.has(working_index)
	mutex.unlock();return stop
func get_pair(index: int, count_hit := true) -> Dictionary:
	mutex.lock()
	var value: Dictionary = prepared.get(index,{})
	if not value.is_empty() and value.token == token:
		if count_hit:metrics.prepared_hits += 1
		order.erase(index);order.append(index)
	else:
		value = {}
		if count_hit:metrics.prepared_misses += 1
	mutex.unlock();return value
func pin(index: int) -> void:
	mutex.lock()
	if pinned != index:prior_pin = pinned;pinned = index
	mutex.unlock()
func status() -> Dictionary:
	mutex.lock()
	var result := metrics.duplicate()
	var ready: Array[int] = []
	for index in prepared:
		if prepared[index].token == token:ready.append(index)
	result.failures = failures.duplicate();result.ready_indices = ready;result.prepared_pairs = ready.size();result.prepared_bytes = prepared_used
	result.desired = desired.duplicate();result.working_index = working_index;result.trace_dropped = events_dropped
	mutex.unlock();return result
func drain_events() -> Array:
	mutex.lock();var result := events;events = [];mutex.unlock();return result
func observe(name: String, since: int) -> void:
	timings[name] = timings.get(name,0.0)+(Time.get_ticks_usec()-since)/1000.0
func _source_matches(job: Dictionary) -> bool:
	var start_time := Time.get_ticks_usec()
	var ok: bool = not job.stamp.is_empty() and Stamp.read(job.path) == job.stamp
	observe("source_validation",start_time)
	return ok
func _read(index: int, job: Dictionary, file: FileAccess) -> Dictionary:
	var hit := decoded.get_frame(index)
	if not hit.is_empty():return hit
	if stopped():return {}
	var entry: Dictionary = Reader.materialize(file,job.entries[index],job.object)
	if entry.has("error"):return entry
	var descriptors: Array = [];var count := 0;var ids := false;var shapes := {};var associations := {}
	for array in entry.descriptor.arrays:
		var components: int = int(array.shape[1]) if array.shape.size()==2 else 1
		descriptors.append({"name":array.name,"dtype":array.dtype,"components":components,"required":true,"chunks":array.chunks})
		shapes[array.name] = array.shape;associations[array.name] = array.association
		if array.name == "position":count = int(array.shape[0])
		if array.name == "particle_id":ids = true
	var descriptor := {"offset":entry.offset,"count":count,"time":entry.time,"channels":descriptors,"has_ids":ids}
	var memory_before := OS.get_static_memory_usage()
	var start_time := Time.get_ticks_usec()
	# This worker owns decoded entries. Borrow a resident neighbor without
	# retaining a new cache or changing its LRU order/limits.
	var reference: Dictionary = decoded.entries.get(index-1,decoded.entries.get(index+1,{})).get("value",{})
	var data := Typed.read(file,descriptor,self,reference)
	observe("read_decode_identity",start_time)
	if data.has("error"):return {"error":Reader.record_error(entry,data.error)}
	if data.is_empty():return data
	data.source_index = index;data.sequence = entry.sequence;data.shapes = shapes;data.associations = associations;data.geometry = entry.descriptor.geometry
	data = Prepare.frame(data,self)
	if data.is_empty() or data.has("error"):return data
	data._memory_delta = OS.get_static_memory_usage()-memory_before
	decoded.put(index,data,data.decoded_bytes)
	return data
func _prune(job: Dictionary, incoming: int, incoming_index: int) -> bool:
	# Erase only small dictionary references while locked; destroy large ID maps
	# and packed arrays on this worker after releasing the publication lock.
	var retired: Array = []
	mutex.lock()
	for index in order.duplicate():
		if prepared[index].token != token:
			retired.append(prepared[index]);prepared_used -= int(prepared[index].bytes);prepared.erase(index);order.erase(index)
	while prepared_used+incoming > int(job.prepared_limit) and not order.is_empty():
		var victim := -1
		for index in order:
			if index != pinned and index != prior_pin and index != incoming_index and not desired.has(index):victim = index;break
		if victim < 0 and not job.get("full_preload",false):
			for index in order:
				if index != pinned and index != prior_pin and index != incoming_index:victim = index;break
		if victim < 0:break
		retired.append(prepared[victim]);prepared_used -= int(prepared[victim].bytes);prepared.erase(victim);order.erase(victim);metrics.prepared_evictions += 1
	var fits := prepared_used+incoming <= int(job.prepared_limit)
	mutex.unlock()
	retired.clear()
	return fits
func _next_job() -> Dictionary:
	mutex.lock()
	var job := {}
	if not closing and not context.is_empty():
		for index in desired:
			if not failures.has(index) and (not prepared.has(index) or prepared[index].token != token):
				working_index = index;working_token = token;job = context;metrics.worker_active = true;break
	mutex.unlock();return job
func _run() -> void:
	while true:
		wake.wait()
		mutex.lock();var done := closing;mutex.unlock()
		if done:break
		# Enforce changed budgets even when every requested pair is already resident.
		mutex.lock();var limits: Dictionary = context;mutex.unlock()
		if not limits.is_empty():
			decoded.configure(limits.decoded_limit)
			var fits := _prune(limits,0,-1)
			mutex.lock()
			metrics.decoded_bytes = decoded.used;metrics.decoded_samples = decoded.entries.size()
			if not fits and limits.token == token and limits.prepared_limit == context.prepared_limit:
				metrics.error = "Prepared pair exceeds the available playback budget; choose a larger safe budget.";desired = []
			mutex.unlock()
		while true:
			var job := _next_job()
			if job.is_empty():break
			var index := working_index;var started := Time.get_ticks_usec();timings = {}
			if decoded_source != job.source_token:decoded.clear();decoded_source = job.source_token
			decoded.configure(job.decoded_limit)
			_prune(job,0,index)
			var outcome := {}
			var memory := memory_headroom()
			var ahead := estimate(job.entries.slice(maxi(0,index-5) if job.config.trails else index,mini(job.entries.size(),index+2)),job.config.trails)
			if memory.available_physical < memory.reserve+ahead.largest_pair*2:
				outcome = {"error":"Playback preparation paused to preserve physical RAM headroom."}
			elif _source_matches(job):
				var file := FileAccess.open(job.path,FileAccess.READ)
				if file != null:
					var a := _read(index,job,file)
					var b := a if index+1 >= job.entries.size() else _read(index+1,job,file)
					var history: Array = []
					if job.config.trails and not a.is_empty() and not a.has("error"):
						for previous in range(index-1,maxi(-1,index-6),-1):
							var old := _read(previous,job,file)
							if old.is_empty() or old.has("error"):break
							history.append(old)
					if a.has("error"):outcome = a
					elif b.has("error"):outcome = b
					elif not a.is_empty() and not b.is_empty() and not stopped():outcome = Prepare.pair(a,b,history,job.config,self)
				else:outcome = {"error":"Cannot open playback source."}
			else:outcome = {"error":"Playback source changed; waiting for source refresh."}
			var gate := test_barrier
			if gate != null:
				mutex.lock();metrics.test_barrier_waiting = true;mutex.unlock()
				gate.wait()
				mutex.lock();metrics.test_barrier_waiting = false;mutex.unlock()
			if not outcome.is_empty() and not outcome.has("error") and not _source_matches(job):outcome = {"error":"Playback source changed during preparation."}
			var cancelled := stopped()
			if not cancelled and not outcome.is_empty() and not outcome.has("error"):
				if not _prune(job,outcome.bytes,index):outcome = {"error":"Prepared pair exceeds the available playback budget; choose a larger safe budget."}
			mutex.lock()
			cancelled = cancelled or working_token != token or not desired.has(index) or closing
			if cancelled:metrics.cancelled += 1
			elif outcome.has("error"):
				failures[index] = outcome.error;metrics.error = ""
			elif not outcome.is_empty():
				outcome.token = working_token;outcome.timings = timings.duplicate();outcome.worker_ms = (Time.get_ticks_usec()-started)/1000.0
				prepared[index] = outcome;prepared_used += int(outcome.bytes);order.append(index);metrics.completed += 1
			metrics.worker_active = false;metrics.decoded_hits = decoded.hits;metrics.decoded_misses = decoded.misses
			metrics.decoded_bytes = decoded.used;metrics.decoded_samples = decoded.entries.size()
			if trace_enabled:
				if events.size() < 4096:
					events.append({"index":index,"token":working_token,"start_us":started,"end_us":Time.get_ticks_usec(),"duration_ms":(Time.get_ticks_usec()-started)/1000.0,"cancelled":cancelled,"error":outcome.get("error",""),"stages":timings.duplicate(),"pair_bytes":outcome.get("bytes",0),"sample_a_bytes":outcome.get("a",{}).get("decoded_bytes",0),"sample_a_memory_delta":outcome.get("a",{}).get("_memory_delta",0),"thread_id":OS.get_thread_caller_id()})
				else:events_dropped += 1
			working_index = -1
			mutex.unlock()
			# Drop the worker's local result before another job can be picked.
			outcome = {}
			if cancelled:continue
			mutex.lock();var failed: bool = not metrics.error.is_empty();mutex.unlock()
			if failed:break
	# Destruction is also off the playback thread.
	prepared.clear();order.clear();decoded.clear()
