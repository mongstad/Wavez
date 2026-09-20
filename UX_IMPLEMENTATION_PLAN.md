# SimScope UX Implementation Plan

**Document:** `UX_IMPLEMENTATION_PLAN.md`  
**Project:** SimScope  
**Status:** Authoritative UX/UI roadmap  
**Primary UI technology:** Godot  
**Review model:** Milestone-gated; no milestone advances without explicit acceptance

---

## 1. Purpose

This document defines the staged UX/UI modernization plan for SimScope.

The goal is not to redesign the application in one large pass. The goal is to evolve SimScope into a coherent, professional scientific visualization application through small, reviewable milestones while preserving existing functionality and scientific behavior.

This roadmap is intentionally separate from the main SimScope engineering roadmap (`G1`, `G2`, `G3`, ...). Core engineering milestones and UX milestones may progress independently unless a dependency is explicitly documented.

UX milestones use the prefix:

- `UX1`
- `UX2`
- `UX3`
- ...

Every UX milestone has a hard review gate. Astra must complete, validate, report, and stop. The next milestone begins only after explicit approval.

---

## 2. Product Design Charter

SimScope should feel like a **modern professional scientific application designed in 2026**:

- sleek
- elegant
- restrained
- precise
- responsive
- technically sophisticated
- visually coherent
- suitable for long scientific/technical work sessions

The interface must **not** become overly glossy, decorative, intrusive, or trend-driven.

The scientific visualization is the visual centerpiece. The UI exists to support the work and should recede when it is not needed.

### 2.1 Visual principles

Prefer:

- Midnight Scientific blue-black surfaces with subtle depth
- clear information hierarchy
- excellent typography
- consistent spacing and alignment
- restrained use of accent color
- subtle borders and tonal separation
- compact, professional desktop-app density
- clear selected, hover, disabled, warning, and error states
- smooth but short micro-interactions
- readable diagnostics and numeric data
- consistent iconography
- strong HiDPI / 4K behavior

Avoid:

- excessive glassmorphism
- neon glow as a general UI treatment
- large decorative, bright, rainbow or animated gradients; static low-contrast
  environmental backgrounds are permitted by UX-STYLE-002, while controls
  remain flat and scientific imagery stays independent
- excessive translucency
- oversized consumer/SaaS-style cards
- gratuitous animations
- large rounded controls everywhere
- excessive shadows
- decoration that competes with the viewport
- hidden functionality for the sake of minimalism

### 2.2 Color principle

Color should primarily communicate:

- selection
- state
- warning
- error
- success
- categorical UI tier (Low / Medium / High / XHigh / Max)
- scientific/data meaning through independent scientific palettes
- hierarchy

Color should not be used merely to make every panel visually exciting.

### Current visual contract after UX-STYLE-001–003

The [design system](docs/UX1_DESIGN_SYSTEM.md) specifies current token values;
[theme documentation](docs/UX2_THEME_LIBRARY.md) specifies implemented primitives.
This roadmap governs scope and milestone authorization. Earlier UX1/UX2 reports
and their evidence are historical snapshots, not competing token definitions.

- **Surfaces:** opaque blue-black `#0B101B`, `#111A29`, `#1A2638`, `#243249`.
  Blue is the interaction accent; sparse purple/teal identity marks are separate.
- **Depth:** optional `AtmosphericSurface` uses a static diagonal `#111E30` to
  `#0B101B` background, below 1.2:1 endpoint contrast. Controls and diagnostics
  remain flat and opaque; no bright, rainbow, animated or control-fill gradients.
- **Tiers:** Low / Medium / High / XHigh / Max use dedicated `tier.*` colors,
  compact labels and optional ordinal cues. They never replace operational
  Success / Warning / Error / Info icons and text or scientific color mappings.
- **Density:** 14 px body, 13 px numeric mono, 12 px help/status/tier text;
  32 px normal and 28 px compact controls; spacing 4/8/12/16/24/32 logical units.
  Apply 100%, 125%, 150% or 200% scale once at each owned window boundary.
- **Motion:** current UX2 controls change states immediately. Retained timing
  tokens are future limits, not implemented tweens; reduced-motion preferences
  and adjacent-tooltip timing remain separately gated work.
- **Isolation:** UI theme colors must never alter scientific colormaps,
  normalization, source values, playback, renderer state, analysis or
  deterministic export. The library and five-page laboratory remain opt-in.

UX1 and UX2 and the refinements in issues #5–#7 are accepted. This does not
start UX3. Issue #8 reconciles documentation and validates the existing theme;
all production shell/panel migrations still require explicit authorization.

### 2.3 UX hierarchy

When priorities conflict:

1. Scientific correctness and application functionality
2. Clarity and discoverability
3. Workflow efficiency
4. Accessibility and readability
5. Visual polish
6. Decoration

---

## 3. Architecture Direction

### 3.1 Current direction

Godot remains the primary SimScope application UI and visualization environment.

The UX modernization should strengthen separation between:

- application state
- simulation/capture state
- rendering state
- presentation/UI state

This separation should make future interfaces easier without requiring them now.

### 3.2 Future-compatible architecture

The implementation should avoid unnecessary coupling that would prevent future support for:

- optional browser dashboard / remote-control interface
- AI-assisted diagnostics and analysis
- remote monitoring clients
- third-party extensions

These are **architectural considerations only** during the current UX roadmap.

They are not current implementation deliverables.

### 3.3 Supported capture baseline

For the UX program, the intended current capture contract is **SIMSCP3 / `.ssc`** using the current `SceneCapture` / `SceneReader` workflow.

Legacy VBCOSM1, SIMSCP1, SIMSCP2, and `.vbc` compatibility are not design requirements and should be retired under Section 4.6 unless a current dependency is demonstrated.

### 3.4 Explicitly deferred

Do **not** implement as part of UX1–UX9 unless this plan is formally amended:

- browser dashboard
- embedded Chromium / CEF / WebView UI
- remote network control
- AI model integration
- AI chat panel
- third-party plugin UI framework
- unrelated renderer rewrites
- unrelated simulation changes

---

## 4. Global Engineering Rules

These rules apply to every milestone.

### 4.1 Preserve existing behavior

UX work must not regress existing functionality, including where applicable:

- supported SIMSCP3 / `.ssc` capture loading
- supported capture playback
- seeking and interpolation
- camera controls
- orbit controls
- renderer behavior
- particles
- meshes
- fields
- trails
- filters
- mappings
- overlays
- screenshot/export behavior
- deterministic video export
- external simulation/API integration
- supported keyboard controls
- performance-sensitive rendering paths
- benchmark compatibility

### 4.2 UI must not become the application core

Do not place simulation or rendering logic directly inside presentation widgets merely for convenience.

Prefer explicit state/functions/signals/interfaces between UI and application behavior.

### 4.3 Reuse before duplication

Prefer reusable:

- theme resources
- UI components
- style tokens
- shared icons
- property-row patterns
- dialog shells
- notification components

Avoid one-off styling when a reusable component is appropriate.

### 4.4 No giant redesign commits

Each milestone should remain reviewable.

Large visual changes should be decomposed internally when necessary.

### 4.5 Validation before aesthetics

A visually successful milestone that breaks workflows is a failed milestone.

---

## 4.6 Legacy Capture Format Retirement

The UX modernization must **not preserve obsolete capture formats merely for historical compatibility**.

Before UX1 implementation work begins, SimScope should retire legacy capture compatibility unless a current, supported workflow is proven to depend on it.

Legacy formats targeted for removal:

- VBCOSM1
- SIMSCP1
- SIMSCP2
- legacy `.vbc` capture loading paths
- legacy-only discovery paths
- legacy-only tests and fixtures
- legacy-only examples and documentation
- compatibility code used solely to support retired capture generations

The supported capture baseline for the UX program is:

- **SIMSCP3**
- normally using the **`.ssc`** extension
- written through the current `SceneCapture` workflow
- read through the current `SceneReader` workflow

### Retirement procedure

Before deleting legacy compatibility code, Astra must perform a focused dependency audit and verify that no current supported:

- SimScope feature
- exporter
- example
- benchmark
- deterministic video workflow
- regression suite
- public documentation path

still requires VBCOSM1, SIMSCP1, SIMSCP2, or `.vbc`.

If no current dependency exists, remove the obsolete formats and update affected tests/documentation before UX1 begins.

If a genuine current dependency is found, document it and stop for review rather than silently preserving the entire legacy stack.

Historical source, reports, Git history, and archived benchmark evidence may continue to mention old formats. Historical records do not make those formats part of the current supported product contract.

The UX roadmap protects the **current supported capture contract**, not every historical capture format SimScope has ever understood.

---

## 5. Review and Acceptance Workflow

Every milestone follows the same lifecycle:

```text
Astra implements UXn
        |
        v
Astra performs validation
        |
        v
Astra writes milestone report
        |
        v
       STOP
        |
        v
Johnny + Sol review
        |
   +----+----+
   |         |
REVISE     ACCEPT
   |         |
   +----> UXn frozen
              |
              v
            UXn+1
```

Astra must **not** begin the next UX milestone automatically.

Every implementation prompt should contain the equivalent of:

> Do not begin UX(n+1) or any later UX milestone. Complete UXn only, validate it, report the results, and stop for review.

### 5.1 Acceptance outcomes

A milestone may receive one of three outcomes:

- **ACCEPTED** — milestone is complete and becomes the new baseline.
- **ACCEPTED WITH FOLLOW-UP** — milestone is usable; explicitly documented minor work may be scheduled later.
- **REVISE** — milestone remains open and Astra must address review findings before proceeding.

---

## 6. Milestone Status

| Milestone | Name | Status |
|---|---|---|
| UX1 | Audit & Design System Specification | ACCEPTED by owner 2026-09-13 at `229d4ea`; [report](docs/UX1_REPORT.md) |
| UX2 | Theme Foundation & Component Library | ACCEPTED by owner 2026-09-13 at `5fae711`; [report](docs/UX2_REPORT.md) |
| Pre-UX3/UX4 | Information architecture & visual direction | Owner merged #14/#40 design package in PR #39 on 2026-09-20; historical review evidence retained |
| UX3 | Main Viewer Shell | #41 shell and #42 transport owner-merged; #43 status/Jobs PENDING OWNER REVIEW; integration separately gated |
| UX4 | Workspace & Control Migration | BLOCKED BY UX3 |
| UX5 | Application Settings | BLOCKED BY UX4 |
| UX6 | Detachable Windows & Multi-Monitor | BLOCKED BY UX5 |
| UX7 | Workspace Persistence & Recovery | BLOCKED BY UX6 |
| UX8 | Interaction, Desktop Accessibility & Polish | BLOCKED BY UX7 |
| UX9 | Regression, Performance & Release Hardening | BLOCKED BY UX8 |

### 6.1 Authority for UX3 and later

The owner merged #14/#40 / PR #39 on 2026-09-20. The accepted
[viewer information architecture](docs/UX_INFORMATION_ARCHITECTURE.md),
[visual language](docs/UX_VISUAL_LANGUAGE.md) and
[control map](docs/UX_CONTROL_MAP.md) are the placement/copy/ownership baseline
for UX3 and UX4. They refine this roadmap; later milestones must not rediscover or
replace that design casually.

The following are already implemented product behavior and are **inputs to the UX
migration, not work to redo**:

- current SIMSCP3 / `.ssc` loading, playback, scene/layer sampling and export
- continuous camera tumble, independent probe-marker visibility and background video export
- Midnight Scientific tokens, theme primitives and UI Laboratory from UX1/UX2
- independent volume color and opacity mappings
- frozen/manual/symmetric/percentile volume color policies and clipping disclosure
- Dense core, Faint structure and Signed field one-time volume quick setups
- current recipe/state compatibility, analysis, selection and deterministic export contracts

UX milestones may **move, relabel, compose or expose** these capabilities through
the accepted UI architecture, but must not reimplement their scientific/rendering
semantics unless a separate engineering issue explicitly authorizes that change.

FIELD-001 (#9), UX-LAB-001 (#24), UI-005 (#32) and UX-LEGEND-001 (#37) remain
separate backlog work. Their existence does not authorize UX3/UX4 to implement
them opportunistically. #37 may reserve visual space only until separately Ready.

---

# UX1 — Audit & Design System Specification

## Goal

Understand the existing SimScope UI before redesigning it, identify technical/UX debt, and define the visual and structural design system that later milestones will implement.

UX1 should make **minimal product-facing visual changes**.

## Scope

Audit the current application for:

- windows
- panels
- overlays
- dialogs
- buttons
- sliders
- spin boxes
- menus
- selectors/dropdowns
- playback controls
- camera controls
- visualization controls
- status information
- notifications
- settings
- keyboard shortcuts
- file workflows
- export workflows
- fullscreen behavior
- scaling behavior
- duplicated controls
- inconsistent terminology
- inconsistent spacing
- inconsistent styling
- hard-coded dimensions/colors
- presentation code tightly coupled to rendering/application logic

Identify:

- high-frequency workflows
- persistent controls
- contextual controls
- infrequently used settings
- diagnostics/status information
- controls that should eventually move
- controls that should remain near the viewport
- areas with regression risk

## Design System Specification

Define a proposed SimScope design system, including at minimum:

### Surface hierarchy

Conceptual tokens such as:

- Surface 0 — application / viewport-adjacent background
- Surface 1 — primary panels
- Surface 2 — raised/secondary panels
- Surface 3 — popups/dialogs/menus

### Text hierarchy

- Primary
- Secondary
- Muted
- Disabled
- Monospace/numeric where useful

### Semantic colors

- Separate categorical tiers: Low / Medium / High / XHigh / Max
- Sparse identity accents (not state or data colors)
- Primary accent
- Selection
- Success
- Warning
- Error
- Informational state

### Spacing system

Establish a small reusable spacing scale, for example:

- 4
- 8
- 12
- 16
- 24
- 32

Current accepted spacing is 4, 8, 12, 16, 24, 32 logical units; see the design system.

### Component geometry

Propose consistent:

- control heights
- corner radii
- border thickness
- panel padding
- row spacing
- icon sizes
- scrollbar sizing

### Typography

Define hierarchy for:

- application/window title
- panel title
- section heading
- property label
- normal text
- secondary/help text
- diagnostic values
- compact status text

### Motion

Define restrained timing rules for:

- hover
- pressed state
- panel expansion
- transitions
- notifications
- tooltips

No animation should be added merely because it is possible.

## Deliverables

UX1 must produce:

1. Current UI inventory
2. UX/problem inventory
3. Coupling/technical-risk inventory
4. Proposed information hierarchy
5. SimScope design-system specification
6. Recommended reusable component list
7. Proposed theme/token architecture
8. Regression-sensitive workflow list
9. UX1 milestone report
10. No implementation of UX2

## Acceptance Criteria

UX1 is ready for review when:

- current UI structure is documented
- major inconsistencies are identified
- design principles are translated into concrete tokens/rules
- high-risk behavior is identified before visual changes begin
- proposed component architecture is understandable
- no unrelated functionality has changed
- no broad redesign has been started

---

# UX2 — Theme Foundation & Component Library

## Goal

Implement the shared Godot theme and reusable UI components before applying the redesign across the application.

## Scope

Create or consolidate a centralized theme architecture for controls including where applicable:

- normal buttons
- primary/action buttons
- destructive buttons
- icon buttons
- checkboxes
- radio controls
- sliders
- spin boxes
- numeric inputs
- dropdowns / option buttons
- line edits
- search fields
- tabs
- panel containers
- section headers
- separators
- scrollbars
- trees
- lists
- tooltips
- menus
- status indicators
- progress bars
- dialogs
- notifications/toasts
- disabled/focus/hover/pressed states

## UI Laboratory / Showcase

Create a dedicated development/test scene that shows representative controls and states without requiring a simulation or capture.

It should allow rapid review of:

- typography
- spacing
- colors
- component density
- hover/focus states
- disabled states
- selected states
- warning/error states
- HiDPI behavior

This scene is a development aid and should not become a user-facing feature unless later approved.

## Requirements

- avoid widespread per-node theme overrides where shared styles suffice
- centralize reusable design tokens where practical
- preserve current application behavior
- do not redesign all production screens yet
- ensure controls remain legible at common scaling factors

## Deliverables

1. Shared theme foundation
2. Reusable component patterns
3. UI laboratory/showcase scene
4. Theme documentation
5. Before/after screenshots where useful
6. Validation results
7. UX2 milestone report

## Acceptance Criteria

UX2 is accepted only when the design language feels:

- professional
- restrained
- coherent
- modern
- readable
- suitable for scientific work
- sufficiently dense
- not overly glossy or decorative

No migration to UX3 until visual foundation is explicitly approved.

---

# UX3 — Main Viewer Shell

## Goal

Implement the accepted application shell around the existing viewer without
reorganizing every scientific/control surface at once.

UX3 owns the persistent structure defined by the accepted Pre-UX3/UX4 design:

- 48 px command bar using Midnight Scientific components
- scientific viewport as the dominant surface
- one right-hand contextual dock **shell** with Scene / Appearance / Selection /
  Analysis navigation available, but without migrating the full contents of those
  workspaces yet
- persistent 64 px transport
- compact persistent status/jobs access
- low-distraction/fullscreen recovery paths

UX3 is a presentation migration over existing controllers. It is **not** a second
information-architecture design pass.

## Required implementation

### Command bar

- Open capture
- current capture identity / source-details access
- **State** menu entry points that preserve typed scene/analysis state semantics
- Export, View and Help entry points
- existing fullscreen/panel recovery paths
- accepted 48 px geometry and desktop-only input scope

Do not duplicate complete recipe/export forms in the command bar. Menus route to
their canonical existing operations.

### Viewport chrome

- Frame scene
- Reset camera
- navigation-mode affordance where current behavior supports it
- panel recovery when the contextual dock is hidden
- concise availability/sampling state where the accepted design places it

Do not alter renderer output, camera mathematics, scientific overlays, colormaps,
selection semantics or export pixels merely to fit the new shell.

### Persistent transport

Migrate existing playback controls into the accepted transport:

- Previous / Play-Pause / Next
- union **Sample index** timeline
- read-only **Displayed time**
- explicit **Seek…** flow with separate editable target
- **Requested time** only while a submitted request differs from the displayed time
- time mode
- applicable playback rate
- loop
- existing readiness/buffering behavior

Do not add field interpolation, change the union-sample model or reinterpret sparse
capture cadence. FIELD-001 remains separate.

### Status and Jobs

- Ready / Preparing / Unavailable / durable failure summary
- persistent Jobs action with count/progress access
- reopen/cancel/output/error paths for existing background jobs
- existing screenshot/video/export lifecycle semantics

Do not create a second job system or move worker ownership into UI nodes.

### Context dock shell

Create the accepted dock frame, splitter/collapse behavior, workspace navigation,
selected-context header area and independently scrolling body. UX3 may use bounded
adapters/placeholders or retain existing inspector content behind the new shell
where needed.

**Do not migrate all Scene/Appearance/Selection/Analysis controls in UX3.**
That consumer migration is UX4.

## Explicitly preserve

UX3 must consume, not recreate:

- UX1/UX2 theme/tokens/components
- current camera/orbit behavior
- current particle, mesh and field rendering
- current volume color/opacity/quick-setup behavior
- source probing and marker semantics
- current selection/analysis controllers
- scene v2 / analysis v3 state ownership
- current deterministic video worker/export behavior
- existing performance/cache workers and budgets

## UX3 non-goals

Do not implement as part of UX3:

- complete Scene/Appearance/Selection/Analysis workspace migration
- new scientific controls or renderer features
- FIELD-001 interpolation
- dual legend behavior from #37
- final icon artwork
- application settings architecture
- detachable/multi-monitor windows
- workspace persistence
- touch/tablet/mobile UX
- arbitrary docking
- broad shortcut redesign

## Validation

Test the native Godot implementation using current real `.ssc` captures and focused
synthetic fixtures. At minimum verify:

- empty/open/failed-open/replace flows
- playback, pause/resume, step, loop and seek
- requested versus displayed time during buffering
- camera movement/frame/reset/fullscreen
- dock hide/show and mouse/keyboard recovery
- existing overlays and screenshot entry
- video job start, panel close/reopen, progress and cancel
- current recipes load and restore without UI-generated edit signals
- 1024×640 and 1440×900 logical layouts
- desktop scaling at supported factors where practical
- normal keyboard + mouse/trackpad behavior, including Nordic keyboard constraints
- no new idle/playback decode/upload/render regressions caused by shell redraws

Run the regression gates relevant to shell migration, especially R01–R04,
R10–R13. Do not rerun scientific solvers.

## Deliverables

1. Production main-viewer shell using accepted Midnight Scientific components
2. Persistent transport/status/jobs implementation
3. Context-dock shell/navigation
4. Empty/loading/error/fullscreen recovery states
5. Focused real-capture and recipe/export regression evidence
6. UX3 milestone report

## Acceptance Criteria

UX3 is accepted when the new shell is usable as the production baseline, the
viewport remains dominant, persistent essentials no longer depend on inspector
scroll position, and existing scientific/rendering/state behavior remains intact.

Acceptance of UX3 authorizes **no UX4 control migration automatically**.

---

# UX4 — Workspace & Control Migration

## Goal

Migrate the existing controls into the accepted Scene / Appearance / Selection /
Analysis architecture **without rebuilding the underlying features**.

The accepted `docs/UX_CONTROL_MAP.md` is the migration checklist and ownership
contract. Every migrated control must preserve its current controller/state owner
unless a separately reviewed architecture change explicitly says otherwise.

## Migration order

Prefer bounded, reviewable slices rather than one giant panel rewrite:

1. **Scene and object context**
   - object list, visibility, availability and source sample status
   - selected-object header/context
   - metadata/geometry details
   - Source probe composition, including the approved provenance presentation when
     its runtime binding is explicitly implemented and tested

2. **Appearance**
   - particle representation/color/history/display filters
   - mesh color/wireframe
   - field Quick setup, Color, Opacity, Volume quality, Slice/Clipping/Surface
   - Viewport presentation as a clearly separate context
   - current reset scopes and one-time action semantics

3. **Selection**
   - explicit source binding
   - exact IDs/rows/ROI/predicates/cohorts/groups
   - gesture/edit modes and membership semantics

4. **Analysis and Results**
   - task-specific Temporal / Space-time / Diagnostic CSV / Compare / Period /
     Matched views forms
   - effective request context shown locally
   - named results, provenance, bounded previews, exact lookup and complete numerical export
   - temporary expanded Results workbench

5. **State / Export composition**
   - keep **State** as the top-level menu name
   - preserve distinct scene v2 and analysis v3 save/load semantics
   - canonical PNG/video/numerical export entry points
   - fixed actions and persistent Jobs integration

6. **Performance access during migration**
   - keep current cache/RAM/GPU/resource controls reachable in a dedicated
     Performance surface
   - do not bury them in Appearance
   - do not remove them before UX5 supplies their approved long-term home

Each slice must be independently reviewable and reversible.

## Existing behavior to consume, not redo

UX4 must expose the implementations already accepted before UX3, including:

- volume opacity mapping
- volume normalization/range policies
- Dense core / Faint structure / Signed field Quick setup
- current particle mapping/range policies
- source probe behavior and independent marker toggle
- mesh/field/particle rendering and sampling contracts
- selections, analysis, matched views and durable numerical exports
- current scene/analysis state and recipe compatibility
- deterministic screenshot/video behavior
- current cache/performance controls

Moving a control is not permission to rewrite its algorithm or saved semantics.

## Information and copy contract

Use the accepted visual/copy specification:

- Midnight Scientific remains the proper design-system name
- SimScope-authored copy uses sentence case
- **Population counts** is the consistent analysis/result term
- **State** remains the top-level menu
- source-defined object/channel names and unit casing are preserved
- developer/state shorthand does not leak into primary labels
- detailed help moves to concise info/details + handbook links where approved
- essential warnings/errors remain visible without opening help

Do not recreate the old long inspector inside new cards.

## Workspace versus application settings

UX4 owns capture/session/task controls used while inspecting a scene.

It does **not** turn scientific/display controls into application defaults merely
because UX5 later adds Settings. In particular, channel, colormap, range, opacity,
ray step, selections, analysis requests and source-bound state remain in their
workspace/state owners.

Only infrequent application-level preferences may be proposed for UX5.

## UX4 non-goals

Do not implement in UX4 unless separately authorized:

- FIELD-001 interpolation
- P4 backlog polish #24/#32/#37
- final icon redesign
- touch/tablet/mobile UI
- arbitrary docking
- new renderer/scientific features
- automatic scientific interpretation/default inference
- settings persistence beyond the existing state contracts
- window/workspace persistence

## Validation

For each migration slice:

- compare behavior before/after using the same current capture/recipe fixtures
- run the mapped regression gates from `docs/UX_CONTROL_MAP.md` /
  `docs/UX1_REGRESSION_WORKFLOWS.md`
- verify exact numeric entry and IDs
- verify source/provenance labels and unavailable/refusal states
- verify panel switching/hiding does not submit, cancel, rebind or recompute
- verify state/recipe round trips and export behavior where affected
- inspect 1024×640 and 1440×900 layouts and supported scale factors
- check focused performance traces when a UI move touches preparation/upload paths

Do not claim a usability improvement from screenshots alone; owner review of real
tasks is required.

## Deliverables

1. Scene workspace migration
2. Appearance workspace migration
3. Selection workspace migration
4. Analysis/Results migration
5. State/Export/Performance access migration
6. Control-map completion/traceability report
7. Real-workflow validation evidence
8. UX4 milestone report

## Acceptance Criteria

All current supported user-facing capabilities have a canonical destination or a
documented separately deferred issue. No duplicate legacy inspector remains as a
competing production path unless explicitly retained as a temporary rollback path.
Normal tasks require less hunting without changing scientific meaning.

---

# UX5 — Application Settings

## Goal

Create a coherent home for **application-level, infrequent preferences** that do
not belong to a capture, selected object, scientific request, result or export job.

UX5 must not become a duplicate of the Scene/Appearance/Selection/Analysis workspaces.

## Candidate categories

Keep the initial system deliberately small. Candidate categories are:

- General
- Interface
- Performance
- Files & export defaults
- Shortcuts

Add another category only when actual settings justify it. Do not create empty
Appearance/Visualization/Camera/Data/Advanced buckets merely because older plans
listed them.

## Candidate scope

Appropriate UX5 settings may include, where the current product actually supports
or explicitly approves them:

- interface scale/density
- application/session defaults that are not scientific source state
- scoped resource/cache budgets moved from the temporary UX4 Performance surface
- screenshot/output-folder defaults where safe
- default export preferences that do not override an explicit job
- shortcut discovery/customization if separately supported
- reduced-motion or similar desktop interface preference if implemented later

## Explicit exclusions

Do **not** move or duplicate into Settings:

- current capture/object visibility
- particle/mesh/field channels or colormaps
- volume Quick setup, color, opacity, ray step, slice or isosurface controls
- camera position/current scene presentation state
- timeline/seek/playback state
- source probe coordinates/result
- selections, analysis requests/results
- scene/analysis recipes
- per-job export state

Those remain workspace/state/job owned.

## Behavior and persistence

- define which settings apply immediately versus on explicit Apply
- persist only settings that are genuinely application preferences
- reset actions must state their exact scope
- settings changes must not silently clear scientific/session state
- preserve existing worker/resource ownership when budgets change
- search/filter is optional and should be added only if the final setting count
  makes it useful

## Input scope

UX5 remains desktop keyboard + mouse/trackpad. It does not introduce touch/tablet
navigation.

## Deliverables

1. Application settings architecture
2. Implemented approved categories/preferences
3. Persistence/reset behavior
4. Focus/scaling validation
5. Migration of approved temporary Performance controls
6. UX5 milestone report

---

# UX6 — Detachable Windows & Multi-Monitor

## Goal

Allow the accepted viewer/workspace architecture to span multiple desktop displays
without recreating the old inspector or inventing a general-purpose IDE docking system.

## Target workflow

The primary window retains the scientific viewport and persistent shell. One or
more **approved** secondary windows may host the existing contextual workspace or
expanded results where this materially improves multi-monitor work.

Detachment changes presentation ownership only; it must not clone controllers,
scientific state, jobs or source bindings.

## Scope

Implement and validate only the detachment patterns justified by UX3–UX5 use:

- detach/reattach the contextual workspace or other explicitly approved surface
- move owned windows between displays
- independent viewer maximize/fullscreen behavior
- correct focus and close/minimize behavior
- mixed-DPI scaling and one-time scale application per window
- recovery when a remembered monitor becomes unavailable
- separate native-window theme/scaling contexts where required

## Non-goals

- arbitrary IDE-style docking
- unlimited user-created panel clones
- duplicate controller instances
- touch/tablet companion UI
- browser/remote control
- scientific/rendering feature changes

If a second detachable window type is not justified by real workflow evidence,
do not add it merely because the milestone mentions windows.

## Validation

UX6 requires real multi-monitor hardware before acceptance, including:

- move/reattach across displays
- mixed scale/DPI where available
- fullscreen on one display while controls remain usable on another
- focus/shortcut routing
- safe minimize/close
- export/background-job continuity
- monitor removal/reconnect recovery
- no duplicate sampling, decode/upload or controller work caused by detachment

## Deliverables

1. Minimal approved multi-window architecture
2. Detach/reattach behavior
3. Dual-monitor validation
4. Display-loss/focus/scaling report
5. UX6 milestone report

---

# UX7 — Workspace Persistence & Recovery

## Goal

Persist **UI arrangement and navigation context** safely without creating a second
scientific-state or recipe system.

## Scope

Candidate persistent UI state:

- dock visibility/width
- approved detached-window visibility, size and safe position
- last active workspace
- expanded/collapsed UI groups where useful
- optionally last safe main-window size/state

Persist additional layout information only when UX3–UX6 prove it useful.

## Strict boundary with scientific state

UX7 workspace persistence must **not** duplicate or override:

- current capture/source identity
- scene v2 / analysis v3 recipes
- camera/scientific presentation state already owned by recipes
- channel/range/opacity/ray-step scientific display state
- selections or analysis results
- export-job state

If a value already has an authoritative scientific/session owner, UX7 must not
silently persist a competing copy.

## Recovery requirements

Startup must recover safely if:

- monitor topology changes
- resolution or scale changes
- a saved window would open off-screen
- a secondary display is disconnected
- persisted UI data is corrupt/unknown-version
- a previously active workspace is unavailable for the current source

Always provide a visible **Reset workspace** recovery action.

Predefined layouts are optional. Add them only after owner review demonstrates a
real workflow advantage; do not invent Default/Visualization/Analysis/Presentation
presets merely because the old roadmap listed examples.

## Deliverables

1. Bounded/versioned workspace persistence
2. Safe restore/fallback behavior
3. Reset workspace recovery
4. Reopen/topology-change validation
5. UX7 milestone report

---

# UX8 — Interaction, Desktop Accessibility & Polish

## Goal

Polish the now-stable desktop interaction system. UX8 refines implementation
quality; it does not redesign the information architecture or add unrelated features.

## Scope

Review and improve:

- keyboard navigation and focus order
- visible focus states
- shortcut discoverability and Nordic-keyboard usability
- hover/pressed/disabled clarity
- concise tooltips and focused help
- error, empty, loading and notification states
- typography consistency
- optical alignment and spacing in native Godot controls
- final icon quality/artwork and semantic consistency
- contrast and non-color-only communication
- desktop pointer target usability
- cursor behavior
- HiDPI / 4K scaling
- restrained transitions/motion
- screen-reader/accessibility metadata where Godot/platform support is practical

## Desktop scope

UX8 does **not** add touch-first controls, touch gestures, tablet navigation or
mobile layouts. Those require a separately authorized future track.

Accessibility here means making the supported desktop application clearer and
more operable; it does not imply certification or support for every assistive
technology.

## Motion guidance

Use motion only where it explains state. Respect the accepted motion tokens/limits
rather than introducing a second animation system. Reduced-motion behavior belongs
here if it is implemented.

## Validation

Include real native interaction review, not just screenshots:

- keyboard-only core workflows
- text/numeric editing versus viewport shortcuts
- focus restoration after menus/dialogs/panel switches
- hover/focus help
- error recovery
- 100/125/150/200% scales where practical
- 4K physical review on available hardware
- multi-window focus/scaling after UX6
- long labels, exact IDs/values and compact layouts

## Deliverables

1. Interaction consistency pass
2. Keyboard/focus/shortcut review
3. Desktop accessibility/contrast review
4. Final icon/typography/alignment polish
5. Native scaling evidence
6. UX8 milestone report

---

# UX9 — Regression, Performance & Release Hardening

## Goal

Prove that the completed UX migration preserves the accepted SimScope product
contracts and does not introduce material performance regressions.

UX9 is verification/hardening, not a final opportunity to add postponed features.

## Baseline

Use the accepted post-maintenance pre-UX3 baseline, accepted UX milestone reports,
current regression fixtures and explicit **frozen external captures**. Historical
scientific simulations are evidence, not instructions to rerun solvers.

Do not regenerate large scientific runs merely to make the UX suite pass.

## Functional regression scope

Verify where applicable:

- SIMSCP3 / `.ssc` open/replace/failure behavior
- playback, union timeline, seek/request/displayed-time semantics
- camera/orbit/fullscreen
- particle, mesh and field rendering
- volume quick setups, color/opacity/range/quality controls
- probes and marker state
- trails/display filters/guides
- selection and all supported analysis/result workflows
- scene v2 / analysis v3 state round trips
- PNG and deterministic video export
- background job continuation/cancel/recovery
- application settings
- multi-window/detachment
- workspace persistence/recovery
- desktop keyboard/focus/help/error behavior
- benchmark/integration compatibility where still current

Separate UI-overlay pixel changes from scientific/source invariants. Do not require
cross-GPU identical pixels where the renderer contract does not promise them.

## Performance

Measure against equivalent accepted captures/settings:

- application startup/opening
- idle UI overhead
- play/seek responsiveness
- main-thread callback/upload stalls
- viewport rendering
- background preparation behavior
- CPU/GPU utilization where meaningful
- memory/cache behavior
- panel/workspace switching
- multi-window overhead if UX6 is implemented

A changed UI must not trigger unnecessary decode, hashing, source scans, texture
uploads, geometry rebuilds or analysis work.

Do not claim “no regression” without measured evidence and identified limits.

## Deferred-work discipline

Open/deferred issues remain deferred unless separately authorized. In particular,
UX9 does not opportunistically implement:

- FIELD-001
- P4 polish issues
- remote/web/AI/plugin tracks
- touch/tablet/mobile UX
- unrelated renderer/scientific changes

## Deliverables

1. Full UX regression report
2. Performance comparison against defined baseline
3. Known limitations / unverified hardware list
4. Final native UX screenshots
5. Documentation/status reconciliation
6. UX modernization completion report

## Acceptance Criteria

UX9 acceptance marks the initial **desktop** UX modernization program complete.
Known separately tracked feature work may remain open without blocking UX9 unless
the owner explicitly makes it release-critical.

---

## 7. Future Reserved Tracks

The following are intentionally reserved for later planning.

### UX-WEB — Optional Browser Dashboard / Remote Control

Potential future scope:

- local browser dashboard
- secondary-device monitoring
- remote controls
- rich charts/tables
- WebSocket/HTTP/API communication

No implementation during UX1–UX9.

### UX-AI — AI-Assisted Diagnostics & Analysis

Potential future scope:

- assistant panel
- structured simulation context
- diagnostics interpretation
- tool-assisted analysis
- viewport/screenshot context
- provider-independent AI backend
- local or cloud models

Scientific/numerical computation remains authoritative; AI acts as analyst/orchestrator.

No implementation during UX1–UX9.

### UX-REMOTE — Remote Monitoring / Network Clients

Potential future scope:

- remote run monitoring
- read-only clients
- network control with appropriate authorization
- tablet/laptop companion interfaces

No implementation during UX1–UX9.

### UX-EXT — UI Extension / Plugin Framework

Potential future scope:

- extension points
- third-party panels
- custom visualization controls

No implementation during UX1–UX9.

---

## 8. Milestone Report Template

At the end of every milestone, Astra should provide a concise report containing:

### UXn Milestone Report

**Status:** Complete / Incomplete

**Implemented**
- ...

**Files changed**
- ...

**Behavior intentionally changed**
- ...

**Behavior explicitly preserved**
- ...

**Validation performed**
- ...

**Automated tests**
- ...

**Manual tests**
- ...

**Screenshots / visual evidence**
- ...

**Known limitations**
- ...

**Risks / follow-up candidates**
- ...

**Out-of-scope work not started**
- ...

**Repository state**
- branch:
- commit:
- working tree status:

**STOP:** Await review and explicit approval before beginning UX(n+1).

---

## 9. Change Control

This document is a roadmap, not a command to blindly complete every originally imagined feature.

At each review gate, the project may:

- modify a later milestone
- split a milestone
- merge small milestones
- defer a feature
- reject a proposed UI pattern
- add newly discovered requirements

A later milestone must not be implemented simply because it appears in this document.

The accepted result of each preceding milestone becomes the baseline for the next.

---

## 10. Current Execution Gate

UX1 and UX2 are accepted. The legacy capture retirement gate is historical
completed groundwork and must not be rerun merely because this roadmap still
records it.

The owner merged shell PR #45 and transport PR #47. Issue #43 was the sole
Ready item at the start of this work, using the existing owner-created linked
branch at accepted main `a976ec6`. Its [status/Jobs implementation](docs/UX3_STATUS.md)
is pending owner review.

1. Review #43 persistent readiness, durable failures and existing Jobs access.
2. The owner controls acceptance and merge; no UX3 milestone acceptance is claimed.
3. Do not start #44 integration without its own Ready authorization.
4. Do not begin UX4 until UX3 is owner-accepted and UX4 is separately authorized.

Astra must use the accepted design system, information architecture, visual
language and control map as inputs. Do not rerun UX1/UX2, redesign the interface
from scratch, or opportunistically implement later UX/backlog features.

**Do not begin UX4.**

---

## 11. Definition of Success

The UX modernization is successful when SimScope feels like a coherent professional application rather than a collection of individually added controls.

A successful result should:

- make the viewport the visual centerpiece
- make controls easier to find
- reduce UI inconsistency
- support long technical/scientific sessions
- work well on HiDPI and multi-monitor setups
- preserve existing scientific and rendering behavior
- make future UI expansion easier rather than harder
- remain visually modern without depending heavily on short-lived design trends

The target is not “more UI.”

The target is **less friction, better structure, and a quiet professional visual identity.**
