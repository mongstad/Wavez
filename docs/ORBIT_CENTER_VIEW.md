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
- **Place ahead** places the draft one draft radius along the current camera's
  forward direction. It does not move the accepted camera or reset the handle
  reference frame.
- Radius controls keep their existing 25% coarse / 2% Shift steps and bounds.
  The accepted radius stays unchanged unless edited.

Opening temporarily suspends Auto Orbit and enables Free Camera placement.
**Apply** commits the world-space target/radius, retains the full current camera
basis (including any placement navigation), then resumes the existing Auto Orbit
around the chosen target. Camera position becomes the new target plus the retained
camera-back direction times the radius. Reopening and applying unchanged values
does not snap or accumulate rounding drift.

**Cancel** restores the complete saved pre-edit pose, target, radius, full-basis
state and navigation modes. Repeated cancelled sessions do not change the view.
Hide/Show controls keeps the existing compact layout behavior. Handles covered by
chrome or outside the usable viewport cannot receive a drag; use Place ahead,
Hide controls or numeric world coordinates when needed.

This edits Auto Orbit placement only. LMB tumble and its inversion preference,
RMB in-place steering, held orbit hotkeys, wheel zoom, Free Camera, the existing
Auto Orbit movement and scientific geometry retain their contracts. #212's original
description named the old #190 RMB orbit; owner clarification preserves the
current [#258 steering/hotkeys](MANUAL_CAMERA_ORBIT.md).

The guide is transient UI. It is excluded from saved inspection/preset/video
state and scientific output; existing dismissal paths remain in place. No
capture payload, object transform, scientific coordinate frame or format changes.
World placement retains Godot's existing vector-precision and clipping limits;
original source arrays retain their own scientific precision.
The earlier [#120 editor report](ORBIT_CENTER.md) remains historical.

## Focused validation and owner checks

The [issue evidence](evidence/issue-212/README.md) records exact results, baseline
reproduction, intermediate failures, native/package checks and limitations.
The focused runner generates eight tiny WVZ1 captures and injects events only
inside Godot; it does not control OS input devices. Run from the repository root:

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

Candidate build 78 is pending owner review; automated checks do not establish acceptance.
