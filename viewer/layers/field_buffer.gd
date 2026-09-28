extends RefCounted
# One cache coordinator and a bounded CPU pool; ordered immutable publication.
const Reader = preload("res://layers/scene_reader.gd")
const Prepare = preload("res://layers/field_prepare.gd")
const Stamp = preload("res://data/source_stamp.gd")
const Memory = preload("res://layers/playback_buffer.gd")
const Work = preload("res://layers/field_work.gd")
var worker_count := default_worker_count()
var automatic_workers := not OS.get_environment("SIMSCOPE_FIELD_WORKERS") in ["1","2","3","4"]
var active_limit := 1
var pressure_events := 0
var rates := {} # Busy batch wall time and successful publications, by lane count.
var lanes: Array = []
var in_flight := {} # Key -> exact retained charge; includes cancelled work until joined.
var in_flight_bytes := 0
var peak_in_flight_bytes := 0
var peak_active := 0
var largest_job_charge := 0
var thread := Thread.new()
var mutex := Mutex.new()
var wake := Semaphore.new()
var closing := false
var token := ""
var working_token := ""
var working_key := ""
var jobs: Array = []
var wanted := {}
var wanted_sources := {}
var prepared := {}
var source_keys := {} # One selected preview per immutable all-channel source sample.
var source_reuses := 0
var cache_token := ""
var order: Array[String] = []
var used := 0
var limit := 128*Memory.MIB
# Keep one already-admitted allocation across compatible channel changes.
# Obsolete entries stay owned/charged until replacements need their space;
# freeing them all can leave malloc-resident pages invisible to RAM admission.
var retained_limit := 0
var error := ""
var failures := {}
# Automatic windows and explicitly selected interval preparation share one cache.
var session := {}
var pending_plan: Array = []
var session_serial := 0
var completed := 0
var cancelled := 0
var evictions := 0
var pressure_evictions := 0
var eviction_events: Array = [] # Bounded diagnostics; no sample payloads.
var protected_keys := {}
var rolling_time := 0.0
var rolling_direction := 1
var cache_hits := 0
var worker_ms := 0.0
var pipeline_stages := {}
var worker_thread := -1
var trace_reads := false # Opt-in bounded diagnostic, never a second capture index.
var read_keys: Array[String] = []
var test_barrier: Semaphore
var at_barrier := false
static func default_worker_count() -> int:
	var configured := OS.get_environment("SIMSCOPE_FIELD_WORKERS")
	if configured in ["1","2","3","4"]:return int(configured)
	return clampi(OS.get_processor_count()-2,1,4)
func start() -> Error:
	worker_count = clampi(worker_count,1,4)
	active_limit = mini(2,worker_count) if automatic_workers else worker_count
	for i in range(worker_count):
		var lane := Work.new();var result := lane.start(self)
		if result != OK:
			for prior in lanes:prior.close()
			lanes.clear();return result
		lanes.append(lane)
	var result := thread.start(_run,Thread.PRIORITY_LOW)
	if result != OK:
		for lane in lanes:lane.close()
		lanes.clear()
	return result
func set_concurrency(count: int) -> void:
	mutex.lock();active_limit = clampi(count,1,worker_count);mutex.unlock();wake.post()
func close() -> void:
	mutex.lock();closing = true;mutex.unlock();wake.post()
	if thread.is_started():thread.wait_to_finish()
func request(next_token: String, next_jobs: Array, bytes: int, automatic := false) -> void:
	mutex.lock()
	if token != next_token:
		failures.clear();session.clear();pending_plan.clear();session_serial += 1
	if not automatic and not session.get("automatic",false) and session.get("state") in ["planning","preparing","ready"]:
		mutex.unlock();return
	if session.get("state") == "blocked":session.state = "refused"
	token = next_token;_set_jobs(next_jobs);limit = bytes if automatic else maxi(bytes,retained_limit);error = ""
	if automatic:
		retained_limit = mini(retained_limit,limit)
		var ready := 0;var rejected := 0
		for job in jobs:
			if prepared.has(job.key) and prepared[job.key].token == token:ready += 1
			if failures.has(job.key):rejected += 1
		session = {"automatic":true,"state":"ready" if ready+rejected == jobs.size() else "preparing","ready":ready,"failed":rejected,"total":jobs.size(),"next":0,"required_bytes":bytes,"started_us":Time.get_ticks_usec()}
	for old in failures.keys():
		if not wanted.has(old):failures.erase(old)
	mutex.unlock();wake.post()
func cancel(retain_cache := false) -> void:
	mutex.lock()
	retained_limit = used if retain_cache else 0
	token += "!";_set_jobs([]);session.clear();pending_plan.clear();session_serial += 1;mutex.unlock();wake.post()
func job_stopped(generation: String, key: String) -> bool:
	mutex.lock();var stop := closing or token != generation or not wanted.has(key);mutex.unlock();return stop
func get_frame(key: String) -> Dictionary:
	mutex.lock();var value: Dictionary = prepared.get(key,{})
	if value.get("token") != token:value = {}
	elif not value.is_empty():order.erase(key);order.append(key);cache_hits += 1
	mutex.unlock();return value
func status(include_events := false) -> Dictionary:
	mutex.lock()
	var result := {"bytes":used,"limit":limit,"retained_limit":retained_limit,"frames":prepared.size(),"completed":completed,"source_reuses":source_reuses,"cancelled":cancelled,"evictions":evictions,"worker_ms":worker_ms,"pipeline_stages":pipeline_stages.duplicate(true),"worker_thread":worker_thread,"active":not working_key.is_empty(),"error":error,"failures":failures.duplicate(),"test_barrier_waiting":at_barrier,"session":session.duplicate()}
	result.active = not in_flight.is_empty() or not working_key.is_empty()
	result.worker_count = worker_count;result.in_flight_bytes = in_flight_bytes;result.active_jobs = in_flight.size()
	result.active_limit = active_limit;result.automatic_workers = automatic_workers;result.pressure_events = pressure_events;result.rates = rates.duplicate(true)
	result.peak_in_flight_bytes = peak_in_flight_bytes;result.peak_active = peak_active
	result.pressure_evictions = pressure_evictions;result.cache_hits = cache_hits
	if include_events:result.eviction_events = eviction_events.duplicate(true)
	result.largest_job_charge = largest_job_charge
	result.retirement_reserve_bytes = largest_job_charge*3*(worker_count-1)
	var charges := {};var resident := 0
	for key in prepared:
		var value: Dictionary = prepared[key]
		resident += mini(int(value.bytes),int(value.sample.decoded_bytes)+int(value.gpu_bytes))
		if value.token == token:charges[key] = value.bytes
	result.charges = charges;result.resident_bytes = resident
	mutex.unlock();return result
func read_trace() -> Array[String]:
	mutex.lock();var result := read_keys.duplicate();mutex.unlock();return result
func protect(keys: Dictionary, time: float, direction: int) -> void:
	mutex.lock();protected_keys = keys;rolling_time = time;rolling_direction = direction;mutex.unlock()
func _memory_headroom() -> Dictionary:
	return Memory.memory_headroom()
# Caller holds the publication mutex. This also makes cancellation O(1),
# independent of the number of admitted samples.
func _set_jobs(next_jobs: Array) -> void:
	jobs = next_jobs;wanted = {};wanted_sources = {}
	for job in jobs:wanted[job.key] = true;wanted_sources[job.get("source_key",job.key)] = true
func prepare_session(next_token: String, next_jobs: Array) -> void:
	mutex.lock()
	if token == next_token and session.get("state") == "ready":
		mutex.unlock();return
	if token != next_token:failures.clear()
	token = next_token;session_serial += 1;pending_plan = next_jobs;_set_jobs([]);failures.clear()
	session = {"state":"planning","planned":0,"total":next_jobs.size(),"ready":0,"required_bytes":0,"error":"","started_us":Time.get_ticks_usec()}
	mutex.unlock();wake.post()
func cancel_session() -> void:
	mutex.lock()
	if session.get("state") != "ready":
		retained_limit = mini(retained_limit,used)
		session.clear();pending_plan.clear();_set_jobs([]);session_serial += 1
	mutex.unlock();wake.post()
func _planning_cancelled(serial: int) -> bool:
	mutex.lock();var stop := closing or serial != session_serial;mutex.unlock();return stop
static func session_capacity(memory: Dictionary, resident: int, other: int, largest: int, workers := 1) -> int:
	# Extra lanes need both live scratch and a retired-batch allowance. Native
	# allocator arenas need not promptly recycle buffers freed by the coordinator.
	return preload("res://layers/playback_memory.gd").capacity(memory,resident,other+largest*6*(workers-1),largest)
func _plan_session() -> void:
	mutex.lock();var plan := pending_plan;pending_plan = [];var serial := session_serial;mutex.unlock()
	if plan.is_empty():return
	var required := 0;var largest := 0;var other := 0;var problem := ""
	for i in range(plan.size()):
		if _planning_cancelled(serial):return
		var job: Dictionary = plan[i]
		if Stamp.read(job.path) != job.stamp:problem = "Field source changed during preparation.";break
		var file := FileAccess.open(job.path,FileAccess.READ)
		mutex.lock()
		var cached: Dictionary = prepared.get(source_keys.get(job.get("source_key",""),""),{})
		var prior_entry: Dictionary = cached.get("entry",{}) if cached.get("scope") == job.get("scope") else {}
		mutex.unlock()
		var entry := Reader.materialize(file,job.entry,job.object) if prior_entry.is_empty() else prior_entry
		if entry.has("error"):problem = entry.error;break
		job.entry = entry
		var charge := Prepare.charge(entry,job.channel,job.budget)
		if charge.has("error"):problem = Reader.record_error(entry,charge.error);break
		job.charge = charge.bytes;job.preview_charge = charge.preview;job.decoded_charge = charge.decoded
		required += job.charge;largest = maxi(largest,job.charge);other = maxi(other,int(job.get("other_reservation",0)))
		mutex.lock()
		if serial == session_serial:session.planned = i+1;session.required_bytes = required
		mutex.unlock()
	var memory := Memory.memory_headroom()
	mutex.lock()
	if serial != session_serial or closing:mutex.unlock();return
	# Lazy window charges can overestimate a future preview. Credit only the
	# known retained arrays/planes, not that conservative admission estimate.
	var resident := 0
	for value in prepared.values():resident += mini(int(value.bytes),int(value.sample.decoded_bytes)+int(value.gpu_bytes))
	var capacity := session_capacity(memory,resident,other,maxi(largest,largest_job_charge),worker_count)
	session.capacity = capacity;session.memory = memory;session.required_bytes = required
	session.resident_credit = resident;session.reserved_other_bytes = other;session.largest_job_bytes = largest
	if problem.is_empty() and required > capacity:
		problem = "Continuous field playback needs %.1f GiB prepared RAM; %.1f GiB is safely available. Choose a shorter interval in Performance, or free RAM and retry. Source quality is unchanged." % [required/float(1024*Memory.MIB),capacity/float(1024*Memory.MIB)]
	if not problem.is_empty():session.state = "blocked";session.error = problem;mutex.unlock();return
	# Replace conservative lazy-header charges with the validated exact plan.
	var ready := 0
	for job in plan:
		if prepared.has(job.key) and prepared[job.key].token == token:
			used += job.charge-int(prepared[job.key].bytes);prepared[job.key].bytes = job.charge;ready += 1
	limit = required;retained_limit = required;_set_jobs(plan);session.state = "preparing";session.ready = ready;session.next = 0
	mutex.unlock()
func _session_progress() -> void:
	mutex.lock()
	if session.get("state") == "preparing" and session.ready+int(session.get("failed",0)) == session.total:
		session.state = "ready";session.elapsed_ms = (Time.get_ticks_usec()-session.started_us)/1000.0
	mutex.unlock()
func _victim() -> String:
	# Caller holds the mutex. Automatic jobs are already ordered by direction;
	# never sacrifice their contiguous runway to prepare a more distant sample.
	if not session.get("automatic",false):
		# Explicit interval admission retains its established replacement order.
		var candidates := order.filter(func(old):return not protected_keys.has(old) and not in_flight.has(old))
		var victim: String = candidates[0] if not candidates.is_empty() else ""
		for old in candidates:
			if prepared[old].token != token:victim = old;break
		for old in candidates:
			if not wanted_sources.has(prepared[old].get("source_key",old)):victim = old;break
		return victim
	var victim := "";var distance := -INF;var unrelated := false
	for old in order:
		if protected_keys.has(old) or in_flight.has(old):continue
		var value: Dictionary = prepared[old]
		if session.get("automatic",false) and wanted.has(old) and value.token == token:continue
		var score := absf(float(value.sample.time)-rolling_time)
		var outside := not wanted_sources.has(value.get("source_key",old))
		if victim.is_empty() or (outside and not unrelated) or (outside == unrelated and score > distance):
			victim = old;distance = score;unrelated = outside
	return victim
func _retire(key: String, pressure: bool) -> Dictionary:
	# Caller holds the mutex; destruction happens outside it on the coordinator.
	var value: Dictionary = prepared[key]
	if source_keys.get(value.get("source_key","")) == key:source_keys.erase(value.get("source_key",""))
	used -= int(value.bytes);prepared.erase(key);order.erase(key);evictions += 1
	if pressure:pressure_evictions += 1
	eviction_events.append({"time":value.sample.time,"playhead":rolling_time,"direction":rolling_direction,"bytes":value.bytes,"pressure":pressure})
	if eviction_events.size() > 128:eviction_events.pop_front()
	return value
func _prune(incoming: int, key: String, release_bytes := 0) -> bool:
	var retired: Array = []
	mutex.lock()
	if cache_token != token and retained_limit == 0:
		var kept: Array[String] = []
		for old in order:
			if prepared[old].token != token and not protected_keys.has(old):
				source_keys.erase(prepared[old].get("source_key",""))
				retired.append(prepared[old]);used -= int(prepared[old].bytes);prepared.erase(old)
			else:kept.append(old)
		order = kept;cache_token = token
	# A matching key from an invalidated generation cannot block its replacement.
	if prepared.has(key) and prepared[key].token != token and not protected_keys.has(key):
		source_keys.erase(prepared[key].get("source_key",""))
		retired.append(prepared[key]);used -= int(prepared[key].bytes);prepared.erase(key);order.erase(key)
	var released := 0
	while used+incoming > limit or released < release_bytes:
		var victim := _victim()
		if victim.is_empty():break
		var value := _retire(victim,release_bytes > 0)
		released += int(value.bytes);retired.append(value)
	var fits := used+incoming <= limit and not prepared.has(key)
	mutex.unlock();retired.clear();return fits
func _take_source(job: Dictionary) -> Dictionary:
	# Only compatible source/visibility/budget scopes can reuse arrays. Remove
	# the obsolete preview's charge before replacing it, retaining one allocation.
	mutex.lock()
	var key: String = source_keys.get(job.get("source_key",""),"")
	var value: Dictionary = prepared.get(key,{})
	var result := {}
	if not value.is_empty() and value.get("scope") == job.get("scope"):
		result = {"sample":value.sample,"entry":value.entry,"previous":value,"previous_key":key}
		used -= int(value.bytes);prepared.erase(key);order.erase(key);source_keys.erase(job.source_key);source_reuses += 1
	mutex.unlock();return result
func _next() -> Dictionary:
	mutex.lock();var next := {}
	if not closing and session.get("state") not in ["ready","blocked","pressure"]:
		var first := 0 # Recheck deferred/admission-limited jobs; in_flight prevents duplicates.
		for index in range(first,jobs.size()):
			var job: Dictionary = jobs[index]
			if session.get("state") == "preparing":session.next = index+1
			if not in_flight.has(job.key) and not failures.has(job.key) and (not prepared.has(job.key) or prepared[job.key].token != token):
				var source: Dictionary = prepared.get(source_keys.get(job.get("source_key",""),""),{})
				if not source.is_empty() and source.get("scope") == job.get("scope"):
					# Lazy headers overestimate the preview by all channel bytes.
					# Use the already-validated descriptor so replacing one preview
					# cannot evict other reusable source samples unnecessarily.
					var exact := Prepare.charge(source.entry,job.channel,job.budget)
					if not exact.has("error"):job = job.duplicate();job.charge = exact.bytes
				next = job;working_key = job.key;working_token = token;break
	mutex.unlock();return next
func _admit(lane, job: Dictionary) -> bool:
	# Coordinator-only admission. Reserve all outstanding jobs even if their
	# generations were cancelled; their arrays remain live until collection.
	var generation := working_token
	var began := Time.get_ticks_usec();var materialized := {};var reusable := {};var result := {}
	mutex.lock()
	var prior: Dictionary = prepared.get(source_keys.get(job.get("source_key",""),""),{})
	if prior.get("scope") == job.get("scope"):materialized = prior.get("entry",{})
	var replacement_bytes: int = int(prior.get("bytes",0)) if not materialized.is_empty() else 0
	var automatic: bool = session.get("automatic",false)
	mutex.unlock()
	if job_stopped(generation,job.key):return false
	if materialized.is_empty():materialized = Reader.materialize(FileAccess.open(job.path,FileAccess.READ),job.entry,job.object)
	if materialized.has("error"):result = {"error":materialized.error}
	else:
		var exact := Prepare.charge(materialized,job.channel,job.budget)
		if exact.has("error"):result = {"error":Reader.record_error(job.entry,exact.error)}
		else:job = job.duplicate();job.charge = exact.bytes
	# Remove the local payload reference before attempting physical reclamation.
	prior = {}
	var memory := _memory_headroom()
	mutex.lock()
	largest_job_charge = maxi(largest_job_charge,int(job.charge))
	var outstanding := in_flight_bytes;var fits_limit: bool = job.charge+outstanding <= limit
	var retirement_reserve := largest_job_charge*3*(worker_count-1)
	mutex.unlock()
	var required: int = memory.reserve+int(job.get("other_reservation",0))+retirement_reserve+(job.charge+outstanding)*3
	if result.is_empty() and automatic and fits_limit:
		# Reclaim before the physical admission check. MemAvailable excludes these
		# resident pages already; ownership credit alone cannot admit new work.
		_prune(maxi(0,outstanding+job.charge-replacement_bytes),job.key)
		memory = _memory_headroom()
		if memory.available_physical < required:
			mutex.lock();pressure_events += 1
			if automatic_workers:active_limit = 1
			mutex.unlock()
			if outstanding > 0:return false
		while memory.available_physical < required:
			var before: int = status().bytes
			_prune(maxi(0,outstanding+job.charge-replacement_bytes),job.key,required-int(memory.available_physical))
			memory = _memory_headroom()
			if status().bytes == before:break
	if result.is_empty() and (not fits_limit or memory.available_physical < required):
		mutex.lock();pressure_events += 1
		if automatic_workers:active_limit = 1
		mutex.unlock()
		# Drain existing work before retrying with fewer simultaneous lanes.
		if outstanding > 0:return false
		if automatic:
			var owned: int = status().resident_bytes
			mutex.lock()
			if token == generation and wanted.has(job.key) and not closing:
				limit = mini(limit,session_capacity(memory,owned,int(job.get("other_reservation",0)),largest_job_charge,worker_count))
				retained_limit = mini(retained_limit,limit);session.state = "pressure"
			mutex.unlock();_prune(0,"");return false
		result = {"error":"Field preparation needs %.1f MiB available RAM including concurrent work and other reservations; %.1f MiB is available. Free RAM or reduce other caches." % [required/float(Memory.MIB),memory.available_physical/float(Memory.MIB)]}
	if job_stopped(generation,job.key):return false
	if result.is_empty():
		if Stamp.read(job.path) != job.stamp:result = {"error":"Field source changed; waiting for refresh."}
		else:
			reusable = _take_source(job)
			if not _prune(outstanding+job.charge,job.key):result = {"capacity":true} if automatic else {"error":"Field frame exceeds the preparation budget."}
	mutex.lock()
	in_flight[job.key] = job.charge;in_flight_bytes += int(job.charge)
	peak_in_flight_bytes = maxi(peak_in_flight_bytes,in_flight_bytes);peak_active = maxi(peak_active,in_flight.size())
	if trace_reads and result.is_empty() and reusable.is_empty() and read_keys.size() < 4096:read_keys.append(job.key)
	mutex.unlock()
	lane.job = job;lane.generation = generation;lane.entry = materialized;lane.reusable = reusable
	lane.result = result;lane.stages = {};lane.elapsed_ms = (Time.get_ticks_usec()-began)/1000.0
	if result.is_empty():lane.wake.post()
	else:lane.done.post()
	return true
func _collect(lane) -> void:
	lane.done.wait()
	var job: Dictionary = lane.job;var result: Dictionary = lane.result;var reusable: Dictionary = lane.reusable
	var gate := test_barrier
	if gate != null:
		mutex.lock();at_barrier = true;mutex.unlock();gate.wait();mutex.lock();at_barrier = false;mutex.unlock()
	if not result.is_empty() and not result.has("error") and not result.has("capacity") and Stamp.read(job.path) != job.stamp:
		result = {"error":"Field source changed during preparation."}
	mutex.lock()
	if closing or token != lane.generation or not wanted.has(job.key):
		cancelled += 1
		if not closing and retained_limit > 0 and reusable.has("previous"):
			var previous: Dictionary = reusable.previous
			if not source_keys.has(previous.source_key) and used+int(previous.bytes)+in_flight_bytes-int(job.charge) <= limit:
				prepared[reusable.previous_key] = previous;order.append(reusable.previous_key);source_keys[previous.source_key] = reusable.previous_key;used += int(previous.bytes)
	elif result.has("capacity"):
		cancelled += 1;session.state = "pressure"
	elif result.has("error"):
		failures[job.key] = result.error
		if session.get("automatic",false):session.failed += 1
		elif session.get("state") == "preparing":session.state = "blocked";session.error = result.error
	elif not result.is_empty() and used+in_flight_bytes > limit:
		# Budget shrank during decoding; do not publish above the new ceiling.
		cancelled += 1
	elif not result.is_empty():
		result.entry = lane.entry;result.scope = job.get("scope","");result.source_key = job.get("source_key",job.key);source_keys[result.source_key] = job.key
		result.token = lane.generation;result.bytes = job.charge;prepared[job.key] = result;order.append(job.key);used += job.charge;completed += 1
		if session.get("state") == "preparing":session.ready += 1
	for stage in lane.stages:
		if not pipeline_stages.has(stage):pipeline_stages[stage] = {"count":0,"total_ms":0.0,"max_ms":0.0}
		pipeline_stages[stage].count += 1;pipeline_stages[stage].total_ms += lane.stages[stage]
		pipeline_stages[stage].max_ms = maxf(pipeline_stages[stage].max_ms,lane.stages[stage])
	worker_ms += lane.elapsed_ms
	mutex.unlock()
	# Release rejected/cancelled data before removing its reservation. The
	# publication reference is immutable and remains charged in `used`.
	lane.result = {};lane.reusable = {};lane.entry = {};lane.job = {};result = {};reusable = {}
	mutex.lock();in_flight_bytes -= int(job.charge);in_flight.erase(job.key);mutex.unlock()
	_session_progress()
func _run() -> void:
	mutex.lock();worker_thread = OS.get_thread_caller_id();mutex.unlock()
	while true:
		wake.wait()
		mutex.lock();var done := closing;mutex.unlock()
		if done:break
		_plan_session();_prune(0,"")
		while true:
			var batch: Array = []
			mutex.lock();var count := active_limit;var before := completed;mutex.unlock()
			var began := Time.get_ticks_usec()
			for lane in lanes.slice(0,count):
				var job := _next()
				if job.is_empty() or not _admit(lane,job):break
				batch.append(lane)
			# Fixed batches bound the completion queue to worker_count. A later
			# result can never publish ahead of an earlier requested sample.
			for lane in batch:_collect(lane)
			if not batch.is_empty():
				mutex.lock();var key := str(batch.size())
				if not rates.has(key):rates[key] = {"samples":0,"seconds":0.0}
				rates[key].samples += completed-before;rates[key].seconds += (Time.get_ticks_usec()-began)/1000000.0
				mutex.unlock()
			mutex.lock();working_key = "";var stop: bool = closing or session.get("state") in ["blocked","pressure"];mutex.unlock()
			_prune(0,"");_session_progress()
			if batch.is_empty() or stop:break
	for lane in lanes:lane.close()
	lanes.clear()
	prepared.clear();source_keys.clear();order.clear();mutex.lock();used = 0;retained_limit = 0;mutex.unlock()
