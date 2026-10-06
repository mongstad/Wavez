# Issue #205 — screen-fixed Cinematic background

The sole top Ready item on 2026-10-06 was #205. Its owner-created branch
`205-ux-viewport-keep-cinematic-background-screen-fixed-during-camera-navigation`
was checked out clean at accepted `main` `d5e536e`; both local and remote
`main` matched it after fetch/prune. #190 and #198 were closed, and the
previous #261 PR #265 had been owner-merged. This candidate proposes
**v0.1.0.55** for review.

## Change and source boundary

The old sky shader sampled world-space `EYEDIR` for its visible gradient.
The candidate samples a screen-space ray reconstructed from `SCREEN_UV`,
viewport aspect, the 55-degree projection and the accepted initial view.
The original belt/cloud/dust/color formula is unchanged; the cubemap pass
retains `EYEDIR`. Resizing updates only the presentation aspect. Camera code,
scientific layer transforms, sample state, mapping and export composition are
unchanged. The accepted shader has no independent time animation; its apparent
motion while navigating was camera coupling.

## Focused results

| Check | Forward+ | Compatibility |
| --- | ---: | ---: |
| Native screen-fixed harness | [65 PASS](forward-source.json) | [65 PASS](compat-source.json) |
| Linux release package harness | [65 PASS](forward-package.json) | [65 PASS](compat-package.json) |
| Two-frame Cinematic mixed-scene MP4 | [complete, stable corners](cinematic-export.json) | [complete, stable corners](cinematic-export.json) |

The screen-fixed harness checks exact whole-frame sky pixels through
upside-down tumble, view-relative orbit, steering, translation, Auto Orbit
camera motion, wheel zoom, reset, framing and direct offline camera transforms.
It repeats the check after 1920×1080 and 3840×2160 resizing and in maximized
and fullscreen modes. Particle, field, mesh and mixed fixtures respond to
camera motion while their scientific samples remain unchanged. The four
synthetic source hashes stayed unchanged in each run. The package runs use
standalone Linux release executables with no script errors.

The [accepted-main default sky](accepted-main-default.png) and
[candidate default](candidate-default.png) differ at **2 of 614,400 pixels**,
by one color level each on Forward+ at 960×640; see
[comparison metrics](appearance-comparison.json). The baseline image came
from the accepted `main.gd` in a separately imported temporary viewer under
the same native renderer. Its subsequent screen-fixed assertions intentionally
failed as expected on the old shader. The
[upside-down empty view](candidate-upside-down.png) retains the same sky pixels.
The [mixed default](mixed-default.png) and
[mixed tumbled](mixed-tumbled.png) images show scene motion in front of it.

An actual viewport-only video export used the
[live Cinematic state](mixed-cinematic-state.json) captured by the focused
viewer harness. With a **2.4 rad/s** camera orbit, it produced two 960×540
frames in each renderer. The four 64×64 sky corners are identical within each
pair, while **148,833 Forward+** and **75,922 Compatibility** pixels changed
with the scene/camera. Both MP4s completed with
clean logs and moving camera positions. Inspect the retained
[Forward+ first](export-forward-first.png) /
[orbited](export-forward-orbited.png) and
[Compatibility first](export-compat-first.png) /
[orbited](export-compat-orbited.png) frames; the generated MP4s and synthetic
WVZ1 fixtures remain outside Git. The existing #198
[viewport export matrix](video-matrix-forward.json) passed **264 checks** on
Forward+, covering four scene types, legends, frame timing, camera traces,
source bytes and repeated pixels. The directly connected
[navigation suite](navigation-headless.json) passed **1,393 headless checks**.

Initial checks exposed validation-environment and harness setup issues:
sandboxed Godot editor sockets, hidden export templates under an isolated
`XDG_DATA_HOME`, an extra packaged main scene covering the test view, and
Compatibility texture diagnostics when temporary sky scenes were removed
before a render flush. The harness was corrected or rerun with appropriate
access; the final runs above passed cleanly. These attempts did not identify
a product regression.

Physical 4K/mixed-DPI monitors, production captures, long sessions and
human assessment of the accepted visual character were not run. The
automated 4K check verifies rendered dimensions, not a physical display.
See the [owner steps](../../CINEMATIC_BACKGROUND.md#owner-verification).
