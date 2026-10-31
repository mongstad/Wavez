# Selections and temporal analysis

Selection/Analysis is experimental beyond its declared validation fixtures.
Use the [scientific integrity boundary](SCIENTIFIC_ANALYSIS.md#21-hardware-independent-scientific-integrity-boundary)
and [current path audit](SCIENTIFIC_INTEGRITY_AUDIT.md) to distinguish stored
samples, derived measurements and visual previews. Passing source transport or
solver benchmarks does not validate every Selection/Analysis operation.

Scientific analysis operates on immutable source values and explicit capture identities. Open a
capture, then choose **Tools → Selection**, then **Use current capture**. The worker pins its
committed bytes and checksum. New appended samples require a deliberate new
binding; they do not silently extend a saved analysis or render job.

## Select a scientific population or location

Expand **Select by ID or region**, choose the selection type, then **Create selection** for exact persistent IDs, sample-local
rows, mesh scopes, grid xyz addresses, probes, or box/sphere/cylinder/finite-slab
regions. Enter IDs as decimal text. The pointer tools offer click, rectangle,
lasso, mesh and slice/derived picks. Their saved visibility/occlusion policy
controls picking. Changing display filters or colors later does not change
scientific membership.

Persistent particle cohorts follow supplied IDs through reordered records and
birth/death samples. Gaps remain gaps. Anonymous rows belong to one sample and
cannot become identity histories. Mesh vertex IDs can survive valid reordering;
faces and barycentric points expire when their contiguous topology epoch ends.
An old topology returning later does not resurrect a face selection. Derived
surface picks belong to the exact generated artifact and have no material identity.

A probe fixes a world or object-local coordinate. A grid address binds the source
grid geometry and centering. Moving a displayed slice does not move its saved
probe. A spatial region reevaluates inclusion at each native sample; **Surface and cohort tools →
Save current members as cohort** creates a distinct fixed cohort or sample-local
set. Multi-select list entries to make a named group. Mixed objects remain
separate analysis series; ambiguous totals refuse.

Hidden selections remain numerically usable. Highlights are a bounded preview;
selected/present/drawn counts differ deliberately. **Show hidden selection** only
changes overlay eligibility. Original source arrays remain unchanged.

## Analyze native samples

For one field at one native sample, **Tools → Spatial spectrum** computes a
source-verified regional spatial spectrum independently of temporal selections.
See [support, normalization, limits and workflow](SPATIAL_SPECTRUM.md). This
derived diagnostic does not alter the scalar viewport or imply optical emission.

In **Temporal analysis**, select the population/group, operation, source channel,
component and inclusive native range. Choose value traces, statistics, population
counts, discrete field integrals, interval velocity, centroids or mesh area.
Recorded velocity and interval-derived velocity have different provenance.
Missing/nonfinite values retain their reasons and counts. Scalars hold for cursor
evaluation; held copies are not counted as extra native observations.

Choose **Run analysis** to start. **Advanced • Scientific options** contains
coordinate, statistic, weight, unit, missing-data and incomplete-subtotal choices.
Expanding a group changes only its presentation; scientific defaults are unchanged.
Hover labels or options for the relevant assumptions. **Advanced • Member lookup**
accepts an exact series member address when the bounded plot list is insufficient.

Weights must be supplied explicitly. Probability-style weights require finite
nonnegative values; signed algebraic sums are separate. Phase, categories and IDs
are not ordinary continuous statistics. Physical mass requires declared actual
particle mass or original-grid mass density with compatible units and scale.
A density sum over sampled tracers is not field mass. Grid integration uses whole
source cells, explicit center inclusion and the absolute affine determinant once;
partial boundary coverage is a stated discrete approximation.

Plots show bounded extrema/gap previews. The full-result table and numerical export
retain every admitted scientific row. Space-time views use the grid or tracer
object's native clock and all requested spatial bins. Orange marks missing support;
pink marks preview cells containing both finite and missing support. Neither color
is a scientific value. The current inline transport admits at most 16,384 preview
pixels and 16,384 full spatial bins, with explicit refusal above those bounds.

## Diagnostics and comparisons

Explicitly choose a CSV, its time/value columns, delimiter, units and missing-data
policy in **Diagnostics and comparisons → Import CSV**. Uncommon parsing/gap
settings are under **Advanced • CSV parsing and gaps**. Choose **Import diagnostic CSV**. Its clock remains separate from capture clocks. Invalid
time axes retain row order and become index-only. Bind selected result series as
left/right with declared quantity/unit correspondence. Choose exact native joins
or an explicit common schedule. Keep the native support on both sides.

Expand **Compare series** to bind inputs and choose **Compare left and right**.
**Common schedule settings** contains the explicit shared schedule. **Estimate a
period** keeps its sampling assumptions in an Advanced group; hold-resampling
never silently substitutes for supplied observations.

Time mapping is `aligned = raw * scale - offset`; value mapping is
`mapped = source * scale + offset`. Manual bookmarks can supply an explicitly
described time origin. Peak-spacing/autocorrelation estimates are exploratory,
window-dependent results. Short, flat, noisy or nonstationary signals can refuse
a candidate. These operations never create automatic physical-event labels.

For matched scenes, save each input as a v3 inspection. In **Matched runs**, select
both recipes, type the source-scoped selection keys, scalar object/channel and
explicit time/value mappings. Explicitly open/select every referenced capture.
Declare a common world origin, axes and units, shared scalar bounds and colormap.
Per-input mappings and video/output limits have separate Advanced groups. Choose
**Prepare matched views…**, then **Render matched views**. Preparation takes the current camera, verifies both inputs on the worker, and
publishes two portable scene jobs plus `comparison.json`. Render them sequentially.
Equal start/end produces a snapshot; clips retain their PNG frames and sidecars.
Each frame records both sources and its own raw/aligned time and native brackets.

Matched scenes do not register or rescale geometry. Known coordinate unit
disagreements refuse. Scene value scales must be positive; negative affine scales
remain available for numerical comparisons. Shared mapped bounds/units are in the
comparison manifest; native per-source legends are suppressed to avoid mislabeling
those mapped quantities. Clips are limited to 4,000 frames per input and a declared
total quota of at most 64 GiB.

## Save, restore and export

**Analysis export and state → Export numerical data…** streams full `values.csv`, support JSONL and provenance
to a new directory with a finite quota. Exact IDs, scientific precision, units,
channels, source checksums/extents, clocks, missing support and derivations survive.
Output never comes from colormap colors or GPU previews. Existing destinations
are preserved; incomplete exports remain labeled partial.

**Save inspection recipe…** and **Load inspection recipe…** handle saved state;
**Locate referenced input…** supplies an explicitly required capture, CSV or artifact.
Export quotas/member lists are under **Advanced • Export limits and members**.

Portable inspection v3 bundles contain exact selection members and optionally
completed result files. Omitting those files leaves hash references that require
the original private results; missing references refuse restore. Captures, CSVs
and derived artifacts remain external and must be explicitly selected. A restored
validated request can be recomputed explicitly. Restore verifies the full input
and asset state before applying it, then pauses playback. Old v1/v2 inspections
and version-1 video jobs retain their behavior. Screenshot destinations remain
session preferences.

G4 PNG/state capture publishes a verified image/state bundle; per-frame video
sidecars can be restored to reproduce the same sample and overlay at matching
renderer, viewport aspect and dimensions. Export pins its source extent and
awaits the exact selection and render barriers. Cancellation cannot publish a
stale overlay frame as a complete job.

The default worker workspace is 512 MiB, with one active interval scan and a
responsive latest cursor request. Analysis pauses during playback underflow and
still observes cancellation and finite deadlines. The default disposable cache
ceiling is 2 GiB; viewer result and overlay limits remain separate. Large requests
can refuse admission instead of reducing the scientific population. Encoding
uses conservative space admission, periodic quota checks and a final publication
check; disk headroom is not a reservation against other applications.

## Reproduce the synthetic walkthrough

```bash
python -m examples.g4_demo --output results/g4-demo
godot --path viewer -- --capture=/absolute/path/to/results/g4-demo/scene.wvz
```

The new output includes `GUIDE.md`, supplied diagnostic CSV, exact selection
definitions and eight complete numerical exports. The independent field-mass oracle
is 288 kg at five native times; the lower-cylinder ROI contains 144 kg. The
tracer-only fixture refuses an original-field mass integral and exports labeled
sample means. The supplied diagnostic period is 2 seconds.
See [the acceptance registry](SCIENTIFIC_ACCEPTANCE.md),
[schemas](ANALYSIS_SCHEMAS.md) and [historical gate](G4_ACCEPTANCE.md).

G5 local control/services/command orchestration and G6 automatic event detection
remain deferred. Web dashboards, external solver work and unrelated visual changes
are outside G4.
