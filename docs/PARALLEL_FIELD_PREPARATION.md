# Bounded parallel field preparation — issue #109

Implementation and measured validation are **pending owner review**. Issue #109
was the only Ready item when work began. Its existing issue-linked branch and
accepted `main` both started at `d9876ee` (owner-merged #108); #103 is an ancestor.
No #106 timeline UI, capture-format change or later issue is included.

## Execution and ownership

The existing field-cache thread now coordinates a pool of one to four persistent,
low-priority CPU lanes. The default is two lanes when Godot reports at least four
logical CPUs, otherwise one. `SIMSCOPE_FIELD_WORKERS=1`, `2`, `3` or `4` selects a
process-lifetime cap; other values use the default. This is a conservative CPU
availability rule, not a claim to detect physical cores or the ideal throughput
for a machine. No processor model, RAM size or GPU model is hardcoded.

The coordinator validates descriptors, admits memory, borrows compatible cached
source arrays, dispatches a bounded batch, and collects results in request order.
Each lane owns one file handle, one job and its completed result. A batch contains
at most the configured number of lanes; there is no additional result queue.
In-flight keys prevent duplicate sample dispatch. Cache/LRU mutation, accounting,
failures and session readiness remain serialized under the existing mutex.

Workers decode every channel at its original precision, consume recorded exact
statistics, convert the selected display channel and create independent CPU
`Image` planes. They never mutate a published sample or shared resource. The
existing main-thread upload path still holds current plus at most one future
texture per visible field, with at most one field upload per process frame.
This follows Godot's [thread-safety guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html):
shared container mutation requires synchronization, and active scene-tree and GPU
operations must stay off these workers.

Cancellation is per job: generation, wanted key and close state are checked under
the coordinator mutex between source chunks and during plane creation/conversion.
Native decompression and typed-array copies cannot be interrupted midway through
one call. Source identity is checked before dispatch, after preparation, and at
publication. A seek, channel change, source change or close cannot make an obsolete
result current. Cancelled channel replacements can return the prior invalidated
source allocation to the bounded cache, preserving #103's reuse behavior.

## Memory and ordering

For exact retained charge `C = source arrays + selected planes + 64 KiB`, each
simultaneously outstanding job reserves `3*C` physical headroom. This covers
compressed input, raw decoded chunks, growing byte assembly and typed conversion
buffers, selected-channel byte copies/planes, and overlap with borrowed old
previews or newly published results. The largest supported per-record allocations
are still validated before payload allocation. The existing current/staged
reference allowance remains within the first lane's reserve.

Automatic and explicit interval capacity subtract an additional `6*largest`
allowance for each extra configured lane, before the existing 5% allocation slack.
Half is live scratch, and half reserves room for a retired batch whose native
allocations may not yet be reusable by the allocating lane. The largest admitted
job remains the retirement-reserve basis until close, even after a smaller seek.
This is a reserve, never credit for released allocations. It was added after a
full-run experiment with only live scratch reported process swap (see below).
Retained cache policy and owned-resident credit are unchanged. Admission checks
fresh physical headroom against the sum of all outstanding job charges plus the
retirement allowance; if another
lane will not fit, the coordinator drains the current batch and retries with fewer
simultaneous jobs. If even one cannot fit, Automatic reports retryable memory
pressure. Cancelled-but-uncollected jobs keep their reservations until their
references are released. A smaller budget rejects over-budget publication.

This deliberately conservative accounting can leave some RAM unused. Linux
`MemAvailable` already excludes resident process pages, while the extra job
reservation covers future allocations without trying to infer which in-flight
buffers have already been allocated. This is cooperative admission, not an OS
memory limit. Arbitrary external allocations and cgroup limits remain outside the
existing policy's guarantees. Swap is not treated as capacity.

The queue keeps #103's requested forward/reverse/loop order. An earlier slow job
holds later results until collection, so the batch design trades some throughput
for simple bounded ownership and predictable publication. GPU staging and the
committed scientific clock still depend on the requested sample's readiness.

## Profiling method

The unchanged production capture has 1,566 three-channel 192³ float32 field
samples and 627 particle samples, ending at t=156.5; each field retains 81 MiB of
source arrays plus 27 MiB of density planes. Hardware: Ryzen 7 5800X, 46.94 GiB
physical RAM, RTX 3070 Ti, Godot 4.7.2, Linux. No solver, capture, cadence,
compression, source precision, channel set or display LOD was changed.

`profile_field_workers.py` measures private CPU lanes on identical samples
100–227, disposing each result before the next sample. Configurations run in
order 1/2/3/4/4/3/2/1 in fresh processes. OS page cache is uncontrolled; no privileged
cache drop or claim of cold-disk throughput is made. The second matrix,
`profile_parallel_preparation.py`, retains the same 128 samples through the real
cache controller, then runs Forward+ playback at 1×/2×/4× with the same 2 GiB field
cache cap and 960×640 Scientific view, point particles and orbit disabled.
These two workloads are distinct; the discard-only rate is not product throughput.

Stage counters sum time spent inside each worker. With concurrent jobs they
overlap, include scheduling waits and must not be summed as wall-time percentages.
File throughput means logical stored payload bytes divided by preparation wall
time, not physical disk traffic. CPU utilization uses 100% per occupied logical
core. Per-core system utilization is retained for the CPU experiment; it is not
per-process core attribution. RSS/swap samples are taken every 50 ms for that
experiment and 100 ms for the native playback profile, with process high-water RSS
also recorded. RSS includes allocator/engine/driver overhead; it does not isolate
an exact per-buffer transient peak.

| Workers | CPU-only samples/s, forward / reverse run order | Integrated samples/s | Integrated wall, 128 samples | Recorded seconds prepared / wall second |
|---|---:|---:|---:|---:|
| 1 | 6.179 / 6.126 | 5.265 | 24.311 s | 0.527 |
| 2 | 10.944 / 10.735 | 9.121 | 14.033 s | 0.912 |
| 3 | 13.531 / 13.353 | 10.874 | 11.771 s | 1.087 |
| 4 | 14.557 / 14.554 | 11.921 | 10.737 s | 1.192 |

Three and four workers exceed the 10 samples/s preparation target in this measured
window. Requirements for 2× and 4× are 20 and 40 samples/s, which are not reached.
The two-worker default improves throughput while reserving CPU capacity for the
viewer, particle worker and other applications; it does not itself establish
sustained indefinite 1× throughput. Four workers are the best measured cap here,
but their advantage over three is modest and cannot be generalized to other hosts.

After hashing was removed by #108, decompression and memory copies dominate.
File reads and descriptor validation remain small in this warm-cache workload;
statistics lookup is negligible. Decompression is CPU work, while assembly,
typed conversion and plane copies move substantial memory. Their rising per-job
time under concurrency is consistent with contention/scheduling pressure, but no
hardware bandwidth or allocator-lock counters were collected to identify a single
cause. Cache publication/admission stay serialized. Reducing redundant assembly
and conversion copies is a promising separately measured next experiment; no such
change is included here.

The identical retained-window probe against an immutable accepted-`main` snapshot
prepared 5.210 samples/s (24.570 s); the new one-worker control was 5.265. This is
the appropriate baseline for the integrated matrix, rather than #107's different
discard-only workload. The final four-worker preparation recheck, with the extra
retirement reserve, reached **11.376 samples/s** (1.138 recorded seconds/wall second).

| Integrated worker count | CPU utilization, one core = 100% | Preparation peak sampled RSS | Live scratch reservation | Decompress / assembly / typed conversion, summed worker seconds |
|---|---:|---:|---:|---|
| 1 | 103.9% | 14.12 GiB | 324.2 MiB | 7.698 / 8.040 / 5.144 |
| 2 | 181.3% | 14.14 GiB | 648.4 MiB | 9.286 / 8.374 / 5.520 |
| 3 | 233.1% | 14.17 GiB | 972.6 MiB | 14.252 / 9.105 / 6.053 |
| 4 | 268.5% | 14.23 GiB | 1296.8 MiB | 20.014 / 9.316 / 6.760 |

All four fixed-window runs observed zero process swap. Publication rates equal
their prepared-sample rates. File-read stage totals were 0.959/1.093/1.345/1.495 s;
logical read throughput was 424/735/877/961 MB/s respectively. The final memory
guard additionally reserves 972.6 MiB for retirement with four 108.0625 MiB jobs.
Raw counters, per-core observations and exact values are in the
[compact evidence](evidence/issue-109/parallel.json).

## Playback and memory results

The ten-second trials start with 18 full samples in the same 2 GiB field cache.
Counts below are transitions into a field wait, not frames spent waiting. Particle
wait events were zero in every one of these trials.

| Workers | Field waits at 1× / 2× / 4× |
|---|---|
| Accepted main | 26 / 66 / 55 |
| 1 | 36 / 65 / 55 |
| 2 | 0 / 50 / 59 |
| 3 | 0 / 33 / 53 |
| 4 | 0 / 26 / 40 |

Complete 1× playback uses normal Automatic capacity, with no test cache ceiling:

| Configuration | Initial fill | Playback wall / recorded time | Field / particle wait events | Process peak RSS / swap | Distinct rendered field samples |
|---|---:|---|---|---|---:|
| Two-worker default, live-only guard | 35.07 s | 156.52 / 156.5 s | 0 / 0 | 37.56 GiB / 0 | 1565 of 1566 |
| Four workers, live-only guard, **failed memory criterion** | 33.03 s | 156.52 / 156.5 s | 0 / 0 | 37.05 GiB / 1.903 GiB | 1566 of 1566 |
| Four workers, final retirement guard | 28.00 s | 156.52 / 156.5 s | 0 / 0 | 36.06 GiB / 0 | 1566 of 1566 |

The first four-worker run demonstrates why bounded live results alone are not
enough evidence for memory safety. RSS substantially exceeded explicit retained
cache charges, and process swap rose during initial filling. Native allocation
retention/fragmentation and OS reclaim are plausible contributors; this probe
does not attribute every retained page. The final guard adds conservative room
for batch retirement, then the complete run was repeated. Its last sample had
5.59 GiB available physical RAM. Initial desktop/page-cache state differed, so
zero swap in that repeat is measured evidence, not a universal guarantee. The
default two-worker full run preceded the final additional reserve; the final
default behavior is covered by the native regressions, not a second full run.

Rendering remains a separate limit. With the final guard, draw-interval p95/p99
were **29.48/39.20 ms**, maximum **138.72 ms**, with 500 of 17,119 draw intervals
above 33.333 ms while neither buffer was waiting. Main callback p99 was 36.94 ms.
The two-worker run's maximum draw gap was 174.84 ms and did not show source index
83 as a rendered frame; its field and particle buffers did not wait. This does not
mean a source sample was removed or downsampled: the existing physical-time
transport can advance across a source timestamp after a presentation delay.
Constant frame pacing and uninterrupted rendering are not established.

Actual cancellation during active 192³ work drained in 6.88/13.87/20.67/20.61 ms
for one/two/three/four workers. Closing active pools took 8.05/12.36/16.29/18.83 ms.
All outstanding reservations were released and no cancelled result published.
These are one-shot observations, not worst-case bounds for native chunk calls.

## Final regression ledger

| Check | Result |
|---|---|
| Concurrency, ordered publication, exact f32/f64 channels and planes; one through four workers | 1,800 checks, 0 failures |
| Real 192³ cancellation/close while every lane is active | 25 checks, 0 failures |
| Field sessions, Forward+ / Compatibility | 342 / 332 checks, 0 failures |
| Automatic cache: default two workers headless, four workers Forward+, four workers Compatibility | 73 checks each, 0 failures |
| Interactive/strict integrity | 473 native checks, 0 failures; 63 independent strict corruption rejections |
| 192³ GPU budget and staging, Forward+ / Compatibility | 56 checks each, 0 failures |
| Maintenance / close-reopen lifecycle | 66 / 51 checks, 0 failures |
| Lazy loading / combined scene playback / mesh playback | 217 / 2,457 / 2,731 checks, 0 failures |
| Python scene contract/chunks/statistics/metadata budget | 14 tests, PASS |
| Godot import, documentation links, three executable API examples, diff whitespace | PASS |

The final native regression total is **8,825 checks**, excluding the performance
profiles. The new deterministic races hold a complete admitted batch before
publication, then change generation, seek/reverse order, reduce the budget or
mutate a disposable source. They verify stale rejection, exact cache accounting,
bounded active jobs and release of cancelled reservations. Existing native suites
cover overlap reuse, distant/rapid seeks, reverse/loop behavior, advanced intervals,
capacity loss/recovery, source errors, close/reopen and GPU staging.

Initial sandbox import/logging failed on sockets/user-log access; approved native
runs passed. An initial GDScript inferred-bool compile error was corrected. The
first shrink-race test used a cap too small for one sample and failed four
assertions; correcting that test input produced the passing 1,800-check run.
The swap-bearing full run is retained above as a failed memory experiment.

Limitations: no full production Compatibility playback or non-Linux/other-hardware
matrix; no cgroup-specific capacity discovery, hardware memory-bandwidth counters,
or exact per-buffer allocation tracing. The 125.95 GB production capture did not
receive a new whole-file payload hash/strict scan in this issue; selected strict
byte oracles and unchanged stat identity are explicit narrower checks. No broad
scientific rerun, new compression/layout, particle scheduling change, presentation
optimization or #106 UI work was performed. Owner acceptance remains pending.

## Reproduction

```sh
python tools/profile_field_workers.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /fresh/cpu-results \
  --first 100 --samples 128 --workers 1 2 3 4 4 3 2 1
python tools/profile_parallel_preparation.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /fresh/native-results \
  --workers 4 --renderer forward_plus --first 100 --samples 128 \
  --cache-mib 2048 --play-seconds 10
python tools/profile_parallel_preparation.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /fresh/full-run \
  --workers 4 --renderer forward_plus --cache-mib 0 --play-seconds 0 --speeds 1
python tools/validate_field_parallel.py --godot /absolute/path/godot \
  --output-dir /fresh/race-fixtures
```

Production source stat identity is checked before/after every Python profile.
Strict Python reading independently checks all source channels and exact
timestamps at samples 100, 164 and 227; CPU plane hashes equal the selected
float32 channel. Synthetic regression covers every value of every channel in all
20 samples, including float64 source preservation and its float32 plane oracle.
The race fixture is explicitly disposable and mutated only for its source-change
test. The production file is never modified. Whole-file payload verification is
the unchanged `tools/verify_ssc.py` workflow; playback still follows #108's
[interactive integrity policy](PLAYBACK_INTEGRITY.md).

## Owner verification

1. Start the viewer normally and open the production capture with Automatic
   preparation, density, full resolution and 1× playback. Allow initial coverage
   to fill, then play to the recorded end. Inspect responsiveness and any pauses.
2. Repeat from a terminal with `SIMSCOPE_FIELD_WORKERS=4` set for the Godot process.
   Keep other applications and viewer settings comparable. Faster preparation
   does not guarantee a constant rendering frame rate.
3. While preparation is active, alternate density/psi_real/psi_imag, scrub within
   and beyond prepared coverage, change direction and enable looping. Check that
   the committed image/clock agree and no old channel appears after a switch.
4. Close during active preparation, reopen, and try a short advanced interval.
   Confirm no stuck preparation, stale result, source error or growing memory
   remains. Repeat the relevant controls with the preferred renderer/display.
5. Review the retained validation limitations before accepting or merging. The
   Project item remains for owner-controlled completion.
