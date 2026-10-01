extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var worker = preload("res://video/render_worker.gd").new()
	worker.job_path = OS.get_cmdline_user_args()[0]
	root.add_child(worker)
