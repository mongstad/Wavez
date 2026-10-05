# Current status

Issue #258 separates RMB free-look steering from held view-relative orbit in
candidate build 52. RMB changes heading in place; Orbit Camera Left/Right are
configurable Navigation shortcuts, Unbound by default. Either input immediately
disables Auto Orbit. Translation speed, LMB, wheel and scientific transforms keep
their accepted behavior. See [camera steering and orbit](MANUAL_CAMERA_ORBIT.md).

Issue #253 makes Save Image capture the visible scientific viewport in candidate
build 51. It retains the live camera framing and eligible scientific legends,
while excluding the top bar, Simulation dock, transport/status strips, Tools,
dialogs and orbit-center gizmo. The configured folder, native picker, shortcut
and optional inspection sidecars keep their existing routes. Fullscreen saves
use the complete viewport regardless of revealed chrome or invocation route;
paused captures request their own draw without waiting for a window event. See
[Save Image](IMAGE_EXPORT.md) for behavior and owner checks.

Issue #256 retunes Free Camera speed adjustment to 10% per `+`/`-` step,
with a 0.02–2.5 multiplier range. The 0.7 default, 200 ms hold cadence,
shortcut behavior, camera interactions and scientific transforms remain as
accepted in #200. Candidate build 50 is pending owner review. See
[Free Camera speed](FREE_CAMERA_SPEED.md).

Issue #200 lowers the default Free Camera translation rate by 30% and adds
editable `+`/`-` speed shortcuts. Each press changes the current rate by 5%; a
held key repeats on a controlled 200 ms cadence within bounded limits. Camera
direction, mouse/orbit interactions and scientific transforms are unchanged.
Candidate build 49 is pending owner review. See [Free Camera speed](FREE_CAMERA_SPEED.md).

Issue #234 uses Auto Orbit as a navigation mode. With Auto Orbit on,
W/A/S/D/Q/E immediately turns it off and applies the same keypress as ordinary
Free Camera movement. Edit Orbit Center temporarily suspends orbit; Apply starts
orbit around the new world-space target and Cancel restores the complete
pre-edit view and mode. LMB/RMB/wheel remain available, and scientific scene
transforms stay unchanged. Candidate build 48 is pending owner review. See the
[Auto Orbit behavior and owner checks](AUTO_ORBIT.md).

Issue #248 arranges Video Export settings into titled Range, Video, Camera,
Presentation and Output groups in candidate build 47. The separate lower
Export summary becomes Export status while a job is active or retained; long
status details scroll within that area so the settings and actions remain
reachable at the minimum dialog size. The cancellation confirmation asks only
“Cancel video export?” with spaced Yes/No actions and No initially focused.
The owner follow-up labels the existing simulation-time control Playback rate,
removes duplicate paths from normal dialog status, automatically cleans PNGs
after successful MP4 export, and places optional ordinary inspection JSON under
collapsed Advanced. Selection-aware version-2 sidecars remain mandatory.
Export timing, rendering and cancellation protocols are unchanged. See
[the video export guide](../VIDEO_EXPORT.md).

Issue #211 restores Reset Camera to the current scene bounds in candidate build
46. It returns to the default orientation while centering and sizing the camera
for the loaded particles, fields and meshes; Frame Scene still preserves the
current orientation. Small scenes receive scale-appropriate clipping planes.
See [camera reset behavior and owner checks](CAMERA_RESET.md).

Issue #220 renames the Video Export Range option from “Custom start/end” to
“Custom” in candidate build 45. The option index, Start/End editability and
custom-range timing are unchanged. See [the video export guide](../VIDEO_EXPORT.md).

Issue #221 groups the Video Export Range, Start and End controls inside a
compact bordered section in candidate build 44. The Full preset and concise
Start/End labels replace the older wording; the exclusive-end explanation is
available on End's tooltip. The estimate keeps output duration/frame count and
shows a compact Temporary storage value. Range timing and FFmpeg admission are
unchanged. See [the video export guide](../VIDEO_EXPORT.md).

Issue #226 adds Edit → Preferences → File Locations in candidate build 43.
FFmpeg defaults to runtime PATH detection, with an explicit validated custom
executable option. Video, image and session-log directories can be configured;
Save Image writes directly to a configured image folder and otherwise retains
the native picker with a session-only folder choice.
Missing FFmpeg stops an MP4 request before rendering. See [File Locations](FILE_LOCATIONS.md)
for defaults, persistence and owner checks.

Issue #242 adds a per-session, bounded local troubleshooting log in candidate
build 42. It records source identity and path, committed controls, Tools and menu
routes, playback actions, jobs, and retained failures with playback context.
Verbose is the current policy; the central logger also supports Minimal and
Disabled for a later preference. See [session logging](SESSION_LOGGING.md).

Issue #224 audits every current Tools route, its controls, source eligibility,
scientific or presentation effect, and recommended classification. Build 41 was
owner-merged in PR #241. It removed no tools and changed no
analysis behavior. See the [live Tools functional audit](TOOLS_FUNCTIONAL_AUDIT.md)
for the route inventory, wording findings, focused evidence, limits and owner
checks.

Issue #232 compares mixed playback before/after #230. On the supplied production
capture, temporary 2× holds came from the existing field refill gate while
particles were ready. Candidate build 37 corrects the Buffering wait reason;
cache policies and worker scheduling are unchanged. See the
[mixed playback investigation and owner checks](MIXED_PLAYBACK_BUFFERING.md).

Issue #229 restores automatic particle caching to safe whole-scene or bounded
capacity, with worker-side descriptor sizing and resident cache details in the
Ready tooltip. Initial interaction remains available while background preparation
continues. Scenes containing fields preserve the smaller rolling particle window
so fields retain RAM priority. Build 36 was owner-merged in PR #230. See the
[particle cache policy, production measurements and owner checks](PARTICLE_CACHE_CAPACITY.md).

Issue #204 opens a successful scene paused at its first recorded sample.
Automatic particle, field and mesh preparation continues through the shared
bounded scheduler while the clock stays still; valid prepared coverage remains
resident during pauses unless source/configuration changes or resource limits
require eviction. See the
[playback and cache contract](WAVEZ_HANDBOOK.md) and
[focused validation and owner checks](PAUSED_PREPARATION.md).

Owner-merged issue #198 confines video frames to the scientific viewport and
enabled viewport legends. The Video Export dialog remains authoritative for rendering
preset, overlays, camera, timing, resolution and other job settings; shell
controls stay outside the frame. Build 34 was accepted in PR #225. See
the [current export contract](../VIDEO_EXPORT.md) and
[viewport composition evidence](VIDEO_VIEWPORT_EXPORT.md).

Owner-merged issue #161 gives File and Tools application-owned dialogs a compact Wavez
surface, consistent actions and scrolling, and removes repeated loaded-scene
identity from tool headings. Genuine filesystem selection uses the native
desktop picker where supported. The accepted #181 Open File picker and its
WVZ1 filter remain unchanged. Build 33 was accepted in PR #223;
see the [route inventory, dimensions and screenshots](DIALOG_COHERENCE.md).

Issue #182's [clean-break design](FORMAT_IDENTITY_PROPOSAL.md) was owner-merged
in PR #213. Issue #215's **WAVEZ Scene Format** (`.wvz`, WVZ1) implementation
was owner-merged in PR #216 as build 31. The writer, Python
analysis, native viewer, current tools and examples use WVZ1 only. The
[current format policy](CAPTURE_FORMAT_POLICY.md) defines the approved wire
identity and intentional alpha break. Historical reports below retain their
original format claims and test results. See the
[WVZ1 implementation validation](WVZ1_IMPLEMENTATION_VALIDATION.md) for the
real Python simulation artifact, native/package checks and owner steps.

Owner-merged issue #181 opens WVZ1 scene files through the desktop's native picker where
supported, using **Open File** and **WAVEZ Scene Format** (`*.wvz`) in the
file-open flow. The built-in picker remains Godot's fallback; video export
kept its existing picker at that review checkpoint. Build 32 was accepted in PR #218. See the
[current dialog behavior](FILE_DIALOGS.md) and [issue validation](evidence/issue-181/README.md).

Issue #202 selects **Meshes** in the Simulation panel after a successful
mesh-only file load. Mixed scenes retain the selected category, and explicit
video-export workspace state remains authoritative. Candidate build 30 is
pending owner review.

Issue #158 reduces application-owned work during continuous native window
resize: empty startup now stops recurring 3D redraw, and the shell applies
the latest native size once per frame. Loaded playback and scientific data
paths are unchanged. Candidate build 28 is **pending owner review**; the
[resize diagnosis, measurements and validation](evidence/issue-158/README.md)
separate owner-operated baseline traces from automated candidate runs.

Issue #201 changes a clean viewer's navigation defaults to **Free camera on**
and **Auto orbit off**. Both remain available through Navigate and the existing
editable shortcut actions; O still toggles Auto Orbit, while Free Camera starts
unbound. Each toggle changes only its own navigation state, including through
Navigate. A binding conflict transfers a key to one action, so F can be
assigned to Free Camera without also invoking Frame Scene. Opening a scene and
Reset Camera retain the current navigation modes.
An explicit view preset can restore both modes; an inspection recipe restores
its saved Auto Orbit state while Free Camera remains session-only. Candidate
build 27 is **pending owner review**. See the
[navigation default review revision](evidence/issue-201/revision-1/README.md).

Issue #190 adds right-drag sideways camera orbit about the camera's screen-up
axis captured at each right-button press. Vertical right-drag motion is ignored;
left-drag can establish a new orientation and orbit plane before the next press.
The gesture works across particle, volume, mesh and mixed scenes without selecting
an object. Its angular sensitivity changes smoothly with camera distance and
viewport size; left-drag tumble, zoom, Frame Scene and Auto Orbit retain their
existing roles. Candidate build 26 is **pending owner review**. See
[usage and owner checks](MANUAL_CAMERA_ORBIT.md) and the
[revised validation](evidence/issue-190/revision-2/README.md). The first two
review-time reports remain historical records of their candidates.

Issue #195 adds a bounded CPU worker pool, decoded endpoint reuse and exact-match
stable-topology reuse for sustained mesh playback. The pool adapts to CPU capacity
and live RAM, preserves the four-pair future window, and keeps GPU uploads on the
main thread. Build 25 was owner-merged in PR #196. See the updated
[mesh preparation policy](MESH_PREPARATION_BUDGET.md) and
[measurements, validation and owner checks](evidence/issue-195/README.md).

The accepted #193 investigation established CPU underproduction on the cavity
capture and motivated this change; its [historical measurements](evidence/issue-193/README.md)
remain unchanged. The #191 [RAM admission evidence](evidence/issue-191/README.md)
also remains a historical record; the current policy adds a separate endpoint
cache share and accounts for concurrent work.

Issue #187 fixes mouse-wheel zoom snapping small/large scenes to fixed 8/500
world-unit limits. Progressive reciprocal zoom now uses scene bounds and camera
clip planes, preserves custom orbit state and honors fractional input. Candidate
build 22 is **pending owner review**. See [reproduction, validation and owner checks](evidence/issue-187/README.md).

Issue #178 removes the decorative starfield entirely, including loaded scenes,
visual/preset state and export settings. The cinematic sky and scientific layer
renderers remain. Candidate build 21 is
**pending owner review**. See [source trace, comparisons and owner checks](evidence/issue-178/removal-review/README.md).

Issue #179 changes the Help menu label to **About**, preserving the existing
About WAVEZ dialog title, content and route. Candidate build 20 is **pending owner
review**. See [validation and owner checks](evidence/issue-179/README.md).

Issue #176 now restores square outer surfaces after owner feedback. The visible
shell uses its original styles; custom dialogs have square outer corners. The
About seam fix remains, and its upper-right X shares the shell's close-button
primitive, icon, size, state styles and hover handling. Candidate build 19 is
**pending owner review**. See [behavior, revised evidence and owner checks](ROUNDED_SURFACES.md).

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
[handbook](WAVEZ_HANDBOOK.md), and [Python API](../WAVEZ_API.md).

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
The inherited aggregate export ceiling is now removed; [reader metadata budgets](WAVEZ_METADATA_BUDGET.md)
separate resource admission from SIMSCP4 validity. Above-boundary native/Python
validation preserves per-record limits, checksums and scientific values.
Strict 33.3 ms pacing and indefinitely uninterrupted playback when decoding is
slower than consumption remain unestablished; this is not a universal smoothness claim.
The owner-confirmed 13.86 GiB capture records 128³ fields. Normal opening now
indexes bounded record headers and loads the first visible scene; requested
records are validated and decoded on demand or within bounded background windows.
Automatic particle preparation no longer preloads the full timeline or gates the
first usable scene. Exact identity-map reuse and native descriptor predicates
remain from the initial profiling change. Comprehensive verification for current
WVZ1 files is explicit through `python tools/verify_wvz.py SCENE.wvz`.
Historical reports and evidence retain their original review-time wording.

As of **2026-09-20**, including G4 and PERF-001/002 maintenance reviewed and accepted by the user. Scientific simulations were not rerun. Historical results identify their recorded checkpoints. PERF-003 mesh maintenance was also reviewed and accepted by the owner on 2026-09-13; implementation checkpoint `7974c78`.

| Area | Current state |
|---|---|
| Authoritative viewer/exporter | `Wavez/` |
| Repository boundary | Wavez product code/docs/tests only; scientific simulations and research data are external |
| Preferred new scene workflow | Explicit `SceneCapture` / `SceneReader`, WAVEZ Scene Format (`.wvz`) |
| Scene contract | WVZ1 only; package 4.0.0, candidate build 31 under #215 |
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

At this earlier checkpoint, older capture writers/readers and public API entry
points had been retired in favor of SIMSCP4 / `.ssc`. Issue #215 supersedes
that format identity; this paragraph records the earlier accepted state.

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

G3 permits at most one particle object per capture and supports one translucent volume and one derived isosurface at a time; multiple meshes and slices are supported. Interactive particle, field and mesh CPU preparation is asynchronous in the accepted maintenance implementation; field textures and mesh surfaces are staged on the main thread. Stable mesh positions interpolate on the GPU, while scalar colors hold the earlier source sample. Initial opening and explicit scientific inspection/export retain synchronous work. Mesh inspection positions and deformed normals are materialized on demand; rendering remains unshaded. Source arrays and probes retain scientific precision, while GPU previews use float32 and may reduce resolution; isosurfaces are explicitly approximate. Budgets are separate allocation limits, not a whole-process memory guarantee. The earlier full G3 demo completed about 19.2 samples/s; neither that result nor the new particle controls establish universal 30 FPS performance. Concurrent CuPy simulation/viewer performance has not been validated. Detailed contracts and measurements are in the [handbook](WAVEZ_HANDBOOK.md) and [format/API guide](CAPTURE_FORMAT_AND_API.md).

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

The current repository is a fresh source snapshot with prior development Git history intentionally archived outside this repository. Scientific simulations, raw captures and research projects remain external. WVZ1 is the sole current scene format. See [repository boundaries](REPOSITORY_BOUNDARY.md), [format policy](CAPTURE_FORMAT_POLICY.md), [evidence](EVIDENCE_INDEX.md), and [provenance](../PROVENANCE.md).

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
