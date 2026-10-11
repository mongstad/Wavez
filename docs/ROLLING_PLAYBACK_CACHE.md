# Rolling playback cache and prepared timeline — #106

Current timeline publication/display is specified in [Prepared timeline](PREPARED_TIMELINE.md).
Issue #378 supersedes the blue/teal drawing and throttled publication described
in this historical #106 report. The report's measurements, review-time wording
and original checks remain preserved below; cache scheduling policy is unchanged.


Implementation is **pending owner review**. #106, PERF-PLAYBACK-001, was the only
Ready item in SimScope Development when selected. The existing linked branch is
`106-perf-playback-001-visualize-prepared-timeline-ranges-and-extend-playback-with-rolling-cache-reuse`.
It began clean at accepted main `309ec00` (PR #129), including #103, #109 and #111.
The previous remote branch was pruned and the local #114 branch removed after its
tree was confirmed identical to the owner's squash merge. No implementation branch
was created or switched. Historical reports and review-time evidence are preserved.

## Behavior

Automatic field preparation previously checked live physical RAM before retiring
resident history. A low-headroom admission could enter pressure state before that
capacity was reclaimed. Adaptive startup preparation remains necessary to absorb
short-term production deficits during playback.

The coordinator now removes eligible obsolete/history entries before checking
physical admission, then rechecks actual headroom after each bounded reclamation.
If parallel scratch would cause pressure, active work drains before retrying with
one lane. Genuine shortages still wait: released allocator pages are never assumed
to be physical capacity. The existing RAM formula, transient allowances, source
checks, ordered publication and cancellation ownership remain in force.

Automatic eviction protects the committed visible sample, requested current and
next directional samples, staged textures' source preparations, and in-flight
jobs. It prefers unrelated source entries farthest from the new playhead, preserves
wanted current-generation runway, and mirrors when direction changes. New plans
follow every source-sample boundary and retry at least once per second. Immutable
job metadata is reused within the same source/channel/budget scope, and history
accounting stops once its bounded allowance is covered. Already
resident overlap is reused without hashing/decoding/preparing it again.

Resident history receives an allowance of at most 10% of the cache, targeting
1–3 playback seconds according to measured producer/consumer ratio and speed.
This reserves space for existing history without scheduling it again. Admission
pressure removes the allowance for ten seconds. Additional history can remain
while space is unused. A sharply reduced budget can temporarily be below protected
resident ownership; new work cannot publish above it and obsolete history is
released. The current scene is never destroyed merely to meet a new target.

Play reuses existing contiguous coverage through the #111/#113 adaptive gate:
three seconds for a measured producer at least 1.10× consumption, eight seconds
near parity (at least 0.95×), otherwise the admitted rolling window. Measurements
need three busy seconds at the current concurrency. Current/next samples remain
required, but no longer override the gate. Status reads the same decision.

While playing, a measured deficit reopens the gate when lead falls below two
seconds or predicted depletion is less than eight seconds away. Unmeasured
production also holds below two seconds. The one-second policy cadence therefore
has room to react before exhaustion. Speed changes recheck the gate. Waiting is
latched until the appropriate startup runway is rebuilt, reusing resident coverage;
a completed admitted window remains playable, including recording boundaries.
GPU staging retains its bounded target wait without resetting CPU-runway confidence.
Eligible history is also reclaimed before publication when the budget shrinks
during decoding, avoiding cancellation/recomputation of already-finished work.
The publication limit remains hard. Explicit advanced intervals retain their
complete-interval gate and eviction order.

## One overlay on the existing playback track

The existing native sample-index slider and playhead are retained. One four-pixel
buffered band sits behind its groove and grabber, using existing theme accents:
blue for selected visible field preparations, with teal over portions prepared for
all required visible layers. This includes independent particle pairs and mesh
pairs, not merely the field cache. Hidden layers do not restrict visible coverage;
settings changes and generation invalidation remove obsolete readiness.

Coverage derives from actual source timestamps and resident current-generation
keys. Gaps remain gaps, and intervals are intersected across required layers.
Source bounds map through the actual union timestamps onto the existing index
axis, including irregular cadences. Coverage touching either recording endpoint
fills to the track edge, including the native grabber padding; interior boundaries
follow the native handle axis. A gap of one or two unprepared samples can appear as
a black vertical line inside the band. It carries readiness information and is
retained without a separate tooltip explanation. Full coverage has no extra black marker.
Updates are limited to five per second and do not request work or mutate the caches.
Hover explains scope and colors. CPU
readiness does not guarantee zero GPU staging delay or universal uninterrupted FPS.

SIMSCP4, payload-integrity policy, source values, channels, precision, clocks,
rendering fidelity, particle/mesh scheduling and offline export semantics are
unchanged. No new dependency or runtime is bundled.

## Validation

The measurements below describe the initial `9130336` review checkpoint. Its
production traversal prefilled the admitted window before Play and therefore did
not test immediate-Play runway gating. The owner's reported regression prompted
the [adaptive-runway follow-up](PLAYBACK_RUNWAY_REVIEW.md), which compares immediate
Play against accepted main and this initial PR checkpoint. Historical measurements
and evidence below remain unchanged.

2026-09-28, Linux, Godot 4.7.2, NVIDIA RTX 3070 Ti, 46.94 GiB physical RAM.
The [validation ledger](evidence/issue-106/validation.json) records **9,285 focused
checks plus 36 production checks, all passing** (9,321 total):

| Suite | Headless | Forward+ | Compatibility |
| --- | ---: | ---: | ---: |
| Rolling cache / coverage / rendered endpoint | — | 72 | 72 |
| Field session / all-channel reuse | 330 | 342 | 332 |
| Adaptive cache | 73 | — | — |
| Parallel preparation | 1,800 | — | — |
| Concurrency policy | 94 | — | — |
| Viewer status | — | 231 | 231 |
| Viewer transport | — | 204 | 204 |
| Field budget | — | 56 | 56 |
| Scene playback | 2,457 | — | — |
| Mesh playback | 2,731 | — | — |

Checks cover a whole fitting recording, partial windows, directional pressure,
protected ownership, early Play inside prepared coverage, repeated seeks/reversals,
selected-channel source hashes and reuse, independent particle clocks, invalidation,
and teardown. Full-coverage endpoint pixels pass on both renderers: the previous
8 px thumb-padding gap is removed. The [synthetic screenshot](evidence/issue-106/full-coverage.png)
shows the single band. A separate [rendering diagnostic](evidence/issue-106/coverage-gap.png)
compares complete coverage, a narrow unprepared gap, and keyboard focus: only the
real gap draws a dark vertical line; it is not a decorative marker.

### Production capture larger than RAM

Read-only input: `SIMSCP4_D192_T200_simscope.ssc`, 125,950,754,101 bytes,
1,566 full-resolution 192³ field samples with three channels and 627 particle
samples. Its source extent is 0–156.5. Natural Automatic preparation had no test
cache ceiling. Initial preparation took 28.087 s and retained 299 samples covering
0–29.8, with a 29.9 s prepared lead. The isolated Forward+ run then traversed the
complete recording in both directions:

| Measurement | Forward 1× | Reverse −1× |
| --- | ---: | ---: |
| Source traversal | 0 → 156.5 | 156.5 → 0 |
| Traversal wall time | 156.526 s | 156.518 s |
| Explicit buffering holds / duration | 0 / 0 s | 0 / 0 s |
| Prepared publications during traversal | 1,267 | 1,319 |
| Evictions during traversal | 1,321 | 1,336 |
| Interior prepared-ahead lead | 17.93–23.73 s | 11.90–18.59 s |
| Interior retained history | 1.24–2.17 s | 2.00–3.80 s |

Interior ranges above use source times 35–120 to exclude recording endpoints.
At a boundary, already-prepared history remains while no further runway needs
its space. Source ranges roll from `[0.5,30.7]` to `[132.1,156.5]` in forward
snapshots, then from `[131.1,156.4]` to `[0,22.9]` in reverse snapshots. Detailed
selected timestamps, coverage islands, budgets and eviction-tail ranges are in the
[production summary](evidence/issue-106/production-summary.json).

During traversal, the adaptive budget ranged from 13.97–32.44 GiB and charged
cache ownership from 13.72–31.98 GiB. Peak process RSS was 36.06 GiB, minimum
sampled available physical RAM 5.17 GiB, and sampled process swap stayed zero.
By the final seek/channel checks: 2,716 evictions, 525 cancelled jobs, 3,133 cache
acquisitions and two compatible source reuses were recorded. Retained seeks caused
no repeated source read; a distant seek prepared explicitly and committed the
requested scene. Python independently matched density/psi_real/psi_imag hashes
for source sample 800, and source file stat identity remained unchanged.

The four-lane aggregate producer rate was 10.10 samples/s versus 10 samples/s
consumption. Other lane counts accumulated 5.53/8.16/9.34 samples/s for 1/2/3
lanes in differing conditions; this is not a matched scaling benchmark. The
starting cache absorbs temporary producer shortfalls. Zero controller holds is
not a guarantee about frame latency or different hardware/captures.

Natural traversal reclaimed history through the budget limit before physical
admission pressure occurred: its pressure-event count was zero. Separate tests
with actual production payloads tightened only the worker's available-headroom
observation. In each direction, admission automatically evicted two historical
samples (216.13 MiB), preserved the committed/current-next pair, and published
two new samples without an external retry. The worker retained 540.31 MiB under
a 756.44 MiB ceiling. With no eligible capacity remaining, it waited safely and
resumed after headroom recovery. These controlled cases verify the pressure path;
they do not claim reproduction of uncontrolled operating-system exhaustion.

Strict complete-file verification passed **all 2,193 records in 336.03 s**,
including descriptors, commit proofs, decoded payload checksums, sample constraints
and required field statistics. This is independent of interactive playback's
structural checks. Exact output is in the validation ledger.

### Development failures and remaining limits

- An exploratory production run overlapped other native validation and reached
  roughly 2.89 GB process swap. It was stopped and excluded from performance
  conclusions; the final run above was isolated.
- An initial eviction-order change broke six advanced-interval checks. Restoring
  its established order resolved them. Old whole-window startup expectations were
  updated for prepared-region startup, and worker-barrier status checks made
  deterministic. Explicit invalidation now uses a serial so identical settings
  cannot reacquire preparations from an invalidated generation.
- The first endpoint pixel assertion used an excessively strict 0.01 color
  tolerance; rounded-border antialiasing differs by about 5/255. The 0.03 check
  passes both renderers and still detects the former 8 px gap.
- Initial sandboxed editor import could not access native sockets/settings;
  permitted native import passed. Python helper compilation and whitespace checks
  passed. No new dependency was introduced.
- Production traversal was measured on Forward+ only. Compatibility has focused
  native checks, but exact float GPU readback remains a known Godot/NVIDIA limit;
  prepared-plane/source hashes are checked there instead. Other hardware, OSes,
  physical DPI settings, cold filesystem cache, and a production p99 frame-latency
  benchmark were not tested. Natural OS exhaustion and universal smooth playback
  are not established. Owner acceptance remains pending.

Reproduce using external Godot and the project Python environment, with fresh
output directories:

```sh
python tools/validate_rolling_cache.py --godot GODOT --output-dir OUTPUT --renderer forward_plus
python tools/validate_rolling_cache.py --godot GODOT --output-dir OUTPUT --renderer gl_compatibility
python tools/profile_rolling_cache.py --godot GODOT --capture CAPTURE.ssc --output-dir OUTPUT --renderer forward_plus
```

The production profiler runs full 1× forward and reverse traversal, retained/distant
seeks, channel reuse, and controlled pressure with actual production payloads. Its
controlled per-worker headroom observation can only tighten real physical admission;
it does not consume unrelated RAM or modify operating-system settings. Natural
system-pressure observations and these forced cases must be reported separately.
Python independently compares all source channels for its reported sample and
checks source stat identity. This is distinct from full-file strict verification.

## Owner verification

1. Open the production capture with Automatic preparation and inspect the single
   buffered overlay on the playback track. The native playhead must remain clear.
   Hover for the blue/teal meanings; toggle particles and visible layers to confirm
   the all-layer coverage changes appropriately.
2. Seek inside blue coverage, allow the requested visible layers to commit, and
   press Play at 1×. Resident preparations must be reused; playback begins when
   the adaptive runway gate is satisfied, without preparing the whole recording.
3. Let playback pass the initially prepared end. Inspect Performance/Details and
   confirm historical entries are reclaimed and future coverage advances. A real
   throughput shortage may buffer; it must recover without manual restart when
   required data becomes available.
4. Set speed to −1×. Verify the window rolls backward and old forward entries are
   reclaimed. Seek into retained history, then beyond it, and repeat rapid seeks
   and reversals. The final requested scene must win.
5. Switch density / psi_real / psi_imag. Check exact selected-channel presentation,
   updated overlay, full resolution, and compatible source reuse. Reopen a capture
   and verify old coverage disappears.
6. Check Loop at both recording boundaries and a selected advanced interval. Repeat
   at the preferred window size/UI scale and with the Compatibility renderer.
   Approve/merge only after owner review.
