# G4 implementation record

G4a–G4f are implemented and the A01–A23 gate passes for the declared synthetic
fixtures and measured workstation workloads, 2026-09-12. Implementation stops
here; the user subsequently reviewed and accepted G4. G5/G6 remain unstarted. Crash recovery preserved valid work
and continued from existing commits and edits.

Use the [acceptance ledger](docs/G4_ACCEPTANCE.md), [user guide](docs/G4_GUIDE.md),
[final evidence](docs/evidence/g4f/gate.json) and
[performance evidence](docs/evidence/g4f/performance.json). The sections below
record historical slice checkpoints; their pending statements describe those
checkpoints. The final G4f section supersedes them.
Contract: [G4_DESIGN.md](G4_DESIGN.md). Test IDs: [acceptance matrix](SIMSCOPE_ACCEPTANCE_MATRIX.md).

## G4a — PASS for source/request foundation

Added a read-only scientific adapter under `simscope_export/analysis/` using the
existing capture scanners with a bounded EOF. It pins the last complete record,
hashes that prefix, selectively decodes requested typed channels and mandatory
identity/topology arrays, and detects mutation/replacement/truncation. Appended
bytes cannot extend a pinned request. No writer defaults or capture schema changed.

Native-clock sampling, exact int64 IDs, float64 interchange, mesh/grid contiguous
epochs and identity audits are implemented. Particle position matching retains
the earlier active set; scalar/velocity values hold. A separate Python/NumPy
worker performs scans, hashes and queries with request revisions, cancellation,
lease/owner checks, quotas and actual RSS reporting. The Godot wrapper submits
small requests and rejects stale replies. It is not yet attached to the viewer UI.
The only existing renderer changes extract pure bracket/mesh compatibility logic.
The [internal schemas](docs/G4_SCHEMAS.md) establish later selection/result/state
boundaries without claiming their durable integration is already implemented.

Crash recovery preserved all surviving edits. Git fsck, tracked-file presence,
Python parsing and diffs were inspected before further work; no reset/discard or
recreation was used. No interrupted test was credited as passing.

| Validation | Result |
|---|---|
| `python -m unittest discover -s tests -v` | PASS, 53 tests: 28 existing, 18 source, 7 worker |
| `python tools/validate_analysis_foundation.py --godot GODOT --output-dir NEW_DIR` | PASS, 157 headless Python/Godot source/protocol checks |
| `python tools/validate_scene.py` with scikit-image 0.26.0 | PASS, 23 existing G3 tests |
| `python tools/validate_scene_playback.py --godot GODOT --output-dir NEW_DIR --renderer headless` | PASS, 2,457 existing playback checks |
| Actual Compatibility/Forward+ selection images | NOT RUN; G4b onward |
| Audited 100k-particle baseline comparison and long resource loops | NOT RUN; G4f |

Source tests cover portions of A11–A16/A19/A22: IDs above 2^53 and at int64 maximum,
birth/death/reorder, invalid reuse, native clocks, anonymous/index-only legacy,
topology A→B→A, f8 preservation, none/zstd parity, selective corruption, affine
trilinear oracle 13.75 (absolute tolerance 1e-12), nonfinite support, source
append/replace/truncate, quota refusal and cancellation. Full A01–A23 acceptance
remains pending; ROI integration/weights/plots/recipes have not been tested.
Identity and preserved bytes compare exactly. Worker race tests use explicit
test-only barriers, not timing guesses, and test reuse and missing-owner-lease exit.

The final tiny synthetic cross-language run measured a 0.199 ms request callback,
1.783 ms worker describe wall time / 1.773 ms CPU, 1,185,592 bytes peak workspace
charge (zero retained at completion), and 37,650,432 bytes worker RSS/HWM. Loaded
worker virtual size was 382,689,280 bytes; baseline + 1 GiB maximum workspace +
256 MiB overhead fit the provisional 2 GiB address-space guard, which was enabled.
These are one small source/protocol run, not playback or universal latency claims.
Python 3.14.7, NumPy 2.4.3, Godot 4.7.2 stable; Linux target machine.
Compact evidence is in [foundation.json](docs/evidence/g4a/foundation.json).

Failed development attempts are recorded as such: runner variable shadowing
stopped one attempt before Godot; a Godot native-signal name collision caused
a second to time out; a post-kill test queried an already reaped process and
logged an engine error despite zero assertion failures. These were corrected
and the final run contains no engine errors. Two initial G3 surface tests failed
for missing scikit-image; an isolated temporary environment supplied the existing
required 0.26.0 dependency, after which all 23 passed. No system package changed.

## G4b — PASS for definitions, picking and group primitives

Source-scoped definitions cover exact ID cohorts, anonymous record-local rows,
mesh object/vertex/face/barycentric addresses, grid addresses, fixed probes and
box/sphere/cylinder/finite-slab regions. Typed predicates preserve integer
thresholds and float64 coordinates. Set edits and explicit group union/intersection
operate on full source membership; different predicates are resolved separately.
Mixed populations are refused for pooled membership. Groups retain names and
member revisions, with rename/delete controls. The complete state has a 1 MiB
control budget, at most 256 definitions and 64 groups.

The separate Selections panel supports click/rectangle/lasso, mesh/slice tools,
typed coordinates/predicates, cohort freezing and bounded highlights. Queries run
on the private worker with a captured camera, committed native bracket and explicit
through/opaque policy. Camera depth bounds, winding/reflections, opaque source
meshes/slices, wireframes, missing styles and float32 display packing limits are
covered. Invalid legacy clocks support explicit record-index picks. Scientific
membership remains independent of later visibility, clipping, style and LOD.
No selection replaces source channels or the particle style/preload cache.

Sets above 64 members use immutable little-endian int64 assets with SHA-256,
shape and byte count. Full members are retained, including IDs above 2^53 and
2^63−1. Assets are limited to 64 MiB / 512 files per owned store and share a
2 GiB / 8192-file publication quota across stores. Worker requests carry explicit
live member pins; unused members and interrupted staging files are reclaimed.
A restarted worker retains its live viewer's assets. New workers reclaim declared
private stores only when their exact owner PID/start time has ended; unknown
files and stores are preserved. User recipes and exports are outside this cache.
G4c will account streamed numerical results under the same total disk ceiling.

A 4 MiB charged LRU retains only verified epoch/audit descriptions, scoped to the
full source-prefix hash. It avoids repeated topology/identity payload decoding
without bypassing source mutation checks. Source arrays are not retained in this
memo; source index/hash scans still occur on the worker for each request.

Derived surface object/face/point inspection validates an exact G3 artifact hash,
algorithm and original source/sample provenance. Geometry is labeled approximate
and never acquires material identity. Sample/threshold changes hide the old
artifact highlight. An explicit source-probe conversion keeps approximate placement
provenance and measures the original grid, never the extraction threshold/colors.
Optional extraction and analysis share the existing heavy-work slot.

| Validation | Result |
|---|---|
| Full Python suite with optional extraction dependency | PASS, 113 tests |
| Follow-up source/selection/worker tests including forced worker crash/restart | PASS, 37 tests |
| Existing G3 headless playback after integration | PASS, 2,457 checks |
| Final headless selection integration | PASS, 31 checks |
| Real extracted-artifact headless integration | PASS, 37 checks |
| Compatibility, NVIDIA 610.57.04 / RTX 3070 Ti | PASS, 38 checks; native MultiMesh readback and image inspected |
| Forward+, Vulkan 1.4.341 / RTX 3070 Ti | PASS, 38 checks; native MultiMesh readback and image inspected |
| 100,000-member source cohort publication | PASS; exact full asset bytes, unchanged source, bounded UI preview and no G4 callback ≥50 ms |
| Full A01–A23 / idle 100k G3 comparison / deterministic export | NOT RUN; G4c–G4f gate remains pending |

Compact reports and source hashes are in
[selection evidence](docs/evidence/g4b/selection.json). The earlier checkpoint
`77b507e` is retained in [initial evidence](docs/evidence/g4b-initial/selection.json).
Run `python tools/validate_selections.py --godot GODOT --output-dir NEW_DIR`
with `--renderer headless`, `gl_compatibility` or `forward_plus`; `--derived`
requires the existing optional scikit-image 0.26.x dependency. Run
`python tools/profile_selection_assets.py --godot GODOT --output-dir NEW_DIR
--count 100000` for the cohort profile. Use new result directories. Generated
captures, images, logs and private caches remain ignored.

Failed development tests were not counted as passes: an outdated descriptor-only
artifact assertion expected the former placeholder status; it now expects explicit
unavailability without the artifact. The first optional sphere test omitted required
spacing in its fixture; the corrected real extraction test passed. Earlier JSON
integer/dummy-renderer issues remain documented in the initial checkpoint.

## G4c — native numerical jobs and plots, scoped PASS

Added pure source reduction and quadrature routines, with no viewer/GPU inputs.
The first 16 numerical tests pass: compensated cancellation across chunk boundaries,
float64 values distinct after float32 rounding, exact integer extrema/signed128
sums, population variance, declared unweighted/weighted quantiles, invalid/negative/
zero weights, explicit algebraic weighted sums, phase/category restrictions,
finite-support coverage, node/cell quadrature and reflected/sheared triangle area.
Independent Decimal and hand-computed references include node integral 72 and cell
integral 288. Empty or invalid support is not published as a valid zero.

The larger anonymous-row fixture also exposed an existing G3 writer bug: a lazy
chunk generator captured a buffer variable that was rebound after its first
4 MiB slice. A two-line iterator correction keeps the complete backing array.
No format, checksum or allocation validation was relaxed. The new none/zstd
multi-chunk float32/float64 round-trip test passed alongside 32 relevant Python
regressions; all 23 existing G3 storage/extraction tests passed. Godot decoded the
same files with 48 exact-value checks and unchanged source hashes. Evidence:
[multi-chunk regression](docs/evidence/g4c/multichunk.json).

The native-job backend now streams exact typed observations and support records
into immutable, hash-checked 4 MiB result chunks. Explicit native-time/index ranges,
source/component traces, cohort/ROI statistics, weights/quantiles, direct-grid
quadrature, physical mass declarations, centroids, mesh areas and interval velocity
are connected. Missing channels have unknown usable counts; absent IDs remain
explicit rows. Grid `sample` associations map to G4 grid membership without a
format change. Anonymous rows refuse identity time traces.

The private worker has one fixed interval lane and one replaceable cursor lane.
At bounded Context checks it suspends the interval stack, services the latest
cursor, then resumes the same arrays/accumulators under one shared memory budget.
It never restarts completed records. Quota-lock sections defer cursor handoff
while retaining cancellation/deadline checks. Cursor CPU is excluded from the
interval CPU deadline. Source hashes can reuse a previously verified prefix only
under the exact path/device/inode/size/mtime/ctime/extent stamp; mutation or append
forces verification. Results and exact member assets share the 2 GiB disk ceiling.

Backend checkpoint: **158 Python tests PASS**, including the optional extraction
case. Tests cover exact native times/IDs, explicit absence, field integral 72,
declared scaled mass 144, recorded/derived velocity, mesh epoch expiry, cooperative
cursor service, shared admission, cancellation and mutation rollback. The same
suite without the optional dependency has 157 PASS and one SKIP. These are backend
correctness checks, not viewer performance or rendered acceptance. This backend checkpoint preceded the viewer integration recorded below.
Evidence: [native backend](docs/evidence/g4c/native-backend.json).

The viewer now offers fixed native-time/index ranges, explicit channel components,
weights/units/physical declarations, named completed results, paged full numerical
rows and a cursor-linked native scatter/min-max plot. The preview is capped at
2048 bins (512 by default); it retains first/last/min/max observations and missing
counts without inventing temporal connecting lines. Exact text values and full
row addresses are available on hover. Decimal subtraction preserves meaningful
plot differences for integer values above 2^53. Up to 16 series are offered for
selection; other exact member addresses can be requested explicitly. Multi-series
comparison/overlay is G4d. At the G4c checkpoint, up to 64 named requests/results fit a charged 48 MiB
request-state allowance. G4d reduces this allowance to 24 MiB shared with manual
bookmarks to reserve space for multiple bounded plots.
No entire result table is loaded by the viewer.

The fixed job continues through selection edits; a completed result remains named
but cannot replace a newer selection's active plot. Cursor requests are separate.
Source replacement/close cancels both lanes. Unresponsive background cancellation
has a two-second process-termination grace. Heavy surface extraction uses the same
busy check so it does not overlap numerical scans. Existing playback paths remain.

G4c validation: **163 Python tests PASS**, **23 headless temporal checks PASS**,
**24 Compatibility checks PASS** and **24 Forward+ checks PASS**, both actual
images inspected. The existing selection integration passed 31 checks and G3
playback passed 2,457 checks. A new large-affine-translation derivative fixture
uses a stable-ID mesh because G3 correctly prohibits transformed particle objects;
that validation remains unchanged. Initial malformed fixture and worker wiring
failures were corrected and are not counted as passing runs.
See [temporal viewer evidence](docs/evidence/g4c/temporal-viewer.json).
This is a scoped G4c checkpoint; whole-gate A01–A23, target-workload performance,
long quota/RSS runs, comparisons and deterministic state/export remain pending.

## G4d — diagnostics backend, IN PROGRESS

Explicit CSV import now maps chosen UTF-8 columns/delimiter, i8/f8 values, units,
source/run binding, manual offset origin and missing intervals/max gap. Raw time
and cell text plus physical CSV line spans remain in support records; entire CSV
bytes and mapping are hashed. Duplicate/reversed/nonfinite time axes remain
index-only, in original order. Blank-line skipping is explicit and counted.
Malformed rows, formula-like numeric text, out-of-range values and oversized rows
refuse with line numbers. CSV remains a separate diagnostic clock, not a capture
layer. Input is read-only, streamed up to 1 GiB/10m declared rows with 16 KiB logical
rows, under the existing worker/result budgets.

Exploratory period kernels operate on full scalar scientific rows, with exact
observed peak indices, explicit detrending/prominence/separation/lag settings,
contiguous finite segments and declared uniform sampling. Optional hold resampling
stays within each finite segment and exports held support. Contour prominence uses
bounded range-minimum queries; autocorrelation uses overlap-normalized FFT sums.
Source peak times are not fitted events or bookmarks. Short/flat/chirped/noisy
fixtures refuse candidate periods. Output preserves peak intervals, lag values,
spread/resolution/correlation evidence and separate full-run/selected-window rows.
If the supplied native result covers only a partial run, it is explicitly labeled
`full_input_range`; it cannot become a claim about unexamined capture times.

**177 Python tests PASS**, including 14 new CSV/period cases and the actual private
worker transport for import/period/full-result paging. Direct correlation sums and
known one-second signals provide independent numerical oracles (1e-12 period/ACF
absolute tolerance in the fixtures). This is backend evidence only. Diagnostic UI,
matched/common-time comparisons, multi-series plots, space-time plots and matched
render jobs remain G4d work. No whole G4d or A06–A09 gate claim yet.

## G4d — diagnostic viewer and explicit comparisons, scoped PASS

The viewer imports CSVs, retains completed results across capture switches, overlays
up to 16 separately labeled native series on explicitly mapped axes, and offers
manual time/camera bookmarks plus exploratory period controls. Source bindings and
exact time tokens survive switching; no IDs are matched across captures automatically.
Pair differences/ratios preserve exact integer differences through signed128 when
mappings are identity. Explicit value/time scale and offset mappings record units,
reference and origin. Exact outer joins retain unmatched rows as missing. Requested
common schedules retain both original source brackets, source observations and
derived evaluation values/statuses. Only source positions interpolate under G2/G3
identity/topology rules; scalar values hold. Missing support and dynamic times outside
the analyzed input range remain unavailable. Interval-velocity/period/comparison
outputs do not acquire instantaneous common-schedule semantics.

Result dependencies retain their input results and member assets within the same
64-result/512-asset caps, including after worker restart. A final bounded file-stamp
check covers every verified input before publication; changed sources discard the
new result. A vector-probe regression also corrected magnitude evaluation to form
the barycentric source vector before taking its magnitude.

**191 Python tests PASS**, **23 diagnostic headless checks PASS**, **24 actual
Compatibility checks PASS**, **24 actual Forward+ checks PASS**; both linked-plot
images inspected. The existing 23-check temporal viewer test passes. A source-switch
aliasing failure was fixed and rerun in fresh output folders; the failed run is
retained as FAIL. [Evidence](docs/evidence/g4d/comparisons-viewer.json).
Space-time diagrams and sequential matched render jobs remain in the authorized
G4d/G4e queue. This checkpoint does not close G4d or the whole acceptance gate.

## G4d — source space-time and tracer plots, scoped PASS

Direct-grid line probes and finite slab mean/integral jobs use native layer times,
original scalar arrays and the existing G3 trilinear/full-cell policies. The shared
quadrature iterator preserves the node eight-corner compensated mean, cell-centered
samples, whole-cell inclusion and absolute affine determinant exactly once. Each
full bin records exact spatial edges, source record/time, support coverage and gaps.
Tracer counts, finite sample means and explicitly declared sampling-weight estimates
remain labeled tracer samples/estimates. They never claim reconstructed field density.
Unknown locations and missing/invalid/negative weights remain explicit. Fixed anonymous
sample-local cohorts cannot become a temporal population.

The viewer offers an axis, full bin count, coordinate space/unit and a finite source
slab or tracer restriction. A bounded heatmap displays source extrema on physically
spaced native rows; empty time spans remain empty. Its image is a display preview,
with full numerical bins still available in the result table/export path. Full spatial
bins are capped at 16384 subject to scientific quotas. The inline control transport
admits at most 16384 display pixels within the design's 1024×512 outer ceiling; larger
requests refuse explicitly. Default 128×64 previews cap width by actual source bins.
This transport limit does not remove bins from numerical analysis.

**199 Python tests PASS**, **21 final headless space-time checks PASS**, **20 actual
Compatibility and 20 actual Forward+ checks PASS**, both images inspected. The actual
images precede the final two sampling-weight UI assertions, which passed headlessly;
the rendered heatmap code was unchanged. Existing 23-check native temporal integration
also passes. [Evidence](docs/evidence/g4d/space-time.json). G4d numerical and interactive
comparisons are covered; sequential matched PNG/clip jobs use the G4e durable state
and deterministic overlay barriers next. Whole G4 and performance acceptance remain
pending.

## Remaining work and risks

Continue G4f: measured lifecycle/performance, regression orchestration and the
complete acceptance ledger. G4e durable state, numerical and matched scene exports
are implemented in the checkpoints below. No G5/G6 work
has started. A01–A23 are a whole-milestone gate, not claimed by this slice.

Large-capture prefix scans remain potentially expensive, though off the UI thread.
Charged allocations, process address-space limits and actual combined viewer/worker
RSS are distinct; long eviction/close/export loops and the idle G3 baseline belong
to G4f. Opaque picking refuses work above five million exact ray/face tests.
Oversized selections refuse rather than drop members. Cache quotas can refuse if
unknown ownership prevents safe reclamation. Source extent changes retain the old
definitions and withhold current highlights; durable explicit rebinding is G4e.
The pre-existing 15 layer `.uid` files remain outside G4 changes.

## G4e — numerical export and inspection v3 checkpoint

Full numerical export streams `values.csv`, source-support JSONL and an analysis
manifest into a new directory. Exact ID/value strings, units, both input sources,
clock mappings, validity, source extents and runtime/code provenance remain intact.
All transitive capture/CSV inputs are reverified. Optional exact member assets
are copied with hashes; full scientific rows never come from a display preview.
Publication reserves a finite quota and uses a no-replace atomic directory rename
after final cancellation and input checks. Failure leaves an explicitly labeled
partial directory, preserving any competing user destination.

Inspection v3 nests the compatible visual state and saves selections/groups,
source-bound completed analysis requests, manual bookmarks, explicit comparison
bindings, current result and plot layout. Binary64 tokens preserve cursor/time and
coordinate bits across Godot/Python JSON. Portable bundles include exact member
assets and, by default, immutable result files. Result arrays stay out of control
JSON. Omitting result files keeps explicit hash references and requires the original
private results to remain available. Missing references fail; a restored request
can be explicitly recomputed. Derived artifact selections require their exact
original artifact to have been explicitly selected; those files remain external.

Restore validates source identity, asset bounds/hashes, selection epochs and
analysis requests on the worker, then verifies the unchanged viewer fingerprint
and source stamp before applying state. Playback pauses. The screenshot destination
remains session-only. Old v1/v2 state and version-1 video jobs retain their paths.
The viewer never opens a capture or CSV merely because a recipe mentions its path.

Validation: 214 Python tests (no skips); 34 headless space-time/export/recipe checks;
49 legacy inspection checks; 23 G3 storage tests; 36 existing G3 checks on the actual
OpenGL renderer, including v2 restore and combined 100k particles/128³ field/surface.
The combined image was inspected. Prerequisite/serialization failures and corrected
runs are recorded in [evidence](docs/evidence/g4e/state-export.json).

This is a scoped checkpoint for A10/A18/A20/A23. Selection-aware PNG/video, matched
run rendering, and measured G4f acceptance remain unfinished; no full G4 PASS is claimed.

## G4e — selection-aware single-scene PNG/clip checkpoint

Version-2 render jobs load a hashed v3 scene recipe, retain exact timing tokens
and resolve visible selections at every output time before the draw barrier.
The overlay parent visibility and geometry commit together. Each frame records
source extent, selection revision, requested time, independent source brackets,
exact marker positions/statuses, display thinning and image hash. The renderer
keeps complete scientific membership distinct from its bounded marker preview.

The video dialog uses this path when selections exist; ordinary scene jobs do
not start analysis scans or copy full plot results. PNG capture with G4 state
publishes a new image/state bundle through the verified worker transaction and
claims the requested PNG without replacement. Frame sidecars can be restored
using their single child asset bundle. Image hashes are checked during restore;
intentionally removed post-encoding PNGs retain explicit provenance. Session
screenshot destination preferences remain unchanged.

Both actual renderers pass 44 checks: source/ID/position oracles, exact frame
counts/times, visible marker pixels, identical PNGs under delayed rendering, and
clip → frame-sidecar restore → ordinary PNG pixel equality at matching viewport
aspect/dimensions. Images were inspected. The existing video continuation suite
also passes, including 41 UX checks, legacy jobs, trails, invalid-job refusal and
atomic cleanup. The Python suite passes 217 tests without skips.
[Evidence and failed-attempt qualifications](docs/evidence/g4e/selection-render.json).

Matched pair preparation/sequential rendering and the measured G4f gate remain
unfinished. This checkpoint does not claim full A09/A19/A20/A21 acceptance.

## G4e — matched-run preparation and sequential rendering

The native Matched runs panel selects two v3 recipes and explicit source-scoped
selection lists, scalar objects/channels, unit/time mappings and common world
coordinates. Background preparation verifies both pinned inputs and recipes,
then publishes a new pair directory with portable scene recipes, version-2
jobs and `comparison.json`. Shared camera, fixed mapped bounds and colormap
are saved exactly. Raw values and transforms are unchanged; known coordinate
unit disagreements refuse. Positive affine value scales map the shared bounds
back to each source; negative-scale numerical comparisons remain available.

One native renderer completes before the other starts. Equal start/end produces
a matched PNG snapshot (also encoded as a one-frame clip); short clips retain
all frames and sidecars. Each frame preserves raw/aligned times, both source
identities and the current run's independent selection brackets. Native source
legends are suppressed; the common mapped units/range remain in the comparison
manifest. A finite total quota includes both jobs and reserves manifest space.
The cap is 4000 frames per input, within the existing file-count bounds.

Validation: 222 Python tests without skips; 44 native preparation/render checks
on OpenGL and 44 on Vulkan, with visible scalar colors, distinct source UUIDs,
different raw time origins/scales, exact physical position oracles, matching
paired PNG pixels, sequential completion and unchanged sources. Seven native
checks also reject altered job/source/camera/time/range metadata. Images were
inspected. [Evidence and qualifications](docs/evidence/g4e/matched-render.json).
G4e functionality is implemented; G4f measured lifecycle/performance and the
complete A01–A23 acceptance ledger follow automatically.

## G4f — final validation and resource gate

A01–A23 pass for the declared fixtures and workstation workloads. The
[acceptance ledger](docs/G4_ACCEPTANCE.md) maps every ID to its evidence and
scientific limits. The [guide](docs/G4_GUIDE.md) and `examples/g4_demo.py` provide
an end-to-end synthetic walkthrough: independent particle/field clocks, exact
cohort versus ROI, recorded velocity, whole-grid mass 288 kg, lower-cylinder mass
144 kg, direct space-time samples, a supplied 2-second diagnostic, and tracer-only
refusal of original-field mass. Eight full numerical exports include provenance.

The final hardening pauses interval work during playback underflow while retaining
its scan state and servicing the latest foreground query. Pause time counts
against finite deadlines. Stuck foreground cancellation has the same bounded
termination grace as background cancellation. Scheduled interpolation charges the
larger endpoint population before allocating masks. Picking matches combined
float32 alpha/brightness visibility; numerical source values remain untouched.
Mixed finite/missing heatmap preview cells have an explicit color and caption.

PNG capture includes selection revisions in its stability fingerprint. Export
preparation cancels on timeout; frame selection waits observe render cancellation.
Image-backed state cannot publish dangling PNG claims. Malformed v2 base types
are rejected before matched-time arithmetic. A legacy video comparison found
that the G4 matched path had added an unnecessary null `comparison` field to old
timing logs. That field is now emitted only for a matched job, preserving the
original byte-level timing format without relaxing the legacy test.

The final Python suite passes 225 tests without skips. Native checks include 160
source/protocol, 2,457 G3 playback, 38 G3 lifecycle, 49 legacy inspection and 11
altered matched-job checks. Selection/derived checks pass 38 per actual renderer;
space-time/state passes 37 per actual renderer; selection PNG/video passes 44 per
renderer with exact delayed/replayed pixels. Append/mutation/quota/cancel render
checks pass 20. Matched preparation/rendering passes 50 final checks per renderer, including
timing-log provenance. Legacy baseline video equality passes all 46 unchanged
checks across both renderers.
Headless counts are not presented as rendered verification. PNGs were inspected.

Three alternating G3-baseline/G4-idle repetitions on the synthetic 81×100,000
particle capture stayed within the 10% target: maximum aggregate increase +4.0%
OpenGL and +9.54% Vulkan. The latter is frame-time p95 and close to the target.
The baseline is `99da48b1cd2dfc05cc12bcccad4c61810d5b49ef`, restored only under
`/tmp`; no historical viewer copy was added to the repository. Both runs used
960×640, 120 FPS cap, default effects, trails off and independent 4-second hidden/
visible intervals. Additional workload measurements separate overlay-only,
single-ID trace, paused ROI scan, scan while playing, CSV export, rapid cold
seeks and tiny visible held-field/mesh transitions. Original G3 playback-profiler
controls cover prebuffering, prepared replay and uncached seeks.

The full ROI scan produces all 405 requested statistics rows over 81 native
records, reads 324,000,000 decoded source bytes and peaks at 58,882,104 charged
workspace bytes. While playing it took 4.40 s OpenGL / 4.85 s Vulkan, with zero
≥50 ms playback callbacks. A single-ID trace still reads the native ID/channel
arrays: about 1.4 s and 91,276,856 peak charged bytes, demonstrating why a small
selection does not imply a cheap long-capture scan. Separate full CSV export
streams 200,835 bytes; no plot preview supplies its values. Worker and viewer
RSS, cache charges, GPU estimates and UI enqueue/ready/seek timings remain
separate in [performance evidence](docs/evidence/g4f/performance.json).

The 30-cycle lifecycle fixture passes 235 checks through 90 random seeks, full
512-record scans, six exports, repeated quota refusals and worker restarts. A
test-only 8 MiB result quota forces reclamation; at most two result directories
(1,737,306 bytes), four worker file descriptors and 45,121,536 bytes worker RSS
were observed. Source hashes remained unchanged and no worker survived close.
Finite test duration does not prove all-duration behavior; explicit allocation,
cache and file-count admission remain enforced for larger inputs.

Whole-viewer close includes existing G3 thread/cache teardown; the recorded active
OpenGL close took 79.55 ms. This is separate from interval-analysis callbacks,
which perform no bulk decode/hash/reduction. GPU figures are engine estimates.
Application-cold tests do not flush OS disk caches. Tiny field/mesh controls do
not establish large-volume performance. These qualifications preserve the G3
limits; there is no universal FPS or whole-process-memory claim.

Failed development/harness attempts are retained and described in the evidence:
wrong profiler result capture and reaped-child probing, a lifecycle harness that
kept stale owner roots, and legacy video fixtures containing new panel names or
the extra null timing field. Only completed corrected runs count as PASS.
No interrupted test was promoted to PASS.

G4 is ready for user review. G5 services/control/command orchestration, G6
automatic events/adapters/release work, web/dashboard work and external
simulations remain unstarted. No capture format, source scientific semantics
or G0–G3 validation was weakened. The original 15 unrelated layer UID files
remain untouched and excluded from G4 commits.

## Final architecture and review handoff

`simscope_export/analysis/` owns immutable pinned scientific reads, identity/epoch
validation, selection definitions, exact member assets, native sampling/reductions,
CSV/period/comparison/space-time jobs and hashed full-result storage.
`tools/analyze_selection.py` is a private child-process worker with no listener.
`viewer/selection/` owns pointer/typed selection UI and bounded marker overlays;
`viewer/analysis/` owns worker transport, plots, explicit diagnostics, durable
state and matched preparation. `viewer/video/` reuses the existing deterministic
renderer with exact G4 selection barriers and v3 sidecars. `main.gd` connects
these modules without a wholesale rewrite. The source/GPU scientific boundary
and independent layer clocks remain unchanged.

Independent numerical tolerances remain fixture-specific: source hashes, IDs,
integer arithmetic, exact float tokens, saved member sets and replayed PNG bytes
compare exactly; the affine trilinear oracle uses 1e-12 absolute tolerance.
Period/autocorrelation analytic cases use 12 decimal places; noisy accepted period
candidates use a declared 0.02 bound. Matched/rendered marker positions are checked
against analytic positions within 1e-14. Exact node/cell mass and selected-population
oracles are not inferred from rendered pixels. See the test modules in the ledger
for complete values, invalid-support cases and other tolerance conventions.

Git checkpoints preserve the separate consolidation (`4d9e99b`), source foundation
(`49b2598`), selection completion (`049f2e4`), native analysis (`bd19245`),
diagnostics/comparisons (`666debb`), space-time (`b70edcb`), state/export (`a00f9c3`),
selection video (`1ccfa33`) and matched rendering (`1308c93`). The final G4f commit
contains runtime hardening, regression tools, the synthetic demo and completed
documentation/evidence; its exact code files are hashed in the gate inventory.
No release or new tag was created during G4; `pre-g4-consolidation` remains the
baseline tag. After user review, a **1.1.0** feature release and `v1.1.0` tag would
be appropriate for these backward-compatible capabilities. Review G4 first, then
seek explicit authorization for the G5 local-control design; do not start G5 now.
