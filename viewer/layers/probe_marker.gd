extends Node3D
# World-anchored annotation drawn after 3D post-processing, below application UI.
const CORE := Color("ef8fff")
const OUTLINE := Color("182033")
class Ink:
	extends Node2D
	var points := PackedVector2Array()
	var color := CORE:
		set(value): color = value;rebuild()
	func _draw() -> void: rebuild()
	func rebuild() -> void:
		var item := get_canvas_item();RenderingServer.canvas_item_clear(item)
		for i in range(0,points.size(),2): RenderingServer.canvas_item_add_line(item,points[i],points[i+1],OUTLINE,7.,true)
		for i in range(0,points.size(),2): RenderingServer.canvas_item_add_line(item,points[i],points[i+1],color,3.,true)
var camera: Camera3D
var vertices := PackedVector3Array()
var canvas := CanvasLayer.new()
var ink := Ink.new()
var projection_key: Array = []
func setup(source_camera: Camera3D) -> void:
	camera = source_camera
	canvas.layer = -1;add_child(canvas);canvas.add_child(ink)
	visibility_changed.connect(update_projection)
	RenderingServer.frame_pre_draw.connect(update_projection)
func set_point(point: Vector3) -> void:
	position = point;vertices.clear()
	for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]: vertices.append_array([point-axis*.35,point+axis*.35])
	projection_key.clear();update_projection()
func update_projection() -> void:
	canvas.visible = is_visible_in_tree()
	if not canvas.visible or not is_instance_valid(camera): return
	var key: Array = [camera.get_camera_transform(),camera.get_camera_projection(),get_viewport().get_visible_rect(),global_transform]
	if key == projection_key: return
	projection_key = key
	var next := PackedVector2Array()
	if not camera.is_position_behind(global_position):
		var inverse := camera.get_camera_transform().affine_inverse()
		var owner_layer := get_parent() as Node3D
		for i in range(0,vertices.size(),2):
			var a: Vector3 = owner_layer.to_global(vertices[i]);var b: Vector3 = owner_layer.to_global(vertices[i+1])
			var az: float = (inverse*a).z;var bz: float = (inverse*b).z
			if az >= -camera.near and bz >= -camera.near: continue
			# Clip a crossing arm before projecting, avoiding points behind the near plane.
			if az > -camera.near: a = a.lerp(b,(-camera.near-az)/(bz-az))
			elif bz > -camera.near: b = b.lerp(a,(-camera.near-bz)/(az-bz))
			next.append_array([camera.unproject_position(a),camera.unproject_position(b)])
	# Update commands before this render, without queueing an extra frame/redraw.
	if next != ink.points: ink.points = next;ink.rebuild()
func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(update_projection): RenderingServer.frame_pre_draw.disconnect(update_projection)
