# Post-G4 maintenance record

The later accepted PERF-001/002 pass is recorded separately in the
[performance maintenance report](PERFORMANCE_MAINTENANCE_REPORT.md), and accepted
PERF-003 in the [mesh playback maintenance report](MESH_PLAYBACK_MAINTENANCE_REPORT.md).
This page retains the earlier documentation/UI/format maintenance evidence.

Completed 2026-09-12 against accepted G4 baseline `58e3d961d72bb2b6956c464465aae195b34a266a`.
All four items are recorded as reviewed and accepted in the workspace
`SIMSCOPE_MAINTENANCE_TODO.md`. This report retains their implementation evidence.
No G5/G6, web/dashboard, external simulation or unrelated rendering work was started.
Package version remains `1.0.0`. The original 15 untracked layer UID files are preserved.

## Completed items

| ID | Result | Changes |
|---|---|---|
| DOC-001 | Complete | Modern public API, executable integration examples, current G4 status, dependencies, units, cache and saved-state contracts reconciled with source; historical reports clearly scoped. |
| UI-001 | Complete | Reproduced the lower-right `fixed` label. Fixed/direct RGB modes now have neither scalar legend text nor colorbar; scalar legends and their visibility controls remain. |
| UI-002 | Complete | Reviewed all six G4 panels and three plot components. Shorter actions, scientific tooltips and expandable groups make common actions easier to find. Normal-resolution and exact 4K GPU layouts checked. |
| ARCH-001 | Complete | One [capture format policy](CAPTURE_FORMAT_POLICY.md) makes `.ssc` / SIMSCP3 the target for new work and freezes VBCOSM1/SIMSCP1/SIMSCP2. The file picker presents the modern scene format first. |

## Documentation audit

The [public Python API](../WAVEZ_API.md) now exposes `SceneCapture` and
`SceneReader`, per-object sample indexes, exact bracket tuples, identity audits,
source probes, source types, writer refusal/recovery, dependencies and limits.
Retired signatures/examples are outside the supported source snapshot.
No API, source format, writer default or numerical algorithm changed.

Corrected the integration examples to use the keys actually recognized by G4:
`time_unit`, `position_unit`, `channel_metadata[object_id][channel]`. Arbitrary
`time_units`/`coordinate_units`/`channel_units` aliases do not declare G4 units.
Examples preserve amplitude-squared density as such; they do not relabel it as mass.
All three modern examples execute and their G4 unit interpretations are checked.

Current entry points reviewed: README, Quickstart, AGENTS, CONTRIBUTING, viewer
README, Start Here, Current Status, handbook, public API, format/API overview,
integration guide, G3 guide, G4 guide, legacy dependency notes and format policy.
Versioned contracts reviewed: VBC/G2b/G3 formats, inspection v1/v2 with the G4 v3
extension, video v1 with the G4 v2 extension, G4 design/schemas, roadmap and
acceptance registry. The handbook now distinguishes pinned v3 append behavior
from older recipes and the bounded G4 result cache from the G3 surface cache.

Historical G2 storage, playback, G3 and G4 reports retain their original findings,
limits and checkpoint results. Explicit banners resolve obsolete development-copy
or future-G4 statements. Moved source links are repaired; bulky artifacts removed
at consolidation are named as external archive references. Cleanup/boundary,
experiment lessons, numerical-validation guidance, retained-evidence pages and
fixture attribution were also reviewed. No external simulation was opened or rerun.
The complete Markdown inventory and local-link check are recorded in
[validation.json](evidence/maintenance/validation.json).

## UI behavior and scientific distinctions

The orphan label originated in the particle `legend` Label created by
`main.gd::_build_inspector`, positioned by `_layout_inspector`. The non-scalar
branch of `_update_particle_legend` displayed the internal color-mode name;
`_toggle_overlay` could restore its visibility independently. Both paths now use
the scalar-only visibility rule. This intentionally changes rendered UI pixels
for fixed/direct RGB modes; numerical values and scalar ranges
are unaffected; source data remains unchanged. The shared legend path also receives compatibility coverage.

The six panels keep their existing top-level names because recipes serialize those
section keys. Nested groups are presentation only and do not enter recipes or
analysis requests. Existing signals, option indexes, numeric defaults, source
bindings and validation remain intact. Labels wrap; button and menu text have
full-text tooltips within the existing resizable inspector.

| Panel | Organization |
|---|---|
| Selections | Pointer/name/list first; editing, typed IDs/regions, surfaces/cohorts and groups expand separately. Value filters are Advanced. |
| Temporal analysis | Population, operation, range/channel and Run analysis remain primary. Weights, units, physical declarations, gaps, incomplete subtotals and exact member lookup are Advanced. |
| Diagnostics and comparisons | Shared series/bookmark name remains visible. Import CSV, Compare series, period estimates and manual bookmarks expand separately; CSV parsing and sampling assumptions are Advanced. |
| Space-time analysis | Source axis, bins and coordinate choices remain primary; tracer-weight interpretation is Advanced. |
| Analysis export and state | Export/save/load/recompute remain primary; finite output limits and exact-member inclusion are Advanced. |
| Matched runs | Input selections, common coordinates/units/range and prepare/render actions remain available; per-input mappings and video/output limits expand separately. |

Tooltips retain exact decimal IDs, world versus object-local coordinates,
fixed cohorts versus spatial regions, source versus display filters, native versus
scheduled comparison times, explicit resampling, incomplete finite support and
original-grid versus tracer estimates. Plot axes show Recorded time/Sample index/
Time lag where appropriate; numerical rows and export provenance retain their exact
machine-readable fields. No physical identity, values or automatic events are inferred.

## Validation

Godot 4.7.2 (`ed1daf0bf`), NVIDIA RTX 3070 Ti / driver 610.57.04, Python 3.14.7,
NumPy 2.4.3. Small synthetic fixtures only. Commands, source hashes, code hashes,
image dimensions/hashes, logs and detailed results are in
[compact evidence](evidence/maintenance/validation.json).

| Check | Result |
|---|---|
| Modern API/integration examples and G4 unit interpretation | 3 examples PASS; source hashes unchanged |
| Repository Markdown links | PASS; no missing local link targets |
| Maintenance UI behavior, headless | 28 checks PASS |
| Maintenance UI, OpenGL Compatibility and Vulkan Forward+, 1440×900 | 36 checks PASS on each renderer |
| Maintenance UI, exact 3840×2160 GPU SubViewport, both renderers | 36 checks PASS on each renderer |
| Selection integration | 31 checks PASS |
| Temporal analysis integration | 23 checks PASS |
| CSV/diagnostic/comparison integration | 23 checks PASS |
| Space-time, numerical export and durable recipe integration | 36 checks PASS |
| Existing G1 inspection/mapping/state compatibility | 49 checks PASS, headless |
| Existing G4 selection PNG/video, delayed render and sidecar replay | 44 checks PASS, actual OpenGL |
| Existing matched preparation, sequential rendering and independent clocks | 50 checks PASS, actual OpenGL |

UI checks exercise F1 and legend preferences; collapsed/expanded widths across all
six panels; reachable primary actions; unchanged saved settings/ID input; and no
analysis worker started by presentation changes. Images were inspected for legible
controls and clipping. The desktop capped the requested 4K window at 2179×1362;
that attempt was **not** counted as 4K. The accepted 4K check uses an exact real GPU
SubViewport with the existing deterministic-export canvas scaling (1440×810).
It establishes 4K rendered layout, not behavior on a physical 4K monitor or every
operating-system DPI scale.

The first headless legend test asserted before asynchronous styling completed;
the corrected test waits for the committed sample. Initial concurrent sandbox
integration attempts failed while sharing the private cache. PID-namespace owner
cleanup is the suspected cause; sequential runs passed without product changes.
Those attempts are retained as failures, not counted as acceptance. Run worker
integration checks sequentially when sandbox invocations have separate PID namespaces.
No whole-G4 performance gate or external scientific workload was repeated.

Reproduce with fresh output directories:

```sh
python tools/validate_documentation.py --output-dir results/check-docs
python tools/validate_maintenance_ui.py --godot /path/to/godot --output-dir results/check-ui
python tools/validate_maintenance_ui.py --godot /path/to/godot --renderer gl_compatibility --resolution 3840x2160 --output-dir results/check-ui-4k
python tools/validate_temporal.py --godot /path/to/godot --output-dir results/check-temporal
python tools/validate_diagnostics.py --godot /path/to/godot --output-dir results/check-diagnostics
python tools/validate_space_time.py --godot /path/to/godot --output-dir results/check-space-time
python tools/validate_g4_render.py --godot /path/to/godot --renderer gl_compatibility --output-dir results/check-render
python tools/validate_g4_matched.py --godot /path/to/godot --renderer gl_compatibility --output-dir results/check-matched
```

Local screenshots/logs remain under `results/maintenance/` and are reproducible;
large generated captures, caches and movies are excluded from Git. Resource policy,
scientific defaults and accepted G0–G4 limits are unchanged. This is a maintenance
review checkpoint, not authorization to begin G5.
