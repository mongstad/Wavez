# Adaptive mesh preparation

Issue #195 adds bounded parallel CPU preparation and endpoint/topology reuse to
#191's adaptive RAM admission. Candidate build 25 is pending owner review.
The policy concerns interactive mesh preparation; GPU quotas, source limits,
scientific values, deterministic export and the shared physical-memory detector
are unchanged.

## Admission and ownership

`playback_memory.gd` supplies the authoritative snapshot. On Linux it uses
`MemAvailable`; swap is never capacity. Its system reserve is 3% of physical RAM,
clamped to 512–2048 MiB, plus 256 MiB for future renderer/UI growth. Its safe-cache
allowance is the smaller of 40% of physical RAM and available physical RAM minus
that reserve, floored at zero. These existing shared rules are unchanged.

The mesh policy first subtracts unused scene-cache and particle-cache allowances,
two largest particle working pairs, and the field pool's bounded scratch allowance
(three largest field-job charges per worker). Already resident field pages reduce
physical availability directly; prospective field cache admission accounts for the
mesh reservation described below.

Let `T` be the summed conservative charge for visible current mesh pairs, `W` the
sum for distinct current plus at most four future pairs per visible mesh, and `R`
the remaining safe-cache bytes after those other reservations:

```
CPU cache allowance = min(max(2*T, W), floor(max(0, R)/5))
Admission requires 2*T <= CPU cache allowance.
```

One share admits prepared pairs, another admits decoded endpoints with cached
display geometry, two more reserve active/staged references and concurrent
decode/conversion/upload scratch, and a fifth remains unused. Job charges
include both decoded samples, identity maps, display/expanded arrays, morph data
and allocation overhead. Lazy descriptors deliberately overestimate geometry.
The charge is a conservative quota, not measured resident memory. This issue does
not weaken the estimator to make the acceptance capture fit.

Demand is established before field acquisition. Fields reserve four times the
mesh allowance instead of the former fixed 256 MiB. No credit is taken for mesh
quota charges as though they were actual resident physical pages. A healthy
admission remains stable while fields fill their separate cache, preventing
repeated division of remaining RAM from surrendering the mesh reservation.
Workload/settings changes trigger recalculation. Once per second, the controller
checks current headroom and other reservations, recalculates under pressure or
insufficient admission, and retries transient worker RAM refusals. The diagnostic
report distinguishes the admission snapshot from current memory/reservations.

## CPU pool and reuse

There are `clamp(logical_CPUs/2 - 2, 1, 4)` persistent low-priority CPU lanes.
On the 8C/16T acceptance host, this selects four lanes and leaves capacity for
rendering, input, fields and the OS. The optional diagnostic environment variable
`WAVEZ_MESH_WORKERS=1|2|3|4` selects a comparison count; it does not bypass RAM
admission. Each lane has its own file handle for each decode task. Workers touch
only CPU data; GPU surface creation remains on the main thread.

The ordered work list contains current pairs first, followed by at most four
future pairs per visible mesh in the playback direction. A lane can decode the
partner of an endpoint already being decoded by another lane. Once both endpoints
are available, the current pair takes priority over distant work. A shared mutex
atomically admits task keys and charges; no endpoint or pair is prepared twice
concurrently. The pool never queues a whole capture.

Before dispatch, live physical headroom subtracts the system/renderer reserve,
other reservations and one endpoint-cache allowance. Three conservative charges
per outstanding task must fit. The active lane limit contracts with that headroom,
and the sum of prepared-pair charges plus in-flight charges must fit one cache
allowance. Cancelled tasks retain their charges until they retire. Budget reductions
stop oversized work, drain it and prevent stale publication. This can temporarily
leave already allocated work above a newly lowered limit; it admits no new work
until the reduced allowance can be respected.

Endpoint keys include path, source stamp, reader generation, object and sample
sequence. Adjacent pairs share decoded source arrays, converted positions, normals,
fixed colors and endpoint bounds. Channel/colormap changes rebuild pair colors
while reusing those channel-independent values. Prepared-pair tokens still include
the complete display configuration. New source generations cannot reuse prior
endpoints. Source stamps are checked before and after work, and publication checks
its generation and current demand again. Dropping obsolete arrays happens on the
workers outside the cache mutex; close wakes and joins every lane.

For `stable_topology`, ordered IDs, vertex count and triangle connectivity must
match the previously validated packed arrays exactly. Only then are ID-map and
triangle-range validation skipped. Changed topology follows the full validation
path. Oriented triangle indices and wireframe lines are shared after validation;
startup lanes may independently validate the first few endpoints. This avoids a
serial startup bottleneck without trusting a declaration alone. Descriptor/commit,
shape, channel and decompression validation still runs for each new endpoint.
The accepted interactive payload-hash policy is unchanged; use strict scientific
verification for complete payload-integrity proof.

Fixed color uses a packed fill and cached endpoint colors. Scalar mapping builds
one packed palette per pair and preserves the exact clamp/round/nonfinite rules.
Morph deltas remain per-pair, while bounds use the union of endpoint bounds.
Positions, supplied or accumulated normals, topology, channels and source times
retain their existing scientific and presentation contracts.

Both caches evict behind the requested window, and topology references are scoped
to current objects/generations. One mesh's five adjacent pairs need at most six
endpoints, rather than retention proportional to recording length. Diagnostic
phase totals and lane counters are fixed-size; timing samples stop at 4096.
`profile_report()` exposes both cache shares, active lanes, cumulative reuse,
phase timings, service times and request-to-ready times.

The current GPU mesh and at most one staged future mesh share each visible
layer's GPU quota. At most one upload occurs per process frame. Stable-topology
position interpolation and held scalar colors retain their existing semantics.

## Refusal and recovery

- **CPU preparation RAM:** reports required and safely admitted MiB, recommends
  freeing RAM or hiding a mesh, and explains that a GPU preview setting cannot
  remove decoded source costs. The Performance panel says **Mesh CPU preparation
  blocked** instead of claiming prefetch is ready. An uncached request holds the
  last committed scientific clock, pauses playback, cancels obsolete work and
  releases future CPU/GPU staging. The last committed scene remains available.
  Admission retries when memory becomes available, without reopening the capture.
- **GPU layer quota:** the existing **Mesh GPU budget exceeded; preview released**
  diagnostic remains. It releases the preview while preserving decoded source
  arrays and the scientific sample.
- **Source/decoded limits:** SIMSCP4's 256 MiB per-record ceiling and the viewer's
  512 MiB visible decoded-pair ceiling are unchanged and remain separate from
  this preparation allowance. Increasing preparation RAM does not bypass them.

Cancellation drains obsolete work; close joins all workers and release preparation ownership.
Scientific source files are read only. These are bounded admission/reservation
rules, not a whole-process memory guarantee against arbitrary concurrent external
allocations or an OS-enforced RSS limit.

## Validation

On the measured 8C/16T host, four lanes sustained 45.85 fixed-color and 41.99
radius pairs/s over 1000 consecutive pairs. Both full 240-second Forward+ runs
tracked 1x wall time with no preparation holds. These are host-specific results.

See [issue #195 measurements and owner checks](evidence/issue-195/README.md) and
the historical [issue #191 admission evidence](evidence/issue-191/README.md). The
historical [PERF-003 report](MESH_PLAYBACK_MAINTENANCE_REPORT.md), earlier performance
reports and their evidence retain their original policies and review-time wording.
