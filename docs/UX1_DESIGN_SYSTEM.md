# Wavez design system — Midnight Scientific

**Current design specification, reconciled by issue #8.** UX1/UX2 and issues
#5–#7 are accepted. The [UX plan](UX_WORKFLOW.md) governs milestone
scope; this document specifies tokens and design rules; the
[theme library](UX2_THEME_LIBRARY.md) documents implemented primitives. The
original [UI audit](UX1_UI_AUDIT.md), milestone reports and their evidence remain
historical. The shared theme and laboratory are implemented and opt-in. Shell,
panel, settings and workspace proposals below remain future work; UX3 is on hold.

## Design decisions

Make the scientific viewport the visual center. Use opaque Midnight Scientific blue-black chrome, compact forms and restrained blue for interaction. Keep scientific color maps, selection highlights, geometry guides and missing-support encodings independent of application chrome. Changing a theme must not change field colors, normalization, camera exposure, source interpretation or exported science.

Keep the existing renderer and scientific controllers. Introduce reusable presentation components and stable semantic identifiers around their current operations. Prioritize access to Open, transport, current source/time/readiness, viewport navigation and export. Detailed caches, analysis assumptions and export limits remain available with accurate explanations.

Default density is compact desktop, with 32 logical-pixel controls and 14 px body text. Avoid translucent panel backgrounds, oversized cards, gradient-filled controls, rounded pill controls, decorative shadows and animated scientific content. Do not make a UI preset silently select a different scientific viewing preset.

UX-STYLE-002 permits a static, opaque, low-contrast atmospheric gradient on an
explicitly opted-in application background. The shared `AtmosphericSurface`
uses a single diagonal ramp from `atmosphere.start` (`#111E30`) to
`atmosphere.end` (`#0B101B`), with endpoint contrast below 1.2:1. Keep normal
controls, panels, popups and diagnostic surfaces flat and opaque. No bright,
rainbow or animated gradients; never apply this background to a scientific
viewport, colormap or export. The laboratory demonstrates this treatment;
production migration remains separately gated.

## Proposed information hierarchy

Issue #14 elaborates this hierarchy in the [information architecture](UX_INFORMATION_ARCHITECTURE.md),
[control map](UX_CONTROL_MAP.md) and [annotated walkthroughs](UX_IA_REVIEW.md).
Those documents are a pending design proposal, not production implementation or
milestone acceptance. The one-dock baseline and tokens below remain authoritative.

This is a placement specification for UX3/4, not a new layout implementation. Default to **one 360 px right-side workspace dock**, not two permanently open sidebars. The viewport occupies the remaining central/left region. Right-side placement is a design recommendation, with usability review in UX3; dock relocation/detachment belongs to UX6. Do not expose a second dock by default.

```text
┌──────────────────────────────────────────────────────────────────┐
│ Open   capture name / source state          Export   View   Help │ 48
├──────────────────────────────────────────┬───────────────────────┤
│                                          │ Workspace chooser     │
│ Scientific viewport                      │ Scene / Appearance /  │
│                                          │ Selection / Analysis  │
│ camera and pointer-tool affordances      │                       │
│ compact sampling/LOD warning + legend    │ context + controls    │
│                                          │ independent scroll    │
├──────────────────────────────────────────┴───────────────────────┤
│ Step  Play/Pause  union-sample timeline  time mode  time / rate   │ 64
├──────────────────────────────────────────────────────────────────┤
│ Ready / Preparing / Unavailable          active jobs / details   │ 24
└──────────────────────────────────────────────────────────────────┘
```

Issue #40's owner refinement makes the command bar 48 px tall with 32 px controls
and 8 px top/bottom padding. At 1440×900, a 360 px dock leaves approximately
1080×764 for the viewport before separators. At a 1024×640 logical desktop
window, a 320 px dock leaves approximately 704×504. The transport may use two
rows within its 64 px allocation. These are layout targets to validate, not
current supported-size promises. A 44 px icon rail with accessible names may
replace the open dock when collapsed; a visible Restore panels action must
always remain. Fullscreen preserves that recovery action. F1 remains compatible.

UX3/UX4 target desktop keyboard and mouse/trackpad. The compact layout is not a
mobile or tablet design. Touch-first controls, touch gestures and touchscreen
target sizing require a separately authorized future milestone; desktop keyboard
accessibility, focus, scaling, contrast and usable pointer targets remain required.

For logical widths below 1200, use one workspace chooser rather than six crowded tabs. The dock can grow from 320 to 560 px; the viewport must retain at least 640 logical pixels while a dock is expanded. Below the proposed 1024×640 minimum, constrain the window or offer a clearly recoverable collapsed-dock layout; never shrink text to fit. Dialogs get a scrollable body and fixed action row. Analysis plots may expand within the viewport region as a temporary workbench; they do not require a permanently open second panel.

| Location | Content / scope | Persistent versus contextual |
|---|---|---|
| Command bar | Open `.ssc`; current capture name and source status; State menu with typed scene/analysis recipe actions; Export menu; View/panels/fullscreen; Help/shortcuts; Settings entry in UX5 | Persistent. Long paths/details in a copyable source-information view |
| Transport | Previous/next union sample, Play/Pause, index slider, explicit mode, requested physical time, committed time, applicable rate, loop | Persistent. Mode-specific rate; readiness disables unsafe actions with a reason |
| Viewport edge | Orbit/pointer mode, Frame scene, reset, concise sample/LOD warning, scalar legend | Near viewport; avoid occluding the active selection area. Detailed sampling text opens on demand |
| Scene workspace | Object list with kind, visibility, availability and source sample time; selected object details; geometry metadata; display guides are edited in Appearance > Viewport presentation | Frequent layer switches and visibility. Source probe in Scene details; slice/isosurface editing in Appearance for that field |
| Appearance workspace | Selected object's color/channel/range/colormap; particle size/brightness/history/type display filters; mesh wireframe; volume representation | Contextual by object capability. Display filters remain separate from selection membership |
| Selection workspace | Pinned source/layer, pointer/edit mode, exact selection list; selected definition; IDs/rows/ROI/predicates/cohorts/groups | Contextual. “Use current capture” becomes “Bind source snapshot”; never bind a changed source implicitly |
| Analysis workspace | Task selector: Temporal, Space-time, Diagnostic CSV, Compare series, Period estimate, Matched views; shared visible request context; results | Request controls only for chosen task. Source/range/channel/units always explicit |
| Results workbench | Named results, full provenance, bounded plot, exact address lookup, paged values, numerical export | Opens for a selected result. Keep full-result export available independently of plot resolution |
| Export entry | PNG; Video; numerical data; links to matched views. Typed scene/analysis recipes live in the command-bar State menu | One discoverable entry, distinct scopes and existing publication rules. Do not route v2 files into a v3-only loader |
| Settings (UX5) | Interface scale/density; application defaults; scoped resource budgets; screenshot/output defaults; shortcuts | Infrequent preferences. Current source/analysis assumptions stay in workspace |
| Status / jobs | Readiness, active operation count, durable failure/success details and recoverable paths | Compact persistent summary; contextual inline validation remains next to the field |

### Terminology rules

Use sentence case for controls; noun section titles; verbs for actions; ellipsis when more input is required. Symbols supplement labels. Name the affected object for destructive or expensive actions. Avoid unexplained slashes and bullets in control names; retain units in a separate suffix/help field.

| Current wording | Proposed user-facing wording / semantic distinction |
|---|---|
| Focus particles | Frame scene; optional Frame selected object later only if separately supported |
| Frame index • union samples | Sample index (union); “frame” reserved for rendered video frames where possible |
| Physical time • recorded timestamps | Recorded time; slider still represents union sample index |
| Playback • frames / second (index mode) | Samples per second; never presented as display FPS |
| Physical time units / second | Recorded time units per playback second; show declared source unit, or “unknown” |
| Point rendering / V / Scientific preset | Point rendering / V changes particle representation only; viewing presets own backdrop/bloom/exposure defaults |
| Size by / Particle size | Size channel / Size multiplier; distinguish data mapping from visual scale |
| Save inspection recipe (two locations) | Save scene recipe… / Save analysis recipe…; load actions state matching scope |
| Source layer / Scene layers | Source object in scientific requests; Layer for its visible representation, with kind shown |
| Particle Filters | Display type filters; scientific predicate called Selection value filter |
| Exact / interpolated / held / unavailable | Preserve distinct sampling states; “exact source sample” does not assert infinite GPU precision |

These are label proposals. Existing serialized labels and schema fields remain mapped through compatibility adapters; no UI wording is a wire-format migration. Do not rename scientific array keys, object IDs, units or user-created selection names.

## Tokens

All dimensions below are logical UI units at scale 1.0. Colors are opaque sRGB hex. Tokens are semantic roles, not a license to recolor scientific data. Original UX1 [contrast evidence](evidence/ux1/contrast.json) describes the historical palette. Current measured contrast and scale results are in the [issue #8 validation report](UX_STYLE_VALIDATION.md). Neither is a whole-product accessibility certification.

### Surfaces and text

| Token | Value | Use |
|---|---|---|
| `surface.0` | `#0B101B` | App background / viewport-adjacent chrome; does not replace scene background |
| `surface.1` | `#111A29` | Primary dock and toolbar |
| `surface.2` | `#1A2638` | Grouped property area, inputs, result rows |
| `surface.3` | `#243249` | Popups, menus, dialogs, tooltips |
| `surface.hover` | `#2C3C54` | Hovered neutral control |
| `surface.pressed` | `#354862` | Pressed neutral control |
| `text.primary` | `#E6EAF0` | Body, active values, headings |
| `text.secondary` | `#B9C1CC` | Supporting labels, units |
| `text.muted` | `#9AA5B3` | Help and secondary metadata; still readable |
| `text.disabled` | `#737C89` | Inactive value only; disabled reason uses secondary text |
| `text.numeric` | `#E6EAF0` | Exact values, time, IDs; monospaced/tabular face |
| `border.subtle` | `#465B76` | Decorative separators; never the sole control/focus boundary |
| `border.control` | `#798FAE` | Input outline where boundary is needed |
| `focus.ring` | `#A8C9FF` | Keyboard focus, 2 px with 2 px gap |

Normal text must reach 4.5:1 against its actual background; meaningful icon/focus/control indicators target 3:1. Primary, secondary and muted text pass the four current base surfaces. Muted text is restricted to base surfaces: use secondary text on hover/pressed fills. Disabled controls are intentionally exempt from the normal-text target, but their explanation is not. Do not render semantic colors at arbitrary low opacity.

### Interaction and semantic colors

| Token | Value | Required companion meaning |
|---|---|---|
| `accent.primary` | `#8CB8FF` | Primary action or link, used sparingly |
| `accent.foreground` | `#142035` | Text/icon on filled primary action |
| `identity.purple` | `#B4A2DC` | Sparse identity marks only; not status, tiers or scientific data |
| `identity.teal` | `#79BFC4` | Sparse identity marks only; not status, tiers or scientific data |
| `selection.fill` | `#233F68` | Selected UI row/tab; independent of scientific highlight |
| `selection.text` | `#DCEAFF` | Selected row text, also has check/marker |
| `state.success` | `#7FD1A7` | Completed / verified, with status text |
| `state.warning` | `#E8BF72` | Limited or missing support, with reason |
| `state.error` | `#F08C91` | Failed / invalid, with actionable text |
| `state.info` | `#9CBEE8` | Informational operation/source status |

Use semantic color for an icon, left rule or short status label; ordinary explanation stays primary/secondary. A warning does not turn a whole panel orange. A selected object and a selected scientific member are distinct roles. Existing viridis/cyclic maps, missing/mixed-support plot colors and selection overlay colors retain their scientific keys; any later change needs legend and export regression review.

### Geometry, spacing and typography

| Token family | Values / rule |
|---|---|
| Spacing | 4, 8, 12, 16, 24, 32. 4 label-to-help/label-to-input; 8 property-row gap; 12 panel padding; 16 major group separation; 24 dialog padding; 32 only between major regions |
| Control height | 32 default; 28 compact tables/tool rows; 40 only explicitly large primary empty-state action. Multi-line controls grow |
| Corners | 0 shell/docks; 4 buttons/inputs/selection; 6 popups/dialogs. No pills |
| Borders | 1 px normal; 2 px focus. Snap physical edges consistently when scaling; avoid double adjacent borders |
| Icons | 16 default, 20 prominent; consistent 1.5–2 px stroke at design size. 28 or 32 px hit box; no emoji or font-dependent arrow glyph as the only command name |
| Scrollbars / splitters | 10 px visual scrollbar in a 14 px interaction lane; 6 px splitter with 10 px hit region and resize cursor |
| Property row | Label column 112–144 px, field flexible, explicit unit suffix; stack label above editor if available row width <320. Exact IDs/paths get full-width row and copy affordance |
| Dock / forms | Dock 360 default, 320–560 adjustable subject to viewport minimum; controls expand to available width; long text wraps or ellipsizes with exact copyable details |
| Dialog | 640 default form width; video/matched form up to 800; maximum 90% usable window width/height. Fixed title and action areas; only body scrolls |
| Plot / table | Minimum 240×200 inline preview; expanded result workbench target ≥640×300; table uses tabular numbers and horizontal scrolling for exact columns, never silent data truncation |

Typography uses the **Godot fallback sans face** and bundled **DejaVu Sans Mono
2.37** for numeric roles, with notices in `viewer/ui/fonts/`. UX2 verified numeric
glyphs and tabular advances; no OS substitution is required. Font metrics may
expand controls but must never change stored numeric formatting or precision.

| Role | Size / emphasis | Rule |
|---|---|---|
| Application title | 18 / semibold | One per primary surface; OS title may use native metrics |
| Panel title | 16 / semibold | Selected workspace or result |
| Section heading | 14 / semibold | Sentence case, no all caps |
| Property label / body | 14 / regular | Primary/secondary according to role |
| Help / units | 12 / regular | Muted on base surfaces; essential instructions may use 14 |
| Numeric / diagnostic | 13 / regular mono | Exact IDs, values and times; right-align comparable columns |
| Compact status | 12 / regular | Short readiness text; full explanation in details |

Allow at least 1.3× font-size line height where layout permits and expand controls for fallback glyph metrics. Font size must not be reduced to conceal overflow. Supported laboratory interface scales are 100%, 125%, 150%, 200%; density changes spacing, not scientific numeric precision. Design scale and physical device scale must be applied exactly once. Root window, independent dialogs and exported SubViewports need separate tested scale contexts. Export overlay geometry stays pinned to the job's existing logical coordinate convention until a versioned change is approved.

### States and motion

The following durations are design limits for later authorized interaction work.
Current UX2 uses immediate native state changes, no tweens and a 500 ms initial
tooltip delay. Adjacent-target delay and reduced-motion preferences are deferred;
static atmospheric backgrounds never animate.

| State / transition | Visual / behavior contract |
|---|---|
| Rest / hover / pressed | Neutral surface 2 → hover → pressed; 80 ms hover transition, immediate press, 60 ms release. No control movement |
| Focus | Persistent ring independent of hover/selection; never removed because mouse leaves |
| Selected / checked | Selection fill + text + check/indicator. Disclosure uses chevron direction and expanded state, not only color |
| Disabled / unavailable | Stable layout; subdued value and explicit reason. Do not hide a capability explanation behind an unfocusable tooltip only |
| Busy | Show current stage and committed state; indeterminate if progress unknown. Cancel requests cancellation; remain busy until acknowledged |
| Invalid | Error border/icon plus inline text; retain editable draft and last valid committed model. Do not replace an exact number with a rounded fallback |
| Empty | Name missing prerequisite and primary next action; empty scene offers Open capture |
| Panel expansion | Immediate layout by default. Optional 100 ms opacity reveal only if it does not shift focused content or trigger re-render work |
| Dialog / workspace transition | 100 ms fade maximum; no sliding/scaling viewport or camera motion |
| Notification | 100 ms enter, 80 ms exit. Success may expire after 5 s and remain in job details; errors/cancellation recovery paths persist until acknowledged |
| Tooltip | 500 ms initial delay; 100 ms for adjacent related targets; max 360 px and wrap. Show shortcut/units/reason, not essential hidden requirements |
| Reduced motion | Zero-duration transitions, no animated progress decoration; meaningful progress numbers remain. UX5 preference, UX8 acceptance |

No easing curve or tween may change scientific time, requested/committed sampling, GPU values or export frame count. Do not animate numeric plot data to imply unrecorded samples.

## Component and state architecture

### Ownership

| State owner | Responsibilities | UI may do |
|---|---|---|
| Application/session | Current capture lifecycle; active jobs; output destinations; application preferences | Request open/replace/cancel; display immutable status; no reader ownership in a widget |
| Capture/scientific | Source identity and committed extent; exact IDs/arrays; layer availability; selection definitions, units, queries/results | Edit typed request drafts and submit through validated commands; never infer membership from display |
| Rendering | Committed sampling, camera, layer representations, mappings, GPU resources, frozen render snapshots | Request validated visual changes; read committed state; never write shader state from theme code |
| Presentation/workspace | Active workspace, expanded groups, scroll/focus, dock width, UI scale and theme | Own these preferences independently, with explicit conversion for old native recipe fields |

Proposed flow: **Control intent → presenter/controller operation → validated model/committed result → read-only view state → control refresh**. Signals update only changed fields. Initialization and refresh use no-signal setters to avoid accidental work. Controller results retain capture generation and revision checks. No new web service, remote command bus, plug-in framework or AI surface is proposed for UX1/2.

### Reusable component contracts

| Component | Inputs / outputs | Ownership and acceptance boundary |
|---|---|---|
| `ActionButton` / `IconAction` | Stable action ID, label, shortcut, enabled reason; emits invoked | Never stores capture or worker; keyboard name and tooltip for icons |
| `SectionHeader` / `Disclosure` | Stable section ID, title, expanded state; emits toggle | Explicit body reference; no searching labels or reparenting sibling ranges |
| `PropertyRow` / `PropertyGroup` | Label, editor, unit, help, validation; responsive stacked layout | Common alignment/padding and focus order; does not choose numeric conversion |
| `ScientificNumberField` | Float64 model, exact round-trip text, finite/range validator; draft/commit/cancel | Preserve unchanged value bit-for-bit; scientific notation; distinguish draft from committed value |
| `ExactIntegerField` / `MemberAddressField` | Decimal text/typed exact ID, namespace/address kind; validated commit | Never route through floating point; support int64 extremes and IDs >2^53 |
| `ScalarSliderRow` | Approximate display parameter, bounds/step, readout/editor | Explicitly for visual multipliers/rates where supported; no silent replacement of scientific editors |
| `EnumField` / `ChannelSelector` | Stable option IDs, labels, availability/units; selection intent | Dynamic options preserve selection identity; unavailable entry explains why |
| `BooleanProperty` | Label, value, capability/reason | Check/toggle role distinct from disclosure and action |
| `ObjectRow` / `SelectionRow` | Stable key, kind, name, visibility/presence/sample state; selected/visibility intent | No source lookup or membership computation in row rendering |
| `StatusBadge` / `InlineMessage` | Severity, concise message, detail/action | Text/icon supplements color; changing text does not move transport |
| `JobStatus` / `Notification` | Job ID, stage/progress, cancellation capability, output/recovery path | Dialog close is not job cancel; controller owns lifetime |
| `DialogShell` / `PathField` | Title, body, actions; selected path and cancellation | Fixed actions; native picker strategy isolated; no change to overwrite/publication policy |
| `TransportBar` | Committed/requested time, union index/count, mode/rate/readiness; playback/seek intents | Composition in UX3; no timer, interpolation, preloader or source reader in component |
| `RangeEditor` / `MappingGroup` | Channel semantics, bounds/policy, log/cyclic capability; validated intents | Composition in UX4; preserve signed-log refusal and frozen interval identity |
| `PlotFrame` / `ResultTable` | Bounded preview/result metadata; exact detail/page/export intents | Reuse existing plot algorithms. Missing/gap markers and full data export remain distinct |
| `SourceContext` | Pinned capture/object/range/channel/units/provenance | Visible before scientific actions; rebinding requires an explicit user operation |

`TransportBar`, object workspaces, analysis forms and result workbench are future consumers of the library. UX2 demonstrates primitive components and their states in its development UI laboratory; it does not migrate these application workflows.

### Implemented theme/token resources

Current shared library paths (introduced in UX2):

```text
viewer/ui/theme/wavez_tokens.gd        # typed semantic token Resource
viewer/ui/theme/wavez_dark.tres        # Godot Theme + style/type variations
viewer/ui/theme/wavez_tokens.tres      # one canonical token instance
viewer/ui/fonts/                         # bundled numeric face and notices
viewer/ui/icons/                         # consistent SVG command icons
viewer/ui/components/                    # reusable controls/scenes
viewer/ui/lab/                           # UX2-only development showcase
```

Use Godot Theme variations for PrimaryButton, SecondaryButton, DestructiveButton, SectionHeader, PropertyLabel, HelpLabel, NumericValue and compact variants. The theme builder derives StyleBox/font/color constants from the one token Resource; generated values must not become a second editable source. Prefer inheritance and containers over scattered per-node overrides. Windows must receive the same Theme explicitly where inheritance does not cross a viewport/window boundary. Plot chrome reads semantic tokens; scientific palettes remain in their current resources.

Centralize UI scale conversion in the theme/presentation boundary. Components accept logical sizes; do not multiply both root scale and each font/spacing token. Theme changes must not allocate scientific textures, call `_restyle`, restart workers, rehash captures, rebuild mappings or advance time. Avoid connecting each control to the process loop. Dispose signal connections on widget replacement without cancelling application-owned jobs.

### Compatibility and rollout rules

1. UX2 provides tokens, theme, primitive controls and a development showcase without replacing the viewer's visual state model. Assert existing viewer behavior stays intact when only the library is loaded.
2. Introduce semantic IDs such as `playback.index_rate`, `appearance.particle_size`, `workspace.camera` in adapters when migrating consumers. Maintain an explicit mapping to existing native recipe labels such as `Playback • frames / second (index mode)`, `Particle size` and `Camera`. Keep reserved inert fields readable. Do not edit frozen recipes to conceal incompatibility.
3. Move one consumer at a time in its authorized milestone. Verify snapshot/apply round trips, no-signal refresh and exact numeric commits before moving the next. Application tests should gradually assert stable command/model behavior, while retaining coverage for old recipe aliases.
4. Separating presentation settings from rendering requires a compatibility layer: v2 scene and v3 analysis recipes remain readable; current deterministic export still receives its expected overlay state. A new schema/version needs its own reviewed decision, not a cosmetic-change side effect.
5. Preserve preset scientific behavior and user preferences during styling. A proposed new shell may change UI-containing screenshot pixels; viewport-only scientific rendering, timing and exact sidecars must remain unchanged. Review UI-containing golden images deliberately with the corresponding milestone.

## Review decisions and later evidence

The one-dock hierarchy and workflow label proposals remain gated by UX3/UX4.
UX2 already validated font packaging, widget metrics, keyboard states and
contrast. Issue #8 revalidates the Midnight Scientific refinement across all
five laboratory pages and scales; see [results and limits](UX_STYLE_VALIDATION.md).
Physical 4K, mixed DPI and assistive-technology acceptance require available
hardware and owner review. See [regression gates](UX1_REGRESSION_WORKFLOWS.md)
before any later production consumer migration.

## Categorical tier accents — issue #7

Tiers are UI categories, independent of operational severity and scientific data.
Use the shared `TierLow`, `TierMedium`, `TierHigh`, `TierXHigh` and `TierMax`
Label variations for compact 12 px labels on opaque base surfaces. Always spell
out the tier; ordinal cues may supplement the label. Never rely on color alone,
fill entire panels with a tier color, or replace status icons/text with tiers.

| Tier | Token | Color |
|---|---|---|
| Low | `tier.low` | `#B8C2D1` (slate) |
| Medium | `tier.medium` | `#62D5DB` (cyan) |
| High | `tier.high` | `#80ACFF` (blue) |
| XHigh | `tier.xhigh` | `#BC9AFF` (violet) |
| Max | `tier.max` | `#EFA5DF` (orchid) |

Amber Warning and red Error retain their operational meaning, icons and wording.
A Max tier can have Success status; a Low tier can have Error status. The Tiers
laboratory page shows these combinations side by side. Tier colors never define
scientific magnitudes, normalization, colormaps, selection or renderer state.
No production consumers or scientific behavior are changed.
