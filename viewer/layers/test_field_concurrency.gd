extends "res://layers/test_field_parallel.gd"
const Controller = preload("res://layers/field_concurrency.gd")
func observations(rates: Dictionary, ahead := 0.0) -> Dictionary:
	return {"rates":rates,"consumer":10.0,"ahead_seconds":ahead,"can_grow":true,"demand":true,"waiting":ahead == 0,"frame_p95_ms":20.0}
func policy_checks() -> void:
	var policy := Controller.new();policy.setup(4,true)
	check(not policy.gate(10,100,false).ready,"Large lead alone does not establish unmeasured throughput")
	var rates := {}
	for second in range(1,11):
		var key := str(policy.active)
		if not rates.has(key):rates[key] = {"samples":0,"seconds":0.0}
		rates[key].samples += [0,5,9,10.8,12][policy.active];rates[key].seconds += 1
		policy.tick(second,observations(rates))
	check(policy.active == 4 and policy.events.size() == 2,"Insufficient producer scales conservatively from two to four")
	check(not policy.gate(10,2,false).ready and policy.gate(10,3.5,false).ready,"Faster producer needs measured startup margin")
	check(not policy.gate(40,20,false).ready and policy.gate(40,0,true).ready,"Slower producer retains admitted-window gate")
	policy.rate = 10;check(not policy.gate(10,7,false).ready and policy.gate(10,8,false).ready,"Near parity needs a larger jitter lead")
	policy.tick(11,observations(rates,35));check(policy.active == 3,"Comfortable lead reduces CPU occupancy")
	policy.tick(12,observations(rates));check(policy.active == 3,"Cooldown prevents immediate up/down oscillation")
	var pressure := observations(rates);pressure.memory_pressure = true
	policy.tick(13,pressure);check(policy.active == 1 and policy.events[-1].reason == "memory_headroom","Physical memory pressure wins over demand")
	policy.tick(15,observations(rates));check(policy.active == 1,"Memory recovery has hysteresis")
	for reason in ["swap","admission_pressure","frame_p95_ms"]:
		policy.setup(4,true);policy.active = 4;policy.changed_at = 0;policy.blocked_until = 0
		var sample := observations(rates);sample[reason] = 100 if reason != "admission_pressure" else true
		policy.tick(30,sample);policy.tick(31,sample)
		check(policy.active < 4,"Backoff signal: "+reason)
	policy = Controller.new();policy.setup(4,false)
	policy.tick(50,pressure);check(policy.active == 4,"Explicit fixed mode retains its diagnostic cap; worker admission still guards RAM")
	policy = Controller.new();policy.setup(1,true)
	for second in range(1,20):policy.tick(second,observations({"1":{"samples":second*2,"seconds":second}}))
	check(policy.active == 1,"Logical CPU cap remains hard")
	policy.setup(4,true);var idle := observations(rates);idle.demand = false
	policy.tick(80,idle);check(policy.active == 2,"Idle does not grow the pool")
	policy = Controller.new();policy.setup(4,true)
	for second in range(1,10):
		var no_growth := observations({"2":{"samples":second*9,"seconds":second}});no_growth.can_grow = false
		policy.tick(second,no_growth)
	check(policy.active == 2,"Scale-up needs additional physical headroom even with unmet demand")
	policy.reset_rates(rates)
	check(policy.rate == 0 and not policy.gate(10,12,false).ready,"Channel generation discards stale fast-producer confidence")
	check(policy.needs_runway(10,1.5,false,false),"Unmeasured producer rebuilds before two policy ticks exhaust the lead")
	policy.rate = 5;policy.measured_seconds = 4
	check(policy.needs_runway(10,3.5,false,false),"Measured deficit predicts exhaustion while several seconds remain")
	check(not policy.needs_runway(10,8,false,false),"A healthy finite runway absorbs a temporary deficit")
	check(not policy.gate(10,3.5,false).ready,"A predictive wait cannot immediately reopen on the same short runway")
	check(policy.gate(10,3.5,true).ready and not policy.needs_runway(10,.2,true,false),"Completed admitted window and recording boundary remain playable")
	policy.rate = 9.8
	check(policy.needs_runway(10,1.5,false,false) and not policy.gate(10,7,false).ready and policy.gate(10,8,false).ready,"Near-parity rebuffering has distinct stop and resume thresholds")
	policy.rate = 12
	check(not policy.needs_runway(10,2,false,false),"Sustained faster production does not repeatedly reopen the latched startup gate")
	check(policy.needs_runway(40,6,false,true),"Speed increase re-evaluates the throughput gate before draining the cache")
func startup_checks(control, view) -> void:
	var status: Dictionary = control.worker.status().duplicate(true)
	status.session.state = "preparing"
	var resident: Dictionary = status.charges.duplicate()
	status.charges.clear()
	for index in range(2):
		var key: String = control._job("field",index,view.scene_layers.field_budget()).key
		status.charges[key] = resident[key]
	control.concurrency.rate = 12;control.concurrency.measured_seconds = 4
	var gate: Dictionary = control.startup_state(status,0)
	check(gate.contiguous_ready and not gate.ready,"Current plus next cannot bypass a measured adaptive runway")
	view.physical_rate = .1;control.concurrency.rate = 1.2
	for index in range(2,5):
		var key: String = control._job("field",index,view.scene_layers.field_budget()).key
		status.charges[key] = resident[key]
	check(control.startup_state(status,0).ready,"Sufficient retained coverage starts a faster producer without unrelated window completion")
	control.concurrency.rate = 1
	check(not control.startup_state(status,0).ready,"Same resident range waits for a larger lead near parity")
	for index in range(5,10):
		var key: String = control._job("field",index,view.scene_layers.field_budget()).key
		status.charges[key] = resident[key]
	check(control.startup_state(status,0).ready,"Near parity releases when retained coverage reaches its runway")
	control.concurrency.rate = .5
	check(not control.startup_state(status,0).ready,"Slower production needs the admitted window despite current/next residency")
	status.session.state = "ready"
	check(control.startup_state(status,0).ready,"Prepared admitted window releases conservative startup")
	control.capacity_wait = true
	check(not control.startup_state(status,0).ready,"Current/next residency cannot override insufficient admission capacity")
	control.capacity_wait = false;view.physical_rate = 1
	control.concurrency.reset_rates(control.worker.status().rates)
func run() -> void:
	policy_checks()
	out = OS.get_cmdline_user_args()[0]
	var reader := Reader.new(false);check(reader.open(out.path_join("session.wvz")),"Synthetic fixture opens")
	var worker := Buffer.new();worker.worker_count = 4;worker.automatic_workers = true;worker.start()
	var gate := Semaphore.new();worker.test_barrier = gate
	worker.request("initial",jobs_for(reader),32*MIB,true)
	check(await barrier(worker),"Initial two-lane batch held before publication")
	check(worker.status().active_jobs == 2,"Auto starts with two lanes")
	var reserve: int = worker.status().retirement_reserve_bytes
	worker.set_concurrency(4);release(worker,gate)
	check(await ready(worker) and worker.status().peak_active == 4,"Scale up applies between real batches")
	accounting(worker)
	worker.cancel(true);gate = Semaphore.new();worker.test_barrier = gate
	worker.request("replacement",jobs_for(reader,"signed"),32*MIB,true)
	check(await barrier(worker) and worker.status().active_jobs == 4,"Four replacements admitted before downscale")
	worker.set_concurrency(1)
	check(worker.status().in_flight_bytes > 0 and worker.status().retirement_reserve_bytes == reserve,"Downscale never releases live or retired-batch reservations")
	release(worker,gate);check(await ready(worker),"Already-admitted work drains normally")
	check(worker.status().active_limit == 1 and worker.status().rates.has("1"),"Subsequent work uses one lane")
	accounting(worker)
	var oracle: Array = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("oracle.json")))
	for index in range(20):
		var frame := worker.get_frame(str(index)+"signed")
		for name in oracle[index]:check(Hash.digest(frame.sample.channels[name].to_byte_array()) == oracle[index][name],"Resizing preserves every source value")
	worker.close();reader.close();check(worker.status().in_flight_bytes == 0 and worker.status().bytes == 0,"Close drains scaled pool")
	var view = make_view(out.path_join("session.wvz"),true)
	var control = view.scene_layers.field_playback
	check(await ready(control.worker),"GPU-wait case has a prepared CPU window")
	startup_checks(control,view)
	control.staged.clear();control.last_upload_frame = Engine.get_process_frames()
	view.playing = true;control.session_waiting = false
	var pending: Dictionary = control.acquire(.1,view.scene_layers.field_budget())
	check(pending.get("pending",false) and not control.session_waiting,"Pending GPU upload does not restart the CPU runway gate")
	view.free();await process_frame
	Job.write_json(out.path_join("concurrency.json"),{"checks":checks,"failures":failures})
	print("FIELD CONCURRENCY: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
