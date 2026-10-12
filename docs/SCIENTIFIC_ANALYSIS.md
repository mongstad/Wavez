# Scientific selection and analysis contract

This is the living behavioral contract for source-data selection, numerical
analysis and reproducible inspection. The accepted implementation is in
`wavez_export/analysis/`, `viewer/analysis/` and `tools/analyze_selection.py`.
[Schemas and resource limits](ANALYSIS_SCHEMAS.md) specify the private interchange;
[the user guide](ANALYSIS_GUIDE.md) describes current Tools routes.
[Scientific acceptance criteria](SCIENTIFIC_ACCEPTANCE.md) preserve the criterion
IDs and independent oracles. [The original G4 ledger](G4_ACCEPTANCE.md) records its
historical tests and limits; this document does not claim new runtime validation.

## 1. Scope

A selection describes what to measure independently of whether it is drawn.
Requests bind it to an immutable committed source extent, source channels,
object-native clocks and explicit numerical policies. Renderers consume bounded
highlight/plot previews and never supply scientific values for analysis.

Supported work includes exact particle cohorts, anonymous sample-local rows,
mesh object/vertex/face inspection, grid probes and regions, named selections and
groups, statistics/traces, diagnostic CSV, space-time views, exploratory period
estimates, matched comparisons and durable numerical/inspection export.
Automatic event detection, network control and new solver integration require
separate owner authorization; see [current boundaries](CURRENT_STATUS.md).

## 2. Sources and ownership

Only [WVZ1](WVZ1_FORMAT.md) `.wvz` captures are supported. `SceneCapture` and
`SceneReader` own typed source arrays, UUID/object identity, record framing and
checksums. The Python `SourceSnapshot` adapter pins a committed prefix and reads
selected arrays under the request budget. Object names are namespaces, not
proof of physical bodies. No selection changes source channels, metadata,
simulation state, coordinates or committed records.

The union timeline is navigation; each object's native records are observations.
Explicit particle IDs support position interpolation under the wire contract;
scalars/categories/phase and volumes hold. Mesh interpolation requires identical
ordered vertex IDs and triangle arrays. Anonymous rows acquire no inferred
identity. Random access reports identity audit coverage instead of certifying
unread lifetimes.

GPU positions/scalars/LOD are display helpers. Source probes and reductions use
original typed arrays, with declared spatial interpolation and precision.
Selections have their own worker, revisions and quotas; display filters,
visibility and playback preparation remain independent.

### 2.1 Hardware-independent scientific integrity boundary

Keep these three layers distinct when interpreting or reporting a value:

| Layer | Authority and limits |
|---|---|
| Stored source data | WVZ1 decoded arrays, particle/vertex IDs, coordinates, field samples, mesh topology, units, native sample times and metadata are authoritative for the capture, subject to the declared storage precision. Lossless compression preserves those bytes. An f4 export has already limited source precision; decoding it into f8 cannot recover discarded precision. Capture fidelity does not certify the solver, physical model or supplied metadata. |
| Derived measurement | Identify the source extent/hash, object/channel/association, native sample or endpoints, algorithm, spatial/temporal interpolation, calculation precision, units, missing support and limitations. Source-array statistics, trilinear/barycentric probes, integrals and interval velocity are computations with declared policies. An interpolated value is derived, never an additional stored observation. |
| Visual presentation | GPU float32 conversion, preview LOD, texture filtering, colormaps, blending, rasterization and image encoding produce presentation. Pixels may vary with GPU/driver; pixel identity and universal GPU equivalence are not required or promised. Screenshot colors and filtered GPU texels must not supply stored-sample readouts or numerical Analysis values. |

Stored sample readouts must address the decoded authoritative array directly.
For example, a `grid_samples` trace reads the selected zyx array element; an
arbitrary `probe` computes source trilinear interpolation and reports
`spatially_interpolated`. Both bind the object's native field sample, which can
be held at a scene cursor time. GPU sample-center appearance is not a substitute
for either operation. See §6 for measurement policies and §8 for export provenance.

The intended source/measurement boundary is independent of display hardware.
This is not a promise of last-bit agreement between every CPU/library/build:
Python calculations use float64, while this Godot build's native probe locations,
transforms and screen-pick camera/ray inputs can use float32. A native **Source
probe** computes from its prepared full-resolution source arrays, not its RF
texture, but its displayed number is a spatial estimate with coordinate precision
limits. Its UI currently shows the value and source time without an explicit
`spatially_interpolated` badge; do not interpret the name as an exact stored-sample
or payload-verification claim.

Normal interactive playback uses structural reads and skips stored/raw payload
SHA comparisons. Native Source probes inherit that limitation. Python
`SceneReader`, selected `SourceSnapshot` reads and offline readers check payload
hashes; a selected read does not verify unrelated unread channels or a complete
identity lifetime. Use `tools/verify_wvz.py` for whole-capture integrity and the
separate identity audit where continuity matters. Internal hashes detect
inconsistency, not physical truth, author authenticity or a coordinated rewrite.
See [wire/storage precision](WVZ1_FORMAT.md) and
[playback integrity policy](PLAYBACK_INTEGRITY.md).

The [#375 inspection-path audit](SCIENTIFIC_INTEGRITY_AUDIT.md) identifies tested
source access, documented derivations, display-only paths, known limits and
**NOT VERIFIED** behavior. Selection/Analysis remains experimental for scientific
interpretation beyond those declared fixtures. Historical G4 PASS results retain
their fixture-specific meaning; they do not validate every function, scientific
application or GPU/driver combination. Report materially misleading imagery as
a scoped presentation defect with source-value evidence, rather than treating
all visual differences as source corruption.

## 3. Selection model and scientific meaning

### 3.1 Common descriptor

Each selection has a stable viewer-generated key, revision, name and optional
display color, plus the following validated fields. Names/colors are presentation;
keys and revisions identify saved requests.

| Field | Contract |
|---|---|
| Source/object | Source reference, format, UUID when present, object ID and kind. A saved request also binds committed bytes and prefix SHA-256. The UUID and prefix identity never imply physical identity. |
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

Diagnostic CSV duplicate/reverse timestamps retain record-index plots and raw times.
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
It is a separate read-only series, not a fourth WVZ1 object kind. Hash CSV
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

Use the source-only `SourceSnapshot` adapter with read-only committed-prefix
views and channel-selective access. The G4 worker must
not share a mutable seek handle with Godot or call `scene_layers.sample` to perform
an interval analysis. Retain all descriptor/shape/allocation checks, mandatory
identity/topology validation and requested-chunk checksums. Selective reads cannot
claim a full payload audit; retain an explicit full-audit mode. Cell/node regional
work may initially assemble one bounded source channel; sparse probe brick reads
must include all interpolation support and preserve G3's invalid-corner rule.

Both languages use a source-sampling contract independent of rendering. The
Godot bracket/ID/mesh-compatibility helper is used by selection highlights and
current sampling. Mirror that contract in Python
with cross-language golden cases, not two independently evolving interpretations.
Do not rewrite `main.gd` or the G2 codec to introduce the boundary.

Python extent pinning applies before analysis of live captures. A view ends
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

### 7.3 Resource admission

The exact protocol and allocation limits live in [ANALYSIS_SCHEMAS.md](ANALYSIS_SCHEMAS.md),
with worker enforcement in `wavez_export/analysis/`. Admission counts retained
arrays, copies, masks, sort indices, ID maps, output chunks and source metadata.
Refuse an oversized request; never reduce its scientific population silently.
Allocation charges and OS process RSS are separate measurements.

| Resource | Current boundary |
| --- | --- |
| Definitions/control | 1 MiB control/recipe JSON; bounded selections, groups, predicates and lasso vertices. Validate before allocation. |
| Exact members | Packed, hashed integer assets; 64 MiB and 512-file ceiling. Large sets remain complete and UI lists are paged. |
| Source samples | Wire limits remain 256 MiB/sample and 4 MiB raw chunks. Metadata shares the request workspace; see [reader accounting](WAVEZ_METADATA_BUDGET.md). |
| Worker | 512 MiB default charged workspace; explicit finite CPU/wall deadlines. Runtime address-space guarding follows the current worker preflight. |
| Viewer/plots | Separate 64 MiB result and 16 MiB overlay allowances; at most 16 series and 2,048 plot bins/series. Inline space-time previews and full spatial requests admit at most 16,384 pixels/bins respectively. |
| Result disk | Default 2 GiB private disposable cache, 256 MiB result admission and free headroom; 8,192-file ceiling. Only unpinned application-owned cache entries may be evicted. |
| Export | Explicit finite output quota, including frames, sidecars and assets. Numerical/export limits are documented in the schemas; captures and user exports are never cache-eviction targets. |

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

Accounting must include coexistence with the current [playback preparation](ROLLING_PLAYBACK_CACHE.md)
reservations, visible source pairs, source-reader LRU, GPU replacement resources
and process overhead. Do not simply add independent “safe” budgets.
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

**Inspection version 3** stores selection/analysis-capable saved state independently
of the WVZ1 capture version. Existing v1 particle and v2 scene inspections retain
their supported field semantics, subject to the current WVZ1 source boundary.
Explicit Matched Views scientific render jobs use version 2. File → Export →
Video always uses visual version-1 jobs, regardless of existing selections; it
excludes Selection/Analysis overlays and does not run scientific selection
queries or require Python/NumPy. Current source-kind identifiers and validation live
in [the inspection contract](../INSPECTION_STATE.md) and [schemas](ANALYSIS_SCHEMAS.md).

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

For scientific PNG bundles and explicitly requested Matched Views, pin definitions/revisions, time policy, source extent, overlay
quality and complete result references. At each frame resolve the selection from
that frame's source brackets, await its overlay data and any requested surface,
then use the existing render completion barrier. Serialize the exact committed
selection and source statuses with the frame. Never use whichever analysis reply
arrives first. Hidden selections can have scientific results without forcing
interactive hidden-particle display preparation. Plot panels are exported
explicitly. File → Export → Video excludes all Selection highlights and Analysis
overlays, irrespective of the current session state; it never evaluates membership,
creates a portable recipe or starts Analysis. These features remain interactive
and independent. Their end-to-end scientific validation is incomplete, so ordinary
MP4 files contain supported visualization/presentation elements only. See
[video](VIDEO_EXPORT.md).

## 9. Scientific acceptance and fixtures

[SCIENTIFIC_ACCEPTANCE.md](SCIENTIFIC_ACCEPTANCE.md) is the criterion registry.
The original [G4 ledger](G4_ACCEPTANCE.md) records the accepted A01–A23 gate for
its declared fixtures and workstation measurements. A future change runs the
criteria relevant to its responsibilities; this document grants no new work.

| Existing criterion | Why clarification is needed |
|---|---|
| A01 | Picking now spans G3 layers; ID correctness must exclude anonymous/derived identity and state the occlusion and committed-time policy. |
| A02 | Fixed cohort and Eulerian ROI need object-native clocks, missing members and display-independent counts. |
| A03 | G3 supplies actual grids; distinguish a source discrete integral from exact continuum mass and require physical semantics/units. |
| A04 | G3 supports both node and cell centering plus affine transforms; “voxel inclusion” alone is ambiguous. |
| A05 | Preserve weighted-statistic intent; specify associations, invalid support and source/reduction precision. |
| A06 | CSV is not a WVZ1 layer kind; import it as a separate explicit clock without changing the format. |
| A07 | Grid and tracer sources have distinct space-time meanings; native nonuniform times and coverage must survive plotting. |
| A08 | Preserve exploratory estimation. Automated detection/bookmark generation is G6, consistent with roadmap §11; no removal from G4. |
| A09 | Preserve matched runs; source-scoped IDs and independently timed layers require explicit selection/time correspondence. Sequential matched rendering reuses G3 and avoids a new multi-scene renderer. |
| A10 | Unchanged read-only requirement. Include new result/state paths in its exercise. |

Small deterministic fixtures under `tests/g4/`, `examples/g4_demo.py` and the
focused `tools/validate_*` scripts exercise these oracles. Generated captures and
results go to temporary directories or ignored `results/`, never into Git.
The fixture labels below retain the accepted independent-oracle definitions.

| Fixture | Oracle and principal cases |
|---|---|
| F01 identity/cadence | Three to eight particles at nonuniform times, shuffled rows, births/deaths, empty sample, IDs around 2^24/2^53/2^63−1; analytic positions and held scalars. Interleave volume times and a late static mesh. Test every endpoint, midpoint, reverse/random seek and after-layer-end hold. A01/A02/A11/A15. |
| F02 invalid lifetime | Reuse existing G2 mutation helpers to construct independently committed external duplicate/reappearing IDs; writers must still refuse them. A short random seek can inspect a valid record with unaudited status; full-prefix history must report reuse and break longitudinal claims. A11. |
| F03 anonymous/time axes | Anonymous WVZ1 objects with reordered equal counts, count changes and missing channels, plus diagnostic CSV duplicate/reverse times. Only sample-local picks and Eulerian statistics; no inferred history or physical-time sorting. A12/A15/A22. |
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
it is not required to complete G4 and no scientific simulation rerun belongs in this contract.

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

Performance review separates idle analysis, selection overlays, ID traces, large
ROI scans, CSV export and analysis-plus-playback. Record p50/p95/max callbacks,
callbacks at least 50 ms, request/ready/cancel latency, worker CPU, cache charges,
viewer/worker RSS, disk quota and GPU usage where available. Include cold/warm
caches, visibility, mesh transitions and rapid seeks. The original accepted
100k-particle comparison used a no-unexplained-regression-above-10% target;
its measured result is workload-specific. Interval decode/hash/reduction must not
move into UI callbacks, and cache/worker growth must remain bounded across loops.

The historical implementation sequencing and deferred roadmap are retained in
[the accepted baseline](https://github.com/mongstad/Wavez/blob/ca220d30163d4a76efd652933c8c963a564c315d/G4_DESIGN.md).
They are not current work authorization. Regression/performance selection follows
[AGENTS.md](../AGENTS.md) and the live issue scope.
