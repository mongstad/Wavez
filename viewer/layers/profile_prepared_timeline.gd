extends SceneTree
## Read-only retained-capture replay. Optional deterministic particle publication
## barrier exercises the existing underflow gate without changing cache policy.
const Memory = preload("res://layers/playback_memory.gd")
func _initialize() -> void:run.call_deferred()
func snapshot(view) -> Dictionary:
	view.timeline.refresh(view,true)
	var layers = view.scene_layers;var ps: Dictionary = layers.playback.worker.status();var fs: Dictionary = layers.field_playback.worker.status()
	var pairs := []
	for index in ps.ready_indices:
		var rows: Array = layers.reader.samples[layers.particle_id]
		pairs.append({"index":index,"a_sequence":rows[index].sequence,"b_sequence":rows[mini(index+1,rows.size()-1)].sequence,"start":rows[index].time,"end":rows[mini(index+1,rows.size()-1)].time})
	return {"wall":Time.get_ticks_msec()/1000.,"time":view.requested_time,"committed":view.committed_sample.get("requested_time"),"playing":view.playing,"coverage":view.timeline.coverage.duplicate(true),"particle_target":layers.playback.pending_time if layers.playback.pending_time != null else view.requested_time,"particle_target_index":layers.playback.last_target,"particle_pairs":pairs,"particles":ps,"field_keys":fs.charges.keys(),"reason":layers.transport_wait_reason,"error":layers.error,"memory":Memory.snapshot()}
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var report := FileAccess.open(args[1],FileAccess.WRITE)
	var view = load("res://main.gd").new();view.capture_path = args[0];view.orbit_enabled = false
	root.add_child(view);view.set_process(false);view.set_process_input(false);view.set_process_unhandled_input(false)
	view.physical_rate = 1.;view.scene_loop_playback = false
	var started := Time.get_ticks_msec();var previous := Time.get_ticks_usec();var next_log := 0
	var playing := false;var gated := false;var released := false;var first_hold := -1;var hold_saved := false
	var gate := Semaphore.new();var inject := args.size()>2 and args[2] == "--particle-barrier"
	while Time.get_ticks_msec()-started < 65000:
		await process_frame
		var now := Time.get_ticks_usec();view.scene_layers.tick((now-previous)/1000000.);previous = now
		var fs: Dictionary = view.scene_layers.field_playback.worker.status()
		var ps: Dictionary = view.scene_layers.playback.worker.status()
		if not playing and fs.active_jobs == 0 and fs.session.get("state") == "ready" and not ps.worker_active and ps.desired.all(func(i):return ps.ready_indices.has(i)):
			if Time.get_ticks_msec()-started > 3000:view.play_button.pressed.emit();playing = view.playing
		if inject and playing and not gated and view.requested_time >= 5.:
			view.scene_layers.playback.worker.test_barrier = gate;gated = true
		if gated and not released and view.scene_layers.transport_wait_reason == "Required particle content":
			if first_hold < 0:
				first_hold = Time.get_ticks_msec()
			if not hold_saved and Time.get_ticks_msec()-first_hold > 600:
				hold_saved = true
				view.timeline.refresh(view,true);view.shell.status_ui.refresh()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(args[1].get_basename()+"-hold.png")
			if Time.get_ticks_msec()-first_hold > 3000:
				view.scene_layers.playback.worker.test_barrier = null;gate.post();released = true
		if Time.get_ticks_msec() >= next_log:
			var row := snapshot(view);row.injected_barrier = inject;row.barrier_released = released
			report.store_line(JSON.stringify(row));report.flush();next_log = Time.get_ticks_msec()+200
		if playing and (not view.playing or view.requested_time >= view.generic_reader.frames[-1].time):break
	view.scene_layers.playback.worker.test_barrier = null
	if gated and not released:gate.post()
	report.store_line(JSON.stringify(snapshot(view)));report.close();view.free();await process_frame;quit()
