extends "res://layers/test_field_parallel.gd"
func run() -> void:
	var args := OS.get_cmdline_user_args();var reader := Reader.new(false)
	check(reader.open(args[0]),"Production source opens")
	var rows: Array = []
	for count in [1,2,3,4]:
		for operation in ["cancel","close"]:
			var worker := Buffer.new();worker.worker_count = count;worker.start()
			var jobs := jobs_for(reader,"density",range(100,116))
			# 512 MiB preview allowance preserves full 192³ density planes.
			for job in jobs:job.budget = 512*MIB
			worker.request("latency",jobs,2048*MIB,true)
			var began := Time.get_ticks_msec()
			while worker.status().active_jobs < count and Time.get_ticks_msec()-began < 5000:await process_frame
			var before := worker.status();check(before.active_jobs == count,"All lanes active at cancellation")
			var started := Time.get_ticks_usec()
			if operation == "close":worker.close()
			else:
				worker.cancel()
				while worker.status().active and Time.get_ticks_usec()-started < 5000000:await process_frame
			var elapsed := (Time.get_ticks_usec()-started)/1000.0
			var state := worker.status()
			check(not state.active and state.in_flight_bytes == 0,"Obsolete workers drained")
			check(state.completed == before.completed and state.bytes == 0,"No obsolete publication")
			rows.append({"workers":count,"operation":operation,"latency_ms":elapsed,"before":before,"after":state})
			worker.close()
	reader.close();Job.write_json(args[1],{"checks":checks,"failures":failures,"rows":rows})
	print("CANCELLATION: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
