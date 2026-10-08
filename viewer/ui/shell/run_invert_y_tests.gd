extends SceneTree
func _initialize() -> void:
	root.add_child.call_deferred(preload("res://ui/shell/test_invert_y_axis.gd").new())
