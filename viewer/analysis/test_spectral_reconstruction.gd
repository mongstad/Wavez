extends SceneTree
## Focused #424 integration: real full-grid derived textures and lifecycle.
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
func wait_job(seconds := 60.) -> bool:
	var until := Time.get_ticks_msec()+int(seconds*1000.)
	while (not map.pending_id.is_empty() or map.jobs.busy() or map.transfer.is_started()) and Time.get_ticks_msec() < until: await create_timer(.02).timeout
	return map.pending_id.is_empty() and not map.jobs.busy() and not map.transfer.is_started()
func wait_band(band: String) -> bool:
	var until := Time.get_ticks_msec()+30000
	while map.loaded_band != band and Time.get_ticks_msec() < until:
		if not map.transfer.is_started() and map.pending_id.is_empty(): break
		await create_timer(.02).timeout
	await settle()
	return map.loaded_band == band and map.reconstructed_view.texture != null
func seek(time: float) -> bool:
	viewer.playing = false
	var accepted: bool = viewer._seek_time(time)
	var until := Time.get_ticks_msec()+10000
	while viewer.committed_sample.get("requested_time",NAN) != time and Time.get_ticks_msec() < until: await process_frame
	await settle()
	return accepted and viewer.committed_sample.get("requested_time",NAN) == time
func source(path: String, index := 0) -> void:
	viewer._open_capture(path); viewer.playing = false; viewer.orbit_enabled = false; await settle()
	map.open(); map.select_object("field"); map.select_channel("amplitude"); map.sample_index.value = index
	map.edge_low.value = .125; map.edge_high.value = .375; map.boundary_ack.button_pressed = true; map.refresh_context(); await settle()
func prepare(label: String) -> bool:
	if map.jobs.worker_pid <= 0: map.jobs.start(out.path_join("analysis-workers"),"spectral_reconstruct")
	var began := Time.get_ticks_usec(); map.compute()
	var callback := (Time.get_ticks_usec()-began)/1000.
	var queued: bool = not map.pending_id.is_empty()
	var completed := await wait_job(90.)
	var ready: bool = completed and not map.result_data.is_empty() and await wait_band(map.selected_band)
	observations[label] = {"callback_ms":callback,"roundtrip_ms":(Time.get_ticks_usec()-began)/1000.,"data":map.result_data.duplicate(true),"source":map.result_source.duplicate(true),"status":map.status.text,"transfer":map.transfer_metrics.duplicate(true),"worker_reply":map.jobs._read("background_result.json")}
	check(queued and callback < 50.,label+": queues without source scan or FFT in callback")
	check(ready,label+": verified full-grid result reaches native texture")
	return ready
func picture(name: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
	if map.window.visible: map.window.get_texture().get_image().save_png(out.path_join(name+"-dialog.png"))
func mutate_copy(path: String) -> void:
	var file := FileAccess.open(path,FileAccess.READ_WRITE); file.seek(file.get_length()-1); var byte := file.get_8(); file.seek(file.get_length()-1); file.store_8(byte^1); file.flush(); file.close()
func memory_checkpoint() -> Dictionary:
	var result := {"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"engine_texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"engine_buffer_bytes":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"engine_static_bytes":OS.get_static_memory_usage(),"derived_texture_bytes":map.reconstructed_view.gpu_bytes}
	if DisplayServer.get_name() != "headless":
		var output: Array = []
		var code := OS.execute("nvidia-smi",["--query-gpu=memory.used","--format=csv,noheader,nounits"],output,true)
		result.device_query_exit = code
		if code == 0 and not output.is_empty(): result.whole_device_used_mib = str(output[0]).strip_edges()
	return result
func stats(values: Array) -> Dictionary:
	var ordered := values.duplicate(); ordered.sort(); var total := 0.
	for value in values: total += value
	return {"min":ordered[0],"median":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"max":ordered[-1],"mean":total/values.size()}
func camera_state() -> Dictionary:
	var state := {"transform":viewer.camera.transform}
	for key in ["yaw","pitch","camera_distance","camera_target","camera_orbit_basis","camera_orbit_basis_active","camera_orbit_basis_yaw","camera_orbit_basis_pitch","free_camera","orbit_enabled","orbit_speed"]: state[key] = viewer.get(key)
	return state
func restore_camera(state: Dictionary) -> void:
	for key in state:
		if key != "transform": viewer.set(key,state[key])
	viewer.camera.transform = state.transform
func profile() -> Dictionary:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await settle()
	var wall: Array = []; var gpu: Array = []; var cpu: Array = []
	var saved_camera := camera_state()
	viewer.orbit_enabled = true; viewer.orbit_speed = .012
	var last := Time.get_ticks_usec()
	for i in 90:
		await process_frame; await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec(); wall.append((now-last)/1000.); last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())); cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
	restore_camera(saved_camera)
	return {"frames":90,"wall_ms":stats(wall),"render_gpu_ms":stats(gpu),"render_cpu_ms":stats(cpu),"mean_fps":1000./stats(wall).mean,"memory":memory_checkpoint(),"resolution":[root.size.x,root.size.y],"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}
func click_control(control: Control) -> void:
	var window := control.get_window(); var point := control.get_global_rect().get_center()
	if window.is_embedded(): point += Vector2(window.position); window = root
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0; window.push_input(event,true)
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
func finish() -> void:
	if is_instance_valid(viewer):
		map.cancel(); await wait_job(5.); map.close(); viewer._close_capture(); viewer.queue_free(); await settle()
	var report := {"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"device":RenderingServer.get_video_adapter_name(),"gpu_memory_note":"NVIDIA checkpoints and CSV measure the whole device including desktop; differences are incremental observations, not isolated process VRAM. Engine counters cover the viewer but may omit driver allocations."}
	var file := FileAccess.open(out.path_join("native.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t",true,true)); file.close()
	print("SPECTRAL RECONSTRUCTION: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)

func run() -> void:
	create_timer(570).timeout.connect(func(): push_error("Reconstruction validation timed out"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reconstruction-output="): out = arg.trim_prefix("--reconstruction-output=")
		if arg.begins_with("--reconstruction-capture="): capture = arg.trim_prefix("--reconstruction-capture=")
	if out.is_empty(): quit(1); return
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); await settle(); map = viewer.spectral_reconstruction
	map.jobs.spectral_reconstruction_progress.connect(func(value):
		if value.get("id") == map.pending_id: progress_seen = value.duplicate(true))
	await source(out.path_join("reconstruction.wvz")); await seek(0.)
	check(map.jobs.worker_pid <= 0 and map.result_data.is_empty(),"Opening reconstruction does not start automatic computation")
	map.boundary_ack.button_pressed = false; map.compute()
	check(map.pending_id.is_empty() and map.jobs.worker_pid <= 0,"Periodic boundary assumption must be explicitly accepted")
	map.boundary_ack.button_pressed = true
	var visual := Visual.snapshot(viewer); var states: Dictionary = viewer.scene_layers.states.duplicate(true)
	if not await prepare("synthetic_cold"): await finish(); return
	var numeric: Dictionary = map.result_data.duplicate(true); var source_binding: Dictionary = map.result_source.duplicate(true)
	check(Visual.snapshot(viewer) == visual and viewer.scene_layers.states == states,"Reconstruction preserves ordinary visual and source-layer state")
	check(map.cancel_button.disabled,"Completed operation correctly disables Cancel")
	check(map.lower_range.value == map.result_data.common_range[0] and map.upper_range.value == map.result_data.common_range[1],"Original symmetric range is preserved exactly without SpinBox step rounding")
	var manifest_path: String = map.result_data.manifest.path
	var manifest_bytes := FileAccess.get_file_as_bytes(manifest_path)
	mutate_copy(manifest_path)
	var refused: Dictionary = preload("res://analysis/reconstructed_field.gd").new().prepare(map.result_data,"low",map.jobs.directory)
	check(refused.get("error","").contains("manifest SHA-256"),"Adapter refuses a tampered manifest before reading display planes")
	var restored := FileAccess.open(manifest_path,FileAccess.WRITE); restored.store_buffer(manifest_bytes); restored.close()
	var golden = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("known-point.json")))
	for band in ["original","low","intermediate","high"]:
		map.select_band(band); check(await wait_band(band),"Loads synthetic full volume: "+band)
		var images: Array[Image] = map.reconstructed_view.texture.get_data()
		check(images.size() == 32 and images[0].get_width() == 32 and absf(images[4].get_pixel(8,6).r-golden[band]) < 2e-6,"GPU texture contains the phase-sensitive analytic scalar, not regional tiles: "+band)
		check(map.reconstructed_view.gpu_bytes == 32*32*32*4 and map.reconstructed_view.lod == 1,"Complete native texture dimensions retained: "+band)
	check(map.result_data == numeric,"Band selection changes no scientific result")
	map.lower_range.value = -.75; map.upper_range.value = .75; map.opacity.value = .18; map.slice_enabled.button_pressed = true; map.clip_enabled.button_pressed = true; map.sync_visibility(); await settle()
	check(map.reconstructed_view.slice.visible and map.reconstructed_view.material.get_shader_parameter("clip_enabled") and map.reconstructed_view.material.get_shader_parameter("opacity") == map.opacity.value,"Slice, clipping and opacity reach the existing volume renderer")
	check(map.result_data == numeric and viewer.scene_layers.states == states,"Derived display edits preserve original state and float64 numerical results")
	map.slice_enabled.button_pressed = false; map.clip_enabled.button_pressed = false; map._reset_range(); map.sync_visibility()
	var texture = map.reconstructed_view.texture; check(await seek(1.),"Ordinary playback seek remains available")
	viewer.playing = true; viewer.physical_rate = .5; var initial: float = viewer.requested_time; await create_timer(.2).timeout; viewer.playing = false
	check(viewer.requested_time > initial and map.reconstructed_view.texture == texture and Exact.exact_float(map.result_data.record.native_time).value == 0.,"Playback moves while reconstruction remains pinned to native zero")
	await seek(0.)
	viewer.scene_layers.selected_volume = "field"; viewer.scene_layers.probe_channel = "amplitude"; viewer.scene_layers.probe_selected_volume()
	check(viewer.scene_layers.probe_label.text.to_lower().contains("unavailable") and map.reconstructed_view.probe(Vector3(4,3,2)) == null,"Derived viewport cannot present an ordinary source probe as a derived value")
	# Selection-controller foreground completions have selection-specific state.
	# A standalone owned worker tests this source query without impersonating that
	# controller's UI request or sending an unrelated result to its handlers.
	var probe_jobs = preload("res://analysis/analysis_jobs.gd").new(); root.add_child(probe_jobs)
	probe_jobs.start(out.path_join("probe-workers"))
	var token: String = probe_jobs.request(source_binding,"probe",{"object":"field","channel":"amplitude","time":0.,"coordinate":[4.,3.,2.]},viewer.capture_generation,viewer.selection_controller.state.revision)
	var probe_until := Time.get_ticks_msec()+10000
	while probe_jobs.pending and Time.get_ticks_msec() < probe_until: await create_timer(.02).timeout
	check(not probe_jobs.pending and probe_jobs.last_result.get("id") == token and absf(probe_jobs.last_result.get("data",{}).get("value",{}).get("value",INF)-golden.original) < 1e-12,"Independent owned scientific worker probe returns the known float64 original source value")
	probe_jobs.shutdown(); probe_jobs.queue_free()
	if DisplayServer.get_name() != "headless":
		check(not viewer.shell.edge_reveal.is_viewport_point(Vector2(map.window.position)+Vector2(map.window.size)*.5),"Nonmodal panel rectangle still consumes viewport navigation")
		click_control(viewer.shell.menus.View); await settle()
		check(viewer.shell.menus.View.get_popup().visible and not viewer.shell.edge_reveal.is_viewport_point(Vector2(500,450)),"An actual menu popup still blocks viewport navigation")
		viewer.shell.menus.View.get_popup().hide(); await settle()
		check(await preset("Cinematic") and map.window.visible and map.result_data == numeric,"Actual menu changes to Cinematic while nonmodal reconstruction remains open")
		check(await preset("Scientific") and map.window.visible and map.result_data == numeric,"Actual menu restores Scientific without recomputation")
		var camera_before: Transform3D = viewer.camera.transform
		var point := Vector2(500,450)
		var press := InputEventMouseButton.new(); press.position = point; press.global_position = point; press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.button_mask = MOUSE_BUTTON_MASK_RIGHT; root.push_input(press,true); await process_frame
		var motion := InputEventMouseMotion.new(); motion.position = point+Vector2(24,-12); motion.global_position = motion.position; motion.relative = Vector2(24,-12); motion.button_mask = MOUSE_BUTTON_MASK_RIGHT; root.push_input(motion,true); await process_frame
		var release := InputEventMouseButton.new(); release.position = motion.position; release.global_position = release.position; release.button_index = MOUSE_BUTTON_RIGHT; release.pressed = false; root.push_input(release,true); await settle()
		check(viewer.camera.transform != camera_before and map.window.visible and map.result_data == numeric,"Native viewport mouse navigation works while reconstruction controls remain open")
		camera_before = viewer.camera.transform
		var movement := InputEventKey.new(); movement.keycode = KEY_W; movement.physical_keycode = KEY_W; movement.pressed = true; movement.window_id = root.get_window_id(); Input.parse_input_event(movement)
		await create_timer(.15).timeout; movement.pressed = false; Input.parse_input_event(movement); await settle()
		check(viewer.camera.transform != camera_before and map.window.visible,"Native keyboard camera movement remains available with nonmodal controls open")
		var editor: LineEdit = map.lower_range.get_line_edit(); var editor_text := editor.text; editor.grab_focus(); await settle(); camera_before = viewer.camera.transform
		check(editor.has_focus() and map.window.gui_get_focus_owner() == editor,"Typing case has real focus in the child-window input")
		movement = InputEventKey.new(); movement.keycode = KEY_W; movement.physical_keycode = KEY_W; movement.unicode = 119; movement.pressed = true; movement.window_id = map.window.get_window_id(); Input.parse_input_event(movement)
		await create_timer(.15).timeout; movement.pressed = false; Input.parse_input_event(movement); await settle()
		check(viewer.camera.transform == camera_before,"Typing in a reconstruction input does not move the camera")
		editor.text = editor_text
		# Mouse takeover must release the child editor, otherwise the keyboard
		# guard would permanently suppress subsequent viewport navigation.
		camera_before = viewer.camera.transform; root.push_input(press,true); await process_frame; root.push_input(motion,true); await process_frame; root.push_input(release,true); await settle()
		check(not editor.has_focus() and viewer.camera.transform != camera_before,"Actual viewport RMB takeover releases child input focus and restores steering")
		camera_before = viewer.camera.transform
		movement = InputEventKey.new(); movement.keycode = KEY_W; movement.physical_keycode = KEY_W; movement.pressed = true; movement.window_id = root.get_window_id(); Input.parse_input_event(movement)
		await create_timer(.15).timeout; movement.pressed = false; Input.parse_input_event(movement); await settle()
		check(viewer.camera.transform != camera_before,"Keyboard camera movement resumes after leaving the panel input")
		map.window.hide(); var export_active: Image = viewer._save_image_viewport()
		var suspended: bool = map.suspend_presentation(); var export_source: Image = viewer._save_image_viewport(); map.restore_presentation(suspended)
		check(export_active != null and export_source != null and export_active.get_data() == export_source.get_data(),"Ordinary image export excludes reconstructed volume and legend")
		check(map.active() and map.reconstructed_view.quad.visible,"Image export restores pinned derived presentation")
		map.open()
	map.select_channel("other")
	check(map.result_data.is_empty() and not map.active(),"Explicit analysis channel change clears reconstruction")
	map.select_channel("amplitude"); await prepare("synthetic_recompute")
	viewer.scene_layers.states.field.channel = "other"; map._process(.2)
	check(map.result_data.is_empty() and not map.active(),"Ordinary source channel change clears reconstruction")
	viewer.scene_layers.states.field.channel = "amplitude"; await prepare("synthetic_close")
	viewer.scene_layers.selected_volume = "missing"; map.sync_visibility()
	check(map.result_data.is_empty() and not map.active(),"Changing the ordinary selected field/probe target invalidates reconstruction")
	viewer.scene_layers.selected_volume = "field"; await prepare("synthetic_close_after_target")
	map.close(); check(map.result_data.is_empty() and not map.active() and viewer.scene_layers.views.field.quad.visible,"Closing controls clears derived volume and restores ordinary source")
	check(viewer._close_capture(),"Completed reconstruction allows source close")
	await source(out.path_join("active.wvz")); progress_seen.clear(); map.compute()
	var until := Time.get_ticks_msec()+10000
	while progress_seen.is_empty() and not map.pending_id.is_empty() and Time.get_ticks_msec() < until: await create_timer(.01).timeout
	check(not map.pending_id.is_empty() and not map.cancel_button.disabled and not progress_seen.is_empty(),"Cancel is enabled during an observed active N192 operation")
	var owned: String = map.pending_id; viewer.spectral_band_map.open(); viewer.spectral_band_map.compute()
	check(map.jobs.background_id == owned and viewer.spectral_band_map.pending_id.is_empty(),"Regional map cannot steal active reconstruction worker ownership")
	viewer.spectral_band_map.close(); var began := Time.get_ticks_usec(); map.cancel(); var cancel_ms := (Time.get_ticks_usec()-began)/1000.
	check(await wait_job(5.) and map.result_data.is_empty() and not map.active(),"Active cancellation acknowledges without partial derived publication")
	observations.cancel = {"callback_ms":cancel_ms,"ack_ms":(Time.get_ticks_usec()-began)/1000.,"observed_progress":progress_seen.duplicate(true)}
	map.compute(); map.close(); check(await wait_job(5.) and map.result_data.is_empty(),"Close during computation cancels and rejects late publication")
	check(viewer._close_capture(),"Cancelled operation releases source close")
	await source(out.path_join("replacement.wvz")); if await prepare("replacement"):
		check(map.result_source.sha256 != source_binding.sha256,"New capture receives a distinct verified source binding")
	map.close()
	var regional = viewer.spectral_band_map; regional.open(); regional.select_object("field"); regional.select_channel("amplitude")
	regional.set_grid_xyz([8,8,8],[16,16,16],"z",[1,1],[16,16]); regional.band_low.text = ".05"; regional.band_high.text = ".25"; regional.compute()
	var regional_id: String = regional.pending_id; map.cancel()
	check(not regional_id.is_empty() and map.jobs.background_id == regional_id,"Reconstruction Cancel cannot cancel an independently owned regional-map request")
	check(await wait_job() and not regional.result_data.is_empty() and regional.plane.visible,"Existing regional map still publishes through its own worker routing")
	map.open(); if await prepare("regional_coexistence"):
		check(not regional.plane.visible and map.active(),"Reconstructed volume suspends the older regional plane")
		map.presentation_enabled.button_pressed = false; map.sync_visibility(); await settle()
		check(regional.plane.visible and not map.active(),"Hiding reconstruction restores the existing regional plane")
	regional.close()
	map.close(); check(viewer._close_capture() and map.result_data.is_empty(),"Source close clears result, texture and provenance")
	await source(out.path_join("zero.wvz")); if await prepare("zero_source"):
		check(map.result_data.common_range == [0.,0.] and map.lower_range.value == -1. and map.upper_range.value == 1. and map.legend.text.contains("zero-field"),"A zero scalar retains true zero range with an explicitly labeled display fallback")
	map.close(); viewer._close_capture()
	var mutation_path := out.path_join("source-mutation-copy.wvz")
	check(DirAccess.copy_absolute(out.path_join("reconstruction.wvz"),mutation_path) == OK,"Mutation case copies only a generated synthetic source")
	await source(mutation_path)
	map.jobs.start(out.path_join("analysis-workers"),"spectral_reconstruct")
	viewer.set_process(false); map.jobs.set_process(false); map.compute()
	var mutation_id: String = map.pending_id; var completed := {}; var mutation_until := Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < mutation_until:
		completed = map.jobs._read("background_result.json")
		if completed.get("id") == mutation_id and completed.get("ok",false): break
		await create_timer(.02).timeout
	check(not mutation_id.is_empty() and completed.get("id") == mutation_id and completed.get("ok",false),"Mutation case obtains a complete worker result before GUI publication")
	if completed.get("ok",false):
		var cached_stamp: Dictionary = viewer.generic_reader.source_stamp.duplicate(true)
		mutate_copy(mutation_path); map._completed(completed)
		check(viewer.generic_reader.source_stamp == cached_stamp and map.result_data.is_empty() and not map.active(),"Fresh source stat rejects an equal-size mutation at result acceptance before ordinary reader polling")
		observations.source_mutation = {"status":map.status.text,"boundary":"worker finished; source changed before GUI result acceptance"}
	map.jobs.set_process(true); viewer.set_process(true); await wait_job(5.)
	map.close(); viewer._close_capture()
	if not capture.is_empty():
		await source(capture,40); check(await seek(40.),"Actual capture seeks native forty")
		# Model A also records derived-marker particles. Hide that independent
		# ordinary layer explicitly so marker dots cannot imply scalar morphology.
		observations.model_layers = {"particle_object":viewer.scene_layers.particle_id,"particle_visibility_before":viewer.particle_layer_visible,"comparison_particle_visibility":false}
		viewer.particle_layer_visible = false; viewer._restyle()
		viewer._apply_preset("Scientific"); map.window.hide(); await settle()
		check(not viewer.current_instance.visible and not viewer.particle_layer_visible,"Actual scalar comparison excludes the independent derived-marker particle layer")
		observations.model_ordinary_memory = memory_checkpoint()
		if DisplayServer.get_name() != "headless": observations.model_ordinary_profile = await profile()
		if await prepare("model_t40_cold"):
			map.window.hide(); map.opacity.value = .25; map._reset_range(); map.sync_visibility(); await settle()
			var fixed_camera := camera_state(); var camera: Transform3D = viewer.camera.transform; var range_low: float = map.lower_range.value; var range_high: float = map.upper_range.value
			observations.model_views = {}
			for band in ["original","low","intermediate","high"]:
				restore_camera(fixed_camera)
				map.select_band(band); check(await wait_band(band),"Actual N192 texture loads: "+band)
				check(map.reconstructed_view.gpu_bytes == 192*192*192*4 and map.reconstructed_view.grid_size == Vector3(192,192,192),"Actual full 192 cubed field, no LOD substitute: "+band)
				check(viewer.camera.transform == camera and map.lower_range.value == range_low and map.upper_range.value == range_high and map.opacity.value == .25,"Actual comparison shares camera, range, color and opacity: "+band)
				await picture("model-t40-"+band+"-common-scale")
				observations.model_views[band] = {"transfer":map.transfer_metrics.duplicate(true),"state":map.display_state(),"memory":memory_checkpoint()}
				if DisplayServer.get_name() != "headless": observations.model_views[band].profile = await profile()
			for band in ["intermediate","high"]:
				map.select_band(band); await wait_band(band)
				var limit := .8 if band == "intermediate" else .15
				map.lower_range.value = -limit; map.upper_range.value = limit; map.sync_visibility(); await picture("model-t40-"+band+"-manual-detail-scale")
				observations["model_detail_"+band] = {"range":[-limit,limit],"opacity":map.opacity.value,"note":"Explicit manual shared range for detail inspection; not amplitude-comparable with the common-scale views."}
			map.select_band("intermediate"); await wait_band("intermediate"); map._reset_range()
			var original_camera := camera_state(); viewer.yaw += .65; viewer._update_camera(); await picture("model-t40-intermediate-alternate-angle-common-scale")
			restore_camera(original_camera); map.volume_enabled.button_pressed = false; map.slice_enabled.button_pressed = true
			for axis in [0,1,2]:
				map.plane_axis.select(axis); map._center_plane(); map.sync_visibility(); await picture("model-t40-intermediate-slice-"+str(axis)+"-common-scale")
			map.volume_enabled.button_pressed = true; map.slice_enabled.button_pressed = false; map.sync_visibility()
			map._reset_range(); map.open(); await picture("model-t40-controls")
			check(map.result_data.metrics.bands.intermediate.ac_fraction > .1997 and map.result_data.metrics.bands.intermediate.ac_fraction < .1998,"Actual intermediate band reproduces approximately twenty percent of AC variance")
	await finish()
