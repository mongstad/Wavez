"""Read-only Blender inspection for the #162 proposed asset.

Execute inside Blender; returns JSON-compatible measurements in ``result``.
No scene state, files, transforms, or meshes are modified.
"""

import math

import bpy
from mathutils import Vector


scene = bpy.data.scenes["Wavez Emblem - Approval Candidate"]
dg = bpy.context.evaluated_depsgraph_get()
meshes, all_points = [], []
for obj in scene.objects:
    if obj.type != "MESH":
        continue
    evaluated = obj.evaluated_get(dg)
    mesh = evaluated.to_mesh()
    try:
        mesh.calc_loop_triangles()
        pts = [obj.matrix_world @ v.co for v in mesh.vertices]
        all_points.extend(pts)
        areas = []
        for triangle in mesh.loop_triangles:
            a,b,c = [mesh.vertices[i].co for i in triangle.vertices]
            areas.append((b-a).cross(c-a).length * 0.5)
        meshes.append({
            "name": obj.name,
            "vertices": len(mesh.vertices),
            "triangles": len(mesh.loop_triangles),
            "materials": [s.material.name for s in obj.material_slots if s.material],
            "dimensions": [round(v,6) for v in obj.dimensions],
            "finite_vertices": all(math.isfinite(c) for p in pts for c in p),
            "degenerate_triangles": sum(a < 1e-14 for a in areas),
            "color_attribute": bool(mesh.color_attributes.get("Color")),
        })
    finally:
        evaluated.to_mesh_clear()

# Compare the actual authored hero-tube centerline with independent reference
# landmarks, in the original 1254px image's coordinate scale (375px radius).
pixels = [(256,595),(300,592),(360,640),(420,693),(460,699),
          (520,670),(580,603),(640,525),(700,471),(760,458),
          (820,495),(880,576),(940,635),(985,634)]
hero = scene.objects["Wavez_Hero_Wave_And_Rim"].data
start = 2 * 113 * 3  # The central tube follows the two negative-phase tubes.
line = []
for i in range(113):
    point = sum((hero.vertices[start+i*3+j].co for j in range(3)), Vector())/3
    line.append(Vector((point.x,point.z)))
errors = []
for x,y in pixels:
    point = Vector(((x-626)/375,(576-y)/375))
    distances = []
    for a,b in zip(line,line[1:]):
        ab = b-a
        fraction = max(0.0,min(1.0,(point-a).dot(ab)/ab.length_squared))
        distances.append((point-(a+fraction*ab)).length * 375)
    errors.append(min(distances))

result = {
    "blender_version": bpy.app.version_string,
    "scene": scene.name,
    "review_state": scene["review_state"],
    "reference_sha256": scene["reference_sha256"],
    "meshes": meshes,
    "total_vertices": sum(m["vertices"] for m in meshes),
    "total_triangles": sum(m["triangles"] for m in meshes),
    "bounds": {
        "min": [round(min(p[i] for p in all_points),6) for i in range(3)],
        "max": [round(max(p[i] for p in all_points),6) for i in range(3)],
    },
    "reference_landmark_count": len(pixels),
    "reference_wave_error_pixels": {
        "maximum": round(max(errors),4),
        "mean": round(sum(errors)/len(errors),4),
        "each": [round(e,4) for e in errors],
        "meaning": "2D centerline distance in the 1254px reference; not full-image similarity or owner acceptance",
    },
    "runtime_exported": False,
    "godot_integration_validated": False,
}
