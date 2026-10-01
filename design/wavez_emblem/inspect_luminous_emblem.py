"""Read-only inspection of the contained luminous #162 review scene.

Run with this scene active in Blender. No transforms, files or meshes are edited.
``result`` contains JSON-compatible measurements of the evaluated geometry.
"""

import math

import bpy
from mathutils import Vector


SCENE_NAME = "Wavez Emblem - Contained Luminous Orb"
scene = bpy.data.scenes[SCENE_NAME]
if bpy.context.scene != scene:
    raise RuntimeError("Select the contained luminous orb scene before inspection")
depsgraph = bpy.context.evaluated_depsgraph_get()
meshes, points = [], []
materials = {}
for obj in scene.objects:
    if obj.type != "MESH":
        continue
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        mesh.calc_loop_triangles()
        world_points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        points.extend(world_points)
        areas = []
        for triangle in mesh.loop_triangles:
            a, b, c = [world_points[i] for i in triangle.vertices]
            areas.append((b - a).cross(c - a).length * 0.5)
        attr = mesh.color_attributes.get("Color")
        meshes.append({
            "name": obj.name,
            "vertices": len(mesh.vertices),
            "triangles": len(mesh.loop_triangles),
            "dimensions": [round(v, 6) for v in evaluated.dimensions],
            "finite_vertices": all(math.isfinite(c) for p in world_points for c in p),
            "degenerate_triangles": sum(a < 1e-14 for a in areas),
            "maximum_radius": round(max(p.length for p in world_points), 6),
            "color_attribute": bool(attr),
            "finite_colors": all(math.isfinite(c) for d in attr.data for c in d.color) if attr else None,
            "materials": [slot.material.name for slot in obj.material_slots if slot.material],
        })
    finally:
        evaluated.to_mesh_clear()
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None:
            continue
        shader = mat.node_tree.nodes.get("Principled BSDF")
        materials[mat.name] = {
            "emission_strength": shader.inputs["Emission Strength"].default_value,
            "roughness": shader.inputs["Roughness"].default_value,
            "surface_render_method": mat.surface_render_method,
        }

# The first 225 four-vertex rings of the energy band are the actual hero tube.
# Compare their measured centerline with the 14 independent reference landmarks.
hero = next(o for o in scene.objects if o.name.startswith("Wavez_Luminous_Energy_Band")).data
line = []
for i in range(225):
    point = sum((hero.vertices[i * 4 + j].co for j in range(4)), Vector()) / 4
    line.append(Vector((point.x, point.z)))
pixels = [(256,595),(300,592),(360,640),(420,693),(460,699),
          (520,670),(580,603),(640,525),(700,471),(760,458),
          (820,495),(880,576),(940,635),(985,634)]
errors = []
for x, y in pixels:
    point = Vector(((x - 626) / 375, (576 - y) / 375))
    distances = []
    for a, b in zip(line, line[1:]):
        ab = b - a
        fraction = max(0.0, min(1.0, (point - a).dot(ab) / ab.length_squared))
        distances.append((point - (a + fraction * ab)).length * 375)
    errors.append(min(distances))

root = next(o for o in scene.objects if o.type == "EMPTY")
maximum_radius = max(p.length for p in points)
result = {
    "blender_version": bpy.app.version_string,
    "scene": scene.name,
    "review_state": scene["review_state"],
    "reference_sha256": scene["reference_sha256"],
    "meshes": meshes,
    "materials": materials,
    "total_vertices": sum(m["vertices"] for m in meshes),
    "total_triangles": sum(m["triangles"] for m in meshes),
    "bounds": {
        "min": [round(min(p[i] for p in points), 6) for i in range(3)],
        "max": [round(max(p[i] for p in points), 6) for i in range(3)],
    },
    "unit_orb_maximum_geometry_radius": round(maximum_radius, 6),
    "all_geometry_within_1_015_radius": maximum_radius <= 1.015,
    "root_rotation_radians": list(root.rotation_euler),
    "particle_systems": sum(len(o.particle_systems) for o in scene.objects),
    "modifiers": sum(len(o.modifiers) for o in scene.objects),
    "reference_landmark_count": len(pixels),
    "reference_wave_error_pixels": {
        "maximum": round(max(errors), 4),
        "mean": round(sum(errors) / len(errors), 4),
        "each": [round(e, 4) for e in errors],
        "meaning": "2D tube-centerline distance at the original 1254px image scale; not full-image similarity or owner acceptance",
    },
    "preview_bloom": "Blender compositor, two Fog Glow scales; not a runtime export feature",
    "runtime_exported": False,
    "godot_integration_validated": False,
}
