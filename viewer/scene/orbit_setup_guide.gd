extends Control
## Projected world-space guides, deliberately outside scientific scene geometry.
var setup
const INK := Color("c4b5fd")
const SHADOW := Color(0.025,0.02,0.06,0.95)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func line(a: Vector2, b: Vector2, color: Color = INK) -> void:
	draw_line(a,b,SHADOW,4.0,true)
	draw_line(a,b,color,1.5,true)

func ring(axis_a: Vector3, axis_b: Vector3) -> void:
	var camera: Camera3D = setup.viewer.camera
	for i in 96:
		var a := TAU * i / 96.0; var b := TAU * (i+1) / 96.0
		var p: Vector3 = setup.pivot + setup.radius * (axis_a*cos(a)+axis_b*sin(a))
		var q: Vector3 = setup.pivot + setup.radius * (axis_a*cos(b)+axis_b*sin(b))
		# Segments behind the camera never produce mirrored/offscreen spikes.
		if camera.is_position_behind(p) or camera.is_position_behind(q): continue
		var screen_p := camera.unproject_position(p); var screen_q := camera.unproject_position(q)
		if not screen_p.is_finite() or not screen_q.is_finite(): continue
		line(screen_p,screen_q,Color(0.65,0.57,0.95,0.65))

func _draw() -> void:
	if not setup.active: return
	var camera: Camera3D = setup.viewer.camera
	ring(Vector3.RIGHT,Vector3.BACK)
	ring(camera.basis.x,(camera.basis.y+camera.basis.z).normalized())
	var center := camera.unproject_position(setup.pivot)
	line(center-Vector2(11,0),center+Vector2(11,0))
	line(center-Vector2(0,11),center+Vector2(0,11))
	draw_arc(center,18,0,TAU,48,SHADOW,4,true)
	draw_arc(center,18,0,TAU,48,INK,1.5,true)
	var box := panel_rect()
	var width := box.size.x
	draw_style_box(panel(),box)
	var font := ThemeDB.fallback_font
	var exponent := int(floor(log(setup.radius)/log(10.0)))
	var value := String.num(setup.radius,maxi(0,5-exponent)) if exponent in range(-3,6) else "%.4f × 10^%d" % [setup.radius/pow(10,exponent),exponent]
	draw_string(font,box.position+Vector2(14,23),"ORBIT SETUP   ·   Radius %s" % value,HORIZONTAL_ALIGNMENT_LEFT,width-28,16,INK)
	draw_string(font,box.position+Vector2(14,47),"Wheel: radius · Shift: fine · Mouse: look",HORIZONTAL_ALIGNMENT_LEFT,width-28,14,Color.WHITE)
	draw_string(font,box.position+Vector2(14,69),"WASD / Q E: fly · Release RMB: set · R: reset",HORIZONTAL_ALIGNMENT_LEFT,width-28,14,Color.WHITE)

func panel_rect() -> Rect2:
	var extent := get_viewport_rect().size
	var right := extent.x; var bottom := extent.y
	var shell = setup.viewer.shell
	if shell.dock.is_visible_in_tree(): right = minf(right,shell.dock.get_global_rect().position.x)
	if shell.transport.is_visible_in_tree(): bottom = minf(bottom,shell.transport.get_global_rect().position.y)
	var width := minf(440,right-32)
	return Rect2(Vector2((right-width)*0.5,minf(extent.y*0.72,bottom-98)),Vector2(width,86))

func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.03,0.065,0.94)
	style.set_corner_radius_all(8)
	return style
