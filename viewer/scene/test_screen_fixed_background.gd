extends Node
## Issue #205: the cinematic sky stays in viewport space while the camera moves.
const Viewer = preload("res://main.gd")
const Hash = preload("res://data/capture_index.gd")
const Job = preload("res://video/render_job.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
var phases := {}
@onready var root: Window = get_tree().root

func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for i in 8: await get_tree().process_frame
	RenderingServer.force_draw(false)
func image() -> Image:
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()
func digest(source: Image) -> String: return Hash.digest(source.get_data())
func sky_corner(source: Image) -> String:
	return digest(source.get_region(Rect2i(16, 16, 64, 64)))
func ready(view) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 12000:
		await get_tree().process_frame
		if not view.scene_layers.is_buffering() and (not view.scene_layers.field_playback.active() or view.scene_layers.field_playback.worker.status().session.get("state") == "ready"): break
	check(not view.scene_layers.is_buffering(), "Loaded sample ready")
	await settle()
func compare_sky(view, baseline: String, label: String, full_image: String = "") -> void:
	await settle()
	var frame := image()
	check(sky_corner(frame) == baseline, label + " keeps the sky pixels screen-fixed")
	if not full_image.is_empty():
		check(digest(frame) == full_image, label + " keeps the full empty viewport unchanged")
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	root.title = "WAVEZ #205 background regression"
	OS.low_processor_usage_mode = false
	await get_tree().process_frame
	# A package starts Main.tscn as well as this validation autoload. Remove
	# that bootstrap so its camera cannot cover the dedicated export-style view.
	if get_tree().current_scene != null:
		RenderingServer.force_draw(false)
		get_tree().current_scene.queue_free()
		await get_tree().process_frame
		RenderingServer.force_draw(false)
	var view = Viewer.new()
	view.offline_instance = true # Same shell/viewport presentation as the export worker.
	root.add_child(view)
	view.set_process(false)
	await settle()
	check(view.environment.background_mode == Environment.BG_SKY, "Cinematic sky is active")
	var initial_camera: Transform3D = view.camera.transform
	var baseline := image()
	check(baseline.save_png(output.path_join("empty-default.png")) == OK, "Save initial sky image")
	var sky := sky_corner(baseline)
	var full_sky := digest(baseline)
	view._orbit_camera_by_drag(Vector2(0, 720), .006)
	check(view.camera.transform != initial_camera and view.camera.basis.y.dot(Vector3.UP) < 0, "LMB tumble crosses upside-down")
	await compare_sky(view, sky, "Upside-down LMB tumble", full_sky)
	check(image().save_png(output.path_join("empty-upside-down.png")) == OK, "Save upside-down sky image")
	view.manual_orbit_axis = view.camera.basis.y.normalized()
	view.manual_orbit_start_basis = view.camera.basis
	view._orbit_camera_horizontally(1.0, view.MANUAL_ORBIT_RATE)
	await compare_sky(view, sky, "View-relative manual orbit", full_sky)
	view._steer_camera(Vector2(310, -220))
	await compare_sky(view, sky, "RMB free-look steering", full_sky)
	view.camera_target += Vector3(30, -15, 6); view._update_camera()
	await compare_sky(view, sky, "Free Camera translation", full_sky)
	view.yaw += 1.2; view._update_camera()
	await compare_sky(view, sky, "Auto Orbit camera motion", full_sky)
	var wheel := InputEventMouseButton.new(); wheel.factor = 1.0
	view._zoom_camera(wheel, true)
	await compare_sky(view, sky, "Wheel zoom", full_sky)
	view._reset_camera()
	await compare_sky(view, sky, "Reset Camera", full_sky)
	view._focus_activity()
	await compare_sky(view, sky, "Frame Scene", full_sky)
	check(view.camera.transform == initial_camera, "Reset/Frame restore the default camera without changing it")
	view.camera.transform = Transform3D(Basis(Vector3.UP, 1.8), Vector3(20, -10, 30))
	await compare_sky(view, sky, "Direct offline export camera transform", full_sky)
	view._reset_camera()
	var default_again := image()
	check(digest(default_again) == digest(baseline), "Full empty viewport pixels return exactly")
	for dimensions in [Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		root.size = dimensions
		await settle()
		var resized := image()
		check(resized.get_size() == dimensions, "Viewport fills " + str(dimensions))
		var fixed := sky_corner(resized)
		view._orbit_camera_by_drag(Vector2(650, -810), .006)
		await compare_sky(view, fixed, "Resized tumble " + str(dimensions), digest(resized))
		check(resized.save_png(output.path_join("empty-%dx%d.png" % [dimensions.x, dimensions.y])) == OK, "Save resized sky " + str(dimensions))
		view._reset_camera()
	for mode in [Window.MODE_MAXIMIZED, Window.MODE_FULLSCREEN]:
		root.mode = mode
		await settle()
		var framed := image()
		check(framed.get_width() > 0 and framed.get_height() > 0, "Mode renders a complete viewport " + str(mode))
		view._orbit_camera_by_drag(Vector2(380, 270), .006)
		await compare_sky(view, sky_corner(framed), "Window mode " + str(mode), digest(framed))
		view._reset_camera()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 640)
	await settle()
	for kind in ["particles", "field", "mesh", "mixed"]:
		view._open_capture(output.path_join(kind + ".wvz"))
		await ready(view)
		view._set_clean(false)
		view._reset_camera()
		await settle()
		var before := image()
		if kind in ["particles", "mixed"]:
			check(before.save_png(output.path_join(kind + "-default.png")) == OK, "Save " + kind + " default image")
		if kind == "mixed":
			check(Job.write_json(output.path_join("mixed-cinematic-state.json"), Job.snapshot(view)) == OK, "Save the live Cinematic state for offline export")
		var corner := sky_corner(before)
		var pose: Transform3D = view.camera.transform
		var sample: Dictionary = view.committed_sample.duplicate(true)
		view._orbit_camera_by_drag(Vector2(150, -90), .006)
		await compare_sky(view, corner, kind + " tumble")
		var after := image()
		check(view.camera.transform != pose and digest(after) != digest(before), kind + " scene responds to camera movement")
		check(sample == view.committed_sample, kind + " scientific sample is unchanged")
		check(after.save_png(output.path_join(kind + "-tumbled.png")) == OK, "Save " + kind + " image")
		view._set_clean(true)
		check(view.environment.background_mode == Environment.BG_COLOR, kind + " Scientific preset retains plain background")
		view._reset_camera()
	phases["layouts"] = ["960x640", "1920x1080", "3840x2160"]
	var report := {"checks": checks, "failures": failures, "phases": phases, "renderer": RenderingServer.get_current_rendering_method(), "packaged": not OS.has_feature("editor")}
	FileAccess.open(output.path_join("screen-fixed-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SCREEN FIXED BACKGROUND: ", checks, " checks, ", failures.size(), " failures")
	view._reset_inspection_source()
	if view.generic_reader != null: view.generic_reader.close()
	RenderingServer.force_draw(false)
	view.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_tree().quit(0 if failures.is_empty() else 1)
