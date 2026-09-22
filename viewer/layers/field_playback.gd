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
var cpu_limit := 128*Memory.MIB # Another 128 MiB reserved for in-flight/active data.
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
func _job(id: String, index: int, budget: int) -> Dictionary:
	var entry: Dictionary = layers.reader.samples[id][index]
	var state: Dictionary = layers.states[id]
	var obj: Dictionary = layers.reader.objects[id]
	var size := 0
	for array in entry.descriptor.arrays:
		if array.name == state.channel:size = int(array.shape[0])*int(array.shape[1])*int(array.shape[2])*4
	return {"key":Grid.sample_key(obj,entry.sequence,state.channel,budget),"id":id,"entry":entry,"object":obj,"channel":state.channel,"budget":budget,"charge":int(entry.decoded)+mini(size,budget)+65536,"path":layers.reader.source_path,"stamp":layers.reader.source_stamp}
func request(time: float, budget: int) -> Array:
	var signature := str(layers.reader.generation)+JSON.stringify(layers.reader.source_stamp)+str(budget)
	for id in layers.states:
		if layers.views[id] is Grid:signature += id+str(layers.states[id].visible)+layers.states[id].channel
	if token != signature:
		token = signature;request_signature = "";staged.clear()
		cpu_limit = mini(128*Memory.MIB,int(Memory.memory_headroom().safe_cache_bytes)/4)
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
	error = ""
	if charge*2 > cpu_limit:
		error = "Visible fields exceed the safe preparation budget; hide a layer or reduce the preview budget."
		jobs.clear()
	else:
		for job in future:
			if jobs.any(func(other):return other.key == job.key):continue
			if charge+job.charge <= cpu_limit:
				charge += job.charge;jobs.append(job)
	var keys := token
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
	if is_instance_valid(label):label.text = ("Preparing fields…" if buffering else "Field prefetch ready")+" • %.1f / %.0f MiB CPU\n" % [status.bytes/float(Memory.MIB),cpu_limit/float(Memory.MIB)]+error
	if is_instance_valid(viewer.play_button):viewer.play_button.disabled = layers.is_buffering() and not viewer.playing
func profile_report() -> Dictionary:return {"enabled":enabled,"buffering":buffering,"cache":worker.status(),"gpu_uploads":uploads,"staged_textures":staged.size(),"error":error}
