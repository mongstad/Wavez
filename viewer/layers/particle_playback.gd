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
var fallback_reason := ""
var memory_budget := {}
var decoded_limit := 0
var prepared_limit := 0
var full_preload := false
var budget_message := ""
var estimates := {}
var label: Label
var mode: OptionButton
var readiness_error := ""
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
	for name in ["Automatic (safe RAM)","512 MiB RAM","2 GiB RAM","8 GiB RAM","16 GiB RAM","All particle pairs, if safe"]:mode.add_item(name)
	mode.selected = ["adaptive","512","2048","8192","16384","full"].find(policy)
	mode.item_selected.connect(func(index: int):set_policy(["adaptive","512","2048","8192","16384","full"][index]))
	mode.tooltip_text = "Automatically preload captures that fit safely; otherwise use a rolling window. Manual RAM choices keep a rolling cache. GPU resources are limited to current particles and visible trails."
	if viewer.shell == null: viewer._check(parent,"Loop recorded interval",viewer.scene_loop_playback,set_loop)
	label = Label.new();label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label)
func set_loop(value: bool) -> void:
	viewer.scene_loop_playback = value;last_target = -1;worker.cancel()
func settings() -> Dictionary:
	return {"color_channel":viewer.color_channel,"size_channel":viewer.size_channel,"brightness_channel":viewer.brightness_channel,"normalization":viewer._effective_normalization(),"manual_min":viewer.manual_min,"manual_max":viewer.manual_max,"logarithmic":viewer.logarithmic,"clamp_map":viewer.clamp_map,"cyclic":viewer.cyclic,"invert_map":viewer.invert_map,"hidden_types":viewer.hidden_types.duplicate(),"trails":viewer.trails_enabled and not viewer.clean_view}
func set_policy(value: String) -> void:
	policy = value;fallback_reason = "";config_signature = "";last_target = -1
	if enabled:begin(viewer.requested_time,4)
func _budgets(entries: Array, config: Dictionary, memory: Dictionary = {}) -> void:
	window_pairs = 8
	memory_budget = Buffer.memory_headroom() if memory.is_empty() else memory
	estimates = Buffer.estimate(entries,config.trails)
	# Other scene caches share the same host; do not promise their RAM to particles.
	var other: int = layers.reader.cache.limit + 256*Buffer.MIB if layers != null else 0
	var safe := maxi(0,int(memory_budget.safe_cache_bytes)-other)
	var transient: int = estimates.largest_pair*2
	var total := mini(2048*Buffer.MIB,maxi(0,safe-transient))
	full_preload = policy in ["adaptive","full"] and fallback_reason.is_empty()
	budget_message = fallback_reason
	if full_preload:
		# Conservative decoded/prepared charges, 25% margin and peak working space.
		if ceili(estimates.total*1.25)+transient <= safe:
			decoded_limit = ceili(estimates.decoded_total*1.25);prepared_limit = ceili(estimates.prepared_total*1.25)
			budget_message = "Full particle preload: estimated %.0f MiB including working space fits %.0f MiB safe RAM." % [(ceili(estimates.total*1.25)+transient)/float(Buffer.MIB),safe/float(Buffer.MIB)]
			return
		budget_message = "Full particle preload exceeds safe RAM; using adaptive window."
		full_preload = false
	elif policy not in ["adaptive","full"]:
		total = mini(int(policy)*Buffer.MIB,maxi(0,safe-transient))
		budget_message = "Manual rolling cache."
		if total < int(policy)*Buffer.MIB:budget_message += " RAM budget reduced to preserve system headroom."
	decoded_limit = total/2;prepared_limit = total-decoded_limit
	# Reserve room for two still-displayed/previous pairs during cache turnover.
	var capacity := maxi(1,int(prepared_limit/maxi(1,estimates.largest_pair))-2)
	window_pairs = mini(8,capacity)
func _context() -> bool:
	var config := settings();var signature := JSON.stringify(config,"",true,true)
	if source_generation == layers.reader.generation and signature == config_signature:return true
	if not layers.reader.samples.has(layers.particle_id):return false
	var entries: Array = layers.reader.samples[layers.particle_id].duplicate(true)
	if entries.is_empty():return false
	_budgets(entries,config)
	if estimates.largest_pair > prepared_limit:
		worker.cancel();context = {};last_target = -1
		budget_message = "A particle pair exceeds the safe RAM budget; playback preparation is paused."
		_update_ui();return false
	source_generation = layers.reader.generation;config_signature = signature;last_target = -1
	var source_token := str(source_generation)+JSON.stringify(layers.reader.source_stamp,"",true,true)
	context = {"source_token":source_token,"token":source_token+signature,"path":layers.reader.source_path,"stamp":layers.reader.source_stamp.duplicate(),"entries":entries,"config":config,"decoded_limit":decoded_limit,"prepared_limit":prepared_limit,"full_preload":full_preload,"transient_estimate":estimates.largest_pair*2}
	return true
func _request(time: float, force := false) -> bool:
	if not enabled or not _context():return false
	var bracket: Dictionary = layers.reader.bracket(layers.particle_id,time)
	if bracket.is_empty():return false
	var target: int = bracket.a
	if not force and last_target == target:return true
	var indices: Array[int] = []
	for offset in range(window_pairs):
		var index := target+offset*direction
		if viewer.scene_loop_playback:index = posmod(index,context.entries.size())
		if index >= 0 and index < context.entries.size() and not indices.has(index):indices.append(index)
	if full_preload:
		for index in range(context.entries.size()):
			if not indices.has(index):indices.append(index)
	last_target = target;worker.request(context,indices)
	return true
func begin(time: float, required := 4) -> void:
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
	else:Profile.count("g3_prepared_cache_hit")
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
	if not enabled:return true
	var target_time: float = float(pending_time) if pending_time != null else viewer.requested_time
	if layers.reader.bracket(layers.particle_id,target_time).is_empty():
		worker.cancel();buffering = false;pending_time = null;last_target = -1;_update_ui();return true
	if viewer.playing:
		var rate: float = viewer.physical_rate if viewer.time_mode == "physical" else viewer.playback_fps
		var next_direction := -1 if rate < 0 else 1
		if next_direction != direction:direction = next_direction;last_target = -1;worker.cancel()
	if not layers.particles_required():suspend();_update_ui();return true
	if hidden:
		hidden = false;begin(viewer.requested_time,1)
	if not _request(float(pending_time) if pending_time != null else viewer.requested_time):return false
	var status := worker.status()
	worker.trace_enabled = Profile.enabled
	for event in worker.drain_events():
		if Profile.enabled:
			if worker_events.size() < 4096:worker_events.append(event)
			else:worker_event_drops += 1
	if not status.error.is_empty():
		if full_preload and status.error in ["Playback preparation paused to preserve physical RAM headroom.","Prepared pair exceeds the available playback budget; choose a larger safe budget."]:
			fallback_reason = "Full preload stopped at the RAM guard; using adaptive window."
			config_signature = "";worker.cancel();last_target = -1
			begin(target_time,1);return false
		viewer.status_label.text = status.error
		buffering = true;_update_ui(status);return false
	if buffering:
		# Automatic mode starts after full preparation, avoiding early-play underflow.
		# Explicit full-preload retains the previously accepted four-pair startup.
		if full_preload and policy == "adaptive" and status.prepared_pairs < context.entries.size():_update_ui(status);return false
		var possible := mini(window_pairs,context.entries.size() if viewer.scene_loop_playback else (context.entries.size()-last_target if direction>0 else last_target+1))
		if _depth(status) < mini(minimum,possible):_update_ui(status);return false
		var time: float = pending_time if pending_time != null else viewer.requested_time
		buffering = false;pending_time = null
		var result: Dictionary = layers.sample(time,true)
		if result.has("pending"):_update_ui(status);return false
		viewer.display_accum = 0
	_update_ui(status)
	return not buffering and (layers.field_playback == null or layers.field_playback.pump())
func _update_ui(status: Dictionary = {}) -> void:
	if not enabled:return
	if status.is_empty():status = worker.status()
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
	if text != last_ui:
		if is_instance_valid(label):label.text = text
		last_ui = text
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = layers.is_buffering()
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
	return {"cache":worker.status(),"events":worker_events.duplicate(true),"events_dropped":worker_event_drops,"decoded_limit":decoded_limit,"prepared_limit":prepared_limit,"policy":policy,"strategy":"full_preload" if full_preload else "rolling","memory":memory_budget,"full_preload":full_preload,"estimates":estimates,"budget_message":budget_message}
