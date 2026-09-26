# Lazy SSC startup — issue #100 / PR #101

Field lookahead and Play admission are now superseded by [adaptive playback caching](SSC_ADAPTIVE_CACHE.md).
The opening and requested-record integrity behavior described here remains applicable.

The opening behavior below is retained. The Play preparation policy and sustained
playback measurements are superseded by [continuous playback](SSC_CONTINUOUS_PLAYBACK.md).

Pending owner review. This revision implements the owner's 2026-09-25 startup
policy. It supersedes the startup/preload policy in the historical
[initial profiling report](SSC_LOAD_PERFORMANCE.md) and
[PERF maintenance report](PERFORMANCE_MAINTENANCE_REPORT.md). Those reports and
`docs/evidence/issue-100/validation.json` are preserved as written.
Current compact evidence: [lazy-validation.json](evidence/issue-100/lazy-validation.json).

## Loading model

Normal opening reads the SIMSCP3 prefix/object table and fixed 80-byte record
headers. It checks version, basic metadata, record boundaries, supported declared
allocation sizes, sequence/timestamp structure and the existing index size cap.
The format has no separate clock directory, so locating the union clock still
requires a header scan. It skips descriptor bodies, payloads and commit proofs.
Legacy disposable `.sidx3.json` indexes are neither parsed nor regenerated.

Only the initial visible samples and their required descriptors are decoded for
first display. Hidden layers and future channel schemas are deferred. Requested
records undergo the existing full descriptor/shape/chunk/bounds validation and
commit/payload checks before decoded data is published. UI channel lists grow
from requested schemas; recipe restoration resolves its explicit target time.

The displayed initial scene is already usable and does not enter a full-preload
wait. Particle preparation uses a rolling window of at most eight pairs, capped
at 2 GiB by default and further restricted by safe physical RAM. Manual RAM
choices remain rolling; the old `full` setting maps to automatic rolling. Budget
estimates use bounded header metadata for the requested pair/history; a large
unrequested future record cannot determine startup admission. Workers check
working-space headroom for their own jobs. Field and mesh preparation retain
bounded current-plus-four lookahead and at most one staged GPU resource per
visible layer. No whole-timeline completion percentage or wait is required.

A failed future prefetch is remembered within its current request window. It
does not block the resident valid scene. When the failing sample is requested,
playback pauses, rejects that sample, retains the last committed scene and
reports the object, zero-based sample index, record sequence and an action, for
example `object sample 3 (record 3): Descriptor checksum mismatch. Reopen or
re-export the capture.` Seeking to another valid sample can recover. Source or
configuration changes invalidate obsolete worker results as before.

Exact ordered-int64 identity-map reuse and native descriptor string checks from
`f8e2c80` remain. Scientific values, requested times, identity matching, cache
charges, rendering algorithms and deterministic offline sampling are preserved.
No simulation/exporter or capture-format change is included.

## Explicit verification

```sh
python tools/verify_ssc.py /absolute/path/capture.ssc
```

This read-only diagnostic uses the strict Python `SceneReader` to validate all
descriptors/commit proofs and read/check every payload, with a zero-sized decoded
cache. It validates per-sample identity/topology constraints and exits nonzero
on error. It does not run a simulation or modify the capture. It is not called
by interactive opening. Explicit scientific inspection/export may still perform
whole-source provenance hashing; that is separate from opening the viewer.

## Production measurements

The owner-confirmed capture is **128³**, 14,878,413,684 bytes (13.86 GiB), with
617 three-channel field samples and 247 50k-particle samples. Its path and SHA-256
are recorded in the evidence. Whole-file hashes before/after profiling are equal.
First-field hashes, statistics and LOD match the accepted-main baseline exactly.

Godot 4.7.2, RTX 3070 Ti, approximately 47 GiB RAM, 1280×800 native windows;
serial runs with warm filesystem caches. Timing begins with viewer tree
attachment, including UI construction and opening. Executable startup, asset
imports and external integrity hashing are excluded. First scene is measured at
`frame_post_draw`; control response uses a real mouse press/release through
`Input.parse_input_event` on Play, then verifies the playback state.

| Metric | Forward+ | Compatibility |
|---|---:|---:|
| Open → synchronous open returns | 0.860 s | 0.822 s |
| Open → first rendered, usable scene | **0.878 s** | **0.856 s** |
| Open → Play click processed | **0.879 s** | **0.857 s** |
| Particle window prepared after first scene, ~0.25 s | 3 / 8 pairs | 3 / 8 pairs |
| Particle window prepared after first scene, ~1 s | 8 / 8 pairs | 8 / 8 pairs |
| Field CPU frames prepared after first scene, ~1 s | 2 | 2 |
| Field CPU frames prepared after first scene, ~2 s | 4 | 3 |
| Interaction blocked at those checkpoints | No | No |

The initial field is already displayed while its worker window is filling;
worker frame counts are not a measure of whether the visible scene exists.
The old PR revision reported 22.089 / 21.515 seconds until full particle-preload
readiness. That metric and policy are no longer the startup target. Its first
draw was 3.797 / 3.713 seconds. The revised fixed-header scan takes only a few
milliseconds; first-field decoding/statistics and UI/render setup dominate now.

Additional requests after the two-second paused background observation:

| Requested capture time | Forward+ availability | Compatibility availability |
|---|---:|---:|
| 0.1, nearby prepared sample | 18 ms | 22 ms |
| 30.8, distant seek | 661 ms | 691 ms |
| 61.6, end | 625 ms | 649 ms |
| 0.0, return to start after distant seeks | 507 ms | 513 ms |

Availability means the asynchronous sample has committed, including required
GPU staging. The previous scene remains displayed while preparing. These are
individual observed local timings, not latency guarantees. Open-return RSS was
about 715 MiB / 346 MiB; after two seconds of background work and first-field
oracle reads it was 947 MiB / 593 MiB. These are phase-specific readings, not
whole-session memory ceilings or directly comparable full-preload peaks.

## Validation and limitations

- Lazy loading: 217 assertions per renderer and headless, covering particles/fields/meshes, deferred bad
  descriptor/payload/commit/shape rejection, header allocation safety, valid
  initial controls, bounded lookahead, nonblocking corrupt future prefetch,
  requested-error pause/recovery, hidden-layer deferral and later-channel recipes.
- Explicit verifier: three valid captures accepted; 15 corrupt variants rejected.
- Scene playback: 2,457 checks per renderer. Maintenance/lifecycle: 66 + 51 per
  renderer. Synthetic 192³ field-budget/source checks: 56 per renderer.
- Float64 field preparation, probes and asynchronous/synchronous rendered equality:
  32 per renderer. Volume opacity: 98 per renderer, plus actual MP4 rendered-pixel,
  sidecar and source-integrity checks.
- Exact descriptor grammar/identity reuse: 26,406. Recipes: 2,697. Mesh playback:
  2,731. Multichunk decoding: 48. Native storage interoperability/live-source
  invalidation: 109. Python storage: five tests. All assertions passed.
- Production checks: 16 per renderer, plus first-scene/input/background metrics,
  unchanged whole-source SHA-256 and exact first-field comparison with baseline.

The earlier volume-color investigation had two failures out of 138 assertions
per renderer, reproduced on accepted main `d42a4dc` (logarithmic midpoint/slice
semantics). No color shader is changed; independent opacity/video checks pass.
The Compatibility test harness initially destroyed newly created viewers before
their first draw, producing GL cleanup warnings despite passing assertions.
Waiting for each initial draw corrected the harness; the final native run is clean.
Cold-cache storage, process startup/import latency, sustained whole-capture
throughput and a production 192³ comparison were not measured in this revision.
Initial visible preparation is still synchronous; texture staging or expensive
new samples may produce stalls or playback underflow. No solver was run.

## Reproduction and owner review

```sh
python tools/profile_field_load.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse_simscope.ssc \
  --renderer forward_plus --output-dir /tmp/lazy-forward --exercise
python tools/profile_field_load.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse_simscope.ssc \
  --renderer gl_compatibility --output-dir /tmp/lazy-compat --exercise
python tools/validate_lazy_loading.py --godot /path/to/godot \
  --renderer forward_plus --output-dir /tmp/lazy-regression
```

Use fresh output directories. The profiling driver hashes the source outside
its timed window, so it intentionally warms filesystem caches. It does not
represent a cold-cache measurement.

1. Open the confirmed production capture and immediately use the camera, menus
   and Play/Pause. There should be no full-timeline preload gate.
2. Inspect Performance: the particle window fills in the background. Seek to the
   middle/end and back; the last committed scene should stay visible until the
   requested sample is available. Pause/resume and reverse playback.
3. Check density/psi channels and probes, restore a recipe, and export a short
   deterministic clip against the accepted result. Repeat in Compatibility if used.
4. Optionally run `validate_lazy_loading.py` on disposable fixtures to inspect
   deferred corruption behavior; never corrupt the production capture.

One existing issue-linked branch and PR #101 targeting main. No merge, issue
closure, auto-merge or Project-state change; stop for owner review.
