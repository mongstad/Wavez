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

- dark neutral surfaces with subtle depth
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
- visualization/data meaning
- hierarchy

Color should not be used merely to make every panel visually exciting.

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
| UX3 | Main Viewer Shell | NOT STARTED — ON HOLD until explicit owner authorization |
| UX4 | Panels & Information Architecture | BLOCKED BY UX3 |
| UX5 | Professional Settings System | BLOCKED BY UX4 |
| UX6 | Detachable Windows & Multi-Monitor | BLOCKED BY UX5 |
| UX7 | Workspace Persistence & Workflow | BLOCKED BY UX6 |
| UX8 | Interaction, Accessibility & Polish | BLOCKED BY UX7 |
| UX9 | Regression, Performance & Release Hardening | BLOCKED BY UX8 |

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

Exact values may change after audit.

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

Make the viewport feel like the primary workspace and reduce unnecessary visual competition around it.

## Scope

Modernize the main viewer shell, including where appropriate:

- top application/header area
- run/capture identification
- playback transport
- timeline
- playback speed
- status information
- fullscreen controls
- quick-access visualization controls
- overlay visibility
- loading state
- progress state
- concise error/notification presentation

## Principles

The viewer should support a low-distraction mode in which the visualization occupies almost the entire application surface.

Controls should be:

- visible when useful
- compact
- logically grouped
- easy to hide
- keyboard-accessible where appropriate

Avoid turning the viewer into a dashboard full of permanent cards.

## Validation

Test UX3 using real current SimScope workflows and SIMSCP3 / `.ssc` captures, not only mock scenes.

Verify at minimum:

- open capture
- playback
- pause/resume
- seek
- speed changes
- camera movement
- fullscreen
- overlays
- visualization mode changes
- screenshot/export entry points where present

## Deliverables

1. Revised viewer shell
2. Updated playback/timeline presentation
3. Low-distraction viewer behavior
4. Real-capture validation results
5. UX3 milestone report

---

# UX4 — Panels & Information Architecture

## Goal

Reorganize controls according to user workflow rather than historical implementation.

## Candidate Workspace Groups

Exact naming must be validated during UX1–UX4, but likely categories include:

- Scene / Data
- Visualization
- Inspector
- Camera
- Playback
- Diagnostics
- Performance

## Scope

Improve:

- panel hierarchy
- property grouping
- collapsible sections
- control naming
- ordering
- contextual visibility
- duplicate settings
- inspector behavior
- diagnostics presentation
- frequently used controls versus infrequent configuration

## Key distinction

Establish a deliberate boundary between:

### Workspace controls

Things users adjust frequently while inspecting a visualization.

### Application/settings controls

Things users configure occasionally.

These should not become one giant settings surface.

## Deliverables

1. Revised panel hierarchy
2. Revised control organization
3. Contextual grouping behavior
4. Terminology cleanup
5. Workflow validation notes
6. UX4 milestone report

## Acceptance Criteria

Evaluate UX4 through real tasks, including:

- opening a capture
- changing visualization
- adjusting camera/display state
- examining diagnostics
- finding less-common settings
- returning to the visualization

The interface should require less hunting, not merely look cleaner.

---

# UX5 — Professional Settings System

## Goal

Create a coherent, searchable settings/configuration experience using the approved SimScope design system.

## Candidate Categories

Exact categories remain subject to UX1/UX4 review:

- General
- Appearance
- Visualization
- Playback
- Camera
- Data
- Performance
- Input
- Shortcuts
- Advanced

## Scope

Where appropriate, support:

- category navigation
- search/filter
- consistent property rows
- descriptions/tooltips
- reset-to-default
- configuration persistence
- clear handling of modified settings
- clear Apply/Cancel semantics when changes are not immediate
- sensible immediate-apply behavior where safe

## Principles

Do not blindly mimic KDE, Windows Settings, or a web SaaS dashboard.

The settings system should use the SimScope design language and remain dense enough for a technical application.

## Deliverables

1. Settings architecture
2. Settings navigation
3. Search/filter behavior if justified
4. Persistence behavior
5. Reset/default behavior
6. Scaling tests
7. UX5 milestone report

---

# UX6 — Detachable Windows & Multi-Monitor

## Goal

Allow the visualization and controls to occupy separate displays cleanly.

## Target Workflow

Example:

```text
Monitor 1
+----------------------------------+
|                                  |
|         SIMSCOPE VIEWER          |
|                                  |
|       Fullscreen / maximized     |
|                                  |
+----------------------------------+

Monitor 2
+----------------------------------+
| Visualization                    |
| Inspector                        |
| Diagnostics                      |
| Playback                         |
+----------------------------------+
```

## Scope

Implement and validate:

- detachable control window(s)
- moving windows between displays
- resize behavior
- independent viewer fullscreen/maximize behavior
- persistence of window size/position where appropriate
- recovery when a remembered monitor is unavailable
- mixed-DPI handling where feasible
- safe close/minimize behavior

## Docking

Full arbitrary IDE-style docking is **not automatically required**.

If robust docking would materially expand scope or risk, UX6 may implement a simpler detachable control-window architecture first. More advanced docking may be proposed as a separate future milestone.

## Deliverables

1. Multi-window architecture
2. Detachable controls
3. Dual-monitor behavior
4. Display-loss recovery behavior
5. DPI/scaling observations
6. UX6 milestone report

## Acceptance Criteria

Must be tested on a real multi-monitor setup before acceptance.

---

# UX7 — Workspace Persistence & Workflow

## Goal

Make multi-window/panel arrangements predictable and reusable.

## Scope

Potential features:

- restore previous workspace
- remember panel visibility
- remember safe window positions
- reset workspace
- predefined layouts where genuinely useful
- save user layout if implementation remains robust

Possible predefined layouts may include:

- Default
- Visualization
- Analysis
- Presentation

Do not add presets solely to increase feature count.

## Requirements

Startup must recover safely if:

- monitor topology changes
- resolution changes
- DPI changes
- saved coordinates are invalid
- a secondary display is disconnected

The application must never become inaccessible because a saved window opens off-screen.

## Deliverables

1. Workspace persistence
2. Safe layout restoration
3. Reset/recovery flow
4. Reopen validation
5. UX7 milestone report

---

# UX8 — Interaction, Accessibility & Polish

## Goal

Polish behavior after the structure is stable.

## Scope

Review and improve:

- keyboard navigation
- focus states
- shortcut discoverability
- hover states
- pressed states
- disabled-state clarity
- tooltips
- contextual help
- error messages
- confirmation behavior
- empty states
- loading states
- transient notifications
- typography consistency
- contrast
- UI scaling
- cursor behavior
- small transitions
- control hit targets

## Motion Guidance

Transitions should remain subtle.

Indicative ranges:

- hover/state transition: approximately 100–150 ms
- panel/section transition: approximately 150–200 ms
- notifications: restrained and non-disruptive

Use motion to explain state changes, not decorate the application.

## Accessibility

Where practical, verify:

- sufficient contrast
- understandable focus indication
- keyboard-reachable core controls
- non-color-only communication for critical states
- readable scaling on HiDPI displays

## Deliverables

1. Interaction consistency pass
2. Keyboard/focus review
3. Accessibility/contrast review
4. Polish pass
5. UX8 milestone report

---

# UX9 — Regression, Performance & Release Hardening

## Goal

Prove that the UX modernization did not compromise SimScope's core functionality or performance.

## Scope

Compare the post-UX application with the accepted pre-UX baseline.

Verify where applicable:

- SIMSCP3 / `.ssc` capture loading
- supported capture playback
- seeking/interpolation
- camera
- orbit
- visualization modes
- particles
- meshes
- fields
- trails
- mappings
- filters
- overlays
- screenshots
- deterministic video export
- file dialogs
- settings persistence
- fullscreen
- multi-window behavior
- saved layouts
- external APIs
- example workflows
- benchmark compatibility

## Performance

Measure whether the redesigned UI introduces meaningful regressions in:

- startup
- interaction responsiveness
- playback responsiveness
- viewport rendering
- idle CPU/GPU usage where relevant
- memory usage where practical

Do not claim “no regression” without evidence.

## Deliverables

1. Full UX regression report
2. Performance comparison
3. Known limitations list
4. Final UX screenshots
5. Documentation updates
6. UX completion report

## Acceptance Criteria

UX9 acceptance marks the initial UX modernization program complete.

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

## 10. First Execution Step

Before UX1, perform the **Legacy Capture Format Retirement** gate defined in Section 4.6:

1. audit current dependencies on VBCOSM1, SIMSCP1, SIMSCP2, and `.vbc`
2. remove those legacy compatibility paths if no current supported workflow requires them
3. update affected tests and documentation
4. validate SIMSCP3 / `.ssc` as the current supported capture baseline
5. report the cleanup result and stop if any genuine dependency blocks retirement

Once that cleanup is accepted, the first UX implementation assignment is:

> **UX1 — Audit & Design System Specification**

UX1 should study the existing SimScope application and documentation, produce the required audit and design-system proposal, validate that no unrelated behavior changed, write the UX1 milestone report, and stop.

**Do not begin UX2.**

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
