extends Node
## Window input is routed through this viewport's pre-GUI input phase.
var navigation
func _input(event: InputEvent) -> void:
	if is_instance_valid(navigation): navigation.handle(event, get_window())
