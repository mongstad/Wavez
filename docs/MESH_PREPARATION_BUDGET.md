# Adaptive mesh preparation

Issue #191 replaces the 128 MiB mesh CPU cache ceiling. Large valid meshes can
prepare when physical RAM safely supports their current/staged source pairs.
This policy concerns interactive mesh preparation; GPU quotas, source limits,
scientific values, deterministic export and the shared physical-memory detector
are unchanged. Implementation is pending owner review, candidate build 23.

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
CPU cache allowance = min(max(2*T, W), floor(max(0, R)/4))
Admission requires 2*T <= CPU cache allowance.
```

One share admits cached preparations, two more reserve active/staged references
and decoder/conversion/upload scratch, and a fourth remains unused. Job charges
include both decoded samples, identity maps, display/expanded arrays, morph data
and allocation overhead. Lazy descriptors deliberately overestimate geometry.
The charge is a conservative quota, not measured resident memory. This issue does
not weaken the estimator to make the acceptance capture fit.

Demand is established before field acquisition. Fields reserve three times the
mesh allowance instead of the former fixed 256 MiB. No credit is taken for mesh
quota charges as though they were actual resident physical pages. A healthy
admission remains stable while fields fill their separate cache, preventing
repeated division of remaining RAM from surrendering the mesh reservation.
Workload/settings changes trigger recalculation. Once per second, the controller
checks current headroom and other reservations, recalculates under pressure or
insufficient admission, and retries transient worker RAM refusals. The diagnostic
report distinguishes the admission snapshot from current memory/reservations.

One CPU worker still prepares meshes. Before **each** decode, it checks live
physical availability against the shared reserve, other working/cache allowances
and three job charges. Budget reductions/cancellation prevent oversized or stale
publication. In-flight charge, cache bytes/limit, requested jobs and staging counts
are exposed in the profile report. Future work stays within both the allowance
and the existing four-future-pair bound; a 2401-sample capture is not preloaded.

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

Cancellation and close join the worker and release preparation ownership.
Scientific source files are read only. These are bounded admission/reservation
rules, not a whole-process memory guarantee against arbitrary concurrent external
allocations or an OS-enforced RSS limit.

## Validation

See [issue #191 evidence and owner checks](evidence/issue-191/README.md). The
historical [PERF-003 report](MESH_PLAYBACK_MAINTENANCE_REPORT.md), earlier performance
reports and their evidence retain their original policies and review-time wording.
