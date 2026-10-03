extends "res://layers/test_scene_playback.gd"
const Memory = preload("res://layers/playback_buffer.gd")
const Policy = preload("res://layers/particle_playback.gd")
func wait_field(view, time: float) -> bool:return await sample(view,time,true)
func gate_ready(worker) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began<10000:
		if worker.status().test_barrier_waiting:return true
		await process_frame
	return false
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-fixture="):out = arg.trim_prefix("--playback-fixture=")
	var view = make_view(out.path_join("zstd.wvz"),true)
	var reference = make_view(out.path_join("zstd.wvz"),false)
	var control := Policy.new()
	var entries: Array = view.generic_reader.samples.particles
	control._budgets(entries,{"trails":false},{"safe_cache_bytes":16*1024*Memory.MIB})
	check(not control.full_preload and control.window_pairs <= 8,"automatic remains bounded rolling even on abundant RAM")
	var cost: Dictionary = Memory.estimate(entries,false)
	control._budgets(entries,{"trails":false},{"safe_cache_bytes":ceili(cost.total*1.25)+cost.largest_pair*2-1})
	check(not control.full_preload,"reduced headroom still uses rolling preparation")
	control._budgets(entries,{"trails":false},{"safe_cache_bytes":0})
	check(not control.full_preload and control.prepared_limit==0,"unavailable safe RAM never enables preload")
	control.policy = "512"
	control._budgets(entries,{"trails":false},{"safe_cache_bytes":16*1024*Memory.MIB})
	check(not control.full_preload and control.prepared_limit+control.decoded_limit==512*Memory.MIB,"manual rolling policy preserved")
	check(Memory.estimate(entries,true).total>cost.total,"trail history included in estimates")
	for time in [0.0,.7,1.25,3.3,4.0,.1]:
		check(await wait_field(view,time),"mixed asynchronous sample commits")
		check(await sample(reference,time,false),"reference sample commits")
		var field = view.scene_layers.views.field
		check(field.data.channels==reference.scene_layers.views.field.data.channels,"field source arrays preserved")
		check(field.probe(Vector3(.5,.5,.5))==reference.scene_layers.views.field.probe(Vector3(.5,.5,.5)),"native source probe matches")
		check(view.committed_sample==reference.committed_sample,"independent clocks and held field metadata unchanged")
	# Shrinking a resident cache must apply without waiting for a decode miss.
	var particle_worker = view.scene_layers.playback.worker
	var original_context: Dictionary = view.scene_layers.playback.context
	var reduced: Dictionary = original_context.duplicate(true)
	reduced.full_preload = false;reduced.decoded_limit = 0
	reduced.prepared_limit = int(particle_worker.status().prepared_bytes)*3/4
	var retained: Array[int] = [int(view.scene_layers.playback.last_target)]
	particle_worker.request(reduced,retained)
	var shrink_started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-shrink_started<10000:
		var status: Dictionary = particle_worker.status()
		if status.decoded_bytes==0 and status.prepared_bytes<=reduced.prepared_limit:break
		await process_frame
	check(particle_worker.status().decoded_bytes==0 and particle_worker.status().prepared_bytes<=reduced.prepared_limit,"resident caches shrink immediately after budget reduction")
	view.scene_layers.playback.set_policy("adaptive")
	check(await wait_field(view,.1),"automatic preparation recovers after cache reduction")
	var fields = view.scene_layers.field_playback
	check(fields.worker.status().worker_thread!=OS.get_thread_caller_id(),"field decode/conversion ran on a real worker")
	check(fields.worker.status().bytes<=fields.cpu_limit,"field CPU LRU bounded")
	check(fields.staged.size()<=1,"one staged texture per visible field")
	# A gated CPU publication must not expose a new field or advance the clock.
	var worker = fields.worker;var gate := Semaphore.new();worker.test_barrier = gate
	view.scene_layers.states.field.channel = "rho";fields.invalidate();view.scene_layers.views.field.key = ""
	var before: Dictionary = view.committed_sample.duplicate(true)
	check(view.scene_layers.seek(3.3),"uncached mixed seek accepted")
	view.scene_layers.playback.pump()
	var waiting := await gate_ready(worker)
	check(waiting,"field worker publication barrier reached")
	check(view.committed_sample==before,"unprepared seek retains committed state")
	check(view.scene_layers.seek(.2),"new seek supersedes pending request")
	worker.test_barrier = null;gate.post()
	check(await wait_field(view,.2) and view.requested_time==.2,"latest request commits after cancellation")
	# Synchronous scientific inspection supersedes pending asynchronous clocks.
	fields.pending_time = 3.3;fields.buffering = true
	check(not view.scene_layers.sample(1.25,false).is_empty(),"synchronous inspection sample succeeds")
	fields.pump()
	check(view.requested_time==1.25 and fields.pending_time==null,"inspection cannot be overwritten by stale field request")
	view.scene_layers.states.field.visible = false
	check(await wait_field(view,2.0),"hidden field does not gate playback")
	check(not view.scene_layers.current.has("field"),"hidden field has no sampled payload")
	view.free();reference.free();await process_frame
	# Field-only physical-time underflow also pauses analysis and Play.
	view = make_view(out.path_join("field.wvz"),true)
	fields = view.scene_layers.field_playback;worker = fields.worker
	check(not view.scene_layers.playback.enabled and fields.enabled,"field-only capture enables independent preparation")
	check(await wait_field(view,0.0),"field-only startup ready")
	gate = Semaphore.new();worker.test_barrier = gate;fields.invalidate()
	view.scene_layers.views.field.key = ""
	before = view.committed_sample.duplicate(true)
	check(view.scene_layers.seek(1.25),"field-only asynchronous seek")
	check(await gate_ready(worker),"field-only barrier reached")
	check(view.scene_layers.is_buffering() and view.play_button.disabled,"field underflow is exposed to UI and analysis")
	view.playing = true;view.scene_layers.tick(.25)
	check(view.committed_sample==before,"underflow freezes committed physical time")
	view.playing = false;worker.test_barrier = null;gate.post()
	check(await wait_field(view,1.25),"field-only pending seek recovers")
	view.physical_rate = -1;view.scene_loop_playback = true
	check(await wait_field(view,.05),"reverse loop start")
	view.playing = true;view.scene_layers.tick(.1)
	var began := Time.get_ticks_msec()
	while fields.buffering and Time.get_ticks_msec()-began<10000:fields.pump();await process_frame
	check(is_equal_approx(view.requested_time,3.95),"reverse field loop preserves physical time")
	view.playing = false
	# GPU preview error leaves native source intact, including reduced previews.
	var bad: Dictionary = view.scene_layers.views.field.data.duplicate(true)
	bad.channels.rho[0] = 1e100
	var prepared := preload("res://layers/field_prepare.gd").prepare(view.generic_reader.objects.field,bad,"rho",32)
	check(prepared.has("error") and bad.channels.rho[0]==1e100,"float32 overflow refuses without changing source")
	# Retain a displayed field if an intentionally tiny budget disables future work.
	fields.cache_cap_bytes = 1;fields.request_signature = ""
	check(not view.scene_layers.sample(view.requested_time,true).has("pending"),"resident field remains usable when future prefetch is refused")
	check(fields.capacity_wait and fields.automatic_jobs.is_empty() and fields.staged.size() <= 1,"automatic refusal stops CPU preparation with bounded GPU staging")
	view.free();await process_frame
	# Source changes during a gated field publication must not publish stale arrays.
	var path := out.path_join("field-live.wvz")
	var original := FileAccess.get_file_as_bytes(out.path_join("field.wvz"))
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_buffer(original);file.close()
	view = make_view(path,true);fields = view.scene_layers.field_playback;worker = fields.worker
	gate = Semaphore.new();worker.test_barrier = gate;fields.invalidate();view.scene_layers.views.field.key = ""
	check(view.scene_layers.seek(3.25),"source-change request accepted")
	check(await gate_ready(worker),"source-change worker reached barrier")
	# Replacement is valid but has a different object table and capture identity.
	file = FileAccess.open(path,FileAccess.WRITE);file.store_buffer(FileAccess.get_file_as_bytes(out.path_join("ids.wvz")));file.close()
	check(not view.scene_layers.refresh(),"source replacement requires reopen")
	check(view.frame_a==null and view.scene_layers.views.field.texture==null,"source replacement releases stale field and clock")
	worker.test_barrier = null;gate.post()
	began = Time.get_ticks_msec()
	while worker.status().active and Time.get_ticks_msec()-began<10000:await process_frame
	check(worker.status().cancelled>0,"obsolete field worker publication cancelled")
	view.free();await process_frame
	Job.write_json(out.path_join("maintenance-results.json"),{"checks":checks,"failures":failures})
	print("PERFORMANCE MAINTENANCE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
