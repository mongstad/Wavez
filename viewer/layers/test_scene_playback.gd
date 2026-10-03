extends SceneTree
const Profile = preload("res://scene/playback_profile.gd")
const Inspection = preload("res://scene/inspection_state.gd")
const Hash = preload("res://data/capture_index.gd")
const Job = preload("res://video/render_job.gd")
var checks := 0
var failures: Array = []
var out := ""
func check(ok: bool, name: String) -> void:
	checks += 1
	if not ok:failures.append(name);push_error(name)
func _initialize() -> void:run.call_deferred()
func make_view(path: String, asynchronous: bool):
	var view = load("res://main.gd").new()
	view.capture_path = path;view.playing = false;view.orbit_enabled = false
	view.scene_prebuffer_enabled = asynchronous;view.scene_hidden_fast_path = asynchronous
	root.add_child(view);view.set_process(false)
	view._set_clean(true)
	return view
func sample(view, time: float, asynchronous: bool) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 10000:
		var result: Dictionary = view.scene_layers.sample(time,asynchronous)
		if result.is_empty():return false
		if not result.has("pending"):
			view.scene_layers.playback.buffering = false;view.scene_layers.playback.pending_time = null
			return true
		await process_frame
	return false
func compare(a,b,label: String) -> void:
	check(a.committed_sample==b.committed_sample,label+" committed sampling/source times")
	check(a.current_mm.buffer.to_byte_array()==b.current_mm.buffer.to_byte_array(),label+" packed GPU buffer")
	check(a.frame_a.channels==b.frame_a.channels,label+" original typed channels")
	check(a.frame_a.ids==b.frame_a.ids,label+" persistent IDs remain int64")
	check(a.current_index==b.current_index and a.phase==b.phase and a.timeline.value==b.timeline.value,label+" union clock")
	check(a.history.map(func(fr):return fr.source_index)==b.history.map(func(fr):return fr.source_index),label+" history indices")
	for layer in range(a.TRAIL_LAYERS):
		check(a.trail_mms[layer].instance_count==b.trail_mms[layer].instance_count and a.trail_mms[layer].buffer.to_byte_array()==b.trail_mms[layer].buffer.to_byte_array(),label+" trail "+str(layer))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-fixture="):out = arg.trim_prefix("--playback-fixture=")
	if out.is_empty():push_error("Missing fixture");quit(1);return
	for name in ["ids","anonymous","zstd"]:
		var reference = make_view(out.path_join(name+".wvz"),false)
		var buffered = make_view(out.path_join(name+".wvz"),true)
		check(buffered.scene_layers.playback.enabled,"real CPU worker enabled "+name)
		for mapping in ["fixed","scalar","visual_color","velocity_magnitude","log_scalar","cyclic_scalar"]:
			for view in [reference,buffered]:
				view.color_channel = "scalar" if mapping in ["log_scalar","cyclic_scalar"] else mapping;view.size_channel = "visual_size";view.brightness_channel = "visual_brightness"
				view.hidden_types = {2:true};view.trails_enabled = name!="anonymous";view.clean_view = false
				view.normalization_mode = "symmetric";view.auto_range = true;view.logarithmic = false;view.cyclic = false;view.invert_map = false
				if mapping == "log_scalar":view.normalization_mode = "frame";view.logarithmic = true
				if mapping == "cyclic_scalar":view.auto_range = false;view.normalization_mode = "manual";view.cyclic = true;view.manual_min = -.5;view.manual_max = .5;view.invert_map = true
				view.scene_layers.particle_key = ""
			for time in [0.0,.2,.5,.9,1.25,1.75,2.75,3.5,4.0,.35]:
				check(await sample(reference,time,false),"reference sample")
				check(await sample(buffered,time,true),"buffered sample")
				compare(reference,buffered,name+"/"+mapping+"/"+str(time))
		# Hidden playback performs metadata bookkeeping without touching payloads.
		for id in buffered.scene_layers.states:buffered.scene_layers.states[id].visible = false
		buffered.particle_layer_visible = false
		Profile.enabled = true;Profile.reset()
		check(await sample(buffered,2.125,true),"seek while hidden")
		check(not buffered.scene_layers.current.has("particles"),"hidden particles have no prepared payload")
		check(not Profile.rows.has("g3_read_sample") and not Profile.rows.has("style_inclusive") and not Profile.rows.has("interpolation_pack"),"hidden fast path skips decode/style/interpolation")
		check(buffered.requested_time==2.125 and buffered.current_index==5,"hidden seek keeps union/source clock")
		Profile.enabled = false
		# Inspection explicitly obtains scientific particle data, even while hidden.
		var inspection := Inspection.snapshot(buffered)
		check(not inspection.is_empty() and inspection.sample.requested_time==2.125,"hidden inspection obtains requested scientific sample")
		check(inspection.particle_identity.available==(name!="anonymous"),"hidden inspection identity")
		buffered.particle_layer_visible = true
		for id in buffered.scene_layers.states:buffered.scene_layers.states[id].visible = true
		check(await sample(buffered,2.125,true),"immediate hidden-to-visible reveal")
		check(await sample(reference,2.125,false),"reveal reference")
		compare(reference,buffered,name+" reveal")
		# Superseded seeks replace the requested window instead of queueing history.
		for time in [3.75,.1,2.8,.6,3.125]:check(buffered.scene_layers.seek(time),"rapid seek accepted")
		var start := Time.get_ticks_msec()
		while buffered.scene_layers.playback.buffering and Time.get_ticks_msec()-start<10000:
			buffered.scene_layers.playback.pump();await process_frame
		check(buffered.requested_time==3.125,"only final rapid seek committed")
		check(await sample(reference,3.125,false),"final seek reference")
		compare(reference,buffered,name+" final seek")
		var cache: Dictionary = buffered.scene_layers.playback.worker.status()
		check(cache.decoded_bytes<=buffered.scene_layers.playback.decoded_limit and cache.prepared_bytes<=buffered.scene_layers.playback.prepared_limit,"independent bounded RAM caches")
		reference.free();buffered.free();await process_frame
	Job.write_json(out.path_join("results.json"),{"checks":checks,"failures":failures,"scope":"CPU worker versus synchronous semantic and buffer equivalence; headless is not image acceptance."})
	print("G3 PLAYBACK: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
