extends MeshInstance3D
const Prepare = preload("res://layers/mesh_prepare.gd")
const Sampling = preload("res://scene/source_sampling.gd")
var gpu_bytes := 0
var key := ""
var error := ""
var data := {}
var display_alpha := 0.0
var positions_alpha := -1.0
var normals_alpha := -1.0
var source_positions := PackedVector3Array():
	get:
		if data.has("next_positions") and positions_alpha != display_alpha:
			source_positions = data.source_positions.duplicate()
			for i in range(source_positions.size()):source_positions[i] = source_positions[i].lerp(data.next_positions[i],display_alpha)
			positions_alpha = display_alpha
		return source_positions
var normal_values := PackedVector3Array():
	get:
		if data.has("next_positions") and normals_alpha != display_alpha:
			if display_alpha == 0:normal_values = data.normal_values
			else:
				var p := source_positions;var indices: PackedInt32Array = data.a.channels.triangles
				normal_values = PackedVector3Array();normal_values.resize(p.size())
				for i in range(0,indices.size(),3):
					var normal := (p[indices[i+1]]-p[indices[i]]).cross(p[indices[i+2]]-p[indices[i]])
					for j in range(3):normal_values[indices[i+j]] += normal
				for i in range(normal_values.size()):normal_values[i] = normal_values[i].normalized()
			normals_alpha = display_alpha
		return normal_values
func load_samples(obj: Dictionary, a: Dictionary, b: Dictionary, alpha: float, state: Dictionary, budget: int, colors: Array) -> String:
	error = ""
	var interpolate: bool = Sampling.mesh_compatible(obj,a,b) and a.sequence != b.sequence
	var status := "interpolated" if interpolate and alpha > 0 else "held"
	var target := "%s/%s/%.8f/%s" % [a.sequence,b.sequence,alpha if interpolate else 0,JSON.stringify(state)]
	visible = state.visible
	if target == key and gpu_bytes <= budget:return status
	clear()
	var prepared := Prepare.prepare(obj,a,b,alpha,state,budget,colors)
	if prepared.has("error"):error = prepared.error;return "unavailable"
	var uploaded := upload(prepared)
	apply_prepared(uploaded,target,0.0,state.visible)
	return status
static func upload(prepared: Dictionary) -> Dictionary:
	var result := prepared.duplicate() # Arrays and immutable source samples stay shared.
	if prepared.get("empty",false):return result
	var surface := ArrayMesh.new()
	var blends: Array[Array] = []
	if prepared.has("blend"):
		surface.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
		surface.add_blend_shape("source_pair");blends.append(prepared.blend)
		surface.custom_aabb = prepared.bounds
	surface.add_surface_from_arrays(prepared.primitive,prepared.arrays,blends)
	result.mesh = surface
	return result
func apply_prepared(prepared: Dictionary, target: String, alpha: float, show_mesh: bool) -> String:
	error = ""
	if key != target or data.get("token") != prepared.get("token"):
		clear();data = prepared;key = target;gpu_bytes = prepared.gpu_bytes
		if not prepared.get("empty",false):
			mesh = prepared.mesh;transform = prepared.transform
			var mat := StandardMaterial3D.new();mat.vertex_color_use_as_albedo = true;mat.vertex_color_is_srgb = true;mat.roughness = .8
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode = BaseMaterial3D.CULL_BACK;material_override = mat
			source_positions = prepared.source_positions;normal_values = prepared.normal_values
	visible = show_mesh and not prepared.get("empty",false)
	display_alpha = alpha if prepared.get("interpolate",false) else 0.0
	if mesh != null and data.has("blend"):set_blend_shape_value(0,display_alpha)
	if prepared.has("preview_error"):error = prepared.preview_error;return "unavailable"
	return "interpolated" if display_alpha > 0 else "held"
static func scalar_color(value: float, state: Dictionary, colors: Array) -> Color:return Prepare.scalar_color(value,state,colors)
func clear() -> void:
	mesh = null;gpu_bytes = 0;key = "";data = {};display_alpha = 0.0;positions_alpha = -1.0;normals_alpha = -1.0
	source_positions = PackedVector3Array();normal_values = PackedVector3Array()
