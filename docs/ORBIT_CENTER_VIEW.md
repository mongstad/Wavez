# Edit Auto Orbit's center from the current view (#212)

Choose **Navigate → Edit orbit center…** after tumbling, steering, zooming or
moving with Free Camera. The editor captures that view's orientation for its
placement handles. The stored center remains a world-space point.

- **Right**, **Up** and **Toward** move the draft along the captured camera's
  right, up and camera-facing depth directions. Toward has a diagonal screen
  handle when depth is end-on; dragging toward its endpoint brings the center
  toward the camera. The reference axes stay fixed for that editing session,
  including if the camera is moved while placing the draft.
- Numeric **X / Y / Z** remain absolute world coordinates. Changing one field
  preserves the exact values of untouched fields; displayed rounding does not
  change a draft on Apply. The coordinates are not camera-space values.
- **Depth** is the distance in world units along the current camera's
  forward direction for the next **Place ahead** click. Opening seeds it once
  from the existing target's view depth, using a positive navigation distance
  if necessary. The value stays visible with controls collapsed and remains
  unchanged by navigation, XYZ edits or radius edits. Enter a different depth
  to choose a nearer or farther point; changing this field alone does not move
  the draft. It must be beyond the camera's near clip plane.
- **Place ahead** puts the draft on the current camera's forward ray at the
  displayed depth. It preserves the camera pose, handle reference
  frame and radius, then releases editor focus so W/A/S/D/Q/E work immediately.
  It uses the depth you choose; it does not pick a scientific feature or infer
  that feature's distance. The initial depth may therefore need adjustment
  after flying close to a structure.
- Radius controls keep their existing 25% coarse / 2% Shift steps and bounds.
  The accepted radius stays unchanged unless edited.

The draft stays fixed in world space while you inspect it from several viewpoints.
Its screen position changes with the camera's perspective, in the same way as
stationary scientific landmarks at that position.
LMB tumble and held orbit shortcuts automatically rotate the actual camera offset
around the draft center; wheel zoom approaches or retreats from that center. **RMB remains
in-place steering**, and W/A/S/D/Q/E remain Free Camera translation. Navigation
never changes the draft's world XYZ, radius or placement depth. Handles, numeric
XYZ/radius, radius buttons and **Place ahead** remain explicit edits during placement. Editing
the center updates the anchor for subsequent navigation. Opening leaves the camera
pose unchanged. The temporary placement anchor ends on Apply or Cancel; there is
no Lock Position toggle or separate lock state.

The radius now has a solid shaded surface, a bright rim and world-aligned rings
and X/Y/Z diameters. It is drawn as an annotation over the field so dense volumes
cannot hide it. A persistent upper-left world XYZ/radius readout stays visible
when controls are collapsed. It identifies views from inside the radius, where
the outer silhouette can lie outside the screen; move backward with Free Camera
to inspect the entire boundary. **World X/Y/Z** label spatial references, while
**Right/Up/Toward** label captured-view editing handles. Foreshortened/overlapping
handles use separate screen endpoints with the same captured world directions.

Opening temporarily suspends Auto Orbit and enables Free Camera placement.
**Apply** commits the world-space target/radius, retains the full current camera
basis (including any placement navigation), then establishes Auto Orbit's stable
equator from that view's up axis. The camera physically circles the chosen target
at the selected radius and keeps looking toward it. Camera position becomes the new target plus the retained
camera-back direction times the radius. Reopening and applying unchanged values
does not snap or accumulate rounding drift.

**Cancel** restores the complete saved pre-edit pose, target, radius, full-basis
state and navigation modes. Repeated cancelled sessions do not change the view.
Hide/Show controls keeps the existing compact layout behavior. Handles covered by
chrome or outside the usable viewport cannot receive a drag; use Place ahead,
Hide controls or numeric world coordinates when needed.

The placement workflow and subsequent automatic camera circle share the chosen
world center. LMB tumble and its inversion preference, RMB in-place steering,
held orbit hotkeys, wheel zoom, Free Camera, shortcuts and scientific geometry
retain their contracts. #212's original
description named the old #190 RMB orbit; owner clarification preserves the
current [#258 steering/hotkeys](MANUAL_CAMERA_ORBIT.md).

The guide is transient UI. It is excluded from saved inspection/preset/video
state and scientific output; existing dismissal paths remain in place. No
capture payload, object transform, scientific coordinate frame or format changes.
World placement retains Godot's existing vector-precision and clipping limits;
original source arrays retain their own scientific precision.
The earlier [#120 editor report](ORBIT_CENTER.md) remains historical.

## Focused validation and owner checks

The owner reports that the sphere still appears to move during WASD/QE after
Place ahead while World XYZ stays fixed. The
[continuous-navigation follow-up](evidence/issue-212/live-navigation/README.md)
checks actual rendered frames during held-key motion, including a stationary
copy of the owner's sample. Those runs found no sphere drift or camera lag;
the owner's exact failing view has not been reconstructed and remains unresolved.
The existing verbose session log now records an `ORBIT` JSON event on editor
open and successful Place ahead: full-precision camera pose/projection,
navigation state, draft center/radius/depth, previous center, capture and sample.
There is no per-frame logging. On the next occurrence, retain the session log;
a second Place ahead click after navigation records the previous anchor and
the new camera ray without requiring manual transcription of the readout.

The [world-placement investigation](evidence/issue-212/world-placement/README.md)
records two reproducible causes: Place ahead silently reused a depth inherited
from navigation, and the clicked button retained focus and blocked immediate
W/A/S/D/Q/E movement. Identical camera poses aimed at the same landmark could
place the draft 300 world units apart with different navigation distances;
immediate W-key travel after the click was zero. The rendered guide agreed
with its stored world position. Earlier tests created a reference at the
chosen draft and manually released focus, so they missed both workflow defects.

The new reproduction uses pre-existing asymmetric particle, mesh and volume
landmarks with realistic dimensions and nonidentity data-to-world transforms.
It records camera pose/pivot, draft/render transforms, placement depth and two
scientific landmark projections around each gesture and an identical-pose
round trip. Local session logs confirm orbit editing in both candidate owner
captures; metadata gives both volumes bounds of `[-48, 48]` on each axis. The
reported sphere lies outside those bounds, but the screenshot's exact capture
and camera pose remain unconfirmed. The evidence distinguishes that bounded
metadata check from the synthetic rendered reproduction.

The historical [Place ahead evidence](evidence/issue-212/place-ahead/README.md)
diagnoses the earlier radius-dependent depth jump and checks camera movement
around a reference created at the placed world center.
The [automatic placement evidence](evidence/issue-212/automatic-placement/README.md)
records the owner's removal of the lock toggle while preserving the anchored
inspection workflow. The [equatorial orbit evidence](evidence/issue-212/equator-refinement/README.md) records
the preceding PR #301 camera-motion refinement. The
[lock refinement evidence](evidence/issue-212/lock-refinement/README.md) records
the owner-requested revision. The [initial issue evidence](evidence/issue-212/README.md) records exact results, baseline
reproduction, intermediate failures, native/package checks and limitations.
The current world-placement runner generates stationary WVZ1 fixtures and injects
events inside Godot. Run from the repository root:

```sh
python tools/validate_orbit_center_world.py \
  --godot /absolute/path/to/godot \
  --renderer forward_plus --expect-explicit-depth \
  --output-dir /tmp/NEW_ORBIT_WORLD_DIRECTORY
```

Repeat with `gl_compatibility` or `headless`. The retained view runner generates
eight small WVZ1 captures and covers the preceding editing contracts:

```sh
python tools/validate_orbit_center_view.py \
  --godot /absolute/path/to/godot \
  --renderer forward_plus \
  --output-dir /tmp/NEW_ORBIT_VIEW_DIRECTORY
```

Repeat with `gl_compatibility` or `headless`. Add `--export` to build and run a
temporary Linux release validation package with a test entry scene and the same
production Viewer/resources. `--packaged` reruns an already built validation
executable; production release templates do not run a `--script` test driver. Fixture/source
hashes, full camera state, draft serialization and scientific transforms are checked.
Connected navigation and Auto Orbit suites cover the unchanged immediate paths.
Add `--placement-refinement` for the automatic placement matrix, dense 32³ field,
close-up/side views, collapsed controls and large-radius interior/exterior.
Add `--equator-refinement` for Apply-time plane/radius/center checks, tilted,
rolled and polar views, asymmetric stationary captures with fixed world axes,
and recorded playback with automatic camera motion on/off.

Before acceptance:

1. In particle, field, mesh and mixed scenes, navigate to a visibly tilted view
   using LMB, RMB and their combination. Open the editor and drag each labeled
   handle; confirm the numeric XYZ show the resulting absolute world position.
2. Apply a new center without editing radius. Confirm the view retains its full
   orientation at Apply and Auto Orbit starts at that world center. Repeat with
   a radius-only edit and several unchanged Apply cycles.
3. Navigate and edit while placing a draft, then Cancel. Confirm the exact prior
   pose, center, radius and Auto Orbit mode return. Repeat open/cancel cycles.
4. Check RMB still steers in place and held orbit hotkeys follow the resulting
   view-up. Repeat normal/fullscreen, both renderers, Linux package, small/large
   scene scales and physical mouse feel. Scientific objects must remain unchanged.
5. Aim at an identifiable feature in a dense 3D field, set **Depth**,
   and click **Place ahead**. Press W/A/S/D/Q/E immediately after the click.
   Steer with RMB, tumble with LMB, zoom and translate around the center. Inspect
   it against stationary features from both sides and return to the original
   camera pose. World XYZ/radius and **Depth** must remain unchanged;
   the original pose must reproduce the original relationship to the features.
   Change depth without clicking and confirm the draft stays put, then click
   Place ahead to use the new distance. Also drag each handle and edit numeric
   XYZ/radius. Repeat with controls collapsed.
6. Inspect from several viewpoints and from inside/outside a large radius.
   Check the shaded surface, bright boundary, world reference rings and readout
   in normal/Fullscreen and with controls hidden. Apply retains the current full
   basis; Cancel restores the exact pre-edit state.

Candidate build 78 is pending owner review; automated checks do not establish acceptance.
