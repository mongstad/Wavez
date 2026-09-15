extends Node2D
var polygon := PackedVector2Array()

func show_polygon(values: Array) -> void:
	polygon.clear()
	for value in values:polygon.append(Vector2(value[0],value[1]))
	queue_redraw()

func _draw() -> void:
	if polygon.size() < 2:return
	var outline := polygon.duplicate();outline.append(polygon[0])
	draw_polyline(outline,Color(1,.75,.15,.95),2,true)
