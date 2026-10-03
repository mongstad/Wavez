# UX4 menu and panel contract — issue #66

**Design specification for owner review; production UI is unchanged.**
Baseline: `bfbb26c663a20bb16bee657bf87c119354abc548`, owner-merged PR #64,
2026-09-22. Issue #66 was the only Ready item on SimScope Development Project 1.
The existing issue-linked branch is
`66-ux4-design-001-finalize-menu-and-panel-contract`.

## Authority and scope

This is the proposed authoritative presentation contract for UX4. After owner
acceptance it supersedes the scrolling workspace/drawer destinations and top-level
State/Export proposals in [the earlier architecture](UX_INFORMATION_ARCHITECTURE.md),
[visual proposal](UX_VISUAL_LANGUAGE.md) and [control map](UX_CONTROL_MAP.md).
Those documents and their review evidence remain intact as historical inputs.
This revision incorporates owner review of PR #72: desktop-first spacing and one
level of related-control expanders replace the initial compact-first flat layout.
It remains a design proposal awaiting owner acceptance.
Their scientific, source, state and controller constraints still apply. The
96 inventory IDs below retain traceability; they are not new serialized keys.

Consume the accepted [UX3 shell](UX3_SHELL.md), [transport](UX3_TRANSPORT.md),
[media timing](UX3_MEDIA_TRANSPORT.md), [status and Jobs](UX3_STATUS.md),
[fullscreen](UX3_FULLSCREEN.md), [production ownership](UX3_UI_OWNERSHIP.md)
and [export overlay behavior](../VIDEO_EXPORT.md). Midnight Scientific tokens,
source names and **Population counts** terminology remain unchanged.

Only documentation is delivered by #66. No controls, callbacks, defaults, schemas,
rendering or scientific algorithms change. No UX4 implementation or owner
acceptance is claimed. The owner separately gates #67 menus, #68 panel, #69 tools,
#70 copy and #71 validation, in that dependency order where specified.

## Permanent panel rule

The right panel contains frequently adjusted simulation controls, with comfortable
spacing at a contemporary desktop window size. **1440×900 logical pixels** is the
standard design baseline; 1920×1080 is an additional roomy desktop check.
**1024×640 is a compact fallback validation case**, not the density target.

One level of clean expanders is allowed for closely related, frequently useful
controls. An expander contains only direct controls: no nested expander, category,
submenu or secondary drawer. No generic Advanced or More groups, ellipsis action
menus, buttons that open another form, prose blocks or hidden documentation belong
here. Outside those explicitly named groups, controls remain directly visible.
Larger windows do not gain extra low-frequency forms. Complex workflows remain
in the canonical menus and focused surfaces below.

A single **Object** dropdown selects a source object; it is context navigation,
not a hidden workspace or a scientific selection. It replaces the stacked
per-object Settings buttons and the Scene, Appearance, Selection, Analysis
workspace chooser. Switching object never changes visibility, channel, source
binding, selection membership or submits a job. Retain each object's live state.
Do not automatically select a different object when the current object is hidden.
Mixed captures show one object's controls at a time. Existing particle-object and
single-translucent-volume limits remain; show the current refusal if another
volume prevents activation. No capture shows an unavailable Object control and
concise empty state; File remains the canonical opening action.

## Top menus and canonical commands

The following tree prescribes visible labels; indentation means a submenu.
Submenus are permitted in the command bar, never in the permanent panel.
Shortcuts are displayed in the native shortcut column, not appended to labels.

```text
File
  Open capture
  State
    Copy state
    Save scene
    Load scene
    Save analysis
    Load analysis
    Resolve input
  Export
    Image
    Video
    Data
View
  Panels
  Fullscreen
  Immersive
  Probe marker
  Guides
    Grid and axes
    Domain
    Data bounds
    Absorber
    Imposed regions
  Viewing preset
    Cinematic
    Scientific
    Temperature
    Density
    Velocity
    Minimal
Tools
  Selection
  Analysis
    Temporal
    Space time
    Diagnostics
    Compare
    Matched runs
    Period
    Bookmarks
    Results
  Mapping
  Quick setup
  Derive range
  Slice
  Clipping
  Isosurface
  Source probe
  Performance
  Geometry
Help
  Shortcuts
  Handbook
```

- **File:** Open uses the current picker and replace/cancel/failure lifecycle.
  Copy state uses the existing committed inspection snapshot. Save/Load scene
  keep current v2 behavior and automatic v3 promotion where required; their names
  do not force a version or discard selections. Save/Load analysis retain v3
  bundles, completed-result inclusion and source validation. Resolve input is
  enabled only for unresolved references and opens the existing locator.
- **Export:** Image owns the PNG destination and inspection-sidecar option;
  Video owns the complete existing export dialog; Data owns complete numerical
  output, membership inclusion, destination and quotas. No export begins just by
  opening a configuration form. Preserve image shortcut P and all accepted job
  lifecycle behavior. Remove the standalone Open, State and Export command-bar
  buttons/menus once File owns them; the empty-state Open shortcut may invoke
  that same command, never a second form.
- **View:** Panels is a checkable visibility action with F1. Fullscreen retains
  F11; Immersive retains Shift+F11 and Esc restoration. Probe marker directly
  toggles the existing session flag. Guides directly toggle their existing flags;
  unavailable metadata remains unavailable. Viewing preset invokes the existing
  action including its environment/particle effects. Minimal is only a display
  alias for the existing `Minimal / Presentation` choice.
- **Tools:** Each leaf opens the one canonical focused surface below. An
  inapplicable tool is disabled with a short reason; never manufacture data or
  silently retarget it. Mapping is particle-only; Quick setup is field-only;
  Derive range supports the existing particle interval and field sample actions.
  Slice explicitly selects particle or field mode; Clipping and Isosurface are
  field-only. Source probe explicitly binds a field, independently of Object.
- **Help:** Shortcuts replaces Navigation help. Handbook opens the existing
  [handbook](WAVEZ_HANDBOOK.md). About is deferred until implemented, with no
  placeholder menu item. Source details remain on the capture-name affordance,
  never in Help. Capture/source names may contain source-provided punctuation.

Frame scene, Reset camera and Navigate stay over the viewport, with their
existing shortcuts. Remove duplicate Frame/Reset menu items. Navigate owns Auto
orbit, Free camera and an Orbit speed editor; retain their mutual-exclusion and
pause behavior. Orbit speed may use a small focused camera dialog launched from
Navigate. Do not keep a Camera section in the right panel. Fullscreen's accepted
mouse recovery controls and Jobs reopen/cancel actions are deliberate recovery
routes to the same state owners, not competing editors.

## Panel geometry and grouping contract

Use a 360-pixel default panel at the **1440×900 logical desktop baseline**, with
existing 320–560 resize bounds and the minimum viewport-width constraint.
The accepted shell reserves 48 pixels for the command bar, at least 64 for the
normal transport and at least 40 for status, leaving **748 pixels nominally**.
At 1920×1080 the same calculation leaves 928 pixels. These are source-derived
planning dimensions, not native measurements of the proposed panel.

Use 32-pixel normal controls, 8-pixel row gaps and 12-pixel top/bottom padding.
Reserve a 32-pixel Object row plus a 12-pixel gap: **68 pixels of base space**.
Each following direct-control row occupies a 40-pixel pitch, including its gap.
Each expander header occupies the same 40 pixels. When expanded, add an 8-pixel
inset gap and 40 pixels per child row. Headers are neutral and concise, with a
clear disclosure indicator and keyboard activation. No smaller font or forced
24-pixel control height is needed to meet a compact-window budget.

The following table defines order, row count and initial state. Semicolons separate
rows; commas combine related direct controls on one row. All groups are siblings,
and their children are controls only. No category or nested navigation belongs
inside them. These groups replace obsolete generic Advanced section identities
in presentation only; saved state compatibility remains unchanged.

| Context | Always-visible rows, after Object | One-level groups in order |
|---|---|---|
| Particles | Visible, Points, History; Size; Channel; Colormap; Range policy; Min, Max; Invert, Legend; Filters — 8 rows | **Brightness and effects**, initially open: Brightness; Exposure; Gamma; Bloom — 4 rows. **Attribute mapping**, initially closed: Size channel; Brightness channel — 2 rows. |
| Mesh | Visible, Wireframe; Channel; Colormap; Min, Max — 4 rows | **Effects**, initially open: Exposure; Gamma; Bloom — 3 rows. |
| Field | Visible, Volume; Channel; Colormap; Min, Max; Color mode — 5 rows | **Opacity**, initially open: Opacity mode; Zero, Full; Opacity; Ray step — 4 rows. **Effects**, initially closed: Exposure; Gamma; Bloom — 3 rows. |

Brightness and effects places the particle gain beside the related global
presentation controls without changing their ownership. Attribute mapping keeps two
related attribute mappings together. Field Opacity groups extinction and sampling
controls while color stays immediately visible and independent. Effects groups
only the three shared presentation controls in mesh/field contexts; it adds no
particle Brightness control to those contexts. No other expander is proposed.

| Context | Initial layout calculation | Initial height | All groups open | Initial spare height at 1440×900 |
|---|---|---|---|---|
| Particles | 68 + 8×40 + 2×40 + 8 + 4×40 | 636 px | 724 px | 112 px |
| Mesh | 68 + 4×40 + 40 + 8 + 3×40 | 396 px | 396 px | 352 px |
| Field | 68 + 5×40 + 2×40 + 8 + 4×40 | 516 px | 644 px | 232 px |

The ordinary desktop layout should fit comfortably without routine scrolling in
its initial state. The all-open estimates fit at the nominal desktop baseline,
but are not a rigid promise for every warning, font metric or window height.
Readability and reachability take precedence over fitting a fixed height.

At 360 wide, 12-pixel side margins leave 336 pixels: a single editor row can use
a 104-pixel caption, 12-pixel gap and 220-pixel editor. Paired bounds use two
164-pixel cells with an 8-pixel gap. At the existing 320-pixel compact width,
296 pixels remain; use an 88-pixel caption, 8-pixel gap and 200-pixel editor, or
two 144-pixel bound cells. If native labels or inputs require wrapping, increase
the row height rather than clip or shrink them. Exact numeric text remains
selectable and may scroll horizontally within its editor; never round it to fit.
Dropdown popups may scroll long source/category lists.

Initial group states apply only on first presentation. Remember user toggles for
the current session/context; resizing or switching objects does not reset them or
change scientific state. Groups expand independently, not as a mutually exclusive
accordion. Collapsing a group preserves its values and shows any live invalid-state
indicator on the header and in status; never hide a blocking refusal with its form.
No new disk persistence or recipe keys are introduced for these new UI groups.

Exposure, Gamma and Bloom are global controls bound to the same owner, shown once
in the active context. Their existing particle/environment effects do not gain
new mesh or field shader semantics. Keep existing availability, including Bloom
being disabled in Scientific view. Size means particle size in the particle
context. Points directly edits `clean_view`, not Viewing preset. History preserves
recorded availability and Scientific suppression. Mesh Channel retains Fixed mesh
color. Volume is the existing independent ray-march switch: it must not become an
exclusive selector that silently disables slices or isosurfaces.

Particle Range policy retains current automatic, symmetric, manual and frozen
interval states; selecting a policy follows current behavior. Min/Max are editable
only where currently allowed; automatic bounds remain read-only. The redundant
Symmetric about zero button is represented by the same policy dropdown action.
Mapping owns logarithmic/cyclic/clamp flags; none are silently reset by hiding
those flags. Field Color mode is Linear or Logarithmic; Opacity mode is Linear
scalar or Magnitude. Color Min/Max and opacity Zero/Full remain separate values.
Brief tooltips explain world units, sample freezing and scientific limitations.

Filters is a flat checkable dropdown of the existing particle categories. Each
choice directly toggles its existing exclusion; no Apply or second form. Its
closed label shows a concise exclusion count. Preserve exact category identities,
including long names, in the popup and tooltip; no fixed category-count limit.
This is a value selector, not a submenu or disclosure of advanced settings.

Current invalid input must remain visible at the offending editor. Persistent
status shows the concise blocking reason and existing Details access; color
clipping, unavailable history, stale probe and unsupported source warnings must
not become tooltip-only. Source identity, exact source time, LOD, sampling policy
and preparation details live in source details, tool context or Jobs, not repeated
paragraphs in the panel. Scientific legends remain viewport overlays with their
existing visibility/export gates.

### Compact fallback and layout acceptance

At **1024×640**, retain the existing compact-width panel and compact transport.
There is **no requirement that every panel control fit fully expanded without
scrolling**. Keep the same destinations, group order, labels and readable metrics.
Users may collapse the named groups; when content exceeds the available height,
allow vertical scrolling of the panel body, with Object context kept reachable.
Do not silently close groups on resize, remove controls or pack the ordinary
desktop layout more tightly to satisfy this fallback case. No horizontal panel
scrollbar, nested hierarchy or generic overflow group is introduced.

Retain F1 hide/show, mouse recovery and the existing width-driven automatic
collapse below 970 logical pixels. At those smaller widths, the existing temporary
sheet may scroll. A short window alone does not require changing that collapse
threshold. Transport, Jobs and fullscreen/immersive recovery remain independent
of panel expansion and scrolling.

Later native validation must inspect the comfortable initial desktop layouts at
1440×900, the roomier 1920×1080 case, and the usable fallback at 1024×640. Test
all groups open/closed, long names, exact numeric editing, warning visibility,
keyboard traversal, scroll reachability, hide/show and resize without state loss.
If native minimum sizes exceed these estimates, preserve spacing and readable
fonts; use overflow scrolling where needed rather than clipping or hiding a
capability. Unexpected routine scrolling at the standard initial desktop layout
requires layout review, not a denser compact-first redesign. HiDPI uses logical
sizes; physical-monitor acceptance remains a separate check.

## Focused surfaces and behavior

Tools are bounded, shallow task surfaces, never the whole former inspector in a
modal. One selected task form is presented at a time. Forms may scroll; titles,
source/request context and action footer remain reachable. Selection must be
nonmodal so its viewport gestures remain usable. Analysis and other inspection
tools should also allow viewport observation. Native file pickers retain their
existing modal behavior. Reopening a tool reuses its controller and draft, not a
second independent instance. Closing hides a form; it does not imply cancel.

| Entry | Concrete contents and actions |
|---|---|
| Selection | Source binding; definition list and naming; gesture/edit/visibility modes; exact IDs, rows and grid addresses; region coordinates and dimensions; predicates and exact integer bounds; Create and Cancel; cohorts, groups and highlight state. Only the chosen definition type's form is shown. |
| Temporal | Selection scope, operation including Population counts, range axis and inclusive endpoints, channel/component, units, weighting/mass declarations, missing-support settings; Run and Cancel. |
| Space time | Effective shared Temporal source/channel/component/range, spatial axis and bins, coordinate declarations, selection/weights; Run and Plot. Shared request edits use the same model, not a copied independent form. |
| Diagnostics | Named CSV input, column/time/value/unit mapping, exact number type, delimiter, blanks and gap declarations; Import. |
| Compare | Explicit left/right bindings, unit/reference/affine mappings and reasons, difference/ratio, exact or scheduled join, schedule inputs; Bind left, Bind right, Clear bindings, Compare, Add series, Clear plot. |
| Matched runs | Both recipes, selections/layers/channels, per-side mappings/reasons, common scalar/world declarations, shared range/map, aligned interval, output size/FPS/rate/quota/folder and frozen camera; Prepare, Render, Cancel. |
| Period | Explicit result/series and temporal range, method, detrend, lag/peak criteria, uniform-sampling or Hold assumptions; Estimate. No automatic event detection. |
| Bookmarks | Name, saved time/camera, explicit source binding; Save, Go, Use offset, Delete. Offset reason remains required. |
| Results | Named result and series, exact member lookup, provenance, Plot and Values views with First page and Next page; Remove result, Recompute. Shared comparison plot and space-time heatmap retain gaps, coverage and bounded-preview disclosures. Export link routes to File > Export > Data. |
| Mapping | Particle Logarithmic, Cyclic phase and Clamp flags, with existing eligibility and refusal. No duplicate channel/map/range editors. |
| Quick setup | Field target and preset choice Dense core, Faint structure or Signed field; low/high percentiles where applicable; Apply. Reuse the existing shared percentile inputs with Derive range. Preserve one-time frozen action, eligibility and resolved values; no live preset mode. |
| Derive range | Explicit object/channel/sample context. Particle interval Start/End, Freeze and Cancel; field Symmetric or Percentile, low/high percentile and Freeze. Reset color and Reset opacity retain their separate existing scopes. No new mesh derivation or field interval scan. |
| Slice | Particle mode: existing X slice toggle and fractional position with its current fixed width. Field mode: None, XY, XZ, YZ, Oblique; normal X/Y/Z and distance. Do not conflate these two operations. Existing immediate callbacks remain immediate. |
| Clipping | Field target, Enabled and X; existing world-plane clipping. |
| Isosurface | Field/channel target, Threshold, Extract, Remove, provenance and approximate-surface warnings. Selection of generated geometry remains in Selection. |
| Source probe | Explicit field/channel, X/Y/Z, Probe and exact result. Stamp capture identity, object, channel, coordinates and actual sampled source time at Probe; do not relabel an old result with current playback time. Stale context is marked. Marker visibility belongs only to View. |
| Performance | Decoded cache budget/usage/Clear cache; particle buffer policy and readiness; field and mesh preparation metrics; layer GPU budget and refusal. Allocation scopes remain separate, not a promised whole-process memory ceiling. |
| Geometry | Declared geometry and provenance, Load override and Clear override. Guide toggles stay in View; metadata details are read-only. |

State/export dialogs retain all existing parameters listed in the disposition
below, with fixed explicit action footers. Include results belongs to Save
analysis; Include members belongs to Data export. The existing Folder, Output limit, CPU
limit and Elapsed limit controls are shared by Data export and analysis bundle
save; keep one shared request-settings model and present its editor only in the
active operation form. Scene promotion and restore retain their existing use of
these limits. Do not replace them with independent defaults or make state saving
depend on opening Export first. Video keeps
its own timing, frame rate, rendering/overlay/history settings, quality, sidecars,
quota, destination, estimates, Start, Cancel and Close. Closing a running Video
form preserves Jobs reopen/cancel and partial-output diagnostics.

Opening, navigating or hiding any form must not run, cancel, rebind, decode,
prepare or upload scientific data. Explicit immediate edits keep their existing
callbacks; draft requests commit only through their original Run/Import/Prepare
or equivalent action. Capture replacement follows existing generation invalidation
and cancellation; never transfer drafts by matching object names across captures.
Tool focus returns to its invoker or recovery control; shortcuts cannot fire
through text/numeric input. No new persistent workspace preference is introduced.

## Complete inventory disposition

Each row covers every constituent of its referenced [original inventory](UX_CONTROL_MAP.md)
entry, including dynamic choices, native pickers, cancel, errors and unavailable
states. The original source symbols and state/regression columns still apply.
Where a row splits, the split is explicit below. “Panel” means the grouping contract
above; “Jobs” means existing status/detail/reopen/cancel, not another editable form.

| ID | Canonical UX4 disposition |
|---|---|
| IA-001 | File > Open capture; existing picker and cancel |
| IA-002 | Capture affordance > Source details for identity/count/time/sampling; transport for progress; status for live failure |
| IA-003 | View > Panels; existing panel resize and mouse recovery |
| IA-004 | Tools > Performance: decoded cache budget, usage, Clear cache |
| IA-005 | Transport: previous, Play, Pause, next, union timeline |
| IA-006 | Transport: Seek time and exact draft target form |
| IA-007 | Transport: Playback speed; existing recorded-time semantics |
| IA-008 | View > Viewing preset |
| IA-009 | Particle panel: Size, Brightness, Points |
| IA-010 | Particle panel: Channel, Colormap, Range policy; symmetric action via policy |
| IA-011 | Tools > Mapping: Logarithmic and Cyclic phase; remove disclosure |
| IA-012 | Tools > Derive range: particle interval, Freeze, Cancel; progress in Jobs/status |
| IA-013 | Particle panel: Min, Max; Tools > Mapping: Clamp |
| IA-014 | Particle panel: Invert and Legend; viewport retains scientific colorbar/text |
| IA-015 | Particle panel: Size channel, Brightness channel |
| IA-016 | Viewport Navigate: Auto orbit, Orbit speed editor |
| IA-017 | Viewport Navigate: Free camera and existing keyboard navigation |
| IA-018 | Viewport Frame scene, Reset camera and gestures; View > Fullscreen |
| IA-019 | Particle panel: History; current suppression/refusal in status |
| IA-020 | Particle panel: Filters, direct flat category choices |
| IA-021 | Active panel: Exposure, Gamma, Bloom, one shared global owner |
| IA-022 | Tools > Slice: particle toggle and fractional position |
| IA-023 | View > Guides: all five toggles; Tools > Geometry: metadata explanation |
| IA-024 | Particle panel: Visible |
| IA-025 | Tools > Geometry: Load override, Clear override |
| IA-026 | File > Export > Image: picker/cancel; screenshot notice in status |
| IA-027 | File > Export > Image: Inspection sidecar |
| IA-028 | File > State > Copy state |
| IA-029 | File > State > Save scene, Load scene |
| IA-030 | File > Export > Video |
| IA-031 | Help > Shortcuts; shortcuts remain bound to canonical commands |
| IA-032 | Tools > Performance: Buffer policy, readiness and memory |
| IA-033 | Transport: Loop |
| IA-034 | Tools > Performance: field preparation details; readiness/failure in status |
| IA-035 | Tools > Performance: mesh preparation details; readiness/failure in status |
| IA-036 | Tools > Performance: GPU budget |
| IA-037 | Panel Object context; source details for per-object sample/LOD/availability; remove Settings expanders |
| IA-038 | Mesh/field panel: Visible; field panel: Volume |
| IA-039 | Mesh panel: Channel, Min, Max, Colormap, Wireframe |
| IA-040 | Field panel: Channel |
| IA-041 | Tools > Quick setup: preset and Apply; prose to handbook/brief tooltips; remove help expander |
| IA-042 | Field panel: Min, Max, Color mode, Colormap |
| IA-043 | Tools > Derive range: sample symmetric/percentile inputs and Freeze |
| IA-044 | Tools > Quick setup: shared Faint structure percentiles, same owner as Derive range |
| IA-045 | Tools > Derive range: Reset color |
| IA-046 | Status: clipping/invalid-state warning; Source details: color policy, derivation sample, finite range |
| IA-047 | Field panel: Opacity mode, Zero, Full |
| IA-048 | Tools > Derive range: Reset opacity |
| IA-049 | Field panel: Opacity, Ray step |
| IA-050 | Tools > Slice: field mode, plane normal and distance |
| IA-051 | Tools > Clipping: Enabled, X |
| IA-052 | Tools > Isosurface: Threshold, Extract, Remove and result status; Jobs for running work |
| IA-053 | Tools > Source probe: target, coordinates, Probe and stamped result |
| IA-054 | View > Probe marker |
| IA-055 | Tools > Selection: explicit source binding and layer |
| IA-056 | Tools > Selection: pointer/edit/pick modes |
| IA-057 | Tools > Selection: names, definitions, Rename, Duplicate, Delete, Highlight, Show hidden |
| IA-058 | Tools > Selection: definition type and exact IDs/addresses |
| IA-059 | Tools > Selection: coordinate space, mesh elements, vectors and ROI dimensions |
| IA-060 | Tools > Selection: predicates, components, exact bounds/values and Copy exclusions |
| IA-061 | Tools > Selection: Create, Cancel, membership/error/overlay; Jobs for running work |
| IA-062 | Tools > Selection: generated surface and Save cohort |
| IA-063 | Tools > Selection: groups, Rename, Delete, Union, Intersection |
| IA-064 | Tools > Analysis > Temporal: scope and operation |
| IA-065 | Temporal request: range axis, inclusive Start/End, Full range, channel/component; shared with Space time |
| IA-066 | Temporal request: coordinates, units, statistics, weighting, mass/length/value declarations |
| IA-067 | Temporal request: Max gap and Finite subtotal; qualification stays visible |
| IA-068 | Temporal: Run, Cancel, progress/error; Jobs for running work |
| IA-069 | Tools > Analysis > Results: result, Remove result, series, member lookup, Plot |
| IA-070 | Results: plot provenance, exact paged Values, First page, Next page |
| IA-071 | Tools > Analysis > Diagnostics: name, CSV file and columns/units |
| IA-072 | Diagnostics: numeric type, delimiter, blanks, gaps and Import |
| IA-073 | Tools > Analysis > Compare: explicit time/value/unit/reference mappings and reasons |
| IA-074 | Compare: Bind left, Bind right, Clear bindings |
| IA-075 | Compare: operation, join/schedule and Compare |
| IA-076 | Compare: Add series, Clear plot; Results: shared plot and provenance |
| IA-077 | Tools > Analysis > Period: method, detrend, lags, peaks, assumptions and Estimate |
| IA-078 | Tools > Analysis > Bookmarks: Save, Go, Use offset, Delete |
| IA-079 | Tools > Analysis > Space time: operation, axis, bins and coordinate declarations |
| IA-080 | Space time: selection, population and weights |
| IA-081 | Space time: Run, Plot; Results: heatmap, coverage/error and full-bin count |
| IA-082 | File > Export > Data: folder, output/time limits, members, Export; shared limit editor also serves state bundles |
| IA-083 | File > State: Save analysis with Include results and shared folder/limits; Load analysis |
| IA-084 | File > State > Resolve input; Results: Recompute; status/Jobs: restore/export progress |
| IA-085 | Tools > Analysis > Matched runs: both recipes, IDs, channels and per-side mappings |
| IA-086 | Matched runs: common time/scalar/world declarations and shared range/map |
| IA-087 | Matched runs: aligned interval, FPS/rate, dimensions, quota/folder and camera readout |
| IA-088 | Matched runs: Prepare, Render, Cancel; Jobs: progress, outputs, reopen |
| IA-089 | File > Export > Video: interval and exact start/exclusive end |
| IA-090 | Video: resolution, dimensions and FPS |
| IA-091 | Video: capture rate and camera/orbit timing |
| IA-092 | Video: rendering, overlays and recorded history |
| IA-093 | Video: quality, temporary frames, inspection sidecars and quota |
| IA-094 | Video: output file, Browse and picker cancel |
| IA-095 | Video: estimates, samples, encoder availability and messages; Jobs: live progress/details |
| IA-096 | Video: Start, Cancel, Close; Jobs: reopen and cancellation |

UX3 additions beyond the original inventory remain canonical: elapsed/total/
remaining playback presentation and toggle, exact seek draft Go/Cancel, delayed
seek feedback and committed/requested distinction stay in transport; persistent
Jobs and durable failures stay in status; immersive restore and mouse recovery
stay in shell. They are not recreated as panel controls.

**Deferred to UX5:** application Settings, future application preferences and
any later approved relocation of system resource defaults. No existing inventory
capability is deferred or removed pending UX5. Performance stays reachable now.
Detached windows, new persistence, interpolation, renderer capabilities and later
backlog polish remain out of scope. About is conditional future help content,
not a capability currently being removed.

## Removal and copy ledger

Remove these permanent-panel groups: Capture and Export, Data cache, particle
playback buffer metrics, field/mesh preparation metrics, GPU/resource controls,
Camera, Geometry and Guides, Selections, Temporal analysis, Space time analysis,
Diagnostics and comparisons, Matched runs, Analysis export and state, Source
probe, Quick setup, Derive range, Slice, Clipping and Isosurface. Move their actual
controls as mapped above; do not merely hide their section buttons. Remove all
Settings object expanders, Advanced normalization, Advanced Size and Brightness,
Advanced Post-processing and explanatory expanders. Their retained frequent
controls become direct rows or the explicitly named one-level groups above.
Remove Show probe marker from the panel.

The table prescribes shortened UI copy. Old strings below are evidence, not
permitted new labels. The menu tree, panel table and focused-surface table provide
the remaining primary labels; use short atomic names inside those forms.

| Existing wording | UX4 visible wording |
|---|---|
| Capture / Export | File with State and Export submenus |
| Copy Inspection State | Copy state |
| Save inspection recipe; Load inspection recipe | Save scene; Load scene or Save analysis; Load analysis, according to owner |
| Locate referenced input | Resolve input |
| Save PNG; Export Video; Export numerical data | Image; Video; Data |
| Navigation help | Shortcuts |
| Show or hide panels | Panels |
| Immersive fullscreen | Immersive |
| Show probe marker | Probe marker |
| Reference grid / axes | Grid and axes |
| Declared simulation domain; Recorded sample data bounds | Domain; Data bounds |
| Declared absorber; Declared imposed regions | Absorber; Imposed regions |
| Minimal / Presentation | Minimal |
| Particle size; Point rendering; Recorded history | Size; Points; History |
| Color by; Size by; Brightness by | Channel; Size channel; Brightness channel |
| Manual Minimum; Manual Maximum; Color range minimum; Color range maximum | Min; Max |
| Show legend; Clamp out-of-range values | Legend; Clamp |
| Volume ray march | Volume |
| Linear color; Logarithmic color • positive only | Linear; Logarithmic |
| Opacity mapping • independent of color range | Opacity mode |
| Magnitude • absolute scalar | Magnitude |
| Zero-opacity threshold; Full-opacity threshold | Zero; Full |
| Opacity / world unit | Opacity |
| Ray step • world units (quality / cost) | Ray step |
| Volume display preset • optional action | Preset, inside Quick setup |
| Apply volume display preset from sample | Apply |
| Freeze symmetric range from sample; Freeze percentile range from sample | Symmetric; Percentile choices with Freeze |
| Reset color • linear 0–1; Reset opacity mapping • linear 0–1 | Reset color; Reset opacity |
| Selections; Temporal analysis; Space time analysis | Selection; Temporal; Space time |
| Diagnostics and comparisons | Diagnostics and Compare as separate items |
| Matched views | Matched runs |
| Layer GPU budget • MiB; Particle playback buffer | GPU budget; Buffer policy |
| Orbit speed • radians / second; Free camera • WASD / Q / E | Orbit speed; Free camera |
| X slice • ±3 simulation units; Slice position • box fraction | Enabled; Position, inside particle Slice |
| Plane normal X; Slice plane distance • world; Clip at world X plane | Normal X; Distance; Enabled, inside their named tools |
| Group (separate series); Grid integral (whole cells) | Group; Grid integral, with semantics in tooltip |
| Start (inclusive); End (inclusive) | Start; End, with inclusive interval in request context |
| Time offset (subtract); Value offset (add) | Time offset; Value offset, with mapping equation beside values |
| Include finite subtotal (incomplete) | Finite subtotal, with incomplete qualification on results |
| Output limit (MiB); CPU time limit (seconds); Elapsed time limit (seconds) | Output limit; CPU limit; Elapsed limit, with separate units |
| Close panel • continue in background | Close, with brief continuation tooltip |
| What do these controls change? | Remove control; use tooltip and handbook |

No revised visible menu, menu-item or primary control name may contain slash,
backslash, asterisk, parentheses or underscore. Do not put full sentences,
shortcut hints or unit explanations in primary labels. Units remain visible as
separate value metadata when needed, and exact source/channel/category names,
scientific values, formulas, paths and serialized identifiers are not rewritten.
Shortening Opacity and Ray step must retain brief descriptions of their independent
mapping, world-unit and quality-cost meanings. Long help belongs in the handbook
or a focused info dialog, never an expander. Essential refusals remain visible.

## Preservation and implementation gates

- Preserve `visual_state.STATE_KEYS`, slider/section aliases, preset identity,
  particle channel preferences and nested layer/opacity/color mappings. Display
  labels must not become new recipe keys. Legacy sections may be ignored for
  presentation but their old payloads must remain readable; do not delete keys
  merely because legacy expanders are replaced. Preserve partial-restore semantics.
- Preserve exact IDs and float64 source/request values, source fingerprints,
  selection revisions, committed results and finite worker limits. Object context
  must not rebind an analysis. Preserve missing data, Hold/interpolation behavior,
  source units and qualified results. No new inferred physical claims.
- Preserve source-probe inputs/result and marker session ownership. Presentation
  provenance is recorded at the probe event, not inferred later. Preserve its
  screenshot behavior and deterministic video's current probe-marker exclusion.
- Preserve display-only filters, independent color/opacity and one-time Quick
  setup, Point rendering without preset replay, independent slice/surface state,
  exact clocks, export timing, cancellation and output retention.
- Use [the workflow matrix](UX1_REGRESSION_WORKFLOWS.md), original inventory gates,
  current shell/transport/status tests, recipe/state, camera/probe, volume
  normalization/opacity/preset and scientific selection/analysis/export gates for
  affected later slices. Test equivalent inputs and rendering before/after,
  source hashes, stale work and zero scientific work on presentation navigation.
- #67 must move controls to their canonical surfaces as it removes sidebar
  access; it cannot leave menu items pointing at hidden or missing sections.
  Minimal reachable focused hosts can precede #69's final task composition.
  #68 implements the desktop grouping and compact fallback contract after #67 acceptance. #69 finishes
  focused forms; #70 audits all changed copy. #71 validates the merged result
  using current captures and small fixtures without rerunning solvers.

## Review evidence and owner verification

For #66, validation is documentary: inventory coverage, current source bindings,
menu/label review, geometry arithmetic, local links, whitespace and production
file invariance. The revised desktop calculations are not screenshots, usability
tests or native layout passes. No new native GUI, GPU, recipe or scientific regression is
claimed for this documentation-only change. Historical review reports and
screenshots are intentionally preserved, including their review-time wording.

Initial submission checks on 2026-09-22, with superseded layout evidence identified:

| Check | Result |
|---|---|
| Inventory set and uniqueness against original map | PASS: 96 of 96 entries, no duplicates |
| Proposed menu labels and forbidden characters | PASS: 54 labels |
| Local Markdown link targets across four changed documents | PASS: 95 targets exist |
| Initial compact-first arithmetic | Superseded by owner review; it is not the revised layout acceptance gate |
| Git whitespace and change-scope audit | PASS: four Markdown files only |
| Godot 4.7.2 headless editor import | PASS on unsandboxed rerun, exit 0 with no errors; no new UID files |

The initial sandboxed import exited 0 but logged local socket creation and editor
settings permission errors, so it was not counted as a clean pass. The authorized
rerun used `../Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path viewer --import`
and completed cleanly. Native interactive layout, physical DPI/monitor checks,
GPU rendering and scientific regressions were not run: this issue introduces no
production or engine inputs. The import is project hygiene, not UX4 validation.

Owner-review revision checks:

- PASS: all 96 disposition rows and all 54 menu labels are byte-for-byte unchanged
  from the initial PR commit `5c1e0d5`; all four distinct group labels comply with
  the naming rules.
- PASS: desktop initial/all-open height arithmetic for particles 636/724, mesh
  396/396 and field 516/644 pixels against the nominal 748-pixel desktop area.
- PASS: all 95 local link targets across the design, roadmap, status and README;
  removed obsolete fixed-height constraints; Git whitespace check.
- PASS: only this design, affected roadmap wording and one current-status sentence
  changed in the revision. README, production files and historical evidence are
  unchanged. All destinations, exclusions and scientific/state ownership remain.
- Native import was not repeated for this prose-only revision; the initial import
  result above remains historical. No native layout, GUI, GPU or scientific test
  is claimed for the proposed groups. The downstream issue specifications may
  still contain their original compact-first wording; this owner-reviewed design
  revision must govern their later scope reconciliation before implementation.
  No downstream issue or production implementation is changed here.

Before accepting this design, the owner should:

1. Review the menu tree and verify one destination for opening, both state types,
   all three exports, Performance and Geometry. Confirm no Settings menu.
2. Review the particle, mesh and field groupings at the 1440×900 desktop target.
   Confirm comfortable spacing, the named one-level groups and their initial
   states. Check that no group contains another category, submenu or expander.
   Native fit and readability remain required implementation gates.
3. Confirm lower-frequency Mapping, Quick setup, reset and field tools belong
   outside the permanent panel, and confirm Source probe belongs in Tools.
4. Trace a selection into Temporal and Space time, a CSV into Compare and Period,
   a bookmark into a manual offset, and a matched run into Jobs. Verify Results
   and every input, refusal and export remain reachable in the disposition.
5. Review field color/opacity labels with their separate meanings; verify the
   source-probe stamp and the distinction between Object and scientific binding.
6. Approve or request changes to this contract before #67. Later #68/#71 owner
   checks must inspect the standard 1440×900 and roomy 1920×1080 layouts, plus
   1024×640 fallback reachability with expansion and scrolling. Verify warnings,
   long source names, keyboard focus, hide/recovery, fullscreen and immersive, and equivalent
   state/export/scientific outcomes. Automated passes do not confer acceptance.

Stop after this issue's PR for owner review; do not start a dependent issue.
