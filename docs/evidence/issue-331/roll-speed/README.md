# Issue #331 / PR #333 — Shared roll-speed refinement

Candidate **v0.1.0.88**, pending final owner review. This continues the existing
`331-ux-nav-add-configurable-roll-camera-leftright-hotkeys-for-free-flight-navigation`
branch after owner feedback on PR #333. Fresh GitHub/fetch checks confirmed the
PR is open against `main`, with initial head `14e8ccebf9677c5c735137ea78cca7fa594a9053`
and accepted main `c33ff2b899330020871792757f5cbfffeedf35ac` (build 87, PR #332).
The branch contained main with a clean tree before edits. The original Ready
selection and 90°/second checkpoint remain in the unchanged [initial report](../README.md).
The owner explicitly authorized this refinement; no Project transition is made.
Build 88 remains fixed under the once-per-PR version rule.

## Behavior

Manual camera roll now defaults to **18°/second**. One **Camera Roll Speed** slider
sits immediately after Roll Camera Left/Right under Navigation, with **5–90°/second**
bounds, **1°** increments and a current-value label such as `18°/s`. Both directions
read the same applied preference. The only runtime camera change substitutes
that angular speed into the existing elapsed-time local-Z basis product; direction,
axis, orthonormalization and orbit-plane retention are unchanged.

The slider participates in the existing modal draft. Apply atomically saves keys,
LMB inversion and roll speed, activates them only after a successful save, and
leaves the editor open. Cancel/Escape/X discard drafts; reopening restores the
applied value. Reset Defaults stages 18°/second with the catalog defaults. A
failed save leaves applied keys/speed intact. Speed is an integer in the
`navigation.camera_roll_speed` application shortcut profile; missing/invalid
values use 18. It is excluded from scientific captures, saved views and exports.
Slider edits do not alter key assignments. No tooltips were added.

## Focused validation

Godot **4.7.2.stable.official.ed1daf0bf**, NVIDIA GeForce RTX 3070 Ti, Linux native
Vulkan Forward+ and OpenGL Compatibility. Each roll run uses an isolated profile,
small generated particle/field/mesh/mixed WVZ1 fixtures, a separate-process restart
and unchanged fixture SHA-256 checks. Package runs use actual Linux release
templates. [Source hashes](source-sha256.json) identify the validated code;
[evidence hashes](SHA256SUMS) cover this refinement record.

| Check | Result | Evidence |
| --- | --- | --- |
| Roll/speed headless | 2,274 assertions, 0 failures | [Result](headless/validation.json), [log](headless/roll.txt) |
| Roll/speed native Forward+ | 2,832 assertions, 0 failures | [Result](source-forward/validation.json), [log](source-forward/roll.txt) |
| Roll/speed native Compatibility | 2,832 assertions, 0 failures; known teardown diagnostics | [Result](source-compatibility/validation.json), [log](source-compatibility/roll.txt) |
| Roll/speed Linux release Forward+ | 2,832 assertions, 0 failures | [Result](package-forward/validation.json), [log](package-forward/roll.txt) |
| Roll/speed Linux release Compatibility | 2,832 assertions, 0 failures; known teardown diagnostics | [Result](package-compatibility/validation.json), [log](package-compatibility/roll.txt) |
| Connected navigation headless | 1,393 assertions, 0 failures | [Report](navigation-headless/camera-report.json), [log](navigation-headless/camera.txt) |
| Connected navigation Forward+ | 1,747 assertions, 0 failures | [Report](navigation-forward/camera-report.json), [log](navigation-forward/camera.txt) |
| Connected navigation Compatibility | 1,747 assertions, 0 failures | [Report](navigation-compatibility/camera-report.json), [log](navigation-compatibility/camera.txt) |
| Shortcut groups/focus headless | 294 assertions, 0 failures; restart/hash verified | [Result](shortcut-groups/validation.json), [log](shortcut-groups/native.txt) |
| Version policy | 2 tests pass; CLI v0.1.0.88 | [Log](version-tests.txt) |
| Python compilation, whitespace, source/evidence hashes | Pass | Recorded commands below and hash manifests |

The **13,602 roll assertions** cover default speed, one slider, limits/snapping,
arrow-key increments, unchanged bindings, draft-only changes, Apply/Cancel/Escape/X,
Reset Defaults, failed saves, invalid stored/input values and fresh-process
restoration of a non-default **37°/s** value and slider position. At **5, 18 and
90°/s**, both directions reach the same quarter turn with **12/120 Hz** stepping.
Default checkpoints are ±90° at 5 seconds, ±180° at 10 and ±360° at 20, including
position/forward/basis checks. Opposite directions undo each other.

Every run also holds a synthetic key through the actual `_process` loop for five
seconds: source Forward+ records **90.1241° in 5.0249 seconds**, Compatibility
**90.1244° in 5.0252 seconds**, package Forward+ **90.1242° in 5.0247 seconds**
and package Compatibility **90.1242° in 5.0245 seconds**. Position error is **zero**;
the largest recorded forward error across these runs is below **1.1e-6**.
The pure elapsed-time five-second check reaches 90° within the existing basis
tolerance. Timer/frame scheduling explains the small wall-clock difference.

Existing checks retain held-key release/repeat/guards, simultaneous manual orbit,
RMB/local translation, custom orbit-center plane and fractional zoom, presets,
offline camera snapshots, reset/frame/reopen, Auto Orbit takeover and fullscreen.
Scientific world transforms, original points, sample/time state and fixture bytes
remain unchanged. The connected navigation and shortcut-group checks cover the
immediate shared paths; unrelated playback/analysis/export suites were not run.

## Layout evidence

Dark and Light themes are checked at normal 1440×900, compact windows (native
minimum 970×600), and simulated 2× scaling with a 1920×1200 window / 960×600 logical
viewport. Assertions measure panel containment, focused slider visibility,
unclipped label/value text and separation from the fixed footer. Native screenshots
were visually inspected. Scaling is a synthetic UI check, not physical mixed-DPI
monitor acceptance. F8/F9 are isolated test assignments; shipping defaults remain
Unbound.

| Theme | Normal | Compact | 2× scale |
| --- | --- | --- | --- |
| Dark | [View](source-forward/speed-dark-normal.png) | [View](source-forward/speed-dark-compact.png) | [View](source-forward/speed-dark-scale-2.png) |
| Light | [View](source-forward/speed-light-normal.png) | [View](source-forward/speed-light-compact.png) | [View](source-forward/speed-light-scale-2.png) |

Equivalent package/Compatibility views and banked scene projections are retained
beside their reports. The current navigation, shortcut, handbook, status and
evidence-index guides are updated; the initial evidence's **82 hashes** still match.

## Investigations and limits

The first import regenerated four pre-existing untracked resize-script UID files
and warned about their missing sidecars; an unchanged warm import succeeded.
[Import log](investigation/initial-import.txt). A preliminary expanded test script
needed an explicit float declaration; its failed load timed out and is not counted
as a pass. Type checking and final complete runs pass after correction.
[Preliminary notes](investigation/preliminary-run-notes.txt).

Compatibility retains exactly **ten** texture-release diagnostics after the main
completed summary and **two** after restart. The unchanged runner accepts only
the previously reproduced exact pattern/count at that stage and retains every
message in logs and JSON. Accepted-main comparison probes are in the
[initial investigation](../README.md#investigations-and-limitations). This is a
known harness teardown limitation, not a clean Compatibility shutdown claim.
All other warnings/errors, incomplete runs and assertions remain failures.

Physical keyboard feel, owner KDE/Wayland/window-manager chords, physical mixed-DPI
or 4K comfort, production captures and long sessions remain owner checks.
Encoded MP4 and numerical export pipelines were not rerun; their code, sampling,
timestamps and formats are untouched. Offline full-transform and source/world
state checks do not constitute a new encoded-video acceptance run.

The normal, uninstrumented owner package is
`/tmp/wavez-331-speed-review/owner-package/WAVEZ.x86_64`, with adjacent `WAVEZ.pck`.
[Build metadata/hashes](owner-package-build.json), [import](owner-package-import.txt),
[export](owner-package-export.txt). Binaries, captures, isolated profiles and caches
remain external to Git.

## Reproduction and owner review

```sh
python tools/validate_camera_roll.py --godot /path/to/godot --renderer headless --output-dir /tmp/roll-speed-headless
python tools/validate_camera_roll.py --godot /path/to/godot --renderer forward_plus --output-dir /tmp/roll-speed-forward
python tools/validate_camera_roll.py --godot /path/to/godot --renderer gl_compatibility --output-dir /tmp/roll-speed-compatibility
python tools/validate_camera_roll.py --godot /path/to/godot --renderer forward_plus --package --output-dir /tmp/roll-speed-package-forward
python tools/validate_camera_roll.py --godot /path/to/godot --renderer gl_compatibility --package --output-dir /tmp/roll-speed-package-compatibility
python tools/validate_camera_tumble.py --godot /path/to/godot --renderer headless --suite navigation --output-dir /tmp/navigation-headless
python tools/validate_camera_tumble.py --godot /path/to/godot --renderer forward_plus --suite navigation --output-dir /tmp/navigation-forward
python tools/validate_camera_tumble.py --godot /path/to/godot --renderer gl_compatibility --suite navigation --output-dir /tmp/navigation-compatibility
python tools/validate_keyboard_shortcuts.py --godot /path/to/godot --renderer headless --group-only --output-dir /tmp/shortcut-groups
python -m unittest tests.test_application_version -v
python -m py_compile tools/validate_camera_roll.py tools/validate_keyboard_shortcuts.py tools/validate_camera_tumble.py
git diff --check
```

1. Launch the normal package; confirm Help → About shows **v0.1.0.88**.
2. Open Edit → Preferences → Keyboard Shortcuts → Navigation. Confirm one
   Camera Roll Speed slider directly below both roll assignments, default 18°/s
   on a profile without a saved speed. Verify 5/90 limits and 1° arrow-key steps.
3. Bind unused left/right keys and Apply. Close Preferences, enable Free Camera
   and hold each for about **five seconds**: expect opposite 90° banks, stable
   position/forward and immediate release. Check both held keys cancel. Assess
   smooth, deliberate physical key feel on representative scientific scenes.
4. Apply another speed; check equal left/right rate, unchanged assignments,
   reopening and restart. Try unapplied speed drafts with Cancel, Escape and X.
   Reset Defaults should stage 18°/s plus default bindings and activate only on Apply.
5. Repeat normal/compact/fullscreen and Dark/Light on the owner's DPI setup.
   Bank, then check RMB steering, LMB tumble, W/A/S/D/Q/E, wheel, held orbit,
   Auto Orbit takeover/custom-center resume, Reset Camera, Frame Scene and saved views.
6. Check focused fields, menus/editors and alt-tab do not resume stale holds.
   Review representative particle/field/mesh/mixed captures and a fixed-camera
   image/video plus numerical output before acceptance.

PR #333 remains for owner review. No merge, issue closure, auto-merge or manual
Project status change is performed.
