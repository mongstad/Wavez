> G4 implementation completed 2026-09-12 under the authorized G4a–G4f plan.
> [Final report](G4_REPORT.md) and [acceptance ledger](docs/G4_ACCEPTANCE.md)
> supersede historical capability/pending statements below. The user accepted G4;
> G5/G6, web work and external simulation work remain outside authorization.

> Historical implementation checkpoint 2026-09-11: G3a/G3b and the reported
> overlay fix were implemented. See G3_REPORT.md and G3_FORMAT.md for that scope;
> current status and later evidence are in docs/CURRENT_STATUS.md and docs/EVIDENCE_INDEX.md.

> Consolidated review 2026-09-12: the authoritative status is now
> [docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md); historical development-copy and
> removed handoff-file references are superseded by that status and docs/EVIDENCE_INDEX.md.
> [G4_DESIGN.md](G4_DESIGN.md) reconciles §9 with current G2/G3 source and proposes
> G4a–G4f plus acceptance clarifications. **The user approved that design and
> authorized G4a–G4f on 2026-09-12, after a separate documentation-consolidation
> commit is pushed. G5/G6 remain outside the current authorization.**

# SIMSCOPE Next — Design and Delivery Plan

**Status:** Proposed implementation specification, not a claim that these features already exist.  
**Prepared:** 2026-09-10 · for Johnny, Astra/Codex and Sol  
**Scope:** Evolve the existing Linux/Godot viewer and Python export ecosystem. Do not start a replacement application or modify simulation physics.

## 1. What we are building

Turn SimScope into a local scientific visualization workbench that combines particles, actual sampled fields, surfaces and time-series evidence in the same reproducible scene. Keep the cinematic experience, but make it much harder to confuse a tracer distribution, a rendering effect, an imposed boundary and a property of the simulated field.

The flagship workflow is:

> Open a vacuum-collapse run. Show density as a volume, overlay persistent tracers, draw the declared computational domain and absorber, inspect a throat region over time, and capture matched signed-current views. A local automation client must be able to reproduce the same inspection using bounded, auditable commands.

This is not a cosmology engine. SimScope must not claim that a visual pattern validates physics. It displays and analyzes supplied data, identifies approximations, and preserves the distinction between measurements and interpretations.

### Evidence and scope boundary

The supplied API/format/report documents describe the earlier reusable viewer: `SimScopeCapture`, VBCOSM1/SIMSCP1, arbitrary scalar channels, live appended frames, scientific/cinematic rendering and stable-index interpolation. They also describe missing compression, persistent indexing and ID matching. [P1–P3]

Johnny subsequently reports working deterministic MP4 export and completion of the screenshot-directory/trail-default changes. Those newer features are **user-reported working behavior**, not independently audited current source in this design package. The original video task is a specification, not proof of its final implementation. [P4; conversation]

Astra must inspect the actual checkout first. Do not rebuild a feature merely because an older report calls it missing. In particular, video export may already have a usable physical-time sampler, state snapshot and job manager; reuse and extend those components.

## 2. Non-negotiable constraints

Preserve existing captures, simulation integrations, working screenshots and high-quality video export. Keep `from simscope_export import SimScopeCapture` working for old callers. Never overwrite or silently migrate original captures.

Target the reported Fedora/KDE/Wayland workstation: Ryzen 7 5800X, 48 GiB RAM, RTX 3070 Ti with 8 GiB VRAM. Verify installed software versions locally; the old documentation's Godot version and installation paths are not discovery results for the current machine. No mandatory hardware purchase, paid service, cloud upload, model subscription or external AI service.

The simulator owns physics. Visualization may run more slowly, but cannot change the solver's timestep, force fields, random state, initial conditions or conservation bookkeeping. Optional adapters must pass a small-run equivalence test with export on versus off.

Recorded History/Trails remain OFF on fresh startup. Scientific presets must not silently enable them. Explicit video-job settings may enable trails without changing the interactive viewer's default. PNG destinations remain session-only: ask on the first interactive Save PNG/P action, reuse until exit, ask again after relaunch. Saved scene files must not accidentally persist this session-only screenshot destination. Explicit batch export destinations are separate.

Do not turn the project into a web dashboard, an autonomous solver, a plugin marketplace or a new GUI framework. Avoid a full rewrite of `main.gd`; extract tested responsibilities incrementally.

## 3. Delivery order and stop conditions

A milestone is complete only when its implementation, tests, reproducible demo and documentation agree. Failed gates block dependent work, not unrelated safe fixes. Continue through the authorized milestone while gates pass and resources allow; do not stop after writing a plan. The current authorization covers G4a–G4f only, with the blocker/stop rules in G4_DESIGN.md and docs/CURRENT_STATUS.md.

| Gate | Deliverable | User-visible result | Depends on |
|---|---|---|---|
| G0 | Audit and regression baseline | Existing viewer still works; real capability inventory | Existing checkout |
| G1 | Shared scene/state/time model; normalization and boundary UX | One-click signed ranges, exact state capture, unambiguous domain guides | G0 |
| G2a | Persistent indexes and bounded caches | Faster repeated opens/seeks; explicit memory and loading states | G1 |
| G2b | Opt-in typed/chunked storage and stable IDs | Compression, exact identity, recoverable new streams | G2a and codec spike |
| G3a | Mesh and scalar-volume rendering | See a mesh or actual field, not only particle markers | G2b |
| G3b | Slices and isosurfaces; simultaneous layers | Density surface/volume with tracer and domain overlays | G3a |
| G4 | Selections and temporal analysis | Click/mark a region, inspect time series and space-time plots | G1–G3 |
| G5 | Secure local control, recipe orchestration and optional MCP bridge | Automated matched views and bounded scientific inspection | G1, G4 |
| G6 | Event detection, adapters and release validation | Reproducible event bookmarks and reusable integrations | G2–G5 |

**First handoff priority:** finish G0 and G1 as an end-to-end change, rather than scattering unfinished stubs across all nine feature areas. Then G2/G3 provide the first actual-field visualization milestone. A small uncompressed volume proof of concept may validate feasibility during G0, but it is not a second permanent format or a substitute for the G3 gate.

## 4. G0 — inspect, measure, preserve

Read the actual `AGENTS.md` instructions, git status/diff and relevant history. Inspect the exporter, readers, `viewer/main.gd`, capture playback, rendering/material code, screenshot workflow, video jobs, tests and existing architecture documentation. Do not reset, stash, delete or commit unrelated user work.

Record `CURRENT_STATE_AUDIT.md`: paths, commit/dirty state, versions, actual implemented features, tests available, limitations observed and deviations from this plan. Review the three known capture families: legacy, generic v1 and any newer formats already added locally.

Run available automated tests and a small real-renderer smoke test. Record baseline frame time, p95 frame time, open/seek latency, process RAM, measured GPU memory where available, upload/decode time and PNG/encoding time. Separate rendered tests from headless parse tests. A headless run without a functioning renderer does not validate visual output.

Use reproducible fixtures: 20k, 100k and 250k particles; a tiny nonuniform-time capture; empty/count-changing/schema-changing captures; a truncated live capture. Preserve representative rendered reference images and the working video test. Do not regenerate multi-gigabyte fixtures repeatedly.

Record architectural decisions only where needed: scene/state extraction, storage protocol, timestamp/identity semantics, coordinate conventions and local-control security. Update an existing decision record rather than creating duplicates.

## 5. Shared architecture and source of truth

The exact filenames below are illustrative; adapt them to the checkout. The responsibility boundaries are requirements.

```text
Simulation / data adapter
  -> writer or importer
  -> capture stream(s), optional diagnostic CSV, scene manifest
  -> DatasetReader + Index + bounded Cache
  -> TimelineSampler + Selection/Statistics services
  -> SceneState + commands
       -> ParticleRenderer / MeshRenderer / VolumeRenderer / PlotView
       -> Screenshot / existing VideoExport
       -> local control + recipes + optional MCP facade
```

UI, export jobs and agent commands must use the same validated command/state path. Do not maintain three competing implementations of color ranges, time interpolation or filters.

Workers may read/decompress/analyze immutable buffers. Scene-tree mutations and GPU resource publication go through the appropriate Godot main/render-thread mechanisms. Do not create textures or mutate scene nodes arbitrarily from worker threads; confirm the installed engine's thread-safety constraints. [G4]

Use cancellable tasks with generations/request IDs. If a user seeks from t=10 to t=500 while a t=10 volume is decoding, an old task must not overwrite the newer requested state. Caches are bounded by bytes, not just a count of objects.

### Scene and layer model

Introduce a versioned JSON scene manifest, provisionally `run.simscope.json`. It references data streams without embedding binary arrays and may coexist with a directly opened `.vbc`. All names and new APIs in this document are proposed until implemented and documented.

A scene contains:

- Dataset identifiers, stable object/layer identifiers and human-readable names.
- Particle, triangle-mesh, uniform-grid volume and diagnostic-series layers.
- Source paths, time axes, units, transforms and data provenance.
- Rendering state, visibility, filters, selected time and camera.
- Named selections, bookmarks and diagnostic regions.

Simulation-supplied data metadata is separate from viewer-state overrides. Opening a bare old `.vbc` constructs an in-memory scene with one particle layer. New scene support must not make old captures require a sidecar.

Paths are resolved relative to the manifest when practical. Opening a manifest cannot execute code, load a plugin or launch a process. Data importers must treat unexpected absolute paths, traversal and external references as untrusted; the user explicitly approves resources outside the chosen dataset root.

## 6. G1 — fix interpretation and reproducibility first

### 6.1 One state snapshot

Create versioned, serializable `ViewerState`/`SceneState` using existing export state where possible. Include capture identity, committed frame/time, layer visibility, active channels, exact ranges, colormap, logarithmic/linear/cyclic mode, clipping behavior, size/brightness/opacity, sample/LOD status, selections, trails and camera.

Provide **Copy Inspection State** and saved inspection recipes. Each PNG may have an optional adjacent JSON sidecar recording the applied state and source frames. Ordinary Save PNG must preserve its existing session-directory behavior. Export-specific sidecars go into the explicitly requested job output directory.

When a screenshot is requested, wait for data load, state application and rendering completion. Record requested time, actual sampled timestamps, interpolation policy and any missing/stale layers. Do not label a t=500 screenshot using a stale t=499 diagnostic title.

### 6.2 Clear channel semantics

Add explicit normalization options: automatic per-frame min/max; automatic symmetric about zero; fixed manual range; fixed range from a selected time interval. For symmetric scaling choose A=max(|min|,|max|), then [-A,+A], with a documented nonzero fallback for all-zero fields. Permit a rounded display bound without altering source data.

Default signed quantities to linear, zero-centered diverging maps when their descriptor declares signed semantics. Do not guess that every custom channel is positive. Preserve explicit user choices. Disable ordinary log scaling for signed values unless a separately defined transform such as symmetric-log is implemented, labeled and tested.

Robust percentile ranges are optional and must label clipped/hidden counts and percentile limits. Freeze one range across a multi-time comparison or video job when requested. Independently autoscaled panels must say so. Provide an explicit cyclic mode for phase rather than treating its wrap point as an ordinary minimum/maximum discontinuity.

Add human-readable type names using a declared ID-to-label metadata table; missing labels remain `Type N`. Preserve the distinction between persistent identity and category.

### 6.3 Domain guides that do not guess physics

Separate **simulation domain**, **data bounds**, **reference grid**, **absorber region** and **imposed geometry**. A data-derived box must never be labeled as the PDE boundary.

Publish and document an optional geometry metadata schema: domain minimum/maximum; coordinate units; origin; grid dimensions and spacing; cell-centered versus node-centered sampling; absorber center/start/width/profile; named imposed regions. Unknown geometry remains unknown. Old captures can use a user-confirmed scene override, explicitly labeled as an override, without editing their bytes.

Apply transforms exactly once. Old particle captures already use exported viewer coordinates. A future grid stores a declared array-axis order plus sample-index-to-world transform. Show the cube and spherical sponge separately, with numeric labels and distinct styles. Test the known case: L=64, N=128, dx=0.5, domain faces ±32, cell centers ±31.75, absorber onset r=27.2. These are a fixture, not a universal default.

Do not infer an absorber or throat from particle positions, `radius` or the visual wireframe.

### 6.4 Shared time semantics

Audit the video-export sampler first. Reuse it for interactive physical-time playback where correct. Keep the existing frame-index playback mode as an explicitly labeled compatibility option.

For increasing timestamps t_i, locate bracketing samples and use w=(t-t_i)/(t_(i+1)-t_i). Exact time requests retrieve the exact sample. New streams enforce strictly increasing finite times per object; static objects have a separate representation. Duplicate/nonmonotonic old times remain inspectable in index mode, with physical-time interpolation disabled or segmented under a documented rule, never silently sorted.

Every layer can have its own cadence. At any scene time show whether the layer is exact, interpolated, held or unavailable. No automatic extrapolation. A growing capture exposes committed records only.

Video time is not source-frame count. Preserve existing end-exclusive range and still-image behavior after auditing it. Test endpoint arithmetic and make the export UI distinguish source samples, output frames, output duration and measured render-time estimates.

**G1 demo:** reopen an old capture, show a truthful boundary guide, select a signed channel, apply symmetric range, save a reproducible screenshot and recreate it from the saved state. Existing MP4 export and PNG session behavior still pass.

## 7. G2 — storage, compression, indexing and identity

**Implementation amendment (2026-09-10):** G2a and the G2b particle storage/ID
contract are implemented in the v1.0.3 copy; see G2_STORAGE.md and G2B_FORMAT.md.
The user explicitly superseded stable-row compatibility: ALL interpolation and
trails require persistent IDs. Anonymous legacy/v1/v2 captures use sample-and-hold.
The contemporaneous deferral of G3 mesh/field records is superseded: G3 is now
implemented in SIMSCP3. G3_FORMAT.md and docs/CURRENT_STATUS.md describe current
behavior. The sections below preserve the historical design roadmap, not a
requirement to recreate implemented features or change existing wire bytes.

### 7.1 Preserve v1; do not smuggle new types into it

The provided SIMSCP1 specification permits float32/uint32 channel arrays and requires particle positions. It does not specify volume chunks, triangle topology or 64-bit identities. Incompatible changes require a new explicit version/magic. [P1, P2]

Keep existing writer defaults and legacy bytes unchanged. Add an opt-in typed stream, provisionally `format="simscope2"`, with an unambiguous new magic/version. Update Python and Godot readers before recommending new captures. The earlier proposal is implemented as `format="simscope2"`; its current contract is G2B_FORMAT.md. New layered work normally uses `SceneCapture` / `SceneReader` and SIMSCP3. Legacy `SimScopeCapture()` still defaults to SIMSCP1; G4 must not change that default.

Do not send IDs through the old custom-float path. Do not encode mesh topology as fictitious particles or reconstruct an allegedly exact volume from a sparse tracer cloud.

### 7.2 Persistent indexes before compression

Add a disposable on-disk index for old and new streams. Index entries contain object, time, record/chunk offsets, sizes and available channel schemas. A reader can rebuild it by scanning validated records; the index is never the only copy of data.

Invalidate on changed file identity, replacement, truncation or incompatible parser version. For new streams use a stable file UUID/generation and per-record integrity checks; for old streams use header/prefix fingerprint and file metadata, conservatively rebuilding when append-only identity cannot be established. A cached index must not make an incomplete tail readable. Update index files atomically and retain the last validated byte offset.

Use binary search for time lookup, bounded decoded-frame caches and asynchronous prefetch. Opening a long capture should not decode every frame or load the entire run into RAM. Log cold/warm open and seek timings separately.

### 7.3 Typed, independently readable chunks

Specify the new wire format in an ADR and test fixtures before using it for production. Requirements:

- Little-endian, explicit version, object descriptors, semantic channel descriptors, shape/dtype, units, sampling location and data transform.
- Particle records with IDs; mesh topology/attribute records; volume brick records; static geometry referenced rather than repeated.
- Independently compressed chunks with codec ID, stored and decoded byte counts, integrity checksum and bounds on all counts/allocations.
- A commit record or equivalent complete-record guarantee: a partially written frame is unavailable; earlier complete frames remain recoverable.
- Unknown optional channels/objects can be skipped by length. Unsupported required codecs/versions fail clearly.
- No whole-file ZIP as the normal live playback format. No mandatory footer or global dependency chain to decode one frame.
- Lossless values by default; float16/quantization or temporal deltas are deferred, explicit derived representations, never silent changes to scientific data.

Start with `none` and Zstandard. Zstandard is an established lossless codec, but actual compression depends on the data. [G5] Perform a Python-write/Godot-read byte-for-byte interoperability spike. Do not assume `FileAccess.open_compressed()` can read an arbitrary Python-compressed file: Godot documents a Godot-specific container restriction. [G6]

First try a verified supported bounded buffer decoder. Introduce a small GDExtension only if required and benchmarked, with a build/install test for the target Linux system. Never spawn a Python process per frame to decode data. Keep the uncompressed reader as a diagnostic/fallback path.

For volumes start with independently readable 32³ or 64³ bricks, measure the tradeoff, and record the chosen default. Decoder halos/neighbor samples for gradients and surfaces must be handled explicitly. Compression must not be required to get the first tiny volume fixture working.

### 7.4 IDs and interpolation rules

Proposed first ID contract: stable, nonnegative signed-64-bit IDs in [0, 2^63-1], unique within a particle object per sample and never recycled during that object's lifetime. Store as integer buffers. On JSON control APIs encode IDs as decimal strings to avoid numeric precision loss. Reject unsupported source ID ranges; an explicit adapter remapping must retain a reversible mapping table.

At bracketing frames, match shared IDs even if array order and particle count change. Interpolate positions only for shared IDs. New IDs appear at their first recorded time; removed IDs have no inferred death trajectory. Hold an endpoint only under a clearly documented lifespan policy. Never draw a trail between unrelated IDs or across an unobserved disappearance/reappearance gap.

**Current sampling contract (supersedes the earlier optional continuous-scalar proposal):** particle positions interpolate only under the established explicit-ID rules. Scalar, categorical and phase values hold; G4 does not enable scalar or temporal field interpolation. Phase interpolation would require a separately approved circular/complex-field policy. Mesh position interpolation requires identical ordered vertex IDs and topology; other transitions hold. See G2B_FORMAT.md, G3_FORMAT.md and G4_DESIGN.md.

User amendment: old streams without IDs use sample-and-hold and cannot enable trails, even if ordering or counts appear stable. Do not invent identities retrospectively from array indices or nearest-neighbor guesses.

**G2 demo:** a shuffled, variable-count particle capture follows the same IDs correctly; v1 still plays; reopening a long file uses a validated index; a truncated compressed tail recovers preceding frames; changed or corrupt data cannot use a stale index silently.

## 8. G3 — actual fields, meshes, slices and surfaces

### 8.1 Data first: the exporter must supply the field

A true volume requires an actual grid sample such as rho=|psi|² with spacing/origin/units. Existing tracer-only captures cannot provide a lossless reconstruction. Support importing already saved raw NPZ snapshots with `allow_pickle=False` and an explicit user metadata mapping; otherwise future simulator runs must export grid snapshots at a chosen cadence.

Do not change the wave equation. A separate adapter may export particles every 0.25–1.0 time unit and volumes less frequently, with different per-object timestamps. These are illustrative cadences, not defaults to impose on all simulations.

For the new uniform-grid contract, use C-contiguous arrays shaped (Nz, Ny, Nx), with x fastest on disk, unless an ADR explicitly chooses another canonical order. Origin denotes the first sample location; cell/node centering and the data-to-world transform are separately declared. Adapters for existing arrays ordered (Nx, Ny, Nz) must explicitly transpose; a non-cubic fixture must detect accidental axis swaps. Vector components and basis transforms need their own declared convention.

Represent complex fields as paired real/imaginary arrays when requested. Store derived rho or phase with its provenance. A density-only stream cannot reconstruct complex phase or arbitrary wave current; report unavailable quantities rather than invent them.

### 8.2 Triangle meshes

Support indexed triangle meshes with positions, topology, optional normals and vertex- or face-associated channels. Start with a supplied static mesh, then fixed-topology animation. Changing topology is a new discrete sample; never blend unrelated vertices.

Use a dedicated renderer such as ArrayMesh/MeshInstance3D; these are documented Godot geometry facilities. [G2] Normals, winding and inverse-transpose normal transforms must be correct. Handle handedness changes explicitly. Invalid indices, nonfinite positions and oversized resources fail validation before GPU upload.

Add surface, wireframe and scalar-colored views. Defer skeletal animation, CAD kernels and arbitrary material graphs. A small deforming toroidal mesh fixture is useful, but label it synthetic geometry, not a physical discovery.

### 8.3 True scalar-volume rendering

Build a volume renderer using a 3D scalar texture and a custom volume shader/ray march. Godot exposes 3D textures for use in custom shaders; that capability is a building block, not an already complete scientific volume renderer. [G1]

The first version handles a single axis-aligned uniform grid with an explicit transform; multiple time samples use bounded buffers. Add scene-layer overlap with particles and an opaque mesh. For intersecting translucent volumes, either implement correct interval compositing or state and enforce the initial limitation; never imply transparency sorting is solved when it is not.

Required controls: scalar channel, transfer function, numeric range, opacity/exposure, sampling quality, clipping planes and optional empty-space skipping. Distinguish emissive cinematic rendering from numerical scalar interpretation. A fog effect or dense point cloud does not satisfy this requirement.

Account for opacity over physical sample length (for example alpha=1-exp(-sigma*delta_s)) so changing ray-march steps does not arbitrarily change apparent density. Validate against a homogeneous slab and simple analytic field. Respect geometry depth and camera-inside-volume behavior. Log all display-only approximations.

Start with full-resolution scalar values on disk. GPU display downsampling/half precision may be optional after measured validation; numeric probes and analysis use declared source precision, not the display texture. Show an explicit `display LOD` label.

### 8.4 Slices and isosurfaces

Support XY/XZ/YZ and an arbitrary plane through a volume, with crosshair numeric probes and known source coordinates. A slice must match an independently computed slice from the same sample, apart from declared interpolation.

Extract an isosurface at an explicit scalar threshold. Prefer a tested existing implementation in an optional Python worker for the first version; do not write an unvalidated marching-cubes table. Record algorithm, source time, threshold, spacing and any smoothing/decimation. Cache by input identity and parameters. Debounce slider changes, cancel stale extraction tasks, and enforce vertex/memory ceilings.

An isosurface is a chosen level set, not automatically a material surface. Remeshing does not create trackable surface-particle identities. Test known sphere/torus fixtures, anisotropic spacing, transformed origins, missing data and slab boundaries; eliminate cracks introduced by brick assembly.

### 8.5 Hardware budgets and progressive quality

One float32 scalar sample requires approximately 8 MiB at 128³, 27 MiB at 192³ and 64 MiB at 256³. These are array-size calculations only: multiple samples/channels, GPU formats, meshes, intermediates and framebuffers add memory.

Proposed starting budgets: 2 GiB decoded CPU cache; 2 GiB viewer GPU working-set target when sharing with CuPy; up to 4 GiB standalone. These are configurable targets, not promises of currently free memory. Measure actual usage where supported and leave OS/desktop/driver/simulation headroom. On allocation failure release preview caches and downgrade explicitly, not crash or alter stored data.

Never load all timesteps of a volume at once. Bound decompression and GPU-upload queues. Under archival recording, apply explicit backpressure without changing physical dt. Dropping is allowed only for an explicitly selected preview stream, with missing timestamps recorded; never silently discard archival frames.

**G3 demo:** a 128³ scalar field plus 100k tracers, actual domain/absorber guides, one movable slice and one isosurface can be inspected and exported on the target machine. Report achieved performance. Include a direct-grid versus tracer comparison from a saved run when raw data is available.

## 9. G4 — selection and temporal analysis

The detailed proposed contract, source review, implementation sequence and test
fixtures are in [G4_DESIGN.md](G4_DESIGN.md). The goals below remain intact;
the detailed design resolves native layer clocks, exact identity, mesh topology,
node/cell quadrature, source precision, bounded workers and saved-state semantics.
The [acceptance matrix](SIMSCOPE_ACCEPTANCE_MATRIX.md) retains A01–A10 and adds
targeted regression criteria. The approved implementation follows G4a–G4f after the documentation-consolidation checkpoint; G5/G6 are not authorized.

### 9.1 Selection semantics

Support ID picking, screen rectangle/lasso, type filters, numeric channel filters, and world-space box/sphere/cylinder/plane-slab regions. Define occlusion policy for picking and volume selections. Highlight the selection without changing the source data.

Two modes must remain distinct:

- **Fixed ID cohort:** the same identified particles followed over time.
- **Spatial query:** whichever samples/particles occupy a region at each time.

Selection descriptors store coordinate system, units, object, time policy, filter expression and missing-data behavior. A lasso on anonymous historical particles is a selection at that sample, not a known longitudinal cohort. Store reproducible predicates, not arbitrary executable expressions.

### 9.2 Statistics without accidental physics claims

Expose count, finite/invalid count, min/max, mean, quantiles and explicitly weighted statistics. Every result states population, object/layer, time, selection and weighting. Distinguish all recorded samples from rendered/LOD-visible/filtered samples.

Coverage tracers and density-weighted tracers are not interchangeable mass elements. Do not sum their sampled density values and label the answer total field mass. A physical particle sum requires physical per-particle mass; a volume integral requires cell measure; a sample estimate requires valid sampling weights. Changing `--simscope-uniform-frac` must not change a supposedly exact field mass diagnostic.

Use promoted float64 accumulations for sensitive sums and signed cancellation diagnostics where practical; report the reduction precision. An integral of |psi|² is a wave norm unless the model explicitly defines a physical mass conversion. Do not silently label every channel called density as mass density.

For wave data, expose simulation-supplied diagnostics separately from viewer-derived approximations. Global angular momentum, flux and vorticity need declared units, origin/reference frame, derivatives and field support. A bright RGB pattern is not evidence of conserved spin.

### 9.3 Time-series and space-time views

Import diagnostic CSV with a selected time column, units and source identity. Do not interpolate across missing intervals silently. Link timeline cursor, plot selection and viewer seeking through the same sampler.

Implement regional count/mass/mean-density/centroid/signed-current plots only when required source data exists. Add a volume-based density-vs-position-vs-time plot along a selected axis or slab. Label tracer histograms as sample estimates, not exact density maps.

For cycles/events, begin with peak detection and autocorrelation with documented windowing, detrending, sampling checks and uncertainty. A few similar peaks are not proof of a stable period. Include full-run and selected-window comparisons.

Create bookmarks, synchronized views with locked camera/range, and batch export of matched channels. Default comparisons share a fixed range or visibly declare independent normalization. Preserve raw times when aligning runs; a bounce-aligned view is a labeled derived time axis.

**Required G4 demo:** use repository-owned deterministic synthetic particles, a direct scalar field, a lower-cylinder ROI and a small supplied diagnostic CSV. Compare native-clock traces with a supported field integral and create a traveling-pulse space-time plot. Repeat on a tracer-only fixture and explicitly decline an exact field integral. This self-contained demo avoids any dependency on an external scientific project. External data may be used only as explicitly selected, optional, read-only validation; its code/data/results must not become repository, test, demo or packaging dependencies.

## 10. G5 — agent control and plugins, locally and safely

Ordinary recipe save/load, saved inspection state, selection reproducibility and
G4 analysis reproducibility belong to G4 (building on existing G1/G3 recipes).
G5 owns local control, authenticated command access, recipe automation/command
orchestration, optional MCP, multi-client concerns and plugin/control lifecycle.

### 10.1 One bounded control API

Build commands on the same G1 state/selection services, not through simulated mouse clicks. Suggested methods are design names, not current APIs:

```text
get_capabilities, get_viewer_state, list_layers, list_channels
get_frame_statistics, get_diagnostic_series, get_geometry
seek_time, set_camera, set_mapping, set_layer_visibility
create_selection, inspect_selection, save_bookmark
capture_inspection, start_export_job, get_job_status, cancel_job
```

Queries accept explicit scope and result limits; no default million-particle JSON responses. Time-consuming operations return job handles. Mutations use expected scene revision/state IDs to prevent races with interactive use. Return the applied state revision and actual times with results.

`capture_inspection` atomically resolves time, applies mapping/camera/selection, waits for rendering and exports image plus state. Optionally restore the interactive state, but do not overwrite newer user edits. Batch work should use the existing separate renderer where practical.

### 10.2 Local transport first

Start with a Python control client and a disabled-by-default authenticated loopback command endpoint, or a protected local IPC channel if already supported. Restrict allowed reads to opened/user-approved datasets and writes to approved output directories. Use session-scoped capabilities, strict schema validation, payload/rate limits and audit logs. Revoke access immediately from the UI.

No shell/eval/file-delete tools. No arbitrary Python from captures. No mutation of simulation physics. Request explicit user approval for enabling access, opening new data roots, replacing an existing file or starting a resource-heavy export outside a preapproved budget. Ordinary approved view changes should not require endless per-click prompts.

An optional MCP facade can wrap the same commands for a compatible client. Start with a local stdio bridge where supported; MCP also specifies Streamable HTTP with Origin validation, localhost binding and authentication protections. [G7] Implement the protocol through a maintained compatible SDK, not a homegrown approximation.

**Important:** building an MCP server does not automatically connect this chat to Johnny's workstation. Client compatibility, configured connection and permissions must be verified separately. Do not expose a public endpoint or add a tunnel merely to claim ChatGPT integration.

### 10.3 Local plugin boundaries

Initially support trusted, explicitly installed data adapters and analysis plugins, not an unrestricted in-viewer script console. Define manifest version, entry point, dependencies, capabilities, plugin/API version and failure reporting. Use an external worker for heavy Python analysis so failure can be handled without losing the viewer.

A separate process is crash isolation, not automatically a security sandbox. Until filesystem/network restrictions are actually enforced and tested, label plugins trusted-code-only. Never auto-install or run a plugin named in capture metadata. No cloud calls without explicit configuration and authorization.

**G5 demo:** a local recipe obtains signed extrema at t=301, sets a symmetric diverging range, captures matched views and writes an inspection report with provenance. Missing authorization and out-of-root paths are rejected. Document which client was actually tested.

## 11. G6 — useful event detection and adapters

### 11.1 Events before autonomous interpretation

Start with deterministic, configurable rules, not a language model deciding which blob is a new physical object. Examples: peak density, RMS-radius turning points, region entry, flux reversal, sustained numerical-budget residual, rapid sample-count changes, absorber contact and an unavailable/stale diagnostic stream.

Use channel units and known diagnostic semantics. A supplied norm residual differs from intentional absorber loss. Speed/phase anomalies near low density need validity masks. A waveform detector needs documented thresholds, minimum durations and refractory periods; do not treat every timestep as a separate event.

Each event includes run/object, time interval, measured value, threshold, algorithm/version, source records, masks, severity and an explanatory label. Return `candidate` or `numerical warning`, not `new physics confirmed`. Calibrate against synthetic known events and non-events; report misses and false positives.

Events can create bookmarks and inspection recipes. An optional external language model may summarize these records later, but basic detection must work offline with no paid dependency. An agent receives untrusted metadata as data, never executable instructions. [G8]

### 11.2 Adapter order

1. Preserve the existing NumPy/CuPy particle workflow and validate external-engine integration through the explicit SceneCapture object contract. [P1]
2. Add uniform scalar/vector grid and mesh-array adapters with explicit origin/spacing/units/association.
3. Add a noninvasive VacuumCollapse adapter exporting direct density samples, optional complex components, domain/sponge metadata and declared tracer populations. Preserve old scripts; use a separate adapter or explicit integration flag.
4. Add diagnostic CSV + raw NPZ import, and a small offline astronomical point-catalog example. Do not fabricate 3D distances from a 2D sky image.
5. Add selected VTK/VTU, HDF5 or Zarr import only after a concrete fixture and dependency review. They are optional import backends, not three competing new native formats. Defer AMR, unstructured volumes and giant survey ingestion until needed.

An adapter must retain units and sampling semantics, report precision changes, and keep data import separate from solving physics. Update `SIMSCOPE_INTEGRATION.md` so the ordinary particle path remains short and new capabilities are discoverable without contradicting `SIMSCOPE_API.md`.

## 12. Performance, export and resource safety

Keep capture storage performance separate from video performance. Compressed captures do not eliminate rendering, GPU readback, PNG compression or final encoding. Profile stages independently before optimizing.

Reuse the working deterministic exporter and add support for new layers through the shared scene renderer. An export job must snapshot the committed data extent: a live-growing capture cannot silently lengthen an active render. Pin quality, normalization, selected ranges, data LOD, transfer functions and random sampling seeds. Repeated runs need reproducible timing/state; bit-identical pixels across GPU drivers are not promised.

If profiling identifies repeated CPU per-particle transforms or styling, evaluate batched buffers and spatial partitioning. Godot's MultiMesh documentation notes all-or-none instance culling and bulk-buffer approaches; do not assume one giant MultiMesh solves every workload. [G3]

Benchmark particle, mesh and volume paths separately and combined. Every performance result includes hardware, driver, resolution, sample sizes, enabled effects, cache state, render mode and source-data storage location. Do not infer speed from final MP4 file size.

Use bounded temporary directories, free-space checks and cancellation. PNG/MP4 cleanup only deletes job-owned generated files after validated success and the user's retention choice. Never delete raw captures. A preview can offer lower quality but must not silently change a final render's recorded settings.

Initial targets: no unexplained greater-than-10% regression on the audited 100k-particle workload; interactive cancellation acknowledged within roughly one second outside a clearly identified uninterruptible engine call; bounded memory over a long seek/playback loop. Targets must be measured locally and revised transparently when unrealistic, not claimed as achieved in advance.

## 13. Scientific acceptance principles

The separate `SIMSCOPE_ACCEPTANCE_MATRIX.md` lists concrete tests. These principles govern all gates:

- Original buffers/captures are immutable inputs; processed views record provenance.
- Direct field samples, Lagrangian tracers, coverage probes, synthetic geometry and derived surfaces have different labels and statistical meanings.
- Compression is tested against decoded original bytes; array shapes and associations are validated independently of visual appearance.
- Integer identity never passes through floating-point conversion.
- Unknown geometry, missing channels and stale time samples are visible states, not silent defaults.
- More visible particles or brighter bloom is not more simulation resolution.
- A rendered smoke test is distinct from parser/API tests and from GPU performance testing.
- Review numerical results independently from visual acceptance. No screenshot certifies conservation or a claimed mechanism.

## 14. Documentation and durable agent handoff

Maintain `docs/CURRENT_STATUS.md` as the single canonical product/gate status with a compact test table, real commands, blockers and the next exact step. Maintain `docs/EVIDENCE_INDEX.md` as the evidence registry, linking gate-specific designs, reports and compact evidence. This supersedes the historical separate implementation-status/next-actions files; do not recreate them. Checkpoint after each tested slice; before stopping, leave a working state or identify precisely what is broken. Never mark a mock-only or headless-only check as a rendered acceptance test.

Update the real API docs and integration guide alongside implementation. Document the scene schema, new stream specification, time/ID semantics, field and mesh conventions, control security, plugin trust model, resource profiles and migration/compatibility matrix. Add dependency licenses and installation instructions for optional components.

If multiple coding agents are available, assign non-overlapping worktrees/files after contracts are agreed. One integrator owns shared schemas and merges. Do not have several agents concurrently rewriting `main.gd` or the binary format. Parallel testing, fixtures and documentation are safer early tasks than parallel architecture redesign.

For each gate report: completed changes; remaining scope; passing/failing/skipped tests; tested dimensions and memory; limitations; reproduction commands; next action. Do not spend the final context window rewriting a long narrative instead of recording a usable checkpoint.

## 15. Deferred scope

Not in this iteration: distributed rendering farms, cloud accounts, public remote access, collaborative editing, arbitrary untrusted code execution, automatic simulation-parameter tuning, probabilistic physics claims, a new fluid solver, a CAD modeling engine, AMR/unstructured-volume rendering, guaranteed real-time millions-of-particles 4K, or a giant camera-keyframe editor. Preserve extension points without implementing all of these preemptively.

## 16. Sources and verification notes

Project sources are supplied snapshots, not a live repository audit. Reconcile their older descriptions against actual code during G0; preserve both the historical record and the verified new state.

- **[P1]** `SIMSCOPE_API.md`, supplied project snapshot: public API, data types, coordinates, mappings and interpolation assumptions.
- **[P2]** `VBC_FORMAT_SPEC.md`, supplied project snapshot: VBCOSM1/SIMSCP1 records, limits, incomplete-tail behavior and versioning rule.
- **[P3]** `IMPLEMENTATION_REPORT.md`, supplied report dated 2026-09-07: original architecture, tests and documented limitations. It predates the reported video-export completion.
- **[P4]** `TASK_Add_professional_deterministic_video_AND_viewer_UX.md` plus the user's subsequent reports: required PNG session-directory behavior, trails default-off, deterministic video export. Requirement documents do not establish test results.
- **[G1]** Godot ImageTexture3D / Texture3DRD, official documentation checked 2026-09-10: `https://docs.godotengine.org/en/stable/classes/class_imagetexture3d.html` and `https://docs.godotengine.org/en/stable/classes/class_texture3drd.html`.
- **[G2]** Godot procedural geometry / ArrayMesh, official: `https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html`.
- **[G3]** Godot MultiMesh optimization, official (page carries an update caveat; benchmark installed version): `https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html`.
- **[G4]** Godot thread-safe APIs, official versioned reference: `https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html`. Check the matching installed-version documentation before implementation.
- **[G5]** Zstandard upstream project: `https://github.com/facebook/zstd`.
- **[G6]** Godot FileAccess and PackedByteArray, official versioned references: `https://docs.godotengine.org/en/4.6/classes/class_fileaccess.html` and `https://docs.godotengine.org/en/4.7/classes/class_packedbytearray.html`. Actual cross-language codec compatibility is a required test, not an assumption.
- **[G7]** MCP transports, official published 2025-11-25 specification checked 2026-09-10: `https://modelcontextprotocol.io/specification/2025-11-25/basic/transports`. Pin a supported negotiated version at implementation time.
- **[G8]** MCP security guidance, official: `https://modelcontextprotocol.io/docs/2025-11-25/tutorials/security/security_best_practices`.

The proposed interfaces, sequence, budgets, schemas and acceptance criteria are design decisions in this document. They are not quoted capabilities of the current project or guarantees from these sources.
