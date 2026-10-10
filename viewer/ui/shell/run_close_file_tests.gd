extends SceneTree
func _initialize() -> void:
	root.add_child.call_deferred(preload("res://ui/shell/test_close_file.gd").new())
