extends SceneTree
## Real live-scene images and immutable jobs for independent video children.
const Visual = preload("res://scene/visual_state.gd")
const Job = preload("res://video/render_job.gd")
const SourceIdentity = preload("res://video/source_identity.gd")
var viewer
var map
var out := ""
var checks: Array = []
var observations := {}
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label); push_error(label)
func json_value(value):
	# JSON parses numeric arrays as floats; compare the full-precision wire
	# values rather than Godot's distinct typed in-memory arrays.
	return JSON.parse_string(JSON.stringify(value,"",true,true))
func settle() -> void:
	for i in 5: await process_frame
	RenderingServer.force_draw(false)
func wait_job() -> bool:
	var until := Time.get_ticks_msec()+45000
	while (not map.pending_id.is_empty() or map.jobs.busy() or map.transfer.is_started()) and Time.get_ticks_msec() < until: await create_timer(.01).timeout
	return map.pending_id.is_empty() and not map.jobs.busy() and not map.transfer.is_started()
func wait_band(band: String) -> bool:
	var until := Time.get_ticks_msec()+15000
	while map.loaded_band != band and Time.get_ticks_msec() < until:
		if not map.transfer.is_started() and map.pending_id.is_empty(): break
		await create_timer(.01).timeout
	await settle()
	return map.loaded_band == band and map.active()
func seek(time: float) -> void:
	viewer.playing = false; viewer._seek_time(time)
	var until := Time.get_ticks_msec()+10000
	while viewer.committed_sample.get("requested_time",NAN) != time and Time.get_ticks_msec() < until: await process_frame
	await settle()
func open_source(path: String) -> void:
	viewer._open_capture(path); viewer.playing = false; viewer.orbit_enabled = false
	await settle(); viewer._apply_preset("Scientific"); await seek(0.)
	map.open(); map.select_object("field"); map.select_channel("amplitude"); map.sample_index.value = 1
	map.edge_low.value = .125; map.edge_high.value = .375; map.boundary_ack.button_pressed = true
	map.refresh_context(); await settle()
func prepare() -> bool:
	if map.jobs.worker_pid <= 0: map.jobs.start(out.path_join("analysis-workers"),"spectral_reconstruct")
	map.compute(); var completed := await wait_job()
	var ready: bool = completed and not map.result_data.is_empty() and await wait_band(map.selected_band)
	check(ready,"Verified pinned reconstruction reaches the live renderer")
	return ready

func capture_live(cropped: bool, legends := true) -> Image:
	# Independent visual oracle: capture the currently drawn scene. It never calls
	# either image-export function or a reconstruction suspension/restoration API.
	var hidden: Array = []
	var windows: Array[Window] = []; viewer._collect_embedded_windows(viewer,windows)
	for window in windows: window.hide()
	var extent: Vector2 = viewer.get_viewport().get_visible_rect().size
	var crop := Rect2(Vector2.ZERO,extent)
	if cropped:
		var top: float = viewer.shell.bar.get_global_rect().end.y if not viewer.shell.immersive and viewer.shell.edge_reveal.states.top.visible and viewer.shell.bar.is_visible_in_tree() else 0.
		var bottom: float = viewer.shell.transport.get_global_rect().position.y if not viewer.shell.immersive and viewer.shell.edge_reveal.states.bottom.visible and viewer.shell.bottom_strip.is_visible_in_tree() else extent.y
		var right: float = viewer.resize_handle.get_global_rect().position.x if not viewer.shell.immersive and viewer.shell.edge_reveal.states.right.visible and viewer.shell.dock.is_visible_in_tree() else extent.x
		crop = Rect2(Vector2(0,top),Vector2(right,bottom-top))
	else:
		for item in [viewer.shell,viewer.resize_handle,viewer.overlay_panel,viewer.legend,viewer.shell.layer_legends]:
			if item != null and item.visible: hidden.append(item); item.hide()
	for item in [viewer.overlay_panel,viewer.spatial_spectrum.region_overlay,viewer.selection_controller.overlay]:
		if item != null and item.visible: hidden.append(item); item.hide()
	if viewer.screenshot_notice != null and viewer.screenshot_notice.visible: hidden.append(viewer.screenshot_notice); viewer.screenshot_notice.hide()
	var reconnect := false
	if not legends and map != null and RenderingServer.frame_pre_draw.is_connected(map.sync_visibility):
		map.sync_visibility(); RenderingServer.frame_pre_draw.disconnect(map.sync_visibility); reconnect = true
		if map.legend_panel.visible: hidden.append(map.legend_panel); map.legend_panel.hide()
	RenderingServer.force_draw(false)
	var image: Image = root.get_texture().get_image()
	for item in hidden: item.show()
	if reconnect: RenderingServer.frame_pre_draw.connect(map.sync_visibility)
	for window in windows: window.show()
	if cropped:
		var scale := Vector2(image.get_size())/extent
		return image.get_region(Rect2i(Vector2i(crop.position*scale),Vector2i(crop.size*scale)))
	return image

func image_case(name: String, spectral: bool) -> void:
	await settle()
	var before := Visual.snapshot(viewer)
	var display: Dictionary = map.display_state().duplicate(true) if spectral else {}
	var numerical: Dictionary = map.result_data.duplicate(true)
	var texture = map.reconstructed_view.texture
	var shown: bool = map.window.visible
	var reference := capture_live(true)
	reference.save_png(out.path_join(name+"-viewport.png"))
	var target := out.path_join(name+"-image.png")
	var error: Error = await viewer._capture_inspection_png(target,false,true)
	check(error == OK and FileAccess.file_exists(target),name+": existing image pipeline publishes PNG")
	if error != OK: return
	var saved := Image.load_from_file(target)
	check(saved.get_size() == reference.get_size() and saved.get_data() == reference.get_data(),name+": image pixels equal the active viewport scientific scene")
	check(Visual.snapshot(viewer) == before and map.result_data == numerical and map.reconstructed_view.texture == texture and map.window.visible == shown,name+": image export preserves active viewport and numerical result")
	if spectral:
		check(map.active() and map.display_state() == display,name+": reconstruction remains active with unchanged display settings")
		var record = JSON.parse_string(FileAccess.get_file_as_string(target.get_basename()+".json"))
		check(record is Dictionary and record.get("kind") == "wavez-visual-export",name+": derived visual provenance is written without optional inspection")
		if record is Dictionary and record.get("reconstruction") is Dictionary:
			check(record.source == map.result_source and record.reconstruction.selected_band == map.selected_band and record.reconstruction.record == map.result_data.record,name+": sidecar describes the selected reconstruction and pinned native sample")
			check(record.reconstruction.display == json_value(display) and record.visual == json_value(before),name+": sidecar preserves the exact serialized display and camera snapshot")
		observations[name] = {"display":display,"metadata":record,"reference_sha256":FileAccess.get_sha256(out.path_join(name+"-viewport.png")),"export_sha256":FileAccess.get_sha256(target)}
	else:
		check(not FileAccess.file_exists(target.get_basename()+".json"),name+": ordinary unchecked sidecar behavior remains unchanged")

func video_job(name: String, spectral: bool, legends := false) -> void:
	var directory := out.path_join(name); DirAccess.make_dir_recursive_absolute(directory)
	var reference := capture_live(false,legends); reference.save_png(directory.path_join("viewport.png"))
	var dialog = viewer.video_dialog; dialog.open(); dialog.range_choice.select(2); dialog.update_range(); dialog.set_range_times(0.,1.5)
	dialog.width.value = reference.get_width(); dialog.height.value = reference.get_height(); dialog.fps.value = 2; dialog.rate.value = 1
	dialog.camera_mode.select(0); dialog.rendering.select(0); dialog.overlays.button_pressed = legends; dialog.inspection_sidecars.button_pressed = true
	dialog.output.text = directory.path_join("result.mp4")
	var before := Visual.snapshot(viewer); var display: Dictionary = map.display_state().duplicate(true) if spectral else {}
	var job: Dictionary = dialog.configured_job(); job.keep_frames = true; job.ffmpeg_path = "/usr/bin/ffmpeg"; job.source = SourceIdentity.capture(viewer.generic_reader)
	check(job.has("spectral_presentation") == spectral,name+": production dialog freezes exactly the currently displayed field")
	if spectral and job.has("spectral_presentation"):
		var stage = load("res://video/spectral_presentation.gd").stage(job.spectral_presentation,directory)
		check(stage.get("ok",false),name+": selected artifact stages into independent video ownership")
		if not stage.get("ok",false): observations[name] = stage; dialog.hide(); return
		job.spectral_presentation = stage.snapshot
	check(Job.validate(job).is_empty(),name+": staged video job validates")
	check(Job.write_json(directory.path_join("job.json"),job) == OK,name+": immutable job written")
	check(Visual.snapshot(viewer) == before and (not spectral or map.display_state() == display),name+": staging does not change the active viewport")
	observations[name] = {"source":job.source,"spectral":spectral,"display":display,"size":[reference.get_width(),reference.get_height()],"legend":legends}
	dialog.hide()

func finish() -> void:
	if is_instance_valid(viewer):
		map.close(); await wait_job(); viewer._close_capture(); viewer.queue_free(); await settle()
	Job.write_json(out.path_join("native.json"),{"checks":checks,"failures":failures,"observations":observations,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name()})
	print("SPECTRAL EXPORT: ",checks.size()," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	create_timer(180).timeout.connect(func(): push_error("Spectral export parent timed out"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spectral-export-output="): out = arg.trim_prefix("--spectral-export-output=")
	if out.is_empty(): quit(1); return
	viewer = load("res://main.gd").new(); viewer.scene_prebuffer_enabled = false; root.add_child(viewer); await settle(); map = viewer.spectral_reconstruction
	await open_source(out.path_join("field.wvz"))
	if not await prepare(): await finish(); return
	var helper_checks: Array = await load("res://video/test_spectral_presentation.gd").new().run(map.export_snapshot().snapshot,out.path_join("helper-contracts"),viewer.get_tree())
	for result in helper_checks: check(result.ok,"Video helper: "+str(result.label))
	var source: Dictionary = map.result_source.duplicate(true)
	for band in ["original","low","intermediate","high"]:
		map.select_band(band); check(await wait_band(band),"Select "+band+" for visual export")
		await image_case(band,true); await video_job("video-"+band,true)
	map.select_band("low"); await wait_band("low")
	await video_job("video-legend",true,true)
	for i in 3:
		await seek(i*.5); capture_live(false,true).save_png(out.path_join("video-legend/viewport-%d.png" % i))
	await seek(0.)
	map.select_band("intermediate"); await wait_band("intermediate")
	var custom_palette: Array = []
	for i in 256:
		var fraction := float(i)/255.
		custom_palette.append([fraction,.15+.7*(1.-fraction),.2+.6*pow(sin(PI*fraction),2)])
	# This palette exists only in this parent's memory. The independent worker
	# must use frozen LUT bytes; a name lookup or built-in substitute cannot pass.
	viewer.colormaps["export-fixture"] = custom_palette
	map.select_colormap("export-fixture"); map.lower_range.value = -.45; map.opacity.value = .13; map.clip_enabled.button_pressed = true; map.slice_enabled.button_pressed = true; map.plane_axis.select(1); map._center_plane(); map.sync_visibility()
	viewer.camera.position += viewer.camera.basis.x*.5
	await image_case("custom",true); await video_job("video-custom",true)
	map.select_band("high")
	var busy_path := out.path_join("pending-transfer-must-not-publish.png")
	var busy_error: Error = await viewer._capture_inspection_png(busy_path,false,true)
	check(busy_error != OK and not FileAccess.file_exists(busy_path),"Image export refuses a pending band transfer instead of exporting another field")
	map.cancel(); await wait_job()
	check(map.result_data.is_empty(),"Cancelled transfer cannot supply stale image/video presentation")
	map.close(); await seek(0.)
	await image_case("ordinary",false)
	await video_job("video-ordinary",false)
	for i in 3:
		await seek(i*.5); capture_live(false,false).save_png(out.path_join("video-ordinary/viewport-%d.png" % i))
	await open_source(out.path_join("replacement.wvz"))
	check(map.result_data.is_empty() and not map.active(),"File switching clears spectral export selection")
	map.close(); await image_case("replacement-ordinary",false)
	map.open()
	if await prepare():
		var bound_source: Dictionary = map.result_source.duplicate(true)
		process_frame.connect(func(): viewer._open_capture(out.path_join("field.wvz")),CONNECT_ONE_SHOT)
		var switching_path := out.path_join("switch-attempt-preserves-active-scene.png")
		var switching_error: Error = await viewer._capture_inspection_png(switching_path,false,true)
		var switching_record = JSON.parse_string(FileAccess.get_file_as_string(switching_path.get_basename()+".json"))
		check(switching_error == OK and viewer.capture_path == out.path_join("replacement.wvz") and switching_record is Dictionary and switching_record.source == bound_source,"File-open attempt is blocked during image capture and the export remains bound to the active source")
		process_frame.connect(func(): map.select_band("low" if map.loaded_band != "low" else "high"),CONNECT_ONE_SHOT)
		var revision_path := out.path_join("revision-during-capture-must-not-publish.png")
		var revision_error: Error = await viewer._capture_inspection_png(revision_path,false,true)
		check(revision_error != OK and not FileAccess.file_exists(revision_path),"Band revision during image capture refuses stale publication")
		map.cancel(); await wait_job()
	await open_source(out.path_join("runtime-mutation.wvz"))
	if await prepare(): await video_job("video-source-midrender",true)
	await open_source(out.path_join("mutation.wvz"))
	if await prepare():
		await video_job("video-source-mutation",true)
		viewer.set_process(false)
		process_frame.connect(func():
			var file := FileAccess.open(out.path_join("mutation.wvz"),FileAccess.READ_WRITE); file.seek(file.get_length()-1); var last := file.get_8(); file.seek(file.get_length()-1); file.store_8(last^1); file.flush(); file.close()
		,CONNECT_ONE_SHOT)
		var path := out.path_join("changed-source-must-not-publish.png")
		var error: Error = await viewer._capture_inspection_png(path,false,true)
		check(error != OK and not FileAccess.file_exists(path),"Source mutation during image capture refuses publication without fallback")
		path = out.path_join("already-changed-source-must-not-publish.png")
		error = await viewer._capture_inspection_png(path,false,true)
		check(error != OK and not FileAccess.file_exists(path),"Already changed source refuses image export without fallback")
	check(FileAccess.get_sha256(out.path_join("field.wvz")) == source.sha256,"Original WVZ1 source is unchanged through every export")
	await finish()
