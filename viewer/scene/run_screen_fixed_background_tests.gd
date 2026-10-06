extends SceneTree
func _initialize() -> void:
	root.add_child(preload("res://scene/test_screen_fixed_background.gd").new())
