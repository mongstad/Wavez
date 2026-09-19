# UI-003 — continuous camera tumble validation

Issue #2 implementation; pending owner review. Only this Ready issue was selected.

## Change and compatibility

Previously a mouse drag clamped pitch to ±82 degrees. Removing that clamp alone
would leave `look_at(target, world_up)` singular at the poles and invert its up
axis beyond them. The viewer now uses `Ry(yaw) * Rx(-pitch)` for its basis and
places the camera at `target + basis.z * distance`. Its up axis therefore moves
continuously through the poles. The existing two-axis orbit is sufficient for
continuous rotation; no quaternion state or recipe schema migration is needed.
Horizontal drag remains world-Y yaw, including during upside-down inspection;
vertical drag follows the yawed right axis. There is no independent roll control.

Only the drag pitch update and camera transform calculation change in runtime
code. Auto-orbit increments, pan, zoom limits, reset, scene bounds, scientific
sampling and export camera sampling are unchanged. Legacy orientations within
±82 degrees match an independent world-up look-at reference within floating-point
tolerance. Existing recipes retain their yaw/pitch/target/distance/transform fields.

## Focused validation

```bash
python tools/validate_camera_tumble.py --godot /path/to/godot --output-dir results/camera-review --renderer forward_plus
python tools/validate_camera_tumble.py --godot /path/to/godot --output-dir results/camera-review-gl --renderer gl_compatibility
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir results/camera-recipes
python tools/validate_video.py --godot /path/to/godot --output-dir results/camera-video --renderer forward_plus --continuation
```

Use the project's Python environment and new output directories. Godot 4.7.2,
NVIDIA RTX 3070 Ti, native Forward+ and Compatibility:

- **13,044 camera checks PASS on each renderer**, clean import/runtime logs.
  [Forward+ report](evidence/issue-2/forward.json),
  [Compatibility report](evidence/issue-2/compatibility.json).
- Real mouse-motion handler: three full revolutions per axis in each direction;
  finite orthonormal transforms, small orientation increments through former
  limits and poles, preserved target/radius, and return to the original view.
  Diagonal drags at ±90, ±270 and ±450 degrees also remain continuous.
- Separate tiny particle, volume and closed-mesh `.ssc` fixtures: wheel zoom,
  camera-relative translation while inverted, Frame scene, orbit center, reset,
  recipe save/load at a pole and first-update continuity all pass. Camera actions
  preserve the committed sample and every fixture's SHA-256 remains unchanged.
- Live automatic orbit equals the deterministic video camera transform for the
  same elapsed time; dragging suppresses auto orbit. Locked sampling preserves
  the saved transform. Existing recipe suite: **2,987 checks PASS**, including
  v2/v3 restoration. The initial math/fixture run passed **13,032 headless checks**
  before replacing the one-sided mesh with a closed tetrahedron for visual review.
- Existing video continuation suite: **PASS**, including 41 native video-UX checks,
  actual MP4 exports, dimensions, frame rates/counts, timestamps, recorded trails,
  source hashes and expected refusal cases. The malformed-path and excessive-frame
  jobs fail intentionally and are asserted as successful negative checks.
- Native images captured at 80, 90, 100 and 180 degrees for each fixture. Reviewed
  beyond-pole views: [particles](evidence/issue-2/particles-pitch100.png),
  [volume](evidence/issue-2/volume-pitch100.png),
  [mesh](evidence/issue-2/mesh-pitch100.png).

Early harness attempts failed on missing synthetic fixture metadata/vertex IDs;
those fixtures were corrected before the passing runs. The first mesh was a
single back-face-culled triangle; it was replaced with a closed asymmetric mesh
and both native camera suites rerun. No production workaround was needed.

## Limits and owner verification

No external scientific simulation was rerun. The full 4K/video acceptance matrix,
full G0–G4 suite, interactive long-session usability and alternative input devices
were not tested. The tests invoke native handlers and render fixtures; they do
not replace owner acceptance of the drag feel. Numerical equivalence in the old
angle range is tested with tolerance, not a promise of bit-identical rasterization.

Before acceptance:

1. Open a particle capture, switch to camera interaction if selection mode is
   active, and turn automatic orbit off with O. Drag vertically through three
   revolutions in each direction, then horizontally and diagonally through the
   poles. Confirm no stop at ±82 degrees, jump, snap or sudden up-axis flip.
2. Repeat with a volume/field capture and a mesh scene. Inspect upside-down views.
3. While inverted, test wheel zoom and free-camera WASD/Q/E movement. Press F:
   the scene recenters without resetting orientation. Drag again to confirm the
   center remains stable. Press R to recover the normal default camera.
4. Save a recipe while inverted or at a pole, reset, reload and drag slightly.
   Confirm the saved view restores and the first movement does not snap.
5. Enable O, verify steady world-Y orbit, then drag/release to check temporary
   suspension and resumption. Export a short locked/orbit clip from the saved
   view and compare its camera path and scene appearance with expectations.

Stop for owner review; no merge, issue closure or subsequent Ready work is included.
