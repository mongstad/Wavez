# Issue #263 — RMB free-look cursor visibility

Candidate **v0.1.0.53**, pending owner review. On 2026-10-06, #263 was the
only issue in the Wavez Development Project's Ready lane. The owner-created
`263-ux-nav-hide-mouse-cursor-while-rmb-free-look-steering-is-active` branch
was checked out clean at accepted `main` `5244bab`. Required predecessor #258
was owner-merged in PR #262 and present at that commit. The completed #258
branch was already absent locally and remotely after pruning.

## Change

The existing RMB free-look state now owns the cursor mode. A valid press in the
scientific viewport uses Godot's hidden mode; release restores visible mode.
Hidden mode leaves mouse motion and pointer location intact. The same cleanup
handles focus loss, LMB interruption, menus, Keyboard Shortcuts, Tools and
export dialogs, inspection capture, fullscreen transitions, and viewer exit.
No steering math, sensitivity, translation, scientific transform, or idle cursor
timeout changed. Issue #261 remains separate and was Backlog at this review.

## Focused validation

Godot 4.7.2 on the local Linux desktop, using tiny generated particle, volume,
mesh and mixed WVZ1 fixtures. The existing navigation suite was extended with
cursor mode and interruption checks. Each run verified unchanged fixture hashes.

| Check | Result |
|---|---|
| Camera/navigation suite, headless | [1,364 checks passed](navigation-headless.json) |
| Same suite, native Forward+ | [1,713 checks passed](navigation-forward.json) |
| Same suite, native Compatibility | [1,713 checks passed](navigation-compatibility.json) |

The application-version unit tests passed (2 tests), the CLI reported
`v0.1.0.53`, and `git diff --check` passed.

Native checks assert immediate hide, continued steering at fixed camera
position, immediate release, unchanged desktop pointer position, LMB/wheel/key
non-triggers, focus and menu/dialog recovery, fullscreen transitions and
double-click exit. The existing suite also checks all movement axes, orbit
shortcuts, Auto Orbit, camera-state persistence and unchanged scientific/world
transforms across the four fixture types. Godot's headless display server does
not expose hidden cursor mode; that run checks steering state and cleanup only.

The first sandboxed editor import could not open its local socket. An authorized
rerun completed. The import also regenerated five previously missing, unrelated
UID sidecars from cache; they were not included in this issue. Physical cursor
feel, compositor behavior during a real alt-tab, and actual menu/dialog clicks
while RMB is held remain for owner verification. No production capture, package
build or unrelated regression suite was run for this local input change.

Reproduce with a new output directory per command:

```sh
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer headless --output-dir /tmp/wavez263-headless
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer forward_plus --output-dir /tmp/wavez263-forward
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer gl_compatibility --output-dir /tmp/wavez263-compat
```

## Owner verification

1. In a scene, hold RMB over the scientific viewport. Confirm immediate cursor
   hide and normal two-axis steering. Release RMB and confirm immediate return
   at the same position, without a camera or pointer jump.
2. Repeat in fullscreen. Leave fullscreen and double-click back to windowed
   mode after steering. Check that the cursor is visible when navigation stops.
3. During a held RMB gesture, alt-tab and open File, Navigate, Keyboard
   Shortcuts, a Tools dialog and Video Export. Confirm none leaves the pointer
   hidden. LMB, wheel, orbit keys and W/S/A/D/Q/E alone should never hide it.
4. Compare representative particle, field, mesh and mixed scenes in Forward+
   and Compatibility. Confirm camera response and scientific content are unchanged.

Stop for owner review. The PR is not an acceptance or merge record.
