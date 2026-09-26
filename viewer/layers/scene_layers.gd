extends Node3D
const Reader = preload("res://layers/scene_reader.gd")
const GridView = preload("res://layers/grid_view.gd")
const MeshView = preload("res://layers/mesh_view.gd")
const Profile = preload("res://scene/playback_profile.gd")
const ColorMapping = preload("res://layers/volume_color.gd")
const VolumePresets = preload("res://layers/volume_presets.gd")
const Opacity = preload("res://layers/volume_opacity.gd")
var viewer
var playback
var field_playback
var mesh_playback
var particle_skipped := false
var prepared_token := ""
var reader
var states := {}
var legend_visibility := {}
var views := {}
var labels := {}
var current := {}
var layer_samples: Array = []
var particle_id := ""
var particle_key := ""
var publishing := false
var generation := -1
var error := ""
var gpu_budget_mib := 256
var panel: VBoxContainer
var probe_label: Label
var probe_stamp := {}
var probe_stamp_label: Label
var probe_channel_label: Label
var probe_channel := ""
var probe_channel_choice: OptionButton
var probe_spins: Array[SpinBox] = []
var selected_volume := ""
var panel_groups: Dictionary = {}
var opacity_controls := {}
var color_controls := {}
var preset_controls := {}
var range_thread := Thread.new()
var range_request := {}
var iso_pid := -1
var iso_directory := ""
var iso_node
var iso_status: Label
var iso_request_serial := 0
var iso_cache_hits := 0
var iso_error := ""
var iso_target := ""
var iso_finished_target := ""
var iso_id := ""
var iso_result := {}
var iso_debounce := 0.0
var identity_generation := -1
var source_identity := {}
var probe_marker: MeshInstance3D
var probe_marker_enabled := true
var probe_marker_valid := false
var performance_panel: VBoxContainer
var tool_bodies := {}
var layer_budget := 0
func setup(scene, source) -> void:
	viewer = scene;reader = source;generation = reader.generation
	for id in reader.objects:
		var obj: Dictionary = reader.objects[id]
		if obj.kind == "particles": particle_id = id;continue
		if obj.kind == "volume":
			var view := GridView.new();add_child(view);view.setup(viewer.camera);views[id] = view
			var first: Dictionary = reader.bracket(id,reader.frames[0].time) if not reader.frames.is_empty() else {}
			var descriptor: Dictionary = reader.describe(id,first.a) if selected_volume.is_empty() and not first.is_empty() else {}
			var channel: String = descriptor.arrays[0].name if not descriptor.is_empty() else ""
			states[id] = {"visible":selected_volume.is_empty(),"channel":channel,"volume":true,"slice":false,"lower":0.0,"upper":1.0,"opacity":.25,"step":.5,"colormap":"viridis","slice_normal":[0.0,0.0,1.0],"slice_distance":0.0,"clip":false,"clip_normal":[1.0,0.0,0.0],"clip_distance":0.0,"threshold":.5,"isosurface":false}
			states[id].opacity_mapping = Opacity.DEFAULT.duplicate()
			states[id].color_mapping = ColorMapping.DEFAULT.duplicate()
			if selected_volume.is_empty(): selected_volume = id
		else:
			var view := MeshView.new();add_child(view);views[id] = view
			states[id] = {"visible":true,"channel":"","lower":-2.0,"upper":2.0,"colormap":"viridis","wireframe":false}
	playback = preload("res://layers/particle_playback.gd").new();playback.setup(self)
	performance_panel = VBoxContainer.new(); viewer.tools_ui.form("Performance").add_child(performance_panel)
	_build_ui()
	field_playback = preload("res://layers/field_playback.gd").new();field_playback.setup(self)
	mesh_playback = preload("res://layers/mesh_playback.gd").new();mesh_playback.setup(self)
func clear_views() -> void:
	if playback != null:playback.invalidate()
	if field_playback != null:field_playback.invalidate()
	if mesh_playback != null:mesh_playback.invalidate()
	particle_skipped = false;prepared_token = ""
	particle_key = "";current = {};layer_samples.clear()
	for id in views:
		if views[id] is GridView: views[id].clear()
		else: views[id].clear()
	viewer.current_mm.instance_count = 0;viewer.frame_a = null;viewer.frame_b = null;viewer.history.clear();viewer.committed_sample.clear()
	for mm in viewer.trail_mms:mm.instance_count = 0
	cancel_iso();iso_finished_target = "";iso_target = "";iso_result = {};identity_generation = -1
	if is_instance_valid(iso_node):iso_node.clear();iso_node.visible = false
func close() -> void:
	if range_thread.is_started():range_thread.wait_to_finish()
	range_request = {}
	if playback != null:playback.close()
	if field_playback != null:field_playback.close()
	if mesh_playback != null:mesh_playback.close()
	cancel_iso()
	_clear_tool_bodies()
	if is_instance_valid(performance_panel):
		performance_panel.get_parent().remove_child(performance_panel);performance_panel.queue_free();performance_panel = null
	if is_instance_valid(panel):
		panel.get_parent().remove_child(panel);panel.queue_free();panel = null
	for id in labels: labels[id] = null
func _exit_tree() -> void: close()
func refresh() -> bool:
	var started := Profile.begin()
	var result := _refresh_profiled()
	Profile.end("g3_layer_refresh",started)
	return result
func _refresh_profiled() -> bool:
	var previous: String = reader.header.sha256
	if not reader.refresh():
		error = reader.error;clear_views();viewer.frame_a = null;viewer.playing = false;return false
	if generation != reader.generation:
		clear_views();generation = reader.generation;viewer.capture_generation += 1;viewer.reader_generation = generation;viewer.shared_timeline = null
		viewer.frame_count = reader.frames.size();viewer.capture = reader.file
		if previous != reader.header.sha256 or viewer.offline_instance:
			error = "Scene source changed; reopen the scene/export.";viewer.frame_a = null;viewer.playing = false;return false
		# Native samples and ticks publish the refreshed union clock here.
		# Publish the union-clock range too, or a live capture keeps its opening
		# slider maximum and subsequent indices clamp visually to 100 percent.
		viewer._set_timeline_extent()
	return true
func sample(time: float, asynchronous := false, force_particles := false) -> Dictionary:
	var started := Profile.begin()
	var previous_key := particle_key
	var result := _sample_profiled(time,asynchronous,force_particles)
	Profile.end("g3_sample",started,{"requested_time":time,"pair_before":previous_key,"pair_after":particle_key,"ok":not result.is_empty(),"pending":result.get("pending",false)})
	return result
func _sample_profiled(time: float, asynchronous: bool, force_particles: bool) -> Dictionary:
	if not refresh() or reader.frames.is_empty(): return {}
	if time < reader.frames[0].time or time > reader.frames[-1].time: error = "Scene time outside recorded range.";return {}
	# Default channels for newly visible/available fields are resolved only at
	# the requested time; hidden layers and future schemas do not delay opening.
	for id in states:
		if states[id].visible and not ensure_channel(id,time):return {}
	var need_particles := force_particles or particles_required()
	var buffered := {}
	if asynchronous and playback.enabled and use_async() and need_particles and not reader.bracket(particle_id,time).is_empty():
		buffered = playback.acquire(time)
		if buffered.is_empty():return {"pending":true,"requested_time":time,"status":"preparing"}
	var prepared := {};var brackets := {};var count_visible := 0;var active_views := 0;var cpu_bytes := 0
	for id in states:
		if states[id].visible:
			active_views += 1
			if states[id].get("isosurface",false):active_views += 1
	layer_budget = gpu_budget_mib*1048576/maxi(1,active_views)
	var fields := {}
	if asynchronous and field_playback != null and field_playback.active():
		fields = field_playback.acquire(time,field_budget())
		if fields.has("pending"):return {"pending":true,"requested_time":time,"status":"preparing fields"}
	var meshes := {}
	if asynchronous and mesh_playback != null and mesh_playback.active():
		meshes = mesh_playback.acquire(time,mesh_budget())
		if meshes.has("pending"):return {"pending":true,"requested_time":time,"status":"preparing meshes"}
	for id in reader.objects:
		var point: Dictionary = reader.bracket(id,time);brackets[id] = point
		if point.is_empty() or (states.has(id) and not states[id].visible) or (id == particle_id and not need_particles):continue
		cpu_bytes += int(reader.samples[id][point.a].decoded)
		if reader.objects[id].kind != "volume" and point.a != point.b:cpu_bytes += int(reader.samples[id][point.b].decoded)
		if cpu_bytes > 512*1048576:error = "Visible source sample pairs exceed 512 MiB; hide a layer.";clear_views();return {}
		var a: Dictionary = buffered.a if id == particle_id and not buffered.is_empty() else (meshes[id].a if meshes.has(id) else (fields[id].sample if fields.has(id) else reader.read_sample(id,point.a)))
		if a.is_empty(): error = reader.error;clear_views();viewer.frame_a = null;return {}
		var b: Dictionary = a
		if reader.objects[id].kind != "volume" and point.b != point.a:
			b = buffered.b if id == particle_id and not buffered.is_empty() else (meshes[id].b if meshes.has(id) else reader.read_sample(id,point.b))
			if b.is_empty(): error = reader.error;clear_views();viewer.frame_a = null;return {}
		prepared[id] = {"a":a,"b":b}
		if reader.objects[id].kind == "volume" and states[id].visible and states[id].volume:count_visible += 1
	if count_visible > 1: error = "One translucent volume can be visible; disable another volume first.";return {}
	publishing = true;error = "";layer_samples.clear();current = prepared
	var pp: Dictionary = brackets.get(particle_id,{})
	var new_particle_key := "%s/%s/%s" % [generation,pp.get("a",-1),pp.get("b",-1)]
	if not need_particles and not particle_id.is_empty():
		if not particle_skipped:
			viewer.current_instance.visible = false
			for instance in viewer.trail_instances:instance.visible = false
			viewer.history.clear();viewer.identity_pair_a = null;viewer.identity_pair_b = null
			viewer.frame_a = viewer.FrameData.new();viewer.frame_a.channels = {"position":PackedFloat32Array()};viewer.frame_a.components = {"position":3};viewer.frame_b = viewer.frame_a
			particle_skipped = true
		viewer.frame_a.sim_time = time;particle_key = new_particle_key;prepared_token = ""
		Profile.count("g3_hidden_particle_skips")
	elif not buffered.is_empty():
		if new_particle_key != particle_key or prepared_token != buffered.token or particle_skipped:
			playback.commit(buffered,pp);particle_key = new_particle_key;prepared_token = buffered.token
			Profile.count("g3_particle_pair_changes")
		particle_skipped = false
		viewer._render_current(float(pp.get("alpha",0)))
	else:
		if new_particle_key != particle_key or particle_skipped:
			var pair_started := Profile.begin()
			Profile.count("g3_particle_pair_changes")
			viewer.history.clear()
			if prepared.has(particle_id):
				var conversion_started := Profile.begin()
				viewer.frame_a = viewer._frame_from_data(prepared[particle_id].a,pp.a)
				viewer.frame_b = viewer._frame_from_data(prepared[particle_id].b,pp.b)
				Profile.end("g3_particle_frame_conversion",conversion_started)
				if viewer.trails_enabled and not viewer.clean_view:
					for i in range(pp.a-1,maxi(-1,pp.a-6),-1):
						var old: Dictionary = reader.read_sample(particle_id,i)
						if old.is_empty():break
						viewer.history.append(viewer._frame_from_data(old,i))
			else:
				viewer.frame_a = viewer.FrameData.new();viewer.frame_a.sim_time = time;viewer.frame_a.channels = {"position":PackedFloat32Array()};viewer.frame_a.components = {"position":3};viewer.frame_b = viewer.frame_a
			if viewer.frame_a == null or viewer.frame_b == null: publishing = false;return {}
			viewer._refresh_mapping_options();viewer._rebuild_style();viewer._rebuild_trails();particle_key = new_particle_key
			Profile.end("g3_particle_pair_rebuild",pair_started,{"pair":particle_key,"particle_layer_visible":viewer.particle_layer_visible})
		viewer._render_current(float(pp.get("alpha",0)))
		particle_skipped = false;prepared_token = ""
	viewer.requested_time = time
	var lo := 0
	while lo+1 < reader.frames.size() and reader.frames[lo+1].time <= time:lo += 1
	viewer.current_index = lo
	viewer.phase = (time-reader.frames[lo].time)/(reader.frames[lo+1].time-reader.frames[lo].time) if lo+1 < reader.frames.size() else 0.0
	for id in reader.objects:
		var obj: Dictionary = reader.objects[id];var point: Dictionary = brackets[id]
		var info := {"id":id,"kind":obj.kind,"visible":viewer.particle_layer_visible if obj.kind == "particles" else states[id].visible,"status":"unavailable","source_time":null,"source_indices":[],"display_lod":"unavailable","units":obj.units}
		if not prepared.has(id):
			if views.has(id):
				if views[id] is GridView:views[id].clear()
				else:views[id].clear()
			if not info.visible:
				info.status = "hidden"
				# Particle clock bookkeeping survives the payload fast path. Other
				# hidden layers retain their existing unsampled export metadata.
				if obj.kind == "particles" and not point.is_empty():
					info.source_time = point.time;info.source_indices = [point.a,point.b]
		else:
			var a: Dictionary = prepared[id].a;var b: Dictionary = prepared[id].b
			info.status = point.status;info.source_time = a.time;info.source_indices = [point.a,point.b]
			if obj.kind == "particles":
				if point.status == "held" and point.a != point.b and a.has_ids:info.status = "interpolated by ID"
				info.display_lod = "all recorded particles";info.scalar_time = a.time
			elif obj.kind == "volume":
				info.source_indices = [point.a]
				var view = views[id]
				if not view.load_sample(obj,a,states[id].channel,field_budget(),fields.get(id,{}) if fields.get(id,{}).has("texture") else {}):
					info.status = "unavailable";info.reason = view.error
				else:
					_note_channels(id,a)
					view.apply(states[id],lut(states[id].colormap));info.display_lod = "float32 / stride %d" % view.lod
					info.channel = states[id].channel;info.geometry = a.geometry
					info.color_compositing = "Compatibility sRGB framebuffer" if RenderingServer.get_current_rendering_method() == "gl_compatibility" else "Forward+ linear framebuffer"
					info.effective_ray_step = "max(requested step, ray length / 1024); early alpha stop .995"
					info.opacity_mapping = Opacity.resolve(states[id]).duplicate()
					info.color_mapping = ColorMapping.resolve(states[id]).duplicate()
					info.color_bounds = [states[id].lower,states[id].upper]
					info.color_source_statistics = view.color_stats
					if not view.color_error.is_empty():info.status = "unavailable";info.reason = view.color_error
					info.numeric_precision = str(a.channels[states[id].channel].get_class()) if a.channels[states[id].channel] is Object else ("float64 source" if a.channels[states[id].channel] is PackedFloat64Array else "float32 source")
			else:
				_note_channels(id,a)
				var view = views[id]
				var status: String = view.apply_prepared(meshes[id],meshes[id].key,point.alpha,states[id].visible) if meshes.has(id) else view.load_samples(obj,a,b,point.alpha,states[id],layer_budget,viewer.colormaps[states[id].colormap])
				if status == "unavailable": info.status = status;info.reason = view.error
				elif status == "interpolated": info.status = status
				info.display_lod = "full mesh";info.channel = states[id].channel
		if views.has(id) and views[id] is GridView:_update_color_status(id)
		layer_samples.append(info)
		if labels.has(id):
			labels[id].text = "%s: %s%s\n%s" % [id,info.status," @ %.4f" % info.source_time if info.source_time != null else "",info.display_lod]
			labels[id].tooltip_text = JSON.stringify(info,"  ")
	if not prepared.has(particle_id):viewer.committed_sample = {}
	viewer.committed_sample.requested_time = time;viewer.committed_sample.layers = layer_samples.duplicate(true)
	viewer._timeline_guard = true;viewer.timeline.value = lo;viewer._timeline_guard = false
	viewer._update_hud();publishing = false
	viewer._update_particle_legend()
	_sync_iso_target()
	if field_playback != null:
		field_playback.committed()
		if field_playback.active():field_playback.request(time,field_budget())
	if mesh_playback != null:
		mesh_playback.committed()
		if mesh_playback.active():mesh_playback.request(time,mesh_budget())
	if not asynchronous and playback != null and playback.enabled:
		# A synchronous scientific sample owns the committed clock too; discard
		# any earlier startup/seek request rather than publishing it on a later tick.
		playback.pending_time = null;playback.buffering = false;playback.last_target = -1
		if particles_required():playback._request(time,true)
		else:playback.suspend()
	return {"a":lo,"b":mini(lo+1,reader.frames.size()-1),"alpha":viewer.phase,"requested_time":time,"status":"scene"}
var luts := {}
func lut(name: String) -> Texture2D:
	if luts.has(name):return luts[name]
	var image := Image.create(256,1,false,Image.FORMAT_RGB8)
	for i in range(256): var c: Array = viewer.colormaps[name][i];image.set_pixel(i,0,Color(c[0],c[1],c[2]))
	luts[name] = ImageTexture.create_from_image(image);return luts[name]
func ensure_channel(id: String, time: float) -> bool:
	if reader.objects[id].kind != "volume" or not states[id].channel.is_empty():return true
	var point: Dictionary = reader.bracket(id,time)
	if point.is_empty():return true
	var descriptor: Dictionary = reader.describe(id,point.a)
	if descriptor.is_empty():fail_playback(reader.error);return false
	states[id].channel = descriptor.arrays[0].name
	if id == selected_volume and probe_channel.is_empty():probe_channel = states[id].channel
	return true
func _note_channels(id: String, data: Dictionary) -> void:
	reader.note_channels(id,data)
	if not panel_controls.has(id) or not panel_controls[id].has("channel"):return
	var choice: OptionButton = panel_controls[id].channel
	var names := {}
	for i in choice.item_count:names[choice.get_item_metadata(i)] = true
	for name in data.channels:
		if names.has(name) or (reader.objects[id].kind == "mesh" and (data.shapes[name].size() != 1 or name == "vertex_id")):continue
		choice.add_item(name);choice.set_item_metadata(choice.item_count-1,name)
	if id == selected_volume and is_instance_valid(probe_channel_choice):
		var known := {}
		for i in probe_channel_choice.item_count:known[probe_channel_choice.get_item_text(i)] = true
		for name in data.channels:
			if not known.has(name):probe_channel_choice.add_item(name)
func fail_playback(message: String) -> void:
	viewer.playing = false;error = message;viewer.status_label.text = message
func resample() -> void:
	particle_key = ""
	var result := sample(viewer.requested_time,use_async())
	if result.is_empty():viewer.status_label.text = error
func tick(delta: float) -> void:
	var started := Profile.begin()
	if Profile.enabled and Profile.trace_enabled:
		Profile.trace_context = {"playing":viewer.playing,"requested_time_before":viewer.requested_time,"source_index_before":viewer.current_index,"particle_pair_before":particle_key,"tail_accumulator_before":viewer.tail_poll,"delta":delta}
	_tick_profiled(delta)
	Profile.end("g3_tick",started)
func _tick_profiled(delta: float) -> void:
	if iso_debounce > 0:
		iso_debounce -= delta
		if iso_debounce <= 0:_start_iso()
	viewer._move_free_camera(delta)
	if viewer.orbit_enabled and not viewer.dragging: viewer.yaw += delta*viewer.orbit_speed;viewer._update_camera()
	viewer.tail_poll += delta
	if viewer.tail_poll >= 1:
		var poll_started := Profile.begin()
		viewer.tail_poll = 0;refresh()
		Profile.count("g3_tail_polls")
		Profile.end("g3_tail_poll",poll_started)
	if playback != null and playback.enabled and use_async() and not playback.pump():_poll_iso();return
	if field_playback != null and not field_playback.pump():_poll_iso();return
	if mesh_playback != null and not mesh_playback.pump():_poll_iso();return
	if viewer.frame_a == null:return
	if viewer.playing and reader.frames.size()>1:
		var committed_index: int = viewer.current_index;var committed_phase: float = viewer.phase
		var next_time: float = viewer.requested_time+delta*viewer.physical_rate
		var interval: Array = field_playback.playback_range() if field_playback != null else [reader.frames[0].time,reader.frames[-1].time]
		var outside: bool = next_time>interval[1] or next_time<interval[0]
		if viewer.scene_loop_playback and outside:next_time = wrapf(next_time,interval[0],interval[1])
		viewer.requested_time = clampf(next_time,interval[0],interval[1])
		viewer.display_accum += delta
		if viewer.display_accum >= 1.0/viewer.DISPLAY_HZ:
			# Keep the fractional frame remainder; resetting it quantizes 30 Hz
			# playback down to 20 Hz on slightly-short 60 Hz callbacks.
			viewer.display_accum -= 1.0/viewer.DISPLAY_HZ
			var result := sample(viewer.requested_time,use_async())
			if result.has("pending"):
				viewer.requested_time = viewer.committed_sample.get("requested_time",viewer.requested_time)
				viewer.current_index = committed_index;viewer.phase = committed_phase
			Profile.count("g3_display_samples")
			if outside and not viewer.scene_loop_playback and not result.has("pending") and field_playback != null and field_playback.limited_playback():viewer._toggle_playback()
	_poll_iso()
func use_async() -> bool:
	return ((playback != null and playback.enabled) or (field_playback != null and field_playback.enabled) or (mesh_playback != null and mesh_playback.enabled)) and not viewer.offline_instance and not viewer.inspection_busy
func is_buffering() -> bool:
	return (playback != null and playback.buffering) or (field_playback != null and field_playback.buffering) or (mesh_playback != null and mesh_playback.buffering)
func field_budget() -> int:
	# Current texture + one staged texture share each field's existing GPU quota.
	return layer_budget/2 if field_playback != null and field_playback.enabled else layer_budget
func mesh_budget() -> int:
	# Current and at most one staged surface share the existing per-layer GPU quota.
	return layer_budget/2 if mesh_playback != null and mesh_playback.enabled else layer_budget
func particles_required() -> bool:
	return not viewer.scene_hidden_fast_path or viewer.particle_layer_visible or viewer.guide_visibility.data or viewer.inspection_busy
func ensure_particle_data() -> bool:
	if not particle_skipped:return true
	return not sample(viewer.requested_time,false,true).is_empty()
func seek(time: float) -> bool:
	if not refresh() or reader.frames.is_empty() or not is_finite(time) or time < reader.frames[0].time or time > reader.frames[-1].time:return false
	if field_playback != null:
		field_playback.seek_outside_interval(time)
		if field_playback.session_waiting:
			field_playback.cancel_session();field_playback.pending_time = time;field_playback.begin_session(time)
		else:field_playback.pending_time = null;field_playback.buffering = false
	if mesh_playback != null:mesh_playback.pending_time = null;mesh_playback.buffering = false
	if use_async() and playback.enabled and not particle_id.is_empty() and not reader.bracket(particle_id,time).is_empty():return playback.seek(time)
	return not sample(time,use_async()).is_empty()
func _number(parent: Control, title: String, value: float, low: float, high: float, step: float, changed: Callable) -> SpinBox:
	var label := Label.new();label.text = title;parent.add_child(label)
	var spin := SpinBox.new();spin.min_value = low;spin.max_value = high;spin.step = step;spin.value = value;parent.add_child(spin);spin.value_changed.connect(changed);return spin
func _scalar_input(parent: Control, title: String, value: float, changed: Callable) -> LineEdit:
	var label := Label.new();label.text = title;parent.add_child(label)
	var edit := LineEdit.new();edit.text = JSON.stringify(value,"",true,true);parent.add_child(edit)
	var last := {"value":value}
	var commit := func():
		var text := edit.text.strip_edges()
		# Preserve the model when focus leaves unchanged text: the engine decimal
		# parser can differ by one float64 ULP from its own formatter.
		if text == JSON.stringify(last.value,"",true,true):return
		if not text.is_valid_float() or not is_finite(text.to_float()):
			viewer.status_label.text = "Enter a finite numeric value (scientific notation is supported).";edit.text = JSON.stringify(last.value,"",true,true);return
		var v := text.to_float()
		if v == last.value:return
		if changed.call(v):last.value = v
		edit.text = JSON.stringify(last.value,"",true,true)
	edit.text_submitted.connect(func(_text):commit.call());edit.focus_exited.connect(commit)
	return edit
func _set_range(id: String, key: String, value: float) -> bool:
	if (key == "lower" and value >= states[id].upper) or (key == "upper" and value <= states[id].lower):
		viewer.status_label.text = "Range maximum must exceed minimum.";return false
	if reader.objects[id].kind == "volume":
		var candidate: Dictionary = states[id].duplicate(true);candidate[key] = value
		candidate.color_mapping.policy = "manual";candidate.color_mapping.source_channel = "";candidate.color_mapping.source_time = 0.
		var problem := ColorMapping.validate(candidate)
		if not problem.is_empty():viewer.status_label.text = problem;return false
		states[id] = candidate
	else:states[id][key] = value
	resample();return true
func _set_threshold(id: String, value: float) -> bool:
	states[id].threshold = value;_sync_iso_target();return true
func _set_opacity_mapping(id: String, key: String, value) -> bool:
	var mapping: Dictionary = states[id].opacity_mapping.duplicate()
	mapping[key] = value
	var problem := Opacity.validate(mapping)
	if not problem.is_empty():viewer.status_label.text = problem;return false
	states[id].opacity_mapping = mapping;resample();return true
func _build_opacity_ui(body: VBoxContainer, id: String) -> void:
	var title := Label.new();title.text = "Mapping";title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;body.add_child(title)
	var mode := OptionButton.new();mode.add_item("Linear scalar");mode.add_item("Magnitude")
	mode.select(Opacity.MODES.find(states[id].opacity_mapping.mode));body.add_child(mode)
	mode.tooltip_text = "Display extinction only; not a calibrated physical measurement. Magnitude treats positive and negative values equally without changing their color or source values."
	mode.item_selected.connect(func(i):
		if not _set_opacity_mapping(id,"mode",Opacity.MODES[i]):mode.select(Opacity.MODES.find(states[id].opacity_mapping.mode)))
	var low := _scalar_input(body,"Zero-opacity threshold",states[id].opacity_mapping.lower,func(v):return _set_opacity_mapping(id,"lower",v))
	var high := _scalar_input(body,"Full-opacity threshold",states[id].opacity_mapping.upper,func(v):return _set_opacity_mapping(id,"upper",v))
	low.tooltip_text = "At or below this scalar (absolute scalar in Magnitude mode), extinction is zero. Set a positive threshold to suppress near-zero space."
	high.tooltip_text = "At or above this scalar, extinction reaches Opacity / world unit. A linear ramp connects the thresholds; color range is unchanged."
	var reset := Button.new();reset.text = "Reset opacity";_tool_body("Derive range",id).add_child(reset)
	reset.pressed.connect(func():
		states[id].opacity_mapping = Opacity.DEFAULT.duplicate()
		# Rebuild through the shared restore path so numeric editors' last values
		# stay synchronized, while session probes/disclosures remain untouched.
		apply_state(snapshot()))
	opacity_controls[id] = {"mode":mode,"lower":low,"upper":high,"reset":reset}
func _clear_tool_bodies() -> void:
	for body in tool_bodies.values():
		if is_instance_valid(body): body.get_parent().remove_child(body); body.queue_free()
	tool_bodies.clear()

func _tool_body(title: String, id := "") -> VBoxContainer:
	var key := title+":"+id
	if not tool_bodies.has(key):
		var body := VBoxContainer.new()
		(performance_panel if title == "Performance" else viewer.tools_ui.form(title)).add_child(body)
		if not id.is_empty():
			var label := Label.new(); label.text = id; label.set_meta("source_name",true); body.add_child(label)
		tool_bodies[key] = body
	return tool_bodies[key]

var category_pages := {}
var object_choices := {}
var object_bodies := {}
var selected_objects := {}
var panel_controls := {}

func show_category(index: int) -> void:
	for kind in category_pages: category_pages[kind].visible = kind == ("volume" if index == 1 else "mesh") and index != 0

func choose_object(kind: String, id: String) -> void:
	if not object_bodies.has(id) or reader.objects[id].kind != kind: return
	selected_objects[kind] = id
	for key in object_bodies:
		if reader.objects[key].kind == kind:object_bodies[key].visible = key == id
	var choice: OptionButton = object_choices[kind]
	for i in choice.item_count:
		if choice.get_item_metadata(i) == id: choice.select(i)

func _panel_group(parent: VBoxContainer, id: String, title: String) -> VBoxContainer:
	var key: String = reader.objects[id].kind + "/" + id + "/" + title
	var body := preload("res://ui/shell/panel_group.gd").create(parent,title,viewer.layer_panel_disclosures.get(key,false))
	var header: Button = body.get_meta("panel_header")
	header.toggled.connect(func(value: bool): viewer.layer_panel_disclosures[key] = value)
	panel_groups[id+"/"+title] = header
	return body

func _build_ui() -> void:
	_clear_tool_bodies()
	panel = VBoxContainer.new();viewer.shell.adapter.add_child(panel)
	category_pages.clear();object_choices.clear();object_bodies.clear();panel_controls.clear()
	for kind in ["volume","mesh"]:
		var page := VBoxContainer.new();panel.add_child(page);category_pages[kind] = page
		var heading := Label.new();heading.text = "Object";page.add_child(heading)
		var choice := OptionButton.new();choice.fit_to_longest_item = false;page.add_child(choice);object_choices[kind] = choice
		for id in reader.objects:
			if reader.objects[id].kind == kind:choice.add_item(id);choice.set_item_metadata(choice.item_count-1,id)
		choice.disabled = choice.item_count == 0
		if choice.item_count == 0:
			var empty := Label.new();empty.text = "No fields" if kind == "volume" else "No meshes";page.add_child(empty)
		choice.item_selected.connect(func(i):choose_object(kind,str(choice.get_item_metadata(i))))
	if playback != null:playback.build_ui(_tool_body("Performance"))
	var gpu := _number(_tool_body("Performance"),"Layer GPU budget • MiB",gpu_budget_mib,1,2048,1,func(v):gpu_budget_mib = int(v);resample())
	gpu.tooltip_text = "MiB for field, mesh and derived-surface allocations. Decoded cache, particle buffering and other process memory are separate."
	for id in reader.objects:
		var label := Label.new();label.text = id;label.clip_text = true;panel.add_child(label);label.hide();labels[id] = label
		if reader.objects[id].kind == "particles":continue
		var body := VBoxContainer.new();category_pages[reader.objects[id].kind].add_child(body);object_bodies[id] = body
		var rendering := _panel_group(body,id,"Rendering")
		var colors := _panel_group(body,id,"Color Mapping")
		panel_controls[id] = {}
		var visible_check := CheckButton.new();visible_check.text = "Visible";visible_check.button_pressed = states[id].visible;rendering.add_child(visible_check)
		panel_controls[id].visible = visible_check
		visible_check.toggled.connect(func(v):
			if v and reader.objects[id].kind == "volume" and states[id].volume:
				for other in states:
					if other != id and reader.objects[other].kind == "volume" and states[other].visible and states[other].volume:
						viewer.status_label.text = "Disable the other volume before showing this one.";visible_check.set_pressed_no_signal(false);return
			states[id].visible = v;resample())
		var channel: OptionButton = viewer._option(colors,"Channel");panel_controls[id].channel = channel
		if reader.objects[id].kind == "mesh":channel.add_item("Fixed mesh color");channel.set_item_metadata(0,"")
		var channel_names := {}
		for a in reader.known_arrays(id):
			if reader.objects[id].kind == "volume" or (a.shape.size() == 1 and a.name != "vertex_id"):channel_names[a.name] = true
		for name in channel_names:
			channel.add_item(name);channel.set_item_metadata(channel.item_count-1,name)
		for i in range(channel.item_count):
			if channel.get_item_metadata(i) == states[id].channel:channel.select(i)
		channel.item_selected.connect(func(i):states[id].channel = str(channel.get_item_metadata(i));resample())
		if reader.objects[id].kind == "volume":_build_preset_ui(_tool_body("Quick setup",id),id)
		panel_controls[id].lower = _scalar_input(colors,"Color range minimum" if reader.objects[id].kind == "volume" else "Range minimum",states[id].lower,func(v):return _set_range(id,"lower",v))
		panel_controls[id].upper = _scalar_input(colors,"Color range maximum" if reader.objects[id].kind == "volume" else "Range maximum",states[id].upper,func(v):return _set_range(id,"upper",v))
		if reader.objects[id].kind == "volume":_build_color_ui(colors,id)
		var map: OptionButton = viewer._option(colors,"Colormap");panel_controls[id].colormap = map
		for name in viewer.colormaps:map.add_item(name)
		for i in range(map.item_count):
			if map.get_item_text(i) == states[id].colormap:map.select(i)
		map.item_selected.connect(func(i):states[id].colormap = map.get_item_text(i);resample())
		var legend_check := CheckButton.new(); legend_check.text = "Show legend"
		legend_check.button_pressed = legend_visibility.get(id,true); colors.add_child(legend_check)
		panel_controls[id].legend = legend_check
		legend_check.toggled.connect(func(v):
			legend_visibility[id] = v
			viewer.shell.layer_legends.sync(); viewer.shell.reposition_legend())
		if reader.objects[id].kind == "mesh":
			var wire := CheckButton.new();wire.text = "Wireframe";wire.button_pressed = states[id].wireframe;rendering.add_child(wire);panel_controls[id].wireframe = wire;wire.toggled.connect(func(v):states[id].wireframe = v;resample());continue
		var volume := CheckButton.new();volume.text = "Volume ray march";volume.button_pressed = states[id].volume;rendering.add_child(volume);panel_controls[id].volume = volume;volume.toggled.connect(func(v):
			if v and states[id].visible:
				for other in states:
					if other != id and reader.objects[other].kind == "volume" and states[other].visible and states[other].volume:
						viewer.status_label.text = "Disable the other volume before showing this one.";volume.set_pressed_no_signal(false);return
			states[id].volume = v;resample())
		var opacity_body := _panel_group(body,id,"Opacity")
		_build_opacity_ui(opacity_body,id)
		var strength := _number(opacity_body,"Opacity strength",states[id].opacity,0,10,.01,func(v):states[id].opacity = v;resample())
		panel_controls[id].strength = strength
		strength.tooltip_text = "Display extinction strength per world unit after the independent opacity mapping. Not a calibrated physical quantity; color normalization does not change this value."
		var step := _number(rendering,"Ray step",states[id].step,.05,10,.05,func(v):states[id].step = v;resample())
		panel_controls[id].step = step
		step.tooltip_text = "Ray step in world units. Smaller steps improve integration detail at greater cost; larger steps can miss fine structure. Not a brightness control. The renderer may enlarge steps to fit its 1024-step cap."
		var slice_body := _tool_body("Slice",id)
		var slice_choice := OptionButton.new()
		for name in ["No slice","XY","XZ","YZ","Oblique"]:slice_choice.add_item(name)
		slice_body.add_child(slice_choice)
		if states[id].slice:
			var normal := Reader.vec(states[id].slice_normal)
			slice_choice.select(1 if normal.is_equal_approx(Vector3.BACK) else (2 if normal.is_equal_approx(Vector3.UP) else (3 if normal.is_equal_approx(Vector3.RIGHT) else 4)))
		slice_choice.item_selected.connect(func(i):states[id].slice = i != 0;states[id].slice_normal = [[0.,0.,1.],[0.,0.,1.],[0.,1.,0.],[1.,0.,0.],[.577350269,.577350269,.577350269]][i];resample())
		for axis in range(3):
			_number(slice_body,"Plane normal "+["X","Y","Z"][axis],states[id].slice_normal[axis],-1,1,.01,func(v):
				var n := Reader.vec(states[id].slice_normal);n[axis] = v
				if n.length() < .001:return
				n = n.normalized();states[id].slice_normal = [n.x,n.y,n.z];states[id].slice = true;resample())
		_number(slice_body,"Slice plane distance • world",states[id].slice_distance,-10000,10000,.1,func(v):states[id].slice_distance = v;resample())
		var clip := CheckButton.new();clip.text = "Clip at world X plane";clip.button_pressed = states[id].clip;_tool_body("Clipping",id).add_child(clip);clip.toggled.connect(func(v):states[id].clip = v;resample())
		_number(_tool_body("Clipping",id),"Clip X",states[id].clip_distance,-10000,10000,.1,func(v):states[id].clip_distance = v;resample())
		_scalar_input(_tool_body("Isosurface",id),"Isosurface threshold",states[id].threshold,func(v):return _set_threshold(id,v))
		viewer._button(_tool_body("Isosurface",id),"Extract isosurface",func():request_iso(id))
		viewer._button(_tool_body("Isosurface",id),"Remove isosurface",func():
			states[id].isosurface = false;_sync_iso_target())
	var probe_body := _tool_body("Source probe")
	var volume_choice := OptionButton.new();probe_body.add_child(volume_choice)
	for id in reader.objects:
		if reader.objects[id].kind == "volume":volume_choice.add_item(id)
	for i in range(volume_choice.item_count):
		if volume_choice.get_item_text(i) == selected_volume:volume_choice.select(i)
	volume_choice.item_selected.connect(func(i):selected_volume = volume_choice.get_item_text(i); refresh_probe_channels())
	probe_channel_label = Label.new(); probe_channel_label.text = "Channel"; probe_body.add_child(probe_channel_label)
	probe_channel_choice = OptionButton.new();probe_body.add_child(probe_channel_choice)
	probe_channel_choice.item_selected.connect(func(i):probe_channel = probe_channel_choice.get_item_text(i))
	refresh_probe_channels()
	var probe_title := Label.new();probe_title.text = "Source probe • world xyz";probe_body.add_child(probe_title)
	for axis in ["X","Y","Z"]:probe_spins.append(_number(probe_body,axis,0,-1e12,1e12,.1,func(_v):pass))
	viewer._button(probe_body,"Probe selected volume",probe_selected_volume)
	probe_label = Label.new();probe_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;probe_body.add_child(probe_label)
	probe_stamp_label = Label.new();probe_stamp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;probe_body.add_child(probe_stamp_label)
	viewer.tools_ui.configure_layer_tools(self)
	for id in color_controls:
		for title in ["Quick setup","Derive range","Slice","Clipping","Isosurface"]:
			var target_body: VBoxContainer = tool_bodies[title+":"+id]
			var context_label := Label.new();context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			context_label.set_meta("tool_object",id);target_body.add_child(context_label);target_body.move_child(context_label,1)
	iso_status = Label.new();iso_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;_tool_body("Isosurface").add_child(iso_status)
	for body in tool_bodies.values(): viewer.tools_ui.shorten_copy(body)
	for kind in object_choices:
		var choice: OptionButton = object_choices[kind]
		if choice.item_count > 0:
			var id: String = selected_objects.get(kind,"")
			choose_object(kind,id if object_bodies.has(id) else str(choice.get_item_metadata(0)))
	preload("res://ui/shell/panel_group.gd").fit(panel)
	preload("res://analysis/ui_controls.gd").fit(panel)
	show_category(viewer.shell.workspace)
# Probe result/position and marker preference are session state, not recipe state.
func set_probe_marker_enabled(enabled: bool) -> void:
	probe_marker_enabled = enabled
	if is_instance_valid(probe_marker):probe_marker.visible = enabled and probe_marker_valid
func probe_selected_volume() -> void:
	if selected_volume.is_empty() or not views.has(selected_volume):return
	var position := Vector3(probe_spins[0].value,probe_spins[1].value,probe_spins[2].value)
	var view = views[selected_volume]
	var value = view.probe(position,probe_channel)
	probe_stamp = {"capture":reader.source_path,"uuid":reader.metadata.uuid,"extent":reader.scan_offset,"object":selected_volume,"channel":probe_channel,"position":position,"key":view.key,"time":view.data.get("time")}

	if not is_instance_valid(probe_marker):
		probe_marker = MeshInstance3D.new();probe_marker.name = "SourceProbeMarker";add_child(probe_marker)
	var lines := PackedVector3Array()
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:lines.append_array(PackedVector3Array([position-axis*.35,position+axis*.35]))
	probe_marker.mesh = preload("res://scene/geometry.gd").lines(lines,Color.WHITE)
	probe_marker_valid = value != null;set_probe_marker_enabled(probe_marker_enabled)
	probe_label.tooltip_text = "The chosen channel must be present in the prepared field sample, and coordinates must fall inside its finite source support. Probe does not prepare hidden fields or change display channels."
	probe_label.text = "Unavailable" if value == null else "%s = %s %s" % [probe_channel,JSON.stringify(value,"",true,true),reader.objects[selected_volume].units]
	refresh_probe_stamp()

func refresh_probe_channels() -> void:
	if not is_instance_valid(probe_channel_choice):return
	probe_channel_choice.clear()
	if selected_volume.is_empty():return
	var channels := {}
	for array in reader.known_arrays(selected_volume):channels[array.name] = true
	for channel in channels:probe_channel_choice.add_item(channel)
	if not channels.has(probe_channel):probe_channel = states[selected_volume].channel
	for i in probe_channel_choice.item_count:
		if probe_channel_choice.get_item_text(i) == probe_channel:probe_channel_choice.select(i)

func refresh_probe_stamp() -> void:
	for body in tool_bodies.values():
		for child in body.get_children():
			if child.has_meta("tool_object"):
				var id: String = child.get_meta("tool_object")
				var field = views[id]
				child.text = "Channel: %s · source time %s" % [states[id].channel,str(field.data.get("time","unavailable"))]
	if not is_instance_valid(probe_stamp_label):return
	var view = views.get(selected_volume)
	if probe_stamp.is_empty():return
	var position := Vector3(probe_spins[0].value,probe_spins[1].value,probe_spins[2].value)
	var stale: bool = view == null or selected_volume != probe_stamp.object or view.key != probe_stamp.key or probe_channel != probe_stamp.channel or position != probe_stamp.position
	probe_stamp_label.text = "%s\n%s · %s\nWorld %s · source time %s%s" % [str(probe_stamp.capture).get_file(),probe_stamp.object,probe_stamp.channel,str(probe_stamp.position),str(probe_stamp.time),"\n⚠ Context changed; press Probe to sample again" if stale else ""]
	probe_stamp_label.tooltip_text = "%s\nCapture %s · committed bytes %s" % [probe_stamp.capture,probe_stamp.uuid,str(probe_stamp.extent)]

func snapshot() -> Dictionary: return {"gpu_budget_mib":gpu_budget_mib,"layers":states.duplicate(true),"legend_visibility":legend_visibility.duplicate()}
func upgrade_state(value: Dictionary) -> Dictionary:
	var upgraded := value.duplicate(true)
	for id in upgraded.get("layers",{}):
		var layer = upgraded.layers[id]
		if reader.objects.has(id) and reader.objects[id].kind == "volume" and layer is Dictionary and not layer.has("opacity_mapping") and layer.has_all(["lower","upper"]):
			layer.opacity_mapping = Opacity.resolve(layer)
		if reader.objects.has(id) and reader.objects[id].kind == "volume" and layer is Dictionary and not layer.has("color_mapping"):
			layer.color_mapping = ColorMapping.DEFAULT.duplicate()
	return upgraded
func validate_state(value, requested_time = null) -> String:
	if not value is Dictionary or not value.get("layers") is Dictionary or not Reader.Index.whole(value.get("gpu_budget_mib")) or value.gpu_budget_mib < 1 or value.gpu_budget_mib > 2048: return "Invalid layer budget/state."
	if not value.get("legend_visibility",{}) is Dictionary: return "Invalid legend preferences."
	for id in value.get("legend_visibility",{}):
		if not states.has(id) or not value.legend_visibility[id] is bool: return "Invalid layer legend preference."
	value = upgrade_state(value)
	if value.layers.size() != states.size() or not value.layers.has_all(states.keys()):return "Scene layer state differs from source objects."
	var visible_volumes := 0;var surfaces := 0
	for id in states:
		var incoming = value.layers[id]
		if not incoming is Dictionary or incoming.size() != states[id].size():return "Invalid layer state fields."
		for key in states[id]:
			if not incoming.has(key) or not preload("res://scene/inspection_state.gd").shape(incoming[key],states[id][key]):return "Invalid layer state: "+key
		var names := {"":true} if reader.objects[id].kind == "mesh" or not incoming.visible else {}
		# Recipe application is an explicit request; resolve its requested-time schema.
		var point: Dictionary = reader.bracket(id,viewer.requested_time if requested_time == null else float(requested_time))
		if not point.is_empty() and not incoming.channel.is_empty():reader.describe(id,point.a)
		for a in reader.known_arrays(id):
			if reader.objects[id].kind == "volume" or (a.shape.size() == 1 and a.name != "vertex_id"):names[a.name] = true
		if not names.has(incoming.channel):return "Unknown layer scalar channel."
		if incoming.upper <= incoming.lower or not viewer.colormaps.has(incoming.colormap):return "Invalid layer range/colormap."
		if reader.objects[id].kind == "volume":
			var color_problem := ColorMapping.validate(incoming)
			if not color_problem.is_empty():return color_problem
			var opacity_problem := Opacity.validate(incoming.opacity_mapping)
			if not opacity_problem.is_empty():return opacity_problem
			if incoming.opacity < 0 or incoming.opacity > 10 or incoming.step < .05 or incoming.step > 10 or Reader.vec(incoming.slice_normal).length() < .001: return "Invalid volume controls."
			if absf(Reader.vec(incoming.slice_normal).length()-1)>1e-5 or absf(Reader.vec(incoming.clip_normal).length()-1)>1e-5:return "Plane normals must be unit length."
			if incoming.visible and incoming.volume:visible_volumes += 1
			if incoming.isosurface:surfaces += 1
	if surfaces>1:return "One extracted surface may be active."
	if visible_volumes>1:return "Only one translucent volume may be visible."
	return ""
func apply_state(value: Dictionary) -> void:
	range_request = {} # A recipe/reset invalidates any pending derived range.
	# Layer controls are rebuilt, but probe inputs/results and disclosure state
	# belong to the current session, not the recipe's rendering-layer snapshot.
	var probe_values: Array = probe_spins.map(func(spin):return spin.value)
	var probe_text := probe_label.text if is_instance_valid(probe_label) else ""
	var expanded := {}
	for id in panel_groups:
		if is_instance_valid(panel_groups[id]):expanded[id] = panel_groups[id].button_pressed
	value = upgrade_state(value)
	gpu_budget_mib = int(value.gpu_budget_mib);states = value.layers.duplicate(true)
	legend_visibility = value.get("legend_visibility",{}).duplicate()
	if is_instance_valid(panel):panel.get_parent().remove_child(panel);panel.queue_free()
	labels.clear();probe_spins.clear();panel_groups.clear();opacity_controls.clear();color_controls.clear();preset_controls.clear();_build_ui()
	for i in range(mini(probe_values.size(),probe_spins.size())):probe_spins[i].set_value_no_signal(probe_values[i])
	probe_label.text = probe_text
	for id in expanded:
		if panel_groups.has(id):panel_groups[id].button_pressed = expanded[id]
	resample()
func request_iso(id: String) -> void:
	for other in states:
		if states[other].has("isosurface"):states[other].isosurface = other == id
	iso_error = "";iso_finished_target = "";resample();_sync_iso_target();iso_debounce = 0;_start_iso()
func _sync_iso_target() -> void:
	if is_instance_valid(iso_node) and iso_node.gpu_bytes > layer_budget:
		iso_node.clear();iso_target = "";iso_finished_target = "";iso_result = {}
	var target := "";var id := ""
	for candidate in states:
		if states[candidate].get("isosurface",false) and states[candidate].visible and current.has(candidate):
			id = candidate;target = "%s/%s/%s/%s/%s" % [generation,id,current[id].a.sequence,states[id].channel,JSON.stringify(states[id].threshold,"",true,true)]
	if target != iso_target:
		cancel_iso();iso_target = target;iso_id = id;iso_result = {};iso_error = ""
		if is_instance_valid(iso_node):iso_node.clear();iso_node.visible = false
		iso_debounce = .25 if not target.is_empty() else 0.0
	if not target.is_empty() and target == iso_finished_target and not iso_result.is_empty() and is_instance_valid(iso_node):
		iso_node.visible = true;viewer.committed_sample.isosurface = iso_result.provenance.duplicate(true)
	elif not target.is_empty():viewer.committed_sample.isosurface_status = "pending" if iso_error.is_empty() else "unavailable"
func _start_iso() -> void:
	if iso_target.is_empty() or iso_pid > 0 or iso_finished_target == iso_target:return
	if viewer.selection_controller != null and viewer.selection_controller.jobs.busy():
		iso_debounce = .1;return
	if identity_generation != generation:
		source_identity = preload("res://scene/inspection_state.gd").identity(viewer);identity_generation = generation
	iso_directory = reader.cache_dir.path_join("surface-jobs/%d-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec(),iso_request_serial]);DirAccess.make_dir_recursive_absolute(iso_directory)
	var job := {"source":reader.source_path,"sha256":source_identity.sha256,"extent":source_identity.committed_bytes,"object":iso_id,"index":current[iso_id].a.source_index,"channel":states[iso_id].channel,"threshold":states[iso_id].threshold,"cache":reader.cache_dir.path_join("surfaces"),"request":iso_target}
	preload("res://video/render_job.gd").write_json(iso_directory.path_join("job.json"),job)
	iso_pid = OS.create_process("/usr/bin/env",PackedStringArray(["OPENBLAS_NUM_THREADS=1","OMP_NUM_THREADS=1","python3",ProjectSettings.globalize_path("res://../tools/extract_surface.py"),"--job",iso_directory.path_join("job.json")]),false)
	if iso_pid <= 0:iso_error = "Could not start Python extraction worker.";iso_finished_target = iso_target
	iso_status.text = "Extracting source level set…"

func cancel_iso() -> void:
	iso_request_serial += 1
	if iso_pid>0 and OS.is_process_running(iso_pid):OS.kill(iso_pid)
	iso_pid = -1
func _poll_iso() -> void:
	if iso_pid <= 0 or OS.is_process_running(iso_pid):return
	iso_pid = -1;iso_finished_target = iso_target
	var path := iso_directory.path_join("result.json");var file := FileAccess.open(path,FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text()) if file != null and file.get_length() < 1048576 else null
	if not result is Dictionary or result.get("request") != iso_target or not result.get("ok",false):
		iso_error = result.get("error","Worker interrupted or result unavailable.") if result is Dictionary else "Worker interrupted or result unavailable."
		iso_status.text = iso_error;return
	var result_generation := generation;var result_target := iso_target
	if not refresh() or generation != result_generation or iso_target != result_target:return
	if result.get("sha256") != FileAccess.get_sha256(result.get("path","")):iso_error = "Derived surface checksum mismatch.";iso_status.text = iso_error;return
	var derived := Reader.new()
	if not derived.open(result.path):iso_error = derived.error;iso_status.text = iso_error;return
	var a := derived.read_sample("isosurface",0)
	if a.is_empty():iso_error = derived.error;iso_status.text = iso_error;return
	if not is_instance_valid(iso_node):iso_node = MeshView.new();add_child(iso_node)
	var state := {"visible":true,"channel":"","lower":0.,"upper":1.,"colormap":"viridis","wireframe":false}
	var status: String = iso_node.load_samples(derived.objects.isosurface,a,a,0,state,layer_budget,viewer.colormaps.viridis)
	derived.close()
	if status == "unavailable":iso_error = iso_node.error;iso_status.text = iso_error;return
	iso_result = result
	if result.cache_hit:iso_cache_hits += 1
	iso_status.text = "%d vertices / %d triangles • %s\nChosen level set; no material identity" % [result.vertices,result.triangles,"cached" if result.cache_hit else "extracted"]
	viewer.committed_sample.isosurface = result.provenance.duplicate(true)
func wait_for_surface() -> bool:
	var queued := Time.get_ticks_msec()
	while viewer.selection_controller != null and viewer.selection_controller.jobs.busy():
		if Time.get_ticks_msec()-queued > 150000:iso_error = "Analysis queue wait timed out.";return false
		await get_tree().create_timer(.05).timeout
	_sync_iso_target();iso_debounce = 0;_start_iso()
	var started := Time.get_ticks_msec()
	while iso_pid > 0:
		_poll_iso()
		if Time.get_ticks_msec()-started > 150000:cancel_iso();iso_error = "Extraction timed out.";return false
		await get_tree().create_timer(.05).timeout
	if not iso_result.is_empty():viewer.committed_sample.isosurface = iso_result.provenance.duplicate(true)
	return iso_error.is_empty()


func particle_frame_at_union(index: int):
	if index < 0 or index >= reader.frames.size():return null
	var time: float = reader.frames[index].time
	if not particle_id.is_empty():
		var point: Dictionary = reader.bracket(particle_id,time)
		if not point.is_empty():return viewer._frame_from_data(reader.read_sample(particle_id,point.a),point.a)
	var frame = viewer.FrameData.new();frame.sim_time = time;frame.channels = {"position":PackedFloat32Array()};frame.components = {"position":3}
	return frame

func frame_scene() -> void:
	var low := Vector3(INF,INF,INF);var high := Vector3(-INF,-INF,-INF)
	if viewer.frame_a != null:
		for p in viewer.frame_a.positions:
			if p.is_finite():low = low.min(p);high = high.max(p)
	for id in views:
		if views[id] is GridView and not views[id].data.is_empty():
			var grid = views[id];var tx: Transform3D = grid.world_to_grid.affine_inverse()
			for x in [grid.bounds_min.x,grid.bounds_max.x]:
				for y in [grid.bounds_min.y,grid.bounds_max.y]:
					for z in [grid.bounds_min.z,grid.bounds_max.z]:
						var p: Vector3 = tx*Vector3(x,y,z);low = low.min(p);high = high.max(p)
		elif views[id] is MeshView:
			for point in views[id].source_positions:
				var p: Vector3 = views[id].transform*point;low = low.min(p);high = high.max(p)
	if not low.is_finite() or not high.is_finite():return
	viewer.camera_target = (low+high)*.5;viewer.half_extent = maxf((high-low).length()*.5,.1)
	viewer.camera_distance = viewer.half_extent*2.8;viewer.camera.far = maxf(1000,viewer.camera_distance*5);viewer._update_camera()

func _set_color_normalization(id: String, mode: String) -> bool:
	var candidate: Dictionary = states[id].duplicate(true);candidate.color_mapping.normalization = mode
	var problem := ColorMapping.validate(candidate)
	if problem.is_empty():problem = ColorMapping.sample_problem(candidate,views[id].color_stats)
	if not problem.is_empty():viewer.status_label.text = problem;return false
	states[id] = candidate;resample();return true
func _build_color_ui(body: VBoxContainer, id: String) -> void:
	var mode := OptionButton.new();mode.add_item("Linear color");mode.add_item("Logarithmic color • positive only");body.add_child(mode)
	mode.select(1 if states[id].color_mapping.normalization == "log" else 0)
	mode.tooltip_text = "Display-only normalization. Opacity remains independent. Log requires positive bounds and positive finite source samples; invalid samples are unavailable."
	mode.item_selected.connect(func(i):
		if not _set_color_normalization(id,"log" if i else "linear"):mode.select(1 if states[id].color_mapping.normalization == "log" else 0))
	var derive := _tool_body("Derive range",id)
	var symmetric := Button.new();symmetric.text = "Freeze symmetric range from sample";derive.add_child(symmetric)
	symmetric.pressed.connect(func():request_color_range(id,"symmetric"))
	var low := _number(derive,"Lower percentile • display choice",states[id].color_mapping.percentile_low,0,100,.1,func(_v):pass)
	var high := _number(derive,"Upper percentile • display choice",states[id].color_mapping.percentile_high,0,100,.1,func(_v):pass)
	var percent := Button.new();percent.text = "Freeze percentile range from sample";derive.add_child(percent)
	percent.pressed.connect(func():request_color_range(id,"percentile",low.value,high.value))
	var reset := Button.new();reset.text = "Reset color • linear 0–1";derive.add_child(reset)
	reset.pressed.connect(func():
		states[id].lower = 0.;states[id].upper = 1.;states[id].color_mapping = ColorMapping.DEFAULT.duplicate();apply_state(snapshot()))
	var status := Label.new();status.hide();body.add_child(status)
	var indicator := Label.new();indicator.hide();body.add_child(indicator)
	indicator.tooltip_text = "Open Details for source ranges and color diagnostics."
	color_controls[id] = {"mode":mode,"symmetric":symmetric,"percentile_low":low,"percentile_high":high,"percentile":percent,"reset":reset,"status":status,"indicator":indicator}
	for spin in [low,high]:spin.value_changed.connect(func(_v):_update_preset_description(id))
	_update_preset_description(id)
	_update_color_status(id)
func _update_color_status(id: String) -> void:
	if not color_controls.has(id):return
	var state: Dictionary = states[id];var m: Dictionary = state.color_mapping
	var description := "%s color • %s range • fixed across playback.\n" % [m.normalization,m.policy]
	if not m.source_channel.is_empty():description += "Derived from %s @ %s; display choice.\n" % [m.source_channel,str(m.source_time)]
	description += "Clipping: values below %s / above %s use endpoint colors." % [str(state.lower),str(state.upper)]
	var view = views[id];var stats: Dictionary = view.color_stats
	if stats.get("finite",0)>0:
		description += "\nSource finite range: %s to %s." % [str(stats.minimum),str(stats.maximum)]
		if stats.minimum < state.lower or stats.maximum > state.upper:description += " COLOR CLIPPING PRESENT."
	if not view.color_error.is_empty():description += "\n"+view.color_error
	color_controls[id].status.text = description
	var indicator: Label = color_controls[id].indicator
	var clipped: bool = stats.get("finite",0)>0 and (stats.minimum < state.lower or stats.maximum > state.upper)
	indicator.text = "⚠ Color unavailable" if not view.color_error.is_empty() else "⚠ Color clipping"
	indicator.visible = clipped or not view.color_error.is_empty()
func request_color_range(id: String, policy: String, low := 1.0, high := 99.0, preset := "") -> bool:
	if range_thread.is_started():viewer.status_label.text = "A range calculation is already running.";return false
	var view = views[id]
	if view.data.is_empty() or view.channel != states[id].channel:viewer.status_label.text = "Show and sample the volume first.";return false
	if policy not in ["symmetric","percentile"] or not is_finite(low) or not is_finite(high) or low<0 or high>100 or low>=high:viewer.status_label.text = "Invalid range policy or percentiles.";return false
	var values = view.data.channels[view.channel]
	var memory := preload("res://layers/playback_buffer.gd").memory_headroom()
	if values.size()>ColorMapping.MAX_VALUES or memory.available_physical < memory.reserve+values.size()*16:
		viewer.status_label.text = "Range calculation exceeds its bounded memory budget; use manual bounds.";return false
	range_request = {"id":id,"key":view.key,"generation":generation,"state":states[id].duplicate(true),"time":view.data.time,"policy":policy,"low":low,"high":high,"preset":preset}
	var status := range_thread.start(func():return ColorMapping.derive(values,policy,low,high),Thread.PRIORITY_LOW)
	if status != OK:range_request = {};viewer.status_label.text = "Could not start range calculation.";return false
	viewer.status_label.text = "Calculating a frozen display range from the current source sample…";return true
func _process(_delta: float) -> void:
	if not range_thread.is_started() or range_thread.is_alive():return
	var result: Dictionary = range_thread.wait_to_finish();var request := range_request;range_request = {}
	if request.is_empty():return
	var id: String = request.id
	if generation != request.generation or not states.has(id) or views[id].key != request.key or states[id] != request.state:
		viewer.status_label.text = "Range result discarded because the sample or settings changed.";return
	if result.has("error"):viewer.status_label.text = result.error;return
	var candidate: Dictionary = states[id].duplicate(true)
	candidate.lower = result.lower;candidate.upper = result.upper
	candidate.color_mapping.policy = request.policy;candidate.color_mapping.source_channel = candidate.channel;candidate.color_mapping.source_time = request.time
	candidate.color_mapping.percentile_low = request.low;candidate.color_mapping.percentile_high = request.high
	if not request.preset.is_empty():
		var resolved := VolumePresets.resolve(states[id],request.preset,result,request.time,request.low,request.high)
		if resolved.has("error"):viewer.status_label.text = resolved.error;return
		candidate = resolved.state
	var problem := ColorMapping.validate(candidate)
	if not problem.is_empty():viewer.status_label.text = problem;return
	states[id] = candidate;apply_state(snapshot())
	viewer.status_label.text = "Display range frozen from the recorded sample. Opacity unchanged." if request.preset.is_empty() else "Display preset applied: linear color [%s, %s], %s; %s opacity [0, %s]. Strength %s and ray step %s unchanged. Manual controls remain available." % [str(candidate.lower),str(candidate.upper),candidate.colormap,candidate.opacity_mapping.mode,str(candidate.opacity_mapping.upper),str(candidate.opacity),str(candidate.step)]

func _build_preset_ui(body: VBoxContainer, id: String) -> void:
	var title := Label.new();title.text = "Volume display preset • optional action";body.add_child(title)
	var help := Button.new();help.text = "What do these controls change?";help.toggle_mode = true;body.add_child(help)
	var guide := Label.new();guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;guide.visible = false
	guide.text = "Color range/normalization maps values to colors. Opacity mapping controls extinction. Ray step controls integration quality/cost, not brightness. Particle visibility can obscure fields; adjust it separately. The scene Viewing preset controls presentation/background and particle style. These are display choices, not calibrated science."
	body.add_child(guide);help.hide();guide.hide();title.tooltip_text = guide.text;help.toggled.connect(func(v):guide.visible = v)
	var choice := OptionButton.new()
	for name in ["Dense core","Faint structure","Signed field"]:choice.add_item(name)
	choice.tooltip_text = "Choose an action, then Apply. This is not an active mode; resolved settings below remain authoritative."
	body.add_child(choice)
	var description := Label.new();description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;body.add_child(description)
	choice.item_selected.connect(func(_i):_update_preset_description(id))
	var apply := Button.new();apply.text = "Apply volume display preset from sample";body.add_child(apply)
	apply.pressed.connect(func():request_volume_preset(id,VolumePresets.IDS[choice.selected],color_controls[id].percentile_low.value,color_controls[id].percentile_high.value))
	preset_controls[id] = {"choice":choice,"description":description,"apply":apply,"guide":title,"help":help}
func _update_preset_description(id: String) -> void:
	if not preset_controls.has(id) or not color_controls.has(id):return
	var controls: Dictionary = preset_controls[id];var selected: int = controls.choice.selected
	var text: String = VolumePresets.HELP[selected]
	if VolumePresets.IDS[selected] == "faint_structure":
		text = text.replace("the percentile entries below","P%s–P%s (edit percentile entries below)" % [str(color_controls[id].percentile_low.value),str(color_controls[id].percentile_high.value)])
	controls.description.tooltip_text = text+" Freezes color and opacity thresholds together. Keeps strength, ray step, particles and scene viewing preset. Manual controls remain available; not calibrated science."
	var problem: String = VolumePresets.problem(VolumePresets.IDS[selected],views[id].color_stats)
	controls.description.text = problem if not problem.is_empty() else "One-time display action"
	var group = viewer.tools_ui.shared_percentiles.get(id)
	if is_instance_valid(group) and viewer.tools_ui.current == "Quick setup":group.visible = selected == 1
func request_volume_preset(id: String, preset: String, low := 1.0, high := 99.0) -> bool:
	var problem := VolumePresets.problem(preset,views[id].color_stats)
	if not problem.is_empty():viewer.status_label.text = problem;return false
	if preset != "faint_structure":low = 0.;high = 100.
	return request_color_range(id,"symmetric" if preset == "signed_field" else "percentile",low,high,preset)
