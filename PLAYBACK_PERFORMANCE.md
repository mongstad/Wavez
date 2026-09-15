> Historical checkpoint report; original scope, paths and measurements below
> describe that run. See [current status](docs/CURRENT_STATUS.md) and
> [retained evidence](docs/EVIDENCE_INDEX.md) for the accepted G0–G4 implementation.

# Real-capture playback performance — 2026-09-10

Implemented and validated only in `SimScope`. The supplied capture and all
60 tracked files in the original `../SimScope` still match their SHA-256 hashes.
The existing project copy was reused. No solver, source format, shader quality,
playback rate default, screenshot destination policy or export timing was changed.

## Finding and measured outcome

The slowdown was reproduced on **D128_isolation_long_simscope.vbc**: SIMSCP1,
4,080,410,529 bytes, 600 complete frames, 100,000 particles and 13 channels.
SHA-256: `2219325de375bb04aa2ca93a34130ccd577e49001f82bd222a67985ece41217b`.
Each frame carries 6,800,000 payload bytes. Source index 250 is frame 251 in the UI.

The primary bottleneck was CPU scalar styling, followed by redundant decoding
and interpolation work. At a requested 12 source FPS the accepted G1 viewer
advanced only about 3.7 source frames per second and presented new content roughly
every half second. Turning off cinematic effects did not resolve those CPU stalls.
The previous synthetic benchmark repeatedly interpolated an already-loaded pair;
it did **not** measure the frame transitions responsible for this report.

Final measurements, Godot 4.7.2 / Vulkan Forward+ / RTX 3070 Ti, 1440×900,
vsync disabled, normal viewer UI/process loop, orbit off, recorded history off:

| Case | Actual source FPS, before → after | Presented-content gap p50, before → after | Gap p95, before → after |
|---|---:|---:|---:|
| Cinematic, requested 12 FPS, source index 250 | 3.80 → 11.93 | 504 → 67 ms | 524 → 83 ms |
| Scientific, requested 12 FPS, source index 250 | 3.72 → 11.90 | 515 → 67 ms | 540 → 74 ms |
| Cinematic, requested 1 FPS, source index 250 | 0.88 → 0.99 | 34 → 34 ms | 55 → 39 ms |
| Inspector hidden, cinematic 12 FPS | 3.74 → 11.92 | 506 → 67 ms | 526 → 85 ms |
| Dense opening frames, cinematic 12 FPS | not separately measured → 11.91 | — → 91 ms | — → 103 ms |
| Physical time, 12 source-time units/second | not separately measured → 11.90 | — → 66 ms | — → 86 ms |
| Velocity magnitude coloring, 12 FPS | not separately measured → 11.92 | — → 80 ms | — → 87 ms |

At 1 source FPS, the worst measured content gap fell from **279 to 85 ms**;
p95 alone hides infrequent transition stalls. At 12 FPS the main-case worst gap
fell from 539 to 86 ms. Initial dense frames remain more expensive; their final
worst gap was 110 ms. This improves responsiveness substantially, but does not
claim 30 rendered updates/second for every channel, frame or history setting.

## Pipeline breakdown

Median milliseconds in the main cinematic 12 FPS case. Inclusive stages overlap:
**do not add every row**. The original full-stage profile is `baseline.json`;
a separate fully frozen G1 project run supplies comparable presented-content cadence.

| Stage | Before | After | Interpretation |
|---|---:|---:|---|
| Source transition, including style/UI | 246.44 | 48.89 | p95 249.60 → 51.24 ms |
| CPU style, inclusive | 188.59 | 42.98 | Dominant measured cost |
| Normalization range scans | 19.50 | 6.75 | Nested inside style; unused direct-brightness scan removed |
| File I/O, per payload read | 1.315 | 0.710 | OS cache warmth not controlled |
| Channel decode, per payload | 4.699 | 4.673 | Source decoding and u32 precision preserved |
| Position conversion | 14.145 | 0.213 | Native packed conversion on stock float32 engine |
| Velocity derivation | 10.863 | not called | Derived lazily when selected; included in velocity case |
| Mapping/filter UI, inclusive | 16.756 | 0.127 | Baseline included eager velocity derivation |
| Interpolation + submission, inclusive | 28.909 | 14.564 | Actual viewer display update |
| Interpolation/packing alone | not isolated in original loop | 11.942 | Typed arrays, invariant checks outside loop |
| Buffer submission CPU | see isolated probe below | 2.501 | Median per bulk submission |
| GPU viewport rendering | 0.362 | 0.571 | GPU work was not the limiting stage |
| Renderer CPU | 0.072 | 0.087 | Excludes script work |
| HUD CPU | 0.026 | 0.024 | Not a meaningful bottleneck |
| Shader uniform updates | 0.027 | 0.028 | Not a meaningful bottleneck |
| Live index refresh | 0.026 | 0.024 | Unchanged complete-tail polling |

Before: 68 payload reads for 33 transitions, including periodic redundant next-frame
reads. After: one new payload per sequential transition, reusing the already-held
next frame. These are **frame-pair hits**, not a new persistent decoded cache.
Only the current/next frames and the existing optional five history frames are
retained; no full-capture preload or unbounded cache was added.

The separate original microprobe measured 29.6 ms to interpolate/pack transforms
and 13.2 ms for a loop of instance setters. Those loops differ from the original
interleaved 28.9 ms update and cannot be added to reconstruct it. The new buffer
submission timer measures the CPU copy/enqueue call, **not isolated GPU DMA**.
Viewport GPU timing measures renderer work; asynchronous transfer completion is
not independently exposed by these instrumentation points. GPU timestamps may
also vary with clock/power state. See the engine's
[render-timing API](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html).

Whole viewer construction/open took 442 ms before and 275 ms after in these runs.
A separate explicit committed-source SHA-256 took **11.63 seconds** for 4.08 GB.
**No source hash ran during playback.** Hash verification remains intact and can
still block large-capture screenshot/recipe/export setup; persistent identity work
requires a correctness contract, not a weaker fingerprint.

The separate resource probe (`resources.json`) measured peak process RSS of
671.8 MiB and driver process GPU memory of 280 MiB. The primary timing run
reported 119.3 MiB engine static allocation and 173.3 MiB engine video allocation;
these are not total process RAM/VRAM. Godot could not read `/proc/self/status`
through its file API, so the resource probe sampled the process externally.
Concurrent CuPy simulation was not part of the test workload.

## Changes

- Typed scalar batches, prepared normalization constants, and bulk MultiMesh buffers
  replace repeated dictionary/object dispatch and per-instance rendering calls.
- Scalar coloring skips display styling for explicitly transparent or filtered
  particles. Their source channels, count, stable ordering and interpolated positions
  remain intact. Hidden display slots may have zero size/RGB; visible attributes
  and rendered pixels match G1. Statistics still scan the full selected channel.
- Position arrays use Godot's native byte conversion on float32 Vector3 builds,
  with a conversion loop retained for double-precision engines. Scientific f4/u4
  values retain their existing precision; float64 display arrays represent every
  uint32 category exactly. No particle identity scheme was added.
- Playback reuses the loaded next frame; unchanged live-tail polls avoid rereading it.
- Velocity magnitude is derived only when needed. Category controls use complete
  native array equality and refresh on category, source or filter changes.
- During catch-up, intermediate frames still advance the same clock and history,
  including schema fallback, but only the final pair is styled for presentation.
  The offline physical-time export path and its exact sampling remain unchanged.
- Opt-in stage timers and a real process-loop profiler are retained for future work.
  Profiling is disabled during ordinary viewing. No per-particle timers were added.

## Acceptance

All final logs contain no Godot errors:

| Validation | Result | Evidence under `results/playback-profile/` |
|---|---|---|
| Real-rendered differential suite vs archived G1 | 34 checks PASS | `equivalence.log`, `validation.log`, `equivalence-regression.log` |
| Python reader/writer tests | 7 PASS | `python.log` |
| Generic viewer, including 250k/count/schema/live-tail cases | 30 checks PASS | `generic-regression.log` |
| Legacy viewer | 6 checks PASS | `legacy-regression.log` |
| G1 inspection and pinned signed-video export | 58 checks + video PASS | `inspection-regression.log` |
| Full video suite, including native 4K, timing, history and failure/cancel handling | PASS | `video-regression.log` |
| Compatibility renderer | 30 generic checks PASS | `compatibility-regression.log` |
| Source preservation | Capture hash and all 60 original files unchanged | `preservation.json` |

The differential suite compares all visible instance attributes, every interpolated
position, ranges and sample provenance, then the **actual pixel arrays**. Tested
real default/initial/density/velocity/catch-up views plus invalid values, exact u32
categories, direct RGBA, clipping/invert, cyclic/constant mapping, empty/count-changing
frames and legacy input. Pixels match exactly on this GPU; visible numeric comparisons
have zero measured error in these cases. `reference.png` and `optimized.png` were
also visually inspected. Dense normalization mode/invalid-value combinations are
checked against the retained scalar reference function. No manual human walkthrough
or concurrent CuPy-solver workload is claimed.

## Reproduce / resume

From the `SimScope` directory:

```bash
python tools/validate_playback.py --godot /path/to/godot
/path/to/godot --path viewer --resolution 1440x900 --audio-driver Dummy --disable-vsync --script scene/profile_playback.gd -- --profile-job="$(pwd)/results/playback-profile/optimized-job.json"
/path/to/godot --path viewer -- --capture="$(pwd)/D128_isolation_long_simscope.vbc"
```

The final timing job covers seven eight-second cases. Use ordinary playback at
12 FPS, history off, to try the improvement; cinematic effects can stay enabled.
The capture's early frames and source index 250 exercise different active populations.

`baseline.json`, `baseline-cadence.json`, `optimized.json` retain per-stage samples,
counts, settings and wall gaps. Presented-content gaps are measured after real draws
when the committed sample changes; raw uncapped draw FPS includes unchanged images
and is not a smoothness metric. No OS caches were flushed, so these are repeat-run
local-file timings, not cold-storage benchmarks. Runs are sequential on the actual
GPU, not headless or fixed-delta simulations. Percentiles store at most the first
8192 samples per stage; content/transition samples fit fully within that limit.

`g1-code.tar.gz` preserves pre-change viewer code for differential acceptance.
`source-sha256.json` identifies the final implementation. Earlier typed/bulk probe
artifacts are development measurements, not final acceptance results.

This is the completed **real-playback performance slice before G2a**. Persistent
validated indexes, byte-bounded seek caches and strong replacement/truncation/live-
append identity validation remain next. G2b and actual meshes/fields remain unimplemented.
Future speed work should use this capture and profile selected channels/history;
CPU batch preparation and interpolation remain more expensive than GPU rendering.
