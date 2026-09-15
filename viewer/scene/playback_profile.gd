extends RefCounted
# Opt-in instrumentation. No per-particle timers and no writes during measurement.
static var enabled := false
static var rows: Dictionary = {}
static var counters: Dictionary = {}
# Bounded, opt-in callback trace. Flush only after a measurement case finishes.
static var trace_enabled := false
static var trace_capacity := 32768
static var trace_rows: Array = []
static var trace_dropped := 0
static var trace_context: Dictionary = {}
static func begin() -> int: return Time.get_ticks_usec() if enabled else 0
static func end(name: String, since: int, details: Dictionary = {}) -> void:
	if not enabled or since == 0: return
	var finished := Time.get_ticks_usec()
	observe(name,(finished-since)/1000.0)
	if trace_enabled:
		if trace_rows.size() >= trace_capacity:
			trace_dropped += 1
		else:
			trace_rows.append({"name":name,"start_us":since,"end_us":finished,"duration_ms":(finished-since)/1000.0,"context":trace_context.duplicate(),"details":details.duplicate()})
static func observe(name: String, milliseconds: float) -> void:
	if not enabled: return
	if not rows.has(name): rows[name] = {"count":0,"total_ms":0.0,"max_ms":0.0,"samples":[]}
	var row: Dictionary = rows[name]
	row.count += 1; row.total_ms += milliseconds; row.max_ms = maxf(row.max_ms,milliseconds)
	if row.samples.size() < 8192: row.samples.append(milliseconds)
static func count(name: String, amount: int = 1) -> void:
	if enabled: counters[name] = counters.get(name,0)+amount
static func reset() -> void:
	rows.clear(); counters.clear()
	trace_rows.clear(); trace_dropped = 0; trace_context.clear()
static func report() -> Dictionary:
	var result := {}
	for name in rows:
		var row: Dictionary = rows[name].duplicate(true)
		var samples: Array = row.samples
		samples.sort(); row.erase("samples")
		row.samples_collected = samples.size()
		row.mean_ms = row.total_ms/row.count
		row.p50_ms = samples[samples.size()/2]
		row.p95_ms = samples[mini(samples.size()-1,ceili(samples.size()*.95)-1)]
		result[name] = row
	var output := {"stages":result,"counters":counters.duplicate(true)}
	if trace_enabled:
		output.trace = {"clock":"Time.get_ticks_usec monotonic microseconds; same clock as callback rows","capacity":trace_capacity,"dropped":trace_dropped,"events":trace_rows.duplicate(true)}
	return output
