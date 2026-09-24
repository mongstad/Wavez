extends RefCounted
const Buffer = preload("res://layers/field_buffer.gd")
const Grid = preload("res://layers/grid_view.gd")
const Memory = preload("res://layers/playback_buffer.gd")
const Profile = preload("res://scene/playback_profile.gd")
var layers
var viewer
var worker := Buffer.new()
var enabled := false
var buffering := false
var pending_time = null
var token := ""
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
func setup(owner) -> void:
	layers = owner;viewer = layers.viewer
	for obj in layers.reader.objects.values():
		if obj.kind == "volume":enabled = true
	enabled = enabled and viewer.scene_prebuffer_enabled and not viewer.offline_instance and layers.reader.trusted
	if enabled and worker.start() != OK:enabled = false
	if enabled:
		label = Label.new();label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;layers.performance_panel.add_child(label)
func close() -> void:worker.close();staged.clear()
func invalidate() -> void:
	worker.cancel();token = "";request_signature = "";staged.clear();buffering = false;pending_time = null;error = ""
func active() -> bool:return enabled and not viewer.offline_instance and not viewer.inspection_busy
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
	var reservations := {"scene_cache":layers.reader.cache.limit,"particle_decoded":0,
		"particle_prepared":0,"particle_working":0,"mesh_cache_and_working":0}
	if layers.playback != null and layers.playback.enabled:
		reservations.particle_decoded = layers.playback.decoded_limit
		reservations.particle_prepared = layers.playback.prepared_limit
		reservations.particle_working = int(layers.playback.estimates.get("largest_pair",0))*2
	# Mesh preparation retains its existing cache + working-space reservation.
	if layers.mesh_playback != null and layers.mesh_playback.enabled:reservations.mesh_cache_and_working = 256*Memory.MIB
	return reservations
func _job(id: String, index: int, budget: int) -> Dictionary:
	var entry: Dictionary = layers.reader.samples[id][index]
	var state: Dictionary = layers.states[id]
	var obj: Dictionary = layers.reader.objects[id]
	var size := 0
	for array in entry.descriptor.arrays:
		if array.name == state.channel:size = int(array.shape[0])*int(array.shape[1])*int(array.shape[2])*4
	return {"key":Grid.sample_key(obj,entry.sequence,state.channel,budget),"id":id,"entry":entry,"object":obj,"channel":state.channel,"budget":budget,"decoded_charge":int(entry.decoded),"preview_charge":mini(size,budget),"charge":int(entry.decoded)+mini(size,budget)+65536,"path":layers.reader.source_path,"stamp":layers.reader.source_stamp}
func request(time: float, budget: int) -> Array:
	var signature := str(layers.reader.generation)+JSON.stringify(layers.reader.source_stamp)+str(budget)
	for id in layers.states:
		if layers.views[id] is Grid:signature += id+str(layers.states[id].visible)+layers.states[id].channel
	if token != signature:
		token = signature;request_signature = "";staged.clear()
	var targets: Array = [];var future: Array = []
	var direction := -1 if viewer.physical_rate < 0 else 1
	for id in layers.states:
		if not layers.views[id] is Grid or not layers.states[id].visible:continue
		var point: Dictionary = layers.reader.bracket(id,time)
		if point.is_empty():continue
		targets.append(_job(id,point.a,budget))
		for offset in range(1,5):
			var index: int = point.a+offset*direction
			if viewer.scene_loop_playback:index = posmod(index,layers.reader.samples[id].size())
			if index >= 0 and index < layers.reader.samples[id].size() and index != point.a:future.append(_job(id,index,budget))
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
	error = ""
	if charge*2 > cpu_limit:
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
	return targets
func acquire(time: float, budget: int) -> Dictionary:
	var targets := request(time,budget);var result := {};var ready := true # A failed future prefetch must not block an already resident sample.
	for job in targets:
		var view = layers.views[job.id]
		if view.key == job.key:result[job.id] = {"sample":view.data}
		elif staged.has(job.id) and staged[job.id].key == job.key:result[job.id] = staged[job.id]
		else:ready = false
	buffering = not ready;pending_time = time if buffering else null
	_update_ui()
	return result if ready else {"pending":true}
func committed() -> void:
	for id in staged.keys():
		if layers.views[id].key == staged[id].key:staged.erase(id)
	buffering = false;pending_time = null;_update_ui()
func pump() -> bool:
	if not active():return true
	if pending_time != null:
		var result: Dictionary = layers.sample(float(pending_time),true)
		if result.is_empty() or result.has("pending"):return false
		viewer.display_accum = 0
	else:request(viewer.requested_time,layers.field_budget())
	_update_ui();return not buffering
func _update_ui() -> void:
	var status := worker.status()
	if error.is_empty():error = status.error
	if is_instance_valid(label):
		label.text = ("Field preparation blocked" if not error.is_empty() else ("Preparing fields…" if buffering else "Field prefetch ready"))+" • %.1f / %.1f MiB CPU cache\n" % [status.bytes/float(Memory.MIB),cpu_limit/float(Memory.MIB)]+error
		label.tooltip_text = "Field cache only, not a process limit. Required target allowance: %.1f MiB. Other cache/worker reservations: %.1f MiB. Current/staged references and preparation temporaries have separate headroom." % [budget_report.get("required_bytes",0)/float(Memory.MIB),budget_report.get("reserved_other_bytes",0)/float(Memory.MIB)]
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = layers.is_buffering() and not viewer.playing
func profile_report() -> Dictionary:
	var current_gpu := 0;var staged_gpu := 0
	for view in layers.views.values():
		if view is Grid:current_gpu += view.gpu_bytes
	for ready in staged.values():staged_gpu += int(ready.get("gpu_bytes",0))
	return {"enabled":enabled,"buffering":buffering,"cache":worker.status(),"budget":budget_report,"gpu_uploads":uploads,"current_gpu_bytes":current_gpu,"staged_gpu_bytes":staged_gpu,"staged_textures":staged.size(),"error":error}
