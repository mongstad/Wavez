extends Node
## Opt-in diagnostics for a person resizing the actual Wavez application.
const ResizeProfile = preload("res://ui/shell/resize_profile.gd")
const PlaybackProfile = preload("res://scene/playback_profile.gd")
var viewer
var path := ""
var stream: FileAccess
var last_usec := 0
var next_usec := 0
var last_draws := 0
var last_callbacks := 0
var longest_gap_ms := 0.0
var size_events := 0
var min_width := INF
var max_width := 0
var min_height := INF
var max_height := 0

func _ready() -> void:
	ResizeProfile.enabled = true
	PlaybackProfile.enabled = true
	ResizeProfile.reset()
	PlaybackProfile.reset()
	stream = FileAccess.open(path, FileAccess.WRITE)
	if stream == null:
		push_warning("Native resize monitor could not open output: " + path)
		ResizeProfile.enabled = false
		PlaybackProfile.enabled = false
		set_process(false)
		return
	get_window().size_changed.connect(_on_size_changed)
	last_usec = Time.get_ticks_usec()
	next_usec = last_usec + 1000000
	last_draws = Engine.get_frames_drawn()
	last_callbacks = Engine.get_process_frames()
	set_process(true)
	print("RESIZE MONITOR READY ", path)

func _on_size_changed() -> void:
	size_events += 1
	var size := get_window().size
	min_width = minf(min_width, size.x)
	max_width = maxi(max_width, size.x)
	min_height = minf(min_height, size.y)
	max_height = maxi(max_height, size.y)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	longest_gap_ms = maxf(longest_gap_ms, (now - last_usec) / 1000.0)
	last_usec = now
	if now < next_usec: return
	var phase_path := path.get_base_dir().path_join("phase.txt")
	var phase := FileAccess.get_file_as_string(phase_path).strip_edges() if FileAccess.file_exists(phase_path) else "unmarked"
	var layers = viewer.scene_layers
	var row := {"unix_seconds":Time.get_unix_time_from_system(),"phase":phase,"window":get_window().size,"mode":get_window().mode,"size_events":size_events,"width_range":[min_width,max_width] if size_events > 0 else [],"height_range":[min_height,max_height] if size_events > 0 else [],"draws":Engine.get_frames_drawn()-last_draws,"callbacks":Engine.get_process_frames()-last_callbacks,"longest_callback_gap_ms":longest_gap_ms,"capture_loaded":viewer.generic_reader != null,"capture_path":viewer.capture_path if viewer.generic_reader != null else "","playing":viewer.playing,"committed_time":viewer.committed_sample.get("requested_time"),"buffering":layers.is_buffering() if layers != null else false,"scene_error":layers.error if layers != null else "","low_processor":OS.low_processor_usage_mode,"max_fps":Engine.max_fps,"gpu_texture_mib":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)/1048576.0,"gpu_buffer_mib":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)/1048576.0,"ui_profile":ResizeProfile.report(),"playback_profile":PlaybackProfile.report()}
	stream.store_line(JSON.stringify(row))
	stream.flush()
	ResizeProfile.reset()
	PlaybackProfile.reset()
	size_events = 0
	min_width = INF
	max_width = 0
	min_height = INF
	max_height = 0
	longest_gap_ms = 0.0
	last_draws = Engine.get_frames_drawn()
	last_callbacks = Engine.get_process_frames()
	next_usec = now + 1000000
	if FileAccess.file_exists(path.get_base_dir().path_join("stop")):
		get_tree().quit()

func _exit_tree() -> void:
	ResizeProfile.enabled = false
	PlaybackProfile.enabled = false
