# Viewer visual language — issue #40

**Revised proposal for owner review. Not accepted or implemented.** 2026-09-20.
Issue [#40](https://github.com/mongstad/SimScope/issues/40) was confirmed as the
only Ready item in **Pre-UX3/UX4 — Validation & Maintenance**. It revises
[PR #39](https://github.com/mongstad/SimScope/pull/39) on the existing
`issue-14-information-architecture` branch. The owner did not accept the original
user-facing visual/copy direction. This document and the
[new mockup gallery](evidence/issue-40/README.md) supersede that direction.

The [information architecture](UX_INFORMATION_ARCHITECTURE.md),
[96-row control map](UX_CONTROL_MAP.md) and
[workflow research](UX_IA_REVIEW.md) retain their semantic authority. Original
wireframes remain historical structural evidence, not the proposed visual target.
Inventory destinations still called Display starting point or Sampling quality
map to Quick setup or Volume quality respectively. Those traceable inventory
terms and source labels are not prescribed visible copy.
There is no production code, scientific mapping, controller, recipe, export,
capture, renderer or dependency change. UX3 has not started.

## Visual proposal and semantic contract

| High-fidelity visual proposal in this revision | Preserved semantic contract |
|---|---|
| Visible two-by-two workspace navigation at desktop widths; compact chooser below 1200 logical pixels | Scene, Appearance, Selection and Analysis remain one contextual dock |
| Separate object name, kind icon, visibility action, sample status and channel control | Row context does not bind a source or change scientific membership; visibility remains independent |
| Color and Opacity headings with labeled fields and quiet state badges | Independent mappings, explicit derivation, sample provenance, clipping and scoped resets |
| Named Quick setup disclosure, action chooser, percentile inputs beside Apply | Dense core/Faint structure/Signed field are one-time actions; no saved or active preset mode |
| Primary/secondary/icon/toggle/menu/disclosure hierarchy | Existing immediate versus explicit-action behavior and UX2 draft/commit contract |
| Persistent visual transport and Jobs button | Union sample index, requested versus displayed time, independent source samples, job ownership and cancellation |
| Compact plot/table presentation and temporary expanded Results | Full-result export, bounded preview, units/support/provenance, source binding and exact values |

Three small composition corrections are intentional: the optional Quick setup
body starts collapsed in the ordinary Appearance view; all workspaces are visible
at normal widths; Jobs uses a 32-pixel action in the transport beside the 24-pixel
status line. The owner's final refinement expands the command bar from 40 to
48 pixels, preserving 32-pixel controls with 8-pixel top/bottom padding.
No control ownership or persistence changes follow from these placements.

## Platform and input scope

UX3/UX4 target **desktop keyboard and mouse/trackpad** input. Compact layouts
mean small desktop windows, not mobile or tablet navigation. Touch-first controls,
touch gestures, tablet navigation, mobile layouts and touchscreen-specific target
sizing are outside this design. Touch/tablet support requires a separately
authorized future milestone. Desktop keyboard accessibility, visible focus,
scaling, contrast and usable pointer targets remain required. The current 32-pixel
controls are desktop targets, not a touch-support claim.

## Midnight Scientific composition

The generator reads colors directly from
[the accepted token resource](../viewer/ui/theme/wavez_tokens.gd). It does not
write to that resource. The [UX2 component contracts](UX2_THEME_LIBRARY.md) remain
authoritative for native implementation.

- **Surfaces:** blue-black `surface.0` through `surface.3`; flat opaque panels,
  editors and menus. The restrained `atmosphere.start` → `atmosphere.end` gradient
  is confined to the application chrome. It never colors the scientific viewport.
- **Type:** 18-pixel object titles, 16-pixel section titles, 14-pixel labels,
  12-pixel secondary metadata and 13-pixel bundled DejaVu Sans Mono numbers.
  Installed Noto Sans and Semibold approximate native fallback/heading roles in
  these static figures. They are not bundled and are not a native font-equivalence
  claim. No text is shrunk to fit a form.
- **Geometry:** 32-pixel controls, 4-pixel control radius, 6-pixel popup radius;
  4/8/12/16/24/32 spacing; 128-pixel property-label column. Long threshold labels
  wrap into two lines. Exact IDs use the full available width. Both normal and
  compact command bars are 48 pixels tall with controls at y=8 through y=40.
- **Interaction:** blue fill identifies a primary action; secondary buttons have
  a visible boundary; quiet disclosures retain a chevron and hit area. Selection
  uses `selection.fill` and a leading icon/label. Focus has a separate 2-pixel ring
  and 2-pixel clearance. A selected workspace is not a scientific selection.
- **Feedback:** warning, error, success and info retain their semantic tokens,
  words and vector icons. A selected blue control is not a success signal.
  Purple/teal are confined to the small brand marks, not scientific quantities.

The dock is 360 pixels at 1440×900 and 320 pixels at 1024×640; the updated viewport
allocations are 1080×764 and 704×504 before separators. Its context header
stays fixed while its body scrolls. Large screens gain viewport area, not an
unbounded property column. The compact screenshot shows a local task, not a claim
that the entire volume form fits without scrolling. Color/Opacity are outside
generic Advanced controls. Opening Quick setup focuses that task; closing it
returns space to the editable mappings.

### Vertical and optical alignment

Center button labels and dropdown contents within the control's height using a
shared font baseline per row; align by glyph metrics rather than a guessed top
offset. Numeric content uses its numeric font metrics. Center chevrons and toolbar
and transport icons in 16-pixel slots, vertically on the control midpoint.
Icon-only buttons also center the slot horizontally, including the wider Play
button. Small placement offsets center the existing provisional drawing within
its slot; the icon paths are unchanged. Labels and icons must appear balanced
when viewed together, without shifting adjacent controls' baselines.

The static generator uses a cap/descender reference for label baselines and a
digit reference for numeric fields. Visible ink may differ from the reference
midpoint by up to 2 pixels for different glyph shapes. Static checks record these
offsets and slot centers. Native pixel-perfect font/icon placement, scaling and
optical review remain UX3 validation tasks, not results of this static check.

## Icon and control language

[The specimen sheet](evidence/issue-40/components.png) demonstrates a **provisional** icon family
and actual button/menu shapes. [The SVG sprite](evidence/issue-40/icons.svg) and
generator retain original, reviewable vector geometry: a 16-unit grid,
1.5-unit outlines, round caps/joins and consistent optical margins. Existing UX2
play/copy/chevron geometry is retained; additional commands are documentation-only
proposals. There is no icon font, emoji, imported icon package or production asset.
This issue does not finalize or expand the artwork. Native icon quality and
optical refinement can be reviewed in UX3 and finalized in UX8, each under its
own authorization. These stages do not authorize work now.

| Pattern | Names and behavior contract |
|---|---|
| Toolbar icon + label | Open, State, Export, View, Help; menus have a separate down chevron |
| Viewport actions | Frame scene, Reset camera and Navigate retain readable labels |
| Transport | Previous sample, Play/Pause, Next sample and Loop playback have vector icons; native consumers must expose these exact accessible names and focused tooltips |
| Visibility | Eye/struck eye; accessible action changes between Hide/Show plus object name |
| Context/navigation | Distinct scene, adjustment, selection, chart, particle, mesh and field drawings supplement their names |
| Details/disclosure | Info opens focused details; chevron expands the named group; Close returns focus |
| Copy | Copy result/value is labeled when space permits; icon-only copy has its exact name in a tooltip/accessibility property |
| Primary action | Apply, Probe source, Create selection or Run analysis; never a bracketed text string |
| Metadata badge | Symmetric, Locked, Complete, Earlier sample; 24-pixel noninteractive metadata, visually distinct from 32-pixel actions |

Locked means fixed color bounds across playback, not read-only editors. It is not
a toggle or a claim that opacity is locked too. Metadata details explain the
derivation channel/time. Menus preserve typed **scene recipe** and **analysis
recipe** names. No visual simplification changes legacy serialization labels,
identifiers, partial restore behavior or v2/v3 state.

## UI copy style guide

Sentence case applies to **every Wavez-authored heading, label, button, menu
item, option and status**, not just section headings. Preserve source-defined
object/channel names, proper names such as Wavez and Midnight Scientific,
established acronyms such as IDs, and conventional unit casing. Do not rewrite
source metadata or sentence-case proper names to enforce style.
Underlying schema keys and historical source labels remain unchanged.

Use `Population counts` consistently for the analysis and its results. Keep the
top-level menu name `State`.

| Rule | Use | Avoid |
|---|---|---|
| Sentence case | `Quick setup`, `Source probe`, `Recorded history` | Title Case Everywhere, uppercase emphasis |
| Section titles | Short nouns naming a task or quantity: Color, Opacity, Volume quality | Packing values, algorithms, provenance or instructions into a heading |
| Redundancy | `Analysis type` labels the `Population counts` selector | A Population counts heading immediately repeating the selected option |
| Action verbs | Open, Apply, Probe source, Create selection, Run analysis, Copy result, Reset color | Bracketed pseudo-buttons, vague Go outside a clearly labeled seek field |
| Range command | `Use full range` for an immediate action; `Full layer range` only for a mode/option | `Use full layer range` on the action button |
| Illustrative names | `Particles`, `Scalar field`, `Mesh`, `Example selection` | Domain-specific names in generic mockups; source-defined names remain verbatim |
| Status names | Ready, Preparing sample…, Unavailable, Complete, Cancelled, Failed; explain cause/recovery beside exceptions | Internal worker states or color-only status |
| Units | Separate value and explicit source unit; use `world units`, `%`, `MiB`; unknown units stay `Source units` | Inferring seconds/metres/density units from a channel name |
| Rates | `Rate` plus `units/s` in compact playback chrome; tooltip: `Recorded units per playback second`; sample mode says `Samples per playback second` | Confusing playback rate, output frames per second and recorded time |
| Numeric formatting | Mono, minus signs, decimal point, exact ID strings without grouping; scientific notation when needed without changing stored precision | Rounding scientific edits to fit, float conversion of IDs, clipped exact values |
| Punctuation | No terminal punctuation on labels/actions; complete explanatory sentences end with a period | `·`, `@`, parentheses or slashes used to glue primary concepts together |
| Ellipsis | One `…` when an action opens a picker/form: Open…, Save scene recipe…, Derive range…; also incomplete progress | Ellipsis on Apply/Run/reset; three separate dots |
| Abbreviations | Established units, IDs and source-defined channel names; define unfamiliar terms in details | FPS for playback samples, engine shorthand, invented abbreviations |
| Errors | Say what happened and how to recover: `Enter a finite number.` Keep draft and last committed value visible | Generic Invalid, silent coercion, tooltip-only failure |

Unit expressions such as `/ world unit`, axis annotations and exact source names
are permitted where they convey mathematical meaning. `%` on the paired Faint
inputs means percentiles, not opacity percentages; the surrounding Quick setup
task and details supply that context. A real native field must keep its complete
round-trip text; short illustrative mockup numbers are not a rounding policy.

Normal views use a **read-only Displayed time** readout and a separate **Seek…**
action. Seek opens a small form titled **Seek time**, with an editable **Target**
in recorded source units and explicit **Go** and **Cancel** actions. Merely editing
the target does not advance the displayed scene or submit a request. Go submits
the seek; Cancel closes the form without submitting. Escape in the numeric editor
restores its committed text; Escape outside active editing closes the form.
Retain the existing numeric draft/validation contract. An editable target is never labeled Displayed
time. While buffering, read-only **Displayed time** remains the committed scene
time and **Requested time** reports the submitted target. A new draft in Seek
does not overwrite either readout until the relevant request/display transition. The
slider says **Sample index**, with secondary **Union of recorded samples**; its
positions are still discrete union indices. A layer's **Source time** is separate.
Probe metadata says **Probed at** and can show an **Earlier sample** badge; it never
relabels an old result with the current clock. Capturing that stamp is the already
identified future UX4 requirement, not a new capability implemented here.

## Quick setup and help workflow

1. Open Quick setup and choose Dense core, Faint structure or Signed field. Menu
   descriptions say what the action is useful for; Signed field explicitly says
   **For positive and negative data**. Selecting an action changes no mappings.
2. Faint structure shows the actual lower/upper percentile values beside Apply.
   [Inherited 0–100](evidence/issue-40/faint-inherited.png) stays 0–100 after Dense
   core. [Edited 1–99](evidence/issue-40/faint-edited.png) is an explicit user choice,
   not a recommended universal default. Current mapping fields below stay unchanged
   before Apply. The prospective clipping notice differs from actual clipping status.
3. Apply runs the existing action with its existing eligibility/budget checks.
   The disabled specimen exposes the both-signs prerequisite. The one-line
   completion feedback says **Setup applied. Settings updated.** Inspect resolved
   Color and Opacity fields; no persistent active-setup badge is created.
4. Manual edits now describe the view. Strength, ray step, camera, particles and
   other objects retain the existing [preset contract](VOLUME_DISPLAY_PRESETS.md).
   Reset color and Reset opacity mapping retain their separate scopes.

Quick setup uses only the compact info affordance in its section heading; there
is no additional **What changes** button. Hover or keyboard focus shows the
one-sentence summary **Apply a one-time color and opacity setup.** Click or
keyboard activation opens [concise details](evidence/issue-40/quick-setup-details.png)
with a **Volume display handbook** link. Closing details restores focus to the
heading's info action. The inline one-time instruction, percentile inputs,
eligibility and clipping notices remain visible without opening help. Details
identify affected colormap/mappings and preserved strength/quality values;
formulae remain in technical documentation, not the action label. The
[Color detail example](evidence/issue-40/color-details.png) demonstrates a short
focused explanation and handbook action. Essential errors are never hidden there.

## Old wording and revised presentation

| Old proposed label/presentation | Revised label/presentation | Reason |
|---|---|---|
| Workspace: Appearance dropdown at every size | Four icon-and-label choices; chooser only in compact view | Exposes the main destinations without adding a sidebar |
| Objects · choose context, not members | Objects; selected row and separate visibility control | Keep instructions out of the heading; binding stays explicit in Selection |
| density · Field · signed | Object title; Uniform grid metadata; Channel field; visibility action | Makes name, type, channel and availability independently readable |
| Display starting point · apply once | Quick setup; `Apply once, then edit any setting.` | Plain task name with one necessary instruction |
| Color · frozen from signed @ t=0 | Color; Symmetric/Locked badges; `Based on sample at time 200` | Keeps provenance available without encoding it in a heading |
| Opacity · Magnitude 0–96 (independent) | Opacity; Mapping, Transparent below, Full strength above, Strength | Exposes separate editable quantities and their units |
| Current displayed t=2 (different) | Displayed time / Probed at; Earlier sample badge | States the two facts rather than narrating a mismatch |
| [ Apply starting point ] / [ Probe source ] | Filled Apply / Probe source buttons | Makes the primary action visually recognizable |
| Sampling quality | Volume quality; Ray step with world units | Names the user concern while preserving the actual parameter |
| Text-only Previous / Play / Next line | Vector transport controls, indexed slider, mono time fields | Separates commands from readouts and exposes timeline structure |
| Population counts heading plus Population counts selector | Analysis type plus selected Population counts option | Removes redundant text |
| Dust particles / Collapse field / Boundary | Particles / Scalar field / Mesh | Keeps illustrative object names neutral |
| Use full layer range action | Use full range | Uses a short immediate command |
| What changes button | Section-heading info; focus summary and activated details | Removes a redundant help control |
| Editable Displayed time | Read-only Displayed time; Seek… opens a labeled target field | Separates observed state from user intent |

## Review and limitations

All 17 figures are **static visual proposals**, not screenshots of an implemented
redesign. The procedural scene marks and result series are illustrative independent
examples, not scientific output, capture-derived evidence or renderer proposals.
The Selection example edits a single-ID selection; the separate Analysis example
uses All particles. Their numbers must not be read as one executed analysis.
The signed example illustrates a manual 0.01 opacity threshold after a setup;
Signed field itself continues to apply zero as its transparent threshold.

The original native observations, W1–W8 tasks, control inventory and regression
mapping are preserved. Workspace switching now selects a visible segment rather
than opening the desktop chooser; prior abstract activation counts were never
physical click measurements. No usability speedup is claimed.
The revised seek path is Seek… → edit Target → Go, one form-opening activation
more than the original inline target. The old W1 counts remain historical; they
are not current interaction counts for this refinement.

Before acceptance, inspect the [gallery](evidence/issue-40/README.md) at native
size and follow its seven review steps. Confirm the visual/copy direction
explicitly; review completion does not accept UX3 or authorize its implementation.
Checks and unrun native/physical/interaction work are listed with the evidence.
