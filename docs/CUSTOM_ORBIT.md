# Custom orbit setup

Issue #120 adds an explicit local camera pivot/radius, **pending owner UX review**.
The implementation starts from accepted `main` `1a60774` on the owner's new
issue-linked branch. Candidate application identity: **v0.1.0.12**.

## Interaction

1. Enable **Navigate → Free camera** and move toward the desired region.
2. Hold **RMB inside the viewport**. The cursor is captured for continuous
   mouse-look. A temporary violet pivot marker, two projected world-space
   radius rings and a compact radius readout appear.
3. Move the mouse to look; continue flying with **WASD / Q E**. The proposed
   center is always `camera_position + camera_forward * radius`. No object
   picking, probe state or surface hit is involved.
4. Scroll to change the radius multiplicatively: wheel up divides by 1.2;
   wheel down multiplies by 1.2. **Shift-wheel** uses 1.02 for finer adjustment.
   The displayed radius is in scene coordinates. The range is `1e-6..1e12`,
   with a coordinate-dependent lower bound to retain a representable float32
   displacement at remote positions. Existing camera clipping planes still apply.
5. Release **RMB** to commit the pivot and radius without changing the visible
   camera pose. The temporary guide immediately disappears.

The configured camera retains the default navigation model at its new position
and scale. Normal left drag tumbles around the local center; the wheel zooms;
Free-camera WASD/Q/E translates **both camera and orbit center together**, keeping
their relative distance. The camera is not locked to an immovable custom target.
This follows the owner's clarification during implementation. Custom zoom accepts
the wider radius range, and translation speed scales with radius so sub-unit
targets remain navigable. The normal camera's existing limits/speed are unchanged.
Auto orbit remains independently controlled by **O** or the Navigate menu.

**R** abandons a pending proposal and runs the existing Reset Camera action.
**F / Frame scene** likewise replaces the custom camera with existing framing.
Neither action changes fullscreen mode. **Esc** keeps its existing fullscreen
recovery behavior and is not assigned to orbit cancellation. Focus loss abandons
the draft and restores the pre-setup camera and pointer mode. Releasing RMB over
application chrome still ends a gesture started in the viewport.

## State and output boundaries

Only RMB release commits the proposal. Draft look/translation affects the live
preview pose but never updates the committed target, distance or serialized
camera. Auto orbit is suspended during setup; playback and scientific settings
retain their existing state.

Portable view presets retain the generic target, distance, yaw/pitch and transform,
plus a `custom_orbit` boolean selecting scale-aware navigation. No capture IDs,
probe identities or scientific source bindings are added. A preset saved during
setup uses the pre-setup committed camera. Loading a valid preset abandons a draft.

Normal PNG capture and selection-aware inspection PNG capture abandon any draft
before rendering, restoring the committed view. The guide is not scientific
geometry, and offline video workers never construct it, including when UI overlays
are requested. Video continues to use the existing locked-transform/world-Y-orbit
sampler with the committed camera state. Source opening also abandons a draft.
The guide redraws only on setup input/resize; it adds no continuous animation.

## Validation and review limits

The focused runner is `tools/validate_orbit_setup.py`. It exercises particles,
fields, meshes and mixed SIMSCP4 fixtures on both supported native renderers:
two off-center targets, all six movement keys during/after setup, look, fine and
large radius changes, repeated commits, normal drag/zoom, preset round trips,
deterministic orbit equality, reset/frame/focus-loss/release routing, fullscreen
recovery, real input dispatch and stationary redraw behavior. It compares the
actual PNG pixels captured during a draft against the committed view, runs locked
and orbit videos with/without UI, and hashes the complete fixture files.

Final results: **31,374 validation assertions**, **two Python version tests**,
and **eight custom-camera video exports**, all passing. Both final imports and
focused native logs are clean. Complete synthetic source files retained their
SHA-256 hashes. The draft/committed PNG comparison is pixel-exact on each renderer.

| Suite | Forward+ | Compatibility |
| --- | ---: | ---: |
| Custom orbit interaction, output and compact layout | 438 | 438 |
| Existing continuous camera tumble | 13,044 | 13,044 |
| Portable view presets | 838 | 778 |
| Viewer shell | 667 | 667 |
| Edge reveal / fullscreen | 210 | 210 |
| Render pacing | 290 | 290 |
| Current scientific video regression | 235 | 225 |

Each renderer passed 34 idle phases with stable pixels. Forward+ recorded no
additional draws; Compatibility recorded at most one additional draw in a phase,
within the existing test bound of four. The custom suite separately checks idle
after commit and during a stationary preview. Its four exports per renderer use
locked/orbit cameras, each with UI inclusion off/on.

[Machine-readable evidence](evidence/issue-120/summary.json) includes the full
counts, idle-phase measurements and development failures that were resolved before
the clean final runs. [Forward+](evidence/issue-120/forward_plus-orbit.json) and
[Compatibility](evidence/issue-120/gl_compatibility-orbit.json) contain the focused
reports and complete fixture hashes. Native preview images cover
[dark](evidence/issue-120/forward_plus-dark.png),
[bright](evidence/issue-120/forward_plus-bright.png) and
[1024×640](evidence/issue-120/forward_plus-compact.png) layouts; corresponding
Compatibility images are in the same evidence directory.

Automated checks do not establish owner acceptance of the control feel. The
tested desktop is Linux, Godot 4.7.2, NVIDIA RTX 3070 Ti. Physical 4K/KDE scaling,
other GPUs/platforms, production captures and long-session ergonomics require
owner review; scientific simulations were not rerun. There was no separate
accepted-main pixel differential run; the existing video determinism checks and
the draft/committed PNG equality tests passed. Earlier issue reports/evidence were
preserved unchanged. Current status, handbook and preset documentation were updated
for this interaction.

## Owner verification

1. Open a capture with an off-center structure. Enable Free camera, fly nearby,
   hold RMB, look around and scroll until the center marker sits on the structure.
2. While holding RMB, try every WASD/Q/E direction and Shift-wheel. Check fine
   control at small radii and practical travel at large radii; repeat elsewhere.
3. Release RMB. Toggle O and verify the local orbit. Then drag, zoom in/out and
   use all six free-movement keys: navigation must remain unrestricted, with
   the orbit frame translating along with Free-camera motion.
4. Repeat setup/commit several times. Check for jumps, accumulated drift,
   distracting guides and unexpected changes to playback or scientific settings.
5. Press R during setup and after commit. Try F / Frame scene. Repeat in
   Fullscreen; R must not restore the window, and Esc must retain window recovery.
6. Save/load a view preset. Take a PNG while holding RMB, and export locked/orbit
   videos with/without UI: temporary guides must be absent. A draft PNG should
   capture the prior committed view.
7. Repeat on Forward+ and Compatibility, bright/dark backgrounds, your preferred
   KDE scale and compact windows. Judge targeting speed, radius precision and
   whether holding/configuring/releasing feels natural before accepting the PR.
