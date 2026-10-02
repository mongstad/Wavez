# Issue #178 — complete decorative starfield removal

Owner feedback requires removing the decorative stars entirely, including after
loading a simulation. This revision supersedes the initial startup-only gate in
PR #186. Build remains `v0.1.0.21`; historical parent evidence stays as written.

Deleted `_star_material`, `_build_starfield`, the 2,400-quad generation path and
both starfield node properties. Removed star visibility from visual snapshots,
portable presets, export overrides and test-job state. The sky shader, environment
and actual scientific particle/field/mesh shaders remain unchanged. There is no
hidden star resource, replacement effect or setting that can re-enable it.

`starfield_visible` is no longer part of newly saved portable presets. Existing
unknown-field handling skips/reports it in older recipes; no migration shim or
star-specific compatibility path was added. See the updated current preset guide.
Historical baseline comparisons still reference the old node solely to suppress
it in the accepted-main snapshot, not to recreate it in current runtime code.

## Final validation

Godot 4.7.2 stable, KDE Plasma, NVIDIA RTX 3070 Ti. Native Wayland focused source
and package runs verify actual 1440 × 900 and 3840 × 2160 at scales 2.0/2.5.

| Suite | Forward+ | Compatibility |
|---|---:|---:|
| Focused source | 44 PASS | 44 PASS |
| Reference driver | 37 PASS | 37 PASS |
| Exact cropped scene-image comparisons | 11 equal pairs | 11 equal pairs |
| Linux release package | 44 PASS | 44 PASS |
| Portable view presets | 814 PASS | 754 PASS |
| Point rendering/visual-state round trips | 60 PASS | 60 PASS |
| Current-format video/export verification | 235 PASS | 225 PASS |
| Render pacing/scientific state/offline isolation | 290 PASS | 290 PASS |

Source comparisons: [Forward+](forward-comparison.json),
[Compatibility](compat-comparison.json). The reference starfield is hidden for
both empty and loaded images. Candidate scene pixels then match exactly in three
startup layouts and eight particle/field/mesh/mixed images across Cinematic and
Scientific modes. This proves the underlying scientific and sky pixels are
preserved when the removed decoration is excluded; original Cinematic images
with stars intentionally differ. Crops exclude shell/status/build text.

Preset tests preserve source hashes and verify round trips, unavailable-layer
handling and atomic invalid-input rejection. Point-rendering tests preserve
environment/presentation and real particle shader switching. Video tests cover
all scientific layer fixtures, clock/sidecar/field bytes, production overlays,
MP4 output and expected corrupt/budget failures. No new production capture was
used. The complete suite reports are adjacent to this document.

Focused candidate idle pixels remain stable. Source Wayland samples measured
173 draws/callbacks on both Forward+ implementations; Compatibility measured
172 reference and 173 candidate in 1.2 seconds, a one-frame boundary difference.
This is display-paced observation, not a GPU/CPU benchmark. Existing X11 pacing
regressions retain zero additional stationary draws, unchanged camera/clock,
bounded orbit and offline behavior. No new per-frame work is introduced.

Final package import, Python compile, whitespace check and two application-version
tests passed. The final runtime source contains no starfield creation, shader,
state or export references. Test references only inspect absence and the historic
accepted-main node. Inspected loaded screenshots show [Forward+](loaded-mixed-forward.png)
and [Compatibility](loaded-mixed-compat.png) scenes without decorative specks.

## Diagnostics and limits

Earlier revised reference processes on both renderers wrote successful assertion
reports but timed out at native shutdown. Their `*-reference-timeout.*` logs/reports
are retained and are not suite passes. A fresh Forward+ reference import then hit
dummy-renderer texture cleanup errors (`failed-reference-import.txt`). The warm
repeat passed strict import and the full final comparison. No arbitrary error
or warning was exempted. Final focused logs retain only the exact accepted-main
libdecor GTK fallback pair, listed in their validation JSON. Final point/preset,
video and pacing suites passed their existing gates.

Current handbook/status/preset docs describe total removal. Earlier review-time
reports are preserved, including the superseded startup-only behavior. Physical
4K/compositor scaling, mixed monitors, Windows/macOS, long sessions and production
GPU/CPU profiling remain unrun. Fixture image equivalence does not prove every
possible capture. Owner visual acceptance remains required.

## Owner checks

1. Launch candidate build 21 on Forward+ and Compatibility, including a Linux
   package. Inspect the retained sky and Open capture button with no specks.
2. Load particle, field, mesh and mixed captures. Inspect the background during
   camera movement, playback, seek and channel changes; no decorative stars
   should return. Actual scientific particles must remain.
3. Switch Cinematic/Scientific presets, save/load a view preset, and export a
   short clip in each mode. Verify no decorative stars return in scenes or output.
4. Repeat on physical 4K KDE at normal scaling and with mixed monitors if used.

PR #186 remains pending owner review, with no merge or auto-merge enabled.
