extends SceneTree
func _initialize() -> void:root.add_child(preload("res://layers/test_mesh_budget.gd").new())
