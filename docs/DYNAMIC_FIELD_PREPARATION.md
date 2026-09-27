# Dynamic field preparation — issue #111

Implementation and validation are **pending owner review**. #111 was the only
Ready item when selected. Work uses the owner's existing linked branch based on
`7dc253e`, the accepted PR #110 merge. Historical #102/#107/#109 reports and their
review-time wording remain unchanged. No #106 timeline UI or capture-format work
is included.

## Controller and ownership

Unset, `auto`, or an invalid `SIMSCOPE_FIELD_WORKERS` value selects Auto. The pool
cap is `clamp(logical_cpu_count - 2, 1, 4)`, reserving logical CPU capacity without
inferring physical cores or using model names. Auto starts with two active lanes,
or one when capped there. Explicit `1`, `2`, `3`, or `4` selects that fixed cap for
diagnostics. The live allocation guard applies in every mode.

The existing coordinator, persistent low-priority lanes, ordered publication,
source checks, cancellation and generation rules remain authoritative. Only the
number dispatched in the **next batch** changes. A reduced target cannot revoke
ownership of an already dispatched job. Its arrays/results stay charged until
collected or cancelled. There are no new job queues, extra workers, scene-tree
operations on workers, GPU uploads on workers, or changes to source decoding.

The main thread samples the policy once per second. Busy batch wall time includes
descriptor/admission work, decoding, preparation and collection. Successful
publication counts and busy wall time are grouped by actual batch size. The
controller smooths observations with weight 0.35 after at least 0.5 seconds of
new work. Idle time does not lower the producer estimate. A lane change or source/
channel generation change discards the old estimate and requires new observations.

The consumer estimate sums each visible field's local source cadence (up to 16
samples either side of the playhead) multiplied by absolute playback speed.
Prepared lead is contiguous cached coverage in the current direction, divided
by playback speed. It follows independent clocks, held samples and loop wrapping;
the least-covered visible field determines the lead. Sparse/variable cadences and
changing per-sample costs remain estimates, not a promised service rate.

| Decision | Condition / reason code |
|---|---|
| Add one lane | At least two measured busy seconds, three seconds since the last change, lead below 15 wall seconds, producer below 1.15× consumption, safe headroom; `producer_below_margin` |
| Urgent startup/seek | Same measurement/cooldown/headroom checks, waiting with less than three seconds of lead; `startup_or_seek` |
| Reduce by one | At least 30 seconds of lead and not waiting; `comfortable_lead`, then ten-second cooldown |
| Reduce to one | Physical headroom below current transient requirement plus margin; `memory_headroom` |
| Reduce to one | Detectable process swap or a new coordinator admission refusal; `process_swap` / `admission_pressure` |
| Presentation backoff | Two consecutive one-second windows with p95 callback/observed tick interval above 66.667 ms; `presentation_pressure`, one lane per pressured evaluation |
| After pressure | No scale-up until ten seconds after the last pressure observation |
| No queued preparation | No growth; all idle lanes sleep on semaphores |

The frame signal includes main callback time and time between callbacks, so it
can detect scheduling/render delays without claiming GPU-time attribution.
CPU utilization is recorded by the Linux profiler; the portable production policy
uses logical CPU count, producer rate and responsiveness. Short noisy measurements
do not establish reliable marginal throughput attribution, so there is no hardware
table or separate optimizer probing arbitrary worker counts.

## Memory remains a hard admission constraint

The #109 live scratch and retired-batch reserves use the **pool cap**, even after
downscaling. The largest admitted job remains the retirement basis until close.
Reducing active lanes never turns recently freed allocator pages into cache credit
or releases reservations for in-flight work. The controller checks physical RAM
after system/renderer, other-cache and retired-batch reservations, then requires
three job charges per active lane plus `max(256 MiB, 1% physical RAM)` spare before
holding/growing concurrency. The worker independently rechecks live headroom at
each admission and immediately lowers the Auto dispatch target on refusal.

Existing adaptive capacity, resident-array credit, exact cache charges and GPU
current-plus-one staging are unchanged. A capacity refresh can reduce the target
limit while an admitted batch drains; publication rejects over-budget results and
the coordinator prunes retained entries. Tests assess the settled bound, and raw
telemetry keeps those temporary transitions visible. Swap is never capacity.
Linux process swap is detectable; other platforms retain physical admission but
do not gain Linux `/proc` telemetry. Arbitrary external allocations, containers'
memory/CPU quotas and OS allocator retention remain outside a strict RSS guarantee.

## Startup and renewed buffering

Automatic preparation still starts on open while the first scene is usable.
Pressing Play requests continuous playback with these gates:

| Measured producer / consumer | Required coverage |
|---|---|
| At least 1.10 | At least three seconds of playback lead |
| 0.95 to below 1.10 | At least eight seconds of playback lead |
| Below 0.95, or fewer than three measured busy seconds at the current concurrency | Entire currently admitted window |
| Admitted window already ready | Start without waiting for a throughput estimate |

These are workload-independent initial thresholds validated against the measured
capture and synthetic boundary cases. Measuring after successive scale-ups can
produce more lead than the minimum. The finite admitted window is the existing
RAM-bounded window, not a claim that an over-RAM capture has been preloaded.
Advanced explicit intervals retain their full-interval preparation contract.

Speed changes with an insufficient producer, a lead below one second with an
insufficient producer, or a missing CPU-prepared sample reopen the gate. A pending
GPU upload keeps its existing bounded target wait without reopening this gate. The
committed scene/clock remains held while preparing. A seek can publish its target
while continuous playback builds runway. Channel changes reset production-rate
confidence while retaining compatible scientific arrays. Gate release is latched;
minor fluctuations around 1.10 do not repeatedly stop already-safe playback.
This cannot make a slower producer sustain unlimited playback. At higher speeds,
rebuffering and a slower overall run remain legitimate outcomes.

## Measurement and validation

The comparison uses the same external read-only 125,950,754,101-byte SIMSCP4
capture as #109: 1,566 three-channel 192³ float32 field samples, 627 particle
samples, t=0–156.5. Native Godot 4.7.2, Linux, Ryzen 7 5800X (16 logical CPUs),
46.94 GiB physical RAM and RTX 3070 Ti; Forward+ at 960×640, Scientific view,
point particles, orbit disabled. No solver or exporter was run.

Every mode runs in a fresh process with normal Automatic capacity and no artificial
cache ceiling. OS page cache and desktop memory are uncontrolled. Modes have
different conservative pool-cap reservations. The benchmark presses Play just
after synchronous open, measures open-to-ready and initial lead, then plays the
entire recording at 1×. Separate fresh-process 2× and 4× runs cover twelve seconds
after readiness. Linux CPU/RSS/swap samples are captured every 100 ms; policy,
lead, rate, demand, active jobs and memory are captured once per second. Worker
decisions carry monotonic timestamps and reason codes. CPU 100% means one occupied
logical core; process peaks include engine, driver and native allocator pages.

Source values at displayed samples 0/100/800/1565 are retained for hashes after
the timed loop, then compared with independent strict Python reads and exact
timestamps. Those retained oracle references add at most four source samples to
process memory. Source stat identity is checked before/after. This is full playback
plus selected strict byte oracles, not a new whole-file payload verification scan.
Interactive integrity and explicit strict verification remain the #108 policy.

### Playback comparison

Final full 1× results (wall time includes startup and rebuffering):

| Mode | Open → ready | Initial lead | Producer/consumer at start | Full wall | Field waits / duration | Peak RSS / swap |
|---|---:|---:|---:|---:|---|---|
| Auto | 10.92 s | 107 samples / 10.70 s | 1.154 | 167.43 s | 0 / 0.00 s | 35.57 GiB / 0.00 MiB |
| 1 | 63.64 s | 315 samples / 31.50 s | 0.478 | 282.88 s | 2 / 62.73 s | 36.05 GiB / 0.00 MiB |
| 2 | 35.55 s | 296 samples / 29.60 s | 0.874 | 192.06 s | 0 / 0.00 s | 35.35 GiB / 337.61 MiB |
| 3 | 4.92 s | 45 samples / 4.50 s | 1.157 | 161.44 s | 0 / 0.00 s | 34.01 GiB / 0.00 MiB |
| 4 | 4.94 s | 52 samples / 5.20 s | 1.313 | 161.45 s | 0 / 0.00 s | 33.60 GiB / 0.00 MiB |

Every final full run commits the complete 156.5-second extent and observes all
1,566 field samples. Particle waits are zero in these full runs. Auto starts at
two lanes, grows to three and four, then encounters real physical-headroom
pressure near 34 seconds after open. It backs off to one with about 11.43 seconds
of lead and about 4.71 GiB reported available RAM, waits through the cooldown,
and recovers via two/three/four lanes. That lead absorbs the temporary production
deficit: the full run has zero field/particle waits and zero swap. Six lane
changes include this single pressure/recovery episode; no recurrent cycling was
observed. The earlier full Auto run also completed without waits/swap, using
only the initial two scale-ups, and is retained as a separate observation.

Auto reached playback-ready in **10.92 s**, versus **35.55 s** for fixed two in
these trials. Its initial lead exceeds the nominal three-second minimum because
the controller measures after successive scale-ups. Fixed three/four can validate
their initial throughput sooner and start in about five seconds. Fixed one/two
use the conservative admitted-window gate. These measurements support early
startup and safe adaptation on this workload; they are not cold-cache or
cross-machine speed guarantees.

Frame timings cover each whole measured loop, including startup/rebuffering.
CPU covers the native process, including post-loop hashing and teardown.
The producer column is successful publications divided by summed busy batch wall
time; the evidence also retains its rolling one-second estimate. Lower frame
percentiles during long buffering phases should not be read as smoother playback.

| Mode | Busy preparation samples/s | Process CPU (one core = 100%) | Draw p95 / p99 / max | Main callback p99 |
|---|---:|---:|---|---:|
| Auto | 10.402 | 287.4% | 28.82 / 36.51 / 165.35 ms | 34.36 ms |
| 1 | 5.800 | 151.4% | 18.65 / 26.21 / 76.58 ms | 24.93 ms |
| 2 | 9.173 | 231.5% | 26.28 / 32.93 / 83.79 ms | 31.04 ms |
| 3 | 10.391 | 301.7% | 33.05 / 40.51 / 73.08 ms | 38.14 ms |
| 4 | 10.877 | 313.1% | 34.07 / 41.45 / 69.53 ms | 39.23 ms |

Auto draw p99 remains above 33.333 ms, and its maximum observed callback is
163.99 ms. Constant presentation pacing is not established.

Short trials run for twelve wall seconds after initial readiness:

| Mode | 2× ready | 2× field / particle wait events | 4× ready | 4× field wait events / time | 4× particle wait events / time | 4× recorded advance |
|---|---:|---|---:|---|---|---:|
| Auto | 26.89 s | 0 / 1 | 27.17 s | 32 / 0.705 s | 69 / 5.491 s | 27.85 s |
| 1 | 63.24 s | 0 / 0 | 64.30 s | 2 / 4.082 s | 0 / 0.000 s | 31.78 s |
| 2 | 36.53 s | 0 / 0 | 36.62 s | 106 / 4.684 s | 30 / 0.829 s | 35.57 s |
| 3 | 28.79 s | 0 / 0 | 29.26 s | 68 / 1.478 s | 77 / 3.698 s | 35.13 s |
| 4 | 25.68 s | 0 / 0 | 25.55 s | 37 / 0.858 s | 73 / 5.615 s | 27.48 s |

All final short trials observe zero process swap. At 2×, Auto has one particle
wait lasting 54.07 ms; the other modes have no particle waits. Their prepared
leads shrink while the initial buffers cover this short interval. At 4×, both
field and particle preparation plus GPU staging limit progress. Field-wait counts
include short GPU target waits; their durations and CPU runway events are retained
separately in the evidence. Whole-playback throughput also depends on the other
layers, so more field workers do not establish optimal 4× playback. No sustained
2×/4× claim is made. Detailed per-run RSS, CPU, render timing, prepared lead,
consumer rate and decision histories are in the compact evidence.

### Regression ledger

| Check | Result |
|---|---|
| Controller thresholds, hysteresis, resize ownership, GPU-wait distinction | 94 checks, 0 failures |
| Ordered publication, generation/seek/shrink/source races; exact f32/f64 channels and planes, 1–4 lanes | 1,800 checks, 0 failures |
| Active 192³ worker cancellation/close | 25 checks, 0 failures |
| Field sessions, Forward+ / Compatibility | 342 / 332 checks, 0 failures |
| Adaptive cache, Forward+ / Compatibility | 73 / 73 checks, 0 failures |
| Interactive/strict integrity | 473 native checks; 63 independent strict corruption rejections |
| GPU budgets and staging, Forward+ / Compatibility | 56 / 56 checks, 0 failures |
| Maintenance / lifecycle | 66 / 51 checks, 0 failures |
| Lazy loading / combined scene playback / mesh playback | 217 / 2,457 / 2,731 checks, 0 failures |
| Python scene contract/chunks/statistics/metadata budget | 14 tests, PASS |
| Godot import, documentation links, three executable API examples, diff whitespace | PASS |
| Production channel/seek/reverse/loop/speed/pressure/active-close/reopen sequence | 22 checks, 0 failures; zero process swap |

The focused native regression total is **8,846**, plus the 22 production interaction
checks and the playback profiles. The interaction test injects an unavailable-RAM
observation into the policy without allocating memory or bypassing the worker's
real admission checks. Auto reduces four lanes to one, preserves reservations,
and later scales back up. It verifies source-array reuse during a channel change,
near/distant seeks, decreasing committed time in reverse, a loop wrap, live speed
changes, an actual cold job in flight during close, and a fresh controller on reopen.
These deliberate demand/pressure changes are distinct from spontaneous oscillation.

Full viewer teardown in the successful interaction repeat took **1.934 s**,
including resource cleanup and the next process frame. The isolated worker
cancellation/close probe is a different, smaller ownership scope; neither timing
is a worst-case bound for native decode calls or a universal UI guarantee.
Worker cancellation took 13.79/13.81/20.63/20.67 ms for 1/2/3/4 lanes;
worker close took 7.10/12.37/10.09/11.32 ms in the isolated probe.

### Failed attempts and limits

- The first import exposed two GDScript inferred-bool errors; explicit annotations
  fixed them before runtime profiling.
- The first short Auto pilot tested the new cache ceiling before an admitted
  batch had drained. Its playback had no waits or swap; the premature final bound
  assertion failed. The corrected probe waits for cancellation/pruning to settle.
- The initial one-worker full probe stopped at the requested endpoint before the
  final display commit. The corrected probe waits for the committed endpoint and
  a final draw. Its repeat supersedes that incomplete display observation.
- Initial high-speed probes exposed a pending GPU upload being classified as a
  CPU shortage. The gate now distinguishes these, with a deterministic regression
  and targeted 4× repeats. The 2× trials had no field waits, so this branch was not
  exercised in those otherwise retained measurements.
- The first interaction close test found an idle pool. The final test explicitly
  queues a cold target, waits for an in-flight job, and closes it; all 22 checks pass.
- Fixed two-worker full playback reported **354,004,992 bytes (337.61 MiB)** of
  process swap. This does **not** meet a zero-swap criterion. Swap appeared during
  playback with several GiB still reported available; exact OS/allocator causes
  were not isolated. It remains a disclosed fixed-mode limitation, not evidence
  that physical-headroom estimates guarantee zero swap.
- The measurements are one host/OS/capture/resolution with uncontrolled file cache
  and desktop state. There is no full production Compatibility run, cross-host/OS
  matrix, competing scientific-solver load test, quota discovery, or exact native
  allocator/GPU timing attribution. Short 2×/4× trials do not establish sustained
  higher-speed throughput or constant presentation pacing. CPU/RAM signals and
  cadence estimates are conservative heuristics; persistent swapped pages keep
  Auto backed off until detected swap clears. No new full-file strict scan was run.

Historical #109 evidence is preserved. Raw native logs, full one-second controller
timelines and 100 ms process telemetry remain outside the repository. The
[compact evidence](evidence/issue-111/dynamic.json) retains summary metrics and a
[controller timeline](evidence/issue-111/timeline.csv), including
roughly five-second observations plus worker/wait/phase/pressure transitions,
reason codes, stage totals, validation results and superseded/failed-attempt notes.

## Reproduction and owner checks

```sh
python tools/profile_dynamic_preparation.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /fresh/auto --workers auto
# Repeat with --workers 1, 2, 3, 4; each default run plays the full recording.
# For short speed trials add --speed 2 (or 4) --seconds 12.
python tools/profile_dynamic_preparation.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /fresh/actions --actions
python tools/validate_field_concurrency.py --godot /absolute/path/godot \
  --output-dir /fresh/concurrency
```

1. Launch with `SIMSCOPE_FIELD_WORKERS` unset (or `auto`), open the production
   capture, keep full resolution and 1×, and press Play promptly. Confirm startup
   waits for useful coverage then advances while preparation continues. Play to
   the recorded end and inspect responsiveness and buffering.
2. Compare fixed `2` and `4` launches with otherwise similar settings. Fixed modes
   keep their diagnostic caps but use the same measured startup gate and live
   memory admission. Observe behavior at 2×/4×; sustained higher-speed throughput
   is not promised.
3. Change density/psi_real/psi_imag during preparation, seek nearby and far away,
   play backward and loop across the ends. Check source/channel/clock agreement,
   including explicit buffering after demand changes.
4. Pause/resume, close during preparation and reopen. Try an advanced selected
   interval. For pressure evidence, use the safe observation-injection profile;
   deliberately exhausting machine RAM is unnecessary.
5. Review the comparison, regression results and limits before accepting. The
   owner controls merge and Project completion.
