# Issue #178 — calmer empty viewport

The top Ready issue was #178, “UX — Remove flickering star-like dots from empty
viewport background.” Work started clean on the existing owner-linked branch
`178-ux-remove-flickering-star-like-dots-from-empty-viewport-background`, exactly
at accepted main `c27af4a` (owner-merged PR #185). Fetch/prune completed and the
completed #179 local branch was already absent. Candidate `v0.1.0.21` proposes
one build increment and remains pending owner review.

## Source and change

`main.gd::_build_starfield()` creates **2,400 decorative QuadMesh instances**,
0.28 units wide, distributed at radii 285.6–420 using seed 5800813. Their dedicated
additive emissive billboard shader is `_star_material()`. These tiny distant
quads are the source of the specks; this shader contains no TIME animation.
The apparent flicker is consistent with tiny projected geometry during camera
movement/redraw, rather than a shader twinkle term. That mechanism is an inference;
the isolated speck source is confirmed by before/after images.

The cinematic background is a separate sky shader in `_build_backdrop()`.
Its belt/cloud/dust calculation, environment, lighting/fog/glow, viewport geometry,
actual scientific particle shader, field/mesh paths and playback/cache code are
unchanged. The starfield now has a hidden identity-transform Node3D parent until
a capture is successfully opened. Child star visibility can still participate in
existing clean-view and saved visual-state behavior, but cannot expose startup
specks while its parent is hidden. A valid capture enables the parent, preserving
accepted loaded Cinematic/Scientific behavior and export state. An invalid first
open leaves it hidden. No replacement effect, animation or per-frame work is added.

## Results

Godot 4.7.2 stable, KDE Plasma, NVIDIA RTX 3070 Ti / driver 615.71.09.
Focused comparisons and release packages use native Wayland; existing pacing
regressions use X11/XWayland. External engine/templates remain uncommitted.

| Validation | Forward+ | Compatibility |
|---|---:|---:|
| Focused source candidate | 44 PASS | 44 PASS |
| Accepted-main comparison driver | 38 PASS | 38 PASS |
| Exact scene-image comparisons to main | 11 pairs equal | 11 pairs equal |
| Focused Linux release package | 44 PASS | 44 PASS |
| Existing render-pacing regression | 290 PASS | 290 PASS |

[Forward+ comparison](forward-comparison.json) and
[Compatibility comparison](compat-comparison.json) compare three startup layouts
and eight loaded scene images per renderer. Startup reference images hide only
the accepted-main starfield: candidate scene pixels exactly match that sky-only
reference. Loaded particles, field, mesh and mixed fixtures match accepted main
in both Cinematic and Scientific modes. Comparison crops cover the scene area,
excluding shell/status/build text; they are not whole-window output equality.
Camera transforms, initial recorded clocks, record counts, sky code and environment
settings match. Source fixtures retain unchanged SHA-256 throughout all runs.

Each focused run verifies actual **1440 × 900** and **3840 × 2160** windows at
content scales **2.0 and 2.5**, startup and forced-redraw stability, failed opening,
child visibility isolation and clean/cinematic preset transitions. Packages:
[Forward+](forward-package.json), [Compatibility](compat-package.json).
The ordinary startup [screenshot](startup-normal.png) and
[log](startup-normal-native.txt) also confirm the centered Open capture button
remains visible after layout/UI processing settles. The inspected
[4K package image](startup-4k-package.png) is compared with
[accepted-main specks](accepted-main-stars.png). Forward+ retains the atmospheric
sky; Compatibility retains its existing renderer-specific background appearance.

## Performance and regression limits

The source Wayland idle observations were **173 draws / 173 callbacks in 1.2 s**
on both accepted main and candidate, for both renderers, with identical retained
pixels. These native Wayland runs continuously draw despite the existing low-CPU
policy; this is also present on main. No draw-cadence increase was measured.
This display-paced sample is not a CPU/GPU benchmark or proof of general speedup.

The existing [Forward+](forward-pacing.json) and
[Compatibility](compat-pacing.json) regressions pass stationary redraw-on-change,
camera interaction, bounded paused orbit, playback/seek/channel changes, all
four layer fixtures and offline-isolation checks. Stable X11 phases have zero
additional draws and unchanged pixels/camera/scientific clock. There is no new
runtime per-frame branch, shader or texture creation. No performance regression
was observed in these short cadence/pacing checks; GPU timings, production
workloads and long sessions were not profiled.

Final viewer import, Python compile, `git diff --check` and the application-version
unit suite (**2 PASS**) passed. New Godot script UID sidecars are included.

## Diagnostics and failed attempt

The first comparison harness failed because KDE adjusted the first requested
window to 1448 × 932 while decoration changes settled, and it incorrectly required
Wayland to have the X11 zero-redraw behavior. Its two failed assertions and report
are preserved in `initial-harness-failures.*`. That run also timed out at 160 seconds
after writing its report; the final driver explicitly closes fixture readers and
frees its viewer before exit. Settling geometry before setting it, measuring
Wayland behavior against main, and completing fixture teardown resolved the
harness failures. They are not counted as successful validation.

Focused strict logs retain the exact libdecor GTK fallback pair reproduced on
accepted main, explicitly listed in each validation JSON; no other diagnostic
was encountered in final focused runs. Existing pacing logs are preserved as run.
The gate has not been weakened for new errors or arbitrary warnings.

Physical 4K/compositor scaling, mixed monitors, Windows/macOS, hands-on perception
of noise/flicker, production performance and broad deterministic video comparisons
remain unrun. Loaded rendering is verified on generated fixtures, not all possible
captures. Historical reports/evidence are intentionally preserved as written;
only current status and handbook behavior documentation change.

## Reproduction and owner verification

```sh
python tools/validate_empty_background.py --godot /path/to/godot --output-dir /tmp/empty-compare --reference-root /tmp/accepted-main --renderer forward_plus
python tools/validate_empty_background.py --godot /path/to/godot --output-dir /tmp/empty-package --renderer gl_compatibility --export
python tools/validate_render_pacing.py --godot /path/to/godot --output-dir /tmp/pacing --renderer forward_plus
```

1. Launch build 21 without a capture on both renderers, including a Linux release.
   Inspect the cinematic background and centered Open capture button; look for
   tiny specks during idle, redraw and camera movement. The sky treatment remains.
2. Repeat on your physical 4K KDE display at normal compositor scaling and any
   mixed-monitor setup. Check normal, maximized and fullscreen states.
3. Open representative particle, field, mesh and mixed captures; compare Cinematic
   and Scientific presets, camera movement, playback, seek and channel changes
   with accepted main. Verify actual particles and overlays remain intact.
4. Try an invalid first capture open, dismiss the error and recheck the empty sky.

Stop for owner review. No merge, auto-merge, manual issue closure, board transition
or next-issue work is performed.
