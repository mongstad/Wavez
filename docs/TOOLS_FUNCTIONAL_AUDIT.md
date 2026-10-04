# Current Tools functional audit — issue #224

This is a trace of the **current live Tools menu**, at candidate build 41. It is
an inventory and decision aid, not a change to analysis, rendering, or control
availability. The menu routes are defined in
[`viewer_shell.gd`](../viewer/ui/shell/viewer_shell.gd); the dialog host in
[`viewer_tools.gd`](../viewer/ui/shell/viewer_tools.gd) moves existing controls
between pages. Opening a page does not submit a scientific request. Its shorter
visible labels retain the original label as a tooltip. A layer **target** in
Derive range, Slice, Clipping, or Isosurface only chooses that tool's controls;
it does not select, reveal, or sample the layer.

Classification: **A** retain distinct function; **B** retain with source or
metadata eligibility made clearer; **C** wording, grouping, or explanation
needs work; **D** consolidate a duplicate route later; **E** remove later if no
credible purpose remains; **F** further evidence needed. These are audit
recommendations, not decisions to remove controls. “Scientific” below means a
request or saved membership/value definition; “presentation” changes rendering
or navigation; “resource” changes preparation/cache policy; “session” changes a
local draft or result list. No active feature was established as E. The Results
links repeated on task pages are D **navigation**, sharing one authoritative
Results view, not duplicate computations.

## Route and control inventory

The current menu exposes **Selection**; Analysis → **Temporal, Space time,
Diagnostics, Compare, Matched runs, Period, Bookmarks, Results**; and **Mapping,
Derive range, Slice, Clipping, Isosurface, Source probe, Performance, Geometry**.
The tables name controls by their current short label where one exists. Page
selectors and Close/X/Escape only navigate or dismiss the nonmodal host; they
do not submit a draft. Controls with immediate display/resource callbacks keep
their already applied changes when the host closes. The state and eligibility
columns distinguish a visible widget from a valid operation. An absent source
kind disables the relevant menu entry or leaves no valid target; invalid
request/metadata combinations report a refusal. Missing per-sample channel
support is recorded as unavailable rather than invented or silently filled.

### Selection

Controller: [`selection_controller.gd`](../viewer/selection/selection_controller.gd),
worker: [`selectors.py`](../wavez_export/analysis/selectors.py). A bound,
complete WVZ1 capture snapshot and source object are required. Selections refer
to source samples, never the display color or particle visibility filter.

| Controls | Actual effect and eligibility | State; class and recommendation |
| --- | --- | --- |
| **Use current capture**, **Source layer** | Binds the current committed source and selects the object for new definitions. Existing definitions refuse a changed committed extent. | Scientific source context; A. Keep explicit binding. |
| **Pointer tool** (Orbit, Click, Rectangle, Lasso, Mesh face/point/vertex, Slice probe, Derived face/point, Field probe on surface), **Selection edit** (New, Replace, Add, Subtract, Toggle), **Pick mode** (through layer or opaque surfaces) | Controls viewport picking and how the active definition is edited. Mesh, derived-surface and field modes require their respective prepared/visible targets; Orbit exits picking. Occlusion governs the gesture, not source data. | Scientific membership plus interaction policy; B. Expose only eligible gestures per source/derived-surface state. |
| **Name**, selection list, **Rename selection**, **Duplicate selection**, **Delete selection** | Manage named definitions; list is also the active or multi-selected input for Temporal and groups. | Scientific/session; A. |
| **Toggle highlight**, **Show hidden selection** | Change selection overlay visibility; neither changes membership. | Presentation; A. |
| **Selection type**, **IDs or sample addresses**, **Coordinate space**, **Mesh elements**, **Start or center**, **End or normal**, **Radius**, **Slab width/height/thickness**, **Create** | Define persistent particle IDs, sample-local rows, mesh object/IDs/rows/faces, grid addresses, point probe, or box/sphere/cylinder/slab ROI. Geometry fields depend on shape; world versus object-local coordinates and vertex/face association are part of the definition. Persistent IDs are exact; rows are local to one sample. | Scientific; B. Keep shape-dependent fields conditional and state ID/row lifetime. |
| **Filter channel**, **Value filter**, **Filter component**, **Exact integer range bounds**, **Lower/Upper bound**, **Integer values**, **Copy current particle type exclusions** | Optional source-channel finite/range/integer membership predicate. The copy action captures today's particle type exclusions into the definition; later display filtering does not change it. Requires a compatible source channel and kind. | Scientific; B. Keep the existing conditional filter fields, distinguish copied type exclusions from a live display filter. |
| **Select generated surface**, **Save current members as cohort** | Selects the derived surface object or freezes current membership into a cohort. A derived surface has no persistent physical identity; a frozen cohort is different from a spatial ROI. | Scientific; B. Offer when corresponding surface/selection exists. |
| **Group selected entries**, **Named groups**, **Rename/Delete group**, **Save group union/intersection** | Manage groups and materialize set operations over selected definitions. A group can feed separate Temporal series. | Scientific/session; A. |
| **Cancel** | Cancels an in-flight selection worker query; completed selections remain. | Session; A. |

### Temporal and its Shared request

Controller: [`temporal_controller.gd`](../viewer/analysis/temporal_controller.gd),
worker: [`native_analysis.py`](../wavez_export/analysis/native_analysis.py),
semantics: [`channel_semantics.py`](../wavez_export/analysis/channel_semantics.py)
and [`quadrature.py`](../wavez_export/analysis/quadrature.py). The **Shared
request** page on Temporal and Space time moves the *same* selection/range,
channel, component, coordinate, weight, unit, and gap widgets. It is not a
separate request, independent preset, or automatic synchronization of two
copies. **Run** submits only the active task's supported fields; **Cancel**
requests cancellation and leaves completed named results available.
**Request**, **Scientific options** and **Shared request** are dialog pages:
Request contains mode-specific fields, Scientific options contains interpretation
and support-policy fields, and Shared request contains the original controls
consumed by both analysis controllers. Switching pages changes no result.

| Controls | Actual effect and eligibility | State; class and recommendation |
| --- | --- | --- |
| **Selections to analyze** (active, list entries, group), **Analysis**, **Range axis** (recorded time/sample index), **Start/End**, **Use full layer range** | Chooses 1–16 bound definitions and inclusive native-time or record-index range. Full range fills fields from the first chosen object's recorded extent. | Scientific request draft; A. |
| **Source channel**, **Component** (scalar/x/y/z/w/magnitude), **Position trace coordinates**, **Override channel units** | Trace/statistics/integral use a declared source channel. Coordinates apply to position traces; a unit override records interpretation and leaves bytes/values unchanged. Other modes may ignore these fields. | Scientific request draft; B/C. Explain relevance per mode; do not imply that an override converts values. |
| **Statistics** | Chooses metrics for Channel statistics. Default is `count,min,max,mean,stddev`; the physical mass path requires exactly `sum`. | Scientific request draft; C. Gate or explain the physical-mass `sum` requirement in a later UX issue. |
| **Weighting**, **Weight channel**, **Weight units override** | Unweighted, source-channel weighting, or world mesh-face-area weighting for supported statistics/centroid requests. A weight unit override records meaning; it is not an implicit numeric conversion. | Scientific request draft; B. Show only for supported mode/object combinations. |
| **Physical mass declaration** (No physical mass claim, Actual particle mass, Original-grid mass density), **Declared mass unit**, **Length unit for mass calculation**, **Physical value scale** | A physical mass claim is accepted only for particle `sum` of explicitly declared actual particle mass, or whole-cell grid integral of explicitly declared original-grid mass density. Scale must be positive and finite; mass unit is explicit. Grid density also requires a matching physical length unit and world grid-coordinate unit. The default “No physical mass claim” makes no mass assertion. Tracer density, particle counts, area and other statistics do not become mass through this selector. The UI currently shows these fields even in modes that ignore them or whose backend rejects the claim. | Scientific interpretation; **C**. Retain strict backend rules, condition the UI by mode/selection and make the `sum` prerequisite visible. |
| **Maximum gap** | Sets a maximum allowed native-time gap between connected observations; it cannot synthesize missing samples. Requires a valid native clock. | Scientific support policy; B. |
| **Finite subtotal** | Only Grid integral consumes it: an incomplete/nonfinite whole-cell integral can also report its finite part, explicitly marked **incomplete**. It is not a complete physical mass. | Scientific support policy; C. Show only for Grid integral with explanatory copy. |
| **Run**, **Cancel**, **Results** link | Submit/cancel the current request; Results opens the one shared result viewer. Navigation does not rerun analysis. | Scientific job/session; A, D navigation link. |

Temporal modes have different scientific meanings: **Value trace** returns
selected source observations; **Channel statistics** aggregates selected channel
values; **Population counts** reports selected/present/matched/unknown support;
**Grid integral (whole cells)** includes original-grid cells by center and sums
value × physical world-cell volume (the absolute world transform determinant
is applied once); **Velocity from position intervals** needs persistent IDs and
native time; **Centroid** computes unweighted or eligible weighted position;
**Mesh area** sums world-triangle area. Nonfinite or missing support is explicit;
the worker does not invent values or a complete integral. The mass declaration
adds a physical claim only under the strict combinations above. All are **A**
distinct computations, with **B** eligibility and **C** mass-copy caveats.

### Space time

Controller: [`space_time_controller.gd`](../viewer/analysis/space_time_controller.gd),
worker: [`space_time.py`](../wavez_export/analysis/space_time.py). Uses the
bound Selection source/layer and the Shared request fields described above.

| Controls | Actual effect and eligibility | State; class and recommendation |
| --- | --- | --- |
| **Analysis**: Grid line probes, Grid slab mean/integral, Tracer counts/sample mean/weighted estimate | Grid modes require a volume; slab reductions additionally require an active finite slab ROI on that object in the same coordinate space. Tracer modes require particles. Counts uses no value channel; means and weighted estimates require numeric source channels. | Scientific; A/B. Explain mode-specific required source and fields. |
| **Axis start/end**, **Spatial bins**, **Coordinate units/space** | Define world or object-local line/bin geometry. Full numerical output retains 1–16,384 bins; heatmap is a bounded preview. Units are declared, not inferred conversion. | Scientific; A/B. |
| **Use active tracer selection**, **Sampling population and weights** | Optional tracer restriction; weighted estimate requires a numeric weight channel declared as sampling weight and a nonempty population interpretation. This is not original-grid mass. | Scientific; B/C. Keep declaration beside the eligible mode. |
| **Run**, **Plot**, **Results** link | Submit native-sample computation, request a bounded plot preview, or navigate to the shared result. Source gaps/coverage remain explicit. | Scientific job/session; A, D navigation link. |

Grid line probes sample the source grid along a line; slab mean and integral
use trilinear values at bin midpoints or reduce whole source cells selected by
their centers inside the declared slab. A slab mean is the arithmetic mean of
eligible cell values; a slab integral is their compensated sum × world cell
volume. Any nonfinite selected cell makes that bin unavailable. Integral units
are channel units × coordinate units³. Tracer counts have unit 1; sample mean
retains value units; weighted estimate is the sum of value × sampling weight,
with product units. No mode interpolates in time or turns tracer sampling
weights into physical mass.

### Diagnostics, Compare, Period and Bookmarks

Controller: [`diagnostics_controller.gd`](../viewer/analysis/diagnostics_controller.gd);
workers: [`diagnostics.py`](../wavez_export/analysis/diagnostics.py),
[`comparisons.py`](../wavez_export/analysis/comparisons.py),
[`periods.py`](../wavez_export/analysis/periods.py). The **Name** input is one
widget moved between these tasks. Results/series selectors are shared with
Results; there is no separate hidden comparison result store.

| Route / controls | Actual effect and eligibility | State; class and recommendation |
| --- | --- | --- |
| Diagnostics: **Name**, **CSV file/Choose CSV**, **Time column/units**, **Value columns/units**, **Number type** (Float64/exact int64), **Delimiter**, **Skip blank lines**, **Maximum CSV gap**, **Missing time intervals**, **Import** | Imports a named external diagnostic series on its own recorded clock. Parsing, exact integer type, gap and missing-interval declarations are explicit; import does not align it to the capture clock. | Scientific supplied data; A/B. Keep clock independence prominent. |
| Compare: **Selected result/Plot series**, **Common time unit/reference**, **Time scale**, **Time offset**, **Reason for time offset**, **Common value unit**, **Compared quantity**, **Source value scale/offset**, **Use current series as left/right**, **Clear left and right** | Binds two scalar series with explicit common meaning. Aligned time = raw time × scale − offset; mapped value = source value × scale + offset. Requires a stated reference and quantity, not matching IDs or inferred event alignment. | Scientific mapping draft; A/B. No automatic geometric registration or identity matching. |
| Compare: **Comparison** (left−right/left÷right), **Comparison times** (exact/common schedule), **Schedule start/step/samples**, **Compare** | Produces a named difference/ratio. Exact times leave unmatched support missing; a declared schedule evaluates only supported holds/position interpolation with native provenance. | Scientific result; A/B. Gate schedule fields to schedule mode. |
| Compare: **Add current series to shared plot**, **Clear shared plot**, overlay | Displays up to 16 bound series on mapped axes, retaining each native clock/support. Clear affects plot bindings, not stored results. | Presentation/session; A. |
| Period: **Selected result/Plot series**, **Start/End** through Temporal, **Period estimate method** (peak spacing/autocorrelation), **Detrend** (mean/linear), **Minimum/Maximum lag**, **Minimum peak separation/prominence**, **Use uniform sampling assumption**, **Hold-resampling step**, **Estimate**, **Edit range** | Exploratory estimate over a selected scalar series and Temporal range. Autocorrelation needs supported uniform sampling or explicit hold resampling; resampling does not create observations. Prominence is normalized-signal, not source-unit, magnitude. Edit range navigates to the Temporal request. | Scientific result plus navigation; A/B. Do not imply physical event detection. |
| Bookmarks: **Name**, **Manual bookmarks**, **Save time and camera bookmark**, **Go to bookmark**, **Use bookmark as manual offset**, **Delete bookmark**, **Time mapping** | Saves exact source/time and a visual snapshot; Go validates the same source, pauses and seeks **time only**. The stored camera snapshot is not applied by Go. Offset copies saved time and origin into Compare; Time mapping opens Compare. | Session/recipe provenance; **C**. Current “time and camera” wording implies a camera restore that does not occur. Rename as a time bookmark or specify a separate camera restore in a future UX issue. |

### Results and Matched runs

Results code: [`temporal_controller.gd`](../viewer/analysis/temporal_controller.gd),
[`durable_controller.gd`](../viewer/analysis/durable_controller.gd).
Matched code: [`matched_controller.gd`](../viewer/analysis/matched_controller.gd)
and [`matched_render.py`](../wavez_export/analysis/matched_render.py).

| Route / controls | Actual effect and eligibility | State; class and recommendation |
| --- | --- | --- |
| Results: **Selected result**, **Remove result**, **Plot series**, **Member address**, **Show plot**, plot/table, **First/Next data page** | One authoritative list of completed named results. Select a result/series, inspect an exact member beyond the first listed series, request plot/table pages, or forget a result. It does not recalculate source values. | Scientific result storage plus presentation; A. |
| Results: **Recompute** | Replays the selected saved request through the current source-bound validation path; source/references must resolve. | Scientific job; B. Keep provenance and missing-input errors visible. |
| Matched runs: **Left/Right recipe**, **selection keys**, **layer ID**, **scalar channel**, per-side **time/value scale/offset**, **time-offset reason** | Explicitly binds two v3 inspection recipes and per-source scalar/time mappings. Identical IDs across captures are not matched automatically. Mappings affect aligned interpretation and color bounds; source values are unchanged. | Scientific mapping plus export draft; B/C. “Matched” means user-declared correspondence, not automatic registration. |
| Matched runs: **Common time units/reference**, **scalar units/quantity**, **world coordinate units/origin and axes**, **shared range min/max**, **colormap** | Declares common meaning and view. Geometry is not registered or rescaled; compatible sources and declarations are required. Current camera is frozen at preparation. | Scientific declarations/presentation; B. |
| Matched runs: **Aligned start/end**, **FPS**, **aligned time per video second**, **width/height**, **output limit**, **folder**, **Prepare/Render/Cancel** | Validates and freezes two source-bound jobs, then renders two videos sequentially. End equal to start is a snapshot. Cancel is cooperative; already completed output is retained. | Export job/resource; A/B. Full pair rendering remains a GPU/platform owner check. |

### Display, sampling and resource tools

These routes share the dialog host but keep the authoritative controls in
[`main.gd`](../viewer/main.gd),
[`scene_layers.gd`](../viewer/layers/scene_layers.gd),
[`particle_playback.gd`](../viewer/layers/particle_playback.gd) and
[`field_playback.gd`](../viewer/layers/field_playback.gd).

| Route / controls | Actual effect and eligibility | State; class and recommendation |
| --- | --- | --- |
| Mapping: **Logarithmic**, **Cyclic phase**, **Clamp** | Particle color normalization/render policy. Log requires positive finite values and is disabled for signed/cyclic/symmetric meanings; cyclic and log are mutually exclusive. Clamp controls out-of-range colors. No source values change. | Presentation; A/B, particles only. |
| Derive range: **target**, particle **Start/End**, **Freeze**, **Cancel** | Scans recorded particle interval for finite color range and freezes a display normalization. Cancel stops the scan. | Presentation computation; A/B, particles only. |
| Derive range: field **symmetric sample**, **Lower/Upper percentile**, **Freeze symmetric/percentile**, **Reset color**, **Reset opacity** | Computes a display color range from the selected volume sample or resets its color/opacity mapping. Percentiles are display choices, not scientific summaries. | Presentation; A/B, volume only. |
| Slice: **target**, particle **Enabled/Position**; field **slice plane** (none/XY/XZ/YZ/oblique), **normal X/Y/Z**, **Distance** | Particle shader X cut uses a position as box fraction of ±3 simulation units; field shader plane uses world distance. Both alter visibility only, not source membership or numerical analysis. | Presentation; A/B. Keep the two coordinate meanings distinct. |
| Clipping: **target**, **Enabled**, **X** | Clips a volume at a world-X plane. Does not cut particles/meshes or modify source samples. | Presentation; A/B, volume only. Different from Slice orientation and from Selection ROI. |
| Isosurface: **target**, **Threshold**, **Extract**, **Remove** | Extracts a bounded/cancellable approximate level surface from the selected volume's source grid/channel, with cache. Requires available sampled source; resulting geometry has no stable material identity. Remove discards that derived surface. | Derived presentation/selection target; B. No mass/topology claim. |
| Source probe: **volume/channel**, **World coordinates**, **Probe** | Samples a prepared volume/channel at a world point by trilinear source-grid interpolation and reports sample/capture stamp. It does not prepare a hidden field or switch the display channel. A stale context is reported; View → Probe marker is a separate display toggle. | Scientific observation/session; A/B. Explain prepared-source eligibility and interpolation. |
| Performance: **decoded cache budget/clear**, particle **Automatic (safe RAM)/manual RAM policy** and readouts, field **Automatic/Selected interval/From current position**, **interval Start/End**, **Window duration**, field/mesh readouts, **GPU budget** | Adjusts preparation/retention, not source values or image quality. Advanced field intervals restrict playback; automatic seeks can reuse cached samples. CPU decoded, prepared resident, and GPU budgets are distinct accounting domains, not total process RAM. | Resource/performance; A/B. Show controls only for present source kinds and label each budget scope. |
| Geometry: declaration readout, **Load override**, **Clear override** | Displays validated source geometry metadata or explicit user JSON override and draws guide geometry. Override changes guides/visual state, not source geometry or analysis. View menu controls guide visibility. | Presentation declaration; A/B. Keep override provenance explicit. |

## Cross-route boundaries and recommendations

- File → State **Save analysis/Load analysis** and File → Export **Data/Image**
  are adjacent routes hosted by the same dialog implementation, not Tools menu
  entries. The state form supplies folder, quota, CPU/elapsed limits,
  include-members and include-results options. Results **Recompute** uses the
  same controller. An export quota refuses an incomplete output rather than
  silently dropping scientific rows.
- Shared request and Results links are intentional single-owner navigation.
  Preserve their one-widget/one-result identity. A future UX pass may simplify
  labels, but should not create independent copies or hidden recomputation.
- Highest-value conditional cleanup: gate Temporal mass/finite-subtotal options
  by actual backend eligibility; guide source-kind fields in Selection and
  Space time; expose prepared-source requirements for probe/isosurface and
  advanced field intervals. Highest-value wording fix: bookmark camera claim.
- Mapping, Slice, Clipping, Selection ROI and Isosurface all affect what users
  see or inspect, but have distinct render, membership and derived-geometry
  semantics. The audit found no safe equivalence to justify combining them.
- No runtime controls, formulas, payload rules, shortcuts, menu routes or
  persistence formats are changed by this audit. Any proposed UX adjustment
  needs its own issue and scientific regression boundary.

### Reachability, coverage and equivalent paths

All 17 named routes are registered in the live menu and opened by the focused
native Tools harness. Menu enablement requires a loaded capture for the tools;
Mapping additionally requires particles; Clipping, Isosurface and Source probe
require a field; Slice and Derive range require particles or a field. Within an
enabled route, the worker and control conditions above still apply. “No exact
replacement” means there is no other route with the same state/result contract,
although the Simulation panel may expose complementary display controls.

| Route | Focused coverage and code trace | Equivalent/related path |
| --- | --- | --- |
| Selection | Native Selections 31; Python selection tests | Viewport gesture is this controller's input, not another selection model. |
| Temporal | Native Temporal 23; Python native-analysis, semantics and quadrature tests | Results is its common output; no equivalent computation. |
| Space time | Native Space time 36; Python space-time tests | Shares Temporal request widgets, but has different spatial reductions. |
| Diagnostics | Native Diagnostics 23; Python diagnostic tests | External CSV input has no other import route. |
| Compare | Native Diagnostics 23; Python comparison tests | Bookmarks can fill an offset, not compare data. |
| Matched runs | Native Tools route; Python matched-render tests | Video export renderer is reused, but no other two-recipe preparation route. Full pair render untested here. |
| Period | Native Diagnostics 23; Python period tests | Temporal range is reused, not another period estimator. |
| Bookmarks | Native Diagnostics 23; Python diagnostic tests | Compare consumes the offset; no other bookmark navigation. |
| Results | Native Tools route; Python result/analysis tests | Task-page Results buttons are D navigation to this one view. |
| Mapping | Native Tools particle controls | Simulation Color Mapping supplies channel/range/colormap; these log/cyclic/clamp flags are additional controls, not equivalent. |
| Derive range | Native Tools particle/field targets | Simulation manual/automatic ranges are related, but not the same frozen interval or sample percentile action. |
| Slice | Native Tools particle/field targets | Clipping and Selection ROI have different coordinate and state semantics. |
| Clipping | Native Tools field target | Slice is a different plane control, not an equivalent world-X clip. |
| Isosurface | Native Tools field target | Derived surface picking consumes its output; no other extraction route. |
| Source probe | Native Tools field probe | Selection's field probe on surface creates a source selection; this route samples numeric prepared grid data at entered world coordinates. |
| Performance | Native Tools cache/preparation controls | Simulation status readouts describe preparation, not an alternate budget control. |
| Geometry | Native Tools override/readout | View guide toggles only control visibility; no other metadata override. |

No current route or control met **E** after tracing its live signal and valid
source path. No **F** classification was needed to describe present code
behavior. Whether a particular external capture's declarations justify a
physical interpretation still needs that source's metadata and the owner's
domain judgment; this audit makes no such claim.

## Evidence and limits

The route trace was cross-checked against live menu construction, dialog
composition, controller arguments and worker validation, rather than historic
UX screenshots. Focused native Tools validation passed **1,904 assertions**
with synthetic particle, field, mesh and mixed WVZ1 fixtures under Godot 4.7.2
Compatibility. Temporal, Space time, Selections and Diagnostics native harnesses
passed **23, 36, 31 and 23 checks** respectively. Focused Python analysis,
selection, diagnostic, channel-semantic, quadrature, period and matched-render
tests passed **76 tests** (44 + 32). The first parallel Selections/Diagnostics
harness invocation failed while using a shared worker-cache directory;
independent serial reruns both passed. Concurrent cache interference is a
plausible cause, not a confirmed diagnosis. An initial Python test command
named a nonexistent module; the corrected module command passed. Neither
invocation established a product failure.

Fixtures establish code paths and semantics, not the physical meaning of an
owner's external capture, its channel metadata, or its coordinate declarations.
This audit did not render a full two-video matched pair, exercise a packaged
binary, or validate hardware-specific GPU behavior. Before acceptance, the owner
can open a real particle, volume and mixed scene; visit every Tools route; verify
source-kind gating, Shared request identity, and that Display tools leave
numerical results unchanged; then check a declared mass case, incomplete grid
integral, diagnostic/compare series and a bookmark whose camera changes before
**Go to bookmark**. The last check should reproduce the documented wording
mismatch: time returns and camera does not.
