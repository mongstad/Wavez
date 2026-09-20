# SimScope handbook

SimScope is a scientific capture viewer with a Python export layer and a Godot desktop viewer. Its job is to preserve declared data and make representation choices inspectable. A visually persuasive image is not a substitute for a numerical field, a conservation check or a declared boundary. The current implementation is `SimScope/`; see [current status](CURRENT_STATUS.md) for accepted scope and [evidence](EVIDENCE_INDEX.md) for measurements.

## Architecture and development history

The simulation advances its own state. Python exporters serialize samples into captures without owning the simulation's equations, units or physical interpretation. The Godot viewer reads committed samples, prepares display buffers and applies camera, mapping and layer settings. Rendering, inspection recipes and deterministic video use the same sampling and visual-state contracts. G4 numerical analysis runs on a bounded private Python worker using NumPy. Optional
full-grid isosurface extraction also uses scikit-image. Compression and external
engines have separate availability requirements.

| Stage | Delivered purpose | Evidence |
|---|---|---|
| G0 | Audit the particle viewer, compatibility, source preservation and real workload | [Historical state audit](CURRENT_STATUS.md) |
| G1 | Scientific particle inspection: signed/phase mapping, declared guides, physical-time inspection and recipes | [Inspection contract](<../INSPECTION_STATE.md>) |
| G2a / G2b | Bounded storage/index/cache and real playback work; typed lossless storage, explicit IDs, optional Zstandard | [Historical G2 storage report](<../G2_STORAGE.md>) |
| G3 | Native scenes with independently sampled particles, meshes and scalar grids; volume/slice/probe/surface rendering and export | [G3 acceptance](<../G3_REPORT.md>) |
| G3 maintenance | Refresh the live timeline's range as committed union timestamps change | Covered by current native timeline regression tests |
| G3 playback | Hidden-particle fast path, asynchronous preparation, startup/seek buffering and bounded RAM policies | [Performance maintenance](PERFORMANCE_MAINTENANCE_REPORT.md) |
| G4 | Selections, native-clock analysis, diagnostics, space-time plots, durable exports and matched runs | [G4 guide](G4_GUIDE.md), [accepted gate](G4_ACCEPTANCE.md) |

Earlier documents sometimes append new checkpoints above obsolete scope tables. This handbook and [current status](CURRENT_STATUS.md) resolve that chronology; a historical “G3 future” paragraph is not current truth.

## Viewer shell

The [issue-41 shell](UX3_SHELL.md) is implemented and pending owner review.
Use Open… in the command bar or empty view. Click the capture name for copyable
source details. State routes to the existing scene/analysis recipe controls;
Export routes to PNG, video and numerical export. View and the viewport buttons
provide frame/reset, panel visibility and fullscreen.

Scene retains the existing inspector. Appearance, Selection and Analysis provide
links into the same controls; choosing a workspace never binds a scientific
source or changes selection membership. Playback and budgets remain in that
inspector for this slice. The fixed header reports current capture context, not
a selected-object editor.

The right dock starts at 360 logical pixels, or 320 below 1200 pixels. Drag its
left edge to resize, use Hide panel/F1 to collapse, and Show panels to recover it.
Below 970 logical pixels the dock starts collapsed and can reopen as a temporary
sheet. Maximized mode keeps the top command bar. Fullscreen hides that bar and retains
Frame scene, Reset camera, Navigate and Exit fullscreen; exiting restores the bar. Failed-open details remain visible
until dismissed; a failed replacement retains the previous usable scene.

## Camera inspection

Mouse drag supports continuous yaw/pitch revolutions with no pitch clamp.
Horizontal motion rotates about world Y; vertical motion rotates about the
camera's yawed right axis. The camera up axis follows the tumble, including
upside-down views, without a world-up flip at either pole. This preserves the
existing two-axis orbit convention; it does not introduce a separate roll control.
Wheel zoom, free-camera WASD/Q/E movement, F (Frame scene), R (reset) and the
chosen orbit center retain their previous roles. O toggles automatic world-Y
orbit independently; manual dragging temporarily suspends it.

Recipes retain the existing yaw, pitch, target, distance and full transform
fields. They can save pole and upside-down orientations without a new schema.
Deterministic video still rotates the saved camera about world Y using video
time. See [UI-003 validation](CAMERA_TUMBLE_VALIDATION.md) for coverage and limits.

## Scenes, layers and time

SIMSCP3 describes named particle, mesh and volume objects, with at most one particle object and 16 total objects in the current implementation. Each has declared units, geometry/transform semantics, identity policy where relevant, and its own samples. A static object has one reusable sample. The scene timeline is the sorted union of committed timestamps, while layer sampling is independent. A field does not acquire a new scientific sample merely because particles were saved.

| Situation at requested physical time | Display/sample behavior |
|---|---|
| Exactly on a layer sample | Use that exact recorded sample |
| Between particle samples, with compatible explicit persistent IDs | Interpolate matched positions; scalar/category/phase values remain held at the earlier source time |
| Anonymous particles | Hold recorded positions and channels; no inferred tracks |
| Stable-topology mesh, compatible ordered vertex IDs and topology | Interpolate compatible vertex positions; held channels |
| Mesh without compatible identity/topology | Hold geometry |
| Volume between samples | Hold full field; no temporal field interpolation |
| Before the first dynamic sample | Layer unavailable |
| After the last sample | Hold the last sample, labeled as such |
| Static object | Reuse its one sample |

Identity is a simulation-owned int64 ID, not row number, category, proximity or a guessed correspondence. IDs may reorder between particle records, but cannot be duplicated or recycled after removal. Births appear at their recorded sample; removed IDs hold until that transition. Trails require explicit identities and contiguous recorded history. A changing isosurface is a geometric level set with no persistent material identity.

Physical-time seek accepts fractional times. The slider still indexes **union timestamps**; its thumb is not a continuous physical-time fraction. The latest fix only synchronizes its extent with committed growth/truncation. Sample source times and exact/interpolated/held state must remain visible in inspection/export provenance.

## Coordinates and scientific meaning

Viewer world uses a right-handed coordinate system with Y up and forward toward −Z. Exported particle positions must already be in viewer world. Meshes and grids can carry an explicit affine `data_to_world`; the adapter owns any axis or unit transformation. There is no automatic scientific unit conversion or arbitrary vector-basis conversion. A storage-axis transpose is different from a physical transform; applying both as rotations can transform data twice.

Keep nominal domain faces, grid sample locations, absorber geometry, imposed regions, source-sample particle bounds and display reference guides distinct. Declare each known item. Unknown geometry stays unknown. Tracer extent, brightness and display extent do not determine a computational domain or absorber.

Stored channels are scientific data. Colormaps, clipping, opacity, marker sizes and GPU previews are representations. A passive probe is not automatically a mass element, a field cell or a volume integral. Density on a real grid must come from that grid; it cannot be recovered exactly from a tracer cloud.

## Inspection and rendering

Particles support declared scalar semantics and categories, explicit marker channels, signed mappings and cyclic phase mappings. Available range policies include automatic per sample, automatic symmetric, fixed manual, and bounds frozen from a chosen recorded interval. Interval scans inspect recorded samples, not unseen extrema. Constant finite values map to the midpoint; invalid-only data have no finite range. Ordinary log mapping excludes nonpositive/nonfinite values and is not a signed mapping. Automatic ranges must remain labeled; scientific comparisons should use fixed ranges.

Volumes use declared uniform-grid geometry, selected channels, transfer ranges/colormaps, opacity and world-distance ray steps. Ray integration clips to the grid and opaque geometry. Axis-aligned and oblique slices, world-coordinate probes and clipping support inspection of the field without inferring it from particles. The initial implementation allows one translucent volume and one derived isosurface; arbitrary overlapping transparent volumes are not composited. Additive particles do not supply opaque depth.

Volume color range and extinction now have independent mappings. **Linear scalar**
maps the selected source scalar between explicit zero/full-opacity thresholds;
**Magnitude • absolute scalar** uses its absolute value for extinction while
preserving sign for color. A non-negative zero threshold permits transparent
zero/near-zero space even with a symmetric color range. **Opacity / world unit**
scales this weight; **Ray step** remains a quality/performance control. These are
presentation settings, not calibrated scientific measurements. New views retain
linear opacity 0–1; old recipes copy their saved color range into independent
opacity thresholds to preserve their original rendering. The
[mapping contract and validation](VOLUME_OPACITY_MAPPING.md) describe persistence,
limits and examples. Color edits alone never change opacity.

Volume color normalization supports linear and explicitly selected logarithmic
mapping, independently of opacity. Bounds can be entered manually or frozen from
the current source sample using its symmetric extrema or selected percentiles.
All policies retain the resolved bounds across playback and recipe restoration.
The controls disclose endpoint clipping, source finite extrema and actual clipping
presence. Log requires positive bounds and positive finite sample values; an
ineligible sample is explicitly unavailable, with source probes still accessible.
These are display choices, not calibrated interpretations. See
[volume color policies and validation](VOLUME_COLOR_NORMALIZATION.md).

Optional volume display presets resolve to explicit frozen settings: **Dense
core** uses full finite sample color extrema and linear opacity from zero to the
maximum; **Faint structure** uses chosen percentiles for color and zero to the
upper percentile for opacity; **Signed field** uses symmetric color and magnitude
opacity. All select linear color and a suitable colormap; strength, ray step,
particle visibility and the scene Viewing preset stay unchanged. These actions
are not active modes or automatic opening defaults. Manual controls and resolved
recipe settings remain authoritative. See [preset contract and review evidence](VOLUME_DISPLAY_PRESETS.md).

Probes read full source arrays with trilinear spatial interpolation and explicit world-to-grid conversion. At source sample coordinates they recover the source value subject to arithmetic/coordinate precision. An arbitrary probe point is an interpolated value, not an extra recorded scientific sample. Out-of-domain probes and invalid interpolation neighborhoods report unavailable. Python uses float64 probe coordinates; Godot coordinates are float32, so its displayed decimal values are not a last-bit validation instrument.

The white three-axis cross belongs to **Scene layers → Source probe**, not the
camera or particle-selection overlay. **Show probe marker** hides/restores the
last valid explicit probe without clearing coordinates or the numeric result.
Playback and seeking retain that last probe; click **Probe selected volume** to
sample again. Probing while hidden updates the result without showing the cross.
An unavailable probe hides it even if the switch is on. Recipe loading preserves
the session's marker visibility, but recipes/PNG sidecars do not serialize this
session-only marker. Screenshots include the cross only when shown; deterministic
video excludes it. F1 hides the inspector, not this 3D marker. Reopening a capture
resets the probe session (switch on, no cross until a valid probe).

GPU grids are float32 previews, potentially reduced by endpoint-aligned power-of-two LOD under budget; the shader samples that preview. Source arrays remain full resolution. Isosurfaces use optional scikit-image Lewiner marching cubes over the full source grid after the algorithm's float32 conversion, with no smoothing or decimation. Nonfinite-corner cells are omitted. A surface is an approximate level set, not a material boundary, tracked particle population or discovered physical object. Extraction is debounced, bounded, cancelable on stale requests and cached by source/settings identity.

Meshes contain real indexed triangles and optional vertex/face channels. Surface and wireframe views are supported. Source CCW winding and normals are transformed explicitly, including reflection and inverse-transpose handling. Face colors may require expanded display geometry; display memory can exceed serialized array size.

Scientific rendering disables decorative effects. Forward+ and Compatibility can differ in blending/color behavior; neither output is calibrated radiance, and cross-renderer identical pixels are not promised.

## Recipes, PNG and deterministic video

Inspection recipes save the source identity/committed extent, requested and actual layer times, camera, geometry guides, normalization and representation settings. The current native scene recipe is version 2; version 3
adds G4 selections, results and exact member assets. Replay pauses automatic clocks
and validates source/sample references. V3 pins the committed prefix, so later
appends cannot alter the replay. Version 2 may reject appends that
change a held bracket. Mutation, replacement and truncation refuse.

PNG sidecars can record the same state and an image hash. The screenshot destination is selected for the current session. Deterministic video renders a separate SubViewport at specified resolution and times, independent of interactive rendering speed; a real GPU renderer is required for image acceptance. The render worker minimizes
its noninteractive window and draws export frames explicitly, so rendering can
continue when it or the main viewer is minimized. Use the Export Video panel for
progress/cancellation; UI-launched jobs retain `renderer.log` alongside progress
and encoder diagnostics. A startup flash or taskbar entry can depend on the
platform.

For output frame `n`, requested capture time is `start + n × playback_rate / fps`; video time is `n / fps`. The interval is `[start,end)`, with a single frame for a zero-length interval. Samples use the same identity/held policies as inspection. Camera orbits advance by video time, not wall-clock render delays. Source identity and committed extent are pinned; unsupported source changes fail. Optional per-frame state survives successful PNG cleanup.

PNG sequences can be encoded with FFmpeg/H.264. Missing FFmpeg leaves useful PNGs; errors/cancellation retain recoverable job artifacts. Publication refuses overwriting an existing output. Timing is deterministic, while pixel identity across GPUs/drivers is not guaranteed. Full timing, cancellation, output and recovery details: [video contract](<../VIDEO_EXPORT.md>).

## Storage and performance

Typed SIMSCP3 channels preserve supported source bytes with optional lossless Zstandard. Compression is a storage choice, not a promise of faster playback. Validated indexes avoid repeated discovery, decoded LRUs avoid repeat decoding, and generation/source checks prevent stale data from being applied. Indexes and surface caches are disposable accelerators; committed capture bytes are authoritative. G3's Godot `.sidx3.json` and Python's direct scene scan are different paths. Native SIMSCP3 interactive particles, fields and meshes use separate bounded CPU workers. Field decoding, float32 conversion and image-plane preparation run ahead of playback; texture creation is staged on the main thread. Mesh source pairs and display buffers are prepared on a worker, with future surfaces staged on the main thread. Initial opening and explicit scientific inspection/export retain synchronous work.

The scene inspector's **Particle playback buffer** separates decoded sample RAM, prepared pair RAM and current GPU resources. **Automatic (safe RAM)** estimates all decoded samples and prepared pairs, including IDs, display arrays and enabled trails. It selects full preloading when a 25% estimate margin plus two largest pairs of working space fit within conservative physical-RAM headroom, after reserving other scene caches. Automatic full preload waits for all pairs before enabling Play. Otherwise a rolling cache targets at most 2 GiB, four initially ready pairs and up to eight pairs ahead, shortened by the safe budget or endpoint. Play waits for the selected preparation threshold, and uncached seeks show preparation while retaining the previous committed sample. Rapid seeks replace obsolete work; reverse playback and the optional **Loop recorded interval** rebuild the preparation window appropriately. Loop defaults off. Hidden particles skip preparation unless a guide, inspection or reveal needs their data.

Manual RAM choices retain a rolling cache; **All particle pairs, if safe** requests full preload while preserving the earlier four-pair startup. Every choice remains subject to the RAM guard. Budget reductions reclaim resident caches even when no new decode is needed. The selected strategy and reason appear in diagnostics. Historical explicit-preload evidence on the 48 GB workstation: a retained 100k-particle capture prepared 81 pairs in 13.3 seconds, enabled Play after 0.78 seconds and used about 2.50 GiB process RSS. An isolated probe measured 18.67 MiB of retained Godot allocations per decoded 100k-particle sample and another 7.27 MiB per prepared pair without trails. Conservative cache charges are larger and count shared references again. CPU preparation does not create GPU resources for every cached pair.

Temporal fields request the current source sample and up to four future samples per visible field, with reverse and loop ordering. A CPU LRU retains source arrays and prepared image planes up to 128 MiB, reduced on low-RAM hosts; another 128 MiB is reserved for active/in-flight field data. Required visible fields must fit the admission budget or preparation reports a refusal. The ordinary decoded-cache control still governs synchronous reads; this independent worker cache remains enabled with a 0 MiB decoded cache.

Each visible field holds its current texture and at most one staged future texture. Their per-texture budgets split the existing layer GPU share; this can increase preview stride on large fields. GPU uploads occur on the main thread, at most one per process frame, ahead of source transitions where possible. Texture binding and shader state changes remain on the main thread. Cold seeks and underflow hold the committed physical clock, disable Play and pause background analysis until the required samples are ready. Stale source/configuration work is discarded. Initial opening, scientific inspection and deterministic export remain synchronous; large textures can still cause an upload callback stall. See the [PERF-001/002 report](PERFORMANCE_MAINTENANCE_REPORT.md) for exact guards, bounds and retained 02B/03B measurements.

Mesh playback uses at most four future source pairs per visible mesh in the current direction, including reverse loops. Its CPU cache is capped at 128 MiB and further limited by safe physical-RAM headroom; displayed, in-flight and temporary data have additional conservative charges. A current mesh and at most one staged future mesh share each layer's GPU quota. At most one mesh upload runs per process frame. Cold seeks hold the committed clock until the pair is ready, and source/settings changes cancel obsolete preparation. GPU budget or float32 display refusals preserve the decoded scientific samples and report the unavailable preview.

Meshes with exactly matching stable vertex IDs and triangle topology use a relative position blend on the GPU. Changing topology or identity holds the earlier geometry. Source arrays remain typed and exact; vertex/face scalar colors hold the earlier sample. The material remains unshaded. Explicit inspection obtains the same float32 preview positions and recomputed deformed normals as synchronous sampling; it never treats a GPU preview as full precision source data. Large buffers may still stall during upload. The owner reviewed and accepted PERF-003 on 2026-09-13; [methods, retained 04B results and limits](MESH_PLAYBACK_MAINTENANCE_REPORT.md) are recorded separately from accepted PERF-001/002 evidence.

On the retained 100k-particle capture, prepared visible transitions measured about 20 ms versus 177–181 ms before optimization, and hidden transitions about 2.6 ms. Both renderers completed the tested matrix, longer replenishment, 2× playback and loop controls without ≥50 ms callbacks. Cold startup and uncached seeks still require an explicit buffer wait. The remaining visible callback is mainly position packing and GPU submission. These measurements do not establish the same latency with every field or trail enabled. See [performance maintenance](PERFORMANCE_MAINTENANCE_REPORT.md) for current methods, limits and regressions.

Earlier checkpoints measured a real ~100k-particle capture at roughly 11.8–11.9 source samples/s when requesting 12. The full analytic G3 demo measured about 19.2 completed samples/s, with median preparation/presentation around 32 ms and p95 around 145–149 ms including extraction barriers. GPU median was about 0.3 ms; CPU preparation and transitions dominated. These are historical host/workload measurements, not universal promises. See [performance evidence](EVIDENCE_INDEX.md) before extrapolating from already-decoded synthetic renders.

Budgeted decoded arrays, caches, graphics buffers, temporary transforms and worker memory are separate. They do not sum to a strict process RSS/VRAM ceiling, and the G3 surface cache has no automatic global disk cap. G4 has separate finite
worker, preview, exact-member and export quotas, including a 2 GiB default disposable
result cache; see [G4 schemas](G4_SCHEMAS.md). [Format/API limits](CAPTURE_FORMAT_AND_API.md) are the integration preflight reference. No simultaneous heavy CuPy/viewer contention benchmark has been accepted.

## Roadmap boundary

G0–G4 are implemented and accepted. G4 reads scientific source values, keeps
independent native clocks explicit and preserves exact identities; hidden or clipped
selections remain numerically usable. [The guide](G4_GUIDE.md) distinguishes source
traces, weighted statistics, field integrals, tracer estimates and exploratory periods.
G5 local control/optional MCP and G6 events/broader adapters/release work are
**NOT IMPLEMENTED and NOT STARTED**. No web/dashboard work is authorized.
New development targets `.ssc` / SIMSCP3 under the
[capture format policy](CAPTURE_FORMAT_POLICY.md). The
[roadmap](../SIMSCOPE_NEXT_DESIGN.md) and [acceptance registry](../SIMSCOPE_ACCEPTANCE_MATRIX.md)
do not independently authorize future milestones.
