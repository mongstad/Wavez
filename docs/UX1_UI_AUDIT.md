# UX1 — Current UI and coupling audit

2026-09-13. Baseline: accepted retirement commit `47fef34dc5bdcbbc8db7f562f778deb100a70d5c`, SIMSCP3 / `.ssc`, exporter 2.0.0. This is an audit of the existing product, not implementation of the proposed design. See the [specification](UX1_DESIGN_SYSTEM.md), [workflow gates](UX1_REGRESSION_WORKFLOWS.md), and [milestone report](UX1_REPORT.md).

## Method and limits

Read the main viewer, scene/layer playback, selection/analysis controllers, plots, visual/inspection state, video dialog/worker, project configuration, and current user guides. Exercised the actual Godot UI with the [audit collector](../tools/audit_ux1.gd), using the small analytic particle/mesh/volume scene. The collector pauses playback and orbit to stabilize screenshots; normal asynchronous preparation remains enabled for the desktop instance. It calls existing controller methods and signals. It does not simulate physical mouse/keyboard use or change product code.

The native run used Godot 4.7.2, Forward+, NVIDIA RTX 3070 Ti, X11, a 2560×1440 screen reporting 93 DPI and scale 1. Two screens were reported; only the current screen was exercised. There was no physical multi-monitor placement, mixed-DPI, screen-reader or human usability study. Frequency classifications below are design judgments based on task dependency, not usage telemetry.

The [summary](evidence/ux1/summary.json) records 590 constructed non-internal Control descendants for the loaded fixture, including hidden controls and the video window's controls. These are **not 590 simultaneously visible controls**, nor a complete count of Godot's internal file-picker widgets. The fixture exposes 17 top-level accordion sections. Larger captures and additional objects produce additional controls. The complete per-state tree remains in ignored `results/ux1/audit.json`.

## Actual shell and ownership

The [main scene](../viewer/Main.tscn) contains one Node3D with [main.gd](../viewer/main.gd), currently 1,714 lines. It constructs the world, particles, camera and UI. There is no shared application Theme resource, UI scene library, main menu bar, settings dialog or workspace manager. Godot's fallback theme supplies most widget styles; the inspector and slider labels have local overrides.

The root uses a 1440×900 logical canvas with `canvas_items` stretching. A CanvasLayer holds the left overlay inspector, a resize handle, colorbar and legend. The inspector is a PanelContainer → ScrollContainer → VBoxContainer. Its top contains HUD, general status and Hide inspector. Opening a scene inserts layer and buffer controls at child index 3, ahead of playback. Most controls scroll together, including transport, errors and file actions. The scientific viewport remains the full rendering surface beneath this overlay.

There are no detachable tool panels. Video export is a Window with a scrollable two-column form. In this run Godot embedded that window and file dialogs in the main surface. Native OS decoration, alt-tab behavior and independent window DPI were not established by these captures.

Current hard-coded styling/geometry anchors (distinct from the proposed tokens):

| Source / element | Current value and inconsistency |
|---|---|
| `main._style_panel` | Background `Color(0.018, 0.035, 0.059, 0.91)`, blue border `Color(0.24, 0.58, 0.65, 0.38)`, 1 px border, 14 px corner radius, 18 px horizontal / 16 px vertical padding |
| Inspector and groups | 12 px outer offset; 340 requested default width; drag range 290–600; 10 px resize handle; section/group separation 5 px, mixed with inherited container separation |
| Text | Most constructed text resolves to fallback 16 px in this run; slider labels explicitly 12 px and `#91B6CA`; plots draw 11–12 px annotations directly with the fallback font |
| Legend | 340×18 colorbar and 340×90 label; right/bottom offsets hard-coded, recomputed from logical viewport and requested panel width |
| Analysis | Selection list minimum height 110; inline plot minima 220×190, 220×260 and 220×330; table minimum height 150; nested grouping uses separate presentation helpers |
| Video / notification | Video form column gap 16; most form spacing/padding inherited, unlike inspector. Screenshot notice uses white text, black shadow and 2 px shadow offsets |

The lack of shared roles makes global sizing/contrast changes require edits across these factories and custom draw methods. Runtime [control inventory](evidence/ux1/control-inventory.json) retains resolved sizes and tooltip/focus properties for comparison.

## Current UI inventory

Frequency: **F** frequent, **C** contextual, **R** occasional configuration, **D** diagnostic. Expansion states are startup defaults, before recipe restoration. Section names below are exact current labels.

| Surface / section | Existing controls and behavior | Frequency / placement judgment |
|---|---|---|
| HUD and general status | Simulation name, frame/union count, physical time, particle count, position/ID/scalar sampling policy; one replaceable message label | F/D. Keep concise sample identity and readiness near viewport; move detailed allocation text into diagnostics |
| Scene layers (inserted block) | Particle buffer policy, loop toggle, preparation/memory text; GPU MiB budget; per-object sample status and LOD; mesh/volume settings; volume source selector, xyz probe and result | F/C/D. Layer list and visibility persistent within the dock; settings contextual; memory tuning occasional |
| Data cache (collapsed) | Decoded cache MiB SpinBox, usage text, Clear decoded cache | R/D. Performance settings with explicit budget scope |
| Playback (expanded) | Step buttons, Play / Pause, integer timeline, index/physical mode, physical-time input and Seek time, separate index FPS and physical-rate sliders | F. Persistent transport outside panel scroll; mode-specific rate editor |
| Rendering (expanded) | Cinematic/Scientific/channel/Minimal presets, particle size, brightness, Point rendering toggle | F/C. Object appearance and viewport presentation; distinguish scalar mapping from visual gain |
| Color Mapping (expanded) | Particle Color by, colormap, range policy, symmetric shortcut, invert, legend; nested Advanced normalization with log, cyclic, interval scan/cancel, manual bounds and clamp | F/C. Selected particle appearance; preserve scientific normalization semantics |
| Advanced • Size / Brightness (collapsed) | Particle Size by / Brightness by selectors | C. Same selected-object appearance context |
| Camera (collapsed) | Auto orbit, orbit speed, free camera, Focus particles, Fullscreen | F/C. Navigation actions near viewport; orbit parameters contextual |
| Trails (collapsed) | Recorded history toggle; requires explicit IDs and is suppressed in Scientific view | C. Particle history representation with capability explanation |
| Particle Filters (collapsed) | Dynamic recorded type/category checks | C. Particle display exclusions, separate from scientific selection filters |
| Advanced • Post-processing (collapsed) | Exposure, gamma, bloom; particle X slice and position | R/C. Split presentation effects from spatial clipping |
| Geometry / Guides (collapsed) | Metadata explanation; reference axes; declared domain/absorber/imposed bounds; current data bounds; particle visibility; geometry override load/clear | C. Object visibility belongs with layers; geometry meaning remains explicit |
| Selections (collapsed) | Bind current capture, source layer, pointer/edit/occlusion modes, name and multi-select list; nested edits, exact IDs/rows/regions and predicates, derived/cohort tools, named groups, cancellation | F/C. A dedicated selection workspace with pinned source context |
| Temporal analysis (collapsed) | Selection scope, analysis mode, range axis/inclusive bounds, channel/component, scientific options, run/cancel, named results/series, exact member lookup, bounded plot, paged full values | C. Request form and result view, with result provenance always identifiable |
| Diagnostics and comparisons (collapsed) | CSV import/parsing/gaps, explicit clock/value mappings, comparison joins/schedules, shared plot, period assumptions, manual bookmarks | C/R. Context-specific analysis tasks; no hidden automatic alignment |
| Space-time analysis (collapsed) | Grid/tracer mode, spatial axis, bins/units/coordinate space, selection/weighting, run and heatmap | C. Currently consumes range/channel from Temporal analysis and source layer from Selections |
| Analysis export and state (collapsed) | Folder name, bounded output/CPU/wall limits, members/results inclusion, numerical export, save/load recipe, locate referenced input, recompute | C/R. Unified export entry with clearly typed operation |
| Matched runs (collapsed) | Left/right recipes, layer/channel/selection correspondence, explicit time/value maps, common units/origin/axes/range/camera/timing, prepare/render/cancel | C/R. Larger dedicated comparison form; retain all declarations |
| Capture / Export (collapsed) | Open capture, PNG, sidecar toggle, copy inspection state, save/load scene recipe, Export Video; condensed keyboard help | F/C. Open/export must remain reachable independently of analysis-panel scroll |

Layer-specific details: meshes offer visibility, channel, exact finite range, colormap and wireframe. Volumes add opacity per world unit, ray step, slice orientation/normal/distance, X clipping, source isosurface threshold/extract/remove. Particle visibility is instead under Geometry / Guides and particle mappings are global. Channel and colormap selectors in the mesh/volume bodies have no adjacent label. Source probes and derived surfaces remain scientifically distinct from GPU preview values and material identity.

The six G4 section heights with nested analysis groups expanded at 323 logical pixels content width were: Selections 2405, Temporal analysis 2155, Diagnostics and comparisons 3143, Space-time analysis 976, Analysis export and state 593, Matched runs 2501. These are content heights, not off-screen-window failures. Vertical scrolling makes the forms reachable, but retaining context across them is expensive.

### Dialogs and file workflows

| Dialog / overlay | Current behavior and constraints |
|---|---|
| Open capture | Filesystem FileDialog, `.ssc` filter, 78% centered size. Invalid opening reports an error before replacing the current reader. No primary empty-state Open button |
| Screenshot folder / notice | First PNG action chooses a session directory (65% dialog). Cancel clears pending state. Subsequent PNGs use that directory. A separate white label with black shadow gives timed feedback; no durable notification list |
| Scene inspection recipe | Save/load JSON picker, 65%; native v2 scene state, validated against open source. Copy Inspection State uses clipboard |
| G4 recipe / numerical bundle | Separate parent-directory or JSON dialogs, usually 70%; explicit new folder, finite quotas, referenced inputs and exact assets. G4 v3 retains selections/results. These are independent of capture format generation |
| Geometry / CSV / referenced input | Explicit geometry JSON, CSV/TSV, or referenced capture/CSV/surface pickers. Input location is an explicit binding step |
| Video export | 760×800 requested size, 600×500 minimum; range/end-exclusive fields, resolution/FPS presets plus numeric values, time rate, camera, rendering, overlays, trails, quality, output and sidecars/quota; estimate, progress and Start/Cancel/Close all scroll |
| Video save path | MP4 save picker, 80%. Worker refuses overwrite; completed intermediates survive cancellation/errors. Closing the panel allows worker continuation; closing the parent requests cancellation |
| Viewport overlays | Scalar colorbar/legend, reference/declared geometry, selection highlights and gesture polygon, probe marker. Scientific overlays must keep their own semantics and export flags |
| Plot views | Custom native draw code, small fixed minimum heights, 11–12 px fallback-font annotations, bounded previews and hover provenance; full values remain available through paged results/export |

### Input, settings and scaling

Current application shortcuts in `_unhandled_input`: Space play/pause; Left/Right union-sample step; O auto orbit; T recorded history; F frame scene; V Scientific/Cinematic switch; P PNG; F1 inspector/legend visibility; F11 fullscreen; R reset camera. Left drag orbits and wheel zooms. Free camera uses physical WASD/Q/E only when enabled and no GUI focus owner exists. Selection handling runs before camera handling; a busy inspection suppresses unhandled input. Text widgets also consume events before this path. Keyboard behavior inside every editor/dialog was not manually exercised.

Shortcut information is spread across button labels, toggle labels and a short help label; V, O, T, F, P and F11 are absent from that condensed help. There is no central command/shortcut registry or user-facing shortcut/settings page. Ordinary widgets use engine focus defaults; no explicit application focus sequence or accessibility naming policy was found. Arrow glyph step buttons have no explanatory tooltip. Expansion generally changes visibility immediately; no shared motion policy exists. No settings search, reset-scope system, density control or workspace persistence UI exists. Current recipes already store some presentation state; session state is not uniformly persistent.

Observed scaling:

- Default `panel_width=340`, requested 290 and actual 367 can differ because minimum sizes win. At requested 600, actual width was 600. The resize handle/legend position use a mix of requested width and actual panel geometry.
- The default loaded timeline's top was y=1472 on the 1440×900 logical canvas. Empty-state timeline top was y=276; loaded content height was 2746. Width 600 still placed the timeline at y=1342.
- A 1280×720 window request produced a 1152×720 captured canvas while the logical UI remained 1440×900; this records the root's fixed-aspect scaling, not a claim that 1280 is fully used for layout. Small text is scaled down rather than reflowed.
- Fullscreen reported 2560×1440 and restored windowed mode; logical canvas remained 1440×900.
- The 3840×2160 GPU target used the existing export-style 1440×810 logical override. It proves rendered scaling at that target. Its synchronous fixture instance omits the asynchronous particle-buffer UI; it is not the desktop preload layout or a physical 4K/DPI acceptance test.

## Problem inventory

Priority **P1**: frequent workflow or scientific interpretation risk; **P2**: consistency/accessibility/maintainability; **P3**: finishing detail. Evidence **O** observed in render/controller exercise, **S** source inspection, **J** proposed design judgment. These are audit findings, not regressions introduced by UX1.

| ID | Priority / evidence | Finding and implication | Proposed owner |
|---|---|---|---|
| U01 | P1 O | Buffer/layer/probe controls push transport out of the loaded first view; scrolling to analysis also loses sample status | UX3 persistent transport and compact status |
| U02 | P1 O/S | Empty state explains `.ssc` but Open capture is in a collapsed section below the fold | UX3 top Open action and empty-state action |
| U03 | P1 O/S | F1 hides inspector and `show_panel_button`; restore requires knowing F1. Recipe apply can make the button visible, creating a different restore path | UX3 one visibility model and mouse/keyboard recovery |
| U04 | P1 S/O | Save/Load inspection recipe appear twice with different v2/v3 scope and workflows | UX4 typed scene versus analysis recipe actions; preserve both readers |
| U05 | P1 S | Union sample index, physical timestamps, held scalar times and output video time can be confused; both rate sliders remain present | UX3/4 explicit time-domain labels and mode-dependent editing |
| U06 | P1 O/S | Particle visibility is in Geometry; mesh/volume controls sit above global particle appearance. Focus particles actually frames a native scene | UX4 object-centered organization and accurate action name |
| U07 | P1 S | Space-time/period/comparison requests consume controls in other collapsed panels. Source pinning requires Use current capture | UX4 visible request context; no automatic rebinding |
| U08 | P1 S/O | Exact float LineEdit, float SpinBox with `.0001`/`.001` steps, and exact integer text coexist. Replacing them by one rounded editor could silently alter science | UX2 editor contracts; UX4 migration tests |
| U09 | P1 O | Video actions/progress require scrolling at default height. Close-panel continuation and cancellation are different operations | UX2 dialog shell, UX4 export composition |
| U10 | P2 O/S | Inspector requested minimum 290 is ineffective; fixed canvas shrinks fonts; legend width is hard-coded 340 and position uses requested panel width | UX2 measurement, UX3 layout, UX8 DPI acceptance |
| U11 | P2 O/S | General status is a replaceable scrolling label; local analysis errors/progress live elsewhere; screenshot notice is a third pattern | UX2 status/notification components; UX3/4 integration |
| U12 | P2 O/S | Translucent blue rounded inspector, gray window chrome, default black controls, blue 12 px slider labels and custom plot palettes lack shared tokens | UX2 opaque neutral theme and semantic roles |
| U13 | P2 O/S | Rendering preset, Point rendering and V all change the Scientific/Cinematic bundle; “Minimal / Presentation” additionally hides UI | UX4 explicit visual presentation presets; retain existing recipe meaning |
| U14 | P2 S/O | Layer channel/colormap selectors lack labels; slider values have no numeric readout; step glyphs lack accessible description | UX2 labeled properties and value/readout controls; UX8 focus/accessibility |
| U15 | P2 S | Actions and accordion headers use the same Button style. G4 groups rely on child order and visible text lookup; only those groups use `UI.fit` clipping/tooltips | UX2 explicit component roles; UX4 bounded migration |
| U16 | P2 O/S | Memory controls expose separate decoded/prepared/GPU allocations before normal tasks; displayed MiB figures can round small values to zero | UX3 concise readiness, UX5 detailed scoped resource settings |
| U17 | P2 S/O | Repeated “Advanced”, slash/bullet labels, sentence/title capitalization and inconsistent “frame/sample/layer” terminology complicate scanning | UX4 glossary and progressive disclosure |
| U18 | P2 S/J | Focus defaults and shortcuts are scattered; no keyboard-only restore/help/settings contract or verified assistive-technology behavior | UX2 focus styles; UX8 interaction acceptance |
| U19 | P2 O/S | Plots and full data pages share the same narrow request form. Long series/IDs are clipped; exact details depend on tooltip or lookup | UX4 result workbench with copyable exact addresses |
| U20 | P3 S | Current handbook still claimed v1 particle recipes; native reader accepts v2 and G4 accepts v3 | Corrected documentation in UX1; historical reports unchanged |

## Coupling and technical risk inventory

| ID / risk | Evidence in current source | Boundary proposed for later work |
|---|---|---|
| C01 High: presentation owns application and render state | `main.gd` creates controls and callbacks directly assign playback, camera, shaders and scene settings | Presentation emits intent; a thin presenter calls existing operations. Do not move numerical work into widgets |
| C02 Critical: display strings are persisted identities | [visual_state.gd](../viewer/scene/visual_state.gd) snapshots `visual_sliders`, `sections`, preset display text; [inspection_state.gd](../viewer/scene/inspection_state.gd) validates against the live model shape | Stable semantic control IDs with explicit aliases for existing v2/v3 payloads. Keep reserved native recipe fields. No blind rename or schema drop |
| C03 High: direct tree/label dependencies | `sections`, `control_checks`, `_option` helpers; `UI.group` reparents sibling slices and `UI.button` finds visible text; native tests also query controls | Components own declared child references; adapters preserve old test/recipe interfaces until migrations have evidence |
| C04 Critical: requested time differs from committed time | [scene_layers.gd](../viewer/layers/scene_layers.gd), workers and timeline commit only prepared samples; button state reflects underflow | Transport consumes readiness/committed snapshot; seeking issues intent. UI must not invent a committed sample |
| C05 Critical: async ownership and stale work | Capture generation, source stamps, selection/analysis revisions, range request tokens, iso target checks, worker cancellation | Preserve generation checks and shutdown order; panel disposal must not destroy jobs or publish stale results |
| C06 Critical: exact numbers and identity | Layer scalar editor preserves unchanged float64 text; selection decimal IDs remain exact; v3 packs exact state/assets | Separate exact-ID, scientific-value and approximate display-control components. Formatting never mutates source/state |
| C07 High: cross-panel scientific inputs | Space-time reads Temporal fields; diagnostics uses current result/range; matched controller captures current camera and recipes | Explicit request-context model with source/range/units summary, independent of widget lifetime |
| C08 Critical: UI snapshot enters PNG/video | [render_worker.gd](../viewer/video/render_worker.gd) creates a full Viewer under a scaled SubViewport; scene and G4 recipes snapshot/apply visual and section state | Separate presentation preferences from render snapshot incrementally; preserve legacy native recipe aliases and offline overlay semantics |
| C09 High: viewport gestures depend on focus and dimensions | `_unhandled_input`, selection gesture projection, orbit/free camera, get_visible_rect | Define viewport-owned event surface and coordinate conversion before docking; never let a panel click start an orbit/pick |
| C10 High: visual edits may trigger expensive work | `_restyle`, `resample`, GPU upload, interval scans, inspection source materialization and isosurface jobs | Keep debouncing/stale-work handling in controllers; no per-frame control rebuilding, shader writes or hashing for cosmetic changes |
| C11 Medium: resources lack one theme path | Local panel/label overrides, copied factories, custom plot drawing and independent Window form | One Theme plus semantic token resource and role variants; plots consume chrome tokens only |
| C12 High: persistence has mixed scopes | Visual snapshot includes panel width, sections, renderer, camera and capture interpretation; screenshot directory is session-only; cache policy not a workspace model | Define scopes before UX5/7. Do not present a new “Reset” that silently clears scientific selections or source binding |
| C13 High: worker lifetime exceeds dialog lifetime | Export dialog hide continues; parent close requests cancel; matched rendering runs sequential processes | Job owner independent of dialog; close, cancel, completion and failure remain distinct observable states |

The existing shared timeline, Visual snapshot/apply, scene layer states, bounded workers and analysis UI grouping helpers are useful seams. A full controller rewrite is unnecessary for UX2. The [component specification](UX1_DESIGN_SYSTEM.md#component-and-state-architecture) defines the narrower starting point.

## Evidence map

- [Empty state](evidence/ux1/01-empty.png), [loaded default](evidence/ux1/03-loaded-default.png), [requested width 290](evidence/ux1/04-width-290.png), [playback after scrolling](evidence/ux1/05-playback.png).
- [Mesh settings](evidence/ux1/layer-surface.png), [volume settings](evidence/ux1/layer-density.png), [selection](evidence/ux1/10-selections.png), [native population plot](evidence/ux1/11-temporal-plot.png).
- [Capture/export actions](evidence/ux1/06-export-actions.png), [video initial](evidence/ux1/07-video-dialog.png), [video actions after scrolling](evidence/ux1/07-video-actions.png), [scene recipe picker](evidence/ux1/08-recipe-dialog.png).
- [Hidden inspector](evidence/ux1/12-hidden.png), [smaller window request](evidence/ux1/13-window-1280x720.png), [4K scaled target](evidence/ux1/14-4k-scaled-target.png).

Screenshots show the existing visual baseline. They are not proposed redesigns. Additional panel/file-picker images and full node trees are reproducible with the collector and remain local to keep retained evidence compact.
