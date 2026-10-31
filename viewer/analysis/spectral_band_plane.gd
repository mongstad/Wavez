extends Node3D
## Optional derived presentation; never a source field or playback-cache entry.
const SHADER = preload("res://analysis/spectral_band_plane.gdshader")
var mesh_instance: MeshInstance3D
var material: ShaderMaterial
var texture: ImageTexture
var data_image: Image
var gpu_breakdown := {}
var grid_columns := 0
var error := ""
var gpu_bytes := 0 # Payload estimate only; excludes driver/renderer allocations.
var centers_world: Array = []
var measured_centers_world: Array = []
var range_min := 0.0
var range_max := 0.0
var opacity := 0.8
var palette := 0
var source_corners: Array = []

func _ready() -> void:
	mesh_instance = MeshInstance3D.new(); mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mesh_instance)
	material = ShaderMaterial.new(); material.shader = SHADER; material.render_priority = 20
	mesh_instance.material_override = material
	hide()

func clear() -> void:
	hide(); texture = null; data_image = null; gpu_bytes = 0; gpu_breakdown.clear(); grid_columns = 0; centers_world.clear(); measured_centers_world.clear(); source_corners.clear()
	if mesh_instance != null: mesh_instance.mesh = null
	if material != null: material.set_shader_parameter("display_values",null)

func publish(data: Dictionary) -> bool:
	error = ""
	var grid: Dictionary = data.grid
	var rows := int(grid.count[0]); var columns := int(grid.count[1])
	if rows < 1 or columns < 1 or rows*columns > 64 or data.measurements.size() != rows*columns: return false
	clear()
	var values: Array = []
	for item in data.measurements:
		if item.status == "measured": values.append(float(item.power))
	range_min = float(values.min()) if not values.is_empty() else 0.
	range_max = float(values.max()) if not values.is_empty() else 0.
	var bytes := PackedByteArray(); bytes.resize(rows*columns*4)
	for i in data.measurements.size():
		var item: Dictionary = data.measurements[i]
		centers_world.append(item.center_world_xyz.duplicate())
		var value := -1.0
		if item.status == "measured":
			# Scaling in float64 first preserves even powers below float32 range.
			value = (float(item.power)-range_min)/(range_max-range_min) if range_max > range_min else 0.5
			measured_centers_world.append(item.center_world_xyz.duplicate())
		bytes.encode_float(i*4,value)
	data_image = Image.create_from_data(columns,rows,false,Image.FORMAT_RF,bytes)
	texture = ImageTexture.create_from_image(data_image); grid_columns = columns
	var normal_axis := "xyz".find(str(grid.plane_axis))
	var row_axis := "xyz".find(str(grid.row_axis)); var column_axis := "xyz".find(str(grid.column_axis))
	var shape: Array = data.geometry.shape; var spacing: Array = data.geometry.spacing; var origin: Array = data.geometry.origin
	var transform_data: Array = data.geometry.data_to_world
	for position in measured_centers_world:
		if not _gpu_coordinate_safe(position,spacing):
			error = "Source coordinates exceed supported float32 viewport precision (quarter source spacing). Numerical data remain source-based; no distorted plane was published."
			clear(); return false
	var fixed_center := float(grid.fixed_start)+(float(data.support.shape[2-normal_axis])-1.)/2.
	var vertices := PackedVector3Array(); var uvs := PackedVector2Array()
	for uv in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
		var index: Array = [0.,0.,0.]
		index[normal_axis] = fixed_center
		index[column_axis] = uv.x*(float(shape[2-column_axis])-1.)
		index[row_axis] = uv.y*(float(shape[2-row_axis])-1.)
		var world: Array = [0.,0.,0.]
		for axis in range(3): world[axis] = float(origin[axis])+index[axis]*float(spacing[axis])+float(transform_data[[3,7,11][axis]])
		if not _gpu_coordinate_safe(world,spacing):
			error = "Source coordinates exceed supported float32 viewport precision (quarter source spacing). No distorted plane was published."
			clear(); return false
		vertices.append(Vector3(world[0],world[1],world[2])); uvs.append(uv)
	source_corners = [vertices[0],vertices[1],vertices[2],vertices[5]]
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); mesh_instance.mesh = mesh
	material.set_shader_parameter("display_values",texture)
	material.set_shader_parameter("source_extent",Vector2(float(shape[2-column_axis])-1.,float(shape[2-row_axis])-1.))
	material.set_shader_parameter("first_center",Vector2(float(grid.start[1])+(float(data.support.shape[2-column_axis])-1.)/2.,float(grid.start[0])+(float(data.support.shape[2-row_axis])-1.)/2.))
	material.set_shader_parameter("center_hop",Vector2(float(grid.hop[1]),float(grid.hop[0])))
	material.set_shader_parameter("center_count",Vector2(columns,rows))
	gpu_bytes = bytes.size()+vertices.size()*12+uvs.size()*8
	gpu_breakdown = {"normalized_texture_and_embedded_mask":bytes.size(),"mesh_positions":vertices.size()*12,"mesh_uv":uvs.size()*8,"palette":"analytic shader; no palette texture","excludes":"driver overhead and separate UI legend"}
	apply_presentation(opacity,palette)
	return true

func _gpu_coordinate_safe(coordinates: Array, spacing: Array) -> bool:
	var bytes := PackedByteArray(); bytes.resize(4)
	for axis in range(3):
		var value := float(coordinates[axis]); bytes.encode_float(0,value)
		var rounded := bytes.decode_float(0)
		if not is_finite(rounded) or absf(rounded-value) > 0.25*float(spacing[axis]): return false
	return true

func center_world(row: int, column: int) -> Array:
	var index := row*grid_columns+column
	return centers_world[index].duplicate() if index >= 0 and index < centers_world.size() and column >= 0 and column < grid_columns else []

func apply_presentation(alpha: float, palette_index: int) -> void:
	opacity = alpha; palette = palette_index
	if material == null: return
	material.set_shader_parameter("opacity",opacity); material.set_shader_parameter("palette",palette)
