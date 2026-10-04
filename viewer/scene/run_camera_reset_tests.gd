extends SceneTree
const Tests = preload("res://scene/test_camera_reset.gd")

func _initialize() -> void:
	root.add_child(Tests.new())
