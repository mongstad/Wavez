# Custom orbit pivot/radius setup — issue #120

Implemented on the existing issue-linked branch and draft PR #149 from accepted
main `1a60774` (PR #148, build 11). Candidate **v0.1.0.12** remains pending owner
verification after the first hands-on review requested changes. #120 was Ready
at initial inspection, then In progress; the owner explicitly confirmed
continuing. No Project status writes, merge or auto-merge were performed.

## Interaction

1. Enable **Navigate → Free camera**, fly toward a region with WASD/QE, and
   **hold RMB inside the simulation viewport**.
2. A compact violet sphere appears entirely in front of the camera. Its initial
   target distance is 40% of the current camera distance, and its radius is
   one eighth of that target distance (5% of the original camera distance).
   A camera distance of 97 therefore starts with radius 4.85, rather than 97.
   These proportions scale with the current camera presentation.
3. **Wheel down** enlarges radius by **1.6×** per notch; wheel up divides by 1.6.
   **Shift+wheel** uses **1.01×** and its reciprocal. Radius changes visibly resize
   the sphere while leaving its pivot fixed. The radius slider is logarithmic.
4. Use the separate **Target distance** logarithmic slider to place the pivot
   along the viewing ray. Continue WASD/QE flight and mouse-look: the sphere
   follows the current camera position/direction at the chosen target distance.
   Automatic orbit is temporarily suspended without changing its enabled state.
5. **Release RMB** to commit, including over chrome. The camera moves to the
   near side of the sphere, at exactly the configured radius from its pivot,
   preserving its orientation. The panel states the forward/backward movement
   before release. Enable **O / Auto orbit**, or left-drag, to orbit the new pivot.
6. **R** during setup abandons the proposal; R after commit clears custom state.
   Reset restores the loaded scene's last successful framing with default
   yaw/pitch (38°/24°) and normal clipping. It no longer resets off-center captures
   to world origin or imposes the old 30-unit minimum distance. Frame Scene still
   frames the current scene while preserving orientation. **Esc** retains its
   existing fullscreen recovery role.

The deterministic geometric model is:

```text
pivot = preview_camera_position + camera_forward * target_distance
committed_camera_position = pivot - camera_forward * radius
```

Placement distance and radius are independent; their difference is the explicit
movement on release. This replaces the initial experiment's surface-observer
model, whose guide filled the viewport and hardly changed apparent size.
Neither control picks a scientific object, surface, probe or selection. A new
hold proposes a new target in front of the current camera; setting target distance
equal to radius produces no camera translation on release.

Both sliders start with a six-decade span relative to their initial value and
expand when wheel/API adjustment reaches farther. Values are bounded to `0.0001`
through `1e12` simulation units; initial target distance is at least `0.0004`.
Window focus loss or leaving Free camera cancels and restores the entry pose.
Free movement after commit retains the custom pivot and stored radius. Deliberate
orbit resumption reconciles distance/yaw/pitch from the new camera position.
Normal noncustom wheel limits and continuous upside-down tumble remain intact.

## Camera recovery and clipping

The old commit budget `far = radius * 8` could remove every scientific object even
with a finite camera transform. Reset then aimed at `(0,0,0)`, leaving an
arbitrary off-center scene inaccessible; enabling orbit inherited that view.
The [retained reproduction](evidence/issue-120/owner-review-1/README.md) records
zero scientific pixels after commit, Reset and Auto Orbit on both renderers.

Custom far clipping now covers the last framed scene bounds from both the live
camera and the entire possible orbit, in addition to the radius budget. Near
clipping is `max(1e-6, far / 90000)`, keeping the projection representable on
Forward+ at small and large scales. It updates after custom flight, zoom and
rotation. The scene recovery frame is refreshed on successful Frame Scene/open,
cleared when a new source is installed, and excluded from portable presets.
Reset reads this frame independently of malformed live target, distance, angles,
transform, clipping or extent. Invalid FOV is also restored to the default.

Keyboard/menu Auto Orbit and an already running orbit validate camera state
before using it. A finite but undersized custom clip budget is repaired; invalid
camera state restores the scene view. Invalid proposals, or radii lost to spatial
float32 precision, are rejected and restore that view with a status message.
This prevents committing a numerically broken camera; it cannot make an arbitrary
empty target contain scientific geometry.

## Temporary guides and saved presentation

The guide uses an outlined pivot cross labelled **Pivot**, a radius spoke, a
camera-facing great circle and two faint tilted meridians. They show the true
world-space sphere radius without an opaque surface. The control panel sits at
the lower left, clear of the default sphere. Guides are clipped to the available
simulation area and remain legible on bright and dark backgrounds.

Ordinary PNG and direct scientific PNG/bundle capture suppress the guide and
panel through nested scopes, restoring an active preview afterward. Offline/video
viewers never construct the preview, including exports with the production shell.

Portable version-1 view presets retain `settings.view.custom_orbit`, target,
distance, yaw/pitch and complete transform. Shared visual snapshots retain the
flag; deterministic video consumes the committed camera through its existing
world-Y sampling. Proposal controls, temporary graphics, input state and loaded
scene recovery bounds are not serialized.

## Validation

Native Godot 4.7.2 / Linux / NVIDIA RTX 3070 Ti results for this owner-review revision:

| Suite | Forward+ | Compatibility |
| --- | ---: | ---: |
| Custom orbit interaction, rendered recovery, capture and fullscreen | 1,028 PASS | 1,028 PASS |
| Existing continuous camera | 13,044 PASS | 13,044 PASS |
| Portable presets | 838 PASS | 778 PASS |
| Viewer shell/menu contract | 667 PASS | 667 PASS |
| Edge reveal/fullscreen restoration | 210 PASS | 210 PASS |
| Redraw pacing/offline isolation | 290 PASS | 290 PASS |
| Status/Jobs | 257 PASS | 257 PASS |
| Current scientific video | 235 PASS | 225 PASS |

**33,068 native assertions** and **two Python version tests** pass. Native import,
Python compilation and whitespace checks pass. Complete generated capture hashes
remain unchanged. Compatibility omits the existing 60 preset quality comparisons
and 10 exact GPU float-plane readback assertions; Forward+ retains them.
The focused Compatibility process still emits two GL texture-leak shutdown
diagnostics of 349,524 bytes each. The same type/size/count reproduce on accepted
main. The validator explicitly compares that retained baseline, normalizing only
runtime GL IDs; other errors, script errors and warnings fail. Clean Compatibility
teardown is not claimed.

Focused coverage includes off-center particles, scalar volumes, meshes and mixed
scenes, plus actual mesh captures scaled by 0.01 and 1000. Native image checks
require scientific content after small-radius commit, Reset, keyboard/menu Auto
Orbit, malformed camera recovery, already active Auto Orbit, and precision
rejection. Pure camera-scale checks span 0.001 through 1e8. Existing interaction,
repeated equal-distance commit, presets, playback, screenshot/scientific bundle,
fullscreen and deterministic video checks remain. PNG equality covers the entire
simulation area; capture-time transport disabling lies outside that comparison.

See [this revision's evidence](evidence/issue-120/owner-review-1/README.md) and
[results](evidence/issue-120/owner-review-1/summary.json). The
[first implementation report](evidence/issue-120/README.md) and all earlier
review evidence are preserved as historical records.

```sh
python tools/validate_orbit_setup.py --godot /absolute/path/godot \
  --output-dir /absolute/new/output --renderer forward_plus
# Repeat with --renderer gl_compatibility and:
# --baseline-log docs/evidence/issue-120/accepted-main-compatibility.txt
```

## Owner verification before acceptance

![Compact initial sphere in front of the camera](evidence/issue-120/owner-review-1/forward-front-sphere.png)

![One normal wheel notch visibly enlarges radius](evidence/issue-120/owner-review-1/forward-coarse-sphere.png)

1. Open the capture that failed in the first review, on each renderer. Hold RMB
   in Free camera: verify the whole initial sphere is ahead of you, its size is
   manageable, and the pivot/radius are clear.
2. Compare several normal wheel notches with Shift+wheel. Adjust Target distance
   independently, then continue WASD/QE and mouse-look. Confirm the panel's
   stated release movement and the chosen placement/radius feel predictable.
3. Release: verify scientific content remains visible and the camera lands at
   the configured radius. Enable Auto Orbit through both O and Navigate; then
   try left-drag and custom zoom. Repeat around another off-center region.
4. Try very small and large radii. Press R during and after setup: verify visible
   scene framing returns, including after a rejected edge case. Repeat R to
   ensure recovery does not return to world origin. Check Frame Scene separately.
5. Repeat in Fullscreen: R retains the window mode, Esc retains shell recovery.
   Release over chrome, cancel by losing focus, and re-enter. Save/load a preset;
   fly again after commit and resume orbit without losing the custom pivot.
6. Capture PNG during setup and export locked/orbit clips with UI off/on. Verify
   the preview is absent. Inspect bright/dark scenes and different capture scales.

Owner feel and the original production-capture failure still require hands-on
verification. Windows/macOS and other GPUs are untested. Very small radii at large
coordinates remain limited by Godot spatial precision, and extremely wide
near/far spans have GPU depth-precision limits. No production simulation was rerun.
