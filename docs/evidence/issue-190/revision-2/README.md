# Issue #190 — view-relative camera orbit revision 2

The owner's second physical review established that the right-drag axis must be
the camera's **screen-up direction at right-button press**, not fixed world Y.
This revision captures that unit vector and the full camera basis at each press.
Horizontal pointer travel accumulates an angle about the captured axis; the
camera basis is recomputed from the press-time basis and total angle. The camera
position remains `camera_target + basis.z * camera_distance`. This keeps the
target and radius fixed, aims at the target, retains the captured screen-up
direction without progressive roll, and permits complete revolutions in both
directions. Vertical pointer travel is ignored. Release ends the gesture; the
next press captures the then-current view.

A tilted view-up orbit cannot generally be represented by the existing yaw and
pitch pair. The full camera basis remains the live orientation after right-drag,
including through zoom, Frame Scene, subsequent left-drag tumble and world-Y
Auto Orbit. Existing left-drag input and angle updates are unchanged. Visual
state and view-preset restoration adopt their already-stored full camera
transform, so a restored view-relative orbit does not snap on its next update.
Reset returns to the legacy yaw/pitch basis. No new recipe/capture schema or
scientific transform was added. Candidate identity stays **v0.1.0.26** on the
existing issue branch and PR #199, pending physical owner review.

The [initial report](../README.md) and [revision 1 report](../revision-1/README.md)
remain unchanged as historical review-time records. Their right-drag axis
descriptions are superseded by this revision.

## Validation

Godot 4.7.2 on Linux KDE/Wayland with NVIDIA RTX 3070 Ti. The focused camera
suite passed **13,798 checks** across particle, volume, mesh and mixed SIMSCP4
fixtures. Each begins with a left-drag tumble to a deliberately non-world-aligned
view. It compares the resulting right-drag transform with rotation about the
captured screen-up axis, explicitly rejects the world-Y result, verifies a
vertical-only no-op, and checks target, radius, aim, captured axis and unchanged
scientific sample. It travels to the opposite side and back in both directions,
then left-tumbles to a second different non-world-aligned view and verifies a
newly captured right-drag axis. Existing left-drag three-revolution and pole
checks passed. A saved inspection recipe round trip from an arbitrary
view-relative orbit produced no camera snap. Fixture source hashes were unchanged.

| Native viewport check | Forward+ | Compatibility |
| --- | ---: | ---: |
| Source, quick cavity capture | 281 PASS | 281 PASS |
| Source, synthetic categories and fullscreen | 258 PASS | 258 PASS |
| Linux release package, quick cavity capture | 281 PASS | 281 PASS |
| Linux release package, synthetic categories and fullscreen | 258 PASS | 258 PASS |

The native suite sends real window events and, on the quick cavity capture,
performs left-drag → right-drag → a second left-drag → a second right-drag.
It verifies both view-up axes, the resulting transforms, vertical-only no-op,
unchanged mesh source vertices and scientific time, category changes, zoom,
Frame Scene, fullscreen and release over chrome. It exercises 1440×900 and
3840×2160 windows with content scales 1, 2 and 2.5. Generated and quick-cavity
source hashes were unchanged in every completed run. The quick cavity SHA-256
remained `9215baf4e475256b254916f290b5c569d17553e944c4778b17b74eed0ba0b10e`.
The separate headless view-preset suite passed **814** checks and the
recipe-state suite passed **2,663** checks. Two application-version unit tests
passed; final Godot imports/exports and `git diff --check` passed.

Machine-readable reports are adjacent to this file. Their `/tmp` fixture paths
identify local validation runs. Generated captures, package binaries and
screenshots were not committed.

## Diagnostic attempts and limits

The first native Forward+ cavity run reported one test failure for the very
large synthetic scene: the new transform comparison used a fixed absolute
position tolerance. A scale-aware position tolerance kept strict basis checks,
and the unchanged product code passed on rerun. One Compatibility source
synthetic/fullscreen attempt wrote a report with all **258 assertions passing**
but timed out after 160 seconds during teardown. An unchanged rerun exited
cleanly with 258 passes. An internal simplification that used the mutable camera
transform as the retained orbit basis produced two Compatibility cavity teardown
timeouts after all 281 assertions passed. Restoring the previously validated
basis-retention path produced a clean 281-pass cavity run. The final native logs
retain only the known Wayland libdecor GTK fallback diagnostic. The older
combined Compatibility cavity/fullscreen teardown timeout was not retested;
final cavity and fullscreen
matrices ran separately and exited cleanly.

The full 240-second cavity capture, sustained playback while physically
dragging, subjective throat/surface feel, physical 4K/mixed-DPI pointer
behavior, long-session use, other operating systems and a new video-export
comparison were not run. Automated camera state and quick-capture checks do
not establish those properties. Physical owner acceptance remains required.

## Owner verification

1. Open the full cavity-collapse torus and press F. With Auto Orbit off,
   left-drag to an obviously arbitrary orientation whose screen-up is not
   world Y. Release left and right-drag sideways around the torus. Inspect its
   opposite side and return through a full circle. Check fixed geometry,
   target, radius, aim and screen-up direction.
2. Right-drag vertically, then diagonally. Vertical-only motion should do
   nothing; diagonal motion should use only horizontal travel. Release right.
3. Left-drag to a completely different orientation. Right-drag again and check
   that the sideways orbit plane now follows the newly visible view. Confirm
   left-drag still tumbles freely.
4. Repeat at whole-scene, close-surface and inside-throat zoom. Check wheel,
   Frame Scene and Auto Orbit pause/resume. Repeat with particle, field, mesh
   and mixed scenes during playback and fullscreen in both renderers and a
   Linux package; release over chrome and close the window.
