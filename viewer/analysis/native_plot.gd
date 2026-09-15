extends Control
# Display-only envelope; full scientific rows live in the worker result store.
var data := {}
var cursor := NAN

func publish(value: Dictionary) -> bool:
	if not value.get("bins") is Array or value.bins.size() > 2048:return false
	if value.get("axis") not in ["record_index","native_time","lag"] or not value.get("units") is String or not value.get("time_units") is String:return false
	if not value.get("x_range") is Array or value.x_range.size() != 2:return false
	if value.get("y_range") != null and (not value.y_range is Array or value.y_range.size() != 2):return false
	if int(value.get("bin_count",0)) < 1 or int(value.bin_count) > 2048:return false
	if JSON.stringify(value).to_utf8_buffer().size() > 1048576:return false
	for cell in value.bins:
		if not cell is Dictionary:return false
		if not cell.has("finite") or not cell.has("missing") or int(cell.get("bin",-1)) < 0 or int(cell.bin) >= int(value.bin_count):return false
		for key in ["first","last","min","max"]:
			if not cell.has(key):continue
			var point = cell[key]
			if not point is Array or point.size() != 5:return false
			if not is_finite(float(point[3])) or not is_finite(float(point[4])) or float(point[3]) < 0 or float(point[3]) > 1 or float(point[4]) < 0 or float(point[4]) > 1:return false
	data = value;queue_redraw();return true

func clear() -> void:
	data = {};queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.04,0.065))
	var bounds := Rect2(Vector2(12,30),Vector2(maxf(1,size.x-24),maxf(1,size.y-52)))
	draw_rect(bounds,Color(0.3,0.36,0.44),false)
	if data.is_empty():return
	for cell in data.bins:
		if int(cell.missing) > 0:
			var x := bounds.position.x+(float(cell.bin)+.5)/float(data.bin_count)*bounds.size.x
			draw_line(Vector2(x,bounds.end.y-5),Vector2(x,bounds.end.y),Color(1,.6,.2),2)
		if cell.has("min") and cell.has("max"):
			var a := _point(cell.min,bounds);var b := _point(cell.max,bounds)
			# An envelope stroke is vertical: it never invents temporal continuity.
			draw_line(Vector2((a.x+b.x)/2,a.y),Vector2((a.x+b.x)/2,b.y),Color(.2,.8,1,.55),1)
		for key in ["first","last","min","max"]:
			if cell.has(key):draw_circle(_point(cell[key],bounds),2.5,Color(.3,.85,1))
	if is_finite(cursor) and data.axis == "native_time":
		var low := float(data.x_range[0]);var high := float(data.x_range[1])
		if high > low and cursor >= low and cursor <= high:
			var x := bounds.position.x+(cursor-low)/(high-low)*bounds.size.x
			draw_line(Vector2(x,bounds.position.y),Vector2(x,bounds.end.y),Color(1,.75,.2),1)
	var font := ThemeDB.fallback_font
	var y_label := "No finite observations"
	if data.y_range is Array:y_label = "%s → %s [%s]" % [data.y_range[0],data.y_range[1],data.units]
	draw_string(font,Vector2(12,18),y_label,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12,Color(.8,.85,.9))
	draw_string(font,Vector2(12,size.y-7),str(data.x_range[0])+" → "+str(data.x_range[1])+" • "+preload("res://analysis/ui_controls.gd").axis_name(data.axis)+" ["+str(data.time_units)+"]",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12,Color(.8,.85,.9))

func _point(point: Array,bounds: Rect2) -> Vector2:
	return bounds.position+Vector2(float(point[3])*bounds.size.x,(1.0-float(point[4]))*bounds.size.y)

func _get_tooltip(at_position: Vector2) -> String:
	if data.is_empty():return ""
	var bounds := Rect2(Vector2(12,30),Vector2(maxf(1,size.x-24),maxf(1,size.y-52)))
	var closest := 144.0;var label := "Native observations and extrema; orange marks indicate missing support."
	for cell in data.bins:
		for key in ["first","last","min","max"]:
			if not cell.has(key):continue
			var distance := at_position.distance_squared_to(_point(cell[key],bounds))
			if distance < closest:
				closest = distance;label = "Time/index: %s\nValue: %s %s\nFull-result row: %s\nBin: %d finite, %d missing" % [cell[key][0],cell[key][1],data.units,cell[key][2],int(cell.finite),int(cell.missing)]
	return label
