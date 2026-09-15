extends RefCounted
# All geometry is already in exported viewer-world coordinates. No axis swap.
static func vector_ok(value) -> bool:
	if not value is Array or value.size() != 3: return false
	for n in value:
		if not (n is float or n is int) or not is_finite(n) or absf(n) > 1e12: return false
	return true

static func box_ok(value) -> bool:
	if not value is Dictionary or not vector_ok(value.get("min")) or not vector_ok(value.get("max")): return false
	for i in range(3):
		if value.min[i] >= value.max[i]: return false
	return true

static func validate(g) -> String:
	if not g is Dictionary: return "Geometry must be an object."
	if g.is_empty(): return ""
	if g.get("version") != 1 or g.get("coordinate_space") != "viewer_world": return "Geometry requires version 1 and coordinate_space viewer_world."
	if not g.get("units", "") is String: return "Geometry units must be text."
	if g.has("domain") and not box_ok(g.domain): return "Domain requires ordered finite min/max vectors."
	if g.has("grid"):
		var grid = g.grid
		if not grid is Dictionary or not vector_ok(grid.get("origin")) or not vector_ok(grid.get("spacing")) or not vector_ok(grid.get("dimensions")): return "Grid requires origin, spacing and dimensions in x,y,z order."
		if grid.get("sampling") not in ["cell", "node"]: return "Grid sampling must be cell or node."
		for i in range(3):
			if grid.dimensions[i] < 1 or grid.dimensions[i] > 1000000 or int(grid.dimensions[i]) != grid.dimensions[i] or grid.spacing[i] <= 0: return "Invalid grid spacing or dimensions."
	if g.has("absorber"):
		var a = g.absorber
		if not a is Dictionary or not vector_ok(a.get("center")): return "Absorber requires a finite center."
		for key in ["start", "width"]:
			if not (a.get(key) is float or a.get(key) is int) or not is_finite(a[key]) or a[key] < 0 or a[key] > 1e12: return "Invalid absorber " + key
		if not a.get("profile", "unspecified") is String: return "Absorber profile must be text."
	if g.has("imposed_regions"):
		if not g.imposed_regions is Array or g.imposed_regions.size() > 64: return "At most 64 imposed box regions are supported."
		for region in g.imposed_regions:
			if not box_ok(region) or not region.get("name") is String: return "Imposed regions require a name and min/max box."
	return ""

static func v(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
static func a(p: Vector3) -> Array: return [p.x,p.y,p.z]

static func describe(g: Dictionary, overridden: bool) -> String:
	var result := "Geometry • user override\n" if overridden else "Geometry • capture metadata\n"
	if g.is_empty(): return "Simulation domain: unknown\nAbsorber: unknown\nReference axes are display guides."
	result += "Units: %s\n" % g.get("units", "unspecified")
	result += "Domain faces: %s → %s\n" % [g.domain.min,g.domain.max] if g.has("domain") else "Simulation domain: unknown\n"
	if g.has("grid"):
		var grid: Dictionary = g.grid
		var last := v(grid.origin) + (v(grid.dimensions)-Vector3.ONE)*v(grid.spacing)
		result += "%s samples: %s → %s\nSpacing: %s; dimensions: %s\n" % [grid.sampling,grid.origin,a(last),grid.spacing,grid.dimensions]
	if g.has("absorber"):
		result += "Absorber: center %s; r≥%.5f; width %.5f\nProfile: %s\n" % [g.absorber.center,g.absorber.start,g.absorber.width,g.absorber.get("profile","unspecified")]
	else: result += "Absorber: unknown\n"
	for r in g.get("imposed_regions", []): result += "Imposed: %s %s → %s\n" % [r.name,r.min,r.max]
	return result.strip_edges()

static func lines(vertices: PackedVector3Array, color: Color) -> Mesh:
	if vertices.is_empty(): return null
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for p in vertices: mesh.surface_add_vertex(p)
	mesh.surface_end()
	return mesh

static func box(low: Vector3, high: Vector3) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for axis in range(3):
		for j in range(2):
			for k in range(2):
				var p := low
				p[(axis+1)%3] = high[(axis+1)%3] if j else low[(axis+1)%3]
				p[(axis+2)%3] = high[(axis+2)%3] if k else low[(axis+2)%3]
				var q := p; q[axis] = high[axis]
				vertices.append_array([p,q])
	return vertices

static func sphere(center: Vector3, radius: float, dashed := false) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for axis in range(3):
		for i in range(128):
			if dashed and i % 2: continue
			for angle in [TAU*i/128,TAU*(i+1)/128]:
				var p := center
				p[(axis+1)%3] += radius*cos(angle)
				p[(axis+2)%3] += radius*sin(angle)
				vertices.append(p)
	return vertices
