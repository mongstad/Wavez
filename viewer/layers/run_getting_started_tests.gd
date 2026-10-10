extends SceneTree
func _initialize() -> void:
	root.add_child.call_deferred(preload("res://layers/test_getting_started.gd").new())
