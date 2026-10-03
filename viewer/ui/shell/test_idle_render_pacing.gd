extends SceneTree
## The empty startup must draw on change; intentional Auto Orbit must animate.
const Viewer = preload("res://main.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func sample() -> int:
	await create_timer(.5).timeout
	var before := Engine.get_frames_drawn()
	await create_timer(1.0).timeout
	return Engine.get_frames_drawn() - before

func run() -> void:
	var view = Viewer.new()
	root.add_child(view)
	check(view.generic_reader == null and view.playing, "Fresh viewer has no capture")
	var empty_draws := await sample()
	check(OS.low_processor_usage_mode and empty_draws <= 3, "Empty viewer draws only when its presentation changes")
	view.orbit_enabled = true
	var orbit_draws := await sample()
	check(not OS.low_processor_usage_mode and orbit_draws > 20, "Intentional Auto Orbit still animates")
	view.orbit_enabled = false
	var settled_draws := await sample()
	check(OS.low_processor_usage_mode and settled_draws <= 3, "Idle redraw stops again after Auto Orbit")
	view.free()
	print("IDLE RENDER PACING: ", checks, " checks, ", failures.size(), " failures; draws=", [empty_draws,orbit_draws,settled_draws])
	quit(0 if failures.is_empty() else 1)
