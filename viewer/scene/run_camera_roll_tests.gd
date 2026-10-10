extends SceneTree

func _initialize() -> void:
	root.add_child.call_deferred(preload("res://scene/test_camera_roll.gd").new())
