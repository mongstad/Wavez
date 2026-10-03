extends SceneTree
## Focused render-pacing checks for an empty viewer and a loaded transport.
const Viewer = preload("res://main.gd")
const ResizeProfile = preload("res://ui/shell/resize_profile.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func run() -> void:
	var initial_low := OS.low_processor_usage_mode
	var initial_cap := Engine.max_fps
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	var view = Viewer.new()
	root.add_child(view)
	view.set_process(false)
	check(view.generic_reader == null and view.playing, "Startup has play intent but no capture")
	view._update_render_pacing()
	check(OS.low_processor_usage_mode and Engine.max_fps == 0, "Empty viewer renders on demand")
	view.orbit_enabled = true
	view._update_render_pacing()
	check(not OS.low_processor_usage_mode and Engine.max_fps == view.PAUSED_ORBIT_MAX_FPS, "Empty animated orbit draws with the paused cap")
	view.orbit_enabled = false
	view.generic_reader = RefCounted.new()
	view._update_render_pacing()
	check(not OS.low_processor_usage_mode and Engine.max_fps == 0, "Loaded active playback draws continuously")
	view.playing = false
	view._update_render_pacing()
	check(OS.low_processor_usage_mode and Engine.max_fps == 0, "Loaded paused playback renders on demand")
	view.generic_reader = null
	for _frame in 2: await process_frame
	ResizeProfile.enabled = true
	ResizeProfile.reset()
	for _event in 100: view.shell.request_layout()
	await process_frame
	var burst: Dictionary = ResizeProfile.report()
	check(burst.get("shell_layout_inclusive", {}).get("calls", 0) == 1, "One layout for a burst of native sizes")
	ResizeProfile.reset()
	root.size = Vector2i(1100, 720)
	for _frame in 3: await process_frame
	var settled: Dictionary = ResizeProfile.report()
	check(view.shell.size == root.get_visible_rect().size, "Final layout uses the last viewport size")
	check(settled.get("shell_layout_inclusive", {}).get("calls", 0) <= 3, "Native size settles without layout feedback")
	ResizeProfile.enabled = false
	view.free()
	OS.low_processor_usage_mode = initial_low
	Engine.max_fps = initial_cap
	print("RESIZE PACING: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
