# Issue #187 — progressive mesh wheel zoom

Build **v0.1.0.22**, pending owner review. Historical reports for earlier issues
remain unchanged. The top Ready item was #187, “BUG — Fix mesh zoom step causing
extreme scale jumps”, in mongstad/Wavez Development (Project 1). Work uses the
existing checked-out owner branch
`187-bug-fix-mesh-zoom-step-causing-extreme-scale-jumps`.
Before edits the tree was clean and the branch, local main and origin/main all
pointed to `97e777dc8ebe22eafc975de5671c482fcb4460e2`, the owner-merged #186.
Remote references were pruned; the completed previous local branch was absent.

## Cause and implementation

All scene layers already share one camera wheel path. Frame Scene derives a
world-space bounding sphere from particle positions, field corners and transformed
mesh vertices. Mesh framing was correct: the owner's quick cavity-collapse
capture framed at radius **0.4913971364** with bounding radius **0.1754989773**.
The fixed wheel-up minimum of 8 forced the first inward notch to **8.0** — a
**16.2801×** outward distance jump. The fixed wheel-down maximum of 500 could
similarly jump a large scene inward. See [baseline reproduction](baseline-reproduction.txt).
No mesh renderer or duplicate event accumulator caused this reproduction.

The shared camera path now applies `0.90 ^ min(event.factor, 1)` inward and its
reciprocal outward. Fractional positive factors give smaller steps, oversized
factors cannot exceed one notch, and releases/nonpositive/nonfinite factors are
ignored. A handled wheel press applies once through viewport input dispatch.
Center, yaw, pitch and camera basis remain unchanged.

The inward stop is `max(2*near, framed_radius+near)`; the outward stop is
`max(inward_stop, far-framed_radius)`. Directional clamping preserves an existing
custom radius outside those stops and lets it recover progressively toward the
interval, without snapping. Normal centered zoom stays outside the framed
bounding sphere and within its far plane. The cavity's first inward notch is now
**0.4422574228**, with stops **0.2254989780** and **999.8245010227**.

Scene framing, its existing 0.1 minimum bounding radius, clip plane values, layer
renderers, scientific samples, preparation and playback algorithms are unchanged.
Limits use the **last Frame Scene bound**, not a newly computed bound every frame.
A moved custom center, deliberate custom radius inside geometry, or later mesh
deformation can still clip; reframe after substantial scene changes. This change
does not promise clipping-free arbitrary camera placement.

## Validation

Godot 4.7.2, Linux KDE/Wayland, NVIDIA RTX 3070 Ti, driver 615.71.09.
Focused wheel runs used native Wayland; standalone camera/orbit regressions used
the environment's native display. Each result below passed with zero failures.

| Suite | Forward+ | Compatibility |
| --- | ---: | ---: |
| Source wheel integration | 160 | 160 |
| Linux release package wheel integration | 160 | 160 |
| Existing continuous camera tumble | 13,044 | 13,044 |
| Existing render pacing | 290 | 290 |
| Existing orbit editor/camera/playback (standalone) | 829 | 829 |

Application version unit checks: **2 PASS**. Python compile and `git diff --check`
passed. Reports and native logs are in the corresponding subfolders.

Wheel coverage includes particles, field/volume, mesh, mixed, tiny/large mesh,
and the external `cavity_collapse_torus_quick.ssc` (12 seconds). It checks one
notch, fractional/large factors, repeated directions, near/far stops, custom
radius recovery, frame recovery, center/orientation and sample/mesh-data isolation.
Full source-file SHA-256 hashes were unchanged; hashes are recorded in reports.
Captures, binaries, profiles and caches are external and are not committed.

Both source and release packages checked actual 1440×900 and 3840×2160 windows,
with 4K content scales 2.0 and 2.5, plus windowed/maximized/fullscreen round trips.
These are automated window/layout checks, not physical-monitor approval.
Unobstructed [framed](cavity-framed.png), [one inward notch](cavity-one-notch.png)
and [package 4K scale 2.5](cavity-package-4k-scale2.5.png) images were inspected.

Focused Wayland runs recorded the existing two-line libdecor GTK initialization
warning; the strict wrapper permits that exact known diagnostic only. No product
errors or new accepted diagnostics were added. Other final native regression logs
are clean. The accepted-main orbit wrapper's full camera-trace equality is not
claimed: wheel behavior intentionally changes. Its standalone candidate suite
passed; this run does not claim exported-video pixel comparison.

### Failed harness attempts retained

The initial new test driver had an invalid GDScript `is preload(...)` type check;
it was fixed to use a preloaded type constant before the final runs. A standalone
orbit invocation with an extra `--` produced invalid source arguments and errors;
its reported checks are rejected. Two subsequent orbit attempts reused the new
wheel fixture directory, whose tiny/large captures end at 1 second rather than
the existing orbit suite's expected 2 seconds: each reported 829 checks and 8
playback-at-end failures. Regenerating the existing suite's five-sample,
two-second fixtures yielded 829/0 in both renderers, without altering playback
code or weakening assertions. Available failed logs/reports are preserved in
[harness-attempts](harness-attempts/).

## Reproduction commands

From the repository root, with a fresh output directory per run:

```sh
python tools/validate_wheel_zoom.py --godot /path/to/Godot --renderer forward_plus --output-dir /tmp/wheel-source --capture /absolute/path/cavity_collapse_torus_quick.ssc
python tools/validate_wheel_zoom.py --godot /path/to/Godot --renderer gl_compatibility --output-dir /tmp/wheel-package --capture /absolute/path/cavity_collapse_torus_quick.ssc --export
```

The remaining renderer/source/package combinations use the same options.
Existing tumble and pacing wrappers retain their normal commands. For standalone
orbit validation, use `validate_render_pacing.fixtures` plus the five-sample
small/large fixtures defined in `validate_orbit_center.py`, then:

```sh
/path/to/Godot --path viewer --script res://ui/shell/test_orbit_center.gd --rendering-method forward_plus --audio-driver Dummy -- /tmp/orbit-fixtures
```

## Owner verification and limits

1. Launch build 22 on KDE/Wayland with a physical mouse. Open the cavity-collapse
   mesh, press F, then scroll one notch inward and outward. Confirm modest scale
   changes without an apparent ejection, and stable center/orientation.
2. Scroll repeatedly to both stops and back; press F to recover framing. Repeat
   while playing, with orbit enabled, and after editing a custom orbit radius.
3. Repeat with particles, fields and a mixed capture in Forward+ and Compatibility.
4. Repeat in windowed, maximized and fullscreen on the owner's 4K monitor at the
   preferred UI scale. Confirm wheel handling over controls still belongs to
   those controls and ordinary viewport scrolling remains responsive.

Physical wheel feel, physical 4K/mixed-DPI monitor transitions, sustained playback
of the 393 MiB 240-second cavity capture, and long-session performance are unrun.
The real quick capture and synthetic scientific-state regressions passed;
hands-on owner acceptance is still required. Stop at the single PR review boundary.
