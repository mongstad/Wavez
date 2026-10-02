extends RefCounted
const Buffer = preload("res://layers/field_buffer.gd")
const Grid = preload("res://layers/grid_view.gd")
const Memory = preload("res://layers/playback_buffer.gd")
const Profile = preload("res://scene/playback_profile.gd")
const Concurrency = preload("res://layers/field_concurrency.gd")
var layers
var viewer
var worker := Buffer.new()
var enabled := false
var buffering := false
var pending_time = null
var token := ""
var invalidation_serial := 0
var cache_scope := ""
var request_signature := ""
var staged := {} # At most one future GPU texture per visible field.
var cpu_limit := 0
var budget_report := {}
var budget_signature := ""
var budget_checked_ms := -1000
var error := ""
var label: Label
var uploads := 0
var last_upload_frame := -1
var session_waiting := false
var session_requested := false
var session_restart := false
var scope_choice: OptionButton
var range_start: SpinBox
var range_end: SpinBox
var forward_duration: SpinBox
var prepared_range: Array = []
var cache_cap_bytes := 0 # Optional per-controller ceiling; zero uses system capacity.
var automatic_jobs: Array = []
var automatic_anchor := 0.0
var automatic_end := 0.0
var automatic_generation := ""
var automatic_checked := -1000
var automatic_targets := ""
var pressure_until := 0
var rolling_pressure_events := 0
var capacity_wait := false
var concurrency := Concurrency.new()
var policy_checked := -1000
var policy_pressure_events := 0
var policy_frames: Array[float] = []
var last_tick_us := 0
var demand_report := {}
var startup_report := {}
var startup_events: Array = []
var last_speed := 0.0
# Test-only observation override; cannot relax the worker's physical admission.
var policy_memory_override := {}
func setup(owner) -> void:
	layers = owner;viewer = layers.viewer
	for obj in layers.reader.objects.values():
		if obj.kind == "volume":enabled = true
	enabled = enabled and viewer.scene_prebuffer_enabled and not viewer.offline_instance and layers.reader.trusted
	if enabled and worker.start() != OK:enabled = false
	concurrency.setup(worker.worker_count,worker.automatic_workers)
	if enabled:
		label = Label.new();label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;layers.performance_panel.add_child(label)
		var title := Label.new();title.text = "Playback preparation";layers.performance_panel.add_child(title)
		scope_choice = OptionButton.new()
		for choice in ["Automatic","Selected interval (advanced)","From current position (advanced)"]:scope_choice.add_item(choice)
		layers.performance_panel.add_child(scope_choice)
		var first: float = layers.reader.frames[0].time if not layers.reader.frames.is_empty() else 0.0
		var last: float = layers.reader.frames[-1].time if not layers.reader.frames.is_empty() else 0.0
		range_start = _range_control("Start time",first,last,first)
		range_end = _range_control("End time",first,last,last)
		forward_duration = _range_control("Window duration",0.0,last-first,minf(10,last-first))
		scope_choice.item_selected.connect(func(_index):_scope_changed())
		_scope_controls()
func _range_control(title: String, low: float, high: float, value: float) -> SpinBox:
	var row := HBoxContainer.new();layers.performance_panel.add_child(row)
	var caption := Label.new();caption.text = title;row.add_child(caption)
	var control := SpinBox.new();control.min_value = low;control.max_value = high;control.step = 0.0;control.value = value;control.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(control)
	control.value_changed.connect(func(_value):_scope_changed())
	return control
func _scope_controls() -> void:
	range_start.get_parent().visible = scope_choice.selected == 1
	range_end.get_parent().visible = scope_choice.selected == 1
	forward_duration.get_parent().visible = scope_choice.selected == 2
	scope_choice.tooltip_text = "Automatic prepares ahead using available RAM and reuses cached samples when seeking. Advanced intervals restrict playback to chosen times. Source values and rendering quality are unchanged."
func _scope_changed() -> void:
	if viewer.playing:viewer._toggle_playback()
	else:cancel_session()
	worker.cancel(true);token = "";automatic_generation = "";capacity_wait = false
	prepared_range.clear();_scope_controls()
func playback_range() -> Array:
	if layers.reader.frames.is_empty():return [0.0,0.0]
	return prepared_range if limited_playback() else [layers.reader.frames[0].time,layers.reader.frames[-1].time]
func limited_playback() -> bool:
	return active() and is_instance_valid(scope_choice) and scope_choice.selected != 0 and not prepared_range.is_empty()
func seek_outside_interval(time: float) -> void:
	if active() and scope_choice.selected == 0:
		# A scrub takes priority even when its target was already queued far ahead.
		automatic_generation = "";return
	if not active() or scope_choice.selected == 0 or prepared_range.is_empty() or (time >= prepared_range[0] and time <= prepared_range[1]):return
	if viewer.playing:viewer._toggle_playback()
	cancel_session();worker.cancel(true);token = "";request_signature = "";prepared_range.clear()
func _selected_range(time: float) -> Array:
	var first: float = layers.reader.frames[0].time;var last: float = layers.reader.frames[-1].time
	if scope_choice.selected == 1:return [clampf(range_start.value,first,last),clampf(range_end.value,first,last)]
	if scope_choice.selected == 2:
		return [maxf(first,time-forward_duration.value),time] if viewer.physical_rate < 0 else [time,minf(last,time+forward_duration.value)]
	return [first,last]
func close() -> void:worker.close();staged.clear()
func invalidate() -> void:
	invalidation_serial += 1
	worker.cancel();token = "";cache_scope = "";request_signature = "";staged.clear();buffering = false;pending_time = null;error = "";session_waiting = false;session_requested = false;session_restart = false;prepared_range.clear()
	automatic_generation = "";automatic_jobs.clear();capacity_wait = false
func active() -> bool:return enabled and not viewer.offline_instance and not viewer.inspection_busy
func partial_initial_window() -> bool:
	if not active() or scope_choice.selected != 0:return false
	var count := 0
	for id in layers.states:
		if layers.views[id] is Grid and layers.states[id].visible:count += layers.reader.samples[id].size()
	return automatic_jobs.size() < count
func begin_session(target_time = null) -> void:
	if not active() or layers.reader.frames.is_empty():return
	if scope_choice.selected == 0:
		session_requested = false
		request(viewer.requested_time if target_time == null else float(target_time),layers.field_budget())
		# Initial Play waits for useful admitted coverage, never the whole file
		# when it exceeds RAM. Subsequent moving windows replenish in background.
		session_waiting = not _automatic_ready()
		buffering = session_waiting;_update_ui()
		return
	session_requested = true;session_restart = false;error = ""
	var time: float = viewer.requested_time if target_time == null else float(target_time)
	# Independent object clocks include the held sample at the interval start.
	if not session_waiting:prepared_range = _selected_range(time)
	if prepared_range[0] >= prepared_range[1] and layers.reader.frames.size() > 1:
		layers.fail_playback("Choose an end time after the start time for field preparation.");session_requested = false;return
	if time < prepared_range[0] or time > prepared_range[1]:
		time = prepared_range[1] if viewer.physical_rate < 0 else prepared_range[0]
		session_waiting = false;layers.seek(time)
	request(time,layers.field_budget())
	var jobs: Array = [];var reserved := 0
	for amount in other_reservations().values():reserved += int(amount)
	for id in layers.states:
		if not layers.views[id] is Grid or not layers.states[id].visible:continue
		var point: Dictionary = layers.reader.bracket(id,time)
		var lower: Dictionary = layers.reader.bracket(id,prepared_range[0]);var upper: Dictionary = layers.reader.bracket(id,prepared_range[1])
		if upper.is_empty():continue
		var lo: int = lower.get("a",0);var hi: int = upper.a
		if not layers.ensure_channel(id,maxf(time,layers.reader.samples[id][lo].time)):return
		var start: int = clampi(point.get("a",lo),lo,hi);var count: int = hi-lo+1
		for offset in range(count):
			var index := lo+posmod(start-lo+offset*(-1 if viewer.physical_rate<0 else 1),count)
			var job := _job(id,index,layers.field_budget());job.other_reservation = reserved;jobs.append(job)
	if jobs.is_empty():return
	worker.prepare_session(token,jobs);session_restart = false;session_waiting = true;buffering = true;_update_ui()
func cancel_session() -> void:
	if not is_instance_valid(scope_choice) or scope_choice.selected != 0:worker.cancel_session()
	session_waiting = false;session_requested = false;session_restart = false;buffering = false;request_signature = ""
	_update_ui()
static func preparation_budget(target_bytes: int, window_bytes: int, memory: Dictionary, reserved: int) -> Dictionary:
	# One cache share plus two shares for current/staged sample references and
	# decoder/conversion temporaries. Leave a fourth share unused. The workload
	# ceiling is the existing current + four-lookahead window, not all host RAM.
	var remaining := maxi(0,int(memory.safe_cache_bytes)-reserved)
	var required := target_bytes*2
	var ceiling := maxi(required,window_bytes)
	return {"cpu_limit":mini(ceiling,remaining/4),"required_bytes":required,
		"target_bytes":target_bytes,"window_bytes":window_bytes,"reserved_other_bytes":reserved,
		"remaining_safe_bytes":remaining,"memory":memory.duplicate()}
func other_reservations() -> Dictionary:
	var reservations := {"scene_cache":maxi(0,layers.reader.cache.limit-layers.reader.cache.used),"particle_decoded":0,
		"particle_prepared":0,"particle_working":0,"mesh_cache_and_working":0}
	if layers.playback != null and layers.playback.enabled:
		var status: Dictionary = layers.playback.worker.status()
		reservations.particle_decoded = maxi(0,layers.playback.decoded_limit-int(status.decoded_bytes))
		reservations.particle_prepared = maxi(0,layers.playback.prepared_limit-int(status.prepared_bytes))
		reservations.particle_working = int(layers.playback.estimates.get("largest_pair",0))*2
	# Mesh cache and active/in-flight reservations follow its admitted workload.
	if layers.mesh_playback != null and layers.mesh_playback.enabled:reservations.mesh_cache_and_working = layers.mesh_playback.reservation_bytes()
	return reservations
func _job(id: String, index: int, budget: int) -> Dictionary:
	var entry: Dictionary = layers.reader.samples[id][index]
	var state: Dictionary = layers.states[id]
	var obj: Dictionary = layers.reader.objects[id]
	var size: int = entry.decoded # Conservative until this descriptor is requested.
	for array in entry.descriptor.get("arrays",[]):
		if array.name == state.channel:size = int(array.shape[0])*int(array.shape[1])*int(array.shape[2])*4
	return {"key":Grid.sample_key(obj,entry.sequence,state.channel,budget),"source_key":Grid.sample_key(obj,entry.sequence,"",budget),"scope":cache_scope,"id":id,"entry":entry.duplicate(true),"object":obj,"channel":state.channel,"budget":budget,"decoded_charge":int(entry.decoded),"preview_charge":mini(size,budget),"charge":int(entry.decoded)+mini(size,budget)+65536,"path":layers.reader.source_path,"stamp":layers.reader.source_stamp}
func request(time: float, budget: int) -> Array:
	var scope := str(layers.reader.generation)+JSON.stringify(layers.reader.source_stamp)+str(budget)
	var channels: Array = []
	for id in layers.states:
		if layers.views[id] is Grid:
			scope += id+str(layers.states[id].visible);channels.append([id,layers.states[id].channel])
	var signature := scope+JSON.stringify(channels)+str(scope_choice.selected)+JSON.stringify(prepared_range if scope_choice.selected != 0 else [])+":"+str(invalidation_serial)
	if token != signature:
		# Retain a bounded full-session allocation only for channel changes in the
		# same source/visibility/texture-budget scope. Acquisition still requires
		# the new generation; CPU replacements evict old entries incrementally.
		worker.cancel(scope == cache_scope);cache_scope = scope
		token = signature;request_signature = "";staged.clear();session_waiting = false;session_restart = session_requested and viewer.playing
		concurrency.reset_rates(worker.status().rates)
	if scope_choice.selected == 0:return _automatic_request(time,budget)
	worker.protect({},time,-1 if viewer.physical_rate < 0 else 1)
	capacity_wait = false
	var targets: Array = [];var future: Array = []
	var direction := -1 if viewer.physical_rate < 0 else 1
	for id in layers.states:
		if not layers.views[id] is Grid or not layers.states[id].visible:continue
		var point: Dictionary = layers.reader.bracket(id,time)
		if point.is_empty():continue
		targets.append(_job(id,point.a,budget))
		var first_index := 0;var last_index: int = layers.reader.samples[id].size()-1
		if scope_choice.selected != 0 and not prepared_range.is_empty():
			first_index = layers.reader.bracket(id,prepared_range[0]).get("a",0)
			last_index = layers.reader.bracket(id,prepared_range[1]).get("a",last_index)
		for offset in range(1,5):
			var index: int = point.a+offset*direction
			if viewer.scene_loop_playback:index = first_index+posmod(index-first_index,last_index-first_index+1)
			if index >= first_index and index <= last_index and index != point.a:future.append(_job(id,index,budget))
	var jobs: Array = [];var charge := 0
	for job in targets:
		charge += job.charge;jobs.append(job)
	var window: Array = jobs.duplicate();var window_bytes := charge
	for job in future:
		if not window.any(func(other):return other.key == job.key):window.append(job);window_bytes += job.charge
	var reservations := other_reservations()
	var reserved := 0
	for amount in reservations.values():reserved += int(amount)
	var next_budget := token+str(charge)+"/"+str(window_bytes)+"/"+str(reserved)
	if budget_signature != next_budget or Time.get_ticks_msec()-budget_checked_ms >= 1000:
		budget_checked_ms = Time.get_ticks_msec()
		# A RAM-guard failure emptied the queue; retry on this bounded refresh.
		if not worker.status().error.is_empty():request_signature = ""
		budget_signature = next_budget
		budget_report = preparation_budget(charge,window_bytes,Memory.memory_headroom(),reserved)
		cpu_limit = budget_report.cpu_limit
		budget_report.reservations = reservations
		budget_report.preview_budget_per_field = budget
		budget_report.targets = targets.map(func(job):return {"id":job.id,"decoded_bytes":job.decoded_charge,"preview_charge":job.preview_charge,"total_charge":job.charge})
	var status := worker.status();var session: Dictionary = status.session
	if status.retained_limit > 0:
		cpu_limit = maxi(cpu_limit,status.retained_limit);budget_report.cpu_limit = cpu_limit
	if session.get("state") in ["preparing","ready"]:
		cpu_limit = status.limit;budget_report.cpu_limit = cpu_limit
		budget_report.strategy = "full_timeline" if scope_choice.selected == 0 else "interval";budget_report.prepared_range = prepared_range.duplicate();budget_report.full_required_bytes = session.required_bytes
		budget_report.admission_memory = session.get("memory",{})
	error = ""
	if charge*2 > cpu_limit and session.is_empty():
		error = "Field preparation needs %.1f MiB; safe budget is %.1f MiB. Hide a field or free RAM; preview reduction cannot remove decoded source costs." % [charge*2/float(Memory.MIB),cpu_limit/float(Memory.MIB)]
		jobs.clear()
	else:
		for job in future:
			if jobs.any(func(other):return other.key == job.key):continue
			if charge+job.charge <= cpu_limit:
				charge += job.charge;jobs.append(job)
	var keys := token+str(cpu_limit)+"/"+str(reserved)
	for job in jobs:job.other_reservation = reserved
	for job in jobs:keys += job.key
	if keys != request_signature:
		request_signature = keys;worker.request(token,jobs,cpu_limit)
	_stage(targets,jobs)
	return targets
func _automatic_request(time: float, budget: int) -> Array:
	var targets: Array = [];var display: Array = [];var heads: Array = []
	var direction := -1 if viewer.physical_rate < 0 else 1
	var status := worker.status();var required := 0;var largest := 0
	for id in layers.states:
		if not layers.views[id] is Grid or not layers.states[id].visible:continue
		var rows: Array = layers.reader.samples[id]
		if rows.is_empty():continue
		var point: Dictionary = layers.reader.bracket(id,time)
		var index: int = point.get("a",0)
		var job := _job(id,index,budget)
		job.charge = int(status.charges.get(job.key,job.charge))
		largest = maxi(largest,job.charge)
		if not point.is_empty():targets.append(job);display.append(job);required += job.charge
		heads.append({"id":id,"index":index,"seen":0,"count":rows.size()})
		var next := index+direction
		if viewer.scene_loop_playback:next = posmod(next,rows.size())
		if next >= 0 and next < rows.size() and next != index:display.append(_job(id,next,budget))
	var signature := token+str(direction)+str(viewer.scene_loop_playback)+str(cache_cap_bytes)
	var protected := {}
	for job in display:protected[job.key] = true
	for id in layers.views:
		if layers.views[id] is Grid and not layers.views[id].key.is_empty():protected[layers.views[id].key] = true
	for ready in staged.values():protected[ready.key] = true
	worker.protect(protected,time,direction)
	var target_signature := str(targets.map(func(job):return job.key))
	largest = maxi(largest,required) # Current/staged references for every visible field.
	var target_missing := targets.any(func(job):return not status.charges.has(job.key) and not automatic_jobs.any(func(item):return item.key == job.key))
	var progressed := absf(time-automatic_anchor) > maxf(.000001,absf(automatic_end-automatic_anchor)*.2)
	var refresh := automatic_generation != signature or automatic_targets != target_signature or target_missing or progressed or Time.get_ticks_msec()-automatic_checked >= 1000
	if refresh:
		automatic_targets = target_signature
		automatic_generation = signature;automatic_checked = Time.get_ticks_msec();automatic_anchor = time;automatic_end = time
		var reservations := other_reservations();var other := 0
		for value in reservations.values():other += int(value)
		var memory := Memory.memory_headroom()
		cpu_limit = Buffer.session_capacity(memory,int(status.resident_bytes),other,maxi(largest,int(status.largest_job_charge)),worker.worker_count)
		if cache_cap_bytes > 0:cpu_limit = mini(cpu_limit,cache_cap_bytes)
		budget_report = {"strategy":"automatic","cpu_limit":cpu_limit,"required_bytes":required,"reserved_other_bytes":other,"reservations":reservations,"memory":memory,"resident_credit":status.resident_bytes,"largest_job_bytes":largest}
		capacity_wait = required > cpu_limit
		if status.pressure_events > rolling_pressure_events:pressure_until = Time.get_ticks_msec()+10000
		rolling_pressure_events = status.pressure_events
		# Reserve a modest amount for resident history, without scheduling it for
		# preparation. Pressure removes this allowance with a ten-second cooldown.
		var demand := _demand(status,time)
		var history_seconds := clampf(concurrency.rate/maxf(1.0,demand.consumer),1.0,3.0)
		var history := mini(int(cpu_limit*.1),int(ceil(demand.consumer*history_seconds))*largest)
		if Time.get_ticks_msec() < pressure_until:history = 0
		var history_bytes := 0
		for id in layers.states:
			if not layers.views[id] is Grid or not layers.states[id].visible:continue
			var rows: Array = layers.reader.samples[id]
			var point: Dictionary = layers.reader.bracket(id,time)
			var index: int = point.get("a",0)
			if direction < 0:
				if not point.is_empty():index += 1
			elif not rows.is_empty() and float(rows[index].time) >= time:index -= 1
			# Only the bounded allowance matters; do not scan the whole recording
			# and rebuild every history key at each source-sample boundary.
			while history_bytes < history and index >= 0 and index < rows.size():
				var row: Dictionary = rows[index]
				var key := Grid.sample_key(layers.reader.objects[id],row.sequence,layers.states[id].channel,budget)
				history_bytes += int(status.charges.get(key,0))
				index -= direction
		history = mini(history,history_bytes)
		var forward_limit := maxi(required+largest,cpu_limit-history)
		forward_limit = mini(cpu_limit,forward_limit)
		budget_report.history_allowance_bytes = history;budget_report.history_seconds = history_seconds
		# The source headers are immutable in this scope. Reuse their existing
		# job metadata, copying only the mutable charge/reservation envelope.
		var reusable_jobs := {}
		for job in automatic_jobs:
			if job.scope != cache_scope or job.budget != budget or job.channel != layers.states[job.id].channel:continue
			if not reusable_jobs.has(job.id):reusable_jobs[job.id] = {}
			reusable_jobs[job.id][job.entry.index] = job
		automatic_jobs = [];var charge := 0
		# Interleave independent object clocks in playback order. Only headers and
		# already known charges are needed; workers validate/decode on demand.
		while not capacity_wait and not heads.is_empty():
			var best := 0;var distance := INF
			for i in range(heads.size()):
				var head: Dictionary = heads[i]
				var when: float = layers.reader.samples[head.id][head.index].time
				var delta := (when-time)*direction
				if delta < 0 and head.seen > 0:delta += layers.reader.frames[-1].time-layers.reader.frames[0].time
				if delta < distance:distance = delta;best = i
			var head: Dictionary = heads[best]
			var cached: Dictionary = reusable_jobs.get(head.id,{}).get(head.index,{})
			var job: Dictionary = cached.duplicate() if not cached.is_empty() else _job(head.id,head.index,budget)
			job.charge = int(status.charges.get(job.key,job.charge));job.other_reservation = other
			if charge+job.charge > forward_limit:break
			charge += job.charge;automatic_jobs.append(job);automatic_end = time+maxf(0,distance)*direction
			head.seen += 1;head.index += direction
			if viewer.scene_loop_playback:head.index = posmod(head.index,head.count)
			if head.seen >= head.count or head.index < 0 or head.index >= head.count:heads.remove_at(best)
		worker.request(token,automatic_jobs,cpu_limit,true)
		error = ""
	_stage(targets,display)
	return targets
func _stage(_targets: Array, jobs: Array) -> void:
	# Drop obsolete staging before allocating another texture (current + one ahead).
	for id in staged.keys():
		if not jobs.any(func(job):return job.id == id and job.key == staged[id].key):staged.erase(id)
	for job in jobs:
		var view = layers.views[job.id]
		if view.key == job.key:continue
		if staged.has(job.id) and staged[job.id].key == job.key:continue
		# Keep the nearest staged frame; later lookahead stays in CPU RAM only.
		if staged.has(job.id) and jobs.any(func(earlier):return earlier.id == job.id and earlier.key == staged[job.id].key and jobs.find(earlier) < jobs.find(job)):continue
		if last_upload_frame == Engine.get_process_frames():break
		var prepared := worker.get_frame(job.key)
		if prepared.is_empty():continue
		staged.erase(job.id)
		var began := Profile.begin();var uploaded := Grid.upload(prepared);Profile.end("g3_field_gpu_stage",began)
		last_upload_frame = Engine.get_process_frames();uploads += 1
		if uploaded.has("error"):error = uploaded.error;break
		uploaded.key = job.key;staged[job.id] = uploaded
func acquire(time: float, budget: int) -> Dictionary:
	var targets := request(time,budget);var result := {};var ready := true # A failed future prefetch must not block an already resident sample.
	var cache := worker.status();var preparation_missing := false
	for job in targets:
		var failure: String = cache.get("failures",{}).get(job.key,"")
		if not failure.is_empty():error = failure;layers.fail_playback(failure)
		var view = layers.views[job.id]
		if view.key == job.key:result[job.id] = {"sample":view.data}
		elif staged.has(job.id) and staged[job.id].key == job.key:result[job.id] = staged[job.id]
		else:
			ready = false
			if not cache.charges.has(job.key):preparation_missing = true
	# A pending main-thread texture upload is not a producer shortage. Keep
	# its existing one-frame wait without restarting the CPU startup gate.
	if preparation_missing and viewer.playing and scope_choice.selected == 0:session_waiting = true
	buffering = session_waiting or not ready;pending_time = time if not ready else null
	_update_ui()
	return result if ready else {"pending":true}
func committed() -> void:
	for id in staged.keys():
		if layers.views[id].key == staged[id].key:staged.erase(id)
	buffering = session_waiting;pending_time = null;_update_ui()
func pump() -> bool:
	if not active():return true
	if session_restart:begin_session()
	if session_waiting:
		if not viewer.playing:cancel_session();return true
		if scope_choice.selected == 0:request(viewer.requested_time if pending_time == null else float(pending_time),layers.field_budget())
		var status := worker.status();var session: Dictionary = status.session
		if session.get("state") in ["blocked","refused"]:
			error = session.error;layers.fail_playback(error);session_waiting = false;buffering = false;_update_ui();return false
		var ready: bool = _automatic_ready() if scope_choice.selected == 0 else session.get("state") == "ready"
		if not ready:
			# An explicit seek may publish its target as soon as that sample is
			# available; continuous playback still waits for safe prepared runway.
			if pending_time != null:layers.sample(float(pending_time),true)
			buffering = true;_update_ui();return false
		cpu_limit = status.limit;session_waiting = false;buffering = false;viewer.display_accum = 0
		if scope_choice.selected == 0:
			startup_events.append(startup_report.merged({"seconds":Time.get_ticks_msec()/1000.0,"time":viewer.requested_time}))
			if startup_events.size() > 64:startup_events.pop_front()

	if pending_time != null:
		var result: Dictionary = layers.sample(float(pending_time),true)
		if result.is_empty() or result.has("pending"):return false
		viewer.display_accum = 0
	else:request(viewer.requested_time,layers.field_budget())
	_update_ui();return not buffering
func _demand(status: Dictionary, time: float) -> Dictionary:
	# Sum source-clock consumption, but use the least contiguous lead across
	# visible fields. Neither a distant cached island nor another field can
	# make a gap in the requested playback direction count as ready coverage.
	var speed: float = maxf(absf(viewer.physical_rate),.000001)
	var direction := -1 if viewer.physical_rate < 0 else 1
	var consumer := 0.0;var lead := INF;var samples := 0;var contiguous := true
	for id in layers.states:
		if not layers.views[id] is Grid or not layers.states[id].visible:continue
		var rows: Array = layers.reader.samples[id]
		if rows.is_empty():continue
		var point: Dictionary = layers.reader.bracket(id,time)
		var index: int = point.get("a",0)
		for offset in range(2):
			var required_index := index+offset*direction
			if viewer.scene_loop_playback:required_index = posmod(required_index,rows.size())
			if required_index < 0 or required_index >= rows.size():continue
			var required_key := Grid.sample_key(layers.reader.objects[id],rows[required_index].sequence,layers.states[id].channel,layers.field_budget())
			if not status.charges.has(required_key):contiguous = false
		var lo := maxi(0,index-16);var hi := mini(rows.size()-1,index+16)
		var duration: float = rows[hi].time-rows[lo].time
		if duration > 0:consumer += (hi-lo)/duration*speed
		var coverage := 0.0;var wrapped := 0.0;var count := 0
		for offset in range(rows.size()):
			var cursor := index+offset*direction
			if viewer.scene_loop_playback:cursor = posmod(cursor,rows.size())
			elif cursor < 0 or cursor >= rows.size():
				coverage = absf((float(rows[-1].time) if direction > 0 else float(rows[0].time))-time);break
			if offset > 0 and cursor == (0 if direction > 0 else rows.size()-1):wrapped += layers.reader.frames[-1].time-layers.reader.frames[0].time
			var key := Grid.sample_key(layers.reader.objects[id],rows[cursor].sequence,layers.states[id].channel,layers.field_budget())
			if not status.charges.has(key):break
			count += 1
			# Hold at cursor until the next source boundary (reverse needs cursor-1).
			var boundary := mini(cursor+1,rows.size()-1) if direction > 0 else cursor
			coverage = maxf(0,(float(rows[boundary].time)-time)*direction+wrapped)
		lead = minf(lead,coverage/speed);samples += count
	return {"consumer":consumer,"ahead_seconds":0.0 if is_inf(lead) else lead,"ahead_samples":samples,"contiguous_ready":contiguous}
func startup_state(status: Dictionary, time: float) -> Dictionary:
	var demand := _demand(status,time)
	var gate := concurrency.gate(demand.consumer,demand.ahead_seconds,status.session.get("state") == "ready")
	# Current/next residency is necessary, but does not establish a sustainable
	# runway. Retained coverage must satisfy the same measured startup gate.
	gate.ready = gate.ready and demand.contiguous_ready and not capacity_wait
	gate.merge(demand);return gate
func _automatic_ready() -> bool:
	var status := worker.status()
	startup_report = startup_state(status,viewer.requested_time if pending_time == null else float(pending_time))
	demand_report = _demand(status,viewer.requested_time if pending_time == null else float(pending_time))
	return startup_report.ready
func observe_frame(milliseconds: float) -> void:
	if not active():return
	var now := Time.get_ticks_usec()
	var interval := (now-last_tick_us)/1000.0 if last_tick_us > 0 else 0.0
	last_tick_us = now
	if policy_frames.size() < 1024:policy_frames.append(maxf(milliseconds,interval))
	if Time.get_ticks_msec()-policy_checked < 1000:return
	policy_checked = Time.get_ticks_msec()
	policy_frames.sort()
	var p95 := policy_frames[mini(policy_frames.size()-1,ceili(policy_frames.size()*.95)-1)] if not policy_frames.is_empty() else 0.0
	policy_frames.clear()
	var status := worker.status()
	demand_report = _demand(status,viewer.requested_time if pending_time == null else float(pending_time))
	var memory := Memory.memory_headroom() if policy_memory_override.is_empty() else policy_memory_override
	var other := 0
	for value in other_reservations().values():other += int(value)
	var largest: int = maxi(int(status.largest_job_charge),int(budget_report.get("largest_job_bytes",0)))
	var reserve: int = int(memory.reserve)+other+int(status.retirement_reserve_bytes)
	var available: int = int(memory.available_physical)-reserve
	var margin: int = maxi(256*Memory.MIB,int(memory.physical*.01))
	var signals := demand_report.merged({"rates":status.rates,"demand":status.session.get("state") == "preparing", "waiting":session_waiting or buffering,"swap":memory.get("process_swap",0),"memory_pressure":available < largest*3*concurrency.active+margin,"can_grow":available >= largest*3*(concurrency.active+1)+margin,"admission_pressure":status.pressure_events > policy_pressure_events,"frame_p95_ms":p95,"available_physical":memory.available_physical,"cache_bytes":status.bytes,"in_flight_bytes":status.in_flight_bytes})
	policy_pressure_events = status.pressure_events
	var count := concurrency.tick(now/1000000.0,signals)
	if count != status.active_limit:worker.set_concurrency(count)
	# Latch a predictive wait before the producer exhausts the runway. pump()
	# holds the clock and releases it only through the adaptive startup gate.
	if scope_choice.selected == 0 and viewer.playing and not session_waiting:
		var changed: bool = last_speed != viewer.physical_rate
		if concurrency.needs_runway(demand_report.consumer,demand_report.ahead_seconds,status.session.get("state") == "ready",changed):
			session_waiting = true;buffering = true
	last_speed = viewer.physical_rate
func _update_ui() -> void:
	if is_instance_valid(scope_choice) and not layers.reader.frames.is_empty():
		var last: float = layers.reader.frames[-1].time
		for control in [range_start,range_end]:
			control.set_block_signals(true);control.max_value = last;control.set_block_signals(false)
		forward_duration.set_block_signals(true);forward_duration.max_value = last-layers.reader.frames[0].time;forward_duration.set_block_signals(false)
	var status := worker.status()
	if error.is_empty():error = status.error
	var session: Dictionary = status.session
	if session.get("state") in ["blocked","refused"]:error = session.error
	if is_instance_valid(label):
		# Build the final status before assigning it. Intermediate strings dirty
		# the visible Performance dialog every callback even when nothing changes.
		var text := ("Field preparation blocked" if not error.is_empty() else ("Preparing fields…" if buffering else "Field prefetch ready"))+" • %.1f / %.1f MiB CPU cache\n" % [status.bytes/float(Memory.MIB),cpu_limit/float(Memory.MIB)]+error
		if session_waiting and scope_choice.selected != 0:
			text = ("Planning fields… %d / %d" % [session.get("planned",0),session.get("total",0)] if session.get("state") == "planning" else "Preparing fields… %d / %d • Pause to cancel" % [session.get("ready",0),session.get("total",0)])
		elif scope_choice.selected == 0:
			text = "Waiting for available memory" if capacity_wait or session.get("state") == "pressure" else ("Playback cache ready" if session.get("state") == "ready" else "Preparing playback… %d / %d" % [session.get("ready",0),session.get("total",0)])
			text += " • %.1f / %.1f GiB" % [status.bytes/float(1024*Memory.MIB),cpu_limit/float(1024*Memory.MIB)]
			if not error.is_empty():text = "Field playback unavailable\n"+error
		elif session.get("state") == "ready" and not prepared_range.is_empty():text = "Fields prepared: %s–%s • %.1f GiB CPU" % [prepared_range[0],prepared_range[1],status.bytes/float(1024*Memory.MIB)]
		if label.text != text:label.text = text
		label.tooltip_text = "Field cache only, not a process limit. Required target allowance: %.1f MiB. Other cache/worker reservations: %.1f MiB. Current/staged references and preparation temporaries have separate headroom." % [budget_report.get("required_bytes",0)/float(Memory.MIB),budget_report.get("reserved_other_bytes",0)/float(Memory.MIB)]
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = layers.is_buffering() and not viewer.playing
func profile_report() -> Dictionary:
	var current_gpu := 0;var staged_gpu := 0
	for view in layers.views.values():
		if view is Grid:current_gpu += view.gpu_bytes
	for ready in staged.values():staged_gpu += int(ready.get("gpu_bytes",0))
	return {"enabled":enabled,"buffering":buffering,"cache":worker.status(true),"budget":budget_report,"concurrency":concurrency.report(),"demand":demand_report.duplicate(),"startup":startup_report.duplicate(),"startup_events":startup_events.duplicate(true),"gpu_uploads":uploads,"current_gpu_bytes":current_gpu,"staged_gpu_bytes":staged_gpu,"staged_textures":staged.size(),"error":error}
