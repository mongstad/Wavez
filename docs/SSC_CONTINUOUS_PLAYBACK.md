# Continuous SSC playback — issue #100 / PR #101

Pending owner review. This extends the lazy opening policy at `f63b140`.
The original startup reports remain historical evidence. Opening is still lazy;
Play now requests complete preparation of the visible temporal fields before
advancing the clock. Initial preparation is allowed to take time.

## Verified starting point

The clean issue branch was
`100-perf-field-005-profile-and-optimize-n192-ssc-loadingpreparation`, with open
PR #101 at `f63b14054ad74c3d08d1ac096d0e1b30573618ca`, targeting main
`d42a4dcd295718357d7bca068e57b1b644311c75`. GitHub had no conversation comments,
inline review comments, submitted reviews or external checks. The two existing
commits add identity-map reuse/native descriptor predicates and lazy opening.
They explicitly do not demonstrate sustained whole-file playback.

The supplied `simscope-ssc-deep-compare-20260926-110903` directory contains
startup profiles, source fingerprints, host information and one attempted live
probe. That probe failed to parse four inferred types, so its log is **not**
playback evidence. The directory and recordings were kept read-only.
Both actual recordings contain 128³ three-channel fields, not 192³:

| Recording | Source bytes | Fields | Particles | Interval |
|---|---:|---:|---:|---:|
| S0_20260925_060202_938955 | 14,878,413,684 | 617, 10 per recorded unit | 247 × 50k | 0–61.6 |
| S2_20260919_204505_268717 | 11,542,897,957 | 401, 2 per recorded unit | 401 × 100k | 0–200 |

S0's configuration declares `t_end=300`, but its last complete record is at
61.6 and there are no trailing bytes. S2's configured and recorded end are both
200. Both declare simulation units, without a separate time-unit field. This
is a recording extent/provenance discrepancy, not evidence of a viewer skipping
data. The reason the external run ended early is not established. No extrapolated
or duplicated frames are added to fill the missing interval.

The field worker must decode/check all source channels, assemble typed arrays,
calculate exact statistics and create selected-channel image planes. The former
four-sample lookahead cannot compensate for preparation slower than consumption.
On the S0 baseline, 61.6 recorded units take 307.133 / 304.885 seconds in fresh /
repeat runs, with 613 / 612 preparation interruptions. Committed-frame p99 is
489.037 / 488.970 ms, while window-draw p99 is only 30.142 / 30.438 ms. Measuring
only window redraws would miss the held simulation clock.

The same limitation is reproduced on unchanged main: a 30-second diagnostic
segment advances only 6.5 recorded units and enters preparation 60 times. This
short main run establishes baseline equivalence, not whole-file acceptance.

## Preparation and memory ownership

Play submits descriptor planning to the existing field CPU worker. It validates
all visible-field descriptors and commit proofs, determines the exact retained
charge, then either admits the entire field timeline or reports an explicit
capacity failure. Payload checks remain in the preparation phase. All source
channels remain resident and available for probes; source precision, geometry,
statistics, color/opacity, lighting, effects and texture resolution are unchanged.

Opening, paused navigation, inspection and offline exports retain their existing
paths. Particle preparation retains its bounded rolling cache and identity reuse.
Opening with autoplay enabled requests the same full-preparation gate as Play.
Meshes retain their existing rolling worker. A single low-priority field worker
avoids CPU contention during playback: it finishes the field work upfront. No
machine-specific thread count, installed RAM size or GPU model selects this path.

The admission calculation uses currently available physical RAM (Linux
MemAvailable excludes swap), credits this cache's already-resident bytes once,
and subtracts the shared OS/renderer reserve, all configured competing scene,
particle and mesh cache/worker reservations, and three maximum-sized field jobs
for transient/current/staged references. It additionally allows 15% overhead for
allocator/driver bookkeeping. Retained charges include every decoded source
channel, unsigned-source widening, selected-channel planes and 64 KiB metadata
per sample. This full-run allocation uses available headroom instead of the
old quarter-share/five-frame window ceiling. It never allocates to installed RAM
alone. The worker rechecks actual available memory before every decode.

Only the current texture and one future texture per visible field occupy GPU
memory. They share the existing per-layer GPU quota, with at most one field
upload per process frame. Full preparation does not populate the GPU with every
sample. The portable renderer does not expose a reliable free-VRAM query; the
existing explicit GPU quota and system-memory reserve remain conservative bounds,
including for shared-memory GPUs. They are not measured process/driver ceilings.

Readiness requires every admitted field sample, including the end. Pause cancels
outstanding planning/preparation without joining the worker on the UI callback.
Completed preparations can be reused; repeat, seek and reverse operations retain
resident data. Source, channel, visibility or texture-budget changes invalidate
the generation. The status badge and Performance details expose field progress.
No status is suppressed to disguise a wait.

The display scheduler retains the fractional remainder of its 30 Hz accumulator.
Discarding that remainder previously quantized slightly-short 60 Hz callbacks
into 20 Hz display updates. Requested timestamps and playback rate are unchanged;
no frames are decimated and no alternate simulation clock is introduced.

## Workload envelope and remaining limits

Capacity is a workload property. A source file's compressed size is not its
prepared size. These 128³ fields require roughly 32 MiB per sample plus metadata:
24 MiB for the three source channels together and an 8 MiB selected-channel preview.
617 samples require about 19.32 GiB of field cache before competing reservations
and safety headroom. A 192³ three-channel float32 field requires about 108 MiB per
sample. Longer captures can exceed RAM on any workstation.

If the full field cache cannot fit, this revision refuses to call a short window
ready for continuous playback. Paused loading and seeking remain available.
A bounded field-streaming implementation that sustains S0's 10 samples per wall
second at 1× has **not** been established. The measured original worker is too slow, so simply
increasing its rolling window would only move the next stall. This is an explicit
remaining limitation, not a raised universal hardware minimum. Particle/mesh
streaming and expensive GPU rendering can independently exceed their deadlines;
field admission alone cannot guarantee arbitrary scene/speed performance.

Only one physical workstation is measured. Synthetic budget constraints test the
policy, not real low-memory pressure or other GPU/CPU architectures.
The asynchronous path retains the reader's existing trusted local-file identity
requirement (currently supported Linux local filesystems). Other platforms and
untrusted files retain their existing paths; sustained playback there is unverified.

## Quality and regression validation

Production images at S0 times 0, 30.8 and 61.6, and S2 times 0, 100 and 200,
are **pixel-identical** between the original PR and the proposed preparation
path. Each comparison also matches the visual configuration, all decoded source
channel hashes, statistics, dimensions/LOD and committed temporal metadata.
No new numerical or visual tolerance is used. The source-file SHA-256 values
remain equal to the original diagnostic fingerprints:

```text
S0 c76d2cc2e9909dcfac5ed90a5526c8873cafb4b3d0d37ea949b135fe4a27e22a
S2 0805d497ad0f69440f3aa7ac30d6cfe9642a4efd142ae406d3a685b595d7d3f5
```

The final native regression matrix uses real Forward+ and Compatibility rendering:

| Suite | Checks per backend | Result |
|---|---:|---|
| Full field session, including autoplay | 130 | Pass on both |
| Scene playback | 2,457 | Pass on both |
| Maintenance / lifecycle | 66 / 51 | Pass on both |
| Adaptive 192³ field budget | 56 | Pass on both |
| Lazy loading / requested corruption | 217 | Pass on both |
| Opacity / native video export | 98 | Pass on both |
| Volume color | 138 | Two existing failures on each |
| Recipes (headless) | 2,697 | Pass |
| Mesh playback (headless) | 2,731 | Pass |
| Load optimizations (headless) | 26,406 | Pass |
| Multichunk storage (headless) | 48 | Pass |
| Native storage / Python storage contract | 109 / 5 | Pass |

Documentation link validation, all three executable API examples, Python
compilation and final native editor import also pass.

The two color failures are `GPU logarithmic midpoint matches linear oracle`
and `slice uses identical logarithmic color semantics`. Both reproduce on
unchanged main `d42a4dc`, on both backends. The color suite stops before its
export stage; the separate opacity suite completes its real video export checks.
These failures remain unresolved and are not counted as passes.

The new session tests cover exact float32/float64 retention, complete readiness,
pause cancellation, seeking during preparation, repeat reuse, channel changes,
capacity refusal/retry, bounded GPU staging, zero full-cache evictions and cleanup.
Budget arithmetic is exercised with artificial available-memory levels of 0, 2,
8 and 32 GiB and competing reservations. These are policy tests on this workstation,
not measurements on four machines.

The final opening-path review added an autoplay entry guard after the timed
production runs: an already-playing transport now invokes the same full session
as the Play button. The measured paused-open/explicit-Play path and continuous
loop are unchanged. The final source reruns full-session checks (128 headless,
130 per GPU backend), scene playback, maintenance/lifecycle and lazy loading on
both renderers, plus the exact production image comparisons. Source hashes and
the small post-measurement differences are recorded explicitly in the evidence.

Earlier diagnostic harness failures are retained separately: the supplied live
probe did not parse, and the first new screenshot test referenced a nonexistent
canvas property before correction. The in-viewer RAM parser omitted some
tab-separated counters before its later correction; external `/proc` telemetry
is authoritative for reported process memory. The first S0 baseline had no
external sampler and was repeated specifically to obtain complete RAM telemetry. Those
harness issues are not attributed to the viewer or silently relabeled as passes.

## Reproduction

Use an externally installed Godot; no runtime or scientific capture is vendored.
Create a new output directory for each command. The complete profiler runs the
real viewer at 1280×800, 1× recorded-time playback and a 60 Hz draw cap, with the
existing 30 Hz display target (33.333 ms). It preserves default rendering settings
and the supplied diagnostic's fixed camera (`orbit_enabled=false`) in both
before and after runs, and records the visual snapshot. Initial and repeat runs
use the same viewer, separated by a seek to the start. The two-second paused
warmup is reported separately. Per-draw
and per-commit tails, every interruption, committed clock, field sample coverage,
RAM/texture/buffer use, CPU/process counters and available NVIDIA telemetry are
retained. Timing is wall-clock; no fixed-delta playback is used.

```sh
python tools/profile_full_playback.py --godot /path/to/godot \
  --capture /absolute/path/recording.ssc --renderer forward_plus \
  --output-dir /absolute/path/new-measurement
python tools/validate_field_session.py --godot /path/to/godot \
  --renderer forward_plus --output-dir /absolute/path/new-session-checks
```

`--viewer` and `--script` allow the same harness to measure a Git archive of the
baseline without switching or modifying the issue branch. Source hashing occurs
after timing; fresh process/viewer does not imply a cold OS page cache. No cache
flush or repeated SSD benchmark is used. Whole-source hashes are compared with
the retained original fingerprints. Raw evidence is outside Git in
`/home/Nozba/Codex/SIMSCOPE/ssc-playback-20260926/`.

## Complete-file measurements

Measured on Fedora Linux 44, Godot 4.7.2, Ryzen 7 5800X (8 cores / 16 logical
CPUs), 50,404,548,608 bytes physical RAM (46.94 GiB), and NVIDIA RTX 3070 Ti
(8 GiB, driver 615.71.09). These are one-workstation Forward+ measurements.
Compatibility has native correctness/export coverage, not a complete production
performance run. No other hardware is claimed validated.

All rows below reach the actual last complete record. Fresh means a fresh viewer;
repeat means seeking back to the start in the same viewer. The OS page cache is
uncontrolled. Preparation is **Play to first advancing frame**, excluding the
separately reported opening and two-second paused warmup. The old PR advances
after its short window and then repeatedly stops; that early advance is not
genuine whole-file readiness. The proposed version waits for every field first.

| Recording / version | Run | Initial preparation, s | Playback wall, s | Interruptions | Total interrupted, s | Committed updates |
|---|---|---:|---:|---:|---:|---:|
| S0 / original PR | fresh | 0.017 | 307.133 | 613 | 263.308 | 1,241 |
| S0 / original PR | repeat | 0.034 | 304.885 | 612 | 261.036 | 1,233 |
| S0 / proposed | fresh | 309.172 | 61.592 | 0 | 0.000 | 1,848 |
| S0 / proposed | repeat | 0.020 | 61.623 | 0 | 0.000 | 1,849 |
| S2 / original PR | fresh | 0.019 | 200.502 | 1 | 0.522 | 5,358 |
| S2 / original PR | repeat | 0.019 | 203.983 | 10 | 4.348 | 6,000 |
| S2 / proposed | fresh | 200.709 | 199.987 | 0 | 0.000 | 6,000 |
| S2 / proposed | repeat | 0.034 | 199.997 | 0 | 0.000 | 6,000 |

The proposed S0 runs present all 617 source fields with 1,848 / 1,849 committed
updates; S2 presents all 401 fields with 6,000 updates on each run. The final
clamped endpoint can add one update relative to an exact 30 Hz interval count.
Each advances the full 61.6 or 200 recorded units in matching wall time to within
one display period. No temporal decimation, artificial duplicates, speed change or
recurring preparation hold is introduced. Each full field cache has zero
evictions and no additional field preparations on repeat.

Window redraw timings and committed-scene timings are distinct. Values below
are milliseconds; p99 is an actual complete-run percentile, not an average FPS.

| Recording / version / run | Draw p95 / p99 / max | Commit p95 / p99 / max |
|---|---:|---:|
| S0 / original PR / fresh | 26.354 / 30.142 / 34.561 | 485.221 / 489.037 / 984.596 |
| S0 / original PR / repeat | 26.609 / 30.438 / 37.231 | 481.934 / 488.970 / 984.783 |
| S0 / proposed / fresh | 31.602 / 34.116 / 38.041 | 38.592 / 40.143 / 43.258 |
| S0 / proposed / repeat | 32.087 / 34.424 / 40.918 | 38.665 / 40.047 / 43.934 |
| S2 / original PR / fresh | 37.062 / 41.411 / 48.343 | 50.624 / 56.432 / 551.971 |
| S2 / original PR / repeat | 32.311 / 36.730 / 44.744 | 38.379 / 40.605 / 577.572 |
| S2 / proposed / fresh | 32.176 / 36.628 / 44.260 | 38.488 / 40.579 / 47.614 |
| S2 / proposed / repeat | 32.082 / 36.493 / 40.988 | 38.315 / 40.300 / 44.253 |

Every interruption timestamp and duration is retained in `preparation-events.csv`
and each `playback.json`. Original S0 interruptions span the recording; its
longest individual preparation wait is 946.397 ms. Original S2 fresh waits
521.934 ms at recorded time 199.953811. Its repeat events occur near
2, 3, 4, 5, 6, 7, 8, 9.466667, 199.466667 and 199.975085;
they last 40.138–560.918 ms. All proposed interruption lists are empty.

### Resource measurements

Process memory comes from external `/proc` sampling at 0.5 s, including kernel
VmHWM. Sustained RSS is the median over the final 30 wall seconds. NVIDIA memory
and utilization are **device-wide**, include the desktop, and are sampled at
1 s; they are not process VRAM measurements. Godot reports its own texture/buffer
allocations separately. All measured runs have zero process swap.

| Measurement | Peak RSS / HWM, GiB | Sustained RSS, GiB | NVIDIA memory median / peak, MiB | Mean CPU cores |
|---|---:|---:|---:|---:|
| S0 original PR, supplementary fresh | 1.504 / 1.504 | 1.503 | 1451 / 1529 | 1.284 |
| S0 proposed, fresh + repeat | 21.076 / 21.077 | 21.076 | 1480 / 1554 | 0.916 |
| S2 original PR, fresh + repeat | 1.513 / 1.513 | 1.503 | 1428 / 1494 | 1.787 |
| S2 proposed, fresh + repeat | 14.211 / 14.211 | 14.188 | 1461 / 1575 | 0.903 |

Mean CPU cores are process CPU seconds divided by total wall time, including
initial preparation and both runs where applicable. They do not claim full CPU
capacity or constant playback-thread utilization. The supplementary original
S0 run exists because the first baseline harness had incomplete RAM counters.
It also completes the full file: 304.633 s with 613 interruptions.

S0: first draw 0.868 s; field cache 19.319 GiB;
Godot texture/buffer peaks 106.021 / 26.023 MiB;
device GPU utilization median / peak 35% / 71%.
The field worker totals 307.472 s, including statistics 188.994 s,
stored/raw hashes 35.731 / 39.207 s,
decompression 10.888 s, assembly 17.916 s,
typed conversion 5.253 s and file reads 2.131 s.
Repeat-play field upload mean / max: 1.719 / 3.696 ms;
particle interpolation packing mean 7.327 ms; source-identity checks mean 2.291 ms.

S2: first draw 0.985 s; field cache 12.556 GiB;
Godot texture/buffer peaks 106.021 / 23.075 MiB;
device GPU utilization median / peak 28% / 73%.
The field worker totals 200.330 s, including statistics 123.148 s,
stored/raw hashes 23.427 / 25.563 s,
decompression 7.196 s, assembly 11.737 s,
typed conversion 3.460 s and file reads 0.929 s.
Repeat-play field upload mean / max: 1.665 / 2.518 ms;
particle interpolation packing mean 14.558 ms; source-identity checks mean 2.320 ms.

### Acceptance and limits

**Complete-file continuity, requested speed and preserved quality pass for both
recordings on the measured workstation, fresh and repeat:** zero post-start
preparation events, every field represented, and equivalent frames exact.
**Strict frame-time acceptance remains unmet:** committed-frame p99 exceeds
the declared 33.333 ms display target, and redraw tails exceed the 16.667 ms
draw target. The remaining variation is visible in the table; these results do
not establish perfectly even 30 Hz presentation or a universal smoothness claim.
The major half-second cache-boundary stalls are removed. Particle interpolation
packing and synchronous source-identity checks remain measurable main-thread
costs; uploads and scheduling also contribute. No quality reduction is used to
force these tails under budget. Overall smoothness acceptance is therefore
**not fully met**, despite the preparation/throughput criteria passing.

For field timelines beyond admitted RAM, continuous playback is explicitly
unsupported by this revision. That workload criterion remains unmet; a faster
bounded field pipeline is still needed. Actual memory pressure from other
applications, other GPUs/CPUs, and whole-production Compatibility performance
have not been validated.

### Evidence map

All paths below are under the external `ssc-playback-20260926` directory above.

- `before-s0.json`, `before-s2/`, `before-s0-telemetry/`: complete original-PR baselines.
- `main-s0-short/`: limited unchanged-main reproduction, not complete-file acceptance.
- `after-s0-final/`, `after-s2-final/`: final fresh/repeat complete native runs, per-draw clock traces, source fingerprints, `/proc` and NVIDIA telemetry.
- `measurements-summary.json`, `preparation-events.csv`: derived metrics and every interruption; `summarize_results.py` regenerates them.
- `frames-s0-comparison.json`, `frames-s2-comparison.json`, `frames-*-before/`, `frames-*-after/`: exact source, temporal and rendered-image comparisons.
- `regressions-final/`, `session-final-headless/`, `autoplay-final/`, `storage-final/`, `python-storage.log`: native and storage checks, including final opening-path validation.
- `main-color-forward_plus/`, `main-color-gl_compatibility/`: unchanged-main color failures.
- `original-evidence-manifest.json`, `original-evidence-unchanged.json`: all 13 original diagnostic files unchanged.
- `tested-code-sha256.json`, `tested-product-verification.json`: measured source identity, with the later autoplay entry guard and profiler-only guards identified.
- `pr-before.diff`, `before-revisions.json`, `commits-before.txt`: inspected starting PR and revisions.

No merge, issue closure or Project transition is authorized by these results.
