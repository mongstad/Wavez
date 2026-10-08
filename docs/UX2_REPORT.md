# UX2 — Theme Foundation & Component Library milestone report

**Status: COMPLETE — awaiting review. UX3 NOT STARTED.**

2026-09-13. The owner explicitly authorized UX2 after accepting UX1 at `229d4ea`. Implementation starts from `7037f5f`, the recorded acceptance checkpoint. This report requests review of the isolated visual foundation, not approval of a production shell or panel migration.

## Implemented

| Deliverable | Result |
|---|---|
| Shared theme foundation | Canonical typed tokens, loadable Godot Theme, generated native control styles and semantic variations; no global theme installation |
| Primitive components | Action/icon actions, responsive property rows, disclosures, scientific float64 and exact int64 editors, stable-ID options, approximate slider/spin controls, status badges, inline messages/notifications, progress and dialog shell |
| Semantic states | Normal/hover/pressed/selected, independent keyboard focus, disabled reasons, read-only values, error drafts, info/success/warning/error feedback; native checkbox/radio, trees/lists, tabs, menus and tooltip surfaces |
| UI Laboratory | Dedicated capture-free `viewer/ui/lab/ui_laboratory.tscn`, with four review pages and 100/125/150/200% scaling |
| Typography/assets | Existing Godot fallback sans, separate bundled DejaVu Sans Mono 2.37 with original license, original SVG command icons imported as per-viewport DPITexture resources |
| Documentation/evidence | [Theme guide](UX2_THEME_LIBRARY.md), [reproducible validator](../tools/validate_ux2.py), [evidence guide](evidence/ux2/README.md), 14 retained native screenshots and this report |

## Files changed

New implementation is confined to `viewer/ui/theme/`, `viewer/ui/components/`, `viewer/ui/icons/`, `viewer/ui/fonts/` and `viewer/ui/lab/`. Components use native Godot controls and explicit signals, without scientific controllers or per-frame callbacks. The additional numeric parser belongs to the new scientific editor only.

New validation tool: `tools/validate_ux2.py`. New documentation/evidence: `docs/UX2_THEME_LIBRARY.md`, `docs/UX2_REPORT.md`, `docs/evidence/ux2/`. Canonical README, current status, evidence index, UX milestone table and third-party font inventory are synchronized. The accepted UX1 specification and historical evidence remain unchanged.

## Behavior intentionally changed

The new development scene can be launched directly for visual review. It emits local action/selection/value intents, allows responsive scaling, and demonstrates a scrolling dialog. Its font, geometry and state treatments derive from shared resources.

The new scientific editor explicitly separates draft, commit and cancel. It supports finite float64 including subnormals, and exact decimal signed int64 IDs. Invalid drafts retain the last committed model. Refresh is silent; unchanged commit preserves model bits; focus loss does not implicitly submit. These semantics are not applied to any existing production input in UX2.

## Behavior preserved

**Production UI and scientific workflows remain unchanged.** All 195 previously tracked files under viewer/exporter/examples/tests match the baseline. There are no edits to `project.godot`, `Main.tscn`, `main.gd`, rendering/particle/mesh/field controllers, data readers/writers, selection/analysis, recipes, camera, playback, scientific palettes, PNG/video exporters or existing tests.

An executed isolation check loads a small current SIMSCP3 particle/mesh/volume fixture and exercises the new library in a separate SubViewport. Scientific/native recipe snapshots and the entire production viewport/UI image remain byte-identical. No scientific preparation/hash/upload instrumentation fires during library activity; root/global theme and startup scene stay unchanged. This is direct evidence for the UX2 boundary, not a fresh claim that every production workflow was rerun.

## Findings and proposed adjustments

The accepted palette and font/control-height tokens are retained. Actual sans height is **20 px** at 14 px type, mono height **17 px** at 13 px type, and every digit advances **8 px**. Derived padding gives actual native buttons of **32 px**, compact buttons **28 px**, and icon targets **32×32 px**. The laboratory reflows and scrolls without shrinking type.

Review the following implementation decisions before freezing UX2:

1. `border.control` reaches only **2.782:1** on hover and **2.389:1** on pressed fills. Use existing `text.secondary` for those active outlines.
2. Error-colored text reaches only **4.224:1** on the pressed neutral fill. Destructive pressed labels use primary text while retaining the error border and explicit action name.
3. Read-only scientific values use secondary text; they remain useful content rather than unavailable values. Percent text sits outside progress fills to preserve contrast.
4. Native HSlider has no focus StyleBox slot. A small reusable subclass draws the shared persistent ring without a process loop.
5. Immediate native state changes are retained in UX2. The proposed 80/60 ms motion tokens are present but not animated; adjacent-tooltip timing and reduced-motion preferences remain later interaction work. This is an explicit review adjustment, not a claim that those motion details are implemented.
6. The tested Godot decimal parser disagrees with **137/300** independent float64 references, including valid subnormals turning into zero and halfway mantissas rounding incorrectly. The new field uses a bounded integer-limb decimal-to-binary64 parser with ties-to-even, validated against all 300 references. It refuses overlong/non-finite/overflow/underflow-to-zero drafts; no production parser is replaced.

Details and usage contracts are in the [theme guide](UX2_THEME_LIBRARY.md#accepted-ux2-metrics-and-implementation-adjustments); individual numeric mismatches and corrected reference checks are retained in [validation evidence](evidence/ux2/validation.json).

## Validation performed

| Executed check | Result |
|---|---|
| Resource import and strict command logs | PASS; final import and native runs have no script errors, engine errors or warnings |
| Native foundation validator | **1,174 assertions/capture checks, zero failures**; count includes per-case numeric and palette assertions, not distinct workflows |
| Independent float64 oracle | **300/300** input bit patterns and formatted round trips; tiny/large values, subnormal extrema, ties-to-even, negative zero, decimal syntax, bounded long mantissa and deterministic random finite binary64 values |
| Exact integer/draft behavior | Signed int64 extrema, IDs above 2^53, overflow/decimal/exponent refusals, scientific validation, silent refresh, unchanged bits, native Enter/Escape and retained focus-out draft pass |
| Native interaction | Space, Tab/Shift-Tab, pointer hover/press/release, selected toggles, disabled reason, slider focus, enum no-signal refresh and dialog focus recovery pass |
| Metrics/scaling | **16** SubViewport combinations: 1024×640, 1440×900, 2560×1440, 3840×2160 × 100/125/150/200%; every page fits horizontally; logical control heights retained. Native root and dialog boundary checks pass at all four scales |
| Contrast | **71** actual-theme/palette combinations pass 4.5:1 ordinary text or 3:1 meaningful indicators; disabled text is not represented as passing the ordinary text target |
| Production isolation | **6/6** checks pass, including identical scientific snapshots and production pixels |
| Existing native HUD regression | **6/6** width/time-mode cases remain stable across digit transitions |
| Source invariance | **195/195** protected existing files match `7037f5f` |
| Documentation | Local Markdown links and three executable public API examples pass; historical locked documents remain valid |
| Repository review | Whitespace, staging scope, file sizes, asset hashes and credential-pattern review completed; no captures, caches, environments or scientific results staged |

Runtime: Godot **4.7.2** Forward+ using **llvmpipe software Vulkan**, Python **3.14.7**. [Commands, logs and hashes](evidence/ux2/README.md) are retained. No external simulation was run.

Manual/visual work consists of direct inspection of rendered native screenshots, including controls, numerical fields, semantic feedback, tokens, menu, dialog and the scale matrix. This was not a human physical-input usability session. The layout and contrast defects discovered during implementation were corrected and the final candidate rerun.

## Screenshots

[Controls and states](evidence/ux2/01-controls-focus-hover.png), [numbers](evidence/ux2/02-numbers.png), [feedback](evidence/ux2/03-feedback.png), [dialog](evidence/ux2/07-dialog.png), [4K/200% target](evidence/ux2/scale-3840x2160-200.png). The [evidence map](evidence/ux2/README.md#visual-evidence) lists all 14 retained images. Production before/after hashes are identical; one preserved production screenshot is retained instead of duplicate PNGs.

## Known limitations and follow-up candidates

- Visual acceptance and subjective density/readability remain with the reviewers. Palette arithmetic and programmatic focus tests do not certify accessibility.
- The scaling matrix uses actual offscreen Godot controls. Physical 4K, mixed DPI, native multi-monitor behavior, assistive technology and other platforms remain untested. Small logical canvases scroll; UX2 does not establish a production minimum window size.
- This run uses software Vulkan. No new GPU performance benchmark, Compatibility acceptance, full G4 regression, deterministic video encoding or release-wide workflow sweep is claimed. Production source/pixels/state isolation and the focused HUD check are the proportional UX2 evidence.
- DPITexture is an experimental Godot API and should be revalidated on an engine upgrade. No distributed executable/export package was built in UX2.
- Scientific drafts are bounded at 768 characters. Consumers must supply their own units and domain validation and must not use approximate slider/spin controls for scientific thresholds or exact IDs.
- Notifications are primitives: controllers own lifetime, recovery details and acknowledgement. No job center, automatic expiry manager, settings preference or application-owned job behavior is introduced.
- Native instantaneous states and deferred tooltip/motion details are disclosed above for review.

## Repository state

- Branch: `main`; baseline/parent `7037f5f`.
- UX2 commit: the local checkpoint containing this report, titled **“Implement isolated UX2 theme foundation and UI laboratory”**. Resolve with `git log -1 --format=%H -- docs/UX2_REPORT.md`; the handoff supplies the ID.
- Committed locally for review. No push as accepted work, release tag or package version bump.
- The 15 pre-existing untracked layer `.gd.uid` files are preserved and unstaged. Additional temporary UIDs generated by the validation import outside the new library are removed; library import descriptors and script UIDs are included.
- No external repository or simulation changes. The sibling, non-authoritative copy of the UX plan is untouched.

## Out of scope / stop

UX3 main viewer shell, UX4 production panels, settings, detachable windows, workspace persistence, later interaction/release passes, G5/G6, web/remote/AI/extensions have not started through this work.

**STOP: UX2 is complete for review. Await explicit acceptance and authorization before beginning UX3.**
