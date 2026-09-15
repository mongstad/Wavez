extends Control
var data := {}
var pixels := PackedByteArray()
var texture: ImageTexture
var cursor := NAN

func publish(value: Dictionary) -> bool:
	if not value.get("width") is float and not value.get("width") is int:return false
	var width := int(value.width);var height := int(value.get("height",0))
	if width < 1 or width > 1024 or height < 1 or height > 512 or width*height > 16384:return false
	if not value.get("pixels") is String or value.pixels.length() != width*height*32 or not value.get("native_rows") is Array or value.native_rows.size() > height:return false
	if not value.get("time_range") is Array or value.time_range.size() != 2 or value.get("axis") not in ["native_time","record_index"]:return false
	if value.get("value_range") != null and (not value.value_range is Array or value.value_range.size() != 2):return false
	if JSON.stringify(value).to_utf8_buffer().size()*8 > 8*1048576:return false
	var bytes: PackedByteArray = value.pixels.hex_decode()
	if bytes.size() != width*height*16:return false
	var rgba := PackedByteArray();rgba.resize(width*height*4)
	for i in range(width*height):
		var low := bytes.decode_float(i*16);var high := bytes.decode_float(i*16+4)
		var finite := bytes.decode_u32(i*16+8);var missing := bytes.decode_u32(i*16+12)
		if not is_finite(low) or not is_finite(high) or low < 0 or low > 1 or high < 0 or high > 1:return false
		var color := Color(0,0,0,0)
		# A min/max color envelope is display-only; no numerical value is read
		# back from this texture. Orange identifies missing support.
		if finite > 0 and missing > 0:color = Color(1,.25,.65)
		elif finite > 0:color = Color.from_hsv(.66*(1-high),.85,.35+.65*high)
		elif missing > 0:color = Color(1,.45,.15)
		rgba.encode_u32(i*4,color.to_abgr32())
	for row in value.native_rows:
		if not row is Dictionary or int(row.get("row",-1)) < 0 or int(row.row) >= height:return false
		if not is_finite(float(row.get("normalized_first",NAN))) or not is_finite(float(row.get("normalized_last",NAN))):return false
		if float(row.normalized_first) < 0 or float(row.normalized_last) > 1 or float(row.normalized_first) > float(row.normalized_last):return false
	data = value;pixels = bytes
	texture = ImageTexture.create_from_image(Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,rgba))
	queue_redraw();return true

func clear() -> void:
	data = {};pixels.clear();texture = null;queue_redraw()

func bounds() -> Rect2:return Rect2(Vector2(42,76),Vector2(maxf(1,size.x-54),maxf(1,size.y-111)))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.025,.04,.065))
	if data.is_empty() or texture == null:return
	var box := bounds();var font := ThemeDB.fallback_font
	draw_rect(box,Color(.3,.36,.44),false)
	for row in data.native_rows:
		var low := box.position.y+float(row.normalized_first)*box.size.y
		var high := box.position.y+float(row.normalized_last)*box.size.y
		var extent := maxf(2,high-low)
		draw_texture_rect_region(texture,Rect2(Vector2(box.position.x,clampf((low+high-extent)/2,box.position.y,box.end.y-extent)),Vector2(box.size.x,extent)),Rect2(Vector2(0,int(row.row)),Vector2(int(data.width),1)))
	if is_finite(cursor) and data.axis == "native_time":
		var first := float(data.time_range[0]);var last := float(data.time_range[1])
		if last > first and cursor >= first and cursor <= last:
			var y := box.position.y+(cursor-first)/(last-first)*box.size.y
			draw_line(Vector2(box.position.x,y),Vector2(box.end.x,y),Color.WHITE,1)
	draw_string(font,Vector2(12,17),str(data.value_origin),HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12)
	draw_string(font,Vector2(12,34),"%s [%s] • %d full bin values" % [str(data.value_range),data.units,int(data.full_bin_values)],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12)
	draw_string(font,Vector2(12,51),"Maxima • orange: missing; pink: mixed support",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12)
	draw_string(font,Vector2(2,box.position.y+12),str(data.time_range[0]),HORIZONTAL_ALIGNMENT_LEFT,39,11)
	draw_string(font,Vector2(2,box.end.y),str(data.time_range[1]),HORIZONTAL_ALIGNMENT_LEFT,39,11)
	draw_string(font,Vector2(12,size.y-19),"Distance 0 → %s [%s]" % [data.spatial.bin_edges.length.text,data.spatial.units],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,12)
	draw_string(font,Vector2(12,size.y-4),"Time axis: %s [%s]" % [preload("res://analysis/ui_controls.gd").axis_name(data.axis),data.time_units],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,11)

func _get_tooltip(position: Vector2) -> String:
	if data.is_empty():return ""
	var box := bounds()
	if not box.has_point(position):return data.policy
	var column := mini(int(data.width)-1,int((position.x-box.position.x)/box.size.x*int(data.width)))
	var y := mini(int(data.height)-1,int((position.y-box.position.y)/box.size.y*int(data.height)))
	var at := (y*int(data.width)+column)*16
	return "%s\n%d finite / %d missing full bin values in this preview cell\nUse the full-result table/export for scientific numbers.\nNo temporal interpolation or held extension." % [data.value_origin,pixels.decode_u32(at+8),pixels.decode_u32(at+12)]
