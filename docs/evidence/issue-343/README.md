# Issue #343 — RMB free-look and camera roll

Candidate **v0.1.0.94**, pending owner review. Issue #343, **NAV — Allow camera
roll shortcuts while RMB free-look is held**, was the top/only Ready issue in
Wavez Development. The exact owner-created, GitHub-linked branch was already
checked out, clean and based on accepted main:
`343-nav-allow-camera-roll-shortcuts-while-rmb-free-look-is-held`.
HEAD, main and origin/main initially matched `ccf90e47d4a1908ab67b6d1b30f9196508445b0e`
(v0.1.0.93), the owner's merged PR #344. Fetch/prune confirmed synchronization;
no completed #340 local branch remained. No branch was created, renamed or
switched, and main was not edited.

## Investigation and implementation

Accepted main reproduced the reported incompatibility. The new focused input
regression ran against its unchanged production camera implementation before
editing it: [196 checks with 120 failed assertions](baseline-headless.json),
[original error log](baseline-headless.log). These are related assertion failures
from the same missing coexistence behavior, not 120 separate product defects.

RMB mouse-motion handling consumes only mouse events; roll key events still reach
the existing editable-shortcut dispatcher. Three guards/cleanup operations caused
the failure:

1. `_start_camera_roll()` rejected `_camera_dragging()`, which includes RMB.
2. `_update_camera_roll()` cleared held keys while `_camera_dragging()` was true.
3. RMB press used `_clear_manual_navigation(false)`, clearing roll pressed first.

The focused change makes the first two roll guards reject LMB `dragging`, while
allowing `free_look_dragging`. An optional `clear_roll` argument preserves roll
only when RMB begins. All other manual-navigation cleanup calls still discard it
by default. RMB continues clearing/blocking held orbit. LMB takeover, focus loss,
menus/dialogs/Preferences, inspection work, changed modifiers/bindings and capture
replacement retain their cleanup/suppression. No input-dispatch redesign, new
bindings, sensitivity change, camera formula or scientific-data transformation
was introduced.

Either roll direction now works whether roll or RMB is pressed first. Releasing
the roll key stops banking while steering continues; releasing RMB restores the
cursor and preserves an independently held roll. Repeated RMB press/release
retains the hold without a jump. Opposite directions cancel and releasing one
resumes the other. Banking uses the existing applied 5–90°/s speed, RMB retains
0.003 radians/pixel and local axes, and invert-Y remains an LMB preference.
Translation and translation-speed actions retain their independent behavior.

## Risk-based validation

The change affects input gates and held camera state, so testing covers those
paths, connected roll/steering/cursor/shortcut guards, and compiled Linux runtime
behavior on both renderers. No format, science pipeline, playback/cache core,
renderer/shader or video implementation changed, so their unrelated suites and
production simulations were not rerun. All inputs are small synthetic WVZ1.

| Check | Result |
| --- | --- |
| Focused source, headless | **205 checks PASS**, [report](headless.json) |
| Focused source, Forward+ | **230 checks PASS**, [report](source-forward.json) |
| Focused source, Compatibility | **230 checks PASS**, [report](source-compatibility.json) |
| Focused Linux release, Forward+ | **230 checks PASS**, [report](package-forward.json) |
| Focused Linux release, Compatibility | **230 checks PASS**, [report](package-compatibility.json) |
| Existing roll/shortcut/vertical/state suite, headless | **2,366 checks PASS**, [report](full-roll-headless.json) |
| Connected steering/orbit/translation/cursor suite, headless | **1,393 checks PASS**, [report](navigation-headless.json) |
| Application version | **2 unit tests OK**, [log](version.log) |
| Python compilation / final import / whitespace | Modified validator compiles; [import](import-final.log) is clean; source/documentation `git diff --check` passes |

The focused suite sends keys/buttons/motion through `Window.push_input`, so it
exercises actual `_input` → GUI → `_unhandled_input` dispatch rather than directly
calling the roll-start function. It measures the full basis against independently
composed camera-local roll/yaw/pitch matrices for both directions, both press
orders, three roll speeds and multiple delta intervals, from a tilted view.
Position, navigation target/radius, geometry transforms, source positions,
committed sample, layer state and paused playback are checked separately.

Coverage includes independent key/RMB releases, repeated gestures, key echoes,
opposite holds, LMB takeover, orbit priority, W/A/S/D/Q/E translation on banked
axes, translation-speed shortcuts, Auto Orbit takeover, invert-Y invariance,
modifier/physical releases, remapped/stale/unbound keys, typing and focused
controls, Preferences/menus/orbit editor, inspection/offline guards and window
focus loss. Real process-loop holds verify continuous roll and prompt key-up
while accepting mouse steering. Native checks verify cursor hidden/restored state.

Every focused run starts a fresh process again to verify persisted Q/E roll,
rebound vertical actions and a nondefault 37°/s applied speed. The unchanged
full suite also checks normal roll, frame-rate-independent angles, science/world
state, framing/restore, shortcut editing and vertical-movement guards. Connected
navigation retains the existing LMB/orbit, wheel, steering and cursor contract.
All generated source hashes remain unchanged.

Release builds include the production Main entry with the test as an autoload.
Their staging checkout is deleted before launch; runtime cwd is unrelated,
PYTHONPATH is empty and PATH excludes the external editor. The release checks
consume the compiled executable/PCK, and fresh-process restart uses the same
resources. The focused #343 runs are strict: there are **no engine/script
errors or warnings** and no teardown exceptions applied. Both native/source and
package roll/restart logs are retained. The older full-suite validator's existing
Light-theme teardown allowance remains for its unrelated mode; the focused
mode does not inherit it, and all current focused diagnostic lists are empty.

## Failed attempts, limits and preservation

The first baseline attempt stopped during editor import: Godot recreated four
missing UID files from its local cache and emitted warnings. The [original import
log](initial-import.log) is retained. A clean second import ran the baseline
assertions above. Those incidental sidecars belong to untouched scripts and are
not included as unrelated changes. No warning was hidden to obtain a pass.

The baseline's 120 failures were resolved by the three gate/cleanup changes.
There are no unresolved candidate failures in the executed suites. Synthetic
input and focus signals verify software event routing and state guards; they do
not establish physical keyboard/mouse, compositor or human feel. Actual physical
KDE input, Nordic-layout hardware, mixed DPI/4K, long sessions, other graphics
hardware and other operating systems remain owner/unrun checks. Native cursor
checks establish engine mouse mode, not a recorded physical pointer-position
measurement. Separate actual-input inspection remains advisable before release.

Package tests remove staging and use an isolated runtime path; this does not
claim machine-wide Godot/Python uninstallation. No public release/distribution
license audit, tag or Release is performed. Existing third-party runtimes remain
external. Passing automated checks does not mark owner acceptance.

Current navigation, shortcut, status and evidence-index docs were synchronized.
Current status now records the owner-merged #340/PR #344 baseline; its historical
review text and all earlier issue evidence are preserved without rewriting.

## Reproduction and exact owner checks

From the repository root, use fresh output directories:

```sh
python tools/validate_camera_roll.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/rmb-source --renderer forward_plus --rmb-only
python tools/validate_camera_roll.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/rmb-package --renderer forward_plus --package --rmb-only
```

Repeat with `gl_compatibility` and new paths. The existing full roll and navigation
checks use `tools/validate_camera_roll.py --renderer headless` without `--rmb-only`
and `tools/validate_camera_tumble.py --renderer headless --suite navigation`.

A normal-entry local Linux package, without the validation autoload, is available
at `/home/Nozba/Codex/Wavez/camera-343-review/WAVEZ.x86_64`; keep its PCK beside it.
[Build identity/hashes](review-package-build.json) identify v0.1.0.94. To reproduce:

```sh
python tools/package_linux.py --godot /absolute/path/to/Godot \
  --output-dir /tmp/wavez-rmb-owner-review
```

1. Launch the normal-entry executable from an unrelated directory, confirm
   Help → About shows v0.1.0.94, and open a small ordinary `.wvz`. Enable Free
   Camera. In Keyboard Shortcuts → Navigation, bind Roll Camera Left/Right to
   two unused keys, confirm default 18°/s or select a clear test speed, Apply,
   then close Preferences before testing navigation.
2. Hold RMB and steer horizontally/vertically. Press/hold each roll direction:
   banking and both steering axes must work together, with the cursor hidden.
   Release only the roll key: banking stops and steering remains. Release RMB:
   the cursor returns and the pose does not jump.
3. Hold roll first, then press/steer/release RMB while keeping roll held. Roll
   must continue across RMB release. Repeat several times in both directions.
   Hold both roll keys: they cancel; release one and the other resumes. Release
   all keys and confirm no stale motion.
4. Check W/A/S/D and configured Up/Down while steering/rolling, translation-speed
   controls and the applied roll-speed slider. Verify without RMB that normal
   roll is unchanged. Rebind roll (including a modifier chord), restart the
   application, and repeat; no new defaults should be assigned.
5. Focus a typing control, open Preferences/a menu/orbit editor, or Alt-Tab during
   the hold. Roll must stop, old holds must not resume after returning, and focus
   cleanup must restore the cursor. Verify key-up before/after RMB-up in each order.
6. Start LMB tumble during RMB/roll: it retains priority and ends those holds.
   Verify ordinary LMB tumble/invert-Y, held orbit, wheel zoom, Auto Orbit takeover
   and Frame/Reset. Scientific objects and playback must remain unchanged.
7. Repeat on Forward+ and Compatibility, on the owner's physical desktop and
   intended release package. Review comfort/long-session/platform limitations
   before acceptance. Owner controls merge, issue closure and Project completion.
