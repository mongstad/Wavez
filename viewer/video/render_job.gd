extends RefCounted
# JSON-only render jobs. File/Export/Video always uses version 1.
# Version 2 is retained for deliberately requested scientific Matched Views.
const VERSION := 1
const Renderer = preload("res://renderer_policy.gd")
const State = preload("res://scene/visual_state.gd")
const ExactState = preload("res://analysis/inspection_v3.gd")
const Spectral = preload("res://video/spectral_presentation.gd")
static func vec(v: Vector3) -> Array: return State.vec(v)
static func vector(a: Array) -> Vector3: return State.vector(a)
static func snapshot(viewer) -> Dictionary: return State.snapshot(viewer)
static func apply(viewer, state: Dictionary) -> void: State.apply(viewer,state)

static func frame_total(job: Dictionary) -> int:
	# Half-open [start,end); one frame for a still. Small epsilon removes FP noise.
	return maxi(1, int(ceil((float(job.end_time)-float(job.start_time)) * float(job.fps) / float(job.playback_rate) - 1e-9)))

static func sample_time(job: Dictionary, n: int) -> float:
	return float(job.start_time) + float(n) / float(job.fps) * float(job.playback_rate)

static func validate(job: Dictionary) -> String:
	if job.has("spectral_error"): return str(job.spectral_error)
	if job.has("spectral_presentation"):
		if job.get("version") != 1: return "Pinned spectral presentation is supported only by ordinary visual video export."
		if not job.spectral_presentation is Dictionary: return "Invalid pinned spectral presentation."
		var spectral_problem := Spectral.validate(Spectral.decode(job.spectral_presentation))
		if not spectral_problem.is_empty(): return spectral_problem
	if job.get("rendering_method",Renderer.METHOD) != Renderer.METHOD:
		return Renderer.REQUIREMENT + " Render jobs must use forward_plus."
	if job.has("presentation"):
		var presentation = job.presentation
		if not presentation is Dictionary: return "Invalid export presentation."
		for key in presentation:
			if key not in ["workspace","scroll","remaining"]: return "Unsupported export presentation field: " + str(key)
		for key in ["workspace","scroll"]:
			var value = presentation.get(key,0)
			if not (value is int or value is float) or not is_finite(value) or value != floor(value) or value < 0 or value > (3 if key == "workspace" else 2147483647): return "Invalid export presentation " + key
		if presentation.has("remaining") and not presentation.remaining is bool: return "Invalid export remaining preference."
	if job.get("version") == 2:
		for key in job:
			if key not in ["version","capture_path","source","state","start_time","end_time","start_frame","end_frame","fps","width","height","playback_rate","output_path","camera_mode","orbit_speed","quality","keep_frames","inspection_sidecars","ffmpeg_path","rendering_method","inspection_path","inspection_sha256","opened_paths","exact_timing","exact_state","presentation","test_frame_delay_ms","comparison","output_quota_bytes"]:return "Unsupported version-2 render field: "+key
		var compatible := job.duplicate(true);compatible.version = 1
		var base_problem := validate(compatible)
		if not base_problem.is_empty():return base_problem
		if not job.get("source") is Dictionary or not job.source.has_all(["path","sha256","committed_bytes","format","complete_frames"]):return "Version 2 requires the pinned source extent."
		if not job.get("output_quota_bytes") is String or not job.output_quota_bytes.is_valid_int() or int(job.output_quota_bytes)<1048576 or int(job.output_quota_bytes)>68719476736:return "Choose a finite 1 MiB–64 GiB selection-aware output quota."
		if not job.get("inspection_path") is String or not job.inspection_path.is_absolute_path() or not FileAccess.file_exists(job.inspection_path) or not job.get("inspection_sha256") is String or job.inspection_sha256.length() != 64:return "Version 2 requires a pinned portable inspection."
		if not job.get("opened_paths") is Array or job.opened_paths.size() > 128 or job.capture_path not in job.opened_paths:return "Explicit render source permissions are missing."
		if not job.get("exact_timing") is Dictionary:return "Exact version-2 timing is missing."
		var exact = ExactState.unpack(job.exact_timing)
		if not exact is Dictionary or exact.size() != 4 or not exact.has_all(["start_time","end_time","fps","playback_rate"]):return "Invalid exact render timing."
		for key in exact:
			if not preload("res://scene/inspection_state.gd").numeric(exact[key]) or exact[key] != job.get(key):return "Exact render timing differs: "+key
		if job.has("exact_state") and ExactState.unpack(job.exact_state) != job.state:return "Exact render state differs."
		if job.has("comparison"):
			var comparison = ExactState.unpack(job.comparison)
			if not comparison is Dictionary or comparison.get("kind") != "wavez-matched-render" or comparison.get("version") != 1 or comparison.get("side") not in ["left","right"] or not comparison.get("common") is Dictionary or not comparison.common.get("timing") is Dictionary:return "Invalid matched comparison metadata."
			var problem := validate_comparison(job,comparison)
			if not problem.is_empty():return problem
		return ""
	if job.get("version", 0) != VERSION: return "Unsupported render-job version."
	for key in ["start_time", "end_time", "fps", "playback_rate", "width", "height"]:
		var value = job.get(key)
		if not (value is int or value is float) or not is_finite(value): return "Invalid " + key
	if job.fps < 1 or job.fps > 240 or int(job.fps) != job.fps: return "FPS must be an integer from 1 to 240."
	var orbit_rate = job.get("orbit_speed", 0.08)
	if not (orbit_rate is int or orbit_rate is float) or not is_finite(orbit_rate): return "Orbit speed must be finite."
	if job.playback_rate <= 0: return "Playback rate must be positive."
	if job.end_time < job.start_time: return "End time must be at or after start time."
	for key in ["width", "height"]:
		var value: float = job[key]
		if value < 64 or value > 8192 or int(value) != value or int(value) % 2: return "Dimensions must be even integers between 64 and 8192."
	# Check in floating point before conversion: a finite input can still overflow
	# when subtracting endpoints or dividing by a very small playback rate.
	var frames: float = (float(job.end_time) - float(job.start_time)) * float(job.fps) / float(job.playback_rate)
	if not is_finite(frames) or frames > 10000000: return "Export exceeds 10 million frames. Choose a shorter range."
	for key in ["capture_path", "output_path", "ffmpeg_path"]:
		if job.has(key) and not job[key] is String: return "Invalid " + key
	if not job.get("capture_path", "").is_absolute_path() or not FileAccess.file_exists(job.capture_path): return "Capture file is missing or not an absolute path."
	if not job.get("output_path", "").is_absolute_path() or job.output_path.get_extension().to_lower() != "mp4": return "Choose an absolute .mp4 output path."
	if FileAccess.file_exists(job.output_path): return "Output already exists. Choose a new filename."
	if not DirAccess.dir_exists_absolute(job.output_path.get_base_dir()): return "Output directory does not exist."
	if not job.get("state") is Dictionary: return "Viewer state is missing."
	var state: Dictionary = job.state
	if not state.get("camera_transform") is Array or state.camera_transform.size() != 4: return "Camera transform is missing."
	for a in state.camera_transform + [state.get("camera_target", [])]:
		if not a is Array or a.size() != 3: return "Invalid camera vector."
		for v in a:
			if not (v is int or v is float) or not is_finite(v): return "Invalid camera value."
	if not state.get("camera") is Dictionary: return "Camera settings are missing."
	if job.get("quality", "high") not in ["high", "balanced", "compact"]: return "Unknown quality setting."
	if job.get("camera_mode", "locked") not in ["locked", "orbit"]: return "Unknown camera mode."
	return ""

static func validate_comparison(job: Dictionary, comparison: Dictionary) -> String:
	if not comparison.get("inputs") is Array or comparison.inputs.size() != 2 or comparison.get("frames") != frame_total(job):return "Matched input/frame inventory differs."
	var common: Dictionary = comparison.common
	if not common.has_all(["camera","timing","width","height","range","colormap","coordinates"]):return "Incomplete matched display settings."
	if not common.camera is Dictionary or not common.camera.has_all(["camera_transform","camera_target","camera","camera_distance","yaw","pitch"]) or not common.range is Array or common.range.size() != 2 or common.width != job.width or common.height != job.height:return "Matched display dimensions/range differ."
	for key in common.camera:
		if common.camera[key] != job.state.get(key):return "Shared matched camera differs: "+key
	var input = comparison.inputs[0 if comparison.side == "left" else 1]
	if not input is Dictionary or not input.has_all(["source","time","value","object","channel","source_range"]):return "Incomplete matched source mapping."
	if not input.source is Dictionary or not input.time is Dictionary or not input.value is Dictionary:return "Invalid matched source/clock."
	for key in ["path","sha256","committed_bytes","format"]:
		if input.source.get(key) != job.source.get(key):return "Matched source differs from pinned render source."
	var scale := preload("res://scene/source_sampling.gd").exact_float(input.time.get("scale"))
	var offset := preload("res://scene/source_sampling.gd").exact_float(input.time.get("offset"))
	if scale.is_empty() or offset.is_empty() or scale.value <= 0 or not common.timing.has_all(["start_time","end_time","fps","playback_rate"]):return "Invalid matched time mapping."
	for key in common.timing:
		if not preload("res://scene/inspection_state.gd").numeric(common.timing[key]):return "Invalid aligned time."
	if job.start_time != (common.timing.start_time+offset.value)/scale.value or job.end_time != (common.timing.end_time+offset.value)/scale.value or job.playback_rate != common.timing.playback_rate/scale.value or job.fps != common.timing.fps:return "Raw render timing differs from declared alignment."
	var value_scale := preload("res://scene/source_sampling.gd").exact_float(input.value.get("scale"))
	var value_offset := preload("res://scene/source_sampling.gd").exact_float(input.value.get("offset"))
	if value_scale.is_empty() or value_offset.is_empty() or value_scale.value <= 0 or not input.source_range is Array or input.source_range.size() != 2 or not input.channel is Dictionary or not input.channel.get("channel") is String:return "Invalid matched value mapping."
	var bounds: Array = []
	for n in range(2):
		var endpoint := preload("res://scene/source_sampling.gd").exact_float(input.source_range[n])
		if endpoint.is_empty() or not preload("res://scene/inspection_state.gd").numeric(common.range[n]) or endpoint.value != (common.range[n]-value_offset.value)/value_scale.value:return "Matched source and common ranges differ."
		bounds.append(endpoint.value)
	var layer = job.state.get("scene",{}).get("layers",{}).get(input.object)
	if layer is Dictionary:
		if layer.channel != input.channel.channel or layer.lower != bounds[0] or layer.upper != bounds[1] or layer.colormap != common.colormap:return "Matched layer scalar mapping differs."
	elif job.state.color_channel != input.channel.channel or job.state.manual_min != bounds[0] or job.state.manual_max != bounds[1] or job.state.colormap_name != common.colormap or job.state.normalization_mode != "manual" or job.state.logarithmic or job.state.cyclic or job.state.invert_map:return "Matched particle scalar mapping differs."
	return ""

static func publish(staging: String, destination: String) -> Error:
	if OS.get_name() == "Linux":
		# A same-filesystem hard link atomically claims the destination without
		# replacing files (including dangling symlinks) created during encoding.
		# -T also prevents treating a competing directory as a target directory.
		var result := OS.execute("/bin/ln", PackedStringArray(["-T", "--", staging, destination]))
		if result != 0: return ERR_CANT_CREATE
		DirAccess.remove_absolute(staging)
		return OK
	# Other platforms retain the existing best-effort publication path.
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination): return ERR_ALREADY_EXISTS
	return DirAccess.rename_absolute(staging, destination)

static func write_json(path: String, data: Dictionary) -> Error:
	if data.has("capture_path") and data.get("spectral_presentation") is Dictionary and data.spectral_presentation.get("kind") == "spectral_reconstruction" and data.spectral_presentation.has_all(["data","display"]):
		# Repeated JSON decimal conversion can move scientific metadata by ULPs.
		# Reuse the existing lossless float codec; ordinary jobs are unchanged.
		data = data.duplicate(true)
		data.spectral_presentation = Spectral.encode(data.spectral_presentation)
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t", true, true))
	f.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

static func find_ffmpeg() -> String:
	var executable := "ffmpeg.exe" if OS.get_name() == "Windows" else "ffmpeg"
	var separator := ";" if OS.get_name() == "Windows" else ":"
	for directory in OS.get_environment("PATH").split(separator):
		var candidate := directory.path_join(executable)
		if FileAccess.file_exists(candidate): return candidate
	return ""

static func ffmpeg_problem(path: String) -> String:
	if path.is_empty() or not path.is_absolute_path() or not FileAccess.file_exists(path):
		return "FFmpeg executable is unavailable: " + path
	var output: Array = []
	var result := OS.execute(path, PackedStringArray(["-version"]), output, true)
	if result != 0 or output.is_empty() or not str(output[0]).to_lower().begins_with("ffmpeg version"):
		return "The selected file could not run as FFmpeg: " + path
	return ""

static func launch_arguments(job_path: String, fps: int) -> PackedStringArray:
	var args := PackedStringArray(["--rendering-method",Renderer.METHOD,"--rendering-driver",Renderer.DRIVER])
	# Official export templates reject path overrides. The standalone executable
	# opens its own PCK; only the development engine needs a project directory.
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--resolution", "640x360", "--position", "0,0", "--fixed-fps", str(fps), "--disable-vsync", "--audio-driver", "Dummy", "--log-file", job_path.get_base_dir().path_join("renderer.log"), "--", "--wavez-render-job=" + job_path])
	return args
