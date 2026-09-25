# SSC loading and preparation profile

Issue #100 / PERF-FIELD-005, top Ready verified 2026-09-25. Pending owner review.
Baseline: accepted main `d42a4dc`, including owner-merged #98 / PR #99.

## Workload correction and method

The issue describes an N=192 capture, but the supplied file records a **128³**
volume. The owner confirmed that this exact slow file should be investigated.
These are production **128³** results, not measured N=192 results:

`~/Documents/VB_FreeCollapse_v0_2/VB_FreeCollapse_v0_2/runs_free_collapse_v0_2/S0_20260925_060202_938955/free_collapse_simscope.ssc`

- 14,878,413,684 bytes (13.86 GiB), 864 records.
- 617 field samples, three float32 channels: density, psi_real, psi_imag.
- First field: 25,165,824 decoded bytes (24 MiB), selected preview 8 MiB.
- 247 particle samples, 50,000 persistent-ID particles; 4,200,000 source bytes
  per initial particle sample.
- Source SHA-256:
  `c76d2cc2e9909dcfac5ed90a5526c8873cafb4b3d0d37ea949b135fe4a27e22a`.

Godot 4.7.2, NVIDIA RTX 3070 Ti, about 47 GiB physical RAM. Baseline and optimized
runs used separate native processes, sequentially, on each renderer at 1280×800.
An isolated archive of accepted main carried the same profiling instrumentation.
Filesystem caches were warm; integrity hashing was outside the timed section.
No cache flushing, SSD benchmark or scientific solver rerun was performed.
The existing direct-read measurement supplied with the issue remains historical
context, not a new result from this work.

Timing starts when the viewer is attached to the scene tree, including its UI
setup and synchronous open. It excludes executable startup and asset import.
First draw is observed at `frame_post_draw`. Playback readiness is measured by
pumping the normal automatic preload controller. The window can display/respond
before full particle preloading finishes; playback-ready time is not all UI
blocking time. Source-oracle hashing happens after the readiness timestamp.

## Before/after results

| Metric | Forward+ before | Forward+ after | Compatibility before | Compatibility after |
|---|---:|---:|---:|---:|
| Viewer setup/open returns | 4.783 s | 3.777 s | 4.655 s | 3.678 s |
| First draw | 4.803 s | 3.797 s | 4.696 s | 3.713 s |
| Automatic playback ready, total | 26.265 s | 22.089 s | 26.028 s | 21.515 s |
| Prebuffer wait after first draw | 21.462 s | 18.293 s | 21.332 s | 17.801 s |
| Index reload, inclusive | 3.923 s | 2.914 s | 3.866 s | 2.869 s |
| Descriptor validation | 2.154 s | 1.193 s | 2.146 s | 1.164 s |
| Worker ID lookup validation/construction | 3.647 s | 0.021 s | 3.657 s | 0.022 s |
| Peak process RSS (`VmHWM`) | 4.904 GiB | 3.647 GiB | 4.585 GiB | 3.340 GiB |

This paired run improved total readiness by **15.9% / 17.3%**, and open-return time
by about **21%** on both renderers. A subsequent production verification run
reached readiness in 21.610 s / 21.536 s. Initial Forward+ baselines were 26.464 s
(with oracle hashing still inside the readiness interval) and 25.913 s with
added stage timers; the paired table uses the corrected common harness.
These are observed local runs, not throughput guarantees or statistical bounds.

## Bottlenecks and focused changes

**Automatic full particle preparation dominated startup.** The existing policy
chose a full 247-pair preload because its conservative approximately 16.2 GiB
allocation estimate fit safe RAM. The baseline worker spent approximately
9.7–9.9 s decoding/checking particle data and 8.4–8.6 s preparing pairs. Within
those inclusive costs, ID lookup construction took about 3.65 s, style packing
about 6.2 s, payload hashing about 4.5–4.6 s, ID matching about 2.3 s and display
frame conversion about 1.8 s. Worker file reads were roughly 0.1 s with warm
filesystem caches; these timings do not suggest an SSD bottleneck.

The same ordered particle IDs were rebuilding an identical dictionary in every
sample. The worker now borrows an already resident neighboring decoded sample.
Only after exact `PackedInt64Array` equality, and confirmation that the prior
identity lookup is immutable, does it share that lookup. All stored/raw payload
checksums still run. Reordered or changed IDs build/validate a fresh map. The
production run reused 246 lookups. There is no new persistent cache, changed LRU
order, relaxed cache charge, preload-policy change, or additional worker thread.

The smaller actual RSS reflects avoided duplicate dictionaries. Decoded and
prepared cache charges intentionally remain conservative and **unchanged**,
even for shared maps; Performance cache budgets are not process RSS limits.

**Descriptor validation was the largest synchronous-open stage.** Each field
record carries many brick offsets and checksum strings. GDScript iterated over
every checksum/decimal character. Native string predicates now do that work,
with explicit lowercase/unsigned/no-prefix restrictions for hex and the existing
canonical integer round-trip and length bounds for decimal. Chunk shape, coverage,
allocation limits, stored/raw checksums and commit proofs are unchanged. Exact
old/new grammar parity is tested for boundary values, malformed strings, character
substitutions and deterministic random inputs.

**Field preparation was smaller for this file.** The instrumented baseline used
about 0.32 s for source statistics, 0.005 s for selected-plane allocations/copies,
and 0.004 s for texture upload. Source field/particle decode during first display
was about 0.17 s combined. Float32-to-float64 source conversion was not needed;
the recorded field stays float32. These costs were measured, not optimized.
Color/opacity range and scientific sample semantics remain unchanged.

Other index costs remain: descriptor JSON parsing about 0.69 s, index-envelope
serialization about 0.78 s, timestamp sorting less than 1 ms. Inclusive index
scanning also contains descriptor reads, hashes, trailer proofs and record
allocation. The worker timings include allocation/conversion overhead in their
owning stages; this is not an allocator-level or GPU-fence latency profile.
Nested stage timings overlap and must not be summed as independent wall time.

## Diagnostics and remaining opportunities

The existing Performance cache readout now includes the last index duration.
Opt-in profiling adds descriptor parse/validation, timestamp/cache serialization,
field statistics, conversion, plane-copy and texture-upload stages. Field timing
collection remains local on the CPU worker; it never mutates the shared main-thread
profiler. The main thread records local results when doing synchronous preparation.
Existing particle worker events distinguish identity reuse from construction.

Remaining costs include unavoidable checksum verification and CPU style/ID-match
work under the existing full-preload policy. Future work could investigate style
packing, index representation/serialization, or an explicitly reviewed startup
policy. None is silently changed here. Initial field data may still be separately
decoded/prepared for the bounded async queue; its smaller cost did not justify a
new cross-cache ownership mechanism in this issue. GPU uploads are already small.
No unbounded field prefetch or eager all-timestamp field preparation was introduced.

The available alternate retained capture is also 128³. No retained production
192³ comparison was established. The voxel ratio 192³/128³ is 3.375, but total
startup is dominated here by particle sample count and preload work, so it is not
valid to multiply total startup time by that ratio. Synthetic 192³ capacity and
scientific regressions pass; they are not a production scaling benchmark.

## Validation

[Compact evidence](evidence/issue-100/validation.json) contains the paired timings,
source proof, scientific hashes, cache-policy comparison and test results.
Raw JSON, logs, temporary captures and the isolated baseline remain under
`/tmp/issue100`, outside Git.

- New grammar/identity suite: **26,406 checks**, zero failures. Includes int64 IDs
  above 2⁵³, reordered/changed IDs, immutable lookup sharing, duplicate/negative
  rejection and unchanged memory accounting.
- Production capture, both renderers: canonical Play/Pause, paused clock, forward
  and backward seeks, resume, particle/field cache bounds and staging checks pass.
  First-field hashes, statistics and full-resolution preview match baseline.
  Full-file SHA-256 matches before/after on both renderers.
- Scene playback: **2,457 checks per renderer**, zero failures.
- Maintenance/lifecycle: **66 + 51 checks per renderer**, zero failures.
- Field budget, including synthetic 192³: **56 checks per renderer**, zero failures.
- Existing field preparation with generated float64 plume oracle: **32 checks per
  renderer**, exact source/probes and identical async/sync volume/slice pixels.
- Volume opacity: **98 checks per renderer**, plus actual MP4 export with identical
  interactive/export pixels, preserved mapping sidecar and unchanged source.
- Recipe restoration: **2,697 headless checks**; mesh: **2,731 headless checks**;
  native multichunk: **48 checks**; Python storage contract/chunks: **5 tests**.
- Godot import/UID generation, Python compile and diff whitespace checks pass.

The volume-color suite still has **two failures out of 138 checks per renderer**:
GPU logarithmic midpoint and slice logarithmic semantics. Both were reproduced
on accepted main `d42a4dc` in this investigation and are not introduced here.
That suite stops before its export phase; the independent opacity/export suite
passes. This branch does not change color shaders or claim to fix those failures.

An initial profiling-script type syntax error was corrected before measuring.
The first new grammar test run passed its assertions but had sandbox log-path and
NUL-output errors; the final runner uses an explicit writable log path and valid
Godot string inputs. No such errors remain in the final runs.

## Reproduction and owner checks

```sh
python tools/profile_field_load.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse_simscope.ssc \
  --renderer forward_plus --output-dir /tmp/ssc-load-forward --exercise
python tools/profile_field_load.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse_simscope.ssc \
  --renderer gl_compatibility --output-dir /tmp/ssc-load-compat --exercise
python tools/validate_load_optimizations.py --godot /path/to/godot \
  --output-dir /tmp/ssc-load-regression
```

Use fresh output directories. For before/after comparisons, place the profiling
harness and instrumentation in an isolated accepted-main archive and pass
`--viewer /absolute/path/to/archive/viewer`; do not switch the implementation
branch. No raw capture is copied into Git.

Owner verification:

1. Open the confirmed production capture and distinguish first display from the
   subsequent “Preparing playback” interval. Inspect the last index time in
   Performance; expect a remaining full-preload wait, not instant readiness.
2. After preparation, Play, Pause, seek forward and backward, and resume. Check
   particles, field sample time, density/psi channels and source probes.
3. Change field color/opacity settings, restore a saved recipe, and export a short
   clip. Compare with the accepted visual/scientific result.
4. Repeat with Compatibility if used. Report actual timings and Performance
   details for any capture that still behaves differently.

One PR targeting main; stop for owner acceptance. No merge or Project transition.
