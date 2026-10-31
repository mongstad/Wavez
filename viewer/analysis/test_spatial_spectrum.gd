extends SceneTree
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var out := ""
var capture := ""
var viewer
var spectrum
var observations := {}
var temporal_completions := 0
var temporal_failures := 0
var startup_foreground_failures := 0
var startup_spectral_failures := 0
var unavailable_message := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
func wait_job(seconds := 25.) -> bool:
	var began := Time.get_ticks_msec()
	while (not spectrum.pending_id.is_empty() or spectrum.jobs.busy()) and Time.get_ticks_msec()-began < seconds*1000:
		await create_timer(.02).timeout
	return spectrum.pending_id.is_empty() and not spectrum.jobs.busy()
func picture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(out.path_join(name+"-viewport.png"))
		if spectrum.window.visible: spectrum.window.get_texture().get_image().save_png(out.path_join(name+"-dialog.png"))
func space(control: Control) -> void:
	control.grab_focus()
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_SPACE; event.physical_keycode = KEY_SPACE; event.pressed = pressed
		control.get_window().push_input(event,true)
func no_tooltips(node: Node) -> bool:
	if node is Control and not node.tooltip_text.is_empty(): return false
	for child in node.get_children():
		if not no_tooltips(child): return false
	return true
func find_button(node: Node, label: String):
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found = find_button(child,label)
		if found != null: return found
	return null
func roi() -> void: spectrum.set_roi_xyz([8,4,0],[32,32,32])
func open_source(path: String) -> void:
	viewer._open_capture(path); viewer.playing = false; viewer.orbit_enabled = false
	await settle()
	spectrum.open(); spectrum.select_object("field"); spectrum.select_channel("amplitude")
	roi(); await settle()
func finish() -> void:
	if is_instance_valid(viewer):
		spectrum.cancel(); await wait_job(); spectrum.close(); viewer._close_capture(); viewer.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name()}
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("SPATIAL SPECTRUM: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	create_timer(160).timeout.connect(func():push_error("Spectrum native validation timed out"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spectral-output="): out = arg.trim_prefix("--spectral-output=")
		if arg.begins_with("--spectral-capture="): capture = arg.trim_prefix("--spectral-capture=")
	if out.is_empty(): quit(1); return
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	await settle(); spectrum = viewer.spatial_spectrum
	var denied := preload("res://analysis/analysis_jobs.gd").new(); root.add_child(denied)
	denied.memory_bytes = 1152921504606846976
	denied.failed.connect(func(_message):startup_foreground_failures += 1)
	denied.spatial_spectrum_failed.connect(func(_message):startup_spectral_failures += 1)
	check(denied.request_background({},"spatial_spectrum",{},0,0,0).is_empty() and startup_spectral_failures == 1 and startup_foreground_failures == 0,"Startup refusal belongs only to the requesting spectral form")
	denied.queue_free()
	var unavailable := preload("res://analysis/analysis_jobs.gd").new(); root.add_child(unavailable)
	unavailable.failed.connect(func(_message):startup_foreground_failures += 1)
	unavailable.spatial_spectrum_failed.connect(func(message):unavailable_message = message)
	var saved_path := OS.get_environment("PATH")
	OS.set_environment("PATH",out.path_join("without-python"))
	unavailable.request_background({"path":out.path_join("field.wvz")},"spatial_spectrum",{},0,0,0)
	OS.set_environment("PATH",saved_path)
	var until := Time.get_ticks_msec()+4000
	while unavailable.background_pending and Time.get_ticks_msec() < until: await create_timer(.02).timeout
	check(unavailable_message.contains("Python 3") and unavailable_message.contains("NumPy") and startup_foreground_failures == 0,"Unavailable external runtime fails explicitly without affecting Selection")
	unavailable.queue_free()
	check(spectrum.jobs == viewer.selection_controller.jobs,"Existing analysis worker owns spatial spectrum")
	check(spectrum.jobs.worker_pid < 0,"Opening viewer does not start spectral work")
	await open_source(out.path_join("field.wvz"))
	check(spectrum.current_channel == "amplitude" and spectrum.window.visible,"Native tool opens a named source channel")
	var menu: Dictionary = viewer.shell.commands.get("tool:Spatial spectrum",{})
	check(not menu.is_empty() and not menu.popup.is_item_disabled(menu.index) and menu.popup.get_item_tooltip(menu.index).is_empty(),"Tools action is enabled for a field and has no tooltip")
	check(no_tooltips(spectrum.window),"No unsolicited tooltip in spectral controls")
	check(spectrum.jobs.worker_pid < 0,"Opening spectral form does not verify or calculate")
	viewer.requested_time = 1.; spectrum.pin_playhead(); roi()
	check(spectrum.sample_index.value == 0 and spectrum.requested_time == 1.,"Playhead pin selects held native sample without changing requested time")
	var visual_before := Visual.snapshot(viewer)
	viewer.timeline.refresh(viewer); var coverage_before: Dictionary = viewer.timeline.coverage.duplicate(true)
	spectrum.jobs.background_completed.connect(func(_result):temporal_completions += 1)
	spectrum.jobs.background_failed.connect(func(_message):temporal_failures += 1)
	spectrum.jobs.spatial_spectrum_completed.connect(func(reply):observations.last_reply = reply.duplicate(true))
	var began := Time.get_ticks_usec(); space(spectrum.compute_button)
	observations.request_callback_ms = (Time.get_ticks_usec()-began)/1000.
	check(not spectrum.pending_id.is_empty() and observations.request_callback_ms < 50.,"Native Compute input queues nonblocking work")
	var first_id: String = spectrum.pending_id
	observations.first_request = spectrum.request_context.duplicate(true)
	var pid: int = spectrum.jobs.worker_pid
	var pinned_before: float = spectrum.requested_time
	var frames := 0
	while not spectrum.pending_id.is_empty() and frames < 1000:
		await process_frame; frames += 1
	check(await wait_job() and not spectrum.result_data.is_empty(),"Verified result publishes through the shared worker")
	observations.responsive_frames = frames
	check(frames > 0,"Main loop continues during verification and FFT")
	if spectrum.result_data.is_empty():
		observations.failure_status = spectrum.status.text; await finish(); return
	var result: Dictionary = spectrum.result_data.duplicate(true)
	observations.first = {"publication_ms":spectrum.publication_msec,"timings":result.timings,"source":spectrum.result_source.duplicate(true),"record":result.record,"roi":result.roi,"bins":result.radial.frequency.size(),"power":result.total_power,"parseval_relative_error":result.parseval_relative_error}
	check(result.record.native_time.text == "0" and result.record.requested_time.text == "1","Actual native and requested time remain distinct in result")
	check(result.roi.start == [0.,4.,8.] and result.roi.end == [32.,36.,40.],"XYZ form maps to complete ZYX source ROI")
	check(result.radial.frequency.size() <= 512 and result.parseval_relative_error < 1e-12,"Bounded numerical plot retains Parseval normalization")
	var tiny: Dictionary = result.duplicate(true)
	tiny.radial.frequency = tiny.radial.frequency.map(func(value):return value*1e-35)
	tiny.radial.power = tiny.radial.power.map(func(value):return value*1e-45)
	check(spectrum.plot.publish(tiny) and spectrum.plot.scales().x < 1e-30 and spectrum.plot.scales().y < 1e-30 and spectrum.plot.scales().y > 0.,"Plot scales preserve tiny positive frequencies and powers")
	began = Time.get_ticks_usec(); spectrum.plot.publish(result)
	observations.plot_update_microseconds = Time.get_ticks_usec()-began
	check(result.units.position == "dimensionless" and spectrum.table.text.contains("Frequency"),"Canonical units and numerical bins are visible")
	check(spectrum.region_overlay.corners.size() == 8 and spectrum.region_overlay.verified,"Verified source region is indicated")
	check(temporal_completions == 0 and temporal_failures == 0,"Spectrum messages cannot populate temporal result handlers")
	check(Visual.snapshot(viewer) == visual_before,"Compute preserves scalar, scene and Scientific visual state")
	if DisplayServer.get_name() != "headless":
		var with_indicator: Image = viewer._save_image_viewport()
		spectrum.close(); await settle()
		var without_indicator: Image = viewer._save_image_viewport()
		check(with_indicator != null and without_indicator != null and with_indicator.get_data() == without_indicator.get_data(),"Ordinary image pixels exclude spectral window and region indicator")
		spectrum.open()
	viewer.timeline.refresh(viewer)
	check(viewer.timeline.coverage == coverage_before,"Spectrum adds no prepared-timeline coverage")
	viewer.requested_time = 3.; spectrum.refresh_context()
	check(spectrum.result_data == result and spectrum.requested_time == pinned_before and spectrum.context.text.contains("Pinned result"),"Playhead changes keep numerical result pinned")
	spectrum.plot.grab_focus()
	var key := InputEventKey.new(); key.keycode = KEY_RIGHT; key.pressed = true; spectrum.window.push_input(key,true)
	check(spectrum.plot.selected_index == 1 and spectrum.detail.text.contains("Bin 1"),"Keyboard plot selection exposes exact bin readout")
	await picture("dark")
	var details_toggle = find_button(spectrum.window,"Details and numerical data")
	space(details_toggle); await settle(); spectrum.scroller.scroll_vertical = int(details_toggle.position.y); await picture("details")
	check(spectrum.geometry_detail.text.contains(str(spectrum.result_source.sha256)) and spectrum.geometry_detail.text.contains(str(spectrum.result_source.committed_bytes)) and spectrum.summary.text.contains(str(result.provenance.normalization)),"Expanded details expose full verified identity and numerical normalization")
	space(details_toggle); spectrum.scroller.scroll_vertical = 0
	viewer.shell.appearance.select(true); spectrum.close(); spectrum.open(); await picture("light")
	spectrum.window.size = Vector2i(380,430); await picture("compact")
	check(spectrum.compute_button.is_visible_in_tree() and spectrum.compute_button.get_global_rect().end.y <= spectrum.window.size.y,"Compact layout retains Compute action")
	check(spectrum.window.size.x >= 520 and spectrum.cancel_button.get_global_rect().end.x <= spectrum.window.size.x and spectrum.channel_choice.get_global_rect().end.x <= spectrum.window.size.x,"Minimum window width keeps source and footer controls inside the dialog")
	viewer.shell.appearance.select(false); spectrum.close(); spectrum.open()
	# ROI edits invalidate old data; stale callbacks cannot republish it.
	spectrum.set_roi_xyz([0,0,0],[32,32,32])
	spectrum._completed({"id":first_id,"data":result,"source":observations.first.source})
	check(spectrum.result_data.is_empty() and spectrum.plot.data.is_empty(),"Changed ROI discards old data and stale completion")
	viewer._apply_preset("Cinematic"); var cinematic_before := Visual.snapshot(viewer)
	spectrum.minimum_frequency.text = ".1"; spectrum.compute()
	check(await wait_job() and not spectrum.result_data.is_empty(),"Warm request completes on existing worker")
	check(Visual.snapshot(viewer) == cinematic_before,"Cinematic mapping and Bloom are independent of spectral analysis")
	viewer._apply_preset("Scientific")
	check(spectrum.jobs.worker_pid == pid,"Warm spectrum reuses owned analysis process")
	if not spectrum.result_data.is_empty():
		observations.warm_publication_ms = spectrum.publication_msec
		check(spectrum.result_data.support.status == "insufficient_support" and spectrum.support_notice.text.contains("Insufficient support"),"Unsupported low frequency is explicitly labeled")
	# Real transport and camera updates remain available while a fixed sample computes.
	viewer.requested_time = 0.; viewer.physical_rate = .25; viewer.playing = true
	var previous_yaw: float = viewer.yaw
	var pinned_time: float = spectrum.requested_time
	spectrum.compute(); viewer.yaw += .05; viewer._update_camera()
	await create_timer(.2).timeout
	check(viewer.requested_time > 0. and viewer.yaw != previous_yaw,"Playback and camera navigation coexist with the spectral form")
	viewer.playing = false
	check(await wait_job() and not spectrum.result_data.is_empty() and spectrum.requested_time == pinned_time,"Playback does not supersede fixed native analysis")
	spectrum.compute(); viewer.selection_controller.state.revision += 1; spectrum._process(.2)
	check(spectrum.pending_id.is_empty() and spectrum.result_data.is_empty() and await wait_job(3.),"Selection revision change cancels stale spectral publication")
	# Preserve existing Close File refusal and asynchronous cancellation.
	spectrum.compute(); check(not spectrum.pending_id.is_empty(),"Cancellation exercise starts a request")
	var owned_id: String = spectrum.pending_id
	viewer.selection_controller.temporal.cancel_analysis()
	check(spectrum.jobs.background_pending and spectrum.jobs.background_id == owned_id,"Temporal Cancel cannot cancel a spectral request")
	viewer.selection_controller.temporal.matched.prepare_to(out.path_join("blocked-matched"))
	check(not viewer.selection_controller.temporal.matched.preparing and spectrum.jobs.background_id == owned_id,"Matched preparation cannot take over an active spectrum")
	var capture_status: int = await viewer.selection_controller.temporal.durable.capture_to(out.path_join("blocked-inspection.png"))
	check(capture_status == ERR_BUSY and not viewer.inspection_busy and spectrum.jobs.background_id == owned_id,"Analysis-state capture refuses without disturbing the spectral owner")
	check(not viewer._close_capture(),"Close File retains active-analysis refusal")
	viewer.shell.details.hide()
	began = Time.get_ticks_usec(); spectrum.cancel()
	observations.cancel_callback_ms = (Time.get_ticks_usec()-began)/1000.
	check(spectrum.pending_id.is_empty() and spectrum.result_data.is_empty() and observations.cancel_callback_ms < 50.,"Cancel clears publication target without joining")
	check(await wait_job(3.),"Worker cancellation acknowledges within grace")
	observations.cancel_ack_ms = (Time.get_ticks_usec()-began)/1000.
	check(viewer._close_capture() and spectrum.result_data.is_empty() and spectrum.region_overlay.corners.is_empty(),"Close after cancellation clears source result and region")
	await open_source(out.path_join("other.wvz")); spectrum.compute()
	check(await wait_job() and not spectrum.result_data.is_empty(),"Source switch computes a newly verified result")
	check(spectrum.result_source.get("sha256") != observations.first.source.sha256,"New source cannot reuse former source identity")
	spectrum.compute(); spectrum.close()
	check(spectrum.pending_id.is_empty() and await wait_job(3.),"Closing spectral window cancels pending work")
	viewer._close_capture(); await open_source(out.path_join("nonfinite.wvz")); spectrum.compute()
	check(await wait_job() and spectrum.result_data.is_empty() and spectrum.status.text.to_lower().contains("nonfinite"),"Nonfinite source refuses without a stale plot")
	check(temporal_completions == 0 and temporal_failures == 0,"Spectrum failure remains scoped away from temporal form")
	spectrum.cancel(); viewer._close_capture()
	if not capture.is_empty():
		viewer.shell.status_ui.acknowledge() # Intentional earlier nonfinite refusal was checked and recorded.
		viewer._open_capture(capture); viewer.playing = false; viewer.orbit_enabled = false; await settle()
		spectrum.open(); spectrum.select_channel("amplitude"); spectrum.set_roi_xyz([32,32,32],[128,128,128]); spectrum.minimum_frequency.text = str(.5/TAU)
		began = Time.get_ticks_usec(); spectrum.compute(); observations.model_request_callback_ms = (Time.get_ticks_usec()-began)/1000.
		check(await wait_job(45.) and not spectrum.result_data.is_empty(),"Actual N192 Model A source reaches native numerical UI")
		if not spectrum.result_data.is_empty():
			observations.model = {"publication_ms":spectrum.publication_msec,"source":spectrum.result_source.duplicate(true),"record":spectrum.result_data.record,"support":spectrum.result_data.support,"timings":spectrum.result_data.timings,"power":spectrum.result_data.total_power}
			check(spectrum.result_data.support.status == "insufficient_support","Actual low-k target remains unresolved even in 128³ support")
			await picture("model-a")
	await finish()
