extends Control
## A projected world-space gizmo, outside scientific geometry and saved camera state.
const COLORS := [Color("ff9494"),Color("90dfad"),Color("99baff")]
const SHADOW := Color(0.02,0.015,0.05,0.95)
var editor
var annotation: SubViewport
var annotation_camera: Camera3D
var sphere: MeshInstance3D
var surface: TextureRect
var render_state: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	annotation = SubViewport.new(); annotation.own_world_3d = true
	annotation.transparent_bg = true; annotation.handle_input_locally = false
	annotation.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(annotation)
	annotation_camera = Camera3D.new(); annotation.add_child(annotation_camera)
	sphere = MeshInstance3D.new(); annotation.add_child(sphere)
	var mesh := SphereMesh.new(); mesh.radius = 1.0; mesh.height = 2.0
	mesh.radial_segments = 64; mesh.rings = 32; sphere.mesh = mesh
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
 float light = 0.3 + 0.7 * max(dot(normalize(NORMAL), normalize(vec3(-0.4,0.6,1.0))),0.0);
 ALBEDO = vec3(0.57,0.43,0.92) * light;
}
"""
	var material := ShaderMaterial.new(); material.shader = shader; sphere.material_override = material
	surface = TextureRect.new(); surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.texture = annotation.get_texture(); add_child(surface); move_child(surface,0)
	# Draw 2D axes above the sphere; this Control's own draw precedes children.
	surface.show_behind_parent = true
	visibility_changed.connect(sync_geometry)
	RenderingServer.frame_pre_draw.connect(sync_geometry)

func sync_geometry() -> void:
	if annotation == null: return
	if not is_visible_in_tree():
		annotation.render_target_update_mode = SubViewport.UPDATE_DISABLED; render_state.clear(); return
	var camera: Camera3D = editor.viewer.camera
	var state := [camera.global_transform,camera.get_camera_projection(),camera.get_viewport().get_visible_rect(),editor.center,editor.radius]
	if state == render_state: return
	render_state = state
	annotation.size = Vector2i(camera.get_viewport().get_visible_rect().size)
	annotation_camera.transform = camera.global_transform
	annotation_camera.projection = camera.projection
	annotation_camera.keep_aspect = camera.keep_aspect
	annotation_camera.fov = camera.fov; annotation_camera.size = camera.size
	annotation_camera.frustum_offset = camera.frustum_offset
	annotation_camera.h_offset = camera.h_offset; annotation_camera.v_offset = camera.v_offset
	annotation_camera.near = camera.near; annotation_camera.far = camera.far
	sphere.visible = camera.global_position.distance_to(editor.center) > editor.radius
	sphere.position = editor.center
	sphere.scale = Vector3.ONE * editor.radius
	annotation.render_target_update_mode = SubViewport.UPDATE_ONCE


func handle(axis: int) -> Dictionary:
	var camera: Camera3D = editor.viewer.camera
	if camera.is_position_behind(editor.center): return {}
	var origin := camera.unproject_position(editor.center)
	var length: float = editor.radius * 1.4
	var direction: Vector3 = editor.handle_basis[axis]
	var end_world: Vector3 = editor.center+direction*length
	if camera.is_position_behind(end_world): return {}
	var endpoint := camera.unproject_position(end_world)
	var screen_length := origin.distance_to(endpoint)
	if screen_length < 8: return {}
	return {"start":origin,"end":endpoint,"direction":(endpoint-origin)/screen_length,"units":length/screen_length}

func line(a: Vector2, b: Vector2, color: Color, width := 1.5) -> void:
	draw_line(a,b,SHADOW,width+2,true); draw_line(a,b,color,width,true)

func _draw() -> void:
	var camera: Camera3D = editor.viewer.camera
	for axes in [[Vector3.RIGHT,Vector3.UP],[Vector3.RIGHT,Vector3.BACK],[Vector3.UP,Vector3.BACK]]:
		for i in 96:
			var a := TAU*i/96.0; var b := TAU*(i+1)/96.0
			var p: Vector3 = editor.center+editor.radius*(axes[0]*cos(a)+axes[1]*sin(a))
			var q: Vector3 = editor.center+editor.radius*(axes[0]*cos(b)+axes[1]*sin(b))
			if camera.is_position_behind(p) or camera.is_position_behind(q): continue
			var first := camera.unproject_position(p); var second := camera.unproject_position(q)
			if first.is_finite() and second.is_finite(): line(first,second,Color(0.68,0.62,0.93,0.5),1.0)
	if camera.is_position_behind(editor.center): return
	var center := camera.unproject_position(editor.center)
	# World XYZ references share the same radius scale as the physical sphere.
	for axis in 3:
		var direction := Vector3.ZERO; direction[axis] = 1.0
		var p: Vector3 = editor.center - direction*editor.radius
		var q: Vector3 = editor.center + direction*editor.radius
		if not camera.is_position_behind(p) and not camera.is_position_behind(q):
			line(camera.unproject_position(p),camera.unproject_position(q),Color(COLORS[axis],0.6),1.0)
	draw_circle(center,7,SHADOW); draw_circle(center,4,Color("ddd4ff"))
	for axis in 3:
		var points := handle(axis)
		if points.is_empty(): continue
		line(points.start,points.end,COLORS[axis],2.5)
		draw_circle(points.end,8,SHADOW); draw_circle(points.end,5,COLORS[axis])
		draw_string_outline(ThemeDB.fallback_font,points.end+Vector2(10,5),["Right","Up","Toward"][axis],HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,SHADOW)
		draw_string(ThemeDB.fallback_font,points.end+Vector2(10,5),["Right","Up","Toward"][axis],HORIZONTAL_ALIGNMENT_LEFT,-1,16,COLORS[axis])
