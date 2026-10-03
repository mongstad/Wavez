extends SceneTree
## Production-path particle sizing, residency, coverage, reuse and pressure.
const Buffer = preload("res://layers/playback_buffer.gd")
const Memory = preload("res://layers/playback_memory.gd")
const Reader = preload("res://layers/scene_reader.gd")
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures: Array[String] = []
var observations := {}
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func snapshot(view) -> Dictionary:
	var p = view.scene_layers.playback
	var result: Dictionary = p.profile_report()
	result.estimates = result.estimates.duplicate()
	result.estimates.erase("sample_estimates");result.estimates.erase("pair_estimates")
	view.timeline.refresh(view,true);view.shell.status_ui.refresh()
	result.coverage = view.timeline.coverage.duplicate(true)
	result.tooltip = view.shell.status_ui.readiness_detail
	result.readiness = view.shell.status_ui.readiness
	result.physical = Memory.snapshot()
	return result
func fill(view, full := true, timeout_ms := 180000) -> bool:
	var p = view.scene_layers.playback
	var began := Time.get_ticks_msec();var last_log := began
	while Time.get_ticks_msec()-began < timeout_ms:
		view.scene_layers.tick(0)
		var status: Dictionary = p.worker.status()
		if full and status.prepared_pairs == p.context.get("entries",[]).size() and p.sized:return true
		if not full and p.sized and not status.worker_active and status.prepared_bytes <= p.prepared_limit and status.decoded_bytes <= p.decoded_limit and status.desired.all(func(index):return status.ready_indices.has(index)):return true
		if not status.failures.is_empty() or not status.error.is_empty():return false
		if Time.get_ticks_msec()-last_log > 10000:
			print("PARTICLE CACHE progress: ",status.prepared_pairs," resident; ",status.prepared_bytes," prepared bytes")
			last_log = Time.get_ticks_msec()
		await process_frame
	return false
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var view = load("res://main.gd").new()
	view.capture_path = args[0];view.orbit_enabled = false
	var source_stamp := Buffer.Stamp.read(args[0])
	root.add_child(view);view.set_process(false);view.set_process_input(false);view.set_process_unhandled_input(false)
	var p = view.scene_layers.playback
	var reader = view.scene_layers.reader
	var rows: Array = reader.samples[view.scene_layers.particle_id]
	var initial_time: float = rows[0].time
	check(not view.playing and view.requested_time == initial_time,"opens paused at first time")
	check(not view.committed_sample.is_empty() and not view.play_button.disabled,"initial scene usable before full cache")
	observations.initial = snapshot(view)
	var began := Time.get_ticks_msec()
	var partial_gate := Semaphore.new()
	p.worker.test_barrier = partial_gate
	view.manual_max += .001;p.begin(initial_time,1)
	# Capture a genuine partial publication; no estimated progress is accepted.
	while Time.get_ticks_msec()-began < 10000:
		var state: Dictionary = p.worker.status()
		if state.get("test_barrier_waiting",false):
			if state.prepared_pairs > 0:break
			partial_gate.post()
		view.scene_layers.tick(0);await process_frame
	observations.partial = snapshot(view)
	p.worker.test_barrier = null;partial_gate.post()
	var partial: Dictionary = observations.partial
	check(partial.cache.prepared_pairs > 0 and partial.cache.prepared_pairs < rows.size(),"partial preparation is observable")
	check(partial.tooltip.contains("%d / %d" % [partial.cache.prepared_pairs,rows.size()]) and not partial.tooltip.contains("Full scene prepared."),"partial tooltip distinguishes current renderability from completion")
	check(partial.tooltip.contains("%.1f MiB decoded" % (partial.cache.decoded_bytes/float(Buffer.MIB))),"partial tooltip uses authoritative decoded charge")
	check(await fill(view),"automatic cache prepares full capture when safe")
	observations.fill_seconds = (Time.get_ticks_msec()-began)/1000.0
	observations.full = snapshot(view)
	var full: Dictionary = observations.full
	check(p.full_preload and full.cache.prepared_pairs == rows.size(),"all admitted intervals actually resident")
	check(full.coverage.scene == [[float(rows[0].time),float(rows[-1].time)]],"timeline matches complete resident coverage")
	check(full.tooltip.contains("Full scene prepared.") and full.tooltip.contains("%d / %d" % [rows.size(),rows.size()]),"complete tooltip follows resident cache")
	check(full.readiness == "Ready" and not view.playing and view.requested_time == initial_time,"Ready remains renderability and paused clock stays fixed")
	check(full.cache.prepared_bytes <= p.prepared_limit and full.cache.decoded_bytes <= p.decoded_limit,"separate cache charges stay within admitted budgets")
	check(full.physical.process_swap == 0,"viewer cache does not use swap")
	var pair: Dictionary = p.worker.get_pair(0,false)
	var file := FileAccess.open(args[0],FileAccess.READ)
	var first := Reader.materialize(file,rows[0],reader.objects[view.scene_layers.particle_id])
	observations.layout = first.descriptor
	observations.actual = {"sample_bytes":pair.a.decoded_bytes,"pair_bytes":pair.bytes,"particles":pair.a.count,"samples":rows.size(),"file_bytes":file.get_length()}
	check(Buffer.sample_estimate(first).bytes == pair.a.decoded_bytes,"descriptor estimate matches authoritative decoded charge")
	check(p.estimates.pair_estimates[0] >= pair.bytes,"descriptor pair estimate bounds actual prepared charge")
	# Whole-file cache must survive scrubs in both directions without any decode.
	var misses: int = full.cache.decoded_misses;var completed: int = full.cache.completed
	for index in [rows.size()/2,rows.size()-1,1,0]:
		check(view._seek_time(float(rows[index].time)),"resident seek accepted "+str(index))
		view.scene_layers.tick(0)
		check(is_equal_approx(view.requested_time,float(rows[index].time)) and not view.scene_layers.is_buffering(),"resident seek commits immediately "+str(index))
	check(p.worker.status().decoded_misses == misses and p.worker.status().completed == completed,"scrubbing reuses resident pairs without redecoding")
	view.play_button.pressed.emit();view.scene_layers.tick(.1)
	check(view.playing and view.requested_time > initial_time,"Play uses prepared coverage immediately")
	view.play_button.pressed.emit()
	check(p.worker.status().decoded_misses == misses,"playback reuses prepared source arrays")
	pair = {} # Do not retain an extra test-only cache reference during pressure.
	# Feed realistic physical-memory snapshots through the production controller
	# and per-job guard. This does not allocate competing system RAM.
	var pressure := Memory.snapshot()
	pressure.safe_cache_bytes = 512*Buffer.MIB+int(full.estimates.total*.18)+int(full.estimates.largest_pair)*2
	pressure.available_physical = int(pressure.reserve)+int(pressure.safe_cache_bytes)
	p.memory_override = pressure;p.budget_checked = -1000;p.direction = 1
	view._seek_time(initial_time)
	check(await fill(view,false),"reduced headroom settles a bounded interval")
	observations.pressure = snapshot(view)
	var bounded: Dictionary = observations.pressure
	check(not p.full_preload and bounded.cache.prepared_pairs < rows.size() and bounded.cache.prepared_pairs > 1,"pressure reduces residency")
	check(bounded.cache.prepared_bytes <= p.prepared_limit and bounded.cache.decoded_bytes <= p.decoded_limit,"pressure trims both resident caches while paused")
	check(bounded.cache.prepared_evictions > 0,"pressure performs real cache eviction")
	var expected: Array = []
	var ready := {}
	for index in bounded.cache.ready_indices:ready[index] = true
	var timeline = preload("res://ui/shell/prepared_timeline.gd")
	expected = timeline.intersect([[float(rows[0].time),float(rows[-1].time)]],timeline.spans(rows,ready,float(rows[0].time),float(rows[-1].time)))
	check(bounded.coverage.scene == expected,"timeline follows actual eviction")
	check(not bounded.tooltip.contains("Full scene prepared."),"pressure tooltip stops claiming complete cache")
	# Even a budget below one pair must reclaim idle history and remain
	# retryable on subsequent ticks, retaining only the protected display pair(s).
	var minimal := pressure.duplicate();minimal.safe_cache_bytes = 0
	p.memory_override = minimal;p.budget_checked = -1000
	var shrink_started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-shrink_started < 5000:
		view.scene_layers.tick(0);await process_frame
		if p.worker.status().decoded_bytes == 0 and p.worker.status().prepared_pairs <= 2:break
	check(p.worker.status().decoded_bytes == 0 and p.worker.status().prepared_pairs <= 2,"sub-pair pressure reclaims unpinned idle cache")
	check(not view.committed_sample.is_empty(),"sub-pair pressure retains committed display")
	p.memory_override = pressure;p.budget_checked = -1000
	check(await fill(view,false),"bounded caching recovers from sub-pair pressure")
	# A changed style guarantees a decode/preparation miss at the live RAM guard.
	var exhausted := Memory.snapshot();exhausted.available_physical = exhausted.reserve
	p.worker.memory_override = exhausted
	view.manual_max += .125;p.budget_checked = -1000
	p.begin(initial_time,1)
	began = Time.get_ticks_msec()
	while not p.worker.status().get("pressure",false) and Time.get_ticks_msec()-began < 5000:
		await process_frame
	check(p.worker.status().get("pressure",false),"per-job physical RAM guard stops unsafe allocation")
	view.shell.status_ui.refresh()
	check(view.shell.status_ui.readiness_detail.contains("physical RAM headroom"),"tooltip exposes the live pressure stop")
	p.worker.memory_override = {};p.memory_override = {};p.budget_checked = -1000
	check(await fill(view),"automatic full preparation recovers after pressure is released")
	observations.recovered = snapshot(view)
	check(Buffer.Stamp.read(args[0]) == source_stamp,"source identity unchanged")
	if DisplayServer.get_name() != "headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1].get_basename()+".png")
	Job.write_json(args[1],{"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"packaged":not OS.has_feature("editor"),"observations":observations})
	view.free();await process_frame
	print("PARTICLE CACHE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
