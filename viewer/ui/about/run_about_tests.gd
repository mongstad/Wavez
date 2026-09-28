extends SceneTree

func _initialize() -> void:
	root.add_child.call_deferred(preload("res://ui/about/test_about.gd").new())
