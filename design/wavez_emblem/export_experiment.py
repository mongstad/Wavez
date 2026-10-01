"""Export the standalone model/animation into the design archive, never Godot."""
from pathlib import Path

import bpy

source = Path(bpy.data.filepath)
assert source.name == "wavez_emblem.drift-experiment.blend"
scene = bpy.context.scene
assert scene.name == "Wavez Emblem - Contained Luminous Orb"
destination = source.parent / "exports/wavez_emblem.drift-experiment.glb"
if destination.exists():
    raise RuntimeError("Refusing to overwrite the preserved experiment export")
asset_objects = [obj for obj in scene.objects if obj.type in {"MESH", "EMPTY"}]
bpy.ops.object.select_all(action="DESELECT")
for obj in asset_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = next(obj for obj in asset_objects if obj.type == "EMPTY")
scene.frame_set(1)
destination.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(destination), export_format="GLB", use_selection=True,
    use_active_scene=True, export_apply=True, export_yup=True,
    export_cameras=False, export_lights=False, export_animations=True,
    export_frame_range=True, export_force_sampling=True,
    export_animation_mode="ACTIONS", export_vertex_color="ACTIVE",
    export_all_vertex_colors=False, export_extras=False,
    export_anim_slide_to_zero=True,
)
summary = {"design_export": str(destination), "bytes": destination.stat().st_size,
           "selected_objects": [obj.name for obj in asset_objects],
           "source": str(source), "duration_seconds": 12}
