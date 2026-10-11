# Current status

Issue #374 proposes candidate **v0.1.0.99**, based on accepted **v0.1.0.98** /
owner-merged PR #376 (`4737019f4ff4050774a8397a450d1ea2e79d2f15`). Forward+ field
slices use explicit eight-texel interpolation for finite neighborhoods. Any
nonfinite corner retains hardware sampling and the existing discard rule;
source probes retain their conservative unavailable-value semantics. Volume
sampling, RF preview geometry/LOD, WVZ1 arrays and scientific measurements remain
unchanged. Owner review is pending. See [accuracy, nonfinite policy, Vulkan
costs and owner checks](FIELD_SLICE_INTERPOLATION.md). Historical review-time
records below and the #360 report are preserved as written.

Issue #367 proposes candidate **v0.1.0.98**, based on accepted **v0.1.0.97** /
owner-merged PR #373 (`c3475573878e7535174b1229b24d35eb6ae82e79`): Particle size
now permits **0.01–8**, retains default **1.8**, and provides logarithmic travel,
an exact numeric readout and thumb-double-click entry with validation/cancellation.
Portable presets and native visual state synchronize the same precise value.
Scientific payloads, additive blending, brightness/exposure/color and renderer
policy remain unchanged. Owner review is pending. See [usage, dense Vulkan
measurements, visibility limits and review steps](PARTICLE_SIZE.md). Historical
review-time records below and the #360 filtering report are preserved as written.

Accepted baseline for this renderer-policy change: **v0.1.0.96**,
`eacdae866b017700e0919b263fdfd04c0f65bc27`, owner-merged PR #370. The repository's application identity is
`viewer/project.godot` → `application/config/version`; see [version policy](VERSIONING.md).

Issue #371 proposes candidate **v0.1.0.97**: **Forward+ Vulkan only**, including
source, standalone Linux and background video workers. Unsupported renderer
overrides are refused, automatic OpenGL fallback is disabled, and Vulkan GPU/driver
requirements are explicit. Owner review is pending. See [renderer policy,
scientific limits and troubleshooting](RENDERER_REQUIREMENTS.md). Historical
Compatibility evidence is preserved; #94 must consume this policy and #362 needs
owner reassessment before any Compatibility-only engine work.

Accepted issue #343 / PR #350 provides concurrent camera roll: existing keys work
concurrently with RMB free-look steering, in either press/release order. Focus,
modal, inspection and LMB guards remain. Bindings, sensitivity and roll/translation
speeds retain their contracts. See [navigation](MANUAL_CAMERA_ORBIT.md) and
[historical review evidence](evidence/issue-343/README.md).

Accepted issue #340 / PR #344 provides independent ordinary Video Export.
File → Export → Video always uses visual version-1 jobs, external FFmpeg and explicitly optional visual records.
Existing selections never trigger scientific recipe processing or Python/NumPy.
Selection highlights and Analysis overlays are excluded from exported frames;
Selection/Analysis, scientific persistence and explicit Matched Views remain
independent. See [video](VIDEO_EXPORT.md), [packaging](PACKAGED_VIDEO_EXPORT.md)
and [historical review evidence](evidence/issue-340/README.md).

Issue #331 provides independently configurable,
initially Unbound Roll Camera Left/Right actions bank Free Camera around its
local view axis while retaining scientific/world state. A shared, persistent
5–90°/second manual roll speed defaults to 18°/second and is staged through the
Keyboard Shortcuts Preferences slider. The full camera basis
continues through movement, steering, framing and saved views; Reset Camera
intentionally restores the default orientation. Configurable Move Camera Up/Down
default to E/Q and transfer conflicts with roll, replacing fixed vertical key
polling while retaining physical W/A/S/D and the existing translation rate.
See [camera navigation](MANUAL_CAMERA_ORBIT.md) and the
[current review evidence](evidence/issue-331/vertical-movement/README.md).

Accepted issue #329 / PR #334 provides File → Close File.
File → Close File returns to the empty viewer and releases capture-exclusive
resources while launched video workers continue. Dependent image, selection,
analysis and matched-view work safely blocks closing with an explanation.
See [Close File](CLOSE_FILE.md) and [review evidence](evidence/issue-329/README.md).

Accepted issue #335 / PR #336 provides focused diagnostic probes and
documentation. The Linux Godot 4.7.2 release template reproduces the root-Window
Popup signal errors independently of Wavez; source/debug runtimes clear the
connections correctly. The existing Close File runtime and release packaging
remain unchanged. Strict release validation still reports the errors and fails.
See [Window signal diagnostics](ROOT_WINDOW_SIGNALS.md) and
[investigation evidence](evidence/issue-335/README.md).

Accepted issue #326 / PR #337: Video Export Start/End controls
and clock readouts no longer generate oversized tooltips. Permanent labels,
precise visible ranges and exact endpoint calculations remain unchanged. The
existing AGENTS rule prohibits adding tooltips without an explicit instruction
for the specific element. See [review evidence](evidence/issue-326/README.md).

Accepted issue #95 / PR #339 provides a three-part
[Getting Started guide](../GETTING_STARTED.md), four small standalone Python
examples and focused source/value/viewer verification. Installation requirements
distinguish Linux standalone viewing from Python generation and source development.
See the original [review evidence](evidence/issue-95/README.md), preserved as written.

The GitHub Issues and Wavez Development Project are the operational queue. Work
requires a Ready issue (or explicit owner authorization), the correct branch/base
and one owner-reviewed PR. A merge does not authorize the next issue. See
[AGENTS.md](../AGENTS.md) and [the UX workflow](UX_WORKFLOW.md).

## Supported sources and workflows

Wavez records particles, meshes and uniform-grid scalar fields and opens their
independently sampled layers in the Godot desktop viewer. New work uses
**WVZ1 `.wvz`**, `SceneCapture` / `SceneReader`. Retired capture generations are
unsupported; filenames cannot convert their payloads. Captures, simulations and
research results remain external to this repository.

The current shell provides command menus, a Particles / Fields / Meshes Simulation
panel, focused Tools, recorded-time playback, status/Jobs and Fullscreen edge
reveal. Opening presents the first usable sample paused while bounded preparation
continues. Preferences include editable shortcuts, LMB-only vertical inversion,
File Locations and performance preparation controls. Current RMB free-look
steering remains independent of LMB inversion and held target-relative orbit.
Held local-axis roll is available without changing existing defaults.

Scientific inspection/analysis operates on original typed source arrays and
object-native clocks. Exact IDs, anonymous row limits, topology epochs, units,
missing support and provenance remain explicit. Portable view presets are
presentation state; inspection bundles include scientific requests/assets.
Image, video and numerical exports have distinct composition, timing and source
binding contracts. Deterministic video uses a separate real-GPU worker and
explicit sample/surface/render barriers; selection barriers apply only to explicit
scientific Matched Views.

## Current sources of truth

| Responsibility | Contract / guide | Authoritative implementation |
| --- | --- | --- |
| Supported format and wire | [Policy](CAPTURE_FORMAT_POLICY.md), [WVZ1 wire](WVZ1_FORMAT.md) | `wavez_export/scene.py`, `viewer/layers/scene_reader.gd` |
| Python capture API and integration | [Getting Started](../GETTING_STARTED.md), [API](../WAVEZ_API.md), [examples](SCENE_CAPTURE_GUIDE.md), [integration](SIMULATION_INTEGRATION_GUIDE.md), [Quickstart](../QUICKSTART.md) | `wavez_export/`, `examples/` |
| Representation and scientific limits | [Format/API overview](CAPTURE_FORMAT_AND_API.md), [handbook](WAVEZ_HANDBOOK.md) | `viewer/layers/`, `viewer/scene/` |
| Inspection and portable state | [Inspection](../INSPECTION_STATE.md), [view presets](WAVEZ_VIEW_PRESETS.md) | `viewer/scene/`, `viewer/analysis/inspection_v3.gd` |
| Selection and numerical analysis | [Scientific contract](SCIENTIFIC_ANALYSIS.md), [schemas](ANALYSIS_SCHEMAS.md), [user guide](ANALYSIS_GUIDE.md), [acceptance criteria](SCIENTIFIC_ACCEPTANCE.md) | `wavez_export/analysis/`, `viewer/analysis/` |
| Image and deterministic video | [Image](IMAGE_EXPORT.md), [video](VIDEO_EXPORT.md), [Linux package](PACKAGED_VIDEO_EXPORT.md) | `viewer/video/`, `viewer/scene/inspection_state.gd`, `tools/package_linux.py` |
| Playback preparation and memory | [Rolling cache](ROLLING_PLAYBACK_CACHE.md), [dynamic fields](DYNAMIC_FIELD_PREPARATION.md), [particles](PARTICLE_CACHE_CAPACITY.md), [meshes](MESH_PREPARATION_BUDGET.md), [metadata](WAVEZ_METADATA_BUDGET.md) | `viewer/layers/`, `wavez_export/metadata_budget.py` |
| Shell, UX and tools | [Handbook](WAVEZ_HANDBOOK.md), [UX workflow](UX_WORKFLOW.md), [Tools audit](TOOLS_FUNCTIONAL_AUDIT.md) | `viewer/ui/`, `viewer/ui/shell/` |
| Navigation and preferences | [Camera](MANUAL_CAMERA_ORBIT.md), [LMB inversion](LMB_Y_INVERSION.md), [shortcuts](KEYBOARD_SHORTCUTS.md), [File Locations](FILE_LOCATIONS.md) | `viewer/main.gd`, `viewer/ui/` |
| Supported renderer and startup | [Vulkan requirements](RENDERER_REQUIREMENTS.md) | `viewer/project.godot`, `viewer/renderer_policy.gd`, `viewer/video/render_job.gd` |
| Developer validation and packaging | [Contributing](../CONTRIBUTING.md), [version policy](VERSIONING.md), [scientific criteria](SCIENTIFIC_ACCEPTANCE.md), [evidence index](EVIDENCE_INDEX.md) | `tests/`, `tools/`, native test scripts in `viewer/` |

## Scientific and resource boundaries

There is at most one particle object per capture, one active translucent volume
and one derived isosurface; multiple meshes/slices are supported. Source arrays
and numerical probes retain scientific precision. GPU previews use float32 and
may reduce resolution under admission limits; derived surfaces are approximate
level sets with no inferred material identity. Scalar/category/phase channels
hold rather than acquiring unrequested temporal interpolation.

Particle/field/mesh CPU preparation is bounded and asynchronous; graphics uploads
remain main-thread work. Cold opening, uncached seeks, explicit inspection/export
and large uploads can still wait or stall. Prepared playback may buffer when
production, source changes or memory admission cannot sustain demand. Analysis
pauses during playback underflow. Allocation/cache/worker/GPU budgets are separate
charges, not whole-process RSS/VRAM guarantees. Workload-specific historical
measurements do not certify universal frame rates or simultaneous heavy CuPy/viewer
contention.

No AMR, automatic vector-basis transformation, exact field reconstruction from
tracers, arbitrary transparent-volume compositing, background archival queue,
writer resume or per-record fsync guarantee is implemented. Automatic event
inference, local services/MCP, browser dashboards, remote/network clients and
new extension architectures remain separately authorized work. The historical
G0–G4 acceptance establishes its declared baseline; G5/G6 are unimplemented.

## Documentation and review records

[The documentation audit](documentation-audit/README.md) maps every tracked
Markdown/documentation artifact, retirement decision and surviving contract.
[The evidence index](EVIDENCE_INDEX.md) retains recorded tests, failures, limits,
screenshots and review-time wording. A historical “pending owner review” describes
that report's original state; it is not the current Project status. Old source
paths/commands in frozen records are provenance and must not be used as current
instructions. Retired documents remain accessible through their accepted Git
permalinks. Current guides above govern supported workflows.

[Public README #94](https://github.com/mongstad/Wavez/issues/94) remains a separate
issue from [Getting Started #95](https://github.com/mongstad/Wavez/issues/95).
Preparing documentation does not authorize publication or repository
administration changes.

## Licensing and release boundary

Original Wavez material uses [PolyForm Noncommercial 1.0.0](../LICENSE);
[third-party terms](../THIRD_PARTY_LICENSES.md), [branding](../TRADEMARKS.md) and
[repository provenance](../PROVENANCE.md) retain their distinct ownership.
Godot and FFmpeg remain external, unvendored dependencies. Before any separately
authorized public release/distribution, review contributor/copyright/license
ownership, repository contents and the exact bundled artifacts' notice/source
obligations. No release/tag or distribution approval follows from this cleanup.
