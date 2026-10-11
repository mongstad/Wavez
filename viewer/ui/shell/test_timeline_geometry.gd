extends SceneTree
const Timeline = preload("res://ui/shell/prepared_timeline.gd")
const ThemeSource = preload("res://ui/theme/wavez_theme.gd")
var checks := 0
var failures := []
var rows := []
var out := ""
func _initialize():run.call_deferred()
func check(ok: bool, label: String):
	checks += 1
	if not ok:failures.append(label);push_error(label)
func settle():
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
func run():
	out = OS.get_cmdline_user_args()[0]
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	var host := Control.new();host.theme = ThemeSource.new();root.add_child(host)
	var slider := Timeline.new();host.add_child(slider)
	slider.position = Vector2(32,40);slider.min_value = 0;slider.max_value = 10;slider.step = 1
	slider.frames = [{"time":0.0},{"time":1.0},{"time":100.0}]
	slider.coverage = {"fields":[],"scene":[[0.,100.]]}
	for factor in [1.0,1.25,1.5,2.0]:
		host.scale = Vector2.ONE*factor
		for width in [200.,600.]:
			slider.size = Vector2(width,16)
			for ratio in [0.,.5,1.]:
				slider.set_value_no_signal(ratio*10);slider.release_focus();slider.overlay.queue_redraw();await settle()
				var image := root.get_texture().get_image()
				var origin := slider.get_global_transform_with_canvas()*Vector2.ZERO
				var color: Color = host.theme.c(&"accent.primary")
				var y := roundi(origin.y+(slider.size.y*.5-4)*factor)
				var pixels := []
				for x in range(floori(origin.x-10*factor),ceili(origin.x+(width+10)*factor)):
					var p := image.get_pixel(x,y)
					if Vector3(p.r,p.g,p.b).distance_to(Vector3(color.r,color.g,color.b)) < .12:pixels.append(x)
				check(not pixels.is_empty(),"Rendered thumb visible")
				var center: float = (float(pixels[0])+pixels[-1]+1)*.5 if not pixels.is_empty() else -999.
				var expected: float = origin.x+width*ratio*factor
				rows.append({"scale":factor,"width":width,"ratio":ratio,"center":center,"expected":expected,"error":center-expected})
				if not baseline:check(absf(center-expected)<=1.,"Rendered thumb center aligns: "+str(rows[-1]))
				# Full coverage must remain visible just inside both native track edges.
				for edge in [origin.x+3*factor,origin.x+(width-3)*factor]:
					var pixel := image.get_pixel(roundi(edge),roundi(origin.y+slider.size.y*.5*factor))
					var expected_color: Color = color if absf(edge-expected) < 5*factor else slider.scene_color
					check(Vector3(pixel.r,pixel.g,pixel.b).distance_to(Vector3(expected_color.r,expected_color.g,expected_color.b)) < .15,"Coverage reaches track edge beneath dominant thumb")
				if factor == 1.0 and width == 600.:image.get_region(Rect2i(16,24,640,48)).save_png(out.path_join("timeline-"+str(ratio)+".png"))
	# Native pointer/keyboard handling uses the same full-width axis.
	host.scale = Vector2.ONE;slider.size = Vector2(600,16);await settle()
	for ratio in [0.,.5,1.]:
		var point := slider.global_position+Vector2(slider.size.x*ratio,slider.size.y*.5)
		# Border hit testing is half-open; dragging beyond it must still reach max.
		var press := InputEventMouseButton.new();press.position = slider.global_position+Vector2(1,8);press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press)
		var move := InputEventMouseMotion.new();move.position=point;move.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(move)
		var release := press.duplicate();release.pressed=false;release.position=point;root.push_input(release)
		check(is_equal_approx(slider.value,ratio*10),"Native dragging maps start/mid/end")
	slider.grab_focus()
	for pair in [[KEY_HOME,0],[KEY_RIGHT,1],[KEY_END,10],[KEY_LEFT,9]]:
		var key := InputEventKey.new();key.keycode=pair[0];key.pressed=true;root.push_input(key)
		check(slider.value == pair[1],"Native keyboard mapping "+str(pair))
	check(Timeline.axis_position(1,slider.frames)==.5,"Unequal timestamps retain sample-index midpoint")
	FileAccess.open(out.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"baseline":baseline},"  "))
	print("GEOMETRY: ",checks," checks, ",failures.size()," failures");host.free();quit(0 if failures.is_empty() else 1)
