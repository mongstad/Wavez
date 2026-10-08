# G4 acceptance ledger

**Implementation gate: PASS, 2026-09-12; subsequently reviewed and accepted by the user.** G4a–G4f follow
the approved [design](https://github.com/mongstad/Wavez/blob/ca220d30163d4a76efd652933c8c963a564c315d/G4_DESIGN.md). This table uses the canonical
[A01–A23 registry](https://github.com/mongstad/Wavez/blob/ca220d30163d4a76efd652933c8c963a564c315d/SIMSCOPE_ACCEPTANCE_MATRIX.md); no test ID or scientific
requirement was dropped. Earlier checkpoint evidence remains historical.

Python paths below are relative to `tests/`. Native checks are real Godot tests;
actual OpenGL/Vulkan rendering is identified separately from headless execution.
Numerical tests use independent analytic/hand-computed expectations, exact identity
and byte comparisons, and specified floating tolerances. Captures are synthetic.

| ID | Result | Evidence and scientific boundary |
|---|---|---|
| A01 | PASS | `test_picking.py`, `test_selections.py`; 38 native selection/derived checks on each actual renderer. Exact source picks, committed times, clipping/occlusion and combined float32 visibility underflow. No inferred anonymous/artifact identity. |
| A02 | PASS | `test_selections.py`, `test_native_analysis.py`; demo cohort versus spatial box counts. Fixed members and native-time ROI inclusion remain different populations. |
| A03 | PASS | `test_channel_semantics.py`, `test_analysis_quadrature.py`; demo actual-grid mass and tracer-only integral refusal. Tracer sample means are explicitly labeled estimates. |
| A04 | PASS | `test_analysis_quadrature.py`, `test_native_analysis.py`; anisotropic node/cell grids, affine determinant, boundaries and invalid coverage. Independent node/cell mass oracles 72/288; demo whole-grid/lower-cylinder 288/144 kg. |
| A05 | PASS | `test_analysis_reductions.py`, `test_channel_semantics.py`; compensated sums, population variance, exact quantiles, weighted support and signed/integer restrictions. Empty support is explicit. |
| A06 | PASS | `test_diagnostics.py`, diagnostics native/GPU checkpoint; separate CSV axis, units, missing/nonuniform samples, provenance and index-only invalid axes. |
| A07 | PASS | `test_space_time.py`; traveling-pulse position oracle, full spatial bins and native times; final space-time UI on both renderers. Mixed finite/missing preview pixels remain visibly distinct. |
| A08 | PASS | `test_periods.py`; steady, chirped, noisy, flat and short signals, explicit windows/assumptions and refusal reasons. Demo supplied period 2 s. No automatic physical-event claim. |
| A09 | PASS | `test_comparisons.py`, `test_linked_plots.py`, `test_analysis_matched_render.py`; 50 final matched preparation/render checks per renderer plus 11 final native altered-job checks. Shared camera/range and explicit mappings; distinct source identities/raw clocks retained. |
| A10 | PASS | Source checksums checked throughout worker, selection, demo, numerical export, recipe, actual PNG/video and matched runs. Deliberate mutation fixtures verify refusal without additional renderer writes to inputs. |
| A11 | PASS | `test_analysis_source.py`, `test_native_analysis.py`, `test_selections.py`; int64 IDs above 2^53, births/deaths/empty/reordered samples, audit coverage, reuse/duplicate rejection and random seeks. No gap-bridged identity history. |
| A12 | PASS | `test_analysis_source.py`, `test_selections.py`, `test_picking.py`; legacy/SIMSCP1/2/3 anonymous records remain sample-local. Bad time axes are not sorted into invented histories. |
| A13 | PASS | `test_analysis_source.py`, `test_selections.py`, `test_native_analysis.py`; source associations, stable vertex IDs versus ordered-topology interpolation, contiguous face epochs, A→B→A expiry and static geometry. |
| A14 | PASS | `test_selections.py`, `test_derived_selection.py`, `test_analysis_quadrature.py`; actual derived picks on both renderers. Geometry-bound addresses versus fixed probes, invalid corners, exact artifact hash and source provenance. |
| A15 | PASS | `test_native_analysis.py`, `test_comparisons.py`, `test_linked_plots.py`; native observations separate from cursor-held/interpolated support, explicit missing channels/IDs and both comparison brackets. |
| A16 | PASS | `test_analysis_reductions.py`, `test_native_analysis.py`, `test_channel_semantics.py`; original f8/integers, independent interval velocity, exact IDs and precision-sensitive coordinates. No GPU/color readback in analysis. |
| A17 | PASS | `test_picking.py`, `test_selections.py`; actual overlays and hidden-particle performance control. Stored hidden selections retain the optimized hidden path; source membership is independent of later display settings. |
| A18 | PASS | `test_analysis_recipes.py`; final native state/PNG replay, 49 old inspection checks and legacy video equality. Full validation before mutation, exact float/ID tokens, hashed members/results, external input permissions and session-only screenshot destination. |
| A19 | PASS | `test_analysis_worker.py`, 160 foundation checks, lifecycle and render-failure tools. Explicit barriers cover stale work, supersession, cancellation, pressure pause/resume, finite deadlines, crash/close and stuck-child termination. |
| A20 | PASS | `test_analysis_export.py`, `test_analysis_recipes.py`; 44 final PNG/clip checks per renderer, exact delayed/replayed pixels and 20 append/mutate/quota/cancel export checks. Full CSV/support/provenance, pinned extent and explicit partial outputs. |
| A21 | PASS | 235 checks across 30 eviction/seek/scan/export/restart cycles; 100k-particle G3/G4 idle comparison, separate active workloads and original playback profiler. Finite source/cache/workspace/result/overlay quotas, no worker orphans or scientific subsampling. See measured limits below. |
| A22 | PASS | 225 Python tests without skips, 2,457 G3 playback checks, explicit playback lifecycle and actual legacy video equality; relevant retained G3 storage/render and legacy video continuation checks. Formats, selective checksum validation and source mutation/append distinction remain. |
| A23 | PASS | `test_selections.py`, `test_member_assets.py`, `test_native_analysis.py`, `test_analysis_recipes.py`; deterministic set edits/revisions, deduplicated compatible groups, mixed-series separation and full exact member assets within quotas. |

## Gate evidence and reproduction

[Gate evidence](evidence/g4f/gate.json) records commands, counts, source preservation,
runtime versions, final source hashes and failed-attempt qualifications.
[Performance evidence](evidence/g4f/performance.json) records bounded summaries,
source identities, exact baseline revision, worktree code hashes, renderer/device,
resolution, intervals and separate callback/cache/RSS/worker/GPU measurements.
Large captures, images, traces and generated exports remain ignored under `results/`.

Use `python -m unittest discover -s tests -q` with the optional surface dependency
installed. Run `python -m examples.g4_demo --output NEW_DIRECTORY` for the
self-contained demo and independent mass/period oracles. Native tools accept
`--godot /absolute/path/to/godot` and fresh output directories:

- `tools/validate_analysis_foundation.py`, `tools/validate_selections.py --derived`,
  `tools/validate_space_time.py`, `tools/validate_g4_render.py`,
  `tools/validate_g4_matched.py`, `tools/validate_g4_render_failures.py`.
- `tools/validate_g4_lifecycle.py` runs the eviction-heavy worker loop.
- `tools/profile_g4.py` archives the `pre-g4-consolidation` Git tag only into a
  temporary directory, then compares identical synthetic 100k workloads.
- `tools/profile_g4_workloads.py` uses that capture and the demo for separate
  overlay, ID trace, export, paused ROI and cold/held-layer seek workloads.
- `tools/validate_scene_playback.py`, native
  `layers/test_scene_playback_lifecycle.gd`, `tools/profile_scene_playback.py` and
  `tools/validate_scene_playback_video.py` retain the G3 regression paths. Exact
  generated job parameters are in the evidence. No external solver data is needed.

## Measured limits and deferred scope

The three-repeat idle comparison stayed below the 10% target: maximum aggregate
increase +4.0% on OpenGL and +9.54% on Vulkan (frame-time p95, close to the target).
This is one 100k workload at 960×640 on the recorded workstation, not a universal
FPS guarantee. Full 81-sample ROI statistics while playing took 4.40/4.85 s on
OpenGL/Vulkan; zero ≥50 ms playback callbacks occurred in those runs. Cold seeks
can buffer. Application-cold is distinct from an OS disk-cache flush, which was
not performed. Tiny field/mesh controls do not establish large-volume throughput.

Budgets are allocation/admission limits, not whole-process RSS guarantees. The
512 MiB worker, 2 GiB disposable cache, exact member assets, 64 MiB viewer results
and 16 MiB overlay limits are separate. GPU figures are Godot-reported buffer and
texture estimates. Whole-viewer close includes G3 thread/cache teardown and can
exceed 50 ms; no analysis interval decode/hash/reduction runs in UI callbacks.
CSV/recipe output uses finite quotas and atomic publication. Encoder space checks
do not reserve free disk against other applications.

Portable results and members are hash-validated. Captures/CSVs/derived artifacts
remain external explicit inputs; omitted result assets require the original cache.
The inline space-time preview admits at most 16,384 pixels; full spatial requests
admit at most 16,384 bins. Larger requests refuse explicitly. Matched scenes use
positive affine value scales and declared compatible coordinates; general geometry
registration is deferred. Scientific negative value scales remain available in
numerical comparisons.

G5 local services/MCP/control and command orchestration, G6 automatic event
detection/adapters/release work, dashboards, external simulation work and unrelated
visual changes remain deferred. G4 has no listener or autonomous event workflow.
