# G4 — selections and temporal analysis

> Implementation status: G4a–G4f completed, A01–A23 gate PASS for declared
> fixtures/workloads. See [final report](G4_REPORT.md) and
> [acceptance ledger](docs/G4_ACCEPTANCE.md). The approved design and its original
> pre-implementation audit below remain the contract and historical context.
> The user accepted G4; G5/G6 have not started.

**Status:** Approved implementation contract, 2026-09-12. The user authorized
G4a–G4f after a separate documentation-consolidation commit is pushed. This
approval does not claim implementation or passing tests; canonical progress is
tracked in docs/CURRENT_STATUS.md and docs/EVIDENCE_INDEX.md.
No G5 service, web work, external simulation work or capture-format change is proposed here.

**Reviewed source:** `10ee69767449f6385060a74a0008db80b3ffe5d0` in the authoritative
`SimScope/` repository, on `main`. Tracked files were clean at review start; 15
untracked `viewer/layers/*.gd.uid` files were present and are outside this change.
The user reports manually verifying G0–G3 after consolidation. This review inspected
source and documentation; it does not claim new runtime or rendered test results.

## 1. Decision and scope

Build G4 as a source-data selection and analysis service with a small Godot UI.
A selection is a versioned description of **what to measure**, independent of
whether it is currently drawn. An analysis request binds that description to an
immutable committed source extent, channels, native sample clocks and explicit
numerical policies. Renderers consume bounded highlight/plot previews; they never
provide the scientific values used by analysis.

G4 includes persistent particle cohorts, sample-local anonymous selections, mesh
object/vertex/face inspection, source-grid probes and spatial regions, multiple
named selections/groups, source statistics and temporal traces, diagnostic CSV,
space-time views, exploratory period estimates, matched comparisons, and saved
state/CSV export. Regional statistics are already required by roadmap §9 and
acceptance A02–A07; they are not an additional simulation-analysis project.

Keep all A01–A10 goals. Clarify their G2/G3 semantics and add missing regression
cases; do not drop period estimation or matched comparison just to shorten G4.
Automatic event detection remains G6. G4 is delivered in reviewable slices G4a–G4f
below; an early slice does not by itself satisfy the full G4 gate.

## 2. Reconciliation with the current implementation

The source wins when historical prose differs. References below identify existing
code; proposed filenames in §10 are deliberately separate.

| Subject | Verified current behavior and G4 consequence |
|---|---|
| Roadmap/status | [SIMSCOPE_NEXT_DESIGN.md](SIMSCOPE_NEXT_DESIGN.md) is a roadmap. [docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md) is the consolidated status; do not recreate removed `IMPLEMENTATION_STATUS.md`/`NEXT_ACTIONS.md` files or development copies. |
| API/format | [SIMSCOPE_API.md](SIMSCOPE_API.md) primarily documents frozen v1/v2 APIs. New layered work uses `SceneCapture`/`SceneReader` in [scene.py](simscope_export/scene.py), as described in [G3_FORMAT.md](G3_FORMAT.md), [G3_GUIDE.md](G3_GUIDE.md) and [the current API guide](docs/CAPTURE_FORMAT_AND_API.md). No new SIMSCP magic is needed. |
| Object identity | SIMSCP3 has a UUID and 1–16 objects, at most one particle object. Particle transforms must be identity; mesh/grid transforms are explicit affine maps. A layer/object identifier is a dataset namespace, not proof of a material body. |
| Particles | [G3_FORMAT.md](G3_FORMAT.md) and `SceneCapture` / `SceneReader` in [scene.py](simscope_export/scene.py) require exact nonnegative int64 IDs for persistent identity and reject invalid/recycled identity histories. Anonymous data holds and cannot acquire inferred identity. |
| Random access | Per-sample decoding checks uniqueness/range; it cannot certify unread lifetimes. Python `validate_identity_history()` / `SceneReader.audit_identity()` perform history audits. G4 must expose audit coverage rather than claim that a successful random seek proves continuity. |
| Time | [scene_reader.gd](viewer/layers/scene_reader.gd) `bracket`, [timeline_sampler.gd](viewer/scene/timeline_sampler.gd), and [scene_layers.gd](viewer/layers/scene_layers.gd) `sample` distinguish the union navigation clock from each object's records. Python `SceneReader.bracket` locates records; it does not implement rendered interpolation. |
| Sampling | Shared-ID particle positions interpolate; unmatched earlier IDs hold until the next record; births/deaths occur at records. All scalar, categorical and phase channels hold. Mesh interpolation additionally requires identical ordered vertex IDs and triangle arrays. Volumes hold. G4 must not activate the roadmap's formerly proposed optional scalar interpolation. |
| Meshes | [mesh_view.gd](viewer/layers/mesh_view.gd) may expand face colors and reverse triangle winding for rendering. Neither expanded row numbers nor GPU triangle numbers are source identities. There is no reserved persistent face-ID contract. |
| Grid/probe | `SceneReader.probe` and [grid_view.gd](viewer/layers/grid_view.gd) use source arrays with trilinear spatial sampling, cell/node bounds and invalid-corner refusal. Python coordinates are float64; Godot `Vector3` coordinates here are float32. GPU LOD never determines a probe's value. |
| Derived surfaces | [extract_surface.py](tools/extract_surface.py) uses full source grids but explicitly casts algorithm input to float32. Outputs have identity `none`, algorithm/provenance and cache hashes. A level set is not a material boundary. |
| Playback | [particle_prepare.gd](viewer/layers/particle_prepare.gd), [playback_buffer.gd](viewer/layers/playback_buffer.gd), and [particle_playback.gd](viewer/layers/particle_playback.gd) prepare particles asynchronously. Hidden-particle playback skips payloads. Visible fields/meshes and explicit inspection still have synchronous paths; G4 must not route interval scans through those UI callbacks. |
| Scientific values | `_frame_from_data` and `_scalar_channels` in [main.gd](viewer/main.gd) retain source channels but also create float32 display positions/velocity magnitudes. Prepared display scalars are rendering helpers. G4 reductions and derived velocity magnitude must start from typed source channels. |
| Filters | Current particle filters hide types; mapping can also hide invalid/out-of-range markers. These are not a general selection-query language. Current `Normalization.statistics` and `_freeze_interval` are display-range helpers, not a temporal analysis engine. In SIMSCP3, traversing union frames can revisit held particle samples. |
| Recipes | [INSPECTION_STATE.md](INSPECTION_STATE.md) is the historical G1 particle contract. Current [inspection_state.gd](viewer/scene/inspection_state.gd) writes v1 for particle captures and v2 for SIMSCP3, and both restore paths reject nonempty `selections`. Layer visual state and deterministic export already exist. |
| Export | [visual_state.gd](viewer/scene/visual_state.gd), [render_job.gd](viewer/video/render_job.gd), and [render_worker.gd](viewer/video/render_worker.gd) share state, pin extent and sample before drawing. Source-prefix SHA-256 hashing is bounded but synchronous. Reuse the contract and move G4-triggered long work off the UI. |
| Reader costs | Both v3 `read_sample` implementations currently decode all arrays in an object sample. Python scans its own index and rejects a changed source stamp, including append, until refresh. The Godot reader has `pin_extent`; Python needs a tested bounded-prefix read view for G4. Selective arrays/bricks are new work, not an assumed API. |

Keep G0–G3 bytes, limits, validation and writer defaults. Preserve anonymous hold,
trails off at startup, screenshot destination session behavior, union-index slider
semantics, one active translucent volume/derived surface, and deterministic video's
existing half-open time interval. No selection changes source channels, metadata,
simulation state or committed records.

## 3. Selection model and scientific meaning

### 3.1 Common descriptor

Each selection has a stable viewer-generated key, revision, name and optional
display color, plus the following validated fields. Names/colors are presentation;
keys and revisions identify saved requests.

| Field | Contract |
|---|---|
| Source/object | Source reference, format, UUID when present, object ID and kind. A saved request also binds committed bytes and prefix SHA-256. Legacy references use the prefix identity, never a fabricated UUID implying physical identity. |
| Entity/association | One of `particle_ids`, `sample_rows`, `mesh_object`, `mesh_vertices`, `mesh_faces`, `mesh_point`, `grid_samples`, `probe`, `roi`, `derived_surface`. Association is explicit: particle/vertex/face/grid sample/location. |
| Selector | Exact ID strings, sample-local indices, a coordinate/geometry predicate, or a derived-artifact reference. No arbitrary code, expression evaluation or metadata-triggered execution. |
| Time policy | `fixed_cohort`, `sample_local`, `spatial_each_sample`, `fixed_location`, `topology_epoch`, or `static`. Availability is resolved per source record, not remembered from the last visited frame. |
| Coordinate policy | `viewer_world` or named object's `data_local`, coordinate units or `unknown`, and transform/geometry reference. Grid indices additionally bind a geometry epoch. No automatic unit conversion. |
| Predicate | Typed conjunction of allowed ID/category membership, finite-value checks and scalar/component numeric ranges, plus at most one region. Store inclusive/exclusive bounds and channels. Missing/invalid operands produce an unknown result and reported excluded count, not a successful match. |
| Creation evidence | Committed source records, requested time, resolved position/scalar statuses, camera/viewport and pick policy for screen selections, copied filter/clip settings if used. |
| Missing policy | Default `unavailable`, never zero fill, nearest-neighbor reassignment or retention of a stale number. An absent cohort member remains in the definition. |

Integer IDs and integer channel predicates are parsed and compared as integers.
JSON IDs are canonical decimal strings in [0, 2^63−1]; counts are bounded integers.
Do not pass IDs through JSON numbers, float64 or the 16-ID inspection preview.
ID selectors are sorted/deduplicated deterministically; repeated UI picks are
idempotent. Sample-local row numbers are addresses, explicitly not identities.
The UI offers one active selection and a paged named-selection list, with explicit
cohort/region/location badges, present/selected counts and pending/error status.
Picking tools are separate from orbit/scrub gestures. An inspector shows source
association and units before offering a statistic, so an unavailable operation
can explain the missing channel or identity instead of guessing a substitute.

### 3.2 Supported entities

| Entity | Meaning and temporal behavior |
|---|---|
| Persistent particle(s) | Exact IDs within capture UUID/object. A fixed cohort tracks declared identities and yields missing results when absent; continuity claims require the audit described in §4. |
| Anonymous particle(s) | Frozen source record plus selected rows; scientifically meaningful attributes at that sample only. At a later scene time it remains inspectable as a pinned sample, but has no current marker unless that record is actually held. No trajectories or identity-based time traces. A separate spatial query can measure successive anonymous populations. |
| Mesh object | The named object's successive supplied samples; counts/bounds/channel statistics are meaningful with stated association. Object persistence does not assert conserved mass, a closed solid or persistent constituent faces. |
| Mesh vertex | Explicit `vertex_id` for temporal inspection of `stable_topology` meshes; otherwise record-local vertex index. ID matching across reordered records is valid for recorded values, but display position interpolation still obeys G3's stricter ordered-ID/topology condition. |
| Mesh face | Source triangle row plus contiguous topology epoch, with ordered source vertex IDs/topology fingerprint for validation. Meaningful as a discretization element only within that epoch, not as a material face. No nearest-face rematching after remesh. |
| Mesh point | Source triangle plus barycentric coordinates. Vertex-associated channels use labeled spatial barycentric interpolation; face channels use that face's value. Dynamic use is limited to the face's topology epoch. It is a surface-coordinate probe, not an inferred particle. |
| Grid sample | Local `[i,j,k]` (xyz address; source array is `[k,j,i]`) with geometry epoch. It names a node/cell sample, not a material parcel. Geometry changes make it unavailable until explicitly rebound. |
| Volume probe | A fixed world or object-local position; each source sample maps it into that sample's grid. Geometry changes can change the support/value or make it out of bounds. It is Eulerian sampling, not flow following. |
| Spatial region | Box, sphere, finite cylinder or finite plane slab evaluated on source positions/sample locations at each native time. Membership can change. Source coordinates/units and inclusion rules are recorded. |
| Slice location | A click intersects the declared slice plane to create an independent probe. Store its world/local coordinates and creation plane; moving the displayed slice does not move the saved probe. A slice/slab region can be saved separately. |
| Derived surface | Select the whole derived artifact or a triangle/point within that exact source sample/threshold/algorithm/cache hash. Only approximate geometry inspection is offered. A new threshold or source sample does not preserve its vertices/faces. “Create source probe here” explicitly creates a new fixed-location grid probe and retains the approximate placement provenance. |

Static meshes without vertex IDs can retain vertex/face addresses because they
have exactly one reusable record; this is static geometry reuse, not an exception
allowing anonymous dynamic identity. Equal vertex counts alone never establish
correspondence. Arbitrary user channels named `face_id` are ordinary data unless
a future format contract explicitly gives them identity semantics.

### 3.3 Topology and geometry epochs

A mesh face epoch is a **contiguous** run of records with the same ordered
vertex-ID array and triangle array. For dynamic meshes without explicit vertex
identity, each record is its own epoch, even if bytes happen to match. An epoch
key includes object, its first record and fingerprint. If topology A changes to
B then back to A, the latter is a new epoch. Hash equality alone cannot resurrect
a selection. Cache epoch verification by pinned source identity; resolve it on a
worker from source history, never from seek visitation order.

A grid-index epoch similarly covers contiguous equal shape, origin, spacing,
centering and object transform. Fixed world/local probes and ROIs do not require
stable grid topology: their definition survives, and support is reevaluated.
Persistent vertex selections survive a face topology change only where their
explicit IDs remain valid; face/barycentric selections do not.

### 3.4 Multiple selections and groups

Support replace/add/subtract/toggle for explicit member sets, rename, duplicate,
delete and show/hide highlight. Definitions change only on explicit selection
commands; scrubbing changes resolution, not membership of a fixed cohort.

A group is an ordered list of selection references and revisions. It can mix
kinds/layers for organization and comparison, but it does not create a combined
physical population. Reductions across group members require the same source,
object, association, native time and compatible units/weight policy. Union and
intersection are evaluated as source-member sets, deduplicating overlap before
reduction. Mixed-object groups default to separate result series; reject an
ambiguous “total.” No nested groups/cycles or executable boolean language in G4.

“Freeze current members as cohort” explicitly materializes IDs for persistent
particles; for anonymous particles it produces sample-local rows. “Keep region”
retains the predicate and reevaluates membership. Store the distinction in the
UI, recipes and every exported result.

## 4. Particle lifespan, gaps and interpolation

| Request/event | Required behavior |
|---|---|
| Exact recorded time | Resolve exact ID membership and source values at that object's record, regardless of global record interleaving. |
| Between records `a,b` | Active population is `a`. Shared IDs use linear source-position interpolation for the current marker; removed IDs hold position from `a`; new IDs in `b` are absent until `b`. Scalars/velocity/phase/categories hold `a`. |
| Before first appearance | `absent_at_sample`; the capture does not establish an earlier physical birth time. |
| First absent record | Member disappears from current results but stays selected. Report last-present/first-absent observations, not an inferred exact physical death time. |
| After the layer's last record | Preserve G3's labeled held endpoint within the scene's range. Native temporal analysis ends at that last record; do not append repeated observations or assert continued life. |
| Long interval without records | A temporal observation gap, not evidence of ID death. G3 rendering may interpolate positions across it; analysis shows the source interval and an optional explicit gap threshold. It must not call the interior observed. |
| ID absent then present again | The writer/audit contract is violated. Report `identity_contract_violation`; never bridge or silently allocate a new lifetime for the same ID. Existing readable records can still be inspected individually. |
| Random seek | Resolve ID by source record, never a remembered row. Current-sample inspection can proceed as `declared_not_audited`; a longitudinal result stays provisional until required history validation completes. |

For a verified persistent history, audit from the object's first record through
the request's last record in the pinned extent. This detects reuse that would
be missed by auditing only a short selected window. Cache completed audit coverage
and bounded lifetime sets; append coverage may extend only after prefix validation.
Do not re-audit during every scrub or claim unseen future records are valid.
Corrupt/duplicate IDs remain hard failures for the affected sample.

History plots use native observations of position/velocity. An optional connecting
position segment is labeled linear interpolation; never connect across absent or
invalid-ID intervals. Recorded History's existing five-sample rendering behavior
and default-off setting are not the analysis data store. A long selected trajectory
uses a bounded display preview backed by full source-derived results.

## 5. Picking, visibility and rendering

Picking captures the **committed** scene revision, per-layer bracket, camera and
viewport. A pending seek is visibly pending; it cannot relabel an old pick. CPU
source geometry is projected using the captured camera, with any float32 camera
or placement limitation recorded. Large candidate queries run asynchronously.

* Particle click: select the nearest projected center within a recorded pixel
  tolerance, then nearest positive camera depth, then exact ID/row as deterministic
  tie-break. Use the committed ID-interpolated/held position, not a stale endpoint.
  Marker radius, brightness, bloom and ray opacity do not define a measurement.
* Rectangle/lasso: include projected centers inside the polygon, including its
  boundary, under the captured eligibility policy. Record camera, viewport and
  polygon as creation evidence; store resolved members for replay. A new camera
  never silently reevaluates a frozen cohort.
* Default screen eligibility: visible target layer and current type/numeric
  exclusions and clipping. Copy the relevant predicate at selection creation.
  Exclude particles whose current style produces no marker. This is a documented
  visual picking policy; the resulting cohort's subsequent statistics use source
  values regardless of appearance.
* Default screen occlusion is **through selection within the chosen layer**.
  Add an explicit opaque-geometry mode using source mesh triangles and opaque
  slice planes. Do not infer depth from additive particles or a translucent
  volume; neither is an opaque blocker. Mesh wireframe has no solid occlusion
  interior in this policy. UI labels the active policy before a query.
* Mesh picking uses source triangle addresses before render expansion/winding
  changes. Choose the nearest positive ray intersection (deterministic face-row
  tie-break); vertex mode chooses projected source vertices. Backface policy
  matches the stated mesh pick mode and is saved. Barycentric hits retain the
  original vertex ordering.
* A volume ray has no unique scalar depth. A volume click requires a displayed
  slice, specified plane/depth, or typed coordinate. Do not use brightest voxel,
  accumulated opacity or first ray-march threshold as an unlabeled probe location.
* World/local ROIs default to **all source members**, independent of camera,
  clipping, visibility or LOD. An explicit action can copy category/numeric/clip
  constraints into the definition. Changing a display clip later changes neither
  that definition nor completed results.

Use a separate selection overlay/mask. It must not write source channels, replace
colormaps or change scalar normalization. Hidden/clipped selected members remain
selected and analyzed; report selected, present and currently drawn counts
separately. Highlights obey visibility/clipping by default. A named “show hidden
selection” overlay is an explicit saved display option, not a membership change.

Do not invalidate particle style/preload caches whenever the active selection
changes. Cache a bounded source-ID-to-current-row highlight mask separately, and
update only when selection revision or source bracket changes. Overlay thinning
must be labeled and deterministic and never thin the selection itself.

## 6. Time and numerical analysis contract

### 6.1 Native observations first

The default analysis axis is each selected object's **native recorded times**.
Never iterate union slider indices and count a held volume/particle sample twice.
Each result carries a clock ID, object-local sample index, global record sequence
where present, source time and source extent. Static objects contribute one
observation with reusable-static semantics, not many independent observations.

The linked plot cursor uses the shared scene time request and an independently
resolved bracket per layer. It may show a held/interpolated evaluation, but that
cursor value is visually distinct from measured points. Positions, channel values
and spatial sampling have separate statuses; one layer-wide `interpolated` label
is not enough. Selection status also remains separate from rendering `hidden` or
GPU `unavailable` status.

Use structured fields such as:

| Field | Examples |
|---|---|
| `time_status` | `exact`, `held`, `static`, `unavailable`, `index_only` |
| `position_status` | `source`, `interpolated_by_id`, `held_unmatched`, `topology_held` |
| `value_status` | `source`, `held`, `spatially_interpolated`, `derived`, `unavailable` |
| `reason` | `before_first_sample`, `absent_at_sample`, `missing_channel`, `out_of_domain`, `nonfinite_support`, `topology_changed`, `identity_contract_violation`, `source_changed` |
| `support` | Source indices/times, interpolation alpha, selected/present/finite counts, identity audit coverage and any explicit missing interval |

No record does not automatically mean missing data: cadences can be deliberately
nonuniform. Explicit missing rows/intervals or a user-declared maximum gap create
plot breaks. Without such a declaration show observations without claiming a
continuous measured interval. Missing channels at a record are gaps; never carry
an old channel forward past a record that lacks it. Preserve NaN/Inf distinction
in value status and excluded counts; unavailable aggregates are null, not zero.

Legacy duplicate/reverse timestamps retain record-index plots and raw times.
Physical-time linking, velocity derivation, period estimation and aligned
arithmetic are unavailable on those axes; never silently sort or coalesce them.
Source intervals for statistics are inclusive recorded endpoints, explicitly
distinct from video's unchanged `[start,end)` output-frame convention.

For example, with particle records at `[0, 0.5, 1.5, 3]` and field records at
`[0, 1, 4]`, a scene cursor at `0.75` resolves particle positions from the
`0.5→1.5` pair, particle scalar values held at `0.5`, and the field held at `0`.
The two plots still contain four particle observations and three field observations;
`0.75` is a cursor evaluation, never an eighth recorded measurement.

### 6.2 Single entities and histories

* Trace any supported source scalar or explicit vector component; record component
  and association. `particle_id`/`vertex_id` are identifiers, not numeric metrics.
* Particle and identified mesh-vertex position histories use source f4/f8 values
  promoted to float64 calculation, applying the object transform once. Mesh
  temporal display follows G3 compatibility even if an ID trace spans a reorder.
* A recorded `velocity` channel is a measurement distinct from a derivative.
  Compute a requested speed from source components in float64, not display
  `velocity_magnitude`. An explicitly stored magnitude remains a separate source
  choice and takes precedence for the source channel of that name.
* If no velocity is supplied, offer an explicit derived interval velocity
  `(x[b]-x[a])/(t[b]-t[a])` for consecutive valid native observations of a verified
  ID. Store both endpoints and the interval midpoint label. No endpoint padding,
  gap bridging, acceleration, or automatic vector-basis conversion. Units require
  known position/time units; otherwise label the units unknown.
* Probe spatial policy matches G3: inverse affine, origin/spacing, source
  trilinear interpolation, node bounds at sample endpoints, cell faces half a
  spacing outside centers with clamping inside boundary half-cells. Any nonfinite
  corner makes the result unavailable, including zero-weight corners. Do not
  silently change that existing policy. An exact grid-sample query instead reads
  that sample directly; it is a separate operation.

### 6.3 Selected-channel statistics

For each native record provide selected count, present count, finite/invalid/
missing count, min/max, sum, arithmetic mean, population standard deviation and
requested quantiles. Always show the population (cohort/ROI/sample-local/mesh
association), source channel, units, record time and weighting. Zero members has
count zero and null value statistics. Missing channel has unknown usable count
and null values, not an apparent empty population with a valid zero sum.

Use deterministic source traversal and Neumaier-compensated float64 sums, with a
stable float64 variance calculation; record algorithm/reduction precision.
Preserve exact integer values in individual
rows and min/max. Integer sums can use a checked exact accumulator; means and other
float64 integer reductions disclose rounding above 2^53. Reject overflow/invalid
arithmetic instead of publishing Inf as a measurement. Phase/categorical channels
offer raw traces/counts; no default linear phase mean or category mean. Circular
statistics require a later separately tested policy.

Weights are an explicit source channel or declared geometric measure with matching
association and units. Report `sum_weights`, valid paired count, invalid/negative
weight count and zero-weight count. Require finite nonnegative weights and positive
total weight for a weighted mean; negative weights refuse that statistic. Invalid
value/weight pairs are excluded with coverage reported. Define weighted mean as
`sum(w*x)/sum(w)` and weighted population variance with the same denominator;
signed scientific values remain signed. A signed weighted sum is a separately
named algebraic operation, not a probability-weighted mean.

Exact unweighted quantiles use sorted finite values with linear interpolation at
`(n-1)*q`. Weighted quantiles use the first sorted value whose cumulative positive
weight reaches `q*sum_weights`, with endpoint conventions recorded. The algorithm
and temporary memory are explicit. If an exact request exceeds its declared
workspace budget, refuse that statistic or require a smaller selection/window;
do not silently switch to approximate quantiles or substitute a preview sample.

Temporal summary is separately requested. Default summaries are per-record,
not a mean across heterogeneous clocks. A record-weighted mean over time must
say so; duration-weighted integration requires an explicit hold/linear policy
and gap handling and is not an automatic follow-on to plotting.

### 6.4 ROI geometry, statistics and physical meaning

Boxes have min/max bounds; spheres a center/radius; finite cylinders two endpoints
and radius; plane slabs a center, orthonormal basis, two finite in-plane extents
and thickness. All use inclusive boundaries without hidden epsilon expansion.
Store exact user numeric parameters and their units. Geometry/coordinate overrides
are viewer state with provenance, never edits to source metadata.

Particle ROI statistics use source positions at that particle record and actual
channels: count, mean, extrema and centroid (arithmetic or explicitly weighted).
They work with anonymous populations too. A current-time preview can evaluate
render-compatible positions, but must label mixed support when scalar predicates
still use the earlier record; this preview is not an extra native observation.

Grid sample statistics include source sample locations inside the ROI. For volume
integrals define a separate discrete quadrature contract:

* Cell-centered data: select whole cells by center inclusion; each measure is
  `dx*dy*dz*abs(det(data_to_world.linear))`. Sum `value*measure` in float64. This is
  exact for the declared piecewise-constant selected-cell model, not an exact
  continuum integral over a curved or partially intersected ROI.
* Node-centered data: select lattice hexahedra by their center; use the mean of
  eight corner values times that same measure. This integrates the trilinear
  interpolant over each full hexahedron. The total full-grid volume uses
  `(Nx-1)*(Ny-1)*(Nz-1)` cells, never `Nx*Ny*Nz` sample volumes.
* Report requested ROI, effective included cell volume, full-cell boundary
  approximation, valid/invalid cell counts and valid volume. Any invalid required
  value makes the full-region integral unavailable; an explicitly requested
  finite-support subtotal can still be shown with its incomplete coverage.
* Transform coordinates once and use the absolute determinant once, including
  reflections/shears. Local-space ROIs measure the declared transformed region;
  world-space ROIs test transformed cell centers. Unknown coordinate units yield
  unknown integral units, not guessed physical mass.

No fractional cell clipping, AMR or conservative remapping in G4. Mesh vertex/face
statistics are association-specific; offer geometric area and explicitly
area-weighted face statistics where the source triangles are valid. Area alone
does not establish a closed volume or material mass. Mesh-object counts/topology
changes stay visible on the plot.

Only a declared physical per-particle mass can produce a “particle mass sum.” A
density-like channel on tracers yields sample statistics, not exact field mass.
A volume density integral needs declared density and length units and explicit
physical semantics; otherwise name it “integral of <channel>.” `|psi|²` remains a
norm unless a supplied model conversion states otherwise. Sampling-weight tracer
estimates require declared sampling weights/population and remain estimates.
No inferred vorticity, flux through a moving surface, conserved spin or field
reconstruction from colors/particles.

### 6.5 Multiple selections, diagnostics and comparisons

Overlay several selections' native series on one plot with distinct labels,
units, counts and statuses. Same capture/object selections share a native clock.
Different objects/captures remain separate series even when timestamps coincide.
No pooled count, automatic row zip, forward fill or implicit time conversion.

For pointwise differences/ratios, default to exact timestamp matches **only after
the user declares common time units/reference and compatible value units**. Export
unmatched points as missing. Offer an explicitly requested common time schedule
using existing held/position interpolation policies, with both source brackets
per result; this is a derived evaluation, not new observations. Unit conversion
is an explicit scale/offset mapping retained in provenance, never inferred from
similar unit labels. Do not apply a position transformation to a vector channel
without a defined vector basis.

Diagnostic CSV is an explicit local import with selected time column, value
columns, units, run/source binding and optional missing interval/max-gap mapping.
It is a separate read-only series, not a fourth SIMSCP3 object kind. Hash CSV
bytes and mapping, preserve row order/raw times and missing cells, reject malformed
rows with line numbers. Nonmonotonic/duplicate axes are index-only as above.
No arbitrary delimiter guessing that changes values, executable formulas, or
automatic channel-name-based pairing with viewer-derived data. Supplied diagnostics
and viewer-derived traces remain separately labeled. Imported unknown text is data.

A matched-run comparison stores two explicit source bindings, time-axis mapping,
selection correspondence, shared camera and coordinate convention, channel/range
policy and output settings. IDs with the same decimal text in different captures
are not matched automatically. Support sequential matched snapshots/short clips
through the existing separate renderer; simultaneous multi-scene rendering is not
needed for A09. Default scalar ranges are shared fixed ranges; independent ranges
must be visibly declared. Manual event/bounce alignment uses `aligned_time =
raw_time - declared_offset`, preserves raw times and labels the offset's origin.
Automatic bounce detection is G6. Manual bookmarks store raw times and state.

### 6.6 Space-time plots and exploratory periods

Space-time plots use one direct-grid channel along a defined axis/line, or a
finite slab reduced into specified spatial bins at each **grid-native** time.
Save spatial bin edges, coordinate units, trilinear line-sampling or slab
quadrature/reducer, source support and per-bin finite coverage. Nonuniform time
rows retain actual coordinates and explicit missing gaps. Do not render rows as
equal-time-width observations or interpolate between them without a label.
An optional held display cell extends to the next source time with a visible hold
label; no extension beyond final time. Traveling-pulse fixtures provide the oracle.

Tracer histograms can show counts, declared weighted estimates, or sample mean
per bin. They must say “tracer samples/estimate,” never “direct field density.”
No deprojection or kernel field reconstruction. Plot texture/pixel reduction is
only a preview; full result bins remain exportable.

Retain A08 in G4 as an exploratory tool on a user-selected scalar series/window:
peak intervals and autocorrelation with explicit mean/linear detrending, lag
range, minimum peak separation and peak prominence. Analyze finite contiguous
segments only. For autocorrelation require declared uniform sampling (default
maximum relative interval deviation 1e-6); nonuniform inputs offer native peak
intervals or an explicitly requested, labeled hold-resampling operation for this
derived diagnostic only. Resampling must not cross declared gaps, records cadence
and held support, and warns of cadence-induced correlation; it never changes
viewer sampling or replaces the original series. Peak times are observed timestamps,
not invented sub-sample events. At least three observed cycles are required to
report a candidate period; report peak-spacing spread, lag/sample resolution,
window length and correlation strength, and refuse a precise period for short,
flat, ambiguous, chirped or noise-dominated signals. Show full-run and selected-window
results separately. These are descriptive estimates, not confidence guarantees,
automatic event bookmarks, or evidence of a stable physical oscillation.

## 7. Source access, background work and bounded resources

### 7.1 Execution boundary

Use one repository-owned Python analysis worker process per active viewer, with
NumPy and the existing capture readers. Keep a persistent worker across requests
and scan samples inside it; never launch Python per frame or per particle. It owns
its file handles, arrays, source-index snapshot, ID/topology audit, reductions and
result files. Set numeric-library thread counts to one initially. The existing
scikit-image extraction dependency remains optional and is not required for basic
G4 selection/statistics/plots. If Python/NumPy is unavailable, viewing still works
and G4 analysis reports the missing capability.

Introduce tested source-only adapters for `CaptureReader` and `SceneReader`, with
read-only committed-prefix views and channel-selective access. The G4 worker must
not share a mutable seek handle with Godot or call `scene_layers.sample` to perform
an interval analysis. Retain all descriptor/shape/allocation checks, mandatory
identity/topology validation and requested-chunk checksums. Selective reads cannot
claim a full payload audit; retain an explicit full-audit mode. Cell/node regional
work may initially assemble one bounded source channel; sparse probe brick reads
must include all interpolation support and preserve G3's invalid-corner rule.

Both languages need a source-sampling contract independent of rendering. Extract
the existing Godot bracket/ID/mesh-compatibility policy into a small pure service
used by selection highlights and current sampling. Mirror that contract in Python
with cross-language golden cases, not two independently evolving interpretations.
Do not rewrite `main.gd` or the G2 codec to introduce the boundary.

G4a must add Python extent pinning before using it on live captures. A view ends
at an exact committed record, never refreshes itself into newer records, verifies
source UUID/prefix identity, and rejects replacement, truncation or changed prefix.
Append is accepted only if the pinned prefix remains verified; otherwise fail
visibly and require a new request. Do not weaken today's `_unchanged` check into
“ignore all changes.” No multi-gigabyte source copy is required. An explicit
“refresh analysis to latest committed data” creates a new result revision.

### 7.2 Request lifecycle and publication

Validated requests carry source identity/extent, source generation, selection and
analysis revision, operation version and request ID. There is one active analysis
request and one replaceable latest interactive request. Scrubbing supersedes
cursor/pick work; it does not repeatedly restart an explicitly launched fixed
interval job. Fixed jobs can continue to a named result while the cursor changes,
but may not replace a newer selection's active plot. Close/source replacement
cancels dependent work and discards late replies.
Checkpoint interval work between record batches to service the latest cursor/pick
request first, then resume the interval. Only one computation runs at a time;
checkpointed result chunks and accumulators remain within the same quotas. Do not
make a cursor wait behind a full-capture scan or accumulate every scrub request.
An interactive overlay is shown only when its source bracket and selection revision
match the committed scene; otherwise hide it and show pending status. Playback can
continue while it prepares. Offline export waits for that exact overlay revision.

Hashing, scans, sorting, numerical reduction, pick acceleration construction and
large export writes happen in the worker. IPC has small validated control messages
and bounded typed result chunks/files, never million-row JSON arrays. The viewer
validates request IDs, revisions, declared sizes and result hashes before publishing.
For the initial worker transport use a private job directory with atomically
published request/progress/result manifests and a cancellation marker, following
the existing extraction job-file pattern. Poll small status records at a bounded
rate and remove superseded job-owned files under quota. This needs no network
listener or G5 command endpoint. A crashed viewer is detected through an owner
liveness/lease check so the persistent worker exits and releases its handles.
Reuse the G3 stale-work principle; do not give an analysis worker direct scene,
texture, MultiMesh or shared playback-cache access.

Yield/cancel checks occur between chunks and bounded row batches. UI cancellation
acknowledges within one second; native calls may finish their bounded chunk. A
nonresponsive process is terminated after a short grace period and reaped
asynchronously; no UI `wait_to_finish` on a long analysis. Reclaim large buffers in
the worker. GPU upload/scene changes are main-thread operations, chunked to a
measured frame budget. Surface extraction and heavy analysis serialize by default
to avoid doubling peak memory; playback preparation has priority. Opening another
capture cannot leave an orphan worker or publish old geometry.

### 7.3 Initial budgets to validate, not measured promises

| Resource | Proposed default/ceiling and response |
|---|---|
| Definitions/control | 1 MiB recipe/control JSON retained; at most 256 selections, 64 groups, 256 members/group, 64 predicate terms, 2,048 lasso vertices. Oversized requests fail before allocation. |
| Materialized members | Up to 1m exact IDs per object as G2; up to 10m anonymous rows as source limits allow. Aggregate selection-member storage capped at 64 MiB of packed entries; duplication counts. UI lists are paged. Large sets use hashed sidecar blobs, not JSON expansion. |
| Source data | Existing 256 MiB/sample, 4 MiB/chunk and index ceilings unchanged. Worker decoded cache defaults to 64 MiB and can be zero. One sample's needed arrays plus bounded scratch at a time for reductions; two endpoints only for a requested interpolation. |
| Worker working memory | 512 MiB charged arrays/cache/scratch by default, 1 GiB opt-in ceiling subject to physical headroom. Preflight all copies, masks, sort indices, ID maps and output chunks; refuse jobs that do not fit. Process RSS is measured separately from this charge. Use a provisional 2 GiB process-address-space guard only after runtime preflight; report failures rather than raising it silently. |
| Viewer result memory | 64 MiB including summaries, paged results and pick structures. At most 16 plotted series and 2,048 preview bins/series; a heatmap at most 1024×512 preview pixels with validity metadata. Preserve gaps/extrema during preview reduction. |
| GPU overlays | At most 16 MiB within the existing scene GPU budget, with deterministic thinning of highlight geometry if needed. No budget increase or change to underlying volume quality without an explicit reported allocation decision. |
| Result disk | Default 2 GiB disposable G4 cache and 256 MiB in-flight temporary quota. Stream completed result chunks within a reserved output quota; preflight expected rows/bytes/free space. Explicit export may use a larger declared quota. Evict only unpinned G4-owned cache entries; never source captures, recipes or user exports. |
| Execution | One active worker request; default 120 s CPU/150 s wall deadline for interactive analyses. Longer explicit batch exports declare a finite deadline/row limit and progress. No unbounded automatic full-run jobs. |

Execution deadlines are per request, including checkpointed jobs. A persistent
process's cumulative OS CPU limit is not a per-request timer: measure request CPU
deltas and elapsed time, and restart an idle worker before any cumulative guard
would expire. Include cancellation/restart behavior in the lifecycle fixture.

Large member sets cannot fit the existing 1 MiB inspection JSON limit. Use an
optional sibling `.inspection.assets/` directory with compact little-endian typed
ID/index files, byte count and SHA-256 in the recipe. Export a portable bundle when
needed. Resolve only within the selected recipe bundle; reject traversal/symlink
escape and never open a source path just because a recipe mentions it. Copy
Inspection State reports whether referenced assets are required and is not called
self-contained in that case. Small selections remain inline.

Accounting must include coexistence with G3's default 2 GiB decoded/prepared particle
cache charge, 512 MiB visible source-pair limit, source-reader LRU, GPU replacement
resources and process overhead. Do not simply add independent “safe” budgets.
Reserve analysis headroom before starting a worker job, throttle analysis during
playback buffer underflow, and refuse oversized analysis rather than degrade the
scientific population. A 256³ f8 channel is 128 MiB; a value copy, masks and an
int64 sort permutation can exceed the default workspace before other arrays.

### 7.4 Cache keys and long captures

Keys include verified prefix hash/extent, UUID/object, record sequence, selected
channel/dtype/association, geometry/topology epoch, selector revision, sampling,
weighting, reduction version and requested interval. Display caches additionally
include camera/viewport or plot range; color changes do not invalidate numerical
results. Namespace alone, path, file size or timestamp alone is insufficient.

Stream one record at a time and all compatible selections/channels for that
record together where it reduces I/O. Cache selected channels and compact results,
not entire trajectories of every particle or all volume times. Index/epoch/audit
metadata are themselves byte-limited and can be paged to disposable disk. Avoid
one Python/Godot dictionary object per particle per time. Result counts/byte products
are checked before multiplication/allocation. Random seeks must not monotonically
increase caches or maintain an unbounded list of pending queries.

## 8. Export, saved state and reproducibility

### 8.1 Analysis results

Export a streamed long-form `values.csv` plus `analysis.json`; optionally include
selection assets and plot PNGs. CSV is the full requested numerical result, not
the decimated plot. Each row identifies result/selection revision, source/object,
entity ID or sample address, channel/component/association, native clock/record,
raw source time, value/statistic and statuses. An aggregate row points to its
complete population definition, not a preview of 16 IDs.

The manifest records:

* Format and schema versions, source path as descriptive provenance, capture UUID,
  committed prefix bytes/SHA-256, source records, external CSV hashes and mappings.
* Exact selection/group definitions and blob hashes, topology/geometry epochs,
  coordinate conventions, transforms, identity audit coverage, source dtypes,
  value/position/time units (or explicitly unknown), and channel semantics.
* Raw and requested/aligned time axes, time-reference mappings, both brackets and
  alpha for evaluated points, missing intervals/max-gap rule, hold/interpolation
  and static status. Record count is not simulation timestep count.
* Statistic/derivation name/version, weights, quadrature/inclusion policy, finite
  support/coverage, reduction precision, period/window assumptions and all display
  approximations. User semantic/unit overrides are labeled as overrides.
* Source/code revision, runtime/NumPy/algorithm versions, request signature,
  completion/cancellation status, row counts and artifact SHA-256 hashes.

Use locale-independent round-trip float text (17 significant digits for float64).
CSV ID fields are decimal text; the schema explicitly marks them as strings so
spreadsheet importers do not silently round large IDs. Store exact source-time
float64 little-endian hex alongside readable timestamps in the machine manifest
or row support table; use the same exact representation for precision-sensitive
saved request coordinates/thresholds. JSON numeric display text is not the sole
round-trip authority on this Godot build. For sampled values retain dtype and
validity tokens (`nan`, `+inf`, `-inf`, `missing`); JSON uses null plus status, never
nonstandard NaN. CSV is numerical interchange, not byte-for-byte capture backup.

Export into a new job-owned staging destination and publish only after completion
and checksums. Cancellation/failure remains visibly partial and cannot masquerade
as a completed result. Existing files are not silently overwritten. Input capture
and diagnostic CSV checksums must remain unchanged. Source replacement or mutation
during a request fails; appends never extend a pinned job's interval.

### 8.2 Inspection recipes and deterministic rendering

Introduce **inspection version 3** for selection/analysis-capable saved state,
independent of the SIMSCP3 capture version. Continue reading v1 particle and v2
scene recipes unchanged. Do not reinterpret nonempty selections in old recipes
that previously rejected them, and do not insert new required fields into old
visual-state shapes. Introduce a versioned render-job extension/new job version
when selection overlays are requested; continue accepting version-1 jobs with
their current defaults and timing behavior.

The v3 envelope stores existing visual/sample/source state plus selection schema,
definitions/groups/active selection, overlay settings, plot requests/layout/axis
ranges, selected channels/weights, manual bookmarks and analysis source extents.
Large computed results are optional hash-verified references; arrays, process IDs,
pending tasks, caches and GPU buffers are not serialized. Current cursor time and
each analysis interval are distinct. Screenshot directory and sidecar checkbox
remain session-only. Missing referenced assets fail before mutation; computed
results may be explicitly recomputed from their validated definition.

Restore validates schema, IDs, source-prefix identity, asset bounds/hashes,
channels/associations and all necessary sample/epoch references before applying
state. Unknown fields/versions fail clearly. Loading a recipe pauses automatic
clocks as today. A saved extent can either be replayed as a pinned view or refused
when incompatible; it may never be silently rebound to an appended bracket.
Explicitly rebinding to a newer extent creates a new revision. Sources must have
been explicitly opened/selected; recipe paths grant no read or execution permission.

For PNG/video, pin definitions/revisions, time policy, source extent, overlay
quality and complete result references. At each frame resolve the selection from
that frame's source brackets, await its overlay data and any requested surface,
then use the existing render completion barrier. Serialize the exact committed
selection and source statuses with the frame. Never use whichever analysis reply
arrives first. Hidden selections can have scientific results without forcing
interactive hidden-particle display preparation. Plot panels are exported
explicitly; ordinary scene video does not automatically start a full-run analysis.

## 9. Acceptance clarification and proposed fixtures

[SIMSCOPE_ACCEPTANCE_MATRIX.md](SIMSCOPE_ACCEPTANCE_MATRIX.md) remains the test-ID
registry. Its G4 section is clarified alongside this document. All G4 cases are
**NOT RUN**; no implementation is claimed. A01–A10 retain their original purpose:

| Existing criterion | Why clarification is needed |
|---|---|
| A01 | Picking now spans G3 layers; ID correctness must exclude anonymous/derived identity and state the occlusion and committed-time policy. |
| A02 | Fixed cohort and Eulerian ROI need object-native clocks, missing members and display-independent counts. |
| A03 | G3 supplies actual grids; distinguish a source discrete integral from exact continuum mass and require physical semantics/units. |
| A04 | G3 supports both node and cell centering plus affine transforms; “voxel inclusion” alone is ambiguous. |
| A05 | Preserve weighted-statistic intent; specify associations, invalid support and source/reduction precision. |
| A06 | CSV is not a SIMSCP3 layer kind; import it as a separate explicit clock without changing the format. |
| A07 | Grid and tracer sources have distinct space-time meanings; native nonuniform times and coverage must survive plotting. |
| A08 | Preserve exploratory estimation. Automated detection/bookmark generation is G6, consistent with roadmap §11; no removal from G4. |
| A09 | Preserve matched runs; source-scoped IDs and independently timed layers require explicit selection/time correspondence. Sequential matched rendering reuses G3 and avoids a new multi-scene renderer. |
| A10 | Unchanged read-only requirement. Include new result/state paths in its exercise. |

Add deterministic generators under proposed `tests/g4/` and
`tools/make_selection_fixtures.py`; generated bytes/results go into disposable
`results/g4/` or temporary directories. Proposed fixtures, not files created by
this planning change:

| Fixture | Oracle and principal cases |
|---|---|
| F01 identity/cadence | Three to eight particles at nonuniform times, shuffled rows, births/deaths, empty sample, IDs around 2^24/2^53/2^63−1; analytic positions and held scalars. Interleave volume times and a late static mesh. Test every endpoint, midpoint, reverse/random seek and after-layer-end hold. A01/A02/A11/A15. |
| F02 invalid lifetime | Reuse existing G2 mutation helpers to construct independently committed external duplicate/reappearing IDs; writers must still refuse them. A short random seek can inspect a valid record with unaudited status; full-prefix history must report reuse and break longitudinal claims. A11. |
| F03 anonymous/legacy | VBCOSM1, SIMSCP1 and anonymous v2/v3 with reordered equal counts, count changes, missing channels and duplicate/reverse legacy times. Only sample-local picks and Eulerian statistics; no inferred history or physical-time sorting. A12/A15/A22. |
| F04 mesh epochs | Static no-ID mesh; deforming stable-ID mesh; reordered IDs with same connectivity; changed connectivity; topology A→B→A; face/vertex channels with different hand values and reflected transform. Face picks map source rows; no epoch resurrection; ID traces survive permissible reorder while geometry holds. A13. |
| F05 field/probe/ROI | Noncubic f8 analytic linear field and constant field, node/cell centering, anisotropic spacing, off-center origin, rotation/shear/reflection. Whole-grid integrals equal known discrete volume; cell-boundary, cylinder/slab inclusion, invalid/zero-weight corners, geometry change and out-of-domain probes have hand-computed results. A03/A04/A07/A14. |
| F06 precision/weights | f8 values distinct after f4 rounding; large coordinate offsets with small motion, cancellation `[1e16,1,-1e16]`, all-zero/constant/invalid data, exact large integer scalars, signed values, phase seam, negative/zero/nonfinite weights and missing channels. Independent f64/decimal reference values, recorded tolerances and null/count semantics. A05/A16. |
| F07 picking/display | Deterministic camera with overlapping projected particles, behind-camera points, mesh occluder, wireframe, opaque slice and translucent field; hidden types, numeric filters, clipping and invalid styles. Toggle LOD/colormap and verify unchanged saved cohorts/results; through/opaque policies choose expected IDs. A01/A17. |
| F08 series/periods | Constant-speed traveling pulse, irregular CSV times, blank rows, explicit gaps, different time origins/units; steady/chirped/noisy/short/flat signals with fixed seeds. Test refusal plus reported candidate lag/peak intervals, full-window differences and no gap-spanning resampling. A06–A09/A15. |
| F09 state/export | Small inline and large asset-backed cohorts, mixed groups, overlapping member sets, wrong source same filename, appended bracket, missing asset, unsupported schema, boundary ID values, precision-sensitive times. v1/v2 compatibility, v3 atomic restore and fixed-extent CSV/PNG/video round trips. A09/A10/A18–A20/A23. |
| F10 bounded lifecycle | Many small records and separately a large valid sample; rapidly superseded requests; controlled worker barriers/delays/crashes; low memory/disk quota; corrupt chunk/cache; source truncate/replace/append during decode/hash/export. Assert cancellation, latest-result publication, no UI blocking or cache/RSS slope. A19–A22. |
| F11 derived surfaces | Known sphere/torus from existing synthetic fields, threshold/source change and optional extraction unavailable. Triangle/probe references retain approximation provenance and cannot track a remesh; numeric field values come from original arrays. A14/A17/A20. |

The G4 demo uses synthetic particles plus a direct field and a lower-cylinder ROI,
a small supplied diagnostic CSV, native traces and a traveling-pulse space-time
plot. Repeat the exact-integral request on a tracer-only fixture and show refusal.
External scientific data may be used as optional read-only validation when explicitly selected;
it is not required to complete G4 and no scientific simulation rerun belongs in this plan.

One F05 hand oracle uses source shape `(Nz,Ny,Nx)=(2,3,4)`, spacing
`(0.5,2,3)`, affine determinant magnitude `2`, and constant value `2`.
Full-domain cell-centered quadrature has 24 cells, world volume 144 and integral
288. The same node-centered dimensions have 6 hexahedra, volume 36 and integral
72. These different correct answers detect accidental sample-count-as-volume
logic and a duplicated/missing transform determinant.

Numerical tests compare against independent analytic/hand-computed results rather
than calling the same reducer twice. Tolerances scale with source dtype, coordinate
conditioning and algorithm; record absolute/relative limits before claiming PASS.
Test integer identity and unmodified source bytes exactly. A small actual-renderer
test separately validates picking/highlight/plot labels and saved image state on
Compatibility and Forward+; headless parsing cannot satisfy it.

## 10. Implementation breakdown and recommended order

Module names below are proposals. Keep contracts small and avoid a new framework.

| Slice | Concrete work / likely files | Exit evidence |
|---|---|---|
| **G4a — source and request foundation** | Add `simscope_export/analysis/` source adapters, sample-status/request models, pinned-prefix reading and selective source-array access; pure sampler/mesh compatibility helper under `viewer/scene/`; `viewer/analysis/analysis_jobs.gd` and `tools/analyze_selection.py` worker lifecycle. Extract only needed existing functions; preserve readers' validation. Implement golden F01–F06 sampling/audit/precision contracts before UI. | A11–A16/A19/A22 source and race tests; selective/full read parity; append/replacement safety; requests never decode/reduce on UI. |
| **G4b — definitions, picking and groups** | `viewer/selection/selection_state.gd`, selection UI and bounded highlight renderer; source query/epoch/pick resolution in analysis package. Click/rectangle/lasso, typed filters, all four ROI shapes, probes, mesh scopes, explicit cohort freeze and groups. | F01–F07/F11; A01/A02/A11–A14/A17/A23; verify rendered picking and large-selection limits. |
| **G4c — numerical traces and regions** | Source entity histories/velocity, per-channel/weighted statistics, quantiles with preflight, particle ROI summaries and node/cell field quadrature, mesh association statistics; streaming typed result store and bounded native-clock plot view. | A02–A05/A10/A15/A16, analytic ROI results, independent clocks and missing channels; compare f4 preview versus f8 source. |
| **G4d — diagnostics and temporal comparisons** | CSV binding/import, linked native plots, line/slab space-time grids, tracer estimates, manual bookmarks/time offsets, multi-selection/run comparison, exploratory peak intervals/autocorrelation. Sequential matched scene jobs reuse the current renderer. | A06–A09/A15; F08 plus same-ID/different-source comparison and missing-data refusal. |
| **G4e — durable state and export** | Inspection v3/assets and compatible render-job extension; shared snapshot/validate/apply path; CSV+manifest export, full-result pagination, fixed-extent overlay barriers, matched PNG/short clips. Evolve `inspection_state.gd`, `visual_state.gd`, `render_job.gd`, `render_worker.gd` with explicit version branches. | A09/A10/A18–A20/A23; full state/number round trip and source hashes; old recipes/jobs remain accepted. |
| **G4f — measured gate and handoff** | Synthetic end-to-end demo, targeted UI polish for selection/status clarity, quota/lifecycle profiling, regression orchestration and documentation updates. No unrelated visual redesign. | All G4 acceptance rows accounted for; renderer evidence and measured resource report; G0–G3 regression results and remaining limitations. |

Recommended order is G4a → G4b → G4c → G4d → G4e → G4f. Define the v3 descriptor
and export row schemas in G4a even though their UI/durable integration finishes
in G4e. Deliver source worker plus a small numeric query first, then persistent
particle selection and one probe as the first end-to-end path; expand entity
types only after the same contracts pass. Do not implement plots on top of the
current render scalar cache and attempt to repair provenance later.

## 11. Regression and performance gates

During implementation run focused new tests at each slice, then existing checks
appropriate to changed responsibilities. Existing entry points inspected in this
review (these commands are **not run by this documentation-only task**):

```bash
python -m unittest discover -s tests -v
python tools/validate_scene.py
python tools/regression_g3.py --godot /path/to/godot
python tools/validate_scene_render.py --godot /path/to/godot
python tools/validate_video.py --godot /path/to/godot --continuation
python tools/validate_scene_playback.py --godot /path/to/godot --output-dir results/g4/playback --renderer headless
python tools/validate_scene_timeline.py --godot /path/to/godot --label g4 --renderer gl_compatibility
```

At the final gate repeat relevant playback/selection/render cases on both actual
renderers. `regression_g3.py` does not replace all newer playback lifecycle,
stall-profile and video equality tests. Include
`viewer/layers/test_scene_playback_lifecycle.gd`, the existing
`tools/profile_scene_playback.py` harness and `tools/validate_scene_playback_video.py`
with generated jobs and an explicit pre-G4 baseline viewer. Adapt test manifests
to available synthetic captures; do not silently depend on external results or
reintroduce copied historical viewer trees into the repository.

Measure idle G4 disabled, selected overlay only, active single-ID trace, large
ROI scan, CSV export and scan-plus-playback separately. Include hidden/visible
particles, held fields, mesh transitions, warm/cold application caches and rapid
random seeks. Report p50/p95/max UI callbacks, ≥50 ms callbacks, request/ready/cancel
latency, worker CPU, decoded/prepared cache charge, viewer plus worker RSS/peak,
disk quota and measured GPU usage where available. Source counts/channels,
hardware/backend/resolution, effects, intervals and exact revisions accompany
every measurement.

Retain the roadmap's no unexplained >10% regression target for the audited 100k
particle workload. Compare G4 idle to the consolidated G3 baseline and active
analysis to a declared bounded workload; report contention rather than claiming
universal frame rates. No unbounded memory growth across a long eviction-heavy
seek/open/close/export loop. New UI callback stalls from analysis decode, hashing,
sorting or bulk result publication block G4 acceptance. Legitimate buffering is
shown with requested versus committed time, never hidden by relabeling pixels.

Principal risks and mitigations:

| Risk | Required design response |
|---|---|
| Prefix hash and Python full scan on large captures | Worker-only validation with progress/cancel, validated extent cache and compact index; do not trade integrity for speed. Measure cold/warm separately. |
| Full sample read for one trace | Selective arrays/ID support first; brick-local probes later within G4 where needed. Instrument decoded bytes, not only elapsed time. |
| ID maps, epoch audits and exact quantiles | Packed representations, bounded audit coverage, preflight sort/mask copies and refusal. No O(particles × times) resident dictionaries. |
| Multiple independent cache budgets | Admission control against combined live allocations/headroom, one heavy analysis/extraction at a time, no extra VRAM copies of scientific arrays. |
| Python worker competes with playback | One numeric thread, priority/backpressure, pause analysis during buffer starvation; no inherited simulation workloads. |
| Plot/selection result explosion | Stream full data, page tables, bound plot bins and IPC, reserve disk quota. Never omit records silently. |
| GPU/float32 placement precision | Float64 source calculations; distinguish picked camera precision from typed source coordinates; reject unrepresentable highlights without losing numeric results. |
| Restore/export races | Pin source/selection revisions, validate before mutation, deterministic barriers, discard stale results and test worker failure. |

## 12. Explicit deferred scope and review boundary

**G5:** authenticated local control endpoint, capability/path authorization,
multi-client command arbitration, optional MCP bridge, recipe command orchestration
and general automated batches, trusted plugin lifecycle. G4's internal request
schema is an extension point, not a listening service or public API promise.
Existing recipe save/load and selection reproducibility stay in G4.

**G6:** automatic event detection, threshold/peak/flux/absorber alarms, automatic
event bookmarks and bounce alignment, scientific adapter expansion and external
simulation equivalence studies, broad optional import backends and release-wide
packaging/long-session validation. G4 exploratory period estimates, manual
bookmarks, explicit CSV import and matched comparisons are not deferred to G6.

**Beyond G4, without promising a later gate:** inferred trajectories/ID remapping,
material tracking on remeshed or extracted surfaces, temporal field/phase
interpolation, arbitrary vector-basis conversion, flow-following probes, exact
partial-cell ROI clipping, moving-surface flux, vorticity or conservation claims,
AMR/unstructured fields, general mesh solid-volume integrals, automatic tracer
field reconstruction, simultaneous multi-scene rendering, and uncapped all-capture
analytics. These need explicit contracts and evidence before scheduling.

The user has authorized G4a–G4f, with a separate documentation-consolidation
commit pushed before code begins. Continue through those slices while their
required gates pass. Stop for review if an approved scientific/architectural
contract is unsatisfiable, source integrity/resource bounds cannot be preserved,
a G0–G3 guarantee would be weakened, or a required criterion needs G5/G6 scope.
No G5/G6 implementation, web/dashboard, solver change or unrelated visual
enhancement is authorized. Stop after the full G4 gate for the final handoff.
