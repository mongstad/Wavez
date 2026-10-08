extends Control
## View-relative placement axes for a world-space center, outside scientific geometry.
const COLORS := [Color("ff9494"),Color("90dfad"),Color("99baff")]
const LABELS := ["Right", "Up", "Toward"]
const END_ON_DIRECTIONS := [Vector2.RIGHT, Vector2.UP, Vector2(0.70710678, 0.70710678)]
const SHADOW := Color(0.02,0.015,0.05,0.95)
var editor
var surface: SubViewport
var surface_camera: Camera3D
var sphere: MeshInstance3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# An isolated annotation world renders above even opaque volume fields.
	# It never enters the scientific world, its depth buffer, or output state.
	surface = SubViewport.new(); surface.own_world_3d = true; surface.transparent_bg = true
	surface.render_target_update_mode = SubViewport.UPDATE_DISABLED; add_child(surface)
	surface_camera = Camera3D.new(); surface.add_child(surface_camera); surface_camera.current = true
	sphere = MeshInstance3D.new(); surface.add_child(sphere)
	var mesh := SphereMesh.new(); mesh.radius = 1.0; mesh.height = 2.0; mesh.radial_segments = 64; mesh.rings = 32; sphere.mesh = mesh
	var material := ShaderMaterial.new(); material.shader = preload("res://ui/shell/orbit_radius.gdshader"); sphere.material_override = material
	visibility_changed.connect(func():
		if not visible: surface.render_target_update_mode = SubViewport.UPDATE_DISABLED)

func update_surface() -> void:
	if not visible or surface == null: return
	var camera: Camera3D = editor.viewer.camera
	surface.size = Vector2i(get_viewport_rect().size)
	surface_camera.transform = camera.global_transform
	surface_camera.projection = camera.projection; surface_camera.keep_aspect = camera.keep_aspect
	surface_camera.fov = camera.fov; surface_camera.size = camera.size
	surface_camera.near = camera.near; surface_camera.far = camera.far
	surface_camera.h_offset = camera.h_offset; surface_camera.v_offset = camera.v_offset; surface_camera.frustum_offset = camera.frustum_offset
	sphere.position = editor.center; sphere.scale = Vector3.ONE*editor.radius
	surface.render_target_update_mode = SubViewport.UPDATE_ONCE

func handle(axis: int) -> Dictionary:
	var result := projected_handle(axis)
	if result.is_empty(): return result
	# A captured axis can become foreshortened or overlap another after moving
	# around the lock. Keep distinct screen endpoints without changing its world
	# direction or world-units-per-pixel mapping.
	for previous in axis:
		var other := handle(previous)
		if result.end.distance_to(other.end) < 30:
			for step in 8:
				var direction: Vector2 = END_ON_DIRECTIONS[axis].rotated(step*PI/4)
				var endpoint: Vector2 = result.start+direction*72
				var clear := true
				for prior in axis:
					if endpoint.distance_to(handle(prior).end) < 30: clear = false
				if clear:
					result.end = endpoint; result.direction = direction; break
	return result

func projected_handle(axis: int) -> Dictionary:
	var camera: Camera3D = editor.viewer.camera
	if (camera.global_transform.affine_inverse()*editor.center).z >= -camera.near: return {}
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
	var screen_direction := (endpoint-origin)/screen_length
	return {"start":origin,"end":origin+screen_direction*72,"direction":screen_direction,"units":length/screen_length}

func line(a: Vector2, b: Vector2, color: Color, width := 1.5) -> void:
	draw_line(a,b,SHADOW,width+2,true); draw_line(a,b,color,width,true)

func world_line(a: Vector3, b: Vector3, color: Color, width := 1.5) -> void:
	var camera: Camera3D = editor.viewer.camera
	var inverse := camera.global_transform.affine_inverse()
	var az: float = (inverse*a).z; var bz: float = (inverse*b).z
	if az >= -camera.near and bz >= -camera.near: return
	if az > -camera.near: a = a.lerp(b,(-camera.near-az)/(bz-az))
	elif bz > -camera.near: b = b.lerp(a,(-camera.near-bz)/(az-bz))
	var first := camera.unproject_position(a); var second := camera.unproject_position(b)
	if first.is_finite() and second.is_finite(): line(first,second,color,width)

func _draw() -> void:
	var camera: Camera3D = editor.viewer.camera
	if surface != null:
		draw_texture_rect(surface.get_texture(),Rect2(Vector2.ZERO,get_viewport_rect().size),false,Color(1,1,1,.84))
	# The rings/diameters are scientific world references; the short, named
	# placement handles below still use the view captured when editing began.
	var basis := Basis.IDENTITY
	for axes in [[basis.x,basis.y],[basis.x,basis.z],[basis.y,basis.z]]:
		for i in 96:
			var a := TAU*i/96.0; var b := TAU*(i+1)/96.0
			var p: Vector3 = editor.center+editor.radius*(axes[0]*cos(a)+axes[1]*sin(a))
			var q: Vector3 = editor.center+editor.radius*(axes[0]*cos(b)+axes[1]*sin(b))
			world_line(p,q,Color("c8b8ff"),1.5)
	for axis in 3:
		var direction: Vector3 = basis[axis]*editor.radius
		world_line(editor.center-direction,editor.center+direction,COLORS[axis],1.0)
		var tip: Vector3 = editor.center+direction
		if (camera.global_transform.affine_inverse()*tip).z < -camera.near:
			var point := camera.unproject_position(tip)+Vector2(8,-8)
			draw_string_outline(ThemeDB.fallback_font,point,"World "+["X","Y","Z"][axis],HORIZONTAL_ALIGNMENT_LEFT,-1,14,4,SHADOW)
			draw_string(ThemeDB.fallback_font,point,"World "+["X","Y","Z"][axis],HORIZONTAL_ALIGNMENT_LEFT,-1,14,COLORS[axis])
	if (camera.global_transform.affine_inverse()*editor.center).z >= -camera.near: return
	var center := camera.unproject_position(editor.center)
	draw_circle(center,7,SHADOW); draw_circle(center,4,Color("ddd4ff"))
	for axis in 3:
		var points := handle(axis)
		if points.is_empty(): continue
		line(points.start,points.end,COLORS[axis],2.5)
		draw_circle(points.end,8,SHADOW); draw_circle(points.end,5,COLORS[axis])
		draw_string_outline(ThemeDB.fallback_font,points.end+Vector2(10,5),LABELS[axis],HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,SHADOW)
		draw_string(ThemeDB.fallback_font,points.end+Vector2(10,5),LABELS[axis],HORIZONTAL_ALIGNMENT_LEFT,-1,16,COLORS[axis])
