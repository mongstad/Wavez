# Auto Orbit around the scene target (#234)

Auto Orbit moves the camera around the accepted world-space `camera_target`.
The camera orientation and `camera_distance` set its orbit pose. The scene root,
scientific coordinates and capture data do not receive an orbit transform.
Left-button tumble and right-button view-relative orbit keep their existing
gestures; either drag suspends automatic motion until release.

While Auto Orbit is on, Free Camera W/S changes the camera-to-target radius
without moving `camera_target`. Near the target, inward movement stops before
crossing it; a smaller radius deliberately set through Edit Orbit Center is
retained without an outward snap. Free Camera A/D and Q/E retain their accepted
side/up translation, which pans the orbit target with the camera. With Auto
Orbit off, all Free Camera axes retain their prior translation behavior.
Wheel zoom uses the same radius. Edit Orbit Center changes the accepted target
and radius; Frame Scene and Reset Camera recalculate them from the current scene.
Disabling or re-enabling Auto Orbit leaves the camera at its current pose.

## Source trace

`scene_layers.tick()` advances automatic yaw, then `_update_camera()` assigns
`camera.transform` from the current orientation, `camera_target` and
`camera_distance`. The pivot is already in world space; Auto Orbit does not
write to a scene or layer transform. Before this correction,
`_move_free_camera()` translated `camera_target` by the full camera-local
movement vector, including W/S. Because `_update_camera()` then placed the
camera at the same radius from the newly translated target, forward/back
movement carried the pivot with the camera. Manual right-button orbit already
uses the authoritative target and radius. This correction changes only the
W/S path while Auto Orbit is enabled.

## Focused validation

The `tools/validate_camera_tumble.py --suite auto-orbit` regression uses tiny
particle, volume, mesh and mixed WVZ1 fixtures. For each, it checks LMB →
Auto Orbit → off, RMB → Auto Orbit → RMB, wheel zoom, W/S while orbiting, an
edited target, Reset/Frame → Auto Orbit, and repeated off/on transitions.
It checks camera travel and aim against the world-space target, stable world
roots and particle transforms, unchanged committed sample and byte-identical
fixture captures. The connected camera tumble suite exercises the existing
drag, zoom, free movement, reset, recipe and video-camera paths.

Final candidate results: 161 checks passed headless and 161 in native Forward+
with the small real cavity-collapse mesh capture; 156 checks passed in native
Compatibility. The connected camera tumble suite passed 13,798 headless checks
and 13,814 Compatibility checks. Two application-version tests, the version
CLI and `git diff --check` passed. Fixture and real-capture hashes were unchanged.
The reported large particle/field capture was not available for this run; the
owner's visual check below remains important for subjective orbit feel.

## Owner verification

1. Open the reported large particle/field scene, choose **Frame Scene**, turn
   on Auto Orbit and hold W, then S. The camera should approach and retreat
   while continuing around the same scene center. The dataset must not swing
   around a moving viewport pivot.
2. Turn Auto Orbit off and on repeatedly. Check that the resulting camera pose
   never snaps. Tumble with LMB, orbit with RMB, and zoom before and after the
   toggles. A held drag should pause automatic motion.
3. Use **Edit Orbit Center** to choose an obviously off-center world coordinate.
   Orbit and move W/S again. Then use **Frame Scene** and **Reset Camera** and
   confirm both restore their established framing/orientation behavior.
4. Repeat with particle-only, field-only, mesh-only and mixed scenes. Confirm
   scientific object coordinates and playback samples remain unchanged by
   camera navigation. Check native Forward+ and Compatibility presentation.
