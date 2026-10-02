extends SceneTree
func _initialize() -> void:
	root.add_child(preload("res://ui/shell/test_empty_background.gd").new())
