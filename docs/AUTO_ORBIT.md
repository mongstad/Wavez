# Auto Orbit and Free Camera (#234)

Free Camera movement is active on a clean launch. W/S moves along the camera's
forward axis, A/D along its lateral axis, and Q/E along its vertical axis. These
keys translate the camera view without applying a transform to scene roots,
scientific coordinates, or capture data.

Auto Orbit moves the camera around the current world-space `camera_target`. It
keeps the existing orientation, target, and positive `camera_distance` camera
representation. While Auto Orbit is on, free-camera translation is suspended.
Pressing any W/A/S/D/Q/E key turns Auto Orbit off and applies that key's normal
free-camera movement on the **same** process tick. Turning Auto Orbit back on
starts from the current camera pose without a snap. Auto Orbit's rotation stops
while LMB tumble is held and resumes on release. RMB free-look and the held
Orbit Camera Left/Right shortcuts immediately disable Auto Orbit and apply
manual control on the same input; releasing them leaves Auto Orbit off. Wheel
zoom retains its accepted behavior. See [steering and orbit](MANUAL_CAMERA_ORBIT.md).

**Navigate → Edit orbit center…** temporarily turns Auto Orbit off and enables
Free Camera movement for placement. The [view-relative handles](ORBIT_CENTER_VIEW.md)
use the orientation captured at entry; numeric XYZ stay absolute world coordinates.
**Lock Position** anchors placement orbit/zoom to the draft without a camera
snap. RMB steering and Free Camera translation remain available; camera motion
leaves draft XYZ/radius exact. The shaded radius and persistent world references
remain visible over dense fields. Handles and numeric edits remain active while locked.
The proposed target and radius remain draft values until Apply. **Apply** commits
the world-space target and radius, retains the full current camera basis and
immediately starts Auto Orbit there. **Cancel** restores the complete camera and
navigation state from before the editor opened, including whether Auto Orbit
was on. Numeric text focus keeps the normal movement-key protection.

Frame Scene and Reset Camera retain their existing framing behavior. Navigation
and Auto Orbit affect the camera, never scientific/world transforms.

## Implementation boundary

`scene_layers.tick()` calls `_move_free_camera()` before advancing automatic
yaw. The movement function switches modes as soon as it finds a movement key,
then uses the existing Free Camera translation path. The rest of the camera
representation remains in place. Issue #258 adds in-place RMB steering through
full-basis/target synchronization and moves view-relative orbit to held keys.
The editor saves
the pre-edit pose and mode, uses a temporary placement mode, and either restores
the saved state or commits the new target and starts Auto Orbit.

The previous #234 candidate let W/S change the radius while Auto Orbit stayed
on. Its validation counts describe that earlier behavior and are retained in
PR history; they do not validate this revision.

## Historical #234 validation

`tools/validate_camera_tumble.py --suite auto-orbit` covers particle, volume,
mesh, and mixed WVZ1 fixtures plus an optional real mesh capture. It checks
default Free Camera movement, automatic orbit motion, immediate exit and
camera-relative translation for all six movement keys, editor Apply/Cancel from
both starting modes, LMB/RMB/wheel, and stable scientific/world transforms.
The connected camera tumble suite checks the existing manual camera behavior.
The runner verifies that fixture and optional real capture bytes do not change.

Revision results: 368 Auto Orbit checks passed in each of headless, native
Forward+, and native Compatibility with the small real cavity-collapse mesh
capture. The connected camera tumble suite passed 13,798 checks headless and
13,814 in native Compatibility. Both application-version tests, the version
CLI (`v0.1.0.48`), and `git diff --check` passed. Fixture and real-capture
SHA-256 hashes were unchanged. The reported large particle/field capture was
not available for this run; its visual feel remains an owner check.

## Owner verification

1. Open a particle, field, or mesh scene. Turn Auto Orbit on, then press each
   movement key. The first press should stop Auto Orbit and move the camera in
   the expected camera-relative direction. Turn orbit back on to check pose
   continuity.
2. Tumble with LMB, steer with RMB, orbit with the configured left/right keys,
   and zoom with the wheel before and after the mode transition. LMB temporarily
   suspends Auto Orbit; RMB and orbit keys disable it until re-enabled.
3. Open Edit Orbit Center first with Auto Orbit on and then off. Navigate while
   placing the guide. Cancel each time to recover the exact previous view and
   mode. Apply a visibly off-center target and confirm orbit starts immediately
   around that target.
4. Check native Forward+ and Compatibility views. Scientific object coordinates
   and playback content should remain unchanged by camera navigation.
