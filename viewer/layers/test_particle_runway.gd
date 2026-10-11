extends "res://layers/test_scene_playback.gd"
const Buffer = preload("res://layers/playback_buffer.gd")
const Memory = preload("res://layers/playback_memory.gd")
var observations := {}
func fill(view) -> bool:
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 15000:
		view.scene_layers.tick(0)
		var p = view.scene_layers.playback;var state: Dictionary = p.worker.status()
		if p.sized and not state.worker_active and not view.scene_layers.is_buffering() and state.desired.all(func(i):return state.ready_indices.has(i)):return true
		if not state.failures.is_empty():return false
		await process_frame
	print("RUNWAY FILL TIMEOUT ",view.requested_time," p=",view.scene_layers.playback.worker.status()," field_wait=",view.scene_layers.field_playback.buffering," reason=",view.scene_layers.transport_wait_reason)
	return false
func constrain(view, pairs: int) -> void:
	var p = view.scene_layers.playback;var fs: Dictionary = view.scene_layers.field_playback.worker.status()
	var plan: Dictionary = p.worker.preparation_estimate(p.sizing_key)
	var memory := Memory.snapshot()
	var other: int = view.generic_reader.cache.limit+256*Buffer.MIB+int(fs.largest_job_charge)*3*int(fs.worker_count)
	var target: int = view.generic_reader.bracket(view.scene_layers.particle_id,view.requested_time).a
	memory.safe_cache_bytes = other+int(plan.pair_estimates[target])*2+ceili(2.*1.05*plan.largest_pair*pairs)
	p.memory_override = memory;p.budget_checked = -1000
func inspect(view, label: String) -> void:
	var p = view.scene_layers.playback;var state: Dictionary = p.worker.status()
	var desired: Array = state.desired;var used: int = int(p.estimates.largest_pair)*2
	for index in desired:used += int(p.estimates.pair_estimates[index])
	check(p.field_priority and not p.full_preload,label+" mixed rolling strategy preserved")
	check(desired.size()>8 and desired.size()<p.context.entries.size(),label+" request runway grows within a finite budget")
	check(desired[0] == p.last_target and used <= p.prepared_limit,label+" target first and actual pair costs fit with two-largest-pair margin")
	check(state.prepared_bytes <= p.prepared_limit and state.decoded_bytes <= p.decoded_limit,label+" both resident cache charges bounded")
	check(state.desired.all(func(i):return state.ready_indices.has(i)),label+" every requested interval is actually published")
	view.timeline.refresh(view,true)
	var rows: Array = p.context.entries;var ready := {}
	for index in state.ready_indices:ready[index] = true
	var spans := preload("res://ui/shell/prepared_timeline.gd").spans(rows,ready,rows[0].time,rows[-1].time)
	check(view.timeline.coverage.scene == preload("res://ui/shell/prepared_timeline.gd").intersect(view.timeline.coverage.fields,spans),label+" scene coverage remains the real intersection")
	observations[label] = {"particle":p.profile_report(),"coverage":view.timeline.coverage.duplicate(true)}
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--playback-fixture="):out = arg.trim_prefix("--playback-fixture=")
	var view = make_view(out.path_join("mixed.wvz"),true)
	view.set_process_input(false);view.set_process_unhandled_input(false)
	var p = view.scene_layers.playback
	check(not view.playing and not view.committed_sample.is_empty(),"opening remains immediately usable and paused")
	check(await fill(view),"mixed worker publishes validated sizing after lazy startup")
	check(p.sized and p.estimates.pair_estimates.size() == 81,"all mixed descriptor costs available")
	check(p.estimates.pair_estimates.max() > p.estimates.pair_estimates.min()*2,"variable-count fixture exercises unequal pair costs")
	check(p.decoded_limit+p.prepared_limit == 2048*Buffer.MIB and p.decoded_limit == p.prepared_limit,"existing mixed 2 GiB and 50/50 reservation unchanged")
	constrain(view,12);check(view._seek_time(0),"bounded forward seek accepted")
	check(await fill(view),"bounded forward runway settles")
	inspect(view,"forward")
	check(view.timeline.coverage.scene[0][1] > .8,"prepared source seconds exceed the old eight-pair lead")
	var before: Dictionary = p.worker.status();var desired: Array = before.desired
	check(view._seek_time(float(p.context.entries[desired[2]].time)),"resident scrub accepted")
	view.scene_layers.tick(0)
	check(not view.scene_layers.is_buffering(),"resident scrub commits immediately")
	check(p.worker.status().prepared_misses == before.prepared_misses,"resident scrub avoids prepared misses")
	check(view._seek_time(6) and await fill(view),"distant forward scrub prepares its new directional runway")
	check(view._seek_time(4) and await fill(view),"reverse scrub prepares its new directional runway")
	inspect(view,"reverse")
	check(p.worker.status().desired[1] == p.last_target-1,"reverse prioritizes adjacent source intervals")
	view.scene_loop_playback = true;p.direction = 1;check(view._seek_time(7.9) and await fill(view),"loop-edge runway settles")
	var loop_desired: Array = p.worker.status().desired
	check(loop_desired[0] == 79 and loop_desired[1] == 80 and loop_desired[2] == 0,"loop prioritizes traversal through the endpoint")
	view.scene_loop_playback = false;p.set_policy("512")
	check(await fill(view) and p.worker.status().desired.size() <= 8,"manual rolling request behavior preserved")
	p.set_policy("adaptive");check(view._seek_time(0) and await fill(view),"automatic bounded runway recovers")
	var minimal: Dictionary = p.memory_override.duplicate();minimal.safe_cache_bytes = 0
	p.memory_override = minimal;p.budget_checked = -1000
	var began := Time.get_ticks_msec()
	while Time.get_ticks_msec()-began < 5000:
		view.scene_layers.tick(0);await process_frame
		if p.worker.status().decoded_bytes == 0 and p.worker.status().prepared_pairs <= 2:break
	check(p.worker.status().decoded_bytes == 0 and p.worker.status().prepared_pairs <= 2,"genuine budget reduction reclaims idle history")
	check(not view.committed_sample.is_empty(),"pressure retains the displayed scientific sample")
	constrain(view,12);check(await fill(view),"rolling runway recovers from pressure")
	view.trails_enabled = true;view.clean_view = false;p.memory_override = {};p.budget_checked = -1000
	check(view._seek_time(4) and await fill(view),"trail configuration sizes and prepares the new representation")
	constrain(view,12);check(await fill(view),"trail history fits a reduced safe budget")
	inspect(view,"trails")
	view.particle_layer_visible = false;view.scene_layers.tick(0)
	check(p.worker.status().desired.is_empty(),"hidden particles cancel preparation")
	view.particle_layer_visible = true;check(await fill(view),"reveal reuses or prepares the required configuration")
	check(view.scene_layers.error.is_empty() and p.worker.status().failures.is_empty(),"no scientific playback or worker errors")
	Job.write_json(out.path_join("particle-runway.json"),{"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"packaged":not OS.has_feature("editor")})
	view.free();await process_frame
	print("PARTICLE RUNWAY: ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
