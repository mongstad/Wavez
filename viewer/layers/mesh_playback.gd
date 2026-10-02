extends RefCounted
const Buffer = preload("res://layers/mesh_buffer.gd")
const MeshView = preload("res://layers/mesh_view.gd")
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
var staged := {} # At most one future GPU mesh per visible mesh.
var cpu_limit := 0
var budget_report := {}
var budget_signature := ""
var budget_checked := -1000
var budget_memory_override := {} # Deterministic admission regression only.
var error := ""
var label: Label
var uploads := 0
var last_upload_frame := -1
func setup(owner) -> void:
	layers = owner;viewer = layers.viewer
	for obj in layers.reader.objects.values():
		if obj.kind == "mesh":enabled = true
	enabled = enabled and viewer.scene_prebuffer_enabled and not viewer.offline_instance and layers.reader.trusted
	if enabled and worker.start() != OK:enabled = false
	if enabled:
		label = Label.new();label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;layers.performance_panel.add_child(label)
func close() -> void:worker.close();staged.clear();cpu_limit = 0;budget_report.clear()
func invalidate() -> void:
	worker.cancel();token = "";request_signature = "";budget_signature = "";staged.clear();buffering = false;pending_time = null;error = ""
func active() -> bool:return enabled and not viewer.offline_instance and not viewer.inspection_busy
func _job(id: String, index: int, budget: int) -> Dictionary:
	var entries: Array = layers.reader.samples[id]
	var entry: Dictionary = entries[index];var next: Dictionary = entries[mini(index+1,entries.size()-1)]
	var state: Dictionary = layers.states[id]
	var obj: Dictionary = layers.reader.objects[id]
	var unresolved: int = maxi(int(entry.decoded) if entry.descriptor.is_empty() else 0,int(next.decoded) if next.descriptor.is_empty() else 0)
	var vertices := mini(1000000,unresolved/12);var indices := mini(6000000,unresolved/4)
	for array in entry.descriptor.get("arrays",[]):
		if array.name == "position":vertices = maxi(vertices,int(array.shape[0]))
		if array.name == "triangles":indices = maxi(indices,int(array.shape[0])*3)
	# Includes decoded pairs, temporary exact-ID maps, original/expanded display
	# arrays, morph input/output, and allocation overhead (shared bytes overcounted).
	for array in next.descriptor.get("arrays",[]):
		if array.name == "position":vertices = maxi(vertices,int(array.shape[0]))
		if array.name == "triangles":indices = maxi(indices,int(array.shape[0])*3)
	var charge := int(entry.decoded)+int(next.decoded)+vertices*200+indices*160+65536
	var key := "%s/%s/%s/%s/%s" % [id,entry.sequence,next.sequence,budget,JSON.stringify(state)]
	return {"key":key,"id":id,"entry":entry.duplicate(true),"next":next.duplicate(true),"object":obj,"state":state.duplicate(true),"colors":viewer.colormaps[state.colormap],"budget":budget,"charge":charge,"path":layers.reader.source_path,"stamp":layers.reader.source_stamp}
static func preparation_budget(target_bytes: int, window_bytes: int, memory: Dictionary, reserved: int) -> Dictionary:
	# One cache share, two shares for active/staged references and decode/upload
	# scratch, and one unused share. Never use swap or reserve an entire capture.
	var remaining := maxi(0,int(memory.safe_cache_bytes)-reserved)
	var required := target_bytes*2
	return {"cpu_limit":mini(maxi(required,window_bytes),remaining/4),"required_bytes":required,
		"target_bytes":target_bytes,"window_bytes":window_bytes,"reserved_other_bytes":reserved,
		"remaining_safe_bytes":remaining,"memory":memory.duplicate()}
func other_reservations() -> Dictionary:
	var reservations := {"scene_cache":maxi(0,layers.reader.cache.limit-layers.reader.cache.used),
		"particle_decoded":0,"particle_prepared":0,"particle_working":0,"field_working":0}
	if layers.playback != null and layers.playback.enabled:
		var status: Dictionary = layers.playback.worker.status()
		reservations.particle_decoded = maxi(0,layers.playback.decoded_limit-int(status.decoded_bytes))
		reservations.particle_prepared = maxi(0,layers.playback.prepared_limit-int(status.prepared_bytes))
		reservations.particle_working = int(layers.playback.estimates.get("largest_pair",0))*2
	if layers.field_playback != null and layers.field_playback.enabled:
		var status: Dictionary = layers.field_playback.worker.status()
		# Resident field cache already reduces MemAvailable. Future field cache
		# admission subtracts our reservation; reserve its bounded pool scratch here.
		reservations.field_working = int(status.largest_job_charge)*3*int(status.worker_count)
	return reservations
func reservation_bytes() -> int:
	# Charge the whole cache + two working shares. Charges overestimate actual
	# residency, so do not credit them as physical pages when reserving for fields.
	return cpu_limit*3
func update_budget(time: float, budget: int) -> Dictionary:
	var plan := _jobs(time,budget)
	var target_bytes := 0;var window_bytes := 0;var largest := 0
	for job in plan.targets:target_bytes += int(job.charge)
	for job in plan.jobs:window_bytes += int(job.charge);largest = maxi(largest,int(job.charge))
	var signature: String = plan.signature+"/%s/%s" % [target_bytes,window_bytes]
	var now := Time.get_ticks_msec()
	if signature != budget_signature or now-budget_checked >= 1000:
		var memory: Dictionary = Memory.memory_headroom() if budget_memory_override.is_empty() else budget_memory_override
		var reservations := other_reservations();var reserved := 0
		for amount in reservations.values():reserved += int(amount)
		var pressure: bool = int(memory.safe_cache_bytes) <= reserved or int(memory.available_physical) < int(memory.reserve)+reserved+largest*3
		# Keep a healthy, admitted allowance stable while fields fill their own
		# cache. Re-dividing remaining RAM every frame would repeatedly surrender
		# the mesh reservation to fields. Live worker admission still gates every job.
		if signature != budget_signature or pressure or target_bytes*2 > cpu_limit or not budget_memory_override.is_empty():
			budget_report = preparation_budget(target_bytes,window_bytes,memory,reserved)
			cpu_limit = budget_report.cpu_limit;budget_report.reservations = reservations
			request_signature = ""
			if layers.field_playback != null:layers.field_playback.automatic_checked = -1000
		budget_report.current_reserved_other_bytes = reserved;budget_report.current_reservations = reservations;budget_report.current_memory = memory
		if int(worker.status().pressure_failures) > 0:request_signature = ""
		budget_checked = now;budget_signature = signature
	return plan
func _jobs(time: float, budget: int) -> Dictionary:
	var signature := str(layers.reader.generation)+JSON.stringify(layers.reader.source_stamp)+str(budget)
	for id in layers.states:
		if layers.views[id] is MeshView:signature += id+JSON.stringify(layers.states[id])
	var targets: Array = [];var future: Array = []
	var direction := -1 if viewer.physical_rate < 0 else 1
	for id in layers.states:
		if not layers.views[id] is MeshView or not layers.states[id].visible:continue
		var point: Dictionary = layers.reader.bracket(id,time)
		if point.is_empty():continue
		targets.append(_job(id,point.a,budget))
		for offset in range(1,5):
			var index: int = point.a+offset*direction
			if viewer.scene_loop_playback:index = posmod(index,layers.reader.samples[id].size())
			if index >= 0 and index < layers.reader.samples[id].size() and index != point.a:future.append(_job(id,index,budget))
	var jobs: Array = targets.duplicate()
	for job in future:
		if not jobs.any(func(other):return other.key == job.key):jobs.append(job)
	return {"signature":signature,"targets":targets,"jobs":jobs}
func request(time: float, budget: int) -> Array:
	var plan := update_budget(time,budget)
	if token != plan.signature:
		token = plan.signature;request_signature = "";staged.clear()
	var targets: Array = plan.targets
	var jobs: Array = targets.duplicate();var charge := 0
	for job in targets:charge += int(job.charge)
	error = ""
	if charge*2 > cpu_limit:
		error = "Mesh CPU preparation needs %.1f MiB; safe cache allowance is %.1f MiB. Free RAM or hide a mesh layer. The GPU preview budget does not reduce decoded source costs." % [charge*2/float(Memory.MIB),cpu_limit/float(Memory.MIB)]
		jobs.clear()
	else:
		for job in plan.jobs:
			if jobs.any(func(other):return other.key == job.key):continue
			if charge+job.charge <= cpu_limit:
				charge += job.charge;jobs.append(job)
	var reserved := int(budget_report.get("current_reserved_other_bytes",0))
	for job in jobs:job.other_reservation = reserved
	var keys := token+str(cpu_limit)+"/"+str(reserved)
	for job in jobs:keys += job.key
	if keys != request_signature:
		request_signature = keys;worker.request(token,jobs,cpu_limit)
	# Drop obsolete staging before allocating another mesh (current + one ahead).
	for id in staged.keys():
		if not jobs.any(func(job):return job.id == id and job.key == staged[id].key):staged.erase(id)
	for job in jobs:
		var view = layers.views[job.id]
		if view.key == job.key and view.data.get("token") == token:continue
		if staged.has(job.id) and staged[job.id].key == job.key:continue
		# Keep the nearest staged frame; later lookahead stays in CPU RAM only.
		if staged.has(job.id) and jobs.any(func(earlier):return earlier.id == job.id and earlier.key == staged[job.id].key and jobs.find(earlier) < jobs.find(job)):continue
		if last_upload_frame == Engine.get_process_frames():break
		var prepared := worker.get_frame(job.key)
		if prepared.is_empty():continue
		if view.gpu_bytes+prepared.gpu_bytes > budget*2:continue
		staged.erase(job.id)
		var began := Profile.begin();prepared = prepared.duplicate();prepared.token = token
		var uploaded := MeshView.upload(prepared);Profile.end("g3_mesh_gpu_stage",began)
		last_upload_frame = Engine.get_process_frames();uploads += 1
		if uploaded.has("error"):error = uploaded.error;break
		uploaded.key = job.key;staged[job.id] = uploaded
	return targets
func acquire(time: float, budget: int) -> Dictionary:
	for id in layers.states:
		if layers.views[id] is MeshView and layers.views[id].gpu_bytes > budget:layers.views[id].clear()
	var targets := request(time,budget);var result := {};var ready := true # A failed future prefetch must not block an already resident sample.
	for job in targets:
		var failure: String = worker.status().get("failures",{}).get(job.key,"")
		if not failure.is_empty():error = failure;layers.fail_playback(failure)
		var view = layers.views[job.id]
		if view.key == job.key and view.data.get("token") == token:result[job.id] = view.data
		elif staged.has(job.id) and staged[job.id].key == job.key:result[job.id] = staged[job.id]
		else:ready = false
	if not ready and not error.is_empty():layers.fail_playback(error)
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
	else:request(viewer.requested_time,layers.mesh_budget())
	_update_ui();return not buffering
func _update_ui() -> void:
	var status := worker.status()
	if error.is_empty():error = status.error
	if is_instance_valid(label):label.text = ("Mesh CPU preparation blocked" if not error.is_empty() else ("Preparing meshes…" if buffering else "Mesh prefetch ready"))+" • %.1f / %.1f MiB CPU cache • %.1f MiB in flight\n" % [status.bytes/float(Memory.MIB),cpu_limit/float(Memory.MIB),status.in_flight_bytes/float(Memory.MIB)]+error
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = (buffering or layers.is_buffering()) and not viewer.playing
func profile_report() -> Dictionary:return {"enabled":enabled,"buffering":buffering,"cache":worker.status(),"budget":budget_report,"cpu_limit":cpu_limit,"reserved_mesh_bytes":reservation_bytes(),"gpu_uploads":uploads,"staged_meshes":staged.size(),"error":error}
