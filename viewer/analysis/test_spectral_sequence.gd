extends SceneTree
## Issue #417: exact-native replay, durable reuse, cancellation and display isolation.
const Visual = preload("res://scene/visual_state.gd")
const Exact = preload("res://scene/source_sampling.gd")
var viewer
var map
var out := ""
var capture := ""
var checks := 0
var failures: Array[String] = []
var observations := {}
var progress_seen := {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
func wait_job(seconds := 30.) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.)
	while (not map.pending_id.is_empty() or map.jobs.busy()) and Time.get_ticks_msec() < until: await create_timer(.02).timeout
	return map.pending_id.is_empty() and not map.jobs.busy()
func seek(time: float) -> bool:
	viewer.playing = false
	var accepted: bool = viewer._seek_time(time)
	var until := Time.get_ticks_msec()+10000
	while viewer.committed_sample.get("requested_time",NAN) != time and Time.get_ticks_msec() < until:
		await process_frame
	map._sync_replay(); map.refresh_context(); await settle()
	return accepted and viewer.requested_time == time and viewer.committed_sample.get("requested_time",NAN) == time
func picture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	root.get_texture().get_image().save_png(out.path_join(name+"-viewport.png"))
	if map.window.visible: map.window.get_texture().get_image().save_png(out.path_join(name+"-dialog.png"))
func space(control: Control) -> void:
	control.grab_focus()
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_SPACE; event.physical_keycode = KEY_SPACE; event.pressed = pressed
		control.get_window().push_input(event,true)
func click_control(control: Control) -> void:
	var window := control.get_window(); var point := control.get_global_rect().get_center()
	if window.is_embedded(): point += Vector2(window.position); window = root
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		window.push_input(event,true)
func key(code: Key, window: Window) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed; event.window_id = window.get_window_id(); Input.parse_input_event(event)
func preset(name: String) -> bool:
	click_control(viewer.shell.menus.View); await settle()
	var popup: PopupMenu = viewer.shell.menus.View.get_popup()
	if not popup.visible: return false
	var entry: Dictionary = viewer.shell.commands["preset:"+name]
	for index in popup.item_count:
		var child := popup.get_item_submenu(index)
		if not child.is_empty() and popup.get_node(child) == entry.popup:
			popup.set_focused_item(index); key(KEY_RIGHT,popup); await settle(); break
	var options: PopupMenu = entry.popup
	if not options.visible or options.is_item_disabled(entry.index): popup.hide(); return false
	options.set_focused_item(entry.index); key(KEY_ENTER,options); await settle()
	return viewer.selected_preset == name
func source(path: String, actual := false) -> void:
	viewer._open_capture(path); viewer.playing = false; viewer.orbit_enabled = false; await settle()
	map.open(); map.select_object("field"); map.select_channel("amplitude")
	if actual:
		map.set_grid_xyz([32,32,32],[128,128,128],"z",[1,1],[32,32]); map.band_low.text = ".05"; map.band_high.text = ".15"; map.set_sequence_range(20,22,1)
	else:
		map.set_grid_xyz([-8,-8,16],[16,16,16],"z",[5,5],[12,12]); map.band_low.text = ".4"; map.band_high.text = ".8"; map.set_sequence_range(0,2,1)
	map.refresh_context(); await settle()
func new_viewer() -> void:
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	await settle(); map = viewer.spectral_band_map
	map.jobs.spectral_band_map_progress.connect(func(value):
		if value.get("id") == map.pending_id: progress_seen = value.duplicate(true))
func prepare(label: String, seconds := 30.) -> bool:
	if map.jobs.worker_pid <= 0: map.jobs.start(out.path_join("analysis-workers"),"spectral_band_sequence")
	var began := Time.get_ticks_usec(); map.prepare_sequence()
	var callback := (Time.get_ticks_usec()-began)/1000.
	var active: bool = not map.pending_id.is_empty()
	var done := await wait_job(seconds)
	var ready: bool = done and not map.sequence_data.is_empty()
	observations[label] = {"callback_ms":callback,"roundtrip_ms":(Time.get_ticks_usec()-began)/1000.,"data":map.sequence_data.duplicate(true),"source":map.result_source.duplicate(true),"status":map.status.text,"worker_reply":map.jobs._read("background_result.json")}
	check(active and callback < 50.,label+": preparation queues asynchronously")
	check(ready,label+": complete verified sequence publishes")
	return ready
func stats(values: Array) -> Dictionary:
	var ordered := values.duplicate(); ordered.sort(); var total := 0.
	for value in values: total += value
	return {"min":ordered[0],"median":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"max":ordered[-1],"mean":total/values.size()}
func profile(show_map: bool) -> Dictionary:
	map.visibility.button_pressed = show_map; map.sync_visibility(); await settle()
	var wall: Array = []; var gpu: Array = []; var cpu: Array = []
	var yaw: float = viewer.yaw; var orbit: bool = viewer.orbit_enabled; var speed: float = viewer.orbit_speed
	viewer.orbit_enabled = true; viewer.orbit_speed = .012
	var last := Time.get_ticks_usec()
	for i in 90:
		await process_frame; await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec(); wall.append((now-last)/1000.); last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	viewer.orbit_enabled = orbit; viewer.orbit_speed = speed; viewer.yaw = yaw; viewer._update_camera()
	return {"frames":90,"wall_ms":stats(wall),"render_gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"mean_fps":1000./stats(wall).mean,"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"engine_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"engine_buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"engine_static_bytes":OS.get_static_memory_usage(),"plane_payload_bytes":map.plane.gpu_bytes,"resolution":[root.size.x,root.size.y],"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}
func replay_safe() -> bool:
	if not map.plane.visible: return true
	if map.result_data.is_empty(): return false
	var exact := Exact.exact_float(map.result_data.record.native_time)
	return not exact.is_empty() and exact.value == viewer.requested_time and viewer.committed_sample.get("requested_time",NAN) == viewer.requested_time
func playback_window(reverse: bool, looping: bool) -> Dictionary:
	viewer.scene_loop_playback = looping; viewer.physical_rate = -2. if reverse else 2.
	var start := 2.5 if reverse else 5.8 if looping else .2
	await seek(start); viewer.playing = true
	var safe := true; var frames := 0; var began := Time.get_ticks_usec(); var initial: float = viewer.requested_time
	while Time.get_ticks_usec()-began < 450000:
		await process_frame; frames += 1; safe = safe and replay_safe()
	viewer.playing = false
	var final_time: float = viewer.requested_time
	viewer.scene_loop_playback = false; viewer.physical_rate = 1.
	return {"start":initial,"finish":final_time,"frames":frames,"safe":safe,"reverse":reverse,"loop":looping}
func mutate_copy(path: String, append: bool) -> void:
	var file := FileAccess.open(path,FileAccess.READ_WRITE)
	if append: file.seek_end(); file.store_8(0)
	else:
		file.seek(file.get_length()-1); var byte := file.get_8(); file.seek(file.get_length()-1); file.store_8(byte^1)
	file.flush(); file.close()
func boundary_mutation_checks() -> void:
	var path := out.path_join("mutation-copy.wvz")
	check(DirAccess.copy_absolute(out.path_join("sequence.wvz"),path) == OK,"Mutation test uses a disposable copy outside fixture hash evidence")
	await source(path); viewer.set_process(false)
	var original_stamp: Dictionary = viewer.generic_reader.source_stamp.duplicate(true)
	viewer.generic_reader.source_stamp = {}; map.prepare_sequence(); map.prepare_sequence()
	check(not map._sequence_source_matches() and map.pending_id.is_empty() and map.jobs.worker_pid < 0,"Missing trustworthy reader stamp refuses sequence preparation")
	viewer.generic_reader.source_stamp = original_stamp; viewer.set_process(true); map.close(); viewer._close_capture()
	await source(path); viewer.set_process(false)
	mutate_copy(path,true); map.prepare_sequence()
	observations.append_boundary = {"status":map.status.text,"pending_id":map.pending_id,"worker_pid":map.jobs.worker_pid,"maps":map.sequence_data.size()}
	check(map.pending_id.is_empty() and map.sequence_data.is_empty() and map.jobs.worker_pid < 0 and map.status.text.contains("changed before"),"Source append between ordinary polls is refused before sequence enqueue")
	viewer.set_process(true); map.close(); viewer._close_capture()
	check(DirAccess.copy_absolute(out.path_join("sequence.wvz"),path) == OK,"Publication mutation test restores only its disposable source copy")
	await source(path); viewer.set_process(false)
	map.jobs.start(out.path_join("analysis-workers"),"spectral_band_sequence")
	map.prepare_sequence(); var expected_id: String = map.pending_id; map.jobs.set_process(false)
	var completed := {}; var until := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < until:
		completed = map.jobs._read("background_result.json")
		if completed.get("id") == expected_id: break
		await create_timer(.02).timeout
	check(not expected_id.is_empty() and completed.get("id") == expected_id and completed.get("ok",false),"Worker completes a verified request before the publication-boundary mutation")
	if completed.get("ok",false):
		mutate_copy(path,false); map._completed(completed)
		observations.mutation_boundary = {"status":map.status.text,"pending_id":map.pending_id,"plane_visible":map.plane.visible,"maps":map.sequence_data.size()}
		check(map.pending_id.is_empty() and map.sequence_data.is_empty() and not map.plane.visible and map.status.text.contains("changed before"),"Equal-size source mutation after worker completion prevents stale publication before the next ordinary poll")
	map.jobs.set_process(true); viewer.set_process(true); map.cancel(); await wait_job(3.)
	map.close(); viewer._close_capture()

func finish() -> void:
	if is_instance_valid(viewer):
		map.cancel(); await wait_job(3.); map.close(); viewer._close_capture(); viewer.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"device":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("SPECTRAL SEQUENCE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	create_timer(390).timeout.connect(func():push_error("Spectral sequence validation timed out"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--band-map-output="): out = arg.trim_prefix("--band-map-output=")
		if arg.begins_with("--band-map-capture="): capture = arg.trim_prefix("--band-map-capture=")
	if out.is_empty(): quit(1); return
	await new_viewer(); await source(out.path_join("sequence.wvz"))
	check(map.jobs.worker_pid < 0 and map.sequence_data.is_empty(),"Opening sequence controls starts no automatic preparation")
	check(map.sequence_start.value == 0 and map.sequence_end.value == 2 and map.sequence_stride.value == 1,"Explicit native-index selection retains the requested bounded range")
	check(map.sequence_estimate.get("selected_times") == 3 and map.sequence_estimate.get("total_centers") == 75 and map.sequence_estimate.get("memory_bytes",0) > 0 and map.sequence_estimate.get("disk_bytes") == 2*1048576 and not map.sequence_notice.text.is_empty(),"Preflight shows three selected native times,75 windows,and bounded RAM/disk before preparation")
	map.set_sequence_range(0,3,2)
	check(map._numeric_array_matches(map._sequence_arguments().get("indices"),[0,2]),"Stride selects explicit native records rather than viewer frames")
	map.set_sequence_range(0,9,1); map.prepare_sequence()
	check(map.pending_id.is_empty() and map.jobs.worker_pid < 0 and map.sequence_prepare_button.disabled,"Oversized or out-of-range selection is refused before starting a worker")
	map.set_sequence_range(0,2,1)
	observations.preflight = map.sequence_notice.text
	check(map.jobs.start(out.path_join("analysis-workers"),"spectral_band_sequence"),"Validation uses the existing worker with a disposable shared cache root")
	await seek(0.); viewer.timeline.refresh(viewer,true); var coverage: Dictionary = viewer.timeline.coverage.duplicate(true)
	var visual := Visual.snapshot(viewer)
	if not await prepare("synthetic_first"): await finish(); return
	var prepared: Dictionary = map.sequence_data.duplicate(true)
	var old_id: String = map.jobs.background_id
	var reply: Dictionary = map.jobs._read("background_result.json")
	check(prepared.maps.size() == 3 and map._numeric_array_matches(prepared.indices,[0,1,2]) and not prepared.cache.hit,"Selected three-record set is a cold cache preparation")
	var golden = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("golden.json")))
	var match_all := true
	for native in range(3):
		var data: Dictionary = prepared.maps[native]
		match_all = match_all and data.coverage.measured == 9 and data.coverage.total == 25 and int(data.record.index) == native
		for index in range(25):
			var expected = golden[native].measurements[index].power; var observed = data.measurements[index].power
			if expected == null: match_all = match_all and observed == null and data.measurements[index].status == "outside_support"
			else: match_all = match_all and observed != null and absf(observed-expected) <= maxf(absf(expected)*1e-11,1e-14)
	check(match_all,"Each cached native map and mask matches the separate full-complex DFT oracle")
	check(prepared.maps[0].request_key != prepared.maps[1].request_key and prepared.maps[1].request_key != prepared.maps[2].request_key,"Native records retain distinct exact numerical request keys")
	check(prepared.maps[0].measurements[12].power != prepared.maps[1].measurements[12].power and prepared.maps[1].measurements[12].power != prepared.maps[2].measurements[12].power,"Time-varying amplitude/frequency produces different measured band powers")
	check(Visual.snapshot(viewer) == visual,"Preprocessing preserves ordinary source and Scientific presentation")
	viewer.timeline.refresh(viewer,true); check(viewer.timeline.coverage == coverage,"Spectral preparation adds no scene-ready timeline coverage")
	check(map.cancel_button.disabled,"Completed selected-time preprocessing disables Cancel")
	for time in [0.,2.,4.]:
		check(await seek(time) and map.plane.visible and Exact.exact_float(map.result_data.record.native_time).value == time,"Exact prepared native sample displays its matching map: "+str(time))
	for time in [1.,3.,6.]:
		check(await seek(time) and not map.plane.visible and map.legend_panel.visible and map.legend.text.to_lower().contains("unavailable"),"Native gaps and missing selected times are visibly unavailable: "+str(time))
	check(map.sequence_data == prepared,"Playback selection does not mutate cached numerical measurements")
	await seek(2.)
	var saved: Dictionary = viewer.committed_sample.duplicate(true)
	viewer.committed_sample.requested_time = 0.; map._sync_replay(); map.sync_visibility()
	check(not map.plane.visible,"A requested native time cannot publish against a different committed scene sample")
	viewer.committed_sample = saved; map._sync_replay(); map.sync_visibility()
	check(map.plane.visible,"Matching committed scene sample restores its prepared plane")
	observations.forward = await playback_window(false,false)
	check(observations.forward.frames > 0 and observations.forward.finish > observations.forward.start and observations.forward.safe,"Ordinary forward playback continues without stale spectral publication")
	observations.reverse = await playback_window(true,false)
	check(observations.reverse.finish < observations.reverse.start and observations.reverse.safe,"Ordinary reverse playback retains exact-map gating")
	observations.loop = await playback_window(false,true)
	check(observations.loop.finish < observations.loop.start and observations.loop.safe,"Ordinary loop wrap retains exact-map gating")
	await seek(2.); map.opacity.value = .55; map.palette.select(2); map._presentation_changed()
	check(map.sequence_data == prepared and map.result_data.measurements == prepared.maps[1].measurements,"Palette and opacity preserve every prepared numerical map")
	var serial: int = map.jobs.serial; map.replay_enabled.button_pressed = false; map.sync_visibility()
	check(not map.plane.visible and map.jobs.serial == serial,"Replay toggle hides cached maps without recomputation")
	map.replay_enabled.button_pressed = true; map._sync_replay(); map.sync_visibility()
	check(map.plane.visible and map.jobs.serial == serial,"Replay toggle restores only the exact prepared sample")
	check(await preset("Cinematic") and map.window.visible and map.sequence_data == prepared,"Actual menu selects Cinematic while spectral controls remain open")
	await picture("cinematic-sequence")
	check(await preset("Scientific") and map.window.visible and map.sequence_data == prepared,"Actual menu selects Scientific without recomputing the sequence")
	map.close(); var camera: Transform3D = viewer.camera.transform
	var free: bool = viewer.free_camera
	if not free: viewer._toggle_free_camera()
	viewer._steer_camera(Vector2(15,-8)); await settle()
	check(viewer.camera.transform != camera and map.sequence_data == prepared,"Camera steering remains independent of prepared values")
	if not free: viewer._toggle_free_camera()
	map.reference_visible.button_pressed = false; await settle()
	check(not viewer.scene_layers.states.field.visible and map.plane.visible,"Source visibility remains independent of the replay plane")
	await picture("prepared-plane-only"); map.reference_visible.button_pressed = true
	if DisplayServer.get_name() != "headless":
		await settle(); var shown: Image = viewer._save_image_viewport(); map.visibility.button_pressed = false; await settle(); var hidden: Image = viewer._save_image_viewport()
		check(shown != null and hidden != null and shown.get_data() == hidden.get_data(),"Ordinary image export excludes the replay plane and legend pixel-for-pixel")
		map.visibility.button_pressed = true
	viewer.inspection_busy = true; map.sync_visibility(); check(not map.plane.visible and not map.legend_panel.visible,"Inspection guard excludes replay plane and unavailable legend")
	viewer.inspection_busy = false; viewer.offline_instance = true; map.sync_visibility(); check(not map.plane.visible and not map.legend_panel.visible,"Offline rendering guard excludes spectral replay")
	viewer.offline_instance = false; map.sync_visibility(); map.open(); await settle()
	check(map.sequence_data == prepared and map.jobs.serial == serial,"Closing/reopening a completed form retains selected maps without requesting work")
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		map.close(); observations.synthetic_baseline = await profile(false); observations.synthetic_prepared = await profile(true); map.open()
	if not await prepare("synthetic_warm"): await finish(); return
	check(map.sequence_data.cache.hit and map.sequence_data.maps == prepared.maps,"Prepared exact-set cache hit preserves original values and masks")
	map.close(); check(viewer._close_capture(),"Completed sequence does not prevent closing a capture")
	check(map.sequence_data.is_empty() and map.result_data.is_empty() and not map.plane.visible,"Closing source clears session replay publication")
	map.jobs.shutdown(); viewer.queue_free(); await settle()
	await new_viewer(); await source(out.path_join("sequence.wvz"))
	check(map.sequence_data.is_empty() and not map.plane.visible,"A fresh viewer never publishes cached results before explicit verification")
	check(map.jobs.start(out.path_join("analysis-workers"),"spectral_band_sequence"),"Fresh viewer reopens the same owned cache namespace")
	if not await prepare("synthetic_reopened"): await finish(); return
	check(map.sequence_data.cache.hit and map.sequence_data.maps == prepared.maps,"Fresh viewer verifies and reuses the durable complete selected sequence")
	map.band_low.text = ".41"; map._process(.2)
	map._completed(reply)
	check(map.sequence_data.is_empty() and map.result_data.is_empty() and not map.plane.visible,"Parameter edits and late prior worker replies cannot restore stale maps")
	map.band_low.text = ".4"; map.refresh_context()
	if not await prepare("synthetic_recover"): await finish(); return
	map.close(); viewer._close_capture(); await source(out.path_join("other.wvz"))
	if not await prepare("different_source"): await finish(); return
	check(not map.sequence_data.cache.hit and map.sequence_data.request_key != prepared.request_key,"Different capture bytes cannot reuse another source's cached set")
	map.close(); viewer._close_capture(); await source(out.path_join("active-sequence.wvz"))
	map.set_grid_xyz([0,0,0],[128,128,128],"z",[8,8],[4,4]); map.band_low.text = ".05"; map.band_high.text = ".15"; map.set_sequence_range(0,2,1); map.refresh_context(); progress_seen.clear()
	if map.jobs.worker_pid <= 0: map.jobs.start(out.path_join("analysis-workers"),"spectral_band_sequence")
	map.prepare_sequence(); var cancel_id: String = map.pending_id
	check(not cancel_id.is_empty() and not map.cancel_button.disabled,"Running multi-record preprocessing enables Cancel")
	var until := Time.get_ticks_msec()+15000
	while not map.pending_id.is_empty() and not (str(progress_seen.get("stage","")).contains("centers") and int(progress_seen.get("completed",0)) > 0) and Time.get_ticks_msec() < until: await create_timer(.01).timeout
	check(map.pending_id == cancel_id and not progress_seen.is_empty(),"Cancellation is exercised after real batch progress")
	observations.cancel_progress = progress_seen.duplicate(true)
	var began := Time.get_ticks_usec(); space(map.cancel_button)
	observations.cancel_callback_ms = (Time.get_ticks_usec()-began)/1000.
	check(map.pending_id.is_empty() and map.sequence_data.is_empty() and not map.plane.visible,"Cancel immediately clears queued/running sequence publication")
	check(await wait_job(3.),"Worker acknowledges mid-batch selected-time cancellation")
	observations.cancel_ack_ms = (Time.get_ticks_usec()-began)/1000.
	var cancelled: Dictionary = map.jobs._read("background_result.json")
	check(cancelled.get("id") == cancel_id and cancelled.get("code") == "cancelled" and not cancelled.has("data"),"Cancelled sequence returns no partial map set")
	map.prepare_sequence(); map.close()
	check(map.pending_id.is_empty() and await wait_job(3.) and map.sequence_data.is_empty(),"Closing the form cancels pending sequence work")
	map.open(); map.prepare_sequence(); viewer.selection_controller.state.revision += 1; map._process(.2)
	check(map.pending_id.is_empty() and await wait_job(3.) and map.sequence_data.is_empty(),"Selection revision invalidates active sequence publication")
	map.close(); viewer._close_capture()
	await boundary_mutation_checks()
	if not capture.is_empty():
		await source(capture,true); await seek(20.)
		if await prepare("model_first",90.):
			var actual: Dictionary = map.sequence_data.duplicate(true)
			check(actual.maps.size() == 3 and map._numeric_array_matches(actual.maps[0].support.shape,[128,128,128]) and actual.maps[0].coverage.measured == 1,"Actual signed N192 sequence retains 128³ support at three explicit native records")
			check(actual.maps[0].support.status == "insufficient_support" and map.legend.text.contains("UNRESOLVED"),"Actual low-frequency maps retain explicit unresolved support")
			for time in [20.,21.,22.]: check(await seek(time) and map.plane.visible and replay_safe(),"Actual prepared native time matches viewport: "+str(time))
			check(await seek(20.5) and not map.plane.visible,"Actual native-time gap is visibly unavailable")
			check(await seek(23.) and not map.plane.visible,"Actual unprepared native time stays unavailable")
			await seek(21.); map.close(); await picture("model-a-sequence")
			if DisplayServer.get_name() != "headless": observations.model_baseline = await profile(false); observations.model_prepared = await profile(true)
			map.open(); await prepare("model_warm",90.); check(map.sequence_data.cache.hit,"Actual selected sequence replays from a verified prepared cache hit")
			map.close(); viewer._close_capture(); map.jobs.shutdown(); await source(capture,true)
			map.jobs.start(out.path_join("analysis-workers"),"spectral_band_sequence")
			await prepare("model_reopened",90.); check(not map.sequence_data.is_empty() and map.sequence_data.cache.hit,"New worker independently verifies and reuses the actual prepared sequence")
	await finish()
