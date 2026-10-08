# UX architecture and review workflow

This document retains the live engineering and review rules from the retired UX
milestone plan. The GitHub Project Ready lane and complete issue specification
select implementation work; a roadmap paragraph grants no authorization.
Follow [AGENTS.md](../AGENTS.md), [CONTRIBUTING.md](../CONTRIBUTING.md) and the
owner's branch instructions. Work on one authorized issue and one PR targeting
`main`, validate the affected paths, then stop for owner review. Do not merge,
auto-merge, manually close an issue or start dependent work.

## Scientific and presentation priorities

When priorities conflict, preserve scientific correctness and application
functionality first, then clarity, workflow efficiency, accessibility/readability,
visual polish and decoration. Scientific visualization is the centerpiece.
Controls support that work with restrained desktop density, legible numbers,
consistent focus/hover/disabled/error states and discoverable actions.

Keep application, source/capture, renderer and presentation state separate.
Widgets call existing state/functions/signals rather than becoming the scientific
core. Reuse themes, style tokens, icons, property rows, dialog shells and status
components. A presentation migration consumes existing behavior; it does not
reimplement analysis, sampling, identity, renderer or export semantics.

The current capture baseline is [WVZ1](CAPTURE_FORMAT_POLICY.md) `.wvz` through
`SceneCapture` / `SceneReader`. Obsolete capture compatibility is not a requirement.
A proposed break to a live workflow must update its writer/reader/tests/docs
together and explain the break. No compatibility feature is added by this guide.

## Sources of truth

| Responsibility | Current source |
| --- | --- |
| Desktop shell and state ownership | [Production ownership](UX3_UI_OWNERSHIP.md), [shell](UX3_SHELL.md), `viewer/ui/shell/` |
| Menu and Simulation/Tools placement | [Menus](UX4_MENUS.md), [Simulation panel](UX4_PANEL.md), [Tools audit](TOOLS_FUNCTIONAL_AUDIT.md), `viewer/ui/shell/` |
| Design and semantic presentation | [Design system](UX1_DESIGN_SYSTEM.md), [theme primitives](UX2_THEME_LIBRARY.md), [visual language](UX_VISUAL_LANGUAGE.md), current `viewer/ui/` theme resources |
| Scientific palette isolation | [Wire/representation contract](WVZ1_FORMAT.md), [normalization](VOLUME_COLOR_NORMALIZATION.md), [opacity](VOLUME_OPACITY_MAPPING.md) |
| Input, focus and settings | [Shortcuts](KEYBOARD_SHORTCUTS.md), [focus](FOCUS_NAVIGATION.md), [File Locations](FILE_LOCATIONS.md), [Performance](PERFORMANCE_DIALOG.md) |
| Scientific persistence | [View presets](WAVEZ_VIEW_PRESETS.md), [inspection](../INSPECTION_STATE.md), [analysis schemas](ANALYSIS_SCHEMAS.md) |
| Build and review evidence | [Version policy](VERSIONING.md), [evidence index](EVIDENCE_INDEX.md), [current state](CURRENT_STATUS.md) |

Theme/accent/operational status colors stay independent of scientific palettes,
normalization and source values. Atmospheric backgrounds remain static and
restrained; controls and diagnostics remain readable. Do not infer scientific
values from decorative colors. Apply display scaling once at the owned window
boundary; font sizes, spacing, compact layouts and focus outlines retain their
shared component ownership. Later accepted theme changes govern their slice;
earlier screenshots/token tables remain historical evidence.

## Validation and owner review

Choose focused validation in proportion to the changed responsibility and shared
boundaries. A visually successful change that breaks a workflow fails review.
Check normal/compact layouts, keyboard focus, disabled/active states, cancellation
and recovery as applicable. Scientific/render changes require independent source
oracles, unchanged input hashes and relevant renderer/package checks. UI changes
must preserve capture loading/playback/seeking, camera, layer controls, mappings,
selection, image/video/numerical export and performance-sensitive paths they use.
Do not run unrelated full suites automatically.

A report identifies the issue, exact branch/revision, files, actual changed
behavior, fixtures, commands/backends, PASS/FAIL/NOT RUN results, failed attempts,
known limits, visual evidence and exact owner checks. Implementation and passing
automation do not constitute owner acceptance. Preserve previous review-time
records as historical records; repair their links without changing outcomes.

Owner outcomes may accept, accept with an explicit follow-up, or request revision.
A follow-up or deferred idea requires its own authorization before implementation.
After an owner-confirmed merge, synchronize/check the repository and wait.

## Deferred concepts

The old plan's detachable windows/multi-monitor UI, workspace recovery,
accessibility/motion preferences, remote/browser services, AI integration and
extension framework are concepts rather than current promised features.
Separate issues must establish scope and review gates before implementation.

If separately authorized, workspace state must remain distinct from scientific
inspection/recipes; restoring UI layout cannot silently change channels, source
time, camera, sampling or export. Windows must share explicit state ownership
rather than copy application cores. Local desktop keyboard/mouse accessibility
remains the primary input scope; mobile/web/network work does not follow from it.
Optional extensions may not execute from capture metadata. Renderer/solver
rewrites and automatic physical-event inference require separate authorization.

The original milestone deliverables and future proposals remain available in
[the accepted plan](https://github.com/mongstad/Wavez/blob/ca220d30163d4a76efd652933c8c963a564c315d/UX_IMPLEMENTATION_PLAN.md).
Current [public README #94](https://github.com/mongstad/Wavez/issues/94) and
[Python onboarding #95](https://github.com/mongstad/Wavez/issues/95) are separate
issues; documentation cleanup does not complete them or authorize publication.
