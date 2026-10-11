extends RefCounted
const Buffer = preload("res://layers/playback_buffer.gd")
const Profile = preload("res://scene/playback_profile.gd")
var layers
var viewer
var worker = Buffer.new()
var enabled := false
var buffering := false
var pending_time = null
var minimum := 1
var window_pairs := 8
var direction := 1
var last_target := -1
var source_generation := -1
var context := {}
var config_signature := ""
var policy := "adaptive" # Existing key now selects automatically.
var budget_target := -1
var budget_checked := -1000
var sizing_key := ""
var sized := false
var field_priority := false
var memory_override := {} # Deterministic physical-pressure regression only.
var memory_budget := {}
var decoded_limit := 0
var prepared_limit := 0
var full_preload := false
var budget_message := ""
var estimates := {}
var label: Label
var mode: OptionButton
var readiness_error := ""
var wait_reason := "Required particle content"
var last_ui := ""
var active_pair := {}
var hidden := false
var worker_events: Array = []
var worker_event_drops := 0

func setup(owner) -> void:
	layers = owner;viewer = owner.viewer
	enabled = viewer.scene_prebuffer_enabled and not viewer.offline_instance and layers.reader.trusted and not layers.particle_id.is_empty()
	if enabled and worker.start() != OK:enabled = false
func close() -> void:
	if is_instance_valid(viewer) and is_instance_valid(viewer.play_button):viewer.play_button.disabled = false
	worker.close();active_pair = {};worker_events.clear()
func build_ui(parent: Control) -> void:
	if not enabled:return
	var title := Label.new();title.text = "Particle playback buffer";parent.add_child(title)
	mode = OptionButton.new();parent.add_child(mode)
	for name in ["Automatic (safe RAM)","512 MiB RAM","2 GiB RAM","8 GiB RAM","16 GiB RAM"]:mode.add_item(name)
	mode.selected = ["adaptive","512","2048","8192","16384"].find(policy)
	mode.item_selected.connect(func(index: int):set_policy(["adaptive","512","2048","8192","16384"][index]))
	mode.tooltip_text = "Automatically prepare particle scenes to safe RAM capacity. Scenes with fields retain a rolling particle window to prioritize field preparation. Manual RAM choices keep a rolling cache. GPU resources remain limited to current particles and visible trails."
	if viewer.shell == null: viewer._check(parent,"Loop recorded interval",viewer.scene_loop_playback,set_loop)
	label = Label.new();label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label)
func set_loop(value: bool) -> void:
	viewer.scene_loop_playback = value;last_target = -1;worker.cancel()
func settings() -> Dictionary:
	return {"color_channel":viewer.color_channel,"size_channel":viewer.size_channel,"brightness_channel":viewer.brightness_channel,"normalization":viewer._effective_normalization(),"manual_min":viewer.manual_min,"manual_max":viewer.manual_max,"logarithmic":viewer.logarithmic,"clamp_map":viewer.clamp_map,"cyclic":viewer.cyclic,"invert_map":viewer.invert_map,"hidden_types":viewer.hidden_types.duplicate(),"trails":viewer.trails_enabled and not viewer.clean_view}
func set_policy(value: String) -> void:
	policy = "adaptive" if value == "full" else value;budget_target = -1;config_signature = "";last_target = -1
	if enabled:begin(viewer.requested_time,1)
func _budgets(entries: Array, config: Dictionary, memory: Dictionary = {}, target := 0, plan: Dictionary = {}) -> void:
	window_pairs = 8
	field_priority = layers != null and layers.field_playback != null and layers.field_playback.enabled
	memory_budget = Buffer.memory_headroom() if memory.is_empty() else memory
	var current := Buffer.estimate(entries.slice(maxi(0,target-5) if config.trails else target,mini(entries.size(),target+2)),config.trails)
	estimates = current if plan.is_empty() else plan
	var other: int = layers.reader.cache.limit+256*Buffer.MIB if layers != null else 0
	if layers != null:
		if layers.mesh_playback != null and layers.mesh_playback.enabled:other += layers.mesh_playback.reservation_bytes()
		if layers.field_playback != null and layers.field_playback.enabled:
			var field: Dictionary = layers.field_playback.worker.status()
			other += int(field.largest_job_charge)*3*int(field.worker_count)
	var safe := maxi(0,int(memory_budget.safe_cache_bytes)-other)
	var transient: int = (current.largest_pair if plan.is_empty() else int(plan.pair_estimates[target]))*2
	var total := maxi(0,int((safe-transient)/1.05))
	full_preload = false
	budget_message = "Sizing particle preparation in the background."
	if policy not in ["adaptive","full"]:
		total = mini(int(policy)*Buffer.MIB,total)
		budget_message = "Manual rolling cache."
	elif field_priority:
		total = mini(2048*Buffer.MIB,total)
		budget_message = "Field preparation keeps RAM priority; particles use a rolling playhead window."
	elif not plan.is_empty():
		full_preload = plan.total <= total and int(plan.get("unresolved",0)) == 0
		total = mini(total,int(plan.total))
		budget_message = "Full-scene particle preparation fits safe RAM." if full_preload else "Bounded particle preparation: safe RAM limits the resident interval."
	else:
		# Only a short startup window is reserved before validated descriptor
		# sizing arrives; large future records never block the current sample.
		total = mini(total,int(current.largest_pair)*16)
	var ratio := .3 if plan.is_empty() else float(plan.decoded_total)/maxi(1,int(plan.total))
	if field_priority:ratio = .5
	decoded_limit = int(total*ratio);prepared_limit = total-decoded_limit
	if full_preload:decoded_limit = int(plan.decoded_total);prepared_limit = int(plan.prepared_total)
	var capacity := maxi(1,int(prepared_limit/maxi(1,current.largest_pair))-2)
	window_pairs = mini(8,capacity)
func _context(time: float) -> bool:
	var config := settings();var signature := JSON.stringify(config,"",true,true)
	var point: Dictionary = layers.reader.bracket(layers.particle_id,time)
	if point.is_empty():return false
	var unchanged: bool = source_generation == layers.reader.generation and signature == config_signature
	var next_key := str(layers.reader.generation)+JSON.stringify(layers.reader.source_stamp,"",true,true)+str(config.trails)
	var plan := worker.preparation_estimate(next_key)
	var now := Time.get_ticks_msec()
	if unchanged and budget_target == point.a and sized == not plan.is_empty() and now-budget_checked < 1000:return not context.is_empty() and context.get("admitted",false)
	if not layers.reader.samples.has(layers.particle_id):return false
	var entries: Array = context.entries if unchanged and not context.is_empty() else layers.reader.samples[layers.particle_id].duplicate(true)
	if entries.is_empty():return false
	_budgets(entries,config,memory_override,point.a,plan)
	budget_checked = now;sizing_key = next_key;sized = not plan.is_empty()
	var requested_cost: int = estimates.pair_estimates[point.a] if sized else estimates.largest_pair
	source_generation = layers.reader.generation;config_signature = signature;budget_target = point.a;last_target = -1
	var source_token := str(source_generation)+JSON.stringify(layers.reader.source_stamp,"",true,true)
	context = {"source_token":source_token,"token":source_token+signature,"path":layers.reader.source_path,"stamp":layers.reader.source_stamp.duplicate(),"entries":entries,"object":layers.reader.objects[layers.particle_id].duplicate(true),"config":config,"decoded_limit":decoded_limit,"prepared_limit":prepared_limit,"full_preload":full_preload,"transient_estimate":requested_cost*2,"sizing_key":sizing_key,"admitted":requested_cost <= prepared_limit}
	if not context.admitted:
		# Apply lower limits even when no new pair can be admitted. The worker
		# can reclaim unpinned history without touching the displayed pair.
		worker.request(context,[])
		budget_message = "A particle pair exceeds the safe RAM budget; preparation is paused."
		_update_ui();return false
	return true
func _request(time: float, force := false) -> bool:
	if not enabled or not _context(time):return false
	var bracket: Dictionary = layers.reader.bracket(layers.particle_id,time)
	if bracket.is_empty():return false
	var target: int = bracket.a
	if not force and last_target == target:return true
	var indices: Array[int] = []
	if sized and policy in ["adaptive","full"]:
		# Contiguous forward/reverse runway first, then retained history. Budget
		# each actual pair, rather than multiplying a fixed sample ceiling.
		var candidates: Array[int] = []
		for offset in range(context.entries.size()):
			var index := target+offset*direction
			if viewer.scene_loop_playback:index = posmod(index,context.entries.size())
			if index >= 0 and index < context.entries.size():candidates.append(index)
		if not viewer.scene_loop_playback:
			for offset in range(1,context.entries.size()):
				var index := target-offset*direction
				if index >= 0 and index < context.entries.size():candidates.append(index)
		# Mixed rolling caches can still pin larger previous pairs after a seek
		# or loop. Reserve both before filling the remaining directional budget.
		var transition_cost: int = estimates.largest_pair if field_priority else estimates.pair_estimates[target]
		var used: int = 0 if full_preload else transition_cost*2
		for index in candidates:
			var bytes: int = estimates.pair_estimates[index]
			if used+bytes > prepared_limit and not indices.is_empty():break
			indices.append(index);used += bytes
		# Mixed scenes keep their existing RAM reservation and rolling eviction,
		# but use that reservation rather than stopping at eight requested pairs.
		if field_priority:window_pairs = indices.size()
	else:
		for offset in range(window_pairs):
			var index := target+offset*direction
			if viewer.scene_loop_playback:index = posmod(index,context.entries.size())
			if index >= 0 and index < context.entries.size() and not indices.has(index):indices.append(index)
	last_target = target;worker.request(context,indices)
	return true
func begin(time: float, required := 1) -> void:
	if not enabled:return
	if not layers.particles_required():
		suspend();return
	hidden = false;pending_time = time;minimum = required;buffering = true
	_request(time,true);_update_ui()
func suspend() -> void:
	if not hidden or last_target >= 0:worker.cancel()
	hidden = true
	buffering = false;pending_time = null;last_target = -1
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = false
func invalidate() -> void:
	worker.cancel();source_generation = -1;context = {};last_target = -1;active_pair = {}
	buffering = enabled;pending_time = viewer.requested_time if enabled else null;minimum = 1
func acquire(time: float) -> Dictionary:
	hidden = false
	if not _request(time):return {}
	var value := worker.get_pair(last_target)
	if value.is_empty():
		Profile.count("g3_prepared_cache_miss")
		pending_time = time
		if not buffering:minimum = 1
		buffering = true;_update_ui()
	else:
		buffering = false;pending_time = null
		Profile.count("g3_prepared_cache_hit")
	return value
func seek(time: float) -> bool:
	if layers.reader.bracket(layers.particle_id,time).is_empty():return false
	direction = -1 if time < viewer.requested_time else 1
	worker.cancel();last_target = -1;begin(time,1)
	if not layers.particles_required():return not layers.sample(time,true).is_empty()
	if not worker.get_pair(last_target,false).is_empty():
		buffering = false;pending_time = null
		var result: Dictionary = layers.sample(time,true)
		if result.has("pending"):buffering = true;pending_time = time
		return not result.is_empty()
	# Preserve the committed sample while the UI explicitly reports preparation.
	return true
func _depth(status: Dictionary) -> int:
	var ready := 0
	if context.is_empty() or last_target < 0:return 0
	for offset in range(mini(window_pairs,context.entries.size())):
		var index := last_target+offset*direction
		if viewer.scene_loop_playback:index = posmod(index,context.entries.size())
		if index < 0 or index >= context.entries.size():break
		if not status.ready_indices.has(index):break
		ready += 1
	return ready
func pump() -> bool:
	wait_reason = "Required particle content"
	if not enabled:return true
	var target_time: float = float(pending_time) if pending_time != null else viewer.requested_time
	if layers.reader.bracket(layers.particle_id,target_time).is_empty():
		worker.cancel();buffering = false;pending_time = null;last_target = -1;_update_ui();return true
	if viewer.playing:
		var rate: float = viewer.physical_rate
		var next_direction := -1 if rate < 0 else 1
		if next_direction != direction:direction = next_direction;last_target = -1;worker.cancel()
	if not layers.particles_required():suspend();_update_ui();return true
	if hidden:
		hidden = false;begin(viewer.requested_time,1)
	if not _request(float(pending_time) if pending_time != null else viewer.requested_time):return false
	var status := worker.status()
	status.error = status.get("failures",{}).get(last_target,status.error)
	worker.trace_enabled = Profile.enabled
	for event in worker.drain_events():
		if Profile.enabled:
			if worker_events.size() < 4096:worker_events.append(event)
			else:worker_event_drops += 1
	if not status.error.is_empty():
		layers.fail_playback(status.error)
		buffering = true;_update_ui(status);return false
	if buffering:
		var possible := mini(window_pairs,context.entries.size() if viewer.scene_loop_playback else (context.entries.size()-last_target if direction>0 else last_target+1))
		if _depth(status) < mini(minimum,possible):_update_ui(status);return false
		var time: float = pending_time if pending_time != null else viewer.requested_time
		buffering = false;pending_time = null
		var result: Dictionary = layers.sample(time,true)
		if result.has("pending"):_update_ui(status);return false
		viewer.display_accum = 0
	_update_ui(status)
	if buffering:return false
	if layers.field_playback != null and not layers.field_playback.pump():
		# Field startup/refill can hold a mixed scene whose particles are ready.
		# Preserve a particle wait if the field pump requested a missing pair.
		if not buffering:wait_reason = "Required field content or startup coverage"
		return false
	return true
func cache_detail(status: Dictionary = {}) -> String:
	if status.is_empty():status = worker.status()
	var count: int = context.get("entries",[]).size()
	var complete: bool = count > 0 and int(status.prepared_pairs) == count
	var preparation := "Full scene prepared." if complete else ("Preparing scene in the background." if status.worker_active else "Prepared interval retained.")
	if status.get("pressure",false):preparation = "Preparation paused for physical RAM headroom."
	return "Particles: %d / %d prepared intervals. %s\nResident cache accounting: %.1f MiB decoded + %.1f MiB prepared (shared arrays counted conservatively).\n%s" % [status.prepared_pairs,count,preparation,status.decoded_bytes/float(Buffer.MIB),status.prepared_bytes/float(Buffer.MIB),budget_message]

func _update_ui(status: Dictionary = {}) -> void:
	if not enabled:return
	if status.is_empty():status = worker.status()
	status.error = status.get("failures",{}).get(last_target,status.error)
	readiness_error = status.get("error", "")
	var depth := _depth(status)
	var duration := 0.0
	if depth > 0 and not context.is_empty():
		var end := clampi(last_target+depth*direction,0,context.entries.size()-1)
		duration = absf(context.entries[end].time-context.entries[last_target].time)
		if viewer.scene_loop_playback:
			duration = 0
			for offset in range(depth):
				var index := posmod(last_target+offset*direction,context.entries.size())
				if index+1<context.entries.size():duration += context.entries[index+1].time-context.entries[index].time
	var text := "%s • %d prepared pairs • %.3f source units buffered\nDecoded %.1f / %.0f MiB • prepared %.1f / %.0f MiB (CPU)" % ["Preparing playback…" if buffering else ("Particles hidden" if hidden else "Playback ready"),depth,duration,status.decoded_bytes/float(Buffer.MIB),decoded_limit/float(Buffer.MIB),status.prepared_bytes/float(Buffer.MIB),prepared_limit/float(Buffer.MIB)]
	if not budget_message.is_empty():text += "\n"+budget_message
	if not status.error.is_empty():text += "\n"+status.error
	if text != last_ui:
		if is_instance_valid(label):label.text = text
		last_ui = text
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = layers.is_buffering() and not viewer.playing
func commit(pair: Dictionary, point: Dictionary) -> void:
	var started := Profile.begin()
	worker.pin(point.a);active_pair = pair
	viewer.history.clear()
	viewer.frame_a = viewer._frame_from_data(pair.a,point.a)
	viewer.frame_b = viewer.frame_a if point.a == point.b else viewer._frame_from_data(pair.b,point.b)
	for data in pair.history:viewer.history.append(viewer._frame_from_data(data,data.source_index))
	viewer.particle_count = pair.a.count
	if viewer.current_mm.instance_count != viewer.particle_count:viewer.current_mm.instance_count = viewer.particle_count
	viewer.current_buffer = pair.styled.buffer;viewer.current_sizes = pair.styled.sizes
	viewer.identity_matches = pair.exact_matches if point.a == point.b else pair.matches
	viewer.identity_pair_a = viewer.frame_a;viewer.identity_pair_b = viewer.frame_b;viewer.held_positions_ready = false
	viewer._refresh_mapping_options()
	viewer.range_min = pair.styled.range.x;viewer.range_max = pair.styled.range.y
	viewer._update_particle_legend()
	for layer in range(viewer.TRAIL_LAYERS):
		var mm: MultiMesh = viewer.trail_mms[layer]
		if layer >= pair.trails.size() or pair.trails[layer].is_empty():mm.instance_count = 0;continue
		var trail: Dictionary = pair.trails[layer]
		if mm.instance_count != trail.count:mm.instance_count = trail.count
		var upload := Profile.begin();mm.buffer = trail.buffer;Profile.end("g3_trail_gpu_submit",upload)
	Profile.end("g3_prepared_pair_commit",started)
func profile_report() -> Dictionary:
	return {"cache":worker.status(),"events":worker_events.duplicate(true),"events_dropped":worker_event_drops,"decoded_limit":decoded_limit,"prepared_limit":prepared_limit,"policy":policy,"strategy":"full_preload" if full_preload else "rolling","memory":memory_budget,"full_preload":full_preload,"field_priority":field_priority,"estimates":estimates,"budget_message":budget_message}
