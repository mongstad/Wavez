# Issue #331 / PR #333 — Configurable vertical movement

Candidate **v0.1.0.88**, pending owner review. The owner requested this follow-up
in [PR #333's review comment](https://github.com/mongstad/Wavez/pull/333#issuecomment-6100864915)
after finding that Q/E roll bindings also triggered fixed vertical movement.
Work continues on the existing
`331-ux-nav-add-configurable-roll-camera-leftright-hotkeys-for-free-flight-navigation`
branch. Before edits, it was clean at `c3bf800d4bd86fc6215e6c670be81c54ccacae08`,
matched the open PR head, and contained current accepted main
`c33ff2b899330020871792757f5cbfffeedf35ac` (build 87, PR #332). The owner explicitly
authorized this scope in the existing PR; no new Ready issue or branch is selected.
Build 88 stays fixed through review revisions.

## Behavior and decisions

- **Move Camera Up** defaults to **E**; **Move Camera Down** defaults to **Q**.
  Both use the existing Navigation catalog/editor, rebind, Clear, Reset Defaults,
  Apply/Cancel/Escape/X, persistence and immediate draft conflict transfer.
- Fixed Q/E polling is removed. Held logical bindings and their modifiers provide
  the vertical component of the unchanged camera-local translation vector and
  speed formula. Opposite directions cancel. Auto Orbit takeover still occurs on
  the first movement tick, including when Free Camera was disabled.
- Assigning Q/E to roll unbinds the corresponding vertical actions. Regression
  input keeps the physical Q/E keys pressed while applying roll and movement
  updates; the camera banks with **zero position/target change**.
- Configured movement plus roll follows the newly banked local up axis on every
  step. Held vertical movement continues through RMB steering and LMB viewport
  gestures, matching existing physical flight behavior. Mouse release does not
  release an independently held key.
- Release is matched by physical identity when available, with logical identity
  otherwise. Modifier changes, rebinding, focus loss, focused controls, menus,
  modal/recovery actions and capture replacement discard holds. Busy/paused/offline
  guards clear them before normal movement processing can resume. OS echo cannot
  restart a cancelled hold.
- Valid saved assignments take priority over a missing/invalid action's default.
  This prevents the new E/Q defaults from stealing any existing saved Q/E binding,
  including actions earlier than roll in the catalog. Explicit saved duplicates
  retain deterministic last-catalog-entry handling. This is current preference
  normalization; no scientific formats or retired interfaces change.
- **W/A/S/D remain fixed physical keys**, as requested. The roll basis, local axis,
  **18°/s default**, shared speed slider, saved views and scientific data are
  unchanged. No new tooltips or movement-speed setting are introduced.

## Focused validation

Godot **4.7.2.stable.official.ed1daf0bf**, NVIDIA GeForce RTX 3070 Ti, Linux native
Forward+ and Compatibility, externally installed release templates. Roll/movement
runs use isolated preferences and small generated particle/field/mesh/mixed WVZ1
fixtures; every cell verifies unchanged fixture hashes and fresh-process restart.
[Validated source hashes](source-sha256.json) identify the tested runtime/harness;
[SHA-256 manifest](SHA256SUMS) covers this evidence.

| Check | Result | Evidence |
| --- | --- | --- |
| Roll/vertical/preferences headless | 2,367 assertions, 0 failures | [Result](headless/validation.json), [log](headless/roll.txt) |
| Native Forward+ | 2,927 assertions, 0 failures | [Result](source-forward/validation.json), [log](source-forward/roll.txt) |
| Native Compatibility | 2,927 assertions, 0 failures; known teardown diagnostics | [Result](source-compatibility/validation.json), [log](source-compatibility/roll.txt) |
| Linux release Forward+ | 2,927 assertions, 0 failures | [Result](package-forward/validation.json), [log](package-forward/roll.txt) |
| Linux release Compatibility | 2,927 assertions, 0 failures; known teardown diagnostics | [Result](package-compatibility/validation.json), [log](package-compatibility/roll.txt) |
| Connected navigation headless | 1,393 assertions, 0 failures | [Report](navigation-headless/camera-report.json), [log](navigation-headless/camera.txt) |
| Connected navigation Forward+ | 1,747 assertions, 0 failures | [Report](navigation-forward/camera-report.json), [log](navigation-forward/camera.txt) |
| Connected navigation Compatibility | 1,747 assertions, 0 failures | [Report](navigation-compatibility/camera-report.json), [log](navigation-compatibility/camera.txt) |
| Auto Orbit headless | 372 assertions, 0 failures | [Report](auto-orbit-headless/camera-report.json), [log](auto-orbit-headless/camera.txt) |
| Auto Orbit Forward+ | 372 assertions, 0 failures | [Report](auto-orbit-forward/camera-report.json), [log](auto-orbit-forward/camera.txt) |
| Auto Orbit Compatibility | 372 assertions, 0 failures | [Report](auto-orbit-compatibility/camera-report.json), [log](auto-orbit-compatibility/camera.txt) |
| Shortcut groups/focus headless | 306 assertions, 0 failures; restart/hash verified | [Result](shortcut-groups/validation.json), [log](shortcut-groups/native.txt) |
| Version identity | 2 tests pass; CLI v0.1.0.88 | [Log](version-tests.txt) |
| Python compilation, whitespace, source/evidence hashes, staged scope/size/credentials | Pass | Commands below and retained manifests |

The **14,075 roll/movement assertions** retain the previous roll-speed, basis,
input and scientific-state coverage and add E-up/Q-down, 12/120 Hz vertical
translation, opposite keys, Q/E conflict transfer with physically held keys,
draft dismissal, clear/defaults, mixed movement/roll, RMB/LMB continuity,
modifier/layout dispatch and physical release, saved-assignment priority, rebinding
and focus/modal/capture interruption. The actual process loop continuously moves
on the configured vertical key and stops on release. Restart restores **Q/E roll**,
**F10/F12 vertical movement** and **37°/s**, then proves Q/E cannot translate and
the rebound vertical keys do. These are isolated test bindings, not shipping defaults.

The retained default roll checks still reach 90° in five elapsed seconds and
measure approximately 90.12° after a real five-second hold, with zero position
drift. Source/world transforms, original scientific points, committed sample/time
state and fixture bytes remain unchanged. Connected navigation and Auto Orbit
cover the directly affected flight/takeover/custom-center paths. Their synthetic
movement events now include logical keycodes as well as physical positions,
matching real key events; physical-only W/A/S/D behavior is unchanged.

Dark/Light, normal 1440×900, compact native 970×600 and simulated 2× scaling
(1920×1200 / 960×600 logical) pass the existing measured panel/focus/text/footer
checks. The two additional rows consume scroll space in the existing group.
The current guides are synchronized; the original **82** evidence hashes and
the previous roll-speed report's **103** hashes remain unchanged.

## Visual evidence

After applying Q/E roll, [Dark](source-forward/vertical-qe-dark.png) and
[Light](source-forward/vertical-qe-light.png) show both vertical actions Unbound,
Q/E on the roll rows and the shared 18°/s speed value.

Default vertical rows are visible in the current layout captures:
[Dark normal](source-forward/speed-dark-normal.png),
[Light compact](source-forward/speed-light-compact.png),
[Dark 2×](source-forward/speed-dark-scale-2.png),
[Light 2×](source-forward/speed-light-scale-2.png).
F8/F9 roll assignments in those captures are validation preferences; the default
roll assignments remain Unbound. Equivalent packaged Q/E screenshots are retained.

## Investigations and limitations

The initial import regenerated four existing missing resize-script UID files;
subsequent warm imports pass. [Import log](investigation/initial-import.txt).
The first expanded fixture used an invalid menu property. The runner rejected
the script error even though a summary printed zero assertion failures:
[preliminary log](investigation/headless-preliminary.txt). The corrected test uses
the existing Navigate menu signal.

The new capture-replacement assertion failed before vertical holds were cleared
at `_open_scene()` entry: [headless](investigation/headless-final-preliminary.txt),
[Forward+](investigation/forward-preliminary.txt). Adding the new held-state cleanup
fixes the failure; complete final runs above pass. Earlier passing runs preceding
mouse-continuity and saved-default refinements are superseded by the final reports.
No preliminary run is counted as final validation.

Compatibility retains the previously documented exact **ten** texture-release
diagnostics after the main completed summary. Both final restart runs have no
cleanup diagnostics. The unchanged runner allows the historical ten-main/two-
restart pattern only at that completed-summary stage, if present, and keeps all
messages in logs/JSON. Accepted-main lifecycle probes remain in the
[initial investigation](../README.md#investigations-and-limitations). This is a
known harness teardown limitation, not a clean Compatibility shutdown claim.
Other errors/warnings, failed assertions and incomplete runs remain failures.

Physical Nordic/KDE/Wayland keyboard and window-manager behavior, physical mixed-DPI
or 4K comfort, production captures and long sessions remain owner checks. W/A/S/D
were deliberately kept physical; assigning another action to one of those keys
does not disable its physical translation. The resolved conflicts are among
configured actions, including E/Q vertical movement and roll.

Encoded MP4/numerical export pipelines were not rerun. Their sampling, timestamps,
schemas and output code are untouched; retained offline full-camera-transform
checks and unchanged source/world/sample state do not certify new encoded output.

The normal, uninstrumented review package is
`/tmp/wavez-331-vertical-review/owner-package-validated/WAVEZ.x86_64`, with adjacent
`WAVEZ.pck`. [Metadata/hashes](owner-package-build.json), [import](owner-package-import.txt),
[export](owner-package-export.txt). Binaries, captures, profiles and caches stay
outside Git; temporary unrelated generated UID files are excluded.

## Reproduction and owner review

```sh
python tools/validate_camera_roll.py --godot /path/to/godot --renderer headless --output-dir /tmp/vertical-headless
python tools/validate_camera_roll.py --godot /path/to/godot --renderer forward_plus --output-dir /tmp/vertical-forward
python tools/validate_camera_roll.py --godot /path/to/godot --renderer gl_compatibility --output-dir /tmp/vertical-compatibility
python tools/validate_camera_roll.py --godot /path/to/godot --renderer forward_plus --package --output-dir /tmp/vertical-package-forward
python tools/validate_camera_roll.py --godot /path/to/godot --renderer gl_compatibility --package --output-dir /tmp/vertical-package-compatibility
python tools/validate_camera_tumble.py --godot /path/to/godot --suite navigation --renderer headless --output-dir /tmp/vertical-navigation-headless
python tools/validate_camera_tumble.py --godot /path/to/godot --suite navigation --renderer forward_plus --output-dir /tmp/vertical-navigation-forward
python tools/validate_camera_tumble.py --godot /path/to/godot --suite navigation --renderer gl_compatibility --output-dir /tmp/vertical-navigation-compatibility
python tools/validate_camera_tumble.py --godot /path/to/godot --suite auto-orbit --renderer headless --output-dir /tmp/vertical-auto-headless
python tools/validate_camera_tumble.py --godot /path/to/godot --suite auto-orbit --renderer forward_plus --output-dir /tmp/vertical-auto-forward
python tools/validate_camera_tumble.py --godot /path/to/godot --suite auto-orbit --renderer gl_compatibility --output-dir /tmp/vertical-auto-compatibility
python tools/validate_keyboard_shortcuts.py --godot /path/to/godot --renderer headless --group-only --output-dir /tmp/vertical-groups
python -m unittest tests.test_application_version -v
python -m py_compile tools/validate_camera_roll.py tools/validate_camera_tumble.py tools/validate_keyboard_shortcuts.py
git diff --check
```

1. Launch the normal package and confirm Help → About shows **v0.1.0.88**.
2. Open Edit → Preferences → Keyboard Shortcuts → Navigation. In a fresh profile,
   confirm **Move Camera Up = E**, **Move Camera Down = Q**, both roll actions
   Unbound and Camera Roll Speed **18°/s**. Fly up/down with E/Q; release and hold
   both to check stop/cancellation. Movement follows the current camera up axis.
3. Assign **Q to Roll Left** and **E to Roll Right**. Confirm Down/Up become
   Unbound in the draft. Apply, close and hold Q/E: each banks slowly without
   vertical motion. At 18°/s, a quarter turn takes about five seconds.
4. Rebind Up/Down to unused keys outside W/A/S/D. Test held flight while rolling
   and through RMB steering/LMB gestures. Test a modifier chord and key release.
   Reopen and restart; Q/E must still only roll and the new keys must translate.
5. Verify Clear, conflict transfer, Reset Defaults and Cancel/Escape/X drafts.
   Reset Defaults stages E-up/Q-down, Unbound roll and 18°/s; it activates on Apply.
   Test focused fields, menus/dialogs, alt-tab and opening another capture during
   a hold. Movement must stop and remain stopped until a fresh press.
6. Repeat Dark/Light, compact/fullscreen and the owner's keyboard/DPI setup.
   Check W/A/S/D, movement-speed shortcuts, Auto Orbit takeover/custom-center
   resume, reset, Frame Scene and saved views in representative particle, field,
   mesh and mixed captures. Assess physical feel before final acceptance.

The existing PR remains for owner review. No merge, issue closure, auto-merge or
manual Project status change is performed.
