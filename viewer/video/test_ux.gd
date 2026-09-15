extends SceneTree
const Job = preload("res://video/render_job.gd")
const Timeline = preload("res://video/offline_timeline.gd")
var fixture := ""
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("FAIL: " + description)
	else: print("PASS: " + description)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--video-fixture="):fixture = arg.trim_prefix("--video-fixture=")
	if fixture.is_empty():push_error("Missing --video-fixture");quit(1);return
	var viewer = load("res://main.gd").new()
	viewer.capture_path = fixture.path_join("fixture.ssc")
	viewer.scene_prebuffer_enabled = false;viewer.playing = false;viewer.orbit_enabled = false
	root.add_child(viewer)
	viewer.set_process(false)
	viewer.playing = false; viewer.orbit_enabled = false
	viewer.set_process_unhandled_input(false)
	await process_frame
	check(viewer.frame_a != null, "test capture opens")
	check(not viewer.trails_enabled, "recorded history disabled on startup")
	viewer._toggle_trails()
	check(viewer.trails_enabled, "T action enables trails")
	viewer._toggle_trails()
	viewer._apply_preset("Cinematic")
	viewer._apply_preset("Scientific")
	check(not viewer.trails_enabled, "presets preserve disabled trails")
	check(viewer.history.is_empty() and viewer.trail_mms.all(func(mm): return mm.instance_count == 0), "disabled trails allocate no instances/history")
	check(viewer.screenshot_directory.is_empty(), "screenshot folder starts empty")
	viewer._save_image()
	check(viewer.screenshot_pending and viewer.screenshot_dialog.visible, "first screenshot prompts for destination")
	viewer.screenshot_dialog.hide()
	viewer.screenshot_dialog.canceled.emit()
	check(not viewer.screenshot_pending and viewer.screenshot_directory.is_empty() and viewer.screenshot_count == 0, "cancel creates no screenshot and chooses no fallback")
	viewer._save_image()
	check(viewer.screenshot_dialog.visible, "cancelled choice prompts again")
	var folder := fixture.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	var screenshots_before := DirAccess.get_files_at(folder).size()
	viewer.screenshot_dialog.hide()
	await viewer._screenshot_directory_selected(folder)
	check(viewer.screenshot_count == 1 and viewer.screenshot_directory == folder, "directory selection saves first screenshot")
	await viewer._save_image()
	check(viewer.screenshot_count == 2 and not viewer.screenshot_dialog.visible, "later screenshot reuses session directory")
	check(DirAccess.get_files_at(folder).size() == screenshots_before + 2, "consecutive screenshots create two distinct files without overwriting")
	check(viewer.screenshot_notice.visible and folder in viewer.screenshot_notice.text, "visible saved-path confirmation")
	var second = load("res://main.gd").new()
	var second_viewport := SubViewport.new()
	second_viewport.size = Vector2i(640,360);second_viewport.own_world_3d = true
	root.add_child(second_viewport)
	second.capture_path = viewer.capture_path
	second.scene_prebuffer_enabled = false
	second_viewport.add_child(second)
	second.set_process(false)
	second.playing = false; second.orbit_enabled = false
	check(second.screenshot_directory.is_empty(), "new viewer session does not inherit screenshot folder")
	second._save_image()
	check(second.screenshot_dialog.visible, "new session prompts again")
	second.screenshot_dialog.hide();second_viewport.queue_free()
	viewer._set_clean(false)
	viewer.color_channel = "temperature"
	viewer.colormap_name = "inferno"
	viewer.brightness_scale = 1.3
	viewer.hidden_types[1] = true
	viewer._restyle()
	var state := Job.snapshot(viewer)
	var job := {"version":1, "capture_path":viewer.capture_path, "start_time":0.1, "end_time":0.3, "fps":30, "playback_rate":1.0, "width":1920, "height":1080, "output_path":fixture.path_join("unused.mp4"), "state":state}
	check(Job.validate(job).is_empty(), "complete snapshot validates")
	var malformed := job.duplicate(true)
	malformed.output_path = 123
	check(Job.validate(malformed) == "Invalid output_path", "malformed path returns a validation error")
	malformed = job.duplicate(true)
	malformed.playback_rate = 1e-300
	check("10 million" in Job.validate(malformed), "overflowing frame count is rejected before integer conversion")
	check(Job.frame_total(job) == 6, "half-open custom interval yields six frames")
	check(is_equal_approx(Job.sample_time(job, 3), .2), "frame clock uses capture units per video second")
	var track := Timeline.new()
	check(track.build(viewer), "capture timestamp index builds")
	var point := track.sample(.15)
	check(point.a == 1 and is_equal_approx(point.alpha,.5), "time-based interpolation between recorded frames")
	viewer.control_checks["Recorded history  [T]"].set_pressed(true)
	track.sample(.65)
	check(viewer.trails_enabled and viewer.history.size() == 5 and viewer.trail_mms[0].instance_count == 3, "UI enables actual recorded trail instances")
	check(viewer.trail_mms[0].get_instance_transform(0).origin.is_equal_approx(viewer.history[0].positions[0]), "enabled trails use recorded particle positions")
	viewer.control_checks["Recorded history  [T]"].set_pressed(false)
	check(not viewer.trails_enabled and viewer.history.is_empty() and viewer.trail_mms.all(func(mm): return mm.instance_count == 0), "UI disables and releases trail history and instances")
	track.error = "old failure"
	check(track.build(viewer) and track.cached_index == -1 and track.error.is_empty(), "rebuilding a timeline resets stale sample cache and errors")
	var transform := Timeline.camera_at(state,2,true,.2)
	var center: Vector3 = Job.vector(state.camera_target)
	var original: Vector3 = Job.vector(state.camera_transform[3])
	check(transform.origin.is_equal_approx(center + Basis(Vector3.UP,.4)*(original-center)), "orbit angle depends on output seconds")
	var clone = JSON.parse_string(JSON.stringify(state))
	Job.apply(viewer,clone)
	check(viewer.color_channel == "temperature" and viewer.colormap_name == "inferno" and viewer.hidden_types.has(1), "JSON snapshot preserves mappings and integer type filters")
	check(viewer.brightness_scale == 1.3 and not viewer.clean_view, "snapshot preserves cinematic appearance")
	clone.size_channel = "visual_size"
	clone.brightness_channel = "temperature"
	clone.auto_range = false
	clone.manual_min = 100.0
	clone.manual_max = 300.0
	clone.logarithmic = true
	clone.invert_map = true
	clone.clamp_map = false
	Job.apply(viewer, clone)
	check(viewer.size_channel == "visual_size" and viewer.brightness_channel == "temperature" and not viewer.auto_range and viewer.manual_min == 100 and viewer.manual_max == 300 and viewer.logarithmic and viewer.invert_map and not viewer.clamp_map, "snapshot restores size/brightness mappings and manual/log/invert/clamp normalization")
	Job.apply(viewer, state)
	var directory := fixture
	var publication := directory.path_join("publication %d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(publication)
	var staged := publication.path_join("staged.mp4")
	var destination := publication.path_join("final.mp4")
	Job.write_json(staged, {"content":"encoded"})
	Job.write_json(destination, {"content":"existing"})
	check(Job.publish(staged, destination) != OK and JSON.parse_string(FileAccess.get_file_as_string(destination)).content == "existing" and FileAccess.file_exists(staged), "publication refuses competing output and retains encoded file")
	DirAccess.remove_absolute(destination)
	check(Job.publish(staged, destination) == OK and FileAccess.file_exists(destination) and not FileAccess.file_exists(staged), "publication succeeds to an unused path containing spaces")
	Job.write_json(directory.path_join("state.json"), state)
	viewer.video_dialog.open()
	check(viewer.video_dialog.visible, "Export Video dialog opens")
	viewer.video_dialog.range_choice.select(0)
	check(viewer.video_dialog.settings().start_time == 0 and viewer.video_dialog.settings().end_time == 1, "entire capture uses exact indexed endpoints")
	viewer.video_dialog.range_choice.select(1)
	check(viewer.video_dialog.settings().start_time == viewer.video_dialog.opened_current, "current-position range uses captured sample time")
	viewer.video_dialog.hide()
	# The exported schema/count transition uses the same held-frame policy.
	viewer._open_capture(fixture.path_join("variable fixture.ssc"))
	var variable_track := Timeline.new()
	check(variable_track.build(viewer), "variable-count export index builds")
	variable_track.sample(.05)
	check(viewer.particle_count == 2 and viewer.current_mm.get_instance_transform(0).origin == Vector3.ZERO, "count change holds positions instead of blending unrelated particles")
	viewer.color_channel = "temperature"
	variable_track.sample(.2)
	check(viewer.color_channel == "fixed" and viewer.particle_count == 3, "changing schema removes unavailable export mapping")
	# Exercise the actual UI-to-child-process launch and verify the parent stays alive.
	viewer._open_capture(fixture.path_join("fixture.ssc"))
	viewer.playing = false
	viewer.video_dialog.open()
	viewer.video_dialog.range_choice.select(2)
	viewer.video_dialog.update_range()
	viewer.video_dialog.start.value = .1
	viewer.video_dialog.end.value = .2
	viewer.video_dialog.rate.value = 1
	viewer.video_dialog.output.text = directory.path_join("ui launch %d.mp4" % Time.get_ticks_usec())
	var before_frame: int = viewer.current_index
	viewer.video_dialog.start_export()
	check(viewer.video_dialog.pid > 0, "UI launches separate render process")
	viewer._step_frame(1)
	check(viewer.current_index == before_frame + 1, "parent playback remains usable during export")
	viewer.video_dialog.hide()
	var deadline := Time.get_ticks_msec() + 30000
	while viewer.video_dialog.pid > 0 and Time.get_ticks_msec() < deadline:
		await create_timer(.1).timeout
	check(viewer.video_dialog.last_progress.get("stage") == "complete", "UI worker reports successful MP4 completion")
	print("VIDEO UX: %d checks, %d failures" % [checks, failures])
	viewer.free()
	for i in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	quit(1 if failures else 0)
