extends Control
## Temporary, source-independent geometric camera proposal. Never an export layer.
const MIN_RADIUS := 0.0001
const MAX_RADIUS := 1e12
const INK := Color("c4baff")
const OUTLINE := Color("10101d")
var viewer
var active := false
var radius := 1.0
var pivot := Vector3.ZERO
var panel: PanelContainer
var slider: HSlider
var radius_label: Label
var pivot_label: Label
var original_transform := Transform3D.IDENTITY
var original_yaw := 0.0
var original_pitch := 0.0
var capture_depth := 0
var draw_area := Rect2()

func setup(owner_viewer) -> void:
	viewer = owner_viewer
	name = "TemporaryOrbitSetup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://ui/theme/violet_slice_theme.gd").new()
	panel = PanelContainer.new(); add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("182234")
	style.set_content_margin_all(12); style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new(); panel.add_child(rows)
	var title := Label.new(); title.text = "Orbit setup · release RMB to commit"; rows.add_child(title)
	radius_label = Label.new(); rows.add_child(radius_label)
	pivot_label = Label.new(); pivot_label.clip_text = true
	pivot_label.add_theme_font_size_override("font_size",12); rows.add_child(pivot_label)
	slider = HSlider.new(); slider.min_value = log(MIN_RADIUS); slider.max_value = log(MAX_RADIUS)
	slider.step = 0.0; slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(300,24); rows.add_child(slider)
	slider.value_changed.connect(func(value: float): set_radius(exp(value)))
	var help := Label.new(); help.text = "Wheel: radius · Shift: fine\nWASD/QE: fly · mouse: look · R: reset"; rows.add_child(help)
	get_viewport().size_changed.connect(layout)
	viewer.get_window().focus_exited.connect(cancel)
	set_process(false); hide()

func layout() -> void:
	var previous_area := draw_area
	var area := get_viewport().get_visible_rect().size
	var left := 16.0
	var right := area.x - 16.0
	var bottom := area.y - 24.0
	var top := 16.0
	if viewer.shell != null:
		if viewer.shell.bar.is_visible_in_tree(): top = viewer.shell.bar.get_global_rect().end.y + 8.0
		if viewer.shell.dock.is_visible_in_tree(): right = minf(right, viewer.shell.dock.get_global_rect().position.x - 16.0)
		if viewer.shell.transport.is_visible_in_tree(): bottom = minf(bottom, viewer.shell.transport.get_global_rect().position.y - 16.0)
	var width := minf(360.0, maxf(280.0, right-left))
	panel.size = Vector2(width, panel.get_combined_minimum_size().y)
	panel.position = Vector2(maxf(left, (left+right-width)*.5), maxf(48.0, bottom-panel.size.y))
	draw_area = Rect2(Vector2(left,top),Vector2(maxf(0,right-left),maxf(0,bottom-top)))
	if draw_area != previous_area: queue_redraw()

func begin() -> void:
	if active or viewer.offline_instance or not viewer.free_camera or viewer.inspection_busy: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	original_transform = viewer.camera.transform
	original_yaw = viewer.yaw; original_pitch = viewer.pitch
	radius = clampf(viewer.camera_distance, MIN_RADIUS, MAX_RADIUS)
	viewer.dragging = false
	active = true; set_process(true)
	refresh(); layout()

func set_radius(value: float) -> void:
	if not active or not is_finite(value): return
	radius = clampf(value, MIN_RADIUS, MAX_RADIUS)
	refresh()

func refresh() -> void:
	if not active: return
	pivot = viewer.camera.position - viewer.camera.basis.z * radius
	slider.set_value_no_signal(log(radius))
	var numeric := String.num(radius, 6)
	if radius >= 1e6 or radius < .001:
		var exponent := int(floor(log(radius)/log(10.0)))
		numeric = "%.4f × 10^%d" % [radius/pow(10,exponent),exponent]
	radius_label.text = "Radius: %s simulation units" % numeric
	pivot_label.text = "Pivot: (%s, %s, %s)" % [String.num(pivot.x,4),String.num(pivot.y,4),String.num(pivot.z,4)]
	visible = capture_depth == 0 and not viewer.inspection_busy
	queue_redraw()

func _process(_delta: float) -> void:
	# Durable inspection capture may bypass the ordinary PNG action. Its busy
	# lock is established before the draw, so the same exclusion covers it.
	visible = active and capture_depth == 0 and not viewer.inspection_busy
	if active: layout()
	if active and not viewer.free_camera: cancel()

func handle_input(event: InputEvent) -> bool:
	if viewer.inspection_busy: return false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and (panel.get_global_rect().has_point(event.position) or viewer.shell.edge_reveal.is_viewport_point(event.position)):
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			set_radius(radius * exp(direction * (.01 if event.shift_pressed else .12)))
			return true
		if event.button_index == MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position): return true
	if event is InputEventMouseMotion and not panel.get_global_rect().has_point(event.position) and viewer.shell.edge_reveal.is_viewport_point(event.position):
		viewer.yaw -= event.relative.x * .006
		viewer.pitch -= event.relative.y * .006
		viewer._update_camera()
		return true
	return false

func commit() -> void:
	if not active: return
	refresh()
	viewer.camera_target = pivot
	viewer.camera_distance = radius
	viewer.custom_orbit = true
	active = false; hide(); set_process(false)
	viewer._custom_camera_clip()
	# The live free-camera transform already faces the proposal. Keep it exactly
	# on release; reconstructing large opposing vectors can lose its origin.

func cancel() -> void:
	if not active: return
	active = false; hide(); set_process(false)
	viewer.camera.transform = original_transform
	viewer.yaw = original_yaw; viewer.pitch = original_pitch
	viewer.dragging = false

func suppress_capture(suppress: bool) -> void:
	capture_depth = maxi(0, capture_depth + (1 if suppress else -1))
	if active: refresh()

func segment(a: Vector3, b: Vector3, color: Color) -> void:
	var camera: Camera3D = viewer.camera
	# Clip the rings near the observer; never project a point behind the camera.
	var inverse := camera.global_transform.affine_inverse()
	var depth_a := -(inverse*a).z; var depth_b := -(inverse*b).z
	var near := maxf(radius * .001, .000001)
	if depth_a <= near and depth_b <= near: return
	if depth_a <= near: a = a.lerp(b, (near-depth_a)/(depth_b-depth_a))
	elif depth_b <= near: b = b.lerp(a, (near-depth_b)/(depth_a-depth_b))
	var p := camera.unproject_position(a); var q := camera.unproject_position(b)
	if not p.is_finite() or not q.is_finite(): return
	# Clip projected guides to the simulation area, including edge/fullscreen
	# chrome. This does not change the accepted camera projection/framing.
	var direction := q-p
	var low := 0.0; var high := 1.0
	for axis in 2:
		if absf(direction[axis]) < .00001:
			if p[axis] < draw_area.position[axis] or p[axis] > draw_area.end[axis]: return
		else:
			var first: float = (draw_area.position[axis]-p[axis])/direction[axis]
			var last: float = (draw_area.end[axis]-p[axis])/direction[axis]
			low = maxf(low,minf(first,last)); high = minf(high,maxf(first,last))
			if low > high: return
	q = p + direction*high; p += direction*low
	draw_line(p,q,OUTLINE,4.0,true); draw_line(p,q,color,1.5,true)

func _draw() -> void:
	if not active or capture_depth > 0 or viewer.inspection_busy: return
	# Equator and meridian of the proposed radius sphere. A ring through the
	# observer would sit on the horizon and vanish at many normal view angles.
	var meridian: Vector3 = viewer.camera.basis.x
	for n in 96:
		var a := TAU*n/96.0; var b := TAU*(n+1)/96.0
		segment(pivot+Vector3(cos(a),0,sin(a))*radius, pivot+Vector3(cos(b),0,sin(b))*radius, INK)
		# Dashed meridian shows the full radius without an opaque surface.
		if n%2 == 0:
			segment(pivot+(meridian*cos(a)+Vector3.UP*sin(a))*radius, pivot+(meridian*cos(b)+Vector3.UP*sin(b))*radius, Color(INK,.6))
	var point: Vector2 = viewer.camera.unproject_position(pivot)
	for axis in [Vector2.RIGHT,Vector2.DOWN]:
		draw_line(point-axis*9,point+axis*9,OUTLINE,5,true)
		draw_line(point-axis*9,point+axis*9,INK,2,true)
	draw_circle(point,3,OUTLINE); draw_circle(point,1.5,INK)
