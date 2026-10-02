extends Node
# RAM admission, real high-resolution playback, pressure and worker lifecycle.
const Viewer = preload("res://main.gd")
const Policy = preload("res://layers/mesh_playback.gd")
const Memory = preload("res://layers/playback_buffer.gd")
const Hash = preload("res://data/capture_index.gd")
const Job = preload("res://video/render_job.gd")
class ConstrainedWorker extends "res://layers/mesh_buffer.gd":
	var pressure := true
	var available_above_reserve := -1
	func _memory_headroom() -> Dictionary:
		var memory := super._memory_headroom()
		if pressure:memory.available_physical = memory.reserve
		elif available_above_reserve >= 0:memory.available_physical = memory.reserve+available_above_reserve
		return memory
var checks := 0
var failures: Array[String] = []
var report := {}
var config := {}
var callback_ms: Array[float] = []
var memory_samples: Array = []
@onready var root: Window = get_tree().root
func _ready() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func policy_checks() -> void:
	var charge := 205*Memory.MIB
	var large := Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":20*1024*Memory.MIB},256*Memory.MIB)
	var medium := Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":3*1024*Memory.MIB},256*Memory.MIB)
	var small := Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":1024*Memory.MIB},256*Memory.MIB)
	check(large.cpu_limit == 5*charge and medium.cpu_limit == (2816*Memory.MIB)/5,"Physical headroom scales cache until the five-pair workload ceiling")
	check(large.cpu_limit > medium.cpu_limit and medium.cpu_limit > small.cpu_limit,"Lower RAM monotonically lowers admission")
	check(small.cpu_limit == (768*Memory.MIB)/5 and small.cpu_limit < small.required_bytes,"Low-memory current/staged pair refused deterministically")
	check(large.required_bytes == charge*2,"Current/staged headroom explicit")
	check(large.cpu_limit*5 <= large.remaining_safe_bytes,"Both caches, working shares and unused fifth share preserved")
	check(Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":0},0).cpu_limit == 0,"Unknown physical headroom refuses")
	check(Policy.preparation_budget(charge,5*charge,{"safe_cache_bytes":1024*Memory.MIB},2*1024*Memory.MIB).cpu_limit == 0,"Other reservations cannot overcommit")
	check(Policy.preparation_budget(0,0,{"safe_cache_bytes":20*1024*Memory.MIB},0).cpu_limit == 0,"Hidden meshes reserve no cache")
	var multiple := Policy.preparation_budget(2*charge,10*charge,{"safe_cache_bytes":20*1024*Memory.MIB},0)
	check(multiple.required_bytes == 4*charge and multiple.cpu_limit == 10*charge,"Multiple visible mesh charges aggregate")
	report.policy = {"large":large,"medium":medium,"small":small,"multiple":multiple}
func make_view(path: String):
	var view = Viewer.new();view.capture_path = path;view.playing = false;view.orbit_enabled = false
	root.add_child(view);view.set_process(false);view._set_clean(true)
	return view
func sample(view, time: float) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 30000:
		var start := Time.get_ticks_usec()
		var result: Dictionary = view.scene_layers.sample(time,true)
		callback_ms.append((Time.get_ticks_usec()-start)/1000.0)
		if result.is_empty():return false
		if not result.has("pending"):return true
		await get_tree().process_frame
	return false
func idle(worker) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 30000:
		var status: Dictionary = worker.status()
		if not status.active and (status.ready_keys.size() == status.requested_jobs and status.requested_jobs > 0 or not status.failures.is_empty() or (status.requested_jobs == 0 and status.frames == 0 and status.decoded_samples == 0)):return true
		await get_tree().process_frame
	return false
func barrier(worker) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 30000:
		if worker.status().test_barrier_waiting:return true
		await get_tree().process_frame
	return false
func invariant(control) -> void:
	var status: Dictionary = control.worker.status()
	check(status.bytes <= status.limit,"Mesh CPU cache stays within admitted allowance")
	check(status.decoded_bytes <= status.decoded_limit and status.decoded_samples <= status.requested_jobs*2,"Endpoint cache stays within its byte and demand bounds")
	check(status.active_jobs <= status.worker_count and status.worker_count <= 4,"CPU pool stays bounded")
	check(status.requested_jobs <= 5 and status.frames <= 5,"No timeline-length prefetch or decoded retention")
	check(control.staged.size() <= 1,"One future GPU stage")
	check(status.in_flight_bytes <= status.peak_in_flight_bytes,"Pool in-flight charge explicit")
	memory_samples.append(Memory.memory_headroom())
func screenshot(view, name: String) -> void:
	if DisplayServer.get_name() == "headless":return
	view._process(0);view._focus_activity();view.shell.refresh()
	for i in 8:await get_tree().process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(config.output.path_join(name+".png"))
func worker_checks(control, target: Dictionary) -> void:
	var constrained := ConstrainedWorker.new();constrained.start()
	constrained.request("pressure",[target],target.charge*2)
	check(await idle(constrained),"Worker physical-pressure refusal finishes")
	check(constrained.status().bytes == 0 and constrained.status().pressure_failures == 1,"Live admission blocks before decoding under physical pressure")
	check(str(constrained.status().failures.get(target.key,"")).contains("CPU preparation"),"Worker reports CPU RAM failure")
	constrained.pressure = false;constrained.request("pressure",[target],target.charge*2)
	check(await idle(constrained) and constrained.status().completed == 1,"Transient pressure recovers with unchanged source/settings")
	constrained.close()
	var worker = control.Buffer.new();var gate := Semaphore.new();worker.test_barrier = gate;worker.start()
	worker.request("shrink",[target],target.charge*2)
	check(await barrier(worker),"In-flight high-resolution work reaches publication barrier")
	check(worker.status().in_flight_bytes == target.charge,"Working charge remains reserved before publication")
	worker.request("shrink",[target],0);worker.test_barrier = null;gate.post()
	check(await idle(worker),"Shrinking an in-flight budget drains safely")
	check(worker.status().bytes == 0 and worker.status().cancelled > 0,"No oversized publication after budget reduction")
	worker.close()
	worker = control.Buffer.new();worker.start();worker.request("close",[target],target.charge*2)
	var began := Time.get_ticks_msec()
	while not worker.status().active and Time.get_ticks_msec()-began < 1000:await get_tree().process_frame
	var active: bool = worker.status().active
	began = Time.get_ticks_msec();worker.close()
	report.close_ms = Time.get_ticks_msec()-began
	check(active and report.close_ms < 2000,"Close joins active high-resolution preparation within two seconds")
	check(worker.status().bytes == 0 and worker.status().in_flight_bytes == 0,"Close releases CPU preparation ownership")
func pool_checks(control, id: String) -> void:
	var worker = control.Buffer.new();worker.worker_count = 4;worker.start()
	var jobs: Array = [];var allowance := 0
	for index in range(100,105):
		var job: Dictionary = control._job(id,index,256*Memory.MIB)
		jobs.append(job);allowance += int(job.charge)
	worker.request("fixed",jobs,allowance)
	check(await idle(worker),"Four-lane rolling window finishes")
	var fixed: Dictionary = worker.status(true)
	check(fixed.decoded == 6 and fixed.frames == 5,"Five adjacent pairs decode exactly six endpoints")
	check(fixed.peak_active > 1 and fixed.peak_active <= 4,"Independent CPU lanes overlap within their bound")
	check(fixed.topology_reuses >= 2,"Later endpoints reuse only matching validated topology")
	check(fixed.bytes+fixed.in_flight_bytes <= allowance and fixed.decoded_bytes <= allowance,"Pair and endpoint cache shares stay bounded")
	var selected: Array = []
	for original in jobs:
		var job: Dictionary = original.duplicate(true);job.state.channel = "radius";job.key += "/radius";selected.append(job)
	worker.request("radius",selected,allowance)
	check(await idle(worker),"Channel change rebuilds prepared pairs")
	var scalar: Dictionary = worker.status(true)
	check(scalar.decoded == fixed.decoded and scalar.completed == 10,"Channel change reuses decoded geometry without stale colors")
	var frame: Dictionary = worker.get_frame(selected[0].key)
	check(frame.has("arrays"),"Scalar pair contains display arrays")
	if not frame.has("arrays"):worker.close();return
	var colors: PackedColorArray = frame.arrays[Mesh.ARRAY_COLOR]
	var expected := PackedColorArray()
	for value in frame.a.channels.radius:expected.append(preload("res://layers/mesh_prepare.gd").scalar_color(value,selected[0].state,selected[0].colors))
	check(colors == expected,"Packed scalar palette exactly matches the scalar-color reference")
	var recolored: Array = []
	for original in selected:
		var job: Dictionary = original.duplicate(true);job.state.colormap = "plasma"
		job.colors = control.viewer.colormaps.plasma;job.key += "/plasma";recolored.append(job)
	worker.request("plasma",recolored,allowance)
	check(await idle(worker),"Colormap change rebuilds prepared colors")
	check(worker.status().decoded == 6,"Colormap change retains validated endpoints")
	var recolored_frame: Dictionary = worker.get_frame(recolored[0].key)
	check(recolored_frame.has("arrays"),"Recolored pair contains display arrays")
	if not recolored_frame.has("arrays"):worker.close();return
	expected = PackedColorArray()
	for value in recolored_frame.a.channels.radius:expected.append(preload("res://layers/mesh_prepare.gd").scalar_color(value,recolored[0].state,recolored[0].colors))
	check(recolored_frame.arrays[Mesh.ARRAY_COLOR] == expected and expected != colors,"New palette matches reference and replaces prior colors")
	var gate := Semaphore.new();worker.test_barrier = gate
	worker.request("pending",jobs,allowance)
	check(await barrier(worker),"Generation change begins with multiple old tasks pending")
	var fresh: Array = []
	for original in jobs:
		var job: Dictionary = original.duplicate(true);job.generation += 1;fresh.append(job)
	worker.request("new-generation",fresh,allowance);worker.test_barrier = null;gate.post()
	check(await idle(worker),"Replacement generation drains and finishes")
	var renewed: Dictionary = worker.status(true)
	check(renewed.decoded == 12 and renewed.cancelled > 0,"New source generation invalidates endpoint reuse and old publication")
	check(worker.get_frame(jobs[0].key).token == "new-generation","Only current-generation pair becomes visible")
	worker.cancel()
	check(await idle(worker),"Pool cancellation drains")
	check(worker.status().bytes == 0 and worker.status().decoded_bytes == 0,"Cancellation releases both cache shares")
	worker.close()
	check(worker.threads.is_empty() and worker.status().in_flight_bytes == 0,"Close joins every CPU lane")
	var limited := ConstrainedWorker.new();limited.pressure = false;limited.worker_count = 4
	limited.available_above_reserve = allowance+jobs[0].charge*3;limited.start()
	limited.request("one-memory-lane",jobs,allowance)
	check(await idle(limited),"RAM-constrained pool still makes progress")
	check(limited.status().active_limit == 1 and limited.status().peak_active == 1,"RAM headroom contracts four configured lanes to one")
	limited.close()
	report.pool = {"fixed":fixed,"radius":scalar,"new_generation":renewed}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mesh-budget-job="):config = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--mesh-budget-job=")))
	if config.is_empty():queue_free();return
	get_tree().create_timer(300).timeout.connect(func():push_error("Mesh budget validation timeout");get_tree().quit(1))
	OS.low_processor_usage_mode = false
	policy_checks()
	var view = make_view(config.capture)
	var control = view.scene_layers.mesh_playback
	var id: String = config.object_id
	var entries: Array = view.generic_reader.samples[id]
	var targets: Array = control.request(entries[0].time,view.scene_layers.mesh_budget())
	report.opening = control.profile_report();report.capture_samples = entries.size()
	check(entries.size() == 2401,"Acceptance capture contains 2401 recorded mesh samples")
	check(targets[0].charge*2 > 128*Memory.MIB,"Acceptance workload exceeds old 128 MiB policy")
	check(control.cpu_limit >= targets[0].charge*2 and control.error.is_empty(),"High-memory host admits current/staged high-resolution pair")
	check(await sample(view,entries[0].time),"Real high-resolution capture opens and prepares")
	check(view.scene_layers.current[id].a.count == 256*256,"256 by 256 source vertices preserved")
	check(view.scene_layers.views[id].mesh != null,"High-resolution mesh has a visible GPU surface")
	check(await idle(control.worker),"Bounded initial prefetch finishes")
	invariant(control);report.prepared = control.profile_report()
	await screenshot(view,"cavity-ready")
	if DisplayServer.get_name() != "headless":
		view.tools_ui.open("Performance");await screenshot(view,"mesh-cpu-budget");view.tools_ui.close()
	var before: int = control.worker.status().completed
	for i in 8:check(await sample(view,entries[0].time),"Repeated current sample reuses preparation")
	check(control.worker.status().completed == before,"Repeated current requests do not decode redundant pairs")
	for item in config.oracle:
		var index := int(item.index);var time := float(entries[index].time)
		check(await sample(view,time),"Seek to recorded source sample "+str(index))
		var data: Dictionary = view.scene_layers.current[id].a
		for channel in item.channels:
			check(Hash.digest(data.channels[channel].to_byte_array()) == item.channels[channel],"Exact independently decoded source channel "+channel+" at "+str(index))
		invariant(control)
	# Exercise committed-clock playback in each direction across multiple pairs.
	for direction in [1,-1]:
		view.physical_rate = direction
		check(await sample(view,entries[12 if direction == 1 else 28].time),"Playback starting sample")
		var started: float = view.requested_time
		for i in 12:
			var tick_start := Time.get_ticks_usec()
			view.playing = true;view.scene_layers.tick(.11);view.playing = false
			callback_ms.append((Time.get_ticks_usec()-tick_start)/1000.0)
			if control.pending_time != null:check(await sample(view,float(control.pending_time)),"Playback transition prepares requested pair")
			await get_tree().process_frame
		check((view.requested_time-started)*direction > .5,"Forward/reverse playback advances the committed clock")
		invariant(control)
	# Rapid seeks supersede pending work without queuing a timeline.
	var scrub_started := Time.get_ticks_usec()
	for index in [100,2000,4,1800,1200]:check(view.scene_layers.seek(entries[index].time),"Scrub target accepted")
	check(await sample(view,entries[1200].time),"Latest scrub target commits")
	report.scrub_ms = (Time.get_ticks_usec()-scrub_started)/1000.0
	check(view.scene_layers.current[id].a.source_index == 1200,"Latest source sample wins")
	report.channel_switch_ms = {}
	for channel in ["radius","z_height","twist_phase",""]:
		view.scene_layers.states[id].channel = channel
		var channel_started := Time.get_ticks_usec()
		check(await sample(view,entries[1200].time),"Channel switch commits "+channel)
		report.channel_switch_ms[channel if not channel.is_empty() else "fixed"] = (Time.get_ticks_usec()-channel_started)/1000.0
	# Dispatch through the production viewport while an uncached seek occupies lanes.
	view.scene_layers.seek(entries[2200].time)
	var camera_before: float = view.camera_distance
	var input_started := Time.get_ticks_usec()
	var wheel := InputEventMouseButton.new();wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true;wheel.position = Vector2(600,400);root.push_input(wheel,true)
	report.input_dispatch_ms = (Time.get_ticks_usec()-input_started)/1000.0
	check(is_equal_approx(view.camera_distance,camera_before*.9),"Camera input remains responsive during uncached mesh preparation")
	check(await sample(view,entries[2200].time),"Preparation completes after camera input")
	view.scene_layers.states[id].visible = false
	check(await sample(view,entries[1500].time),"Hidden mesh playback needs no payload")
	check(await idle(control.worker) and control.worker.status().bytes == 0 and control.cpu_limit == 0,"Hide releases CPU cache and reservation")
	view.scene_layers.states[id].visible = true
	check(await sample(view,entries[1500].time),"Reveal prepares correct mesh")
	# CPU refusal keeps the committed scientific state, cancels work and releases staging.
	var committed: Dictionary = view.committed_sample.duplicate(true)
	control.budget_memory_override = {"safe_cache_bytes":0,"available_physical":0,"reserve":0};control.budget_checked = -1000
	check(view.scene_layers.sample(entries[1700].time,true).has("pending"),"Low-memory uncached seek is refused safely")
	check(control.error.contains("CPU preparation") and control.error.contains("Free RAM") and not control.error.contains("reduce the preview"),"CPU diagnostic is actionable and distinct from GPU quota")
	check(view.committed_sample == committed,"Pressure cannot advance the scientific clock")
	check(await idle(control.worker) and control.worker.status().bytes == 0 and control.staged.is_empty(),"Pressure releases future CPU/GPU preparation")
	check(not view.playing and control.label.text.begins_with("Mesh CPU preparation blocked"),"Pressure is surfaced as blocked, never prefetch ready")
	control.budget_memory_override.clear();control.budget_checked = -1000
	check(await sample(view,entries[1700].time),"Freeing RAM recovers admission without reopening source")
	var gpu_limit: int = view.scene_layers.gpu_budget_mib
	view.scene_layers.gpu_budget_mib = 0
	check(await sample(view,entries[1700].time),"GPU refusal still commits valid scientific data")
	check(view.scene_layers.views[id].mesh == null and view.scene_layers.views[id].error.contains("GPU budget"),"GPU quota remains a separate preview refusal")
	check(not view.scene_layers.current[id].a.channels.position.is_empty(),"GPU refusal preserves decoded source positions")
	view.scene_layers.gpu_budget_mib = gpu_limit
	check(await sample(view,entries[1700].time),"Restoring GPU quota restores preview")
	if DisplayServer.get_name() != "headless":
		view._toggle_fullscreen()
		for i in 12:await get_tree().process_frame
		check(await sample(view,entries[1800].time),"Fullscreen prepares and plays high-resolution mesh")
		check(view.shell.immersive,"Production fullscreen route entered")
		await screenshot(view,"cavity-fullscreen")
		view._toggle_fullscreen()
		for i in 12:await get_tree().process_frame
		check(await sample(view,entries[1801].time) and not view.shell.immersive,"Windowed playback restored")
	await worker_checks(control,targets[0])
	await pool_checks(control,id)
	invariant(control);report.final = control.profile_report()
	view.free();await get_tree().process_frame
	# Field admission consumes the actual mesh reservation, with both workers active.
	view = make_view(config.mixed)
	check(await sample(view,.7),"Mixed particle/field/mesh playback remains usable")
	control = view.scene_layers.mesh_playback
	var fields = view.scene_layers.field_playback
	check(control.reservation_bytes() > 256*Memory.MIB and fields.other_reservations().mesh_cache_and_working == control.reservation_bytes(),"Field cache honors adaptive mesh allocation")
	check(control.reservation_bytes() == control.cpu_limit*4,"Mesh reservation includes both caches and two working shares")
	check(fields.worker.status().bytes <= fields.worker.status().limit,"Field cache remains bounded")
	var particles = view.scene_layers.playback
	check(particles.worker.status().prepared_bytes <= particles.prepared_limit and particles.worker.status().decoded_bytes <= particles.decoded_limit,"Particle caches remain bounded")
	view.free();await get_tree().process_frame
	callback_ms.sort()
	report.callbacks = {"count":callback_ms.size(),"p95_ms":callback_ms[int(callback_ms.size()*.95)],"p99_ms":callback_ms[int(callback_ms.size()*.99)],"max_ms":callback_ms[-1],"over_50_ms":callback_ms.filter(func(ms):return ms >= 50).size()}
	report.memory_samples = memory_samples
	check(memory_samples.all(func(memory):return int(memory.process_swap) == 0),"Viewer uses no swap during accepted workload")
	report.application_version = ProjectSettings.get_setting("application/config/version")
	check(report.application_version == config.application_version,"Runtime uses authoritative candidate application identity")
	report.checks = checks;report.failures = failures;report.packaged = not OS.has_feature("editor");report.renderer = RenderingServer.get_current_rendering_method()
	Job.write_json(config.output.path_join("report.json"),report)
	print("MESH BUDGET: ",checks," checks, ",failures.size()," failures; ",report.callbacks)
	get_tree().quit(0 if failures.is_empty() else 1)
