extends SceneTree
const Visual = preload("res://scene/visual_state.gd")
var checks := 0
var failures: Array[String] = []
var out := ""
var capture := ""
var viewer
var map
var observations := {}
var unrelated_completions := 0
var unrelated_failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
func wait_job(seconds := 30.) -> bool:
	var began := Time.get_ticks_msec()
	while (not map.pending_id.is_empty() or map.jobs.busy()) and Time.get_ticks_msec()-began < seconds*1000:
		await create_timer(.02).timeout
	return map.pending_id.is_empty() and not map.jobs.busy()
func picture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(out.path_join(name+"-viewport.png"))
		if map.window.visible: map.window.get_texture().get_image().save_png(out.path_join(name+"-dialog.png"))
func space(control: Control) -> void:
	control.grab_focus()
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = KEY_SPACE; event.physical_keycode = KEY_SPACE; event.pressed = pressed
		control.get_window().push_input(event,true)
func grid() -> void:
	map.set_grid_xyz([-8,-8,16],[16,16,16],"z",[5,5],[12,12]); map.band_low.text = ".4"; map.band_high.text = ".8"
func open_source(name: String) -> void:
	viewer._open_capture(out.path_join(name+".wvz")); viewer.playing = false; viewer.orbit_enabled = false
	await settle(); map.open(); map.select_object("field"); map.select_channel("amplitude"); grid(); await settle()
func no_tooltips(node: Node) -> bool:
	if node is Control and not node.tooltip_text.is_empty(): return false
	for child in node.get_children():
		if not no_tooltips(child): return false
	return true
func stats(values: Array) -> Dictionary:
	var sorted := values.duplicate(); sorted.sort()
	var total := 0.
	for value in values: total += value
	return {"min":sorted[0],"median":sorted[sorted.size()/2],"p95":sorted[mini(sorted.size()-1,int(sorted.size()*.95))],"max":sorted[-1],"mean":total/values.size()}
func profile(show_map: bool) -> Dictionary:
	map.visibility.button_pressed = show_map; map.sync_visibility(); await settle()
	var wall: Array = []; var gpu: Array = []; var cpu: Array = []
	var yaw: float = viewer.yaw
	var orbit: bool = viewer.orbit_enabled; var speed: float = viewer.orbit_speed
	viewer.orbit_enabled = true; viewer.orbit_speed = .012
	var last := Time.get_ticks_usec()
	for i in 60:
		await process_frame; await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec(); wall.append((now-last)/1000.); last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	viewer.orbit_enabled = orbit; viewer.orbit_speed = speed; viewer.yaw = yaw; viewer._update_camera()
	return {"frames":60,"wall_ms":stats(wall),"render_gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"mean_fps":1000./stats(wall).mean,"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"engine_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"engine_buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"engine_static_bytes":OS.get_static_memory_usage(),"plane_payload_bytes":map.plane.gpu_bytes,"plane_allocations":map.plane.gpu_breakdown.duplicate(true),"resolution":[root.size.x,root.size.y],"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}
func finish() -> void:
	if is_instance_valid(viewer):
		map.cancel(); await wait_job(); map.close(); viewer._close_capture(); viewer.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"device":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("SPECTRAL BAND MAP: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	create_timer(280).timeout.connect(func():push_error("Band map native validation timed out"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--band-map-output="): out = arg.trim_prefix("--band-map-output=")
		if arg.begins_with("--band-map-capture="): capture = arg.trim_prefix("--band-map-capture=")
	if out.is_empty(): quit(1); return
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer)
	await settle(); map = viewer.spectral_band_map
	check(map.jobs == viewer.selection_controller.jobs and map.jobs == viewer.spatial_spectrum.jobs,"Both spectral tools use the existing worker")
	check(map.jobs.worker_pid < 0,"Opening viewer starts no analysis process")
	await open_source("field")
	var menu: Dictionary = viewer.shell.commands.get("tool:Spectral band map",{})
	check(not menu.is_empty() and not menu.popup.is_item_disabled(menu.index),"Tools exposes band map for source fields")
	check(no_tooltips(map.window) and menu.popup.get_item_tooltip(menu.index).is_empty(),"New controls contain no unsolicited tooltips")
	check(map.jobs.worker_pid < 0,"Opening map form performs no source calculation")
	viewer.requested_time = 1.; map.pin_playhead(); grid()
	check(map.sample_index.value == 0 and map.requested_time == 1.,"Requested time pins the actual held native sample")
	var visual_before := Visual.snapshot(viewer)
	viewer.timeline.refresh(viewer); var coverage_before: Dictionary = viewer.timeline.coverage.duplicate(true)
	map.jobs.background_completed.connect(func(_reply):unrelated_completions += 1)
	map.jobs.background_failed.connect(func(_reply):unrelated_failures += 1)
	map.jobs.spatial_spectrum_completed.connect(func(_reply):unrelated_completions += 1)
	map.jobs.spatial_spectrum_failed.connect(func(_reply):unrelated_failures += 1)
	var began := Time.get_ticks_usec(); space(map.compute_button)
	observations.request_callback_ms = (Time.get_ticks_usec()-began)/1000.
	check(not map.pending_id.is_empty() and observations.request_callback_ms < 50.,"Keyboard Compute queues without blocking")
	var first_id: String = map.pending_id
	var pid: int = map.jobs.worker_pid
	var frames := 0
	while not map.pending_id.is_empty() and frames < 1000: await process_frame; frames += 1
	check(await wait_job() and not map.result_data.is_empty(),"Verified plane publishes through shared worker")
	observations.responsive_frames = frames
	check(frames > 0,"Viewer continues frames while batch calculates")
	if map.result_data.is_empty(): observations.failure_status = map.status.text; await finish(); return
	var result: Dictionary = map.result_data.duplicate(true)
	var binding: Dictionary = map.result_source.duplicate(true)
	observations.first = {"publication_ms":map.publication_msec,"source":binding,"data":result}
	check(result.record.native_time.text == "0" and result.record.requested_time.text == "1","Native and requested time are explicit")
	check(result.coverage.total == 25 and result.coverage.measured == 9 and result.timings.decoded_samples == 1,"25 centers share one decode and retain 16 boundary masks")
	var golden = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("golden.json")))
	var values_match := true; var centers_match := true; var texture_matches := true
	for i in range(25):
		var expected: Dictionary = golden.measurements[i]; var item: Dictionary = result.measurements[i]
		for axis in range(3): centers_match = centers_match and absf(item.center_xyz[axis]-expected.center_xyz[axis]) < 1e-12
		var texel: float = map.plane.data_image.get_pixel(i%5,i/5).r
		if expected.power == null:
			values_match = values_match and item.power == null and item.status == "outside_support"; texture_matches = texture_matches and texel < 0.
		else:
			values_match = values_match and item.status == "measured" and absf(item.power-expected.power) <= absf(expected.power)*1e-12
			var normalized: float = (expected.power-map.plane.range_min)/(map.plane.range_max-map.plane.range_min)
			texture_matches = texture_matches and absf(texel-normalized) < 1e-6
	check(values_match,"Every displayed numerical value matches independent full-complex DFT band integration")
	check(centers_match,"Anisotropic origin and even-support center coordinates match source geometry")
	check(texture_matches,"Display texels map row/column values and explicit negative unavailable mask")
	check(map.plane.measured_centers_world.size() == 9 and map.plane.centers_world.size() == 25,"Measured markers and unavailable centers are distinct")
	check(map.plane.source_corners.size() == 4 and absf(map.plane.source_corners[0].z+.25) < 1e-6,"Viewport plane lies at source-aligned window-center depth")
	check(map.plane.gpu_bytes < 16777216 and map.plane.data_image.get_size() == Vector2i(5,5),"Overlay allocates only bounded center texture and plane")
	check(map.legend.text.contains("dimensionless") and map.legend.text.contains("9 / 25") and map.legend.text.contains("unavailable"),"Viewport legend identifies units and measurement coverage")
	check(Visual.snapshot(viewer) == visual_before,"Computation preserves source scalar and Scientific visual state")
	map.details_toggle.button_pressed = true
	check(map.geometry_detail.text.contains(binding.sha256) and map.geometry_detail.text.contains(binding.committed_bytes) and map.summary.text.contains(result.provenance.normalization),"Details expose full source identity and power normalization")
	map.details_toggle.button_pressed = false
	map.opacity.value = .55; map.palette.select(2); map._presentation_changed()
	check(map.result_data == result,"Palette and opacity never modify measured data")
	map.palette.select(0); map.opacity.value = .8; map._presentation_changed()
	viewer.requested_time = 3.; map.refresh_context()
	check(map.result_data == result and map.requested_time == 1. and map.legend.text.contains("current playhead 3"),"Playback cursor leaves map pinned and explicitly labeled")
	viewer.timeline.refresh(viewer); check(viewer.timeline.coverage == coverage_before,"Map creates no prepared timeline coverage")
	map.close(); await settle()
	check(map.plane.visible and map.legend_panel.visible,"Closing completed form keeps the viewport map and legend")
	viewer.inspection_busy = true; map.sync_visibility()
	check(not map.plane.visible and not map.legend_panel.visible,"Inspection rendering guard excludes plane and legend")
	viewer.inspection_busy = false; viewer.offline_instance = true; map.sync_visibility()
	check(not map.plane.visible and not map.legend_panel.visible,"Offline rendering guard excludes plane and legend")
	viewer.offline_instance = false; map.sync_visibility()
	viewer.yaw = 0.; viewer.pitch = .15; viewer._update_camera()
	await picture("dark-plane-reference")
	if DisplayServer.get_name() != "headless":
		var shown: Image = viewer._save_image_viewport(); map.visibility.button_pressed = false; await settle()
		var hidden: Image = viewer._save_image_viewport()
		check(shown != null and hidden != null and shown.get_data() == hidden.get_data(),"Ordinary saved image excludes transient plane and legend pixel-for-pixel")
		map.visibility.button_pressed = true; map.reference_visible.button_pressed = false; await settle()
		check(not viewer.scene_layers.states.field.visible and map.plane.visible,"Source field and spectral plane visibility are independent")
		await picture("dark-plane-only")
		map.opacity.value = 1.; await picture("opaque-plane-only"); map.opacity.value = .8
		map.reference_visible.button_pressed = true
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
		observations.synthetic_baseline = await profile(false); observations.synthetic_map = await profile(true)
	map.open(); await picture("dark-controls")
	viewer.shell.appearance.select(true); map.close(); map.open(); await picture("light-controls")
	map.close(); await picture("light-plane-reference"); map.open()
	map.window.size = Vector2i(560,400); await picture("compact")
	check(map.compute_button.get_global_rect().end.y <= map.window.size.y and map.channel_choice.get_global_rect().end.x <= map.window.size.x and map.hop[1].get_global_rect().end.x <= map.window.size.x,"Compact scroll layout retains sources, grid controls and Compute")
	viewer.shell.appearance.select(false); map.close(); map.open()
	map.set_grid_xyz([4,4,16],[16,16,16],"z",[2,2],[12,12]); map._completed({"id":first_id,"data":result,"source":binding})
	check(map.result_data.is_empty() and not map.plane.visible and map.warnings_detail.text.is_empty(),"Changed grid and stale callback cannot show prior plane or warnings")
	viewer._apply_preset("Cinematic"); var cinematic_before := Visual.snapshot(viewer)
	map.compute(); check(await wait_job() and not map.result_data.is_empty(),"Reduced-center warm batch completes")
	check(map.support_xyz[0].value == 16 and map.result_data.coverage.total == 4,"Center fallback preserves 3D support")
	check(Visual.snapshot(viewer) == cinematic_before and map.jobs.worker_pid == pid,"Cinematic mapping remains independent and warm request reuses worker")
	map.close(); await picture("cinematic"); map.open(); viewer._apply_preset("Scientific")
	map.band_low.text = ".41"; map._process(.2)
	check(map.result_data.is_empty() and not map.plane.visible,"Band edit invalidates completed plane even without a text-change signal")
	map.compute(); check(await wait_job() and not map.result_data.is_empty(),"Edited band recomputes")
	map.sample_index.value = 1
	check(map.result_data.is_empty() and not map.plane.visible,"Native-index edit invalidates completed plane")
	map.compute(); check(await wait_job() and not map.result_data.is_empty() and map.result_data.record.native_time.text == "2","Explicit native time recomputes correct record")
	map.select_channel("energy_density")
	check(map.result_data.is_empty() and not map.plane.visible,"Explicit channel change invalidates old amplitude map")
	map.compute(); check(await wait_job() and not map.result_data.is_empty() and map.result_data.channel == "energy_density","Only explicit channel selection permits another recorded scalar")
	map.select_channel("amplitude"); viewer.requested_time = 1.; map.pin_playhead(); grid(); map.compute(); await wait_job()
	map.close(); var camera_before: Transform3D = viewer.camera.transform; var centers_before: Array = map.plane.centers_world.duplicate(true)
	var was_free: bool = viewer.free_camera
	if not was_free: viewer._toggle_free_camera()
	viewer._steer_camera(Vector2(15,-8)); await settle()
	check(viewer.free_camera and viewer.camera.transform != camera_before and map.plane.centers_world == centers_before,"Free-camera steering changes viewpoint without moving measured source centers")
	await picture("free-camera")
	if not was_free: viewer._toggle_free_camera()
	map.open()
	viewer.requested_time = 0.; viewer.physical_rate = .25; viewer.playing = true
	var yaw: float = viewer.yaw; map.compute(); viewer.yaw += .05; viewer._update_camera(); await create_timer(.2).timeout
	check(viewer.requested_time > 0. and viewer.yaw != yaw,"Playback and camera remain responsive during fixed-time analysis")
	viewer.playing = false; check(await wait_job() and not map.result_data.is_empty() and map.requested_time == 1.,"Playback does not replace pinned sample")
	map.compute(); viewer.selection_controller.state.revision += 1; map._process(.2)
	check(map.pending_id.is_empty() and map.result_data.is_empty() and await wait_job(3.),"Selection changes cancel stale publication")
	grid(); map.compute(); var owned_id: String = map.pending_id
	viewer.selection_controller.temporal.cancel_analysis()
	check(map.jobs.background_pending and map.jobs.background_id == owned_id,"Temporal Cancel cannot cancel map owner")
	viewer.spatial_spectrum.open(); viewer.spatial_spectrum.compute()
	check(map.jobs.background_id == owned_id and viewer.spatial_spectrum.pending_id.is_empty(),"Individual spectrum cannot take over active map")
	viewer.spatial_spectrum.close()
	viewer.selection_controller.temporal.matched.prepare_to(out.path_join("blocked-matched"))
	check(not viewer.selection_controller.temporal.matched.preparing and map.jobs.background_id == owned_id,"Matched preparation respects map ownership")
	var capture_status: int = await viewer.selection_controller.temporal.durable.capture_to(out.path_join("blocked-inspection.png"))
	check(capture_status == ERR_BUSY and not viewer.inspection_busy and map.jobs.background_id == owned_id,"Analysis-state capture respects active map ownership")
	check(not viewer._close_capture(),"Close File retains active-analysis refusal")
	viewer.shell.details.hide(); began = Time.get_ticks_usec(); map.cancel()
	observations.cancel_callback_ms = (Time.get_ticks_usec()-began)/1000.
	check(map.pending_id.is_empty() and map.result_data.is_empty() and observations.cancel_callback_ms < 50.,"Cancel immediately clears map without waiting")
	check(await wait_job(3.),"Worker acknowledges cancellation")
	observations.cancel_ack_ms = (Time.get_ticks_usec()-began)/1000.
	check(viewer._close_capture() and map.plane.centers_world.is_empty(),"Closing source clears plane data")
	await open_source("other"); map.compute()
	check(await wait_job() and not map.result_data.is_empty() and map.result_source.sha256 != binding.sha256,"New capture receives a new verified binding")
	map.compute(); map.close(); check(map.pending_id.is_empty() and await wait_job(3.),"Closing pending form cancels without partial map")
	viewer._close_capture(); await open_source("nonfinite"); map.compute()
	check(await wait_job() and not map.result_data.is_empty() and map.result_data.coverage.measured == 8,"Nonfinite support masks only affected center")
	map.close(); await picture("nonfinite-mask"); map.cancel(); viewer._close_capture()
	await open_source("translated"); map.compute()
	check(await wait_job() and not map.result_data.is_empty(),"Translated source produces a map")
	if not map.result_data.is_empty():
		var xyz: Array = map.plane.center_world(2,2)
		var center := Vector3(xyz[0],xyz[1],xyz[2])
		check(center.is_equal_approx(Vector3(1.875,-3.1875,4.75)),"Source translation is applied exactly once to center geometry")
		for axis in [0,1]:
			map.set_grid_xyz([16,16,16],[16,16,16],axis,[1,1],[12,12]); map.compute()
			check(await wait_job() and not map.result_data.is_empty() and map.plane.source_corners.size() == 4,"Alternate plane normal publishes aligned source plane "+str(axis))
			if not map.result_data.is_empty():
				var expected: float = [1.875,-3.1875,4.75][axis]
				check(absf(map.plane.source_corners[0][axis]-expected) < 1e-6 and absf(map.plane.source_corners[3][axis]-expected) < 1e-6,"Plane normal coordinate stays fixed "+str(axis))
	map.set_grid_xyz([-32,-32,16],[16,16,16],"z",[1,1],[12,12]); map.compute()
	check(await wait_job() and not map.result_data.is_empty() and map.result_data.coverage.measured == 0 and map.legend.text.contains("unavailable") and not map.legend_gradient.visible,"Fully masked map reports unavailable range without a numeric color scale")
	check(not map.plane._gpu_coordinate_safe([1e40,0.,0.],[.25,.375,.5]) and not map.plane._gpu_coordinate_safe([1e10+.25,0.,0.],[.25,.375,.5]),"GPU presentation refuses overflow and sub-grid coordinate loss")
	map.cancel(); viewer._close_capture(); await open_source("scaled")
	map.compute()
	check(await wait_job() and map.result_data.is_empty() and not map.plane.visible and map.status.text.contains("unsupported"),"Unsupported source transform leaves no plausible stale map")
	map.cancel(); viewer._close_capture()
	await open_source("energy-only"); map.compute()
	check(map.current_channel == "amplitude" and map.channel_choice.selected < 0 and map.pending_id.is_empty() and map.result_data.is_empty(),"Missing signed amplitude never silently substitutes energy density")
	map.cancel(); viewer._close_capture()
	check(unrelated_completions == 0 and unrelated_failures == 0,"Map results and failures remain scoped away from other forms")
	if not capture.is_empty():
		viewer.shell.status_ui.acknowledge(); viewer._open_capture(capture); viewer.playing = false; viewer.orbit_enabled = false; await settle()
		map.open(); map.select_channel("amplitude"); map.sample_index.value = 20; map.band_low.text = ".05"; map.band_high.text = ".15"
		map.set_grid_xyz([-32,-32,32],[128,128,128],"z",[5,5],[32,32]); began = Time.get_ticks_usec(); map.compute()
		observations.model_callback_ms = (Time.get_ticks_usec()-began)/1000.
		check(await wait_job(60.) and not map.result_data.is_empty(),"Actual N192 capture reaches 128³-window viewport plane")
		if not map.result_data.is_empty():
			observations.model = {"publication_ms":map.publication_msec,"source":map.result_source.duplicate(true),"data":map.result_data.duplicate(true)}
			check(map.result_data.coverage.measured == 9 and map.result_data.support.status == "insufficient_support" and map.legend.text.contains("UNRESOLVED"),"Actual low-frequency support remains explicitly unresolved")
			map.compute(); check(await wait_job() and not map.result_data.is_empty(),"Actual warm batch reuses verification memo")
			observations.model_warm = {"publication_ms":map.publication_msec,"timings":map.result_data.timings}
			map.close(); await picture("model-a-plane-reference")
			if DisplayServer.get_name() != "headless":
				observations.model_baseline = await profile(false); observations.model_map = await profile(true)
				map.reference_visible.button_pressed = false; await picture("model-a-plane-only"); map.reference_visible.button_pressed = true
			map.open(); await picture("model-a-controls")
	await finish()
