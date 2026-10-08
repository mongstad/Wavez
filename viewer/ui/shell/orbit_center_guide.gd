extends Control
## View-relative placement axes for a world-space center, outside scientific geometry.
const COLORS := [Color("ff9494"),Color("90dfad"),Color("99baff")]
const LABELS := ["Right", "Up", "Toward"]
const END_ON_DIRECTIONS := [Vector2.RIGHT, Vector2.UP, Vector2(0.70710678, 0.70710678)]
const SHADOW := Color(0.02,0.015,0.05,0.95)
var editor

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func handle(axis: int) -> Dictionary:
	var camera: Camera3D = editor.viewer.camera
	if camera.is_position_behind(editor.center): return {}
	var origin := camera.unproject_position(editor.center)
	var depth: float = -(camera.global_transform.affine_inverse()*editor.center).z
	var length := camera.project_position(origin+Vector2(72,0),depth).distance_to(editor.center)
	var direction: Vector3 = editor.edit_basis[axis]
	var end_world: Vector3 = editor.center+direction*length
	var endpoint := origin if camera.is_position_behind(end_world) else camera.unproject_position(end_world)
	var screen_length := origin.distance_to(endpoint)
	# Depth points end-on at entry. Give it an explicit screen drag handle while
	# retaining its captured world direction, so all three axes remain usable.
	if screen_length < 8:
		endpoint = origin + END_ON_DIRECTIONS[axis]*72.0
		screen_length = 72.0
	return {"start":origin,"end":endpoint,"direction":(endpoint-origin)/screen_length,"units":length/screen_length}

func line(a: Vector2, b: Vector2, color: Color, width := 1.5) -> void:
	draw_line(a,b,SHADOW,width+2,true); draw_line(a,b,color,width,true)

func _draw() -> void:
	var camera: Camera3D = editor.viewer.camera
	var basis: Basis = editor.edit_basis
	for axes in [[basis.x,basis.y],[basis.x,basis.z],[basis.y,basis.z]]:
		for i in 96:
			var a := TAU*i/96.0; var b := TAU*(i+1)/96.0
			var p: Vector3 = editor.center+editor.radius*(axes[0]*cos(a)+axes[1]*sin(a))
			var q: Vector3 = editor.center+editor.radius*(axes[0]*cos(b)+axes[1]*sin(b))
			if camera.is_position_behind(p) or camera.is_position_behind(q): continue
			var first := camera.unproject_position(p); var second := camera.unproject_position(q)
			if first.is_finite() and second.is_finite(): line(first,second,Color(0.68,0.62,0.93,0.5),1.0)
	if camera.is_position_behind(editor.center): return
	var center := camera.unproject_position(editor.center)
	draw_circle(center,7,SHADOW); draw_circle(center,4,Color("ddd4ff"))
	for axis in 3:
		var points := handle(axis)
		if points.is_empty(): continue
		line(points.start,points.end,COLORS[axis],2.5)
		draw_circle(points.end,8,SHADOW); draw_circle(points.end,5,COLORS[axis])
		draw_string_outline(ThemeDB.fallback_font,points.end+Vector2(10,5),LABELS[axis],HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,SHADOW)
		draw_string(ThemeDB.fallback_font,points.end+Vector2(10,5),LABELS[axis],HORIZONTAL_ALIGNMENT_LEFT,-1,16,COLORS[axis])
