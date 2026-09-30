extends SceneTree
const Worker = preload("res://video/render_worker.gd")
class CheckedWorker extends Worker:
	func status(stage: String, message: String) -> void:
		super.status(stage,message)
		if stage == "rendering":
			assert(viewer.orbit_setup == null,"Offline export must never construct an orbit guide")
			assert(viewer.custom_orbit,"Export must consume the committed custom camera")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var worker := CheckedWorker.new(); worker.job_path = OS.get_cmdline_user_args()[0]; root.add_child(worker)
