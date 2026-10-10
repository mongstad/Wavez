# Issue #331 — Camera-local roll

Candidate **v0.1.0.88**, pending owner review. Issue #331 was the sole/top Ready
item on Wavez Development when selected. The existing linked branch is
`331-ux-nav-add-configurable-roll-camera-leftright-hotkeys-for-free-flight-navigation`.
Its clean baseline matched accepted `main` **c33ff2b899330020871792757f5cbfffeedf35ac**,
owner-merged PR #332, build 87. No additional predecessor is specified by #331.
The accepted full-basis navigation, editable shortcuts and observer-plane orbit
contracts are consumed by this implementation.

## Change and measured contracts

- Two independent Navigation actions, **Roll Camera Left** and **Roll Camera Right**,
  default to Unbound. Existing bindings and editor behavior remain intact.
- Held roll uses elapsed time at 90°/second about local camera Z, with an
  orthonormalized basis. Left banks camera up toward camera left; right mirrors it.
  No Euler roll parameter or scientific/world transform is introduced.
- Camera position, forward direction, navigation target and radius remain fixed.
  The measured maximum position error is **0**; maximum forward-axis error across
  ±90°/180°/360° checkpoints is **5.04003025980637e-7**. Per-frame checks also enforce
  determinant within 1e-5 of one and forward error below 1e-5.
- Translation/RMB steering consume the rolled local axes. Frame Scene, saved
  views, capture reopening and export-state application retain the basis.
  Reset Camera intentionally restores the default orientation. Auto Orbit
  takeover follows existing manual steering; roll alone does not enable a
  disabled Free Camera when Auto Orbit is already off.
- Simultaneous held manual orbit carries the current bank forward. After a custom
  orbit-center Apply, camera-only roll rebases the orbit's starting basis while
  retaining its Apply-time observer plane, center and distance. Resumed Auto Orbit
  and fractional zoom keep that plane and bank.
- Release, modifier changes, focus loss, focused text/numeric/button controls,
  mouse gestures, modal editors, inspection work, rebinding and capture replacement
  stop pending roll. Both directions cancel until one is released.
- Shortcut persistence, conflict transfer, applied Clear, draft Cancel/X/Escape,
  Reset Defaults, failed persistence and fresh-process restart are covered.
  Dark/Light labels use the existing Navigation font/color resources.
- Original fixture bytes, scientific coordinates, world/guide/layer transforms,
  committed samples and scene settings remain unchanged by roll. Offline viewers
  apply the existing full-transform snapshot; preference bindings are not added to
  scientific captures, recipes or export schemas.

## Focused validation

Godot **4.7.2.stable.official.ed1daf0bf**, NVIDIA GeForce RTX 3070 Ti,
Vulkan Forward+ / OpenGL Compatibility. Source and Linux release-template tests
use generated, small particle, field, mesh and combined WVZ1 captures and isolated
preferences. Every matrix cell includes a fresh-process restart and byte hashes.
The [validated source hashes](source-sha256.json) identify the implementation and
focused harness files; [SHA-256 manifest](SHA256SUMS) covers retained evidence.

| Check | Result | Evidence |
| --- | --- | --- |
| Roll headless | 2,168 assertions, 0 failures | [Result](headless/validation.json), [log](headless/roll.txt) |
| Roll native Forward+ | 2,709 assertions, 0 failures | [Result](source-forward/validation.json), [log](source-forward/roll.txt) |
| Roll native Compatibility | 2,709 assertions, 0 failures; baseline GL teardown diagnostics | [Result](source-compatibility/validation.json), [log](source-compatibility/roll.txt), [restart](source-compatibility/restart.txt) |
| Roll Linux release Forward+ | 2,709 assertions, 0 failures | [Result](package-forward/validation.json), [log](package-forward/roll.txt) |
| Roll Linux release Compatibility | 2,709 assertions, 0 failures; baseline GL teardown diagnostics | [Result](package-compatibility/validation.json), [log](package-compatibility/roll.txt), [restart](package-compatibility/restart.txt) |
| Connected navigation headless | 1,393 assertions, 0 failures | [Report](navigation-headless-final/camera-report.json), [log](navigation-headless-final/camera.txt) |
| Connected navigation Forward+ | 1,747 assertions, 0 failures | [Report](navigation-forward-final/camera-report.json), [log](navigation-forward-final/camera.txt) |
| Connected navigation Compatibility | 1,747 assertions, 0 failures | [Report](navigation-compatibility/camera-report.json), [log](navigation-compatibility/camera.txt) |
| Empty-view/Auto Orbit pacing, each native renderer | 4 assertions, 0 failures; draws 0 → 60 → 0 | [Forward+](idle-forward.txt), [Compatibility](idle-compatibility.txt) |
| Application-version contract | 2 Python tests passed; CLI v0.1.0.88 | [Log](version-tests.txt) |
| Python compilation, whitespace | Passed | `python -m py_compile tools/validate_camera_roll.py`; `git diff --check` |

The 13,004 roll checks cover both directions, 90°/180°/360°, 12/120 Hz stepping,
release/OS repeat, simultaneous directions/orbit, rolled translation/steering,
presets/export snapshots, reset/frame/capture change, custom-plane resume and
zoom, all input guards, shortcuts, theme and fullscreen. Connected navigation
covers the unchanged LMB/RMB/orbit/wheel/saved-state paths. The small idle test
covers the shared pacing expression. No unrelated full-suite or production
scientific run was needed.

## Visual evidence

[Dark shortcuts](source-forward/shortcuts-dark.png) and
[Light shortcuts](source-forward/shortcuts-light.png) show both separate roll rows
without a transient overlay. The illustrative F8/F9 assignments are validation
preferences, not shipping defaults.

Native Forward+: [0°](source-forward/bank-0.png),
[90°](source-forward/bank-90.png), [180°](source-forward/bank-180.png),
[360°](source-forward/bank-360.png). The tests also measure a fixed world landmark's
projection against screen-space rotation at each checkpoint. The backdrop crop
is byte-identical through the banks. The 360° rendered round trip differs only
by at most one RGB level in a small number of pixels due to floating-point basis
accumulation; see [pixel comparison](visual-comparison.json). Package and
Compatibility views are retained in their result directories.

## Investigations and limitations

The first editor import hit sandbox socket restrictions and generated missing UID
warnings from older scripts. The authorized rerun imported cleanly; incidental
unrelated UID files were excluded. [Initial log](investigation/initial-sandbox-import.txt).

The original connected navigation harness printed one failed real-process hold
assertion: [candidate headless](investigation/navigation-original-candidate-headless.txt),
[candidate Forward+](investigation/navigation-original-candidate-forward.txt), and
[accepted-main headless](investigation/navigation-original-baseline-headless.txt).
Waiting four process frames for deferred recipe/editor work before pressing the
key fixes the fixture, without changing production behavior. The same corrected
fixture passes on [accepted main](investigation/navigation-baseline-settled.json)
and in all candidate renderer runs above.

The idle harness still expected startup `playing = true`, an obsolete assertion
under the accepted paused-start contract. Its initial run already measured the
correct redraw sequence 0/60/0 but failed that startup assertion:
[initial log](investigation/idle-original-candidate.txt). Only the assertion was
corrected to require no source and paused startup. Runtime startup/pacing defaults
are unchanged.

Compatibility prints exactly ten `Texture with GL ID …: leaked 349524 bytes`
diagnostics after the main test's completed summary, and two after its restart
summary. Accepted `main` reproduces the same counts with the matching five
export-style viewer lifecycles and fresh-process Light-theme validation node:
[ten-message baseline](investigation/accepted-main-five-viewers.txt),
[two-message baseline](investigation/accepted-main-restart-node.txt),
[probe source](investigation/roll_cleanup_probe.gd.txt),
[node probe](investigation/roll_restart_node_probe.gd.txt),
[probe entry](investigation/run_roll_restart_probe.gd.txt).
A final native frame flush did not remove them:
[before](investigation/compatibility-before-flush.txt),
[after](investigation/compatibility-after-flush.txt).
The runner retains the complete messages in logs and result JSON, and permits only
those exact counts/patterns after the completed summary. Other warnings/errors,
incomplete runs and assertion failures still fail validation. Forward+ completes
without these diagnostics. This is a baseline harness teardown limitation, not a
clean Compatibility shutdown claim.

Inputs are synthetic Godot events. Physical keyboard feel and OS-reserved chords,
owner KDE/Wayland interaction, mixed-DPI/4K comfort, production captures and long
sessions remain owner checks. Actual MP4/numerical export pipelines were not
rerun: their timing, sampling, format and rendering code is unchanged. Export
coverage here proves rolled full-transform application in offline viewers and
unchanged source/world/sample state; it does not certify a new encoded-video run.

The normal uninstrumented owner package is external at
`/tmp/wavez-331-review/final-owner-package/WAVEZ.x86_64` with adjacent `WAVEZ.pck`.
[Build metadata/hashes](owner-package-build.json),
[import](owner-package-import.txt), [export](owner-package-export.txt).
No Godot/FFmpeg executable or generated capture is committed.

## Reproduction and owner review

```sh
python tools/validate_camera_roll.py --godot /path/to/godot --renderer headless --output-dir /tmp/roll-headless
python tools/validate_camera_roll.py --godot /path/to/godot --renderer forward_plus --output-dir /tmp/roll-forward
python tools/validate_camera_roll.py --godot /path/to/godot --renderer gl_compatibility --output-dir /tmp/roll-compatibility
python tools/validate_camera_roll.py --godot /path/to/godot --renderer forward_plus --package --output-dir /tmp/roll-package-forward
python tools/validate_camera_roll.py --godot /path/to/godot --renderer gl_compatibility --package --output-dir /tmp/roll-package-compatibility
```

1. Launch the normal package and confirm **Help → About = v0.1.0.88**.
2. Open Keyboard Shortcuts. In a fresh profile both roll rows should be Unbound.
   Assign unused keys to each, Apply and close. With Free Camera on, hold each,
   release, hold both and release one. At 90°/second, one second banks 90° and four
   seconds completes a turn. The camera should keep its position and heading.
3. Bank 90°, fly W/A/S/D/Q/E and steer with RMB. Check LMB tumble, wheel zoom and
   held orbit too. Enable Auto Orbit then roll: it should turn off immediately
   and stay off after release. With both Auto Orbit and Free Camera off, roll
   should not enable Free Camera.
4. Apply an orbit center from the current view, roll, and re-enable Auto Orbit.
   Its chosen observer plane/center/distance must remain, with no bank snap.
   Zoom out/in with fractional wheel movement. Check editor Apply/Cancel,
   Frame Scene, Reset Camera, capture reopening and a saved banked view preset.
5. Rebind/Clear/conflict-transfer; Cancel/X/Escape should discard only drafts.
   Restart to verify saved assignments. Try text/numeric focus, shortcut/orbit
   editors, menus and alt-tab during a hold. Pending roll must not resume.
6. Repeat Dark/Light, fullscreen, Forward+/Compatibility and representative
   particle, field, mesh and mixed captures. Review a fixed-camera image/video
   and numerical export; scientific coordinates, interval/timing and source data
   must remain unchanged. Assess physical key feel before acceptance.

Current guides were updated with roll behavior and build status. Earlier issue
review evidence remains untouched. Implementation and this evidence remain
pending owner acceptance; no merge, manual closure or Project change is performed.
