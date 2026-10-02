# Current status

Issue #176 shares the About six-pixel outer radius across current custom dialog
surfaces, fixes the About header/body seam, and rounds visible shell chrome only
in normal windowed mode. Internal scientific viewport joins stay square; cached
styles suppress shell rounding when maximized/fullscreen. Candidate build 19 is
**pending owner review**. See [behavior, evidence and owner checks](ROUNDED_SURFACES.md).

Issue #180 removes the visible WAVEZ label from the main shell top bar.
Frame scene, Reset camera and Navigate now start at the existing left margin;
menus, pin/window controls and blank-area window dragging retain their paths.
Candidate build 18 is **pending owner review**. Both renderers and Linux release
packages passed existing regressions; physical 4K/KDE review remains required.
See [validation and exact owner checks](evidence/issue-180/README.md).

Issue #175 adds **Edit → Preferences → Keyboard Shortcuts**, replacing the Help
shortcut list with a compact custom violet editor. Captured bindings are staged;
duplicates unbind their previous action, Cancel discards edits, and Apply saves
and activates them immediately while keeping the editor open. A shell-styled X
silently discards unapplied edits and closes the editor. Apply stays disabled until
the draft differs from the active bindings, including after reverting all edits. Preferences remain
outside scientific/session and export state. Candidate build 17 is **pending owner review**. See
[behavior, validation and owner checks](KEYBOARD_SHORTCUTS.md). Earlier review-time
reports and evidence below retain their original wording.

Issue #151 removes the redundant instruction above the empty viewport’s
**Open capture** button and centers the button in the available scene area.
Capture opening is unchanged; candidate build 16 is pending owner review.

Issue #171 replaces Help → Handbook with **About WAVEZ → Documentation**,
opening the repository README. The normal repository link and shared Details
surface remain. This navigation change is pending owner review; repository
documentation and version/license/runtime information are preserved. See the
[navigation validation and owner checks](ABOUT_DOCUMENTATION_NAVIGATION.md).

Issue #160 removes Quick setup and its Tools menu entry, pending owner review
(candidate build 15). Field/channel controls, Derive range percentile inputs,
manual color/opacity mappings, scene/portable view presets and reusable volume
preset calculations remain. See [dependency audit and owner checks](QUICK_SETUP_REMOVAL.md).

The owner merged final UX3 validation in PR #64, the [UX4 design](UX4_DESIGN.md)
in PR #72, and [command menus](UX4_MENUS.md) in PR #73 at `3dddf71`.
The category simulation panel was owner-merged in PR #75 at `b2f0384`.
Focused scientific tools were owner-merged in PR #76 at `28b5358`.
Video export progress details were owner-merged in PR #87 at `7e656e2`.
Fullscreen window-state restoration was owner-merged in PR #88 at `f74a11f`.
Simulation-panel launch defaults were owner-merged in PR #89 at `a3c6c50`.
Video export dialog actions were owner-merged in PR #90 at `a6a34c5`.
Independent legend visibility and placement were owner-merged in PR #91 at `d11e426`.
Independent layer legends were owner-merged in PR #92 at `9774623`.
Adaptive field preparation capacity was owner-merged in PR #99 at `d42a4dc`.
Continuous SSC playback preparation was owner-merged in PR #101 at `573c097`.
SSC generation and adaptive playback caching were owner-merged in PR #103 at
`6d4df9a`. Playback integrity policy was owner-merged in PR #108 at `d9876ee`.
Bounded parallel field preparation was owner-merged in PR #110 at `7dc253e`.
Dynamic field preparation was owner-merged in PR #113 at `0b3d3b4`.
Paused rendering was owner-merged in PR #119 at `788de5d`.
Current video-export regression and startup corrections were owner-merged in
PR #122 at `f867248`. Export-setting locks and active-job actions (#125) were
owner-merged in PR #126 at `e26af1e`. Compact legend content (#115) was
owner-merged in PR #127 at `2c3678a`. Unified playback/preparation status (#114)
was owner-merged in PR #129 at `309ec00`. Rolling cache, prepared timeline and
adaptive runway corrections were owner-merged in PR #130 at `fb75c8c`.
Application version/build identity was owner-merged in PR #132 at `653f817`.
About SimScope was owner-merged in PR #133 at `f6191e0`.
Load-error recovery was owner-merged in PR #134 at `a97af18`.
Hidden legend defaults were owner-merged in PR #137 at `26b6800`.
Portable view presets were owner-merged in PR #139 at `b6008e0`.
Video cancellation confirmation was owner-merged in PR #140 at `dd706ca`.
Timeline endpoint alignment was owner-merged in PR #141 at `e11ea58`.
Pinned edge reveal and simulation-only Fullscreen (#117) were owner-merged in
PR #142 at `b33e9a8`. Capture and video file-dialog preferences (#50) were
owner-merged in PR #144 at `61f6a78`, accepted build 9.
The violet visual-system slice (#143) was owner-merged in PR #145 at `d23f431`,
accepted build 10. Its [review reports](UX5_STYLE_SLICE.md) and Round 1–4 evidence
retain their original review-time wording. Residual UI cleanup (#147) was
owner-merged in PR #148 at `1a60774`, accepted build 11. Its
[review report](UX5_CLEANUP.md) retains its original review-time wording.
Repositioning the existing orbit center/radius (#120) was owner-merged in PR #152
at `f82a939`, accepted build 12. Its [review report](ORBIT_CENTER.md) and earlier
custom-orbit report/evidence retain their historical review-time wording.
File → Exit (#153) was owner-merged in PR #154 at `d6e4bd8`, accepted build 13.
Its [review report](EXIT_MENU.md) retains its original review-time wording.
Current authorized work is #155, the sole Ready issue when selected on 2026-10-01:
[WAVEZ branding migration](BRANDING_MIGRATION.md), **pending owner review**,
candidate build 14. The application is WAVEZ (Wavez in ordinary prose).
Current Python imports use `wavez_export`; capture/schema identifiers and saved
preferences retain their established contracts. The owner will rename the GitHub
repository after this task; existing URLs and the local checkout path remain valid.

The historical checkpoints below retain the product name used at the time.
For current branding, package names and commands, use the migration guide,
[handbook](SIMSCOPE_HANDBOOK.md), and [Python API](../SIMSCOPE_API.md).

Particle Filters retain membership
semantics with violet checkboxes; immediate boolean controls share violet switches,
including rebuilt Fields/Meshes and Tools controls. **File → Details…** opens the
existing source/status surface, retaining full paths and diagnostics. The top Source
icon, passive bottom filename and persistent bottom Details action are removed.
About uses the unchanged owner-supplied violet logo. Scientific behavior, saved
state, dropdown styling, #117 edge/fullscreen and #118 redraw contracts remain intact.
Ordinary recipe save/load uses a small source-independent presentation JSON and
direct platform file picker. Scientific inspection bundles remain separate.
Field preparation uses a small CPU pool with ordered publication and explicit
in-flight memory reservations. Auto starts conservatively and changes active
concurrency within a CPU-count-bounded pool of at most four lanes, using measured
preparation demand and resource pressure. `SIMSCOPE_FIELD_WORKERS=1..4` selects a
fixed diagnostic cap. Playback reuses contiguous prepared coverage and waits for
an adaptive startup/resume runway: three seconds with measured faster production,
eight near parity, otherwise the admitted window. Predicted depletion triggers
intentional buffering before the lead is exhausted. Automatic windows reclaim eligible history before retrying
physical admission, while protecting current/staged samples. A single overlay in
the playback slider shows actual prepared coverage for fields and visible layers.
The adaptive cache and [interactive integrity policy](PLAYBACK_INTEGRITY.md) remain intact.
Interactive reads skip payload SHA recomputation while preserving structural,
descriptor/commit, decode and source-change checks. Readable scientific corruption
may be missed during playback; explicit full verification, Python analysis and
offline exports retain strict checking. SIMSCP4 and #103's cache policy are unchanged.
Lazy opening is retained. [Adaptive playback caching](SSC_ADAPTIVE_CACHE.md) now
prepares forward automatically within current physical-RAM capacity. Scrubs reuse
overlapping samples and prioritize missing targets; manual intervals remain advanced
options. Compatible channel changes reuse validated source arrays. SIMSCP4 requires exact field statistics and
contiguous array chunks; package 3.0.0 refuses old capture formats without fallbacks.
The external S0 run stopped on the previous format's descriptor ceiling. Its exact
recorded prefix now needs 2.70 MB of descriptor charge rather than 33.55 MB.
The inherited aggregate export ceiling is now removed; [reader metadata budgets](SSC_METADATA_BUDGET.md)
separate resource admission from SIMSCP4 validity. Above-boundary native/Python
validation preserves per-record limits, checksums and scientific values.
Strict 33.3 ms pacing and indefinitely uninterrupted playback when decoding is
slower than consumption remain unestablished; this is not a universal smoothness claim.
The owner-confirmed 13.86 GiB capture records 128³ fields. Normal opening now
indexes bounded record headers and loads the first visible scene; requested
records are validated and decoded on demand or within bounded background windows.
Automatic particle preparation no longer preloads the full timeline or gates the
first usable scene. Exact identity-map reuse and native descriptor predicates
remain from the initial profiling change. Comprehensive verification is explicit
through `python tools/verify_ssc.py CAPTURE.ssc`.
Historical reports and evidence retain their original review-time wording.

As of **2026-09-20**, including G4 and PERF-001/002 maintenance reviewed and accepted by the user. Scientific simulations were not rerun. Historical results identify their recorded checkpoints. PERF-003 mesh maintenance was also reviewed and accepted by the owner on 2026-09-13; implementation checkpoint `7974c78`.

| Area | Current state |
|---|---|
| Authoritative viewer/exporter | `SimScope/` |
| Repository boundary | SimScope product code/docs/tests only; scientific simulations and research data are external |
| Preferred new capture workflow | Explicit `SceneCapture` / `SceneReader`, **SIMSCP4**, normally `.ssc` |
| Capture contract | SIMSCP4 / `.ssc` only; package 3.0.0, clean format break under #102 |
| G0–G3 | Implemented: inspection, bounded storage/cache, typed identities, independent particle/mesh/volume layers, rendering and export |
| Latest maintenance | PERF-003: bounded mesh preparation/prefetch and GPU position interpolation complete; reviewed and accepted by the owner (2026-09-13). [Mesh maintenance report](MESH_PLAYBACK_MAINTENANCE_REPORT.md). PERF-001/002 remain accepted: [report](PERFORMANCE_MAINTENANCE_REPORT.md). |
| G4 | Implemented through G4f; A01–A23 PASS for declared fixtures and measured workloads. Accepted by the user. [Report](../G4_REPORT.md), [acceptance ledger](G4_ACCEPTANCE.md), [guide](G4_GUIDE.md). |
| G5 | Local control/optional MCP: **NOT IMPLEMENTED / NOT STARTED** |
| G6 | Events, broader adapters and release work: **NOT IMPLEMENTED / NOT STARTED** |

The slider bug was reproduced on independent particle/volume cadences and a retained external layered capture: the union clock grew while the slider maximum stayed stale. The fix updates the range. The slider continues to represent **union sample index**, including in Physical-time mode. It does not represent a continuous percentage of physical elapsed time. The new regression passed 28 checks on each renderer and 25 on the actual capture; relevant G1–G3 regressions passed.

The prior investigation associated all **113 callbacks above 50 ms** with particle source-pair changes, while the nominal one-second tail poll stayed below 3.1 ms. The focused optimization now skips unneeded hidden-particle work and prepares visible particle pairs on a CPU worker. On the exact retained `complete.ssc`, median visible transitions fell from **177–181 ms to about 20 ms**, and hidden transitions to about 2.6 ms. Both renderers had zero ≥50 ms callbacks in the final matrix and longer replenishment, 2× speed and loop controls. Cold startup and uncached seeks explicitly buffer; they do not synchronously rebuild the pair on the UI callback. All **3,168 regression checks and 122 performance assertions passed**, including deterministic visible/hidden video equality. These are retained historical measurements; current maintenance reports supersede the old investigation files.

Automatic particle buffering uses a rolling cache capped at 2 GiB and physical-RAM headroom, with up to eight requested pairs. First display and controls do not wait for that window. Uncached seeks wait only for the requested samples and retain the last committed scene. Fields automatically fill a RAM-bounded window while paused or playing, retain overlapping prepared samples on scrubs, and prepare missing targets first. Explicit interval preparation is an advanced option; meshes retain at most four future pairs. Both keep one staged GPU resource per visible layer. Later structurally malformed or undecodable requested records pause playback and identify their object, sample and record. The [lazy loading report](SSC_LAZY_LOADING.md) supersedes the startup policy described in the historical [maintenance report](PERFORMANCE_MAINTENANCE_REPORT.md).

Representative external captures informed G3 timeline/playback validation. Scientific interpretation remains outside SimScope and is not a product result or dependency.

## Capture contract cleanup — accepted

Older capture writers/readers and public API entry points were retired before the UX milestones. The active product contract is SIMSCP4 / `.ssc` only; replacement coverage uses repository-owned native scenes and synthetic fixtures.

## UX1 and UX2 — accepted; UX3 final integration pending review

The [UX1 report](UX1_REPORT.md) records the current UI inventory, observed layout
problems, technical coupling, proposed information hierarchy, concrete design
tokens and reusable component contracts. The [design specification](UX1_DESIGN_SYSTEM.md)
and [regression workflow matrix](UX1_REGRESSION_WORKFLOWS.md) use the accepted
SIMSCP3 implementation as their baseline. Product UI, rendering, storage and
scientific code are unchanged. Native audit evidence includes combined layers,
exact-ID selection, population analysis, dialogs and scaled layouts.

The owner accepted UX1 on 2026-09-13 at `229d4ea91b0b55e6c151b1a58ae15b59fdcdcbd5`.
The implementation report and evidence retain their original review-time state.
The owner subsequently authorized UX2. The [UX2 report](UX2_REPORT.md) records the
completed opt-in theme, primitive component library, bundled numeric font and UI
Laboratory, with native state/scaling/numeric/contrast validation and production
snapshot/pixel/source isolation evidence. [Theme documentation](UX2_THEME_LIBRARY.md)
records the measured widget metrics and proposed adjustments for review.
The owner reviewed and accepted UX2 on 2026-09-13 at
`5fae711aa042d16a72ce4e6283e030aa69a32097`. Its milestone report and retained
evidence preserve their original review-time state.
The owner merged the design package in PR #39 and placed #41 in Ready.
The shell and transport were owner-merged in PRs #45 and #47.
Status/Jobs and media timing were owner-merged in PRs #48 and #51.
Transient seek status, immersive fullscreen, production-shell overlay exports and
left-panel cleanup were owner-merged in PRs #57, #58, #60 and #63. The #44
[integration report](UX3_REPORT.md) is pending owner review. UX4 remains separately
gated under the [UX plan](../UX_IMPLEMENTATION_PLAN.md). Historical reports retain
their original review-time wording and have not been relabeled as fresh #44 runs.

## RENDER-001 — accepted

Issue #3 separates the Point rendering checkbox and `V` shortcut from viewing
preset environment changes. Particle representation can now change while the
selected preset, background, starfield, fog, bloom and exposure remain intact.
Selecting a viewing preset still applies its existing defaults. Visual recipes
retain their existing state format; restoring a recipe also restores Bloom
control availability from its saved environment rather than particle style.

Focused Scientific/Cinematic coverage checks both particle styles, checkbox and
keyboard actions, shader state, and visual-state round trips. Owner acceptance
should verify these combinations on a particle capture, including saving and
reloading a recipe. This maintenance does not authorize further queued work.

## STATE-001 — accepted

Issue #21 corrects recipe/control synchronization and preserves session probe
inputs/results and layer-settings disclosures during restoration. Partial
environment/guide dictionaries preserve omitted live values without applying
preset defaults. Complete v2/v3 state formats and legacy video-job defaults are
retained. [Recipe ownership and investigation](../INSPECTION_STATE.md) documents
the reproduced defects, intentionally persisted settings, session-only fields,
and focused repeated-save/load regression. The owner's original combination of
unexpected settings was not available; these are independently reproduced fixes.

## UX-STYLE-001 — accepted

Issue #5 refines the opt-in shared theme and UX2 laboratory with Midnight
Scientific blue-black surfaces and sparse blue/purple/teal identity marks.
Compact typography and control metrics remain unchanged. Production UI and
scientific rendering consumers remain isolated. Native Godot 4.7.2 Forward+
validation on NVIDIA RTX 3070 Ti passed 1,182 checks, 79 contrast pairs, 300
float64 oracle cases, six viewer-isolation checks and six HUD cases. The
16 size/scale combinations include 100%, 125%, 150% and 200% and a 4K
SubViewport, not physical-monitor acceptance.

[Review screenshot](evidence/issue-5/controls.png) and
[validation summary](evidence/issue-5/summary.json) retain the focused evidence.
The first sandboxed import failed on local socket creation; the authorized
native rerun passed with clean logs. Compatibility renderer, physical 4K,
mixed-monitor and long-session comfort checks were not run. Owner review
should inspect the laboratory pages, focus/hover/disabled/error states and
readability at the preferred desktop scale. Gradients, tier families, broader
document reconciliation and UX3 remain separate work.

## UX-STYLE-002 — accepted

Issue #6 adds an opt-in `AtmosphericSurface` shared theme variation and applies
it to the UX2 laboratory root. A static opaque diagonal blue-black gradient
adds restrained background depth; ordinary controls and diagnostic panels
retain flat surfaces. No production viewer or scientific renderer is changed.
The design guidance permits this bounded use without authorizing UX3.

Godot 4.7.2 Forward+ on NVIDIA RTX 3070 Ti passed 1,325 native checks,
198 contrast pairs (including 17 gradient samples), 300 float64 oracle cases,
six viewer-isolation checks, six HUD cases and 16 size/scale combinations.
Import and logs were clean; validation preserved source files.
[Review screenshot](evidence/issue-6/controls.png) and
[summary](evidence/issue-6/summary.json) retain focused evidence.
Physical 4K/mixed-monitor, compatibility renderer, historical baseline and
long-session comfort checks were not performed. Owner review should confirm
that the background depth is noticeable but quiet, with no distracting banding,
and that labels, diagnostics and focus states remain readable at their normal
scale. Production captures should retain their previous appearance.

## UX-STYLE-003 — accepted

Issue #7 adds five separate UI tier tokens and compact Label variations for
Low / Medium / High / XHigh / Max. The laboratory Tiers page pairs labeled,
ordinal examples with independent operational status icons/text. Panels remain
neutral; scientific colormaps and production consumers are unchanged.

Godot 4.7.2 Forward+ validation passed 1,366 native checks, 218 contrast pairs,
300 float64 oracle cases, six viewer-isolation checks, six HUD cases and the
existing 16 size/scale combinations. Import and logs were clean; source
invariance and whitespace checks passed. The tier labels meet 4.5:1 contrast
on all four base surfaces. [Tier screenshot](evidence/issue-7/tiers.png) and
[summary](evidence/issue-7/summary.json) retain review evidence.

Owner review should check immediate tier recognition and separation from
Warning/Error on their display, including the small labels at preferred scale.
Color-vision accessibility is supported by explicit labels and ordinal cues;
formal color-vision/user testing, physical 4K/mixed-monitor, compatibility
renderer and archived historical comparisons were not performed. No subsequent
issue or production migration is authorized by this implementation.

## UX-STYLE-004 — accepted

Issue #8 reconciles the roadmap and current design system with accepted
Midnight Scientific refinements, identifies historical versus current evidence,
and extends the scale matrix to all five laboratory pages. The
[validation report](UX_STYLE_VALIDATION.md) records 1,402 passing native checks,
218 contrast pairs, all four scales, scientific-viewer isolation and physical
4K limitations. No theme or production behavior was changed by issue #8. Current UX3
authorization follows the issue #53 gate above.

## UI-003 — accepted

Issue #2 removes the manual pitch limit and derives the camera basis directly
from yaw/pitch, carrying the up axis smoothly through both poles. Existing
camera recipe fields and automatic world-Y orbit are preserved. Pan, zoom,
Frame scene, reset and orbit-center behavior have focused regression coverage.
[Camera validation](CAMERA_TUMBLE_VALIDATION.md) records synthetic particle,
volume and mesh results, native render checks, recipe/video regressions and
original owner acceptance steps. The owner reviewed and accepted issue #2; PR #29
was merged on 2026-09-19. The validation report and evidence preserve their
original review-time state. Acceptance does not authorize another issue.

## UI-004 — pending owner review

Issue #4 adds **Show probe marker** beside the volume source-probe action.
The cross is `scene_layers.gd`’s `SourceProbeMarker`; hiding it retains the
last probe and does not alter scientific data. The session preference survives
playback, seeking and recipe restoration. Screenshots honor visibility;
deterministic video retains its existing exclusion of session-only probe markers.
[Focused validation](PROBE_MARKER_VALIDATION.md) records both native renderers,
source invariance, screenshot/video checks and owner verification steps.

## VIDEO-001 — pending owner review

Issue #1 makes offline GPU rendering independent of window redraws. The worker
minimizes its noninteractive window and uses explicit draws for its export
SubViewport. Progress, cancellation and source/sample/camera contracts remain
intact; UI-launched jobs retain renderer diagnostics. [Background export
validation](BACKGROUND_EXPORT_VALIDATION.md) records native window-state tests,
unchanged frame/timing comparisons, limitations and manual owner checks.

## VOLUME-004 — validation pending owner review

Issue #13 was reviewed under **Pre-UX3/UX4 — Validation & Maintenance**. The
[real-capture volume review](VOLUME_DEFAULTS_VALIDATION.md) records 16 comparison
views and 81 integrity/rendering checks per backend. Source data remains unchanged.
The review identifies density-range tradeoffs and signed color/opacity coupling;
useful untuned defaults are not demonstrated across all requested cases. This is
validation only: no defaults or later-UX features were implemented. Recommendations
remain subject to separate owner authorization.

## VOLUME-002 — pending owner review

VOLUME-002 (#11) is implemented and **pending owner review** under its current
**UX4 — Panels & Information Architecture** milestone. Independent scalar or
magnitude opacity thresholds address the signed-field opaque-domain behavior.
New density defaults are preserved, and legacy recipes migrate their saved bounds.
[Mapping and validation](VOLUME_OPACITY_MAPPING.md) record both GPU backends,
recipe/export checks and external-capture evidence. No VOLUME-003 range policies,
VOLUME-001 presets or UX4 panel restructuring are included.

## VOLUME-003 — pending owner review

VOLUME-003 (#12) is implemented and **pending owner review** under
**UX4 — Panels & Information Architecture**. Volume color ranges support frozen
manual, symmetric-sample and percentile-sample policies with explicit clipping
disclosure and validated logarithmic mapping. Opacity remains independent.
[Normalization contract and validation](VOLUME_COLOR_NORMALIZATION.md) record
native GPU, recipe, export, playback and read-only real-capture checks. No presets,
interval scan, interpolation or panel reorganization are included.

## VOLUME-001 — pending owner review

Issue #10 adds opt-in Dense core, Faint structure and Signed field display
presets plus control guidance under **UX4 — Panels & Information Architecture**.
Actions resolve to explicit frozen color/opacity settings, retain manual controls
and preserve ray step, strength, particles and scene presentation. Opening defaults
and scientific source values are unchanged. [Preset semantics and validation](VOLUME_DISPLAY_PRESETS.md)
record review evidence and limitations. No panel restructuring, interpolation or
later issue is included. Implementation remains pending owner review.

## Current limits

G3 permits at most one particle object per capture and supports one translucent volume and one derived isosurface at a time; multiple meshes and slices are supported. Interactive particle, field and mesh CPU preparation is asynchronous in the accepted maintenance implementation; field textures and mesh surfaces are staged on the main thread. Stable mesh positions interpolate on the GPU, while scalar colors hold the earlier source sample. Initial opening and explicit scientific inspection/export retain synchronous work. Mesh inspection positions and deformed normals are materialized on demand; rendering remains unshaded. Source arrays and probes retain scientific precision, while GPU previews use float32 and may reduce resolution; isosurfaces are explicitly approximate. Budgets are separate allocation limits, not a whole-process memory guarantee. The earlier full G3 demo completed about 19.2 samples/s; neither that result nor the new particle controls establish universal 30 FPS performance. Concurrent CuPy simulation/viewer performance has not been validated. Detailed contracts and measurements are in the [handbook](SIMSCOPE_HANDBOOK.md) and [format/API guide](CAPTURE_FORMAT_AND_API.md).

No AMR, general vector-basis transformation, reconstruction of exact fields from tracers, arbitrary transparent-volume compositing, background archive queue, writer resume, or per-record fsync is implemented. Existing inspection recipes and deterministic export are implemented; do not confuse these with the future G5 control service.

## Completed authorized milestone

Documentation consolidation was committed separately as `4d9e99b`, followed by
G4a–G4f under the approved [design](../G4_DESIGN.md). All A01–A23 have specific
PASS evidence in the [ledger](G4_ACCEPTANCE.md); no acceptance ID was removed or
weakened. The synthetic demo supplies both a source-grid mass oracle and a
tracer-only refusal example. The user reviewed and accepted G4; further milestones require
new authorization. No external scientific simulation was rerun.

G4 numerical work runs on a bounded private worker, preserves native clocks and
source values, and exports full results with source/units/identity provenance.
Selections, recipes, PNGs and matched clips retain exact sampling state. Analysis
pauses during playback underflow. Worker memory, disposable cache, exact member
assets, viewer previews and GPU overlays have separate finite budgets; oversized
requests refuse. The 100k-particle idle comparison stayed below the 10% regression
target on both renderers. See the final report for workload-specific measurements
and limits; this does not establish universal frame rates or whole-machine limits.

Further playback work should be driven by measured remaining costs: particle position packing, large mesh/volume GPU upload cost, or large trail histories. The hidden-particle and proactive preparation work is complete. External scientific research is managed separately from the SimScope roadmap.


## Licensing baseline

PolyForm Noncommercial 1.0.0 is the intended license for original SimScope material in this fresh source snapshot. Branding is separately reserved. Separately licensed bundled material and external dependency notes are tracked in [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md); repository-reset scope is recorded in [PROVENANCE.md](../PROVENANCE.md).

## Release checklist

- [ ] Before first public release: review project license, contributor policy/CLA requirements, third-party licensing, copyright ownership, branding/trademark policy, and repository contents.
- [ ] Before any public binary distribution: audit the exact bundled engine/runtime/encoder/dependency artifacts and preserve all required third-party notices/source obligations.

Track third-party licensing in [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md).

## Repository baseline

The current repository is a fresh source snapshot with prior development Git history intentionally archived outside this repository. Scientific simulations, raw captures and research projects remain external. SIMSCP4 is the only supported capture format for new work. See [repository boundaries](REPOSITORY_BOUNDARY.md), [capture policy](CAPTURE_FORMAT_POLICY.md), [evidence](EVIDENCE_INDEX.md), and [provenance](../PROVENANCE.md).

## UX-IA-001 / UX-IA-002 — design baseline merged

The owner merged PR #39 on 2026-09-20 at `1043966`. Issues #14 and #40 are Done
on the Project board. The [architecture](UX_INFORMATION_ARCHITECTURE.md),
[control map](UX_CONTROL_MAP.md) and [visual language](UX_VISUAL_LANGUAGE.md)
provide the design inputs for separately authorized implementation slices.
Original review reports, mockups and evidence preserve their review-time wording.

## UX3 shell, transport and status

The shell was accepted and merged in PR #45. Issue #42 moves playback/time controls
into a persistent bottom transport and adds a separate draft/Go/Cancel seek form.
Displayed time remains the committed scientific clock while requested time shows
a differing submitted target during buffering. See the [transport contract and
validation](UX3_TRANSPORT.md) for implementation, evidence, limits and owner checks.

The right dock retains its workspace entry points and scientific forms. Native
fullscreen hides the command bar and retains camera controls, transport and mouse
recovery. [Status/Jobs](UX3_STATUS.md) adds persistent access to existing worker
operations. Full workspace migration and UX3 milestone acceptance are not claimed. Historical reports/evidence retain their original review wording.


Issue #46 adds a separate [immersive fullscreen](UX3_FULLSCREEN.md) action on its
issue branch, pending owner review. Interactive fullscreen retains the controls
above; immersive hides all application chrome while preserving scientific
overlays and restores the preceding shell/native mode with Esc. This is session-only
presentation state, with no recipe or rendering-model change.


Issue #55 reuses the current production shell for video UI overlays, pending owner
review. The explicit export checkbox controls UI inclusion independently of
fullscreen; existing scientific-overlay gates and native 3D framing are preserved.
See [export behavior](../VIDEO_EXPORT.md) and [validation](evidence/issue-55/README.md).
