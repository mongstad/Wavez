extends Control
## Bounded presentation of verified numerical bins. No source sampling or FFT.
signal selection_changed(index: int)
const MAX_BINS := 512
var data := {}
var selected_index := -1

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	gui_input.connect(_input_plot)

func publish(value: Dictionary) -> bool:
	if JSON.stringify(value).to_utf8_buffer().size() > 1048576: return false
	var radial = value.get("radial")
	if not radial is Dictionary or not radial.get("frequency") is Array or not radial.get("power") is Array: return false
	if radial.frequency.is_empty() or radial.frequency.size() > MAX_BINS or radial.frequency.size() != radial.power.size(): return false
	if not value.get("units") is Dictionary or not value.units.get("frequency") is String or not value.units.get("power") is String: return false
	var previous := -1.0
	for i in radial.frequency.size():
		var f = radial.frequency[i]
		var p = radial.power[i]
		if not (f is float or f is int) or not (p is float or p is int): return false
		if not is_finite(f) or not is_finite(p) or f < 0 or p < 0 or f <= previous: return false
		previous = f
	data = {"radial":radial.duplicate(true),"units":value.units.duplicate(true)}
	selected_index = 0
	queue_redraw()
	selection_changed.emit(selected_index)
	return true

func clear() -> void:
	data.clear(); selected_index = -1; queue_redraw()

func bounds() -> Rect2:
	return Rect2(Vector2(64,24),Vector2(maxf(1,size.x-80),maxf(1,size.y-70)))

func scales() -> Dictionary:
	if data.is_empty(): return {"x":1.,"y":1.}
	# Positive source values can be arbitrarily small; only all-zero power
	# needs a fallback. A magnitude floor would hide valid weak signals.
	var xmax := float(data.radial.frequency[-1])
	var ymax := float(data.radial.power.max())
	return {"x":xmax if xmax > 0. else 1.,"y":ymax if ymax > 0. else 1.}

func _draw() -> void:
	var ink := get_theme_color("font_color","Label")
	var muted := Color(ink,0.6)
	var box := bounds()
	draw_rect(box,Color(ink,0.07))
	draw_rect(box,muted,false)
	if data.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(70,48),"Compute a verified regional spectrum.",HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-86),12,ink)
		return
	var frequencies: Array = data.radial.frequency
	var power: Array = data.radial.power
	var scale := scales()
	var xmax: float = scale.x
	var ymax: float = scale.y
	var points := PackedVector2Array()
	for i in frequencies.size():
		points.append(Vector2(box.position.x+float(frequencies[i])/xmax*box.size.x,box.end.y-float(power[i])/ymax*box.size.y))
	if points.size() > 1: draw_polyline(points,Color(.40,.64,1.0),1.5,true)
	for i in range(5):
		var fraction := float(i)/4.
		var x := box.position.x+fraction*box.size.x
		draw_line(Vector2(x,box.end.y),Vector2(x,box.end.y+4),muted)
		draw_string(ThemeDB.fallback_font,Vector2(x-22,box.end.y+19),_tick(fraction*xmax),HORIZONTAL_ALIGNMENT_CENTER,48,11,ink)
		draw_string(ThemeDB.fallback_font,Vector2(2,box.end.y-fraction*box.size.y+4),_tick(fraction*ymax),HORIZONTAL_ALIGNMENT_RIGHT,56,11,ink)
	draw_string(ThemeDB.fallback_font,Vector2(64,15),"Radial bin power ["+str(data.units.power)+"]",HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-80),11,ink)
	draw_string(ThemeDB.fallback_font,Vector2(64,size.y-5),"Spatial frequency ["+str(data.units.frequency)+"]",HORIZONTAL_ALIGNMENT_LEFT,maxf(1,size.x-80),11,ink)
	if selected_index >= 0 and selected_index < points.size():
		var p: Vector2 = points[selected_index]
		draw_line(Vector2(p.x,box.position.y),Vector2(p.x,box.end.y),Color(.9,.65,.25,.6))
		draw_circle(p,3.5,Color(.95,.7,.3))
	if has_focus(): draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color(.6,.5,1),false,2)

func _tick(value: float) -> String:
	if value == 0: return "0"
	var exponent := int(floor(log(absf(value))/log(10.)))
	if exponent < -3 or exponent > 3: return "%.1f" % (value/pow(10.,exponent))+"e"+str(exponent)
	return String.num(value,maxi(0,3-exponent))

func _input_plot(event: InputEvent) -> void:
	if data.is_empty(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		var box := bounds()
		var fraction := clampf((event.position.x-box.position.x)/box.size.x,0,1)
		var desired := fraction*float(data.radial.frequency[-1])
		var nearest := 0
		for i in data.radial.frequency.size():
			if absf(float(data.radial.frequency[i])-desired) < absf(float(data.radial.frequency[nearest])-desired): nearest = i
		selected_index = nearest; queue_redraw(); selection_changed.emit(nearest); accept_event()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_HOME,KEY_END]:
		var step := -1 if event.keycode == KEY_LEFT else 1
		selected_index = clampi(selected_index+step,0,data.radial.frequency.size()-1)
		if event.keycode == KEY_HOME: selected_index = 0
		if event.keycode == KEY_END: selected_index = data.radial.frequency.size()-1
		queue_redraw(); selection_changed.emit(selected_index); accept_event()
