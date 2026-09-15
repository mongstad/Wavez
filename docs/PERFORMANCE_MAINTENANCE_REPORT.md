# PERF-001 / PERF-002 maintenance review

Implemented **2026-09-13** against accepted maintenance baseline
`ed2ac2ad485fa0679d61afcd0b044092fc669ef9`. **Reviewed and accepted by the user on 2026-09-13.**
Accepted implementation checkpoint: `008e13f` (PERF-001 and PERF-002).
Package version remains 1.0.0. G5/G6 remain unstarted. Both retained benchmark
captures were read without rerunning their scientific generators; before/after
SHA-256 checks confirm unchanged capture bytes.

## PERF-001: automatic particle cache selection

The default menu choice is now **Automatic (safe RAM)**; the existing `adaptive`
policy key remains valid. Before preparing payloads, the controller examines every
sample descriptor and estimates the decoded samples and prepared frame pairs.
The estimate includes decoded channel bytes, particle counts, exact identity maps,
display/mapping arrays, frame count and enabled trail history. It deliberately
counts some shared references twice. Compressed file size alone cannot establish
whether prepared data fits. There is no benchmark- or simulator-specific product logic.

Full preload is selected when:

```
ceil(1.25 × (estimated decoded bytes + estimated prepared-pair bytes))
    + 2 × largest estimated pair
    <= safe cache allowance − ordinary decoded-cache limit − 256 MiB
```

The additional 256 MiB reserves field preparation/active data. Automatic full
preload waits for every pair before enabling Play, so it does not begin with an
inadequate short window. On 02B, the estimate including margin and working space
was **4,348 MiB**, below the **18,716 MiB** allowance after other cache reservations.
All **61 pairs** were prepared automatically in **4.878 seconds** after the
measurement harness requested startup preparation. This is conservative cache
accounting, not predicted process RSS.

When the estimate does not fit, the controller uses a rolling cache capped at
2 GiB combined decoded/prepared charge, split equally. The rolling target is at
most eight pairs, reduced according to pair size while leaving space for two
still-displayed/previous pairs. Startup normally requires four pairs, shortened
by capacity or the endpoint. A pair that cannot fit safely pauses preparation
with a diagnostic rather than allocating beyond the limit.

Manual 512 MiB / 2 / 8 / 16 GiB rolling choices remain. Explicit **All particle
pairs, if safe** still supports its earlier four-pair startup while completing
full preparation in the background. All manual choices respect the safety guard.
Source generations, append changes, display settings and policy changes cause
re-estimation. Policy, selected strategy, estimate, actual charges, limits and the
selection/fallback reason are available in diagnostics.

## Memory guard and runtime behavior

`memory_headroom()` uses physical RAM and, on Linux, `/proc/meminfo`'s
`MemAvailable`, excluding swap. Its safe cache allowance is:

```
max(0, min(40% of physical RAM,
           available physical RAM − max(2 GiB, 15% of physical RAM) − 1 GiB))
```

Other platforms conservatively use reported physical/free memory, not an
available-memory number that might include swap. Missing usable RAM information
cannot authorize full preload. The particle controller additionally deducts the
other scene caches and transient pair space as shown above. Workers check current
physical headroom before each preparation job. Full-preload runtime budget or RAM
refusal automatically switches to a rolling window; persistent insufficient RAM
pauses further preparation. Unexpected prepared-size overflow cannot repeatedly
evict and rebuild a supposedly complete preload. Reducing a manual budget now
reclaims resident decoded/prepared caches even when every requested pair is a hit.

These are conservative allocation guards, not a hard process-RSS or whole-machine
memory guarantee. Renderer/driver allocations, source references retained for the
committed display, other applications and budget-change overlap have distinct
lifetimes. All six final runs reported **0 bytes of process VmSwap at completion**;
this is not a continuous system-wide swap measurement.

## PERF-002: field preparation and upload staging

Interactive SIMSCP3 fields now use a separate low-priority CPU thread with a
private file handle. The shared checked channel decoder validates stored/raw
checksums and bounded Zstandard frames. Native source arrays remain float64 where
recorded; float32 conversion, preview reduction and RF image-plane construction
happen on the worker. Workers do not mutate scene nodes, GPU textures or the global
main-thread profiler. Immutable results publish under a short mutex. Source stamp,
generation and channel/preview configuration checks reject stale publications.

The CPU request queue prioritizes the current held sample and **up to four future
source samples per visible field**, respecting reverse playback and loops. The
LRU may retain additional history within its byte cap. Its cache limit is
`min(128 MiB, safe_cache_bytes / 4)`; another 128 MiB is reserved for active/in-flight
field data. Charges include source bytes, estimated preview-plane bytes and
64 KiB overhead per frame. Required visible target charges must fit half the
CPU cache limit; queued charges cannot exceed the full limit. The worker also
requires physical headroom for three times an incoming frame's charge. Requests
that cannot fit report a refusal; a resident current sample remains usable when
future prefetch is refused. The ordinary decoded-cache slider controls synchronous
reads; this separate bounded preparation cache still operates at **0 MiB** on that
slider.

**Uploads use one staged future texture per visible field, with at most one GPU
upload per process frame across the queue.** They are scheduled ahead when CPU
results are ready. Current and staged textures split the existing per-layer GPU
share, so large interactive fields may use a coarser preview stride. After a
configuration/budget change, the old committed texture may survive until its
replacement is ready. The CPU queue is deeper than the GPU staging slot; there is
no full-capture GPU preload. Binding an already staged texture happens when the
sample's physical time is actually committed.

Texture creation and shader/binding changes remain on the main thread, following
[Godot's thread-safety guidance](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html).
In final 03B runs, staged upload calls had maxima of **0.638 ms** (0 MiB decoded
cache) and **0.631 ms** (256 MiB), with p95 **0.200 / 0.244 ms**. Large uploads can
still stall a callback; this work does not claim asynchronous GPU transfer or
universal large-volume frame rates.

Cold seeks/underflow preserve the committed sample and physical clock. Field
buffering disables Play and pauses G4 background analysis, including field-only
captures. Picking also respects combined particle/field buffering. Rapid seeks,
hidden fields, source replacement and synchronous scientific inspection cancel
or supersede obsolete work. Mesh reads, initial opening, explicit scientific
inspection and deterministic export remain synchronous. Source precision, held
field semantics and independent object clocks are unchanged.

## Final retained regression measurements

Sequential before/after runs used the same harness and retained captures, Godot
4.7.2 (`ed1daf0bf`), OpenGL Compatibility, NVIDIA RTX 3070 Ti / driver 610.57.04,
1280×800, VSync off, physical rate **1×**, looping and no trails. The baseline is
an isolated `git archive` of `ed2ac2ad`; the current viewer uses its default
particle policy. Worker/integration tests were not run concurrently with timing.
OS disk/page-cache state was not flushed and the desktop was not otherwise
isolated. Callback rates are application callbacks, not monitor FPS or GPU timing.

### 02B: 16-second particle playback

| Measurement | Before: default rolling | After: automatic full preload |
|---|---:|---:|
| Startup preparation | 0.679 s | 4.878 s |
| Buffering during playback | 4.559 s | **0 s** |
| Completed displayed wraps | 7 | **10** |
| Source transitions | 342 | **477** |
| Prepared pairs retained at end | 34 / 61 | **61 / 61** |
| Prepared-pair evictions | 409 | **0** |
| Callback p99 | 10.173 ms | 10.368 ms |
| Maximum callback | 15.856 ms | 15.142 ms |
| Callbacks ≥50 ms | 0 | 0 |
| End process RSS | 1,127.89 MiB | 1,204.50 MiB |

The benefit is uninterrupted playback after a longer automatic preparation wait,
not faster particle packing. A frozen clock can generate many inexpensive
callbacks during underflow; its higher raw callback rate is not better playback.
Both runs visited all 60 retained intervals, and the complete terminal pair was
prepared automatically. Generic endpoint semantics are covered by the existing
synthetic tests.

### 03B: 12-second field playback

| Measurement | Before, 0 MiB | After, 0 MiB | Before, 256 MiB | After, 256 MiB |
|---|---:|---:|---:|---:|
| Callbacks/s | 94.69 | **355.64** | 239.36 | **354.96** |
| Callback p95 | 48.566 ms | **2.889 ms** | 4.995 ms | **2.872 ms** |
| Callback p99 | 49.363 ms | **5.901 ms** | 48.564 ms | **5.919 ms** |
| Maximum callback | 55.347 ms | **6.431 ms** | 51.377 ms | **6.485 ms** |
| Callbacks ≥50 ms | 3 | **0** | 10 | **0** |
| Buffering | 0 s | 0 s | 0 s | 0 s |
| Source transitions | 119 | 119 | 119 | 120 |
| Displayed wraps | 2 | 2 | 2 | 3 |
| End process RSS | 260.10 MiB | 385.68 MiB | 339.60 MiB | 387.46 MiB |

The last wrap can fall just before/after the timer boundary. Every run traversed
all 40 intervals. All **41 frames**, including the final endpoint, independently
passed source, float32 preparation and probe checks. The new CPU cache retained
**125.5625 MiB / 128 MiB**, with 41 completed frames and no evictions. Extra memory
in the 0 MiB case is the explicitly bounded field preparation cache, not a failure
to honor the synchronous decoded-cache control. Before's zero particle buffering
flags did not detect synchronous field stalls; after records combined field and
particle underflow.

The historical 02B and 03B benchmark reports remain unchanged. An initial timing
pass showed the same improvement (02B buffering 4.66→0 s, default-cache 03B p99
48.25→5.94 ms); the tables above use the final code and final measurement pass.

## Validation and evidence

| Check | Result |
|---|---|
| Existing asynchronous particle/mixed-scene semantics | 2,457 checks PASS |
| Maintenance policy, boundary, manual shrink, worker, underflow and source replacement tests | 66 checks PASS |
| Existing lifecycle: append, cancellation, reverse, loops, legacy switch | 38 checks PASS |
| Retained 03B exact source/float32/probe checks, headless | 452 checks PASS |
| Retained 03B source/probes and volume/slice image equivalence | 459 checks PASS on each of OpenGL and Vulkan |
| Existing particle image/source/identity equivalence | 4 checks PASS on each renderer |
| Existing multi-chunk typed decoder interoperability | 48 checks PASS |
| Existing G4 temporal worker integration | 23 checks PASS |
| Final retained performance and memory assertions | 18 checks PASS |
| Documentation links and modern API examples | No broken local links; 3 examples PASS |

Lifecycle waits now check combined buffering so their original clock assertions
also cover field preparation. Early integration runs exposed a mixed seek handoff
and the resident-cache budget reduction issue; both were fixed. Early harness
parse/type failures were corrected, and a sandbox GPU attempt lacked display
access; those attempts are not counted as acceptance. Final logs are checked for
both failure return codes and Godot `ERROR:` output.

Compact summaries, code/source hashes, test-result hashes and command scope are
in [validation.json](evidence/performance-maintenance/validation.json). Raw timing
rows, logs, generated fixtures and images remain locally under
`results/perf-maintenance/`, excluded from Git. The 15 pre-existing untracked
Godot UID files are preserved.

Reproduce synthetic maintenance checks:

```sh
python tools/validate_performance_maintenance.py --godot /path/to/godot --output-dir results/perf-check
python tools/validate_scene_playback.py --godot /path/to/godot --output-dir results/perf-playback
```

For before/after timing, create an isolated baseline using `git archive ed2ac2ad`,
copy `viewer/layers/profile_maintenance.gd` into its viewer/layers directory, then:

```sh
python tools/validate_performance_maintenance.py --godot /path/to/godot \
  --output-dir results/perf-retained --renderer gl_compatibility \
  --baseline-viewer /path/to/baseline/viewer --benchmark-root /path/to/SimScope-Benchmarks
```

For the retained field oracle/images, run `layers/test_field_preparation.gd` with
`--field-job=/absolute/path/job.json`. The job contains `capture` (03B field.ssc),
`oracle` (03B simscope/oracle.json), and `output` (a fresh checks.json path). Use
`--rendering-method gl_compatibility` or `forward_plus` for image checks;
`--headless` covers source/preparation/probes only. The benchmark assets must
already be present; no scientific rerun is part of these commands.
