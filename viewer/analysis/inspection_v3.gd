extends RefCounted
# Bounded control only. Source/asset validation runs on the existing worker.
const Visual = preload("res://scene/visual_state.gd")
const Inspection = preload("res://scene/inspection_state.gd")

static func pack(value):
	if value is float:return {"$f64":PackedFloat64Array([value]).to_byte_array().hex_encode(),"text":JSON.stringify(value,"",true,true)}
	if value is Dictionary:
		if value.has_all(["version","id","manifest_sha256"]) and value.size() == 3:return {"version":int(value.version),"id":value.id,"manifest_sha256":value.manifest_sha256}
		if value.has_all(["version","sha256","dtype","shape","bytes"]) and value.size() == 5:return {"version":int(value.version),"sha256":value.sha256,"dtype":value.dtype,"shape":value.shape.map(func(v):return int(v)),"bytes":value.bytes}
		var result := {}
		for key in value:result[key] = pack(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:result.append(pack(item))
		return result
	return value

static func unpack(value, depth := 0):
	if depth > 32:return null
	if value is Dictionary:
		if value.has("$f64"):
			if value.size() != 2 or not value.get("$f64") is String or not value.get("text") is String:return null
			var exact := preload("res://scene/source_sampling.gd").exact_float({"text":value.text,"f64_le_hex":value["$f64"]})
			return exact.value if not exact.is_empty() else null
		var result := {}
		for key in value:result[key] = unpack(value[key],depth+1)
		return result
	if value is Array:
		var result: Array = []
		for item in value:result.append(unpack(item,depth+1))
		return result
	return value

static func references(value, results: Dictionary, members: Dictionary) -> void:
	if value is Dictionary:
		if value.has_all(["version","id","manifest_sha256"]) and value.size() == 3:results[value.id] = value
		elif value.has_all(["version","sha256","dtype","shape","bytes"]) and value.size() == 5:members[value.sha256] = value
		else:
			for item in value.values():references(item,results,members)
	elif value is Array:
		for item in value:references(item,results,members)

static func snapshot(temporal, bundled_results: bool) -> Dictionary:
	var viewer = temporal.viewer
	var source: Dictionary = temporal.selections.source.duplicate(true)
	if viewer.scene_layers == null or not source.has("sha256") or viewer.committed_sample.is_empty():return {}
	var old_source := source.duplicate(true);old_source.erase("uuid");old_source.erase("complete_records");old_source.complete_frames = viewer.frame_count
	var base := {"kind":"wavez-inspection","version":2,"source":old_source,"visual":Visual.snapshot(viewer),"sample":viewer.committed_sample.duplicate(true),"frame_index":viewer.current_index,"alpha":viewer.phase,"history_indices":viewer.history.map(func(frame):return frame.source_index),"layers":viewer.scene_layers.layer_samples.duplicate(true),"selections":[]}
	var summaries: Array = temporal.summaries.duplicate(true)
	for summary in summaries:summary.erase("charged_bytes")
	var bookmarks: Array = temporal.diagnostics.bookmarks.duplicate(true)
	for bookmark in bookmarks:bookmark.erase("charged_bytes")
	var series: Dictionary = temporal.series_list.get_item_metadata(temporal.series_list.selected) if temporal.series_list.selected >= 0 else {}
	var analysis := {"summaries":summaries,"current":temporal.current_result,"left":temporal.diagnostics.left,"right":temporal.diagnostics.right,"bindings":temporal.diagnostics.bindings,"bookmarks":bookmarks,"layout":{"series":series,"member_address":temporal.member_address.text,"plot_bins":512,"heatmap_width":128,"heatmap_height":64}}
	var payload := {"base":base,"selections":temporal.selections.state.snapshot(),"analysis":analysis}
	var results := {};var members := {};references(payload,results,members)
	return {"kind":"wavez-inspection","version":3,"source":source,"payload":pack(payload),"members":members.values(),"results":results.values(),"bundled_results":bundled_results}

static func scene_snapshot(temporal) -> Dictionary:
	var recipe := snapshot(temporal,false)
	if recipe.is_empty():return {}
	var payload: Dictionary = unpack(recipe.payload)
	payload.analysis = {"summaries":[],"current":{},"left":{},"right":{},"bindings":[],"bookmarks":[],"layout":{"series":{},"member_address":"","plot_bins":512,"heatmap_width":128,"heatmap_height":64}}
	var results := {};var members := {};references(payload,results,members)
	recipe.payload = pack(payload);recipe.members = members.values();recipe.results = [];recipe.bundled_results = true
	return recipe

static func preflight(viewer, payload: Dictionary) -> String:
	if not payload.has_all(["base","selections","analysis"]) or not payload.base is Dictionary:return "Invalid v3 payload."
	var base: Dictionary = payload.base
	if not base.has_all(["visual","sample","frame_index","alpha","source"]) or not base.visual is Dictionary or not base.sample is Dictionary:return "Missing v3 visual/sample state."
	var problem := Inspection.validate_visual(viewer,base.visual)
	if not problem.is_empty():return problem
	if int(base.source.get("complete_frames",-1)) != viewer.frame_count:return "Saved extent differs from the opened view. Open the original extent; no automatic rebinding."
	if not Inspection.numeric(base.frame_index) or int(base.frame_index) != base.frame_index or base.frame_index < 0 or base.frame_index >= viewer.frame_count or not Inspection.numeric(base.alpha) or base.alpha < 0 or base.alpha > 1:return "Invalid saved visual sample."
	if viewer.scene_layers != null:
		var time = base.sample.get("requested_time")
		if not Inspection.numeric(time) or not viewer._ensure_timeline() or viewer.shared_timeline.bracket(time).is_empty():return "Saved scene time is unavailable."
	return ""

static func apply_verified(temporal, payload: Dictionary) -> String:
	var viewer = temporal.viewer
	var problem := preflight(viewer,payload)
	if not problem.is_empty():return problem
	var base: Dictionary = payload.base
	# Preflight the bounded frame pair before changing any scene state. This is
	# the existing G0–G3 single-view sample path, never an interval analysis scan.
	if viewer.scene_layers != null:
		for oid in viewer.generic_reader.objects:
			var point: Dictionary = viewer.generic_reader.bracket(oid,base.sample.requested_time)
			if point.is_empty():continue
			for index in [point.a,point.b]:
				if viewer.generic_reader.read_sample(oid,index).is_empty():return "Saved layer sample is unreadable."
	else:
		if viewer._read_frame(int(base.frame_index)) == null:return "Saved particle frame is unreadable."
	var previous := Visual.snapshot(viewer);var previous_time: float = temporal.selections._time()
	var history_frames: Array = []
	if viewer.scene_layers == null:
		if viewer._read_frame(mini(int(base.frame_index)+1,viewer.frame_count-1)) == null:return "Saved following frame is unreadable."
		for index in base.history_indices:
			var frame = viewer._read_frame(int(index))
			if frame == null or not frame.has_ids:return "Saved history requires available frames with explicit IDs."
			history_frames.append(frame)
	viewer.playing = false;viewer.inspection_paused = true
	if viewer.scene_layers != null:
		Visual.apply(viewer,base.visual)
		if viewer.scene_layers.sample(base.sample.requested_time).is_empty():
			Visual.apply(viewer,previous);viewer.scene_layers.sample(previous_time);return "Saved sample could not be committed; previous visual state restored."
	else:
		viewer._seek_frame(int(base.frame_index));Visual.apply(viewer,base.visual);viewer.history.assign(history_frames);viewer._rebuild_trails();viewer.phase = float(base.alpha);viewer._render_current(viewer.phase);viewer.requested_time = viewer.committed_sample.requested_time
	var state = temporal.selections.state
	state.definitions = payload.selections.definitions.duplicate(true);state.groups = payload.selections.groups.duplicate(true);state.active = payload.selections.active;state.overlay = payload.selections.overlay.duplicate(true);state.revision = int(payload.selections.revision)
	temporal.selections._changed()
	temporal.jobs.cancel_background();temporal.revision += 1
	temporal.summaries = payload.analysis.summaries.duplicate(true);temporal.summary_charge = 0;temporal.result_list.clear()
	for summary in temporal.summaries:
		summary.charged_bytes = JSON.stringify(summary).to_utf8_buffer().size()*8+8192;temporal.summary_charge += summary.charged_bytes
		temporal.result_list.add_item("%s • %d rows" % [summary.label,int(summary.rows)])
	temporal.current_result = payload.analysis.current.duplicate(true);temporal.current_source = {};temporal.series_list.clear();temporal.plot.clear();temporal.table.text = ""
	for i in range(temporal.summaries.size()):
		if temporal.summaries[i].result == temporal.current_result:temporal.current_source = temporal.summaries[i].source;temporal.result_list.select(i)
	var diagnostic = temporal.diagnostics
	diagnostic.left = payload.analysis.left.duplicate(true);diagnostic.right = payload.analysis.right.duplicate(true);diagnostic.bindings = payload.analysis.bindings.duplicate(true);diagnostic.bookmarks = payload.analysis.bookmarks.duplicate(true);diagnostic.bookmark_list.clear();diagnostic.overlay.clear()
	for bookmark in diagnostic.bookmarks:
		bookmark.charged_bytes = JSON.stringify(bookmark).to_utf8_buffer().size()*8+8192;temporal.summary_charge += bookmark.charged_bytes;diagnostic.bookmark_list.add_item("%s • %s" % [bookmark.label,bookmark.raw_time.text])
	var layout: Dictionary = payload.analysis.layout
	temporal.member_address.text = layout.member_address
	if not layout.series.is_empty():temporal.series_list.add_item("Restored source series");temporal.series_list.set_item_metadata(0,layout.series);temporal.series_list.select(0)
	temporal.update_pins()
	viewer._update_hud()
	return ""
