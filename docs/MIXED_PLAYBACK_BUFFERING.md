# Mixed playback and temporary buffering at 2×

Issue #232 investigated the mixed particle/field hold reported after #229 / PR
#230. Candidate **v0.1.0.37** corrects the reported cause of a mixed-scene wait.
It does **not** change cache admission, worker counts, preparation algorithms,
scientific samples, playback speed, or field buffering thresholds.

## Result and decision

On the supplied `free_collapse.wvz`, both accepted pre-#230 code and merged #230
advanced the playhead to the recording's end after a paused cache fill followed
by 2× playback.
Both temporarily held playback to refill **fields**, with their required particle
pairs already resident. The owner confirmed that the reported stop also resumed
automatically after buffering. The exact 15–20% stop position was not reproduced
with current real RAM conditions; there is no fixed percentage stop in this path.

The measured cause supports retaining #230's particle policy. Reverting particle
admission would not remove the field refill hold demonstrated on pre-#230 code.
This investigation does not establish that every possible lower-RAM condition is
free of particle starvation, and does not promise uninterrupted 2× playback.

There was a concrete diagnostic defect: `particle_playback.pump()` also pumps the
field controller. If that field pump returned false, the shared transport labelled
the hold **Required particle content**, even when particles were ready. The
controller now passes the actual field wait reason to the existing Buffering
tooltip. An actual particle wait retains its particle reason. Controller calls
and readiness decisions remain the same.

## Why prepared fields can coexist with a hold

The field controller uses a predictive buffering gate. When preparation is slower
than playback consumption, it can pause before reaching the end of resident
coverage, then resume when its admitted window or measured-rate gate is ready.
Remaining prepared fields protect against an abrupt underrun; their presence does
not mean the controller promises to consume all of them before waiting.

This recording samples fields every 0.1 source seconds. At 2×, playback consumes
**20 field samples per wall-clock second**. During the matched unpressured holds,
field production was approximately **11.1–11.2 samples/s**. Even a full initial
RAM cache loses prepared coverage at that consumption rate. The same cached
source time lasts half as long at 2× as at 1×.

Particles are sampled every 0.5 source seconds, requiring four pairs/s at 2×.
Their rolling window kept up: all 150 pairs completed, with no prepared-pair
misses, discarded preparations or particle failures in the matched pre-#230 and
merged-#230 runs. The field gate predates #230 and uses contiguous coverage and
measured preparation rate, not percentage position or total cached bytes alone.

## Workers and RAM

Fields retain their background pool of up to four workers. Automatic concurrency
reacts to throughput, display responsiveness and physical-memory pressure.
Particles have their own low-priority background worker. GPU upload and rendering
boundaries are unchanged.

Under memory pressure, including observed process swap, the existing field policy
reduces concurrency. A candidate pressure run recorded a reduction from four
field workers to one, lower throughput and more refill holds; particles remained
admitted and ready. Swap is not treated as extra cache capacity.

A small cache size alone does not establish a leak. A discarded pair of
accidentally overlapping diagnostic runs with simulated RAM reservations
confounded headroom. They were stopped and replaced by sequential runs using
real RAM snapshots; their results do not establish production behavior.

Process RSS and conservative cache charges differ. RSS remaining high after
eviction can involve allocator retention or other allocations; these traces do
not prove a particular explanation. Memory returning when a process exits does
not rule out a leak while it runs. No comprehensive long-session allocation/leak
analysis was performed or is claimed.

## Repeatable comparison

Use the same capture, renderer, speed and ordinary workload. Run one diagnostic
viewer at a time, with trails off for this case. Let the admitted caches finish
while paused, then press Play at 2×. Record the actual plateau: a 25–30 GiB field
cache is not a whole-file cache when the prepared recording is larger than RAM.

The read-only profiler waits until the field window is ready, field jobs are idle
and requested particle pairs are resident for two seconds before pressing Play:

```sh
python tools/profile_mixed_playback.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse.wvz \
  --output-dir /tmp/mixed-playback-review --speed 2 --renderer forward_plus
```

`--viewer /absolute/path/to/baseline/viewer` uses an imported baseline snapshot.
Traces contain particle requests/residency, budgets, bytes, evictions,
completions, cancellations, failures, field coverage, producer/consumer rate,
worker policy, RAM and swap. Observations are sampled once per second, so hold
durations are approximate. The profiler stops when the requested playhead reaches
the end; its final committed presentation can lag by one display step. It does
not verify final-frame pixels. Before/after file metadata checks are not full
payload-integrity verification. See [issue evidence](evidence/issue-232/README.md)
for measurements, validation, corrected attempts and remaining uncertainty.

## Owner verification

1. Open the supplied mixed capture and leave it paused with trails off until
   cache use reaches its plateau. Record field cache size, process RSS and other
   workload/RAM use separately.
2. Play at 2×. If Buffering appears while particles are ready, hover the status:
   it should name **Required field content or startup coverage**. Wait for
   automatic recovery and check progress to the recording's end.
3. Compare at 1× with the same renderer/workload. Verify pause/resume and scrubbing
   still reuse prepared content; the diagnostic change does not change speed.
4. Open a particle-only capture and confirm Automatic still fills the safe
   whole-scene allocation. Mixed particles retain the small rolling window.
5. If a future hold does not recover, retain its trace and memory/workload details.
   That differs from the temporary refill demonstrated here.

The owner controls whether this diagnosis and reporting correction resolve #232.
No claim of owner acceptance or sustained 2× throughput is made.
