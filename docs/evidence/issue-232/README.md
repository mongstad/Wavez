# Issue #232 — mixed playback investigation

Candidate **v0.1.0.37**, pending owner review, 2026-10-04.

The supplied mixed capture advances beyond the reported 15–20% position and to
the end on both pre-#230 and merged-#230 code. Both temporarily hold at 2× to
refill fields while required particles are ready. The owner confirmed that the
reported stop resumed automatically. The exact original stop position and RAM
conditions were not reproduced; this is an equivalent field-refill condition,
not proof of the cause of every earlier stop.

The candidate fixes a misleading **Required particle content** wait reason when
the nested field pump actually blocks. It retains #230's cache policy and all
existing field gates, worker scheduling and scientific behavior. It does not
claim to make this capture play continuously at 2×. The owner decides whether
the diagnosis and reporting correction resolve the issue.

## Provenance and protocol

- #232 was the top/only Ready item in Wavez Development. Its existing linked
  branch was checked out clean before edits:
  `232-bug-playback-mixed-particlefield-playback-can-stall-despite-prepared-field-headroom`.
- Accepted pre-#230 baseline: `70fd282780b78a67ff10ba467c96560579a69de5`.
- Merged #230 / branch base / synchronized accepted main:
  `3df35ee4b175b512ebabd60aae39e0d55b5a3a62` (build 36). The owner merged #230;
  the old local issue branch was removed only after confirming identical trees.
  Remote references were pruned. No branch was created or replaced for #232.
- Baselines were temporary `git archive` source snapshots, imported by Godot.
  Experimental memory overrides were restored from the exact commits before
  the real-RAM comparisons below. The new regression was also run against the
  unchanged merged runtime to establish the diagnostic failure.
- Linux, Godot 4.7.2, NVIDIA RTX 3070 Ti, 50,404,556,800 bytes physical RAM.
  Production traces use Forward+, 960×640, trails off, nonlooping 2× playback.
- Protocol: open paused; wait until the admitted field window is ready, no
  field job is active and requested particle pairs are resident for two seconds;
  then Play. Each authoritative run had one diagnostic viewer and no simulated
  RAM reservation. Background applications and filesystem cache were not held
  identical, so this is causal investigation, not a controlled speed benchmark.
- [Source metadata](source.json): external `free_collapse.wvz`, 54,283,866,848
  bytes, time 0–74.5 s; 150 samples of 50,000 persistent-ID particles (16 arrays,
  4,200,000 raw bytes/sample), 746 field samples (192³, density/real/imag,
  84,934,656 raw bytes/sample). No mesh object. No source payload is committed.

## Matched full-prefill observations

RAM values below use GiB (2³⁰ bytes). Hold spans are first-to-last one-second
observations, not exact event durations. Field lead is in **wall seconds at 2×**.

| Measurement | Pre-#230 | Merged #230 | Candidate repeat |
| --- | ---: | ---: | ---: |
| Paused field cache | 29.76 GiB / 282 samples | 29.97 GiB / 284 | 31.98 GiB / 303 |
| Initial field lead | 14.10 s | 14.20 s | 15.15 s |
| Play-to-end wall time | 48.930 s | 48.894 s | 49.810 s |
| Requested end time | 74.5 s | 74.5 s | 74.5 s |
| First refill at source time | 46.330 s (62.2%) | 44.471 s (59.7%) | 52.406 s (70.3%) |
| Observed refill span | 11.055 s | 11.047 s | 12.054 s |
| Field lead at hold | 3.235 s | 3.364 s | 3.147 s |
| Field producer at hold | 11.128 samples/s | 11.207 samples/s | 11.312 samples/s |
| Field consumption | 20 samples/s | 20 samples/s | 20 samples/s |
| Min/max particle budget | 2 / 2 GiB | 1.717 / 2 GiB | 2 / 2 GiB |
| Peak sampled RSS | 33.02 GiB | 33.12 GiB | 35.00 GiB |
| Peak process swap | 0 | 0 | 0 |
| Particle completions / cancellations | 150 / 0 | 150 / 0 | 150 / 0 |
| Prepared-pair misses / failures | 0 / 0 | 0 / 0 | 0 / 0 |
| Particle evictions / final resident pairs | 115 / 35 | 115 / 35 | 115 / 35 |

The requested particle window never exceeds eight pairs. At each observed hold,
particles are ready, the field session is waiting, and contiguous prepared
fields remain. In old code the false return from the field controller propagated
through `particle_playback.pump()` and was labelled as a particle wait. The
candidate reports **Required field content or startup coverage** instead.

The existing field gate predicts exhaustion when production falls behind. With
sufficient rate measurements it requests a refill if remaining lead is below
two wall seconds or predicted exhaustion is within eight seconds. Without rate
confidence it uses the two-second threshold. Resumption requires the admitted
window or the existing measured-rate/lead gate to be ready. These rules predate
#230. Initial RAM runway delays this event but cannot sustain 20 samples/s when
preparation supplies about 11 samples/s.

The profiler stops at the requested end time. Final committed presentation was
74.475584 / 74.481740 / 74.475768 s respectively, up to one display step behind;
these runs do not assert exact endpoint pixels. Every particle pair completed.
Field completion counters count work, not unique samples (including occasional
repreparation). File size/mtime/ctime remained unchanged; this is not a full
54 GB payload hash or strict whole-file integrity verification.

Machine-readable evidence:

- [Pre-#230 summary](pre-230-summary.json), [observations](pre-230-trace.jsonl).
- [Merged-#230 summary](merged-230-summary.json), [observations](merged-230-trace.jsonl).
- [Candidate summary](candidate-summary.json), [observations](candidate-trace.jsonl).

Summaries retain initial/final budgets, reservations, particle state, field gate
and worker transitions. Compact observations retain the particle requested and
resident indices, decoded/prepared bytes and limits, estimates, completion,
cancellation, eviction, miss and failure counters; field coverage, cache state,
producer, active workers and mesh reservation; RSS, available RAM and swap.
They contain no scientific sample arrays. Original full traces were temporary
diagnostic output. A one-second sampler cannot characterize every subsecond wait.

## Audit of the proposed particle causes

| Candidate cause | Evidence and conclusion for these runs |
| --- | --- |
| Field-worker allowance | Included after #230, but particles remained admitted at observed holds. No admission failure established. |
| Mesh reservations | Zero throughout; the capture has no mesh. |
| Five percent slack | Can reduce the available particle budget. Even the measured 1.717 GiB minimum kept required pairs ready; no causal hold shown. |
| Periodic reassessment | Merged budget first fell below 2 GiB at wall 46.285 s / source 38.438896 s, to 2,018,004,967 bytes. No prepared miss then or later. This measurable divergence did not cause a particle wait. |
| History reclamation | Both baselines ended with 115 evictions and 35 resident pairs; no required-pair miss. Pressure run reclaimed more history and still kept up. |
| Completion against latest budget | Zero particle cancellations/failures and 150 completions. No discarded particle work observed. |
| Persistent-ID/channel estimator | Largest estimates changed from 72,832,768 then 119,049,152 bytes to 63,433,792 then 108,400,960; no sizing/admission failure. |
| Shared readiness / scheduler | Required particles were resident when transport waited; `field_playback.session_waiting` supplied the false return. |
| Eight-pair window / consumption | Four particle pairs/s at 2× versus 20 field samples/s. Particle completions kept ahead of the shared clock; prepared misses remained zero. |
| Fields starving particles | Field cache had RAM priority and substantial runway. Particle budget reductions occurred, but starvation was not reproduced. Field throughput/refill gating accounts for the observed waits. |

No first causal divergence producing particle starvation was found. A rollback
would remove useful particle-only caching and/or safety logic without addressing
the field gate reproduced on the earlier accepted baseline, so none is proposed.

## Pressure and memory uncertainty

An earlier candidate run with the same full-prefill protocol encountered actual
process swap. Its initial field cache was 29.76 GiB, peak RSS 36.11 GiB, peak
process swap 158,982,144 bytes and minimum particle budget 938,275,961 bytes.
At policy time 48.664242 s the existing automatic field policy changed from four
workers to one with reason `process_swap`. A hold at source 48.420108 s spanned
22.182 sampled seconds, followed by many shorter refills. The playhead still
reached 74.5 s (82.533 wall seconds after Play); particles completed 150 pairs
with zero misses/cancellations/failures, evicting 129 and retaining 21.

See [pressure summary](candidate-pressure-summary.json) and
[observations](candidate-pressure-trace.jsonl). This pressure case is retained,
not pooled into the no-swap comparison. The unchanged candidate repeat above
had no swap. The source of that run's additional memory pressure was not isolated.

A separate sequential [controlled exploration](merged-pressure-exploration-summary.json)
subtracted 16 GiB from memory snapshots (without allocating it), started after
three seconds and reached the end with automatic field refill holds and ready
particles. It checks conservative admission degradation, not real OS pressure
or the owner's full-prefill sequence. The small particle-cache regression also
forces budget reduction and verifies subsequent full-cache recovery.

RSS remaining high while cache-owned bytes fall does not prove allocator
retention or rule out a leak. Similarly, memory being released on process exit
does not exclude a leak during the process lifetime. No long-session allocation
study was done. The observed 12–13 GB cache alone cannot establish a leak.

## Focused validation

| Check | Result | Why included |
| --- | --- | --- |
| New mixed field barrier regression on unchanged merged baseline | 70 checks, **2 expected failures** | Demonstrates wrong blocker and Buffering tooltip before the fix. |
| Same maintenance suite, candidate headless | **70 checks, 0 failures** | Field/particle readiness, clock hold, pause/seek/cancellation boundaries. |
| Same maintenance suite, native Forward+ | **70 checks, 0 failures** | Production renderer and status integration. |
| Same maintenance suite, native Compatibility | **70 checks, 0 failures** | Alternate renderer and status integration. |
| Scene playback semantics, headless | **2,457 checks, 0 failures** | Shared particle/field pump and committed scientific sample behavior. |
| Particle cache, headless | **38 checks, 0 failures**, fixture SHA-256 unchanged | Particle-only full cache, constrained budget, recovery and scrub reuse. |
| Application version Python tests | **2 passed** | Sole version source proposes main build + 1. |
| Candidate editor import | Passed, no errors | GDScript/resource loading. Existing missing-resize-UID warnings generated unrelated files which were removed. |
| Final profiler wrapper, native Forward+ synthetic mixed fixture | Passed: requested end reached, no errors, source metadata unchanged | Final CLI, paused-fill detection and output contract. |

Retained logs: [baseline failure](maintenance-baseline.txt),
[headless](maintenance-headless.txt), [Forward+](maintenance-forward-plus.txt),
[Compatibility](maintenance-compatibility.txt), [scene playback](scene-playback.txt),
[particle cache summary](particle-cache-summary.json).

For the maintenance suite, generate fixtures as below, then run Godot's
`layers/test_performance_maintenance.gd -- --playback-fixture=/absolute/fixture/path`
with isolated `XDG_DATA_HOME`/`XDG_CONFIG_HOME`; add `--headless` or
`--rendering-method forward_plus` / `gl_compatibility`. That targeted script was
run directly; the separate lifecycle suite in the broader wrapper was not run.
Other commands were `tools/validate_scene_playback.py`,
`tools/validate_particle_cache.py` (both headless) and
`python -m unittest tests.test_application_version`. See the
[production profiling command and owner checks](../../MIXED_PLAYBACK_BUFFERING.md).

Fixture generation from the repository root (use a fresh output directory):

```python
from pathlib import Path
import numpy as np
from tools.validate_scene_playback import prepare
from wavez_export import SceneCapture
fixtures = Path('/tmp/mixed-review-fixtures')
prepare(fixtures)
with SceneCapture(fixtures/'field.wvz', objects=[dict(id='field', kind='volume', units='u')], compression='zstd') as writer:
    for time in [0, 1.25, 3.25, 4]:
        writer.add_volume('field', time, {'rho': np.full((4, 4, 4), time+1, dtype='f8')}, origin=[0, 0, 0], spacing=[1, 1, 1])
```

[Validation metadata](validation.json) also records the final profiler smoke
result and the before/after production-source metadata comparison.

## Corrected attempts and limits

- Early 1× runs began after three seconds and reached the end without later
  field holds. Early 2× runs identified the same field gate. One prototype
  stopped after 12 seconds without progress; that was its own timeout, not
  evidence of an indefinite viewer deadlock. Subsequent runs allowed 45 seconds.
- Two diagnostic runs with simulated 16/8 GiB reservations accidentally
  overlapped after a sandboxed process lookup failed to see native Godot.
  Both were stopped with host process visibility. They confounded RAM headroom
  and their cache sizes/timings are excluded. All four real-RAM runs retained
  above were sequential. The user was informed of the mistake.
- First headless regression attempts lacked writable isolated Godot settings
  and log paths. They were rerun with separate XDG paths; retained clean logs
  distinguish the baseline's two actual assertions from environment diagnostics.
- No Windows/macOS, packaged build, physical 4K/mixed-DPI, long soak, allocation
  profiler or whole-file payload verification was run. No simulation was rerun.
  Existing historical evidence was preserved. Broader camera, video/export,
  format and unrelated UI regressions were outside this diagnostic-only change.
- The supplied capture is about 54.3 GB, not a 150 GB capture. Findings are scoped
  to this file and tested conditions. More constrained real RAM could still
  expose another path; no universal no-starvation or continuous-2× claim is made.

Owner acceptance remains pending. Follow the five manual checks in the
[current investigation guide](../../MIXED_PLAYBACK_BUFFERING.md#owner-verification).
