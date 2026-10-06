# Issue #261 — viewport cursor inactivity

Candidate **v0.1.0.54**, pending owner review. On 2026-10-06, #261 was the sole
Ready item in the Wavez Development Project. Its owner-created
`261-ux-viewport-auto-hide-mouse-cursor-after-25-seconds-of-viewport-inactivity`
branch was checked out clean at accepted `main` `62d70dc`. The required #263
RMB cursor behavior was owner-merged through PR #264 and present in that base.
The prior #263 issue branch was already absent locally and remotely after
pruning; no owner-acceptance record was added to a separate branch.

## Change

A single monotonic inactivity deadline hides the pointer after 2.5 seconds
without mouse interaction inside the scientific viewport. Any mouse motion,
button input, wheel or double-click resets the deadline and restores the
pointer. The existing shell viewport boundary excludes chrome and Window
popups; the Control-based Keyboard Shortcuts and orbit-center editors are also
excluded. Focus loss, viewport exit, dialog openings and fullscreen exit
restore visibility. Held mouse input and dragging prevent idle hiding.

RMB free-look retains its accepted immediate hide. While RMB steering is
active, it wins over the idle rule; release restores the cursor and starts a
new 2.5-second interval. Hidden cursor mode preserves pointer location and
normal mouse motion. Camera, edge-reveal timing, scientific state and export
behavior were not changed.

## Focused validation

Godot 4.7.2 on the local Linux desktop, using tiny generated particle, volume,
mesh and mixed WVZ1 fixtures. The existing navigation suite gained deterministic
deadline, input, chrome, dialog, focus, fullscreen and edge-reveal checks. Each
run verified unchanged fixture hashes.

| Check | Result |
|---|---|
| Headless navigation and state | [1,393 checks passed](navigation-headless.json) |
| Native Forward+ | [1,747 checks passed](navigation-forward.json) |
| Native Compatibility | [1,747 checks passed](navigation-compatibility.json) |

Native checks assert hidden/visible cursor modes and unchanged desktop pointer
position. Headless cannot expose hidden cursor mode, so that run checks state
and transitions. Both application-version unit tests passed; the CLI reported
`v0.1.0.54`, and `git diff --check` passed.

The first editor import stopped on five previously missing, unrelated UID
sidecars regenerated from cache. The warmed rerun passed. A first headless
candidate run found that the Control-based Keyboard Shortcuts editor was not
excluded by the Window-popup boundary; the guard was corrected before the
passing runs above. These generated sidecars are not part of this issue.

Automated checks use simulated input and deterministic time advancement.
Physical 2.5-second timing under the owner's compositor, real alt-tab, native
file-dialog behavior, and mixed-display pointer feel remain owner checks. No
production capture, package build, or unrelated full-suite regression was run
for this local cursor/UI change.

Reproduce with a new output directory per command:

```sh
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer headless --output-dir /tmp/wavez261-headless
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer forward_plus --output-dir /tmp/wavez261-forward
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer gl_compatibility --output-dir /tmp/wavez261-compat
python -m unittest tests.test_application_version
python tools/application_version.py
```

## Owner verification

Follow the exact [viewport cursor checklist](../../VIEWPORT_CURSOR.md#owner-verification)
on the preferred KDE/Wayland desktop. In particular, verify real timing,
pointer location, UI exclusion, edge reveal, alt-tab recovery and RMB priority
in both native renderers before acceptance.

Stop for owner review. The PR is not an acceptance or merge record.
