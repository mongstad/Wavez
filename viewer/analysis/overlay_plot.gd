extends Control
const Native = preload("res://analysis/native_plot.gd")
var plots: Array = []
var cursor := NAN

func publish(value: Dictionary) -> bool:
	if not value.get("plots") is Array or value.plots.is_empty() or value.plots.size() > 16:return false
	if JSON.stringify(value).to_utf8_buffer().size()*8 > 8*1048576:return false
	for item in value.plots:
		var validator := Native.new()
		var valid := validator.publish(item)
		validator.free()
		if not valid or not item.get("label") is String or item.label.length() > 128:return false
		for cell in item.bins:
			if cell.has("missing_x") and (not is_finite(float(cell.missing_x)) or float(cell.missing_x) < 0 or float(cell.missing_x) > 1):return false
	plots = value.plots;custom_minimum_size.y = 235+plots.size()*18;queue_redraw();return true

func clear() -> void:
	plots.clear();queue_redraw()

func bounds() -> Rect2:
	var top := 35+plots.size()*18
	return Rect2(Vector2(12,top),Vector2(maxf(1,size.x-24),maxf(1,size.y-top-25)))

func point(value: Array, box: Rect2) -> Vector2:
	return box.position+Vector2(float(value[3]),1-float(value[4]))*box.size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.04,.065))
	if plots.is_empty():return
	var box := bounds();var font := ThemeDB.fallback_font
	draw_rect(box,Color(.3,.36,.44),false)
	var first: Dictionary = plots[0]
	draw_string(font,Vector2(12,17),"%s [%s]" % [str(first.y_range),first.units],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12)
	for i in range(plots.size()):
		var item: Dictionary = plots[i];var color := Color.from_hsv(fmod(i*.618+.53,1),.55,1)
		draw_string(font,Vector2(12,35+i*18),"%s • %d finite / %d missing" % [item.label,int(item.finite),int(item.missing)],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12,color)
		for cell in item.bins:
			if int(cell.missing) > 0:
				var x: float = box.position.x+float(cell.get("missing_x",.5))*box.size.x
				draw_line(Vector2(x,box.end.y-5),Vector2(x,box.end.y),color,2)
			if cell.has("min") and cell.has("max"):
				var a := point(cell.min,box);var b := point(cell.max,box)
				draw_line(Vector2((a.x+b.x)/2,a.y),Vector2((a.x+b.x)/2,b.y),color*.7)
			for key in ["first","last","min","max"]:
				if cell.has(key):draw_circle(point(cell[key],box),2.2,color)
	var low := float(first.x_range[0]);var high := float(first.x_range[1])
	if is_finite(cursor) and low < high and cursor >= low and cursor <= high:
		var x := box.position.x+(cursor-low)/(high-low)*box.size.x
		draw_line(Vector2(x,box.position.y),Vector2(x,box.end.y),Color(1,.75,.2))
	draw_string(font,Vector2(12,size.y-7),"%s → %s • mapped time [%s]" % [first.x_range[0],first.x_range[1],first.time_units],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12)

func _get_tooltip(position: Vector2) -> String:
	var best := 144.0;var label := "Separate native observations; markers at the bottom indicate missing support."
	var box := bounds()
	for item in plots:
		for cell in item.bins:
			for key in ["first","last","min","max"]:
				if not cell.has(key):continue
				var distance := position.distance_squared_to(point(cell[key],box))
				if distance < best:
					best = distance;label = "%s\nMapped time: %s\nMapped value: %s %s\nFull source-result row: %s\nNative clock: %s\nTime reference: %s" % [item.label,cell[key][0],cell[key][1],item.units,cell[key][2],item.clock,item.mapping.time.reference]
	return label
