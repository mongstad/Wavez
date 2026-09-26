extends RefCounted
# One private CPU thread; immutable publication, independent file handle, finite LRU.
const Reader = preload("res://layers/scene_reader.gd")
const Channels = preload("res://layers/scene_channels.gd")
const Prepare = preload("res://layers/field_prepare.gd")
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
var worker_ms := 0.0
var pipeline_stages := {}
var worker_thread := -1
var trace_reads := false # Opt-in bounded diagnostic, never a second capture index.
var read_keys: Array[String] = []
var test_barrier: Semaphore
var at_barrier := false
func start() -> Error:return thread.start(_run,Thread.PRIORITY_LOW)
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
func stopped() -> bool:
	mutex.lock();var stop := closing or token != working_token or not wanted.has(working_key);mutex.unlock();return stop
func get_frame(key: String) -> Dictionary:
	mutex.lock();var value: Dictionary = prepared.get(key,{})
	if value.get("token") != token:value = {}
	elif not value.is_empty():order.erase(key);order.append(key)
	mutex.unlock();return value
func status() -> Dictionary:
	mutex.lock()
	var result := {"bytes":used,"limit":limit,"retained_limit":retained_limit,"frames":prepared.size(),"completed":completed,"source_reuses":source_reuses,"cancelled":cancelled,"evictions":evictions,"worker_ms":worker_ms,"pipeline_stages":pipeline_stages.duplicate(true),"worker_thread":worker_thread,"active":not working_key.is_empty(),"error":error,"failures":failures.duplicate(),"test_barrier_waiting":at_barrier,"session":session.duplicate()}
	var charges := {};var resident := 0
	for key in prepared:
		var value: Dictionary = prepared[key]
		resident += mini(int(value.bytes),int(value.sample.decoded_bytes)+int(value.gpu_bytes))
		if value.token == token:charges[key] = value.bytes
	result.charges = charges;result.resident_bytes = resident
	mutex.unlock();return result
func read_trace() -> Array[String]:
	mutex.lock();var result := read_keys.duplicate();mutex.unlock();return result
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
static func session_capacity(memory: Dictionary, resident: int, other: int, largest: int) -> int:
	return preload("res://layers/playback_memory.gd").capacity(memory,resident,other,largest)
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
	var capacity := session_capacity(memory,resident,other,largest)
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
func _prune(incoming: int, key: String) -> bool:
	var retired: Array = []
	mutex.lock()
	if cache_token != token and retained_limit == 0:
		var kept: Array[String] = []
		for old in order:
			if prepared[old].token != token:
				source_keys.erase(prepared[old].get("source_key",""))
				retired.append(prepared[old]);used -= int(prepared[old].bytes);prepared.erase(old)
			else:kept.append(old)
		order = kept;cache_token = token
	# A matching key from an invalidated generation cannot block its replacement.
	if prepared.has(key) and prepared[key].token != token:
		source_keys.erase(prepared[key].get("source_key",""))
		retired.append(prepared[key]);used -= int(prepared[key].bytes);prepared.erase(key);order.erase(key)
	while used+incoming > limit and not order.is_empty():
		# Retire obsolete channels first, preserving every current-session sample
		# already counted toward readiness. The cache never exceeds its one limit.
		var victim := 0
		for i in range(order.size()):
			if prepared[order[i]].token != token:victim = i;break
		# A smaller interval should retain its already-decoded source samples
		# while releasing unrelated times, even across a channel generation.
		for i in range(order.size()):
			if not wanted_sources.has(prepared[order[i]].get("source_key",order[i])):victim = i;break
		var old: String = order[victim];order.remove_at(victim)
		source_keys.erase(prepared[old].get("source_key",""))
		retired.append(prepared[old]);used -= int(prepared[old].bytes);prepared.erase(old);evictions += 1
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
		var first: int = session.get("next",0) if session.get("state") == "preparing" else 0
		for index in range(first,jobs.size()):
			var job: Dictionary = jobs[index]
			if session.get("state") == "preparing":session.next = index+1
			if not failures.has(job.key) and (not prepared.has(job.key) or prepared[job.key].token != token):
				var source: Dictionary = prepared.get(source_keys.get(job.get("source_key",""),""),{})
				if not source.is_empty() and source.get("scope") == job.get("scope"):
					# Lazy headers overestimate the preview by all channel bytes.
					# Use the already-validated descriptor so replacing one preview
					# cannot evict other reusable source samples unnecessarily.
					var exact := Prepare.charge(source.entry,job.channel,job.budget)
					if not exact.has("error"):job = job.duplicate();job.charge = exact.bytes
				next = job;working_key = job.key;working_token = token;break
	mutex.unlock();return next
func _run() -> void:
	mutex.lock();worker_thread = OS.get_thread_caller_id();mutex.unlock()
	while true:
		wake.wait()
		mutex.lock();var done := closing;mutex.unlock()
		if done:break
		_plan_session()
		_prune(0,"")
		while true:
			var job := _next()
			if job.is_empty():
				_session_progress();break
			var began := Time.get_ticks_usec();var result := {};var stages := {};var memory := Memory.memory_headroom()
			var reusable := {};var materialized := {};var file: FileAccess
			mutex.lock()
			var prior: Dictionary = prepared.get(source_keys.get(job.get("source_key",""),""),{})
			if prior.get("scope") == job.get("scope"):materialized = prior.get("entry",{})
			var automatic: bool = session.get("automatic",false)
			mutex.unlock()
			if materialized.is_empty():
				file = FileAccess.open(job.path,FileAccess.READ)
				materialized = Reader.materialize(file,job.entry,job.object)
			if materialized.has("error"):result = {"error":materialized.error}
			else:
				var exact := Prepare.charge(materialized,job.channel,job.budget)
				if exact.has("error"):result = {"error":Reader.record_error(job.entry,exact.error)}
				else:job = job.duplicate();job.charge = exact.bytes
			mutex.lock();var fits_limit: bool = job.charge <= limit;mutex.unlock()
			if result.is_empty() and automatic and (not fits_limit or memory.available_physical < memory.reserve+int(job.get("other_reservation",0))+job.charge*3):
				# Capacity pressure is retryable, not corrupt source data. Release
				# cold entries on this worker and leave the displayed scene intact.
				var owned: int = status().resident_bytes
				mutex.lock()
				if token == working_token and wanted.has(job.key) and not closing:
					limit = mini(limit,session_capacity(memory,owned,int(job.get("other_reservation",0)),job.charge))
					retained_limit = mini(retained_limit,limit);session.state = "pressure"
				working_key = ""
				mutex.unlock();_prune(0,"");break
			if not result.is_empty():pass
			elif memory.available_physical < memory.reserve+int(job.get("other_reservation",0))+job.charge*3:
				result = {"error":"Field preparation needs %.1f MiB available RAM including other reservations; %.1f MiB is available. Free RAM or reduce other caches." % [(memory.reserve+int(job.get("other_reservation",0))+job.charge*3)/float(Memory.MIB),memory.available_physical/float(Memory.MIB)]}
			elif Stamp.read(job.path) != job.stamp:result = {"error":"Field source changed; waiting for refresh."}
			else:
				reusable = _take_source(job)
				if not _prune(job.charge,job.key):result = {"capacity":true} if automatic else {"error":"Field frame exceeds the preparation budget."}
				elif not reusable.is_empty():
					materialized = reusable.entry
					result = Prepare.prepare(job.object,reusable.sample,job.channel,job.budget,self)
					stages = result.get("timings",{}).duplicate()
				else:
					if file == null:file = FileAccess.open(job.path,FileAccess.READ)
					mutex.lock()
					if trace_reads and read_keys.size() < 4096:read_keys.append(job.key)
					mutex.unlock()
					var entry := materialized
					materialized = entry
					var decoded := entry if entry.has("error") else Channels.read(file,entry,job.object,self)
					if decoded.has("error"):result = {"error":decoded.error if entry.has("error") else Reader.record_error(job.entry,decoded.error)}
					elif decoded.is_empty():result = decoded
					else:
						stages = decoded.get("timings",{}).duplicate()
						var sample := {"time":job.entry.time,"count":0,"channels":decoded.channels,"components":decoded.components,"shapes":decoded.shapes,"associations":decoded.associations,"statistics":decoded.get("statistics",{}),"geometry":entry.descriptor.geometry,"has_ids":false,"identity_map":null,"source_index":job.entry.index,"sequence":job.entry.sequence,"decoded_bytes":decoded.reserve}
						result = Prepare.prepare(job.object,sample,job.channel,job.budget,self)
						stages.merge(result.get("timings",{}))
			var gate := test_barrier
			if gate != null:
				mutex.lock();at_barrier = true;mutex.unlock();gate.wait();mutex.lock();at_barrier = false;mutex.unlock()
			if not result.is_empty() and not result.has("error") and Stamp.read(job.path) != job.stamp:result = {"error":"Field source changed during preparation."}
			var obsolete := stopped()
			mutex.lock()
			if obsolete or token != working_token or closing:
				cancelled += 1
				# Planning or a rapid channel switch can cancel the replacement
				# after it borrowed source arrays. Return the old, still-invalidated
				# entry to the bounded cache; never publish it as the new channel.
				if not closing and retained_limit > 0 and reusable.has("previous"):
					var previous: Dictionary = reusable.previous
					if not source_keys.has(previous.source_key) and used+int(previous.bytes) <= limit:
						prepared[reusable.previous_key] = previous;order.append(reusable.previous_key);source_keys[previous.source_key] = reusable.previous_key;used += int(previous.bytes)
			elif result.has("capacity"):
				cancelled += 1;session.state = "pressure"
			elif result.has("error"):
				failures[job.key] = result.error
				if session.get("automatic",false):session.failed += 1
				elif session.get("state") == "preparing":session.state = "blocked";session.error = result.error
			elif not result.is_empty() and used+job.charge > limit:
				# A controller may reduce the budget while this job is decoding.
				cancelled += 1
			elif not result.is_empty():
				result.entry = materialized;result.scope = job.get("scope","");result.source_key = job.get("source_key",job.key);source_keys[result.source_key] = job.key
				result.token = working_token;result.bytes = job.charge;prepared[job.key] = result;order.append(job.key);used += job.charge;completed += 1
				if session.get("state") == "preparing":session.ready += 1
			for stage in stages:
				if not pipeline_stages.has(stage):pipeline_stages[stage] = {"count":0,"total_ms":0.0,"max_ms":0.0}
				pipeline_stages[stage].count += 1;pipeline_stages[stage].total_ms += stages[stage]
				pipeline_stages[stage].max_ms = maxf(pipeline_stages[stage].max_ms,stages[stage])
			worker_ms += (Time.get_ticks_usec()-began)/1000.0;working_key = ""
			var failed: bool = not error.is_empty() or session.get("state") == "blocked"
			mutex.unlock();result = {}
			_session_progress()
			if failed:break
	prepared.clear();source_keys.clear();order.clear();mutex.lock();used = 0;retained_limit = 0;mutex.unlock()
