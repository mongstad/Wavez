# Viewer information architecture — issue #14

**Design proposal, pending owner review. No production migration is authorized.**
Reviewed baseline: `68e3b5abb548d2e95ba5ae5b8e57e03d652de502` (2026-09-20).
Issue #14 is Ready in **Pre-UX3/UX4 — Validation & Maintenance**. Its revised
brief is design-only. [Roadmap](../UX_IMPLEMENTATION_PLAN.md) controls authorization;
[design system](UX1_DESIGN_SYSTEM.md) controls tokens; [UX2 library](UX2_THEME_LIBRARY.md)
supplies implemented primitives. This proposal elaborates the existing one-dock
hierarchy. It does not supersede those authorities or accept UX3/UX4.

Review alongside the [control map](UX_CONTROL_MAP.md), [walkthroughs and validation](UX_IA_REVIEW.md)
and [static wireframes](evidence/issue-14/wireframes.md). Every layout below is
proposed; current behavior is identified explicitly in the control map.

## Evidence and changes since UX1

The [UX1 audit](UX1_UI_AUDIT.md) is historical. Current source review includes
main, layer/playback, selection, all six analysis controllers, visual/inspection
state, video dialog and the current handbook. Fresh native layout observations
cover empty, combined, particle-only, mesh-only, field-only and an external
combined capture. These are controller-driven observations, not a timed human
study. Frequency judgments mean expected task frequency, not usage telemetry.

Changes since UX1 matter to placement: Point rendering/V no longer reapplies a
viewing preset; camera tumble crosses poles; source-probe marker visibility is
session-only; export continues through explicit offscreen draws with a minimized
worker; volume opacity is independent; color bounds can be frozen from a sample;
three explicit volume starting-point actions resolve into saved mappings.
The particle legend describes particles correctly. Missing field legend context
is a discoverability limitation, not a demonstrated stale-legend defect.

## Shell and ownership

At 1440×900 logical pixels use a 40-pixel command bar, 64-pixel transport and
24-pixel status line. One right dock starts at 360 pixels; resize between 320
and 560 subject to at least 640 pixels of viewport width. The resulting default
viewport is approximately 1080×772 before borders. A 1024×640 layout uses a
320-pixel dock and approximately 704×512 viewport. These are design allocations,
not runtime promises. Use a chooser at compact widths; four named workspaces
remain Scene, Appearance, Selection and Analysis. No permanent second sidebar.

| Region | Canonical home and always-reachable content |
|---|---|
| Command bar | Open; copyable capture identity/details; **State** menu (scene and analysis recipe actions explicitly named); Export; View; Help. Settings comes in UX5. |
| Viewport | Scientific image; Frame scene, Reset camera and pointer/navigation mode; concise sample/availability notices. Existing particle legend stays explicitly particle-scoped. |
| Context dock | Workspace chooser and object/request identity fixed above independently scrolling content. Context header names kind, channel and current source sample where relevant. |
| Transport | Previous/next union sample, Play/Pause, union-index slider, index/count, time mode, committed time, requested time while buffering, explicit seek, applicable rate and loop. |
| Status/jobs | Ready/Preparing/Unavailable; Jobs action with count and progress; durable failure indicator. Jobs opens fixed cancel/reopen actions and retained output/error details. |

Empty state: central **Open capture…** plus the same command-bar Open. They invoke
one operation. No disabled dummy scientific form. Failed open retains the existing
scene, with a durable error and Choose another capture action. While loading,
show source identity and actual preparation stage; unknown progress stays unknown.

View > Hide dock leaves a labeled **Show panels** edge button. Fullscreen retains
that button and **Exit fullscreen**. F1/F11 remain alternatives. Hidden UI cannot
trap a mouse-only user. Camera navigation does not require entering a property form.

Time labels are literal: the slider is **Sample index (union)** even in Recorded
time mode. Its equally spaced positions are not physical-time distances. Show
**Displayed t**, **Requested t** only when different, and contextual **Source sample t**.
Rate is **Samples / playback second** or **Recorded units / playback second**.
Video forms separately say **Recorded units / video second** and **Output frames / second**.
Unknown physical units remain unknown. Independent layers retain held/interpolated/
unavailable descriptions; a shared display time does not imply synchronous records.

## Context is not scientific selection

**Scene** owns the object list: name, kind, visibility, availability and source time.
Select a row to edit it. The row click changes presentation context only: no hiding
other objects, mapping reset, scientific membership change or source binding.
Visibility has a separate named checkbox. Enforce the existing single translucent
volume constraint with a visible reason; never silently hide another volume.
Metadata/source geometry and field Source probe live in selected-object details.

**Appearance** uses the same selected object. A persistent context control can
switch object without visiting Scene. Particle controls apply to the one supported
particle object; do not suggest unsupported independent particle populations.
Meshes retain only visibility, scalar/fixed color, finite range, colormap and
wireframe. Field volume, slice and derived surface are related representations,
with distinct availability, source and extraction semantics, not duplicate sources.

**Viewport presentation** is a named alternative in the Appearance context chooser.
It owns Scientific/Cinematic and other existing viewing presets, exposure, gamma,
bloom, camera orbit settings and display guides. It is never selected implicitly
when an object is clicked. Particle size/brightness and particle X-slice remain
particle-scoped. Label preset side effects before Apply: scene viewing presets can
change environment and particle presentation, unlike volume starting points.

**Source probe** shows target field/channel, world X/Y/Z, Probe, last result and
**Last probed at t=…** together with Show probe marker. Proposed provenance display
must capture time/channel with the explicit probe operation; the current text lacks
that stamp. This is a later UX4 presentation requirement, not implemented here.
Playback does not relabel a stored result as newly sampled. Hide marker changes
only the session cross; PNG honors it, deterministic video excludes it.

**Selection** pins an explicitly bound source snapshot and source object. Keep
Bind source snapshot separate from the scene object chooser. Definitions, exact
IDs/rows, geometric regions, predicates, cohorts, groups and gesture mode each
retain their semantics. Display filters do not modify membership; Copy display
exclusions is an explicit operation. A selected scene row is not a selected member.

**Analysis** opens one task form: Temporal, Space-time, Diagnostic CSV, Compare
series, Period estimate or Matched views. Every form shows effective source(s),
object, selection scope, channel/component, units and inclusive request range
before Run. Space-time and period must expose their current dependencies locally
through adapters to existing request state, not silently create different defaults.
Changing the task neither submits work nor rebinds its source. Forms can have
named secondary scientific options; there is no wall of expanded unrelated tasks.

**Results** is a subview of Analysis, with named result, provenance/source extent,
request, bounded preview, exact member lookup and paged complete values. A temporary
expanded workbench uses viewport space and returns to the previous scene/context;
it does not create a second dock. Missing support and finite-subtotal qualifications
remain visible. Numerical export exports full results, not preview pixels.

Performance is not appearance. UX3 exposes readiness/details; UX4 must retain a
reachable Performance dialog for existing controls during migration. UX5 can move
those controls into Settings > Performance after separate approval. Do not remove
existing budget access while waiting for UX5. Distinguish decoded cache, prepared
particle/mesh/field memory, GPU quota and G4 output quotas; they are not a single
process memory ceiling.

## Volume detail layout and disclosure

The object/channel/representation header remains visible above scrolling content.
The first loaded volume task shows Starting point, Color and Opacity summaries and
editors. Use concise rows, not giant accordions. Default order and state:

| Group | Initially visible | One named secondary disclosure |
|---|---|---|
| Object and representation | Name, field kind, channel, visibility, ray-march/slice/surface status, current source sample and unavailable reason | Metadata in Scene details; no nested metadata tree here |
| Display starting point | Optional action chooser, exact affected settings, Apply; Faint percentile inputs beside Apply, current values and saturation warning | None; no generic explanatory button |
| Color | Colormap, linear/log normalization, resolved min/max, frozen/manual policy, derivation channel/time and clipping status | **Derive range from sample**: symmetric or percentile inputs + Freeze; **Reset color** action remains explicit |
| Opacity | Linear scalar/Magnitude, zero/full thresholds and strength | Mapping details link, not hidden essential editors; explicit **Reset opacity mapping** |
| Sampling quality | Current ray step and units, concise quality/cost help | **Sampling details**: cap/preview limits; editor can remain on main row |
| Slice / clipping / surface | Three separate named collapsed groups; each header shows active state | Expand the selected task once for plane/distance, X clip, or threshold/Extract/Remove and status |

No generic Advanced drawer hides Color or Opacity. At small height the dock scrolls,
but header, current invalid/clipping summary and primary task action remain reachable.
Starting-point percentile inputs and Apply move as one block; never place Apply
across a scroll boundary from its inputs. At most one disclosure within a volume
task; full handbook detail opens separately. Current-value summaries do not require
expanding derivation tools. A wider dock is optional, not required to read a value.

Starting-point selector caption: **Apply once; mappings below define the view.**
After Apply, show a completion message with resolved settings, not an “active preset”
badge. Manual edits remain authoritative. Dense core sets stored percentiles to
0–100; Faint structure must display those actual inputs until explicitly edited.
Do not silently substitute 1/99. Signed requires both signs; density actions require
eligible nonnegative data; failed/range-budget-limited actions preserve prior state
and offer manual bounds. Preset eligibility/limits remain those in the
[preset contract](VOLUME_DISPLAY_PRESETS.md).

Color-only Freeze never alters opacity. Preset Apply changes only bounds,
color_mapping, opacity_mapping and colormap; never strength, step, particles,
camera or viewport presentation. Color clipping does not imply source truncation.
Ordinary logarithmic mapping requires positive valid data; unavailable samples
stay visibly unavailable. Particle interval/cyclic policies do not imply volume
interval scanning or temporal field interpolation. #9 remains separate.

## Wording, help and reset contracts

| Draft label / local guidance | Meaning and recovery |
|---|---|
| Color bounds — “Values outside these bounds use endpoint colors.” | Show clipping present and derivation t/channel. Edit bounds or explicitly Freeze again. |
| Opacity mapping — “Controls extinction independently of color.” | Linear uses scalar; Magnitude uses absolute scalar. Zero/full thresholds and strength remain separate. |
| Extinction strength / world unit — “Display strength, not calibrated physical opacity.” | Preserve existing `opacity` value and units semantics. |
| Ray step / world unit — “Smaller steps sample more finely at higher GPU cost.” | Details explain 1024-step cap; not a brightness correction. |
| Faint structure — “Values above the chosen upper percentile saturate.” | Show lower/upper inputs next to Apply, including inherited 0–100. |
| Apply starting point — “Replace this field's color and opacity mappings once.” | List exact colormap/mapping changes; preserve strength and quality. |
| Samples / playback second | Advances union sample indices; not monitor FPS. |
| Recorded units / playback second | Advances requested recorded time; source values still follow their sampling contract. |
| Save/Load scene recipe… | v2: scene/camera/time/visual state; not analysis definitions/results. |
| Save/Load analysis recipe… | v3: validated inspection with selections, analysis and referenced assets; results inclusion explicit. |
| Reset color to linear 0–1 | Only color bounds and color_mapping; not colormap, opacity, channel or other objects. |
| Reset opacity mapping to linear 0–1 | Only opacity_mapping; not strength, color or ray step. |
| Reset camera | Existing camera reset only; never reset source, selection or mapping. |
| Clear decoded cache | Evict decoded cache, not source data or all memory; preserve existing lifecycle. |

Help hierarchy: visible label/unit/state first; one actionable sentence or tooltip
second; keyboard-accessible focused details third; deep handbook anchor fourth.
Essential errors, clipping, unavailable samples, busy/cancelled actions and missing
prerequisites are visible status, never tooltip-only. Examples link to
[rendering](SIMSCOPE_HANDBOOK.md#inspection-and-rendering),
[time](SIMSCOPE_HANDBOOK.md#scenes-layers-and-time) and
[recipe ownership](../INSPECTION_STATE.md#recipe-ownership-and-restore-behavior).

This uses progressive disclosure and reduced memory burden as supporting design
principles ([GNOME](https://developer.gnome.org/hig/principles.html)). Supplementary
hover/focus content should be dismissible, hoverable and persistent while used
([W3C guidance](https://www.w3.org/WAI/WCAG22/Understanding/content-on-hover-or-focus)).
These references do not require GNOME styling or establish accessibility conformance.
No auto-binding or inferred scientific settings are justified by “reducing effort.”

## Drafts, focus and state transitions

Proposed keyboard order: command bar → viewport navigation → dock chooser/context
→ current form in reading order → transport → jobs. Provide named region-navigation
actions in Help and View; assign new shortcuts only after Nordic keyboard review.
Tab/Shift-Tab, Enter/Space on buttons, native menu arrows and Escape provide a
complete route; no essential operation depends on US bracket keys. Text/number
editors consume camera/playback shortcuts while editing. Selection gestures retain
input priority and never begin through chrome. Focus ring uses shared tokens.

Exact fields use UX2 NumberField's draft/commit contract: unchanged commits preserve
bits; Enter commits valid input, Escape restores committed text; focus loss retains
draft. Invalid drafts remain editable with local errors and last committed values.
Exact integers never pass through float. No new rounding/coercion for layout.
Immediate toggles/choices remain immediate where currently supported; analysis,
preset, derivation and export remain explicit actions. Do not turn Run forms into
live expensive recomputation. Moving a widget is not permission to change its model.

| Transition | Proposed focus/draft/job behavior |
|---|---|
| Switch object/workspace | Save in-session draft and scroll keyed by source generation + object + task. Do not commit. Restore when returning; persistent “Unapplied draft” indicator links back. |
| Collapse group | Preserve draft; move focus to its disclosure if focused child hides. Error count remains on group header. |
| Hide dock / fullscreen | Focus recovery action; preserve contexts. Restore previous valid focus on reopening. |
| Open/close dialog | Capture invoking focus; fixed actions; Escape closes panel/picker without submitting. Return focus to invoker or region fallback. |
| Hide running task/export | Job continues; persistent Jobs can reopen/cancel. Cancel requests acknowledgement; completed output remains. |
| Load recipe | Existing atomic validation first. If drafts conflict, explicitly Keep editing or Discard drafts and load; never silently commit. Refresh without edit signals; preserve session probe/disclosures per existing contract. |
| Replace capture | Existing controller lifecycle cancels/invalidates owned stale work. Confirm discarding unsaved drafts if necessary; do not carry drafts to same-named objects in another source. |
| Result completes while elsewhere | Durable Jobs notification, no stolen focus or forced workspace switch. |

New workspace/draft persistence is proposed session behavior. Disk persistence,
shortcut customization, settings reset and detachable windows belong to UX5/6/7.
No new recipe fields in this issue. Legacy slider/section/preset display labels
remain compatibility aliases even after UI wording changes. Retain inert reserved
fields, partial dictionary semantics, source-bound validation and v2/v3 readers.
The control map records current ownership; it must not be inferred from new location.

## Responsive and accessibility review targets

Use 14-pixel body, 13-pixel numeric, 12-pixel secondary text; 32-pixel controls
(28 compact), spacing 4/8/12/16/24/32. Opaque shared surfaces and focus/text roles
come from the design system. Static wireframes use these tokens; actual font,
assistive technology and physical DPI behavior still require later native tests.

| Physical target / scale | Logical space | Proposed allocation |
|---|---|---|
| 1440×900 / 100% | 1440×900 | 360 dock, four workspaces via chooser; 1080×772 viewport |
| 1024×640 / 100% | 1024×640 | 320 dock, stacked labels, two-row transport, 704×512 viewport |
| 3840×2160 / 100% | 3840×2160 | 360 dock; no stretched full-width property cards |
| 3840×2160 / 125% | 3072×1728 | Same logical sizes, one scale application |
| 3840×2160 / 150% | 2560×1440 | Same shell; more viewport, not more simultaneous forms |
| 3840×2160 / 200% | 1920×1080 | 360 dock; normal form/text metrics retained |
| 1024×640 physical / 200% | 512×320 | Below proposed minimum: recoverable collapsed dock; temporary full-width task sheet, fixed actions, scrolling body; no font shrinking. Native feasibility unresolved. |

Do not apply UI and OS scale twice. At widths below 1200 use one chooser; at
widths that cannot leave 640 pixels of viewport, collapse the dock with visible
recovery rather than overlap two panels. Titles/paths wrap or truncate with an
accessible copyable details action. Exact values use full-width rows as needed;
ordinary forms have no horizontal scrolling. Result tables may scroll horizontally
with stable column headers and exact copy/export. Error messages wrap and are not
overwritten by unrelated status updates. Text plus icon/shape conveys severity.

## Migration slices, rollback and owner decisions

Design acceptance and implementation authorization are separate decisions.

| Proposed slice (not started) | Boundary and regression gate | Rollback |
|---|---|---|
| UX3 shell/transport/status | Compose existing commands, timeline and readiness; preserve R01–04, R10–13 from [workflow gates](UX1_REGRESSION_WORKFLOWS.md). Empty/loaded/hidden/fullscreen, async seeks, source replacement, job reopen/cancel, screenshot/offline overlay coordinates. | Revert presentation shell/adapters together; retain original controller/state APIs. Keep old recipe aliases until covered. |
| UX4 object appearance/probe | Scene + particle + mesh + field context; R05–07/R10/R11 plus volume color/opacity/preset, camera and probe-marker validators. No new renderer capability. | Revert one consumer and its adapter; saved resolved mappings remain readable by old viewer. |
| UX4 selection and task forms/results | Explicit request summary, source binding, exact inputs and result workbench; R07–10/R13; lifecycle and bounded-preview coverage. | Revert task presentation independently; source/results and request format unchanged. |
| UX4 export composition | Typed State/Export entries, fixed actions and shared Jobs integration; R10–12, background worker and G4 failure tests. | Revert dialog composition; existing workers/publication paths unchanged. |
| UX5 / UX6 / UX7 / UX8 / UX9 | Settings / detachment / persisted workspace / interaction hardening / release validation, separately gated in roadmap. | No dependency on new persisted fields before their own compatibility review. |

Next proposed implementation slice is UX3 shell/transport/status **only after**
owner design acceptance and explicit authorization. Do not create issues or advance
milestones automatically. Preserve worker/cache ownership: no UI rebuild starts
hashing, scans, decode, texture upload or scientific jobs; no per-frame tree rebuilding.

Owner decisions still required:

1. Approve the single right dock, State menu naming and Scene/Appearance shared context.
2. Approve the volume default disclosure and compact scroll tradeoff: core mappings
   stay visible, but a complete form exceeds 512 pixels and requires local scrolling.
3. Approve temporary expanded Results and explicit draft-conflict behavior on recipe load.
4. Resolve below-minimum window policy during UX3 native feasibility review (minimum
   size versus temporary full-width sheet), without claiming this mockup supports it.
5. Approve adding a last-probe provenance readout in the later consumer migration;
   current stored text alone cannot accurately reconstruct an old probe time.

Future dual per-layer legends (#37) have a reserved viewport overlay location with
layer/channel labels and independent visibility; this proposal implements no new
legend and changes no priority. Marker styling (#32), selection padding (#24),
field interpolation (#9), universal volume defaults and later UX features remain
outside scope. No open question grants implementation authorization.
