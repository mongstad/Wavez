"""Reproduce the preserved drift experiment in a background Blender process.

Open wavez_emblem.contained-luminous.review.blend first. This preserves that
checkpoint and writes a separate source with a reusable 12-second drift.
The #162 application integration was not accepted; this is design-only work.
"""
import math
from pathlib import Path

import bpy

source = Path(bpy.data.filepath)
assert source.name == "wavez_emblem.contained-luminous.review.blend"
destination = source.with_name("wavez_emblem.drift-experiment.blend")
if destination.exists():
    raise RuntimeError("Refusing to overwrite the preserved experiment source")
scene = bpy.context.scene
assert scene.name == "Wavez Emblem - Contained Luminous Orb"
root = next(obj for obj in scene.objects if obj.type == "EMPTY")
scene.render.fps = 24
scene.frame_start, scene.frame_end = 1, 289
root.rotation_mode = "XYZ"
for frame in range(1, 290):
    phase = 2 * math.pi * (frame - 1) / 288
    root.rotation_euler = (math.radians(2) * math.sin(2 * phase),
                           0, math.radians(12) * math.sin(phase))
    root.keyframe_insert(data_path="rotation_euler", frame=frame)
root.animation_data.action.name = "Wavez_Drift"
scene.frame_set(1)
scene["review_state"] = "Standalone branding experiment; #162 application integration not accepted, 2026-10-01"
scene["animation_description"] = "12s contained drift: +/-12deg yaw and +/-2deg pitch; fixed brightness; returns to front"
scene["source_checkpoint"] = source.name
bpy.ops.wm.save_as_mainfile(filepath=str(destination), check_existing=False, compress=True)
summary = {"source": str(destination), "frames": [1, 289], "fps": 24,
           "duration_seconds": 12, "animation": root.animation_data.action.name,
           "meshes": sum(obj.type == "MESH" for obj in scene.objects)}
