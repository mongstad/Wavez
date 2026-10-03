# G4 internal interchange

Source and selection schemas are implemented through G4b, including exact member
assets and derived-artifact inspection. Native numerical jobs and result storage are implemented in G4c; native plots are connected to the viewer. Comparisons/space-time are implemented. G4e numerical export and inspection v3 are implemented; selection-aware single-scene PNG/video is implemented; matched rendering follows. See [the checkpoint report](../G4_REPORT.md).
The governing semantics and limits remain [G4_DESIGN.md](../G4_DESIGN.md).
These are private file/message formats, with no executable expressions or service.

## Exact primitives and source identity

An ID is a canonical decimal string in `[0, 9223372036854775807]`.
An exact finite float is `{ "text": "0.10000000000000001",
"f64_le_hex": "9a9999999999b93f" }`. Bytes are the round-trip authority;
Python validates that the descriptive text agrees. Interactive requests may use
finite JSON numbers; durable state converts scientific coordinates and times to
exact tokens. Coordinates are arrays of doubles, never Godot Vector3 storage.
Nonfinite source numbers use null, source dtype and `nan`/`+inf`/`-inf` status.

A pinned source reference contains `path`, `format`, `uuid` (the native scene UUID), decimal `committed_bytes`, `sha256`, and `complete_records`.
Paths are descriptive and must refer to an explicitly opened source. A different
prefix is a different revision. Reading an appended file never extends the
reference. Anonymous particle objects remain anonymous.

## Request and reply version 1

Requests contain exactly `version`, `id`, `scene_revision`, `selection_revision`,
`source`, `operation`, `arguments`, optional `budget`, `analysis_revision` (default 0),
`member_pins` and `result_pins`. IDs are short opaque
request strings; revisions are nonnegative bounded integers. Arguments depend
on the operation. G4a operations are `describe`, `records`, `sample`, `probe`,
`identity_audit`, `epoch`. G4b adds `define_selection`, `resolve_selection`,
`resolve_selections`, `edit_selection`, `freeze_selection`, `combine_selections`
and `pick` / `inspect_derived`. G4c adds `analyze` on the fixed background lane,
plus bounded `result_page` / `result_manifest` on the cursor lane. `analyze` requires
a fully pinned source. Background files use the `background_` prefix; a cursor
request does not supersede that ID. Fixed-job member references remain pinned.
`result_pins` holds up to 64 immutable result references. `member_pins` lists content-addressed members
retained by the live state; the worker also preserves references in the current
arguments before reclaiming unpinned assets. Bounded structural integers also accept the exact integer-valued
double representation produced by Godot's JSON parser; IDs still require strings.
Source metadata now shares the enclosing `memory_bytes` allocation pool rather
than a fixed 33 MiB cumulative-read cap. An internal `SourceSnapshot(metadata_bytes=...)`
can additionally restrict metadata; exhaustion is `memory_limit`. See
[reader accounting](WAVEZ_METADATA_BUDGET.md).

Budgets have `memory_bytes`, `wall_seconds`,
`cpu_seconds`; omitted fields use the approved defaults.

Replies contain matching request IDs/revisions and `ok`. Success carries pinned
`source`, operation `data`, and metrics. Failure carries `code` and `error`.
Worker replies add actual process `memory`, address-space `guard`, compact
`verification_memo` and `member_assets` metrics.
Source-clock support uses native indices, exact time tokens, requested time,
alpha and sampling-policy version. Value and position statuses are separate.
Publication requires all IDs/revisions still match the viewer's pending request.
Transport JSON files are bounded to 1 MiB and atomically replaced; only one
worker is owned by a viewer. Cancellation, close, owner death or lease expiry
terminate stale work. This is not a public command API.

## Selection definition version 1

The v3 recipe selection block will contain `version: 1`, `revision`, `active`,
`definitions`, `groups`, and `overlay`. Each definition has `key`, `revision`,
`name`, `source`, `object`, `kind`, `association`, `time_policy`, `selector`,
`coordinates`, `predicate`, `creation`, `missing_policy`, and `display`.
`missing_policy` is `unavailable`. Display contains color and highlight visibility.

Kinds and selector addresses follow design §3: `particle_ids`, `sample_rows`,
`mesh_object`, `mesh_vertices`, `mesh_faces`, `mesh_point`, `grid_samples`,
`probe`, `roi`, `derived_surface`. IDs are sorted unique strings. Local rows bind
an exact record. Grid and face addresses bind a contiguous epoch's first record
and fingerprint; barycentric coordinates preserve source triangle order.
Probe/ROI coordinates declare `viewer_world` or `data_local` and units. A region
has one of box, sphere, finite cylinder, finite slab geometry. Predicates are
typed conjunctions with explicit inclusivity and missing-operand counts.
Creation evidence records source brackets and optional camera/pick/filter policy.

Groups contain `key`, `revision`, `name`, and an ordered `members` array of
`{key, revision}` references. No nested groups or implicit cross-object totals.
Large exact member arrays use bounded typed asset references with content hash,
dtype, count and association; asset I/O occurs on the worker. Definitions never
store a preview of members in place of the full member set. Inline sets are at
most 64 members. Larger selectors use `ids_asset`, `rows_asset` or `xyz_asset`:
`{version:1, sha256, dtype:"i8", shape:[count] or [count,3], bytes:"decimal"}`.
Files contain exact little-endian int64 values, sorted unique IDs/rows or xyz
triples. References carry no executable path. Active definitions and incoming
request references pin members; a worker crash does not release viewer ownership.
Private owner records bind PID plus process-start time to avoid PID reuse.

A derived selector carries the source index, channel, threshold, algorithm,
`artifact_sha256`, and `artifact:{path,sha256,signature}`, with optional face and
barycentric address. The signature binds the G3 provenance; the full artifact
hash, source-prefix hash, geometry, affine and source time are revalidated on the
worker. Missing artifacts are unavailable. Explicit probe conversion records this
reference in creation evidence and creates an independent fixed source location.

## Numerical rows and manifest version 1

The streamed long-form row columns are `result_id`, `selection_key`,
`selection_revision`, `source_key`, `object`, `association`, `entity_id`,
`member_key`, `source_row`, `clock`, `sample_index`, `sequence`, `time`, `time_f64_le_hex`,
`aligned_time`, `channel`, `component`, `statistic`, `value`, `value_f64_le_hex`, `source_dtype`,
`units`, `time_status`, `position_status`, `value_status`, `reason`, and
`support_key`. Empty values have an explicit status; integer IDs stay text.
Full results stream to a bounded store/CSV; plot previews have a separate schema
and cannot be exported as complete results. Support records carry brackets,
counts, audit coverage, intervals and numerical policy.

An immutable result reference is `{version:1,id:"r-<32 hex>",manifest_sha256}`;
it contains no filesystem path. Its manifest records `version`, `algorithm`,
`request` (including full selection definitions), `source`, `objects`, `clocks`,
`channels`, `precision`, `provenance`, `runtime`, `missing_policy`, `gap_policy`,
`completion`, `columns`, `row_count`, `support_count`, `artifacts` and
`output_admission`. Artifacts specify kind, relative path, SHA-256, bytes and
contiguous row offsets/counts. Channel declarations preserve source metadata and
explicit overrides. Each numerical row has a deterministic semantic `result_id`;
the cache's random directory ID is only an address. Source f4/f8 rows preserve
exact float64 promotion bytes; integer values and IDs stay decimal text. Raw
nonfinite floating sources retain text/bytes with nonfinite status; failed derived
arithmetic has an empty value and reason. `member_key` is an address (ID/row/face/
xyz/probe), never an inferred physical identity. Historical cache pages verify
stored hashes and explicitly make no new capture evaluation.

`analyze.arguments` requires 1–16 `selections`, `mode` and an inclusive `range`
with `axis` (`native_time` or `record_index`), `start`, `end`. Modes are `trace`,
`statistics`, `population`, `integral`, `interval_velocity`, `centroid`, `area`.
Trace/statistics/integral choose 1–16 `channels` with named source `channel`,
optional numeric `component` or `magnitude`, `coordinates`, and declared `override`.
Optional `metrics`, source `weight` (same channel schema) or
`{geometric:"face_area"}`, `max_gap`, `result_bytes`, `finite_subtotal`,
`physical_mass`, `time_units`, `position_units` remain explicit request provenance.
Named source metadata lives under `channel_metadata[object][channel]`; arbitrary
other metadata does not drive calculation. Known declarations include `units`,
`semantic`, `quantity`, `physical` and descriptive vector `basis`. Physical mass
requires `actual_particle_mass` or `mass_density` plus mass units/scale; density
also requires matching declared coordinate units. Units default to unknown and
are never implicitly converted. Full-cell integration uses geometric ROI centers;
a node predicate is refused because it does not define a quadrature-cell policy.

Result chunks are at most 4 MiB, row/support records at most 16 KiB, control
messages/manifests at most 1 MiB, and pages at most 128 rows with a byte cap.
Default per-result admission reserves 256 MiB; members/results share the private
2 GiB disk and 8192-file ceiling with 256 MiB free headroom. Unknown files are
preserved with refusal. Failed/cancelled staging is never a complete result.
Durable numerical export is implemented in the G4e checkpoint. `result_series` and `result_plot` use the background
lane because they may scan the full result. The former offers the first 16 distinct
`{selection_key,channel,component,statistic,member_key}` series and an explicit
`more` flag. The latter requires that exact series key, `result` and optional
`bins` (1–2048, default 512). It returns units, clock/time units, native/index axis,
counts, exact text x/y ranges, `bin_count` and nonempty bins. Each bin reports
finite/missing counts and first/last/min/max points as
`[x_text,value_text,full_row_offset_text,normalized_x,normalized_y]`.
Normalization uses Decimal subtraction before display conversion; native values
are not obtained by inverting a color or canvas coordinate. Preview policy states
scatter/min-max display only, no gap filling. Incompatible clocks/units within a
series are refused. Preview files are never substituted for full numerical rows.

## Diagnostic import and period jobs (G4d backend)

`import_csv` and `estimate_period` are fixed background jobs with fully pinned
capture/run bindings and the same result writer. CSV arguments explicitly choose
`path`, `key`, `time_column`, `time_units`, `delimiter` and 1–16 `values` entries
(`column`, `dtype` i8/f8, `units`, optional `semantic`). Optional fields are `name`,
`blank_lines` (`reject` default or explicit counted `skip`), `row_limit` (default
1m, ceiling 10m), `max_gap`, `missing_intervals`, `time_offset`, `offset_origin`
and `result_bytes`. Missing intervals are inclusive pairs on the raw CSV clock;
aligned time is raw time minus the declared offset. Bad axes refuse physical
alignment and remain index-only. CSV line spans, raw times/values, missing coverage
and source byte/hash identity survive import. The current file must still match
before new period arithmetic; historical cached viewing alone does not re-evaluate it.

`estimate_period` requires `result`, exact `series`, explicit native `window` and
`options`: `method` peak_spacing/autocorrelation, `detrend` mean/linear, positive
`lag_range`, `min_separation` and nonnegative `prominence`. Autocorrelation requires
`uniform:true` (relative interval tolerance default 1e-6) or explicit positive
`hold_cadence`. Optional acceptance thresholds `relative_spread` (default .15) and
`min_correlation` (default .6) are retained as declared exploratory assumptions.
At least three observed peak intervals are required. Results preserve source peak
rows, period candidates/refusal reasons, interval pairs, full lag values and
resampled held support. Whole input and selected window remain separate;
`full_run` is used only when coverage establishes the whole supplied native/CSV
series, otherwise `full_input_range`. Lag curves have axis `lag`, distinct from
native scene time. No automatic event generation or interpretation is performed.

## Explicit comparison and linked plots (G4d)

`compare_series` takes `left`, `right`, `operation` (`difference`/`ratio`) and
`join`. Each binding requires a pinned `source`, immutable `result`, exact `series`,
`time` mapping and `value` mapping. Mappings explicitly declare target `units` and
`reference`, optional finite `scale`, `offset`, descriptive `origin`. Changing a
unit declaration requires an explicit scale. Time uses `raw*scale-offset`; value
uses `raw*scale+offset`. Time scales are positive, value scales nonzero. Compatible
units/reference on both bindings are required; no semantic pairing by ID/name.

`join:{mode:"exact"}` is an outer exact-time join: unmatched rows remain missing.
`join:{mode:"schedule",start,step,count}` explicitly evaluates a finite increasing
common schedule (at most one million times, subject to result/memory/CPU quotas).
This accepts original native analyses or CSVs, refusing interval velocities and
other derived diagnostics. Scalars hold within the analyzed domain; exact source
position traces interpolate only under the existing particle/mesh contracts.
Declared gaps and missing/absent support remain unavailable. Original input row,
value/bit token and both native result/source brackets remain distinct from the
evaluated value. Output rows say `derived_evaluation`, never native observations.

`result_overlay` is a background cached-result preview with 1–16 labeled `bindings`
and explicit `bins` (default 128 per series, maximum 2048, total control <=1 MiB).
Each binding uses the same mapping schema; shared axes require compatible declared
units/reference. Native clocks, counts, gaps and full row pointers remain separate.
No pooled statistics or connecting lines are implied by display superposition.
Record-index and lag plots remain individual plots rather than physical overlays.
Raw category/phase/ID traces can be overlaid without value conversions; comparison
arithmetic on those semantics is refused. Historical previews do not re-evaluate
source captures. New numerical comparison jobs verify their bound source inputs.

Private result collection follows transitive result dependencies (64 total); member
assets referenced by retained results are also pinned (512 assets, 64 MiB packed).
Immediately before new result publication, every verified source/CSV/member file
must retain its last verified device/inode/size/mtime/ctime stamp. An intervening
change fails publication rather than slipping through a final cursor handoff.

## Native space-time results (G4d)

`space_time` is a fixed source background job. Required: `object`, `mode`
(`grid_line`, `grid_slab`, `tracer_bins`), inclusive native/index `range`, and
`spatial:{start,end,bins,space,units}`. Start/end are source-coordinate xyz, bin
count 1–16384, coordinate space explicit local/world. Uniform spatial edges run
from zero to axis length, with exact evaluated lower/upper tokens on every support
row. Spatial slabs require a finite `slab` in the existing ROI schema. Projection
bins include lower bounds, exclude upper bounds except the final inclusive edge.

Line mode uses scalar `channel` and reducer `probe`. Slab modes use `mean` or
`integral` over whole source quadrature cells selected by center. Direct-grid
values and original geometry remain distinct from display previews. Tracer mode
uses `count` without a value channel, `sample_mean`, or `weighted_estimate` with
an explicitly declared `sampling_weight` channel and descriptive
`sampling_population`. Optional same-object `selection` restricts the particle
population. Anonymous cohorts remain local to their recorded sample. Count/finite
coverage, absent cohort members, invalid positions, value/weight support and exact
bin/time provenance are explicit. Optional `max_gap` marks native gaps; no extra
union-clock observations are generated. Missing complete weighted support does
not become zero or an unlabeled subtotal.

`result_heatmap` scans the complete scientific result in the background and returns
a bounded preview (`result`, optional `width`, `height`). Default dimensions are
128×64, width capped by full source bin count. Inline pixels are capped at 16384
within 1024×512; larger controls refuse and can be requested at a smaller display
size. Each 16-byte little-endian pixel has float32 normalized min/max and uint32
finite/missing counts, hex encoded under the 1 MiB control ceiling. Exact global
value/time ranges and each occupied row's actual native coordinates remain in
metadata. Decimal normalization preserves source float64 differences before the
explicit display conversion. The current canvas colors preview maxima and labels
that policy; full extrema/coverage remain in the typed preview. Scientific exports
always read the full native result, never this texture or normalized lane.

## Numerical export

`export_analysis` uses the background lane with a fully pinned source and
`result`, absolute **new directory** `destination`, explicit `quota_bytes`
(default 256 MiB; 1 MiB–64 GiB), and `include_members` (default true). It streams
full `values.csv` and `support.jsonl`, copies dependency manifests and optional
exact members, and writes `analysis.json` with artifact hashes and full provenance.
All CSV cells are strings; import `entity_id` as text. The final directory is
published without replacement after final source/cancellation verification.
A failed attempt retains a `.NAME.partial-UUID/status.json` marked failed.
No user source or existing destination is modified.

## Inspection version 3 and rendering

The envelope is `{kind:"wavez-inspection",version:3,source,payload,members,
results,bundled_results}`. `payload` contains `base` (nested native scene v2
visual/sample snapshot), `selections` (version-1 selection state), and `analysis`.
Analysis stores at most 64 named result/request summaries, the current result,
explicit left/right/16 overlay bindings, up to 256 manual bookmarks and a bounded
series/member/plot-bin/heatmap layout. No pending jobs, cache ownership, PIDs, GPU
buffers or session screenshot preferences are serialized.

Each floating payload value uses `{"$f64":"little-endian hex","text":"decimal"}`.
Existing `{text,f64_le_hex}` source tokens remain supported inside the payload.
V3 accepts equivalent decimal spellings only when they match the exact finite
bits, then canonicalizes their text; old exact token parsers are unchanged.
Structural versions, indices/counts and member-array shapes remain bounded exact
integers; scientific int64 IDs/values remain decimal strings. Selection overlay
`maximum` is 1–512 combined markers, consistent with the current query protocol.

`save_recipe` takes `recipe`, absolute new bundle `destination`, `quota_bytes`
and `opened_paths`; `load_recipe` takes an explicitly selected bundle
`inspection.json` `path` and session `opened_paths`. Both use the background lane
and fully pinned primary source. The control allowance is 960 KiB, leaving IPC
headroom inside 1 MiB. Source paths in a recipe do not authorize reads.

Bundles contain `inspection.json`, `members/SHA.i8` (64 MiB/512-file ceiling)
and optional `results/r-ID/` immutable result artifacts. Source captures and CSVs
remain external. Setting `bundled_results:false` keeps hash-verified references
to existing private results; unavailable results refuse restore. The viewer
offers explicit recomputation of a restored request. Original derived artifacts
also remain external and must have been explicitly selected before validation.
Traversal, links, wrong hashes, conflicting reference shapes/hashes, stale group
revisions, changed source extents and unsupported selection/request fields fail.

Restore validates the entire state and assets before UI mutation. The native
viewer also validates the visual schema, checks its unchanged view fingerprint
and source stamp, and pauses playback on apply. Appended extents incompatible
with the opened view are refused; they are not silently rebound. Computed plots
are requested explicitly after restore; no interval scan starts automatically.
Native v2 recipes retain their schema and rejection of nonempty selections.
Capture-specific v1 recipes are retired, including nested v1 state in a v3 envelope.

Version-2 render jobs are implemented. They retain the v1 fields and add
`inspection_path` (the job's `recipe.inspection/inspection.json`), its
`inspection_sha256`, explicit `opened_paths`, decimal `output_quota_bytes`
and `exact_timing` (packed binary64 start/end/rate with integer FPS). The exact
timing is authoritative when parsing JSON. Source extents are pinned before
building the export timeline; the recipe is validated once, then each frame
forces its exact source-selection resolution before drawing. Version-1 jobs
retain their previous behavior.

Per-frame v3 sidecars may specify `asset_directory:"recipe.inspection"`, a
single child directory within the selected sidecar's directory. `base.render`
contains the exact selection-frame evidence and PNG identity/dimensions. Loader
paths stay inside the selected bundle; hashes and dimensions are checked for
retained images. Explicit `retained_after_encode:false` permits the known PNG
to be absent after successful encoding. Ordinary G4 PNG/state capture bundles
`image.png` and `inspection.json`, then claims the chosen PNG name without
overwriting an existing destination. `save_recipe` accepts an explicit
`image:{path}` only for this captured-image input; it never reads image paths
merely from unvalidated recipe text.

G4 scene video uses a scene-only recipe with selections and empty analysis
results/layout: plotted data is not implicitly recomputed or filmed. Its finite
quota (1 MiB–64 GiB) includes frames, sidecars, assets and encoding. Conservative
admission preserves 256 MiB free space; 8,192 files / 1,024 directories bound a
job. The file-count ceiling is checked before rendering. These G4 bounds do not
change version-1 export limits. Pixel comparison requires equal renderer,
viewport aspect/dimensions and visual settings.

`prepare_matched_render` takes `left`, `right`, packed `common`, explicit
`opened_paths` and a new `destination`. Each input names its full source identity,
`recipe_path`/`recipe_sha256`, nonempty `selection_keys`, scalar `object`/`channel`,
and packed `time`/`value` mappings using the comparison units/reference/scale/offset
contract. Common settings contain the shared camera, declared viewer-world
coordinates, fixed mapped range, colormap, aligned timing, dimensions, quality
and total byte quota. No source identity or geometry correspondence is inferred.

The atomic output contains `comparison.json` and `left`/`right` job directories.
Version-2 jobs now optionally carry `exact_state` and packed `comparison` metadata;
new jobs save both. Exact state/timing are authoritative on parse. Per-frame
comparison metadata retains both inputs plus raw and aligned frame times.
Preparation/restore use source/member validation on the existing background
worker; rendering remains sequential through the existing native renderer.
Positive value scales preserve the shared colormap direction. Known coordinate
unit differences refuse because matched rendering does not rescale/register
geometry. Missing source samples retain ordinary G2/G3 statuses.

## G4f runtime completion

The native wrapper sends a private playback-pressure flag while a background
request and particle-buffer underflow coincide. The worker preserves its exact
scan stack, services the latest foreground query, and resumes after pressure
clears. Paused time counts against the wall deadline. Replies report cumulative
worker pressure pauses/time. Cancellation has a two-second acknowledgement grace
period before a stuck child is terminated; stale revisions never publish.

PNG/state preparation cancels on timeout. An image-backed recipe cannot be
resaved with a dangling image claim: an explicit captured PNG is required.
Render cancellation is checked while awaiting exact selection geometry.
Version-2 job validation checks compatible base types before comparison arithmetic.
See [final acceptance](G4_ACCEPTANCE.md) for the validated implementation gate.
