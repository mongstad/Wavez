# UX1 — Audit & Design System Specification milestone report

**Status: COMPLETE — awaiting review. UX2 NOT STARTED.**

2026-09-13. The owner accepted pre-UX retirement and authorized UX1 only. The baseline is `47fef34dc5bdcbbc8db7f562f778deb100a70d5c`, SIMSCP3 / `.ssc`, package 2.0.0. The accepted retirement checkpoint was pushed to the private origin. UX1 is a separate local checkpoint for review.

## Deliverables completed

| Requirement | Result |
|---|---|
| Current UI inventory | [UI audit](UX1_UI_AUDIT.md): windows, inspector sections, layer controls, overlays, file/export dialogs, settings, shortcuts, focus and scaling; 590 constructed controls in the loaded fixture |
| UX/problem inventory | 20 prioritized findings U01–U20, distinguished as runtime observation, source evidence or design judgment |
| Coupling/risk inventory | 13 risks C01–C13 covering live label/schema dependencies, exact numbers, async lifecycle, viewport input, render snapshots and job ownership |
| Information hierarchy | [Design specification](UX1_DESIGN_SYSTEM.md): persistent command/transport/status areas, one contextual dock, explicit source/analysis/result/export scopes |
| Concrete design system | Opaque neutral surfaces, semantic text/colors, contrast targets, typography, spacing, geometry, input states, motion and scale rules |
| Reusable components | Explicit contracts for actions, disclosures, property rows, exact/scientific numeric editors, selectors, status/jobs, dialogs, source context and future transport/result compositions |
| Theme/token architecture | Proposed Godot Theme/token Resource, role variations, scale boundary and gradual presenter adapters; no runtime resources implemented |
| Regression-sensitive workflows | [13 workflow gates](UX1_REGRESSION_WORKFLOWS.md) mapped to existing native validators and additional physical-input/DPI acceptance |
| Milestone evidence/report | [Evidence guide](evidence/ux1/README.md), 15 reviewed screenshots, compact inventory/measurements, source hashes and this report |
| UX1-only boundary | No production UI, theme, component scene, icon/font asset or UX2 laboratory added |

## Main findings and proposed direction

After loading the small combined scene, the timeline starts at y=1472 in a 900 px logical window. Open and export also depend on scrolling. Requested inspector width 290 still yields 367 because current controls impose a larger minimum. Video export actions require scrolling. F1 hides the mouse restore affordance. Scene and G4 recipe actions have identical labels despite different scope.

The proposal keeps transport, readiness and file actions persistently accessible; uses one contextual workspace dock; distinguishes scene recipes from analysis bundles; and adopts a restrained neutral theme. Exact IDs and float64 scientific entries have separate editor contracts from approximate visual sliders. Existing scientific rendering colors and normalization remain independent of UI tokens.

The highest migration risks are visible text used as saved-state keys, widgets directly mutating rendering state, requested versus committed time during buffering, cross-panel scientific inputs, and full Viewer construction in deterministic export. The specification defines compatibility adapters and gate-specific tests before those surfaces change.

## Files changed

New specification documents: `docs/UX1_UI_AUDIT.md`, `docs/UX1_DESIGN_SYSTEM.md`, `docs/UX1_REGRESSION_WORKFLOWS.md`, `docs/UX1_REPORT.md`.

New audit-only tooling: [audit_ux1.gd](../tools/audit_ux1.gd) and [summarize_ux1.py](../tools/summarize_ux1.py). These collect current UI evidence and verify palette/source invariance; they are not linked from the running application.

New retained evidence: `docs/evidence/ux1/` contains the evidence guide, inventory/summary, palette calculations, baseline file hashes, native logs/HUD geometry, documentation validation, repository review and 15 PNGs. Generated `.ssc` fixtures and bulky per-state output stay ignored under `results/ux1/`.

Updated navigation/status: [README](../README.md), [current status](CURRENT_STATUS.md), [evidence index](EVIDENCE_INDEX.md), [UX milestone table](../UX_IMPLEMENTATION_PLAN.md). The [handbook](WAVEZ_HANDBOOK.md#recipes-png-and-deterministic-video) corrects a stale recipe-support sentence to the existing native v2 scene / v3 G4 contract. The historical retirement report and frozen evidence were not rewritten.

## Behavior changed and preserved

**Product-facing visual/functional changes: none.** All 195 baseline-tracked files in viewer, exporter, examples and tests remain byte-identical. The package version and capture/recipe/job formats are unchanged. The new hierarchy, labels, tokens and component paths are proposals only.

Preserved by unchanged code: native capture storage, identities and checksums; particles/mesh/volume playback; async preparation and bounded caches; timeline/selection/scientific semantics; camera and shortcuts; inspection recipes; PNG and deterministic video; existing external benchmark integrations. UX1 does not claim fresh end-to-end validation of every preserved workflow: it uses the accepted retirement implementation and limits its new execution to the audit and relevant checks below.

## Validation performed

| Check actually run | Result / scope |
|---|---|
| Godot audit script parse | Final script passed with a writable XDG data directory and clean output. An earlier parser invocation emitted only a sandbox user-log write diagnostic; GPU runs used a writable directory and clean logs |
| Small analytic scene generation | Passed; 64 explicit-ID particles, mesh and 32³ volume channels over nine union times; no scientific solver |
| Native Forward+ audit | **37 checks, 0 failures**. Includes 26 screenshot writes and 11 controller/observation checks: preparation, G4 binding, exact-ID selection, population result/plot, screenshot-directory cancellation and hide/fullscreen behavior. Deficiency observations count as collected evidence, not usability passes |
| Existing native HUD regression | **6 cases stable** at requested widths 290/366/600 in physical/index modes across digit transitions; no HUD height or control-position shifts |
| Proposed palette arithmetic | **46 pairs passed** their specified 4.5:1 text or 3:1 indicator threshold; does not certify current UI |
| Source invariance | **195/195 files identical** to accepted baseline in viewer/exporter/examples/tests |
| Documentation validation | Local links across **54 Markdown documents** and **3 executable current API examples** passed; historical hash-locked reports remained valid |
| Repository review | Whitespace/diff, staged file sizes and credential-pattern review; no captures, videos, environments or pre-existing UID files staged |

Reproduction commands, runtimes and scope are in the [evidence guide](evidence/ux1/README.md). Exact automated results are in [native summary](evidence/ux1/summary.json), [HUD geometry](evidence/ux1/hud.json), [contrast](evidence/ux1/contrast.json).

Visual inspection: reviewed all 15 retained screenshots directly, including empty/default/scroll states, selection and native result plot, mesh/volume settings, video and recipe dialogs, the constrained window and 4K target. This was screenshot inspection of programmatically exercised native UI, not a human physical-input usability session. No keyboard-only, screen-reader, cross-monitor or subjective readability acceptance is claimed.

## Known limitations and follow-ups

- Frequency/placement decisions are informed design judgments; no user telemetry or observed scientist task study was supplied. Validate the proposed dock placement and minimum logical window size in UX3.
- UI diagnostics describe this fixture and backend. Two displays were reported, but only the current 2560×1440 screen was used. The 4K screenshot is a GPU SubViewport with an export-style logical canvas, not a physical 4K/mixed-DPI check. Its synchronous fixture viewer omits the desktop particle-buffer controls.
- The collector freezes the main viewer's process/unhandled-input callbacks for stable audit capture. Controller queries and preparation still run. Screenshots are UI inventory evidence, not deterministic scientific render comparisons.
- Most control focus behavior is inherited from Godot. Actual keyboard traversal, assistive technology, native window behavior and all proposed scale/density combinations require later milestone validation.
- No new movie encoding, retained benchmark execution, complete G4 suite or scientific simulation was run. Historical benchmark limitations remain historical evidence rather than newly rerun acceptance.
- Current UX deficiencies remain in the product by design during UX1. The proposed theme does not resolve them until subsequent milestones are separately authorized. Numeric font packaging, physical contrast/focus checks and live recipe-label migration tests belong to UX2 and later consumer work.

## Repository state

- Branch: `main`.
- Accepted baseline/parent: `47fef34dc5bdcbbc8db7f562f778deb100a70d5c`; private `origin/main` synchronized to that accepted checkpoint before UX1 staging.
- UX1 commit: the checkpoint containing this report, titled **“Specify UX1 design system and audit current native UI”**. Resolve its full ID with `git log -1 --format=%H -- docs/UX1_REPORT.md`; the final review handoff records the ID.
- UX1 is committed locally for review and is not pushed as accepted work. No release tag or version bump.
- Tracked product files are unchanged. The completed checkpoint contains only the listed documentation, audit tools and evidence; 15 pre-existing untracked `viewer/layers/*.gd.uid` files remain untouched and unstaged. See [repository review](evidence/ux1/repository-review.json).
- Historical reports, archived scientific sources and frozen benchmarks remain unchanged. No external repository edits in UX1.

## Out of scope / stop

UX2 theme foundation, component implementation and UI laboratory have not started. UX3–UX9, G5/G6, detachable windows, workspace persistence, web/CEF, remote control, AI and extension frameworks have not started through this work.

**STOP: UX1 is complete for review. Await explicit approval before beginning UX2.**
