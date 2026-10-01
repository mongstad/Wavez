extends Node
const GridView = preload("res://layers/grid_view.gd")
const Job = preload("res://video/render_job.gd")
const SourceIdentity = preload("res://video/source_identity.gd")
const Profile = preload("res://scene/playback_profile.gd")
const Timeline = preload("res://video/offline_timeline.gd")
var job_path := ""
var job: Dictionary
var directory := ""
var viewport: SubViewport
var viewer
var encoder_pid := -1
var completed := 0
var total := 0
var began := 0
var stopping := false
var trace: FileAccess
var timeline
var encoder_pipe: Dictionary = {}
var encoder_log: FileAccess
var encoder_error := ""
var inspection_source: Dictionary = {}
var selection_recipe: Dictionary = {}
var committed_output_bytes := 0
var initial_output_files := 0
var source_binding: Dictionary = {}
var metrics := {"sample_ms":0.0,"render_readback_ms":0.0,"png_ms":0.0}
var encoding_began := 0

func _ready() -> void:
	began = Time.get_ticks_msec()
	Profile.enabled = OS.get_environment("SIMSCOPE_VIDEO_PROFILE") == "1"
	get_tree().auto_accept_quit = false
	RenderingServer.render_loop_enabled = false # Offline frames own their draw calls.
	_configure_window()
	_run.call_deferred()

func _configure_window() -> void:
	# Godot cannot hide its main window after startup. Keep the real GPU display
	# connection but minimize this noninteractive worker and remove focusability.
	get_tree().root.title = "WAVEZ export worker"
	get_tree().root.unfocusable = true
	get_tree().root.mode = Window.MODE_MINIMIZED

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stopping = true

func _exit_tree() -> void:
	if encoder_pid > 0 and OS.is_process_running(encoder_pid): OS.kill(encoder_pid)

func cancelled() -> bool:
	return stopping or FileAccess.file_exists(directory.path_join("cancel"))

func status(stage: String, message: String) -> void:
	Job.write_json(directory.path_join("progress.json"), {"stage":stage, "message":message, "current_frame":completed, "total_frames":total, "elapsed_seconds":float(Time.get_ticks_msec()-began)/1000, "renderer_pid":OS.get_process_id(), "encoder_pid":encoder_pid, "output_path":job.get("output_path", ""), "intermediate_directory":directory})

func finish(stage: String, message: String, code: int) -> void:
	if cancelled() and stage == "failed":stage = "cancelled";message = "Export cancelled during source preparation.";code = 2
	metrics.elapsed_ms = Time.get_ticks_msec()-began
	if encoding_began > 0:metrics.encoding_ms = Time.get_ticks_msec()-encoding_began
	metrics.profile = Profile.report()
	Job.write_json(directory.path_join("metrics.json"),metrics)
	if encoder_pid > 0 and OS.is_process_running(encoder_pid): OS.kill(encoder_pid)
	if trace != null: trace.close()
	if encoder_log != null: encoder_log.close()
	status(stage, message)
	print("WAVEZ export: " + message)
	get_tree().quit(code)

func _run() -> void:
	directory = job_path.get_base_dir()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	if not parsed is Dictionary:
		job = {}
		finish("failed", "Invalid render-job JSON.", 1)
		return
	job = parsed
	if job.get("version") == 2:
		if job.has("exact_state"):job.state = preload("res://analysis/inspection_v3.gd").unpack(job.exact_state)
		var exact = preload("res://analysis/inspection_v3.gd").unpack(job.get("exact_timing",{}))
		if exact is Dictionary:
			for key in ["start_time","end_time","fps","playback_rate"]:
				if exact.has(key):job[key] = exact[key]
	var invalid := Job.validate(job)
	if not invalid.is_empty():
		finish("failed", invalid, 1)
		return
	total = Job.frame_total(job)
	if job.version == 2:
		var usage := output_usage();var required: float = float(total)*(float(job.width)*job.height*8+2097152)+usage+8388608
		var access := DirAccess.open(directory)
		if usage < 0 or initial_output_files+total*2+16 > 8192 or required > int(job.output_quota_bytes) or access == null or access.get_space_left() < int(job.output_quota_bytes)+268435456:finish("failed","Selection-aware render quota/file-count/free-space admission failed; choose a larger explicit quota or a shorter/smaller export.",1);return
		committed_output_bytes = usage+8388608
	if DisplayServer.get_name() == "headless":
		finish("failed", "This Godot build uses a dummy renderer in --headless mode. A GPU display connection is required; the monitor resolution does not limit export size.", 1)
		return
	var frames_dir := directory.path_join("frames")
	if DirAccess.dir_exists_absolute(frames_dir) and not DirAccess.get_files_at(frames_dir).is_empty():
		finish("failed", "Frame directory already contains files. Use a new job directory.", 1)
		return
	if DirAccess.make_dir_recursive_absolute(frames_dir) != OK:
		finish("failed", "Cannot create temporary frame directory.", 1)
		return
	if cancelled():finish("cancelled","Export cancelled before loading.",2);return
	if job.get("source") is Dictionary and SourceIdentity.is_local(job.source) and not SourceIdentity.unchanged(job.capture_path,job.source):finish("failed","Source changed before worker launch.",1);return
	var loading_began := Time.get_ticks_usec()
	status("loading", "Loading capture and reproducing viewer state…")
	viewport = SubViewport.new()
	viewport.size = Vector2i(int(job.width), int(job.height))
	viewport.size_2d_override = Vector2i(1440, roundi(1440.0 * job.height / job.width))
	viewport.size_2d_override_stretch = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	viewer = load("res://main.gd").new()
	viewer.offline_instance = true
	viewer.offline_cancel = cancelled
	viewer.capture_path = job.capture_path
	viewport.add_child(viewer)
	metrics.open_ms = (Time.get_ticks_usec()-loading_began)/1000.0
	viewer.set_process(false)
	viewer.set_process_unhandled_input(false)
	if viewer.frame_a == null:
		finish("failed", "Capture could not be loaded: " + viewer.status_label.text, 1)
		return
	var identity_began := Time.get_ticks_usec()
	if job.has("source"):
		var identity = job.source
		if not identity is Dictionary or not identity.get("committed_bytes") is String or not identity.committed_bytes.is_valid_int() or not identity.get("complete_frames") is float and not identity.get("complete_frames") is int:
			finish("failed","Invalid committed source extent.",1);return
		var matches := false
		if SourceIdentity.is_local(identity):matches = SourceIdentity.matches(viewer.generic_reader,identity)
		else:
			# Portable inspection recipes retain their explicit content-hash contract.
			# Normal dialog jobs use the local metadata/stamp binding above.
			matches = recipe_source_matches(identity) if job.version == 2 else await verify_prefix(identity)
		if not matches or identity.complete_frames < 1 or identity.complete_frames > viewer.frame_count or int(identity.complete_frames) != identity.complete_frames:
			finish("failed","Capture identity/committed extent changed after export was requested.",1);return
		viewer.frame_count = int(identity.complete_frames)
		if viewer.scene_layers != null and not viewer.generic_reader.pin_extent(int(identity.committed_bytes)):finish("failed","Invalid scene committed extent.",1);return
	source_binding = SourceIdentity.capture(viewer.generic_reader)
	if source_binding.is_empty():finish("failed","Cannot bind export to a reliable unchanged local source stamp.",1);return
	metrics.worker_identity_ms = (Time.get_ticks_usec()-identity_began)/1000.0
	metrics.snapshot_identity_ms = job.get("source_identity_ms",0)
	timeline = Timeline.new()
	if not timeline.build(viewer):
		finish("failed", timeline.error, 1)
		return
	if job.start_time < timeline.times[0] or job.end_time > timeline.times[-1]:
		finish("failed", "Selected range is outside the complete capture timestamps.", 1)
		return
	# Resolve the current source schema at the export start, not at capture open.
	# This also prevents visual-state restoration from resetting a later particle
	# mapping simply because that channel is absent from the first sample.
	if not source_unchanged():return
	var sample_began := Time.get_ticks_usec()
	var first_sample: Dictionary = timeline.sample(job.start_time)
	metrics.sample_ms += (Time.get_ticks_usec()-sample_began)/1000.0
	if not source_unchanged():return
	if first_sample.is_empty():
		finish("failed", timeline.error, 1)
		return
	# Version-1 jobs made before G1 inherit defaults only for newly added fields.
	var merged: Dictionary = Job.snapshot(viewer)
	merged.merge(job.state,true)
	var invalid_state: String = preload("res://scene/inspection_state.gd").validate_visual(viewer,merged)
	if not invalid_state.is_empty(): finish("failed",invalid_state,1); return
	Job.apply(viewer, merged)
	if job.version == 2:
		if not await load_selections():finish("failed","Selection recipe could not be verified/restored: "+viewer.selection_controller.temporal.durable.status.text,1);return
		Job.apply(viewer,merged)
	elif job.get("inspection_sidecars",false): inspection_source = source_binding.duplicate(true)
	# Rendering state is frozen; only deterministic sample and camera functions advance.
	viewer.playing = false
	viewer.orbit_enabled = false
	viewer.free_camera = false
	viewer.shell.prepare_export(job.get("presentation",{}))
	trace = FileAccess.open(directory.path_join("timing.jsonl"), FileAccess.WRITE)
	if trace == null:
		finish("failed", "Could not write timing manifest.", 1)
		return
	metrics.ready_ms = Time.get_ticks_msec()-began
	status("ready","Source verified; beginning offline rendering…")
	await get_tree().process_frame
	for n in range(total):
		if cancelled():
			finish("cancelled", "Export cancelled. Completed PNG frames retained in " + frames_dir, 2)
			return
		if job.version == 2 and not output_fits():finish("failed","Output quota or free-space headroom exhausted; partial frames retained.",1);return
		var time := Job.sample_time(job, n)
		if not source_unchanged():return
		sample_began = Time.get_ticks_usec()
		var point: Dictionary = timeline.sample(time)
		metrics.sample_ms += (Time.get_ticks_usec()-sample_began)/1000.0
		if not source_unchanged():return
		if point.is_empty():
			finish("failed", timeline.error, 1)
			return
		# The interactive viewer can disclose an unavailable preview and continue.
		# A video must not publish that missing scientific layer as a valid frame.
		# A layer before its first recorded sample has no failure reason and remains
		# legitimately absent under the current independent-clock semantics.
		if viewer.scene_layers != null:
			for info in viewer.scene_layers.layer_samples:
				if info.visible and info.status == "unavailable" and not info.get("reason", "").is_empty():
					finish("failed", "Layer %s at t=%s: %s" % [info.id,time,info.reason], 1)
					return
		if viewer.scene_layers != null and not await viewer.scene_layers.wait_for_surface():
			finish("failed",viewer.scene_layers.iso_error,1);return
		viewer.camera.transform = Timeline.camera_at(job.state, float(n)/job.fps, job.get("camera_mode", "locked") == "orbit", float(job.get("orbit_speed", 0.08)))
		if job.version == 2 and not await viewer.selection_controller.await_committed_overlay(150000,cancelled):
			finish("cancelled" if cancelled() else "failed","Frame selection resolution cancelled or unavailable; no stale overlay frame was published.",2 if cancelled() else 1);return
		viewer.shell.refresh_export()
		# Yield for layout, process events and cancellation without depending on a
		# visible OS window. Minimized/hidden windows may suppress the normal loop.
		await get_tree().process_frame
		if cancelled():
			finish("cancelled", "Export cancelled. Completed PNG frames retained in " + frames_dir, 2);return
		var render_began := Time.get_ticks_usec()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		RenderingServer.force_draw(false, 1.0 / float(job.fps))
		var img := viewport.get_texture().get_image()
		metrics.render_readback_ms += (Time.get_ticks_usec()-render_began)/1000.0
		if not source_unchanged():return
		if img == null or img.get_size() != Vector2i(int(job.width), int(job.height)):
			finish("failed", "Rendered dimensions do not match the requested resolution.", 1)
			return
		var path := frames_dir.path_join("frame%08d.png" % n)
		var png_began := Time.get_ticks_usec()
		if img.save_png(path) != OK:
			finish("failed", "Could not save PNG; check free disk space: " + path, 1)
			return
		metrics.png_ms += (Time.get_ticks_usec()-png_began)/1000.0
		if not metrics.has("first_frame_ms"):metrics.first_frame_ms = Time.get_ticks_msec()-began
		if job.version == 2:committed_output_bytes += FileAccess.open(path,FileAccess.READ).get_length()
		if job.get("inspection_sidecars",false) or job.version == 2:
			var record: Dictionary
			if job.version == 2:
				record = preload("res://analysis/inspection_v3.gd").snapshot(viewer.selection_controller.temporal,true)
				record.members = selection_recipe.members;record.asset_directory = "recipe.inspection"
				var payload = preload("res://analysis/inspection_v3.gd").unpack(record.payload)
				payload.base.render = {"selection_frame":viewer.selection_controller.frame_evidence(),"backend":RenderingServer.get_current_rendering_method(),"dimensions":[img.get_width(),img.get_height()]}
				if job.has("comparison"):payload.base.render.comparison = comparison_frame(n,time)
				payload.base.render.image = {"file":"frames/"+path.get_file(),"retained_after_encode":job.get("keep_frames",false),"width":img.get_width(),"height":img.get_height(),"sha256":FileAccess.get_sha256(path)}
				record.payload = preload("res://analysis/inspection_v3.gd").pack(payload)
			else:record = preload("res://scene/inspection_state.gd").snapshot(viewer,inspection_source)
			if record.is_empty(): finish("failed","Source changed while recording inspection state; PNGs retained.",1); return
			if job.version == 1:record.image = {"file":"frames/"+path.get_file(),"retained_after_encode":job.get("keep_frames",false),"width":img.get_width(),"height":img.get_height(),"sha256":FileAccess.get_sha256(path)}
			if Job.write_json(directory.path_join("inspection-%08d.json" % n),record) != OK:
				finish("failed","Could not write inspection sidecar; PNGs retained.",1); return
			if job.version == 2:committed_output_bytes += FileAccess.open(directory.path_join("inspection-%08d.json" % n),FileAccess.READ).get_length()
		var timing_record := {"n":n, "capture_time":time, "video_time":float(n)/job.fps, "a":point.a, "b":point.b, "alpha":point.alpha, "width":img.get_width(), "height":img.get_height(), "camera_origin":Job.vec(viewer.camera.position), "color_channel":viewer.color_channel, "colormap":viewer.colormap_name, "clean_view":viewer.clean_view, "trails":viewer.trails_enabled, "trail_instances":viewer.trail_mms[0].instance_count, "overlays":viewer.overlay_visible, "sample":viewer.committed_sample, "normalization":{"mode":viewer._effective_normalization(),"bounds":[viewer.range_min,viewer.range_max] if is_finite(viewer.range_min) and is_finite(viewer.range_max) else null}, "guides":viewer.guide_visibility}
		if job.has("comparison"):timing_record.comparison = comparison_frame(n,time)
		trace.store_line(JSON.stringify(timing_record))
		trace.flush()
		completed = n + 1
		status("rendering", "Rendering frame %d / %d" % [completed, total])
		# This optional test-only delay proves timing is independent of throughput.
		if job.get("test_frame_delay_ms", 0) > 0: await get_tree().create_timer(float(job.test_frame_delay_ms)/1000, true, false, true).timeout
	trace.close()
	trace = null
	if cancelled():
		finish("cancelled", "Export cancelled. PNG sequence retained in " + frames_dir, 2)
		return
	await encode(frames_dir)

func output_usage() -> int:
	var pending: Array[String] = [directory];var bytes := 0;var files := 0;var directories := 0
	while not pending.is_empty():
		var current: String = pending.pop_back();var access := DirAccess.open(current)
		if access == null:return -1
		directories += 1
		if directories > 1024:return -1
		for name in access.get_files():
			files += 1
			if files > 8192 or access.is_link(name):return -1
			var file := FileAccess.open(current.path_join(name),FileAccess.READ)
			if file == null:return -1
			bytes += file.get_length()
		for name in access.get_directories():
			if access.is_link(name):return -1
			pending.append(current.path_join(name))
	initial_output_files = files
	return bytes

func output_fits() -> bool:
	var bytes := committed_output_bytes;var access := DirAccess.open(directory)
	for name in ["encoded.partial.mp4","timing.jsonl","ffmpeg.log"]:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):bytes += FileAccess.open(path,FileAccess.READ).get_length()
	return bytes >= 0 and bytes <= int(job.output_quota_bytes) and access != null and access.get_space_left() >= 268435456

func load_selections() -> bool:
	if job.inspection_path != directory.path_join("recipe.inspection/inspection.json") or FileAccess.get_sha256(job.inspection_path) != job.inspection_sha256:return false
	selection_recipe = JSON.parse_string(FileAccess.get_file_as_string(job.inspection_path))
	var control = viewer.selection_controller
	control.temporal.durable.opened_paths = job.opened_paths.duplicate()
	control.bind_source()
	var start := Time.get_ticks_msec()
	while control.jobs.busy() and Time.get_ticks_msec()-start < 150000:
		if cancelled():control.jobs.shutdown();return false
		await get_tree().create_timer(.01).timeout
	if control.jobs.busy() or not control.jobs.error.is_empty():return false
	# The analysis bind already verifies this exact prefix. Do not hash it again
	# on the renderer thread before the portable recipe validator does its work.
	for key in ["sha256","committed_bytes","format"]:
		if control.source.get(key) != job.source.get(key):return false
	control.temporal.durable.load_from(job.inspection_path)
	start = Time.get_ticks_msec()
	while control.jobs.busy() and Time.get_ticks_msec()-start < 150000:
		if cancelled():control.jobs.shutdown();return false
		await get_tree().create_timer(.01).timeout
	return control.temporal.durable.last_recipe.get("restored",false) and control.temporal.durable.last_recipe.get("sha256") == job.inspection_sha256

func encode(frames_dir: String) -> void:
	if not source_unchanged():return
	encoding_began = Time.get_ticks_msec()
	var executable: String = job.get("ffmpeg_path", Job.find_ffmpeg())
	var staging := directory.path_join("encoded.partial.mp4")
	var crf: int = {"high":18, "balanced":21, "compact":25}[job.get("quality", "high")]
	var args := PackedStringArray(["-nostdin", "-n", "-hide_banner", "-loglevel", "error", "-framerate", str(int(job.fps)), "-start_number", "0", "-i", frames_dir.path_join("frame%08d.png"), "-frames:v", str(total), "-an", "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-progress", directory.path_join("encoding-progress.txt"), staging])
	Job.write_json(directory.path_join("encoding.json"), {"executable":executable, "arguments":Array(args), "final_output":job.output_path})
	if executable.is_empty() or not FileAccess.file_exists(executable):
		finish("frames_ready", "FFmpeg is unavailable. All PNG frames and encoding instructions are retained in " + directory, 0)
		return
	status("encoding", "Encoding H.264 MP4…")
	encoder_pipe = OS.execute_with_pipe(executable, args, false)
	encoder_pid = encoder_pipe.get("pid", -1)
	encoder_log = FileAccess.open(directory.path_join("ffmpeg.log"), FileAccess.WRITE)
	if encoder_pid <= 0:
		finish("failed", "Could not launch FFmpeg. PNG sequence retained in " + directory, 1)
		return
	while OS.is_process_running(encoder_pid):
		if not source_unchanged():return
		drain_encoder()
		if job.version == 2 and not output_fits():OS.kill(encoder_pid);finish("failed","Encoding reached the declared output quota; partial output retained.",1);return
		if cancelled():
			OS.kill(encoder_pid)
			finish("cancelled", "Encoding cancelled. PNGs and partial MP4 retained in " + directory, 2)
			return
		status("encoding", "Encoding H.264 MP4…")
		await get_tree().create_timer(0.1, true, false, true).timeout
	drain_encoder()
	if encoder_log != null: encoder_log.flush()
	var exit_code := OS.get_process_exit_code(encoder_pid)
	encoder_pid = -1
	if cancelled():
		finish("cancelled", "Export cancelled before publishing MP4. Intermediates retained in " + directory, 2)
		return
	var output := FileAccess.open(staging, FileAccess.READ)
	if exit_code != 0 or output == null or output.get_length() < 12:
		finish("failed", "FFmpeg failed (exit %d), or produced no valid output. %s\nPNGs and any partial MP4 retained in %s" % [exit_code, encoder_error.strip_edges().left(600), directory], 1)
		return
	output.seek(4)
	if output.get_buffer(4).get_string_from_ascii() != "ftyp":
		finish("failed", "Encoded output is not an MP4. Intermediates retained in " + directory, 1)
		return
	output.close()
	if job.version == 2 and not output_fits():finish("failed","Output exceeds the declared quota; no MP4 published.",1);return
	if not source_unchanged():return
	if Job.publish(staging, job.output_path) != OK:
		finish("failed", "Cannot publish MP4; output exists, is unwritable, or the filesystem cannot publish it safely. Encoded file retained in " + directory, 1)
		return
	if not job.get("keep_frames", false):
		# Only remove this job's known frames, after successful encoding/publication.
		for n in range(total): DirAccess.remove_absolute(frames_dir.path_join("frame%08d.png" % n))
		DirAccess.remove_absolute(frames_dir)
	finish("complete", "Saved " + job.output_path, 0)

func drain_encoder() -> void:
	for key in ["stdio", "stderr"]:
		if not encoder_pipe.has(key): continue
		var pipe: FileAccess = encoder_pipe[key]
		for _i in range(16):
			var data := pipe.get_buffer(4096)
			if data.is_empty(): break
			if encoder_log != null: encoder_log.store_buffer(data)
			if key == "stderr": encoder_error = (encoder_error + data.get_string_from_utf8()).right(4096)

func comparison_frame(n: int, raw_time: float) -> Dictionary:
	var comparison: Dictionary = preload("res://analysis/inspection_v3.gd").unpack(job.comparison)
	var timing: Dictionary = comparison.common.timing
	comparison.frame = {"index":n,"raw_time":raw_time,"aligned_time":float(timing.start_time)+float(n)/timing.fps*timing.playback_rate}
	return comparison

func source_unchanged() -> bool:
	if SourceIdentity.unchanged(job.capture_path,source_binding):return true
	finish("failed","Source changed during export; no MP4 published. Intermediates retained.",1)
	return false

func verify_prefix(identity: Dictionary) -> bool:
	if not identity.get("sha256") is String:return false
	var extent := int(identity.committed_bytes)
	var file := FileAccess.open(job.capture_path,FileAccess.READ)
	if file == null or extent < 16 or extent > file.get_length():return false
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	var remaining := extent;var chunks := 0
	status("verifying","Verifying explicit portable recipe source; cancellation is available…")
	while remaining > 0:
		if cancelled():return false
		var count := mini(1048576,remaining);var data := file.get_buffer(count)
		if data.size() != count:return false
		hash.update(data);remaining -= count;chunks += 1
		if chunks % 16 == 0:await get_tree().process_frame
	return hash.finish().hex_encode() == identity.get("sha256")

func recipe_source_matches(identity: Dictionary) -> bool:
	# Verify the small recipe envelope before pinning; load_selections performs
	# the existing strict portable-source verification before any rendered frame.
	if job.inspection_path != directory.path_join("recipe.inspection/inspection.json"):return false
	var file := FileAccess.open(job.inspection_path,FileAccess.READ)
	if file == null or file.get_length() > 983040:return false
	var raw := file.get_buffer(file.get_length())
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	if hash.finish().hex_encode() != job.inspection_sha256:return false
	var recipe = JSON.parse_string(raw.get_string_from_utf8())
	if not recipe is Dictionary or not recipe.get("payload") is Dictionary:return false
	var payload = preload("res://analysis/inspection_v3.gd").unpack(recipe.payload)
	if not payload is Dictionary or not payload.get("base") is Dictionary or not payload.base.get("source") is Dictionary:return false
	for key in ["sha256","committed_bytes","format"]:
		if not payload.base.source.get(key) is String or not identity.get(key) is String or payload.base.source[key] != identity[key]:return false
	var frames = payload.base.source.get("complete_frames")
	if not (frames is float or frames is int) or frames != identity.complete_frames:return false
	return true
