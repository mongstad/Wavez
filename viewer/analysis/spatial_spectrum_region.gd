extends Control
## A projected UI wire, separate from scene materials and export rendering.
const EDGES := [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]]
var viewer
var corners := PackedVector3Array()
var caption := ""
var verified := false
var last_view := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func clear() -> void:
	corners.clear(); caption = ""; last_view = ""; queue_redraw()

func publish(low: Vector3, high: Vector3, label: String, is_verified: bool) -> void:
	corners.clear()
	for z in [low.z,high.z]:
		for y in [low.y,high.y]:
			for x in [low.x,high.x]: corners.append(Vector3(x,y,z))
	caption = label; verified = is_verified; last_view = ""; queue_redraw()

func _process(_delta: float) -> void:
	if not visible or corners.is_empty() or not is_instance_valid(viewer) or not is_instance_valid(viewer.camera): return
	var key := str([viewer.camera.global_transform,viewer.camera.get_camera_projection(),size,viewer.inspection_busy,viewer.offline_instance,visible])
	if key != last_view:
		last_view = key; queue_redraw()

func _draw() -> void:
	if not is_instance_valid(viewer) or not is_instance_valid(viewer.camera) or viewer.offline_instance or viewer.inspection_busy or corners.size() != 8: return
	var color := Color(.32,.8,1,.85) if verified else Color(.95,.68,.3,.85)
	var first := Vector2(INF,INF)
	for edge in EDGES:
		var a: Vector3 = corners[edge[0]]
		var b: Vector3 = corners[edge[1]]
		# Do not project points behind the camera into a misleading screen wire.
		if viewer.camera.is_position_behind(a) or viewer.camera.is_position_behind(b): continue
		var pa: Vector2 = viewer.camera.unproject_position(a)
		var pb: Vector2 = viewer.camera.unproject_position(b)
		draw_line(pa,pb,color,1.5,true)
		if pa.y < first.y: first = pa
	if is_finite(first.x):
		first.x = clampf(first.x,12,maxf(12,size.x-280)); first.y = clampf(first.y-8,24,maxf(24,size.y-12))
		draw_string(ThemeDB.fallback_font,first,caption,HORIZONTAL_ALIGNMENT_LEFT,280,12,color)
