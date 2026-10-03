extends SceneTree
## Native resize diagnostic driven by a PID-scoped desktop harness.
const Viewer = preload("res://main.gd")
const ResizeProfile = preload("res://ui/shell/resize_profile.gd")
const PlaybackProfile = preload("res://scene/playback_profile.gd")
var output: String
var capture: String
var view
var resize_events := 0
var sizes: Array[Vector2i] = []
var transport_minimum_events := 0
var rows: Array[Dictionary] = []
var resize_attempts: Array[int] = []
var post_checks := {}

func _initialize() -> void:
	run.call_deferred()

func record_size() -> void:
	resize_events += 1
	sizes.append(root.size)

func record_minimum() -> void:
	transport_minimum_events += 1

func phase(name: String) -> void:
	FileAccess.open(output.path_join(name + ".ready"), FileAccess.WRITE).store_string(JSON.stringify({"x":root.position.x,"y":root.position.y,"width":root.size.x,"height":root.size.y}))
	while not FileAccess.file_exists(output.path_join(name + ".start")):
		await process_frame
	var start := Time.get_ticks_usec()
	var last := start
	var frames := Engine.get_frames_drawn()
	var callbacks := Engine.get_process_frames()
	var initial_resize := resize_events
	var initial_sizes := sizes.size()
	var initial_minimum := transport_minimum_events
	var camera_before: Transform3D = view.camera.transform
	var target_before: Vector3 = view.camera_target
	var distance_before: float = view.camera_distance
	var records_before: int = view.generic_reader.records.size() if view.generic_reader != null else 0
	ResizeProfile.reset()
	PlaybackProfile.reset()
	var longest_frame := 0.0
	var elapsed := 0.0
	var live: Array[Dictionary] = []
	var next_live := start + 1000000
	while not FileAccess.file_exists(output.path_join(name + ".stop")):
		await process_frame
		var now := Time.get_ticks_usec()
		longest_frame = maxf(longest_frame, (now - last) / 1000.0)
		last = now
		if now >= next_live:
			live.append({"seconds":(now-start)/1000000.0,"draws":Engine.get_frames_drawn()-frames,"callbacks":Engine.get_process_frames()-callbacks,"size_events":resize_events-initial_resize,"last_size":root.size,"longest_callback_gap_ms":longest_frame,"playback_time":view.committed_sample.get("requested_time")})
			FileAccess.open(output.path_join(name + "-live.json"), FileAccess.WRITE).store_string(JSON.stringify(live, "  "))
			next_live = now + 1000000
		if now - start > 25000000:
			push_error("Resize phase timed out: " + name)
			quit(1)
			return
	elapsed = (Time.get_ticks_usec() - start) / 1000000.0
	var phase_sizes := sizes.slice(initial_sizes)
	var widths := phase_sizes.map(func(value: Vector2i): return value.x)
	var heights := phase_sizes.map(func(value: Vector2i): return value.y)
	rows.append({"phase":name,"elapsed":elapsed,"draws":Engine.get_frames_drawn()-frames,"callbacks":Engine.get_process_frames()-callbacks,"longest_callback_gap_ms":longest_frame,"native_size_events":resize_events-initial_resize,"width_range":[widths.min(),widths.max()] if not widths.is_empty() else [],"height_range":[heights.min(),heights.max()] if not heights.is_empty() else [],"resize_attempts":resize_attempts.duplicate(),"transport_minimum_events":transport_minimum_events-initial_minimum,"window":root.size,"playback_time":view.committed_sample.get("requested_time"),"playing":view.playing,"source_loaded":view.generic_reader != null,"buffering":view.scene_layers.is_buffering() if view.scene_layers != null else false,"scene_error":view.scene_layers.error if view.scene_layers != null else "","camera_unchanged":view.camera.transform == camera_before and view.camera_target == target_before and view.camera_distance == distance_before,"records_unchanged":(view.generic_reader.records.size() if view.generic_reader != null else 0) == records_before,"ui_profile":ResizeProfile.report(),"playback_profile":PlaybackProfile.report()})
	FileAccess.open(output.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("RESIZE PHASE ", name, " ", rows[-1])
	while not FileAccess.file_exists(output.path_join(name + ".done")):
		await process_frame

func validate_after_resize() -> void:
	var before_target: Vector3 = view.camera_target
	var before_distance: float = view.camera_distance
	var record_count: int = view.generic_reader.records.size()
	var frame_index := mini(2, view.generic_reader.frames.size() - 1)
	var target_time: float = view.generic_reader.frames[frame_index].time
	post_checks["seek_accepted"] = view._seek_time(target_time)
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not view.scene_layers.is_buffering() and absf(float(view.committed_sample.get("requested_time", -INF)) - target_time) < .000001: break
	post_checks["seek_committed"] = absf(float(view.committed_sample.get("requested_time", -INF)) - target_time) < .000001
	post_checks["source_unchanged"] = view.generic_reader.records.size() == record_count
	post_checks["camera_unchanged"] = view.camera_target == before_target and view.camera_distance == before_distance
	var switched := false
	for id in view.scene_layers.panel_controls:
		var controls: Dictionary = view.scene_layers.panel_controls[id]
		if not controls.has("channel"): continue
		var choice: OptionButton = controls.channel
		for index in choice.item_count:
			var next_channel := str(choice.get_item_metadata(index))
			if next_channel == view.scene_layers.states[id].channel: continue
			choice.select(index)
			choice.item_selected.emit(index)
			switched = true
			post_checks["channel_selected"] = view.scene_layers.states[id].channel == next_channel
			break
		if switched: break
	post_checks["channel_available"] = switched
	if switched:
		deadline = Time.get_ticks_msec() + 12000
		while Time.get_ticks_msec() < deadline:
			await process_frame
			if not view.scene_layers.is_buffering(): break
		post_checks["channel_prepared"] = not view.scene_layers.is_buffering()
	post_checks["scene_error_free"] = view.scene_layers.error.is_empty()
	FileAccess.open(output.path_join("post-resize.json"), FileAccess.WRITE).store_string(JSON.stringify(post_checks, "  "))

func run() -> void:
	var args := OS.get_cmdline_user_args()
	output = args[0]
	capture = args[1]
	view = Viewer.new()
	ResizeProfile.enabled = true
	PlaybackProfile.enabled = true
	view.scene_prebuffer_enabled = false
	root.add_child(view)
	var native_start: Callable = view.shell.window_chrome.start_resize
	view.shell.window_chrome.start_resize = func(edge, id):
		resize_attempts.append(edge)
		native_start.call(edge, id)
	view.orbit_enabled = false
	root.title = "WAVEZ #158 resize diagnostic"
	root.size_changed.connect(record_size)
	view.shell.transport.minimum_size_changed.connect(record_minimum)
	await create_timer(1.0).timeout
	if args.size() <= 2 or args[2] != "playing":
		await phase("empty")
	if args.size() > 2 and args[2] == "empty":
		view.free()
		await process_frame
		quit(0)
		return
	view._open_capture(capture)
	view.playing = false
	await create_timer(1.0).timeout
	if args.size() <= 2 or args[2] != "playing":
		await phase("paused")
	view.scene_loop_playback = true
	view._toggle_playback()
	await create_timer(0.5).timeout
	await phase("playing")
	await phase("playing_idle")
	view.playing = false
	await create_timer(1.0).timeout
	await phase("recovered")
	await validate_after_resize()
	var valid := true
	for key in post_checks:
		if key != "channel_available" and not post_checks[key]: valid = false
	view.free()
	await process_frame
	quit(0 if valid else 1)
