# Spectral research: architecture and implementation boundaries

Research proposal for issue #135; no runtime behavior described as proposed here
is implemented or owner-accepted. Source inspection baseline:
`681a46f8f8473ee6b5323ec4af71ada883183077` (accepted v0.1.0.113).
The data audit and bounded experiments accompanying this report determine which
actual Model A channels and captures satisfy the proposed input requirements.

## Recommended first increment

Implement, in a separately authorized issue, **one explicit spatial spectrum of a
finite, grid-aligned 3D region at one pinned native field sample**. Compute it in
the existing Python analysis worker from verified source arrays. Show the result
in a numerical plot beside the unchanged conventional field view, with the
region located in that view. Begin with one windowed real 3D FFT, radial
band-power aggregation and directional diagnostics; keep the DC/mean term
separate. Define normalization and conjugate-half weighting before implementation.
This is a local region measurement, not a voxel's unique wavelength, an optical
emission spectrum, a wave-propagation measurement, or a full 3D spectral map.
Choose its physical support from the requested wavelengths before selecting an
FFT size. For this Model A reference, an exploratory region around 128³ samples
is more appropriate than a generic 32³ or 64³ default, with substantial resolution
limits remaining as described below. Its cost must be measured at that support.

The first implementation should be explicit and paused/pinned, rather than
automatically recomputing on every playhead update. A cached plot may remain
visible during navigation only with its original region and source-time label.
Do not let it masquerade as a result for the newly displayed sample. Whole-volume
spectra are useful diagnostics but cannot substitute for localization.

If signed scalar samples, finite grid geometry and native timestamps are present,
**no WVZ1 format extension is needed** for this increment. Unknown physical units
permit a clearly labeled spectrum in simulation-coordinate or grid-index units;
they do not permit nanometre labels. A magnitude or energy channel can have its
own mathematically valid spectrum, labeled with that exact quantity, but cannot
be substituted for missing signed-field phase or wavelengths. A missing source
quantity may require a separately approved simulation exporter change; it does
not by itself establish a need to change the WVZ1 wire format.

The accompanying data audit identifies the finalized 192³ reference as suitable
for this starting point: its `amplitude` channel stores signed float64 field
samples alongside `energy_density` and `gradient_magnitude`, at spacing 1/6 and
native times 0–40 in steps of 1. The newer finalized 320³ capture stores only
`energy_density`; its finer sampling and longer duration do not recover the
missing signed field. Its `Downloads` copy is a committed prefix, not the
finalized full reference. These are different data contracts, not interchangeable
performance fixtures. See the accompanying audit for exact paths, provenance and
verification coverage.

## Current ownership and extension points

All references below identify inspected source, not newly implemented behavior.

| Responsibility | Current owning source and functions | Consequence for a spectral increment |
| --- | --- | --- |
| Scientific/presentation distinction | [Scientific contract §2.1](../../SCIENTIFIC_ANALYSIS.md#21-hardware-independent-scientific-integrity-boundary) | Preserve stored samples, derived measurements and presentation as separate authorities. |
| Scientific/Cinematic presets | [main.gd](../../../viewer/main.gd), `_set_clean`, `_apply_preset`; [view_preferences.gd](../../../viewer/scene/view_preferences.gd), `defaults` | Presets set particle/background/fog behavior and independently recalled Bloom preferences. They do not select separate scientific field-analysis pipelines. Spectral analysis must not reinterpret either preset. |
| Shared field rendering | [grid_view.gd](../../../viewer/layers/grid_view.gd), `setup`, `load_sample`, `apply`; [volume.gdshader](../../../viewer/layers/volume.gdshader), `fragment`; [slice.gdshader](../../../viewer/layers/slice.gdshader), `slice_value`, `fragment` | Both presets use the same scalar-texture/LUT volume and slice path. Opacity, colormap, clipping, Bloom and ray integration are presentation, not spectral measurements. |
| Native field preparation | [field_prepare.gd](../../../viewer/layers/field_prepare.gd), `charge`, `prepare`; [grid_view.gd](../../../viewer/layers/grid_view.gd), `upload` | All decoded source channels are retained for existing probes; the selected preview becomes RF float32 and may be subsampled to fit its texture budget. Image planes are prepared on CPU; GPU texture creation stays on the main thread. Never FFT the preview texture as source evidence. |
| Interactive reader | [scene_reader.gd](../../../viewer/layers/scene_reader.gd), `_init`, `read_sample`; [main.gd](../../../viewer/main.gd), `_open_scene` | Interactive opening passes `offline_instance` as the payload-verification flag. Ordinary display does not perform the payload SHA checks required for the proposed scientific result. |
| Verified scientific source | [source.py](../../../wavez_export/analysis/source.py), `SourceSnapshot.__init__`, `verify`, `identity`, `read_sample` | Pin committed extent and prefix SHA; select the named source channel; validate stored and decoded payload hashes. Selected-channel reads still fully decode that channel before an ROI is cropped. |
| Worker ownership | [analysis_jobs.gd](../../../viewer/analysis/analysis_jobs.gd), `start`, `request_background`, `_poll`, `cancel_background`, `shutdown`; [analyze_selection.py](../../../tools/analyze_selection.py), `Worker.perform`, `service_foreground` | Reuse one owned process, private bounded file messages, revisions, cancellation and playback-pressure handling. Add a validated background operation in a future implementation; it does not exist today. |
| Request and budget contract | [jobs.py](../../../wavez_export/analysis/jobs.py), `validate_request`, `execute`; [contracts.py](../../../wavez_export/analysis/contracts.py), `Context`, `SharedBudget` | New request fields/operations require explicit validation and documented private analysis-contract updates. A private analysis operation is not a WVZ1 wire extension. |
| Scientific results | [result_store.py](../../../wavez_export/analysis/result_store.py), `ResultCache`, `ResultWriter`; [ANALYSIS_SCHEMAS.md](../../ANALYSIS_SCHEMAS.md) | Reuse transactional, hash-bound, quota-limited result ownership where its fixed columns can represent spectral bins/support. Do not assume the current fixed row schema or artifact allowlist already accepts dense spectral arrays. |
| Field cache and preparation | [field_playback.gd](../../../viewer/layers/field_playback.gd), `_job`, `readiness_scope`, `readiness_signature`, `_stage`; [field_buffer.gd](../../../viewer/layers/field_buffer.gd), `_admit`, `_collect` | Existing keys include source generation/stamp, channel, visibility and preview budget. They are presentation/cache identities, not durable scientific identities. Spectral allocations must not enter this cache as if they were ordinary prepared fields. |
| Playback and readiness | [scene_layers.gd](../../../viewer/layers/scene_layers.gd), `_sample_profiled`, `tick`; [prepared_timeline.gd](../../../viewer/ui/shell/prepared_timeline.gd), `refresh`, `spans` | The scene commits only after its required existing preparations are ready. The timeline publishes their resident intersection. An optional spectral job must neither gate conventional playback nor color its prepared band. |

The current viewer permits one active translucent volume; a proposal for two
overlaid translucent scalar/spectral volumes would cross that architecture
boundary. An adjacent plot, or later an explicitly selected derived slice, is a
smaller first visualization. No changes to ordinary image/video export, view
presets or saved inspection recipes follow automatically from this research.

## Data and computation contract

Resolve the displayed union-clock cursor to the selected object's **held native
field record**. Record both requested cursor time and actual native time; do not
interpolate successive field spectra merely because the global playhead moves
smoothly. Freeze source extent, object, channel, sequence/index and geometry.

The initial region uses integer sample bounds in source `[z,y,x]` order with
explicit inclusive/exclusive conventions and node/cell centering. This avoids an
extra resampling operation. Record the taper, shape, removed mean, finite-sample
count, FFT convention, precision, power normalization, bin edges and complete
window support. Nonfinite samples or missing support produce an explicit refusal
in the first increment; silently replacing them with zero changes the spectrum.
Do not silently pad a truncated edge region, duplicate a periodic endpoint, wrap
across a boundary, or infer periodicity from the algorithm alone.

The reference's initial noise has an angular-wavenumber cutoff `k ≤ 0.9`, with
characteristic content around `k ≈ 0.5`. At spacing `h = 1/6`, choose support using
`L = N h` and nominal angular-frequency bin separation `Δk = 2π/L`:

| Window | FFT length L in simulation-coordinate units | Nominal Δk | Interpretation for the initial low-k content |
| --- | ---: | ---: | --- |
| 32³ | 5.333 | 1.178 | First nonzero axial bin is above the cutoff; low-k wavelength content is unresolved. |
| 64³ | 10.667 | 0.589 | Marginal: less than one cycle of k≈0.5 fits along an axis. |
| 96³ | 16 | 0.393 | More support, but only about 1.27 cycles of k≈0.5 along an axis. |
| 128³ | 21.333 | 0.295 | Suggested exploratory starting support; still only about 1.70 cycles of k≈0.5 along an axis. |

These are nominal discrete bins, not a claim of spectral resolving power: a
taper broadens features, arbitrary directions project differently onto each
axis, and a few cycles give weak separation of nearby modes. `L = Nh` is the FFT
period convention; the span between the first and last sample centers is
`(N−1)h`. The source's fine-grid Nyquist bound does not remove the separate
finite-window low-k resolution limit. A displayed peak on a 32³ crop would not
establish a resolved initial Model A wavelength merely because the calculation
returns a number. Keep the full 192³ diagnostic for comparison; its greater
spectral support sacrifices localization and still does not prove a unique
local mode. Later-time higher-k content needs its own measured support check.

If a 128³ job is too slow, prefer fewer region centers, cached pinned results or
explicit asynchronous computation. A 16³/32³ window may be useful for a declared
higher-k band, or must retain an **unresolved low-k** state; it is not an equivalent
lower-cost estimate of the same initial wavelengths. The planned 32/64/96/128
comparisons should expose this tradeoff rather than select a window on speed
alone.

Use declared data-local spacing and coordinate units. A rectangular array's
dimensions do not imply isotropic spacing. If the sample-to-world linear map is
`A`, index-frequency vector `q` maps to world angular wavenumber as
`k = 2π A⁻ᵀ q`; the inverse transpose matters for anisotropic or sheared grids.
The smallest increment can report data-local axes and decline world radial
aggregation for unsupported transforms. Unknown length units remain unknown;
field amplitude units and the squared units of power remain separately labeled.

Power alone loses phase; a radial sum additionally loses direction. Retain the
method's directional diagnostic and explain that phase-preserving filtering or
reconstruction would need complex coefficients plus their origin/window and
normalization. Do not persist a huge complex cube merely to draw the first small
plot. Reconstruction is a separate claim with its own window-overlap and error
tests, not an implication of a successful spectrum.

## Caching and invalidation proposal

The first increment can use a small, byte-bounded in-process numerical-result
cache. Durable output, if authorized, belongs in the existing owned analysis
result storage, separately from raw captures, project history and playback
preparation. Cache deletion must never delete a source capture or scientific
export. Partial/cancelled results are not complete results.

Hash a canonical request containing:

- Source format, committed extent and verified prefix SHA; UUID is supplemental,
  not a sufficient identity. Include object/channel, dtype, record sequence/index
  and exact native-time token.
- Full shape, spacing, origin, centering, data-to-world transform and coordinate
  unit declaration; exact region bounds and axis convention.
- Algorithm/version, implementation provenance, numeric precision, window and
  detrend/mean policy, boundary handling, FFT normalization, radial/directional
  bins, and finite/missing-data policy.

Color map, camera pose, panel layout, Bloom and display exposure belong in a
separate presentation key. They should not trigger recomputation of numerical
power. A later observer response or exploratory color mapping is another derived
stage with its own response-curve/mapping hash; it cannot overwrite the measured
spatial spectrum.

Invalidate or explicitly rebind on source replacement/truncation/mutation,
geometry/channel/sample changes, region edits, or any algorithm parameter
change. For appends, a pinned old result remains scientifically tied to its old
verified prefix, but the initial implementation should conservatively miss the
cache when a new extent is requested. Cross-extent reuse requires proof of the
unchanged prefix, not a matching pathname/UUID. Drop stale replies using scene,
selection, analysis and request revisions before publication. Close File and
source switching cancel ownership; preserve any explicitly exported result.

## Computation placement and resource budget

| Placement | Benefit | Cost and recommendation |
| --- | --- | --- |
| Simulation/export-time preprocessing | Can access unexported signed values and known boundary/units metadata; amortizes playback cost. | Couples an analysis choice to the producer and stores potentially large outputs. Do not make this a prerequisite when current signed samples suffice; any producer modification needs its own issue. |
| Offline Wavez-side preprocessing | Reproducible source-bound maps, bounded batches, no runtime FFT deadline. | Additional disk/cache lifecycle and cold I/O; useful later for selected times/regions. Store derived products separately rather than rewriting a capture. |
| On-demand worker CPU | Reuses verified source access, float64 arithmetic, cancellation, quotas and small plots. | Cold prefix hashing and whole-channel decompression can dominate a tiny ROI. Recommended first path. Avoid whole-capture work at load time. |
| Live GPU FFT/filter bank | Potential throughput for a future dense map. | New compute/render ownership, scratch buffers, numerical comparison, readback and VRAM competition; existing RF preview is not a valid substitute for source input. Defer until CPU semantics and a measured workload justify it. |

The following are **analytic payload estimates, not observed process peaks or
timing measurements**. `N` is the region edge length; a real64 cube costs `8N³`
bytes and its complex128 `rfftn` output costs `16N²(floor(N/2)+1)` bytes.

| Cubic region | One real64 array | One half-complex output | Proposed provisional FFT-workspace reservation |
| --- | ---: | ---: | ---: |
| 32³ | 0.25 MiB | 0.266 MiB | 2 MiB |
| 64³ | 2 MiB | 2.063 MiB | 16 MiB |
| 128³ | 16 MiB | 16.25 MiB | 128 MiB |

Reservations allow several real buffers, power output and FFT scratch, but are
engineering starting points only. Measure the chosen library/build, account for
all retained arrays, and reject a job when its conservative estimate does not
fit. Library-internal memory and allocator retention require RSS/peak monitoring
in addition to logical leases. Do not present these reservations as enforced
limits in today's code.

The existing source reader charges approximately `3 × selected decoded bytes +
9 MiB` for a volume channel before algorithm workspace, metadata and memo charges.
Its full-channel read remains the dominant lower bound even for a small ROI:

| One source channel | Source float32 bytes | Read reservation formula (float32) | Read reservation formula (float64) | Current record admission |
| --- | ---: | ---: | ---: | --- |
| 128³ | 8 MiB | 33 MiB | 57 MiB | One channel fits. |
| 192³ | 27 MiB | 90 MiB | 171 MiB | One channel fits; three float64 channels total 162 MiB. |
| 256³ | 64 MiB | 201 MiB | 393 MiB | One channel fits; all channels must also satisfy the record ceiling. |
| 320³ | 125 MiB | 384 MiB | 759 MiB | One float64 channel is 250 MiB and fits; three would be 750 MiB and fail. |
| 512³, hypothetical | 512 MiB | 1,545 MiB | 3,081 MiB | Rejected before analysis; one float32 or float64 channel exceeds the record ceiling. |

The worker defaults to a shared 512 MiB logical budget and validates at most
1 GiB, but worker allocation is not the first admission gate.
[`scene.py`](../../../wavez_export/scene.py), `MAX_SAMPLE`, descriptor validation,
`SceneCapture` writing and `SceneReader` indexing enforce a **256 MiB decoded
ceiling for an entire record**, summed across its arrays. The hypothetical 512³
row illustrates scaling only and is not a supported input at those dtypes; raising
worker memory or adding ROI reads cannot make that record valid. The actual
320³ energy-only record fits just below this ceiling, whereas adding amplitude
and gradient as two more float64 channels to that same record would not.

For valid records that exceed a worker budget, cropping after decode is not a
solution. A separately scoped verified chunk/ROI reader might reduce selected
read allocation without changing the format, but this inspection does not
certify one. Other choices require an explicit source/export design and scientific
sampling review; do not silently downsample or reinterpret an oversized capture.

For the actual float64 192³ reference, the 171 MiB selected-channel reservation
plus a provisional 128 MiB reservation for a 128³ FFT workspace totals **299 MiB**.
That could fit within 512 MiB, subject to measured FFT allocations, actual retained
metadata, verification memo and coexisting analysis leases; it is not a measured
peak or an admission guarantee. The float64 320³
energy channel requires a 759 MiB read reservation before these other charges and
therefore cannot use the default 512 MiB path. Raising the budget is not an
implicit part of the first increment and would not make that channel a signed
field.

Cold source verification is a separate, potentially much larger cost:
`SourceSnapshot.__init__` computes a SHA-256 over the entire pinned committed
prefix unless a valid verification memo entry exists. That can scan approximately
7 GB for the signed 192³ reference or 98 GiB for the finalized 320³ energy-only
capture before a single ROI is calculated. The memo key binds path, source stamp
and extent; source changes require the existing revalidation rules. A warm FFT
benchmark excludes this I/O and cannot establish end-to-end interactive latency.
Keep explicit cancellable verification progress, reuse only genuinely verified
memo entries, and do not weaken integrity checks to meet the warm-response target.

The first source-appropriate ROI should allocate **no 3D spectral GPU texture**: only a bounded
plot and region indicator. Its incremental VRAM demand should be small compared
with the scalar scene, but this has not been measured or certified on an 8 GB
GPU. For a later coarse map, four float32 quantities at 64³ centers cost 4 MiB per
time sample (8 MiB for two samples), before staging, masks and renderer overhead.
Four quantities at every 256³ voxel cost 256 MiB per time sample. Those numbers
exclude the ordinary volume, depth targets, meshes, particles, Bloom, desktop and
driver allocations; an 8 GB device is not an 8 GB spectral allocation budget.
The current `SceneLayers.gpu_budget_mib = 256` is a default layer-preview budget,
not a guarantee of total VRAM headroom. At full resolution, one 192³ RF preview is
27 MiB and one 320³ RF preview is 125 MiB; conversion has already reduced the
float64 source's precision. `SceneLayers` divides its budget by active views,
including requested isosurfaces; `field_budget` halves that share when field
playback is enabled so the current and staged textures share the same quota.
`FieldPrepare` doubles its LOD factor until the
selected preview fits, sampling source indices rather than creating an
antialiased scientific reduction. A texture that fits memory therefore does not
certify spectral fidelity, even before display sampling and ray integration.

Dense localization also multiplies computation. Valid 32³ windows on a 128³
source at stride 8 give `13³ = 2,197` transforms per time sample. At stride 16,
`7³ = 343` transforms give a smaller fallback. A 2D slice of window centers gives
`13² = 169` transforms at stride 8; each measurement can still use 3D support.
These are workload examples for a band that those windows can resolve, not a
recommended low-k Model A map. Using 128³ support on the actual 192³ source gives
`5³ = 125` valid centers at stride 16, or `5² = 25` centers on one plane. Reducing
to stride 32 gives `3³ = 27` centers while preserving each region's spectral
support; it lowers spatial sampling density instead of shortening the window.
Stream windows/bands; do not materialize one transform per voxel simultaneously.
The exact sample-center coordinates and uncovered edge mask are part of the
derived geometry. A smoothly interpolated color between centers is presentation,
not an additional measured window.

No interactive FPS, GPU speedup, capture-loading latency or dense-map throughput
was measured by this architecture inspection. Future acceptance must separately
record cold source verification/decode, warm FFT, reduction, cache-hit, IPC/plot
publication, total wall time, logical peak, worker RSS and GPU staging. The first
implementation should benchmark the source-appropriate approximately 128³ support
before setting a numerical refresh deadline; a fast 64³ result does not establish
the required scientific resolution. Show visible cancellable progress for cold
work and any longer warm computation, with cancellation acknowledgment within the
existing 2-second grace period as a target to test, not a reported result. Native
FFT calls need bounded sizes because cancellation checks cannot interrupt an
arbitrary library call. Prefer fewer centers or asynchronous pinned analysis as
fallbacks; neither removes full-source decoding costs. Smaller windows change
the scientific support and require the unresolved/higher-k qualification above.

## Minimal interaction proposal

Use an explicitly selected **Spatial spectrum** analysis action. Show one source
object/channel, native sample time, integer region/physical extent, window size
and its nominal Δk/support limitations,
one method, and Compute/Cancel. Keep the scalar viewport and its current
Scientific/Cinematic settings independent. The result plot labels wavenumber
(cycles/unit or radians/unit, never ambiguously mixed), wavelength away from
zero, power normalization, units, window support and the separate mean. A radial
plot must disclose its direction reduction. Include a concise permanent
“Derived spatial spectrum; not an optical emission spectrum” label when relevant.
Do not add unsolicited tooltips.

Report unsupported source quantity, unknown units, nonuniform/invalid geometry,
insufficient support, nonfinite samples, missing Python/NumPy, checksum/source
changes and exhausted RAM as distinct states. Unknown units do not necessarily
block index-space analysis; checksum failure or missing source values does.
Display pending, cancelled and pinned-to-earlier-sample states explicitly. No
automatic data download, dependency installation, capture rewrite, or inferred
calibration follows from activating the action.

Later, offer one selected band-power slice/map with a numerical legend and an
independent scalar-reference toggle. Preserve numerical band power separately
from normalization and exploratory colors. Human Vision is a later response
stage: calibrated optical spectra and declared exploratory spatial-to-visible
mappings must remain distinct, with response integration separate from display
color conversion, gamut clipping and tone mapping.

## Proposed sequence for owner review

These are proposed scopes, **not created GitHub issues or authorized runtime
work**. Each should retain one branch/PR and a separate acceptance decision.

| Phase | Dependency and scope | Proposed acceptance boundary |
| --- | --- | --- |
| 1. Source-bound ROI spectrum | Owner accepts data audit, input quantity and method. Choose physical support for requested wavelengths, then add one validated CPU operation and numerical region plot; retain scalar view. | Synthetic sinusoid/mixed/oblique/phase/window-edge oracles; support-size convergence and unresolved-low-k cases; declared power/Parseval convention; anisotropic geometry/units; source-hash and native-time binding; record/worker-budget refusals, cancellation and stale replies; measured cold/warm costs. No full 3D spectral map or optical claims. |
| 2. Bounded local spatial map | Phase 1 accepted and the owner chooses center stride/window/band semantics. Start at one pinned time with a 2D plane of 3D windows; optionally a coarse 3D map. | Compare each mapped center against the Phase-1 oracle; expose incomplete edges; preserve scalar reference; bound RAM/VRAM and report interpolation as display-only; no silent radial-direction equivalence. |
| 3. Selected-time preprocessing and replay | A map has demonstrated value and storage cost. Add immutable source-bound derived cache, explicit time range and bounded playback reuse. | Append/mutation/close/cancel/quota tests; no false conventional timeline readiness; no spectral job blocking ordinary playback; measure 8 GB VRAM coexistence and smaller fallback. |
| 4. Human Vision response | Separate owner-approved physical-spectrum contract or explicitly exploratory mapping; reviewed response data/licensing. | Known standard color-science integration/conversion cases; units and wavelength sampling; metamerism/gamut/adaptation limits; observer response separated from display transform; no claim that Model A modes are emitted light. |
| 5. Optional alternatives | A measured limitation of accepted CPU work. Wavelets/filter banks, directional maps, phase-aware reconstruction or GPU computation get separate scopes. | Match independent numerical references and quantify tradeoffs; justify added dependency/storage/renderer complexity before implementation. |

**Architecture decision:** conditional GO for a small verified CPU region-spectrum
increment when the data audit supplies the needed signed samples and geometry;
NO-GO for claiming calibrated Human Vision, automatic live spectral rendering,
or per-voxel physical wavelength from a scalar preview. Existing reader and worker
ownership provide a feasible starting point. The smallest required production
change is a separately authorized analysis operation plus its region/result
presentation—not a capture-format change or a replacement field renderer.
