# UX2 evidence — 2026-09-13

Implementation baseline: `7037f5f` (recorded UX1 acceptance), with accepted UX1 design at `229d4ea`. This is the new opt-in library's review evidence, not acceptance of a production migration.

## Retained results

- [summary.json](summary.json): full commands and successful strict runner result; Godot 4.7.2, Forward+, llvmpipe software Vulkan. All final command logs are free of warnings and errors.
- [validation.json](validation.json): **1,174 checks, zero failures**. Includes 300 independent float64 cases (parse, IEEE-754 bit equality and full-precision text round trip), exact int64 bounds, draft/cancel/validation, semantic states, keyboard and pointer input, native control sizes, 71 contrast pairs, root/dialog scale checks, 16 SubViewport size/scale cases and 13 screenshot writes. Check count includes individual assertions and captures, not 1,174 distinct workflows.
- [float64-oracle.json](float64-oracle.json): deterministic Python `float`/`struct.pack` reference bits, seed 20260913, including subnormals, ties-to-even, negative zero, extrema, decimal syntax and a long bounded mantissa. The native Godot parser disagreed with 137 of these 300 cases; individual disagreements are recorded in `validation.json`. The new bounded parser agrees with all 300.
- [isolation.json](isolation.json): **six checks, zero failures**. A small loaded particle/mesh/volume fixture has identical scientific/native recipe snapshots and byte-identical existing production UI/viewport pixels before and after library load, component edit and theme reconstruction. Scientific instrumentation has no counters/stages. Root theme, global theme setting and main scene remain unchanged.
- [hud.json](hud.json): the existing native HUD regression passes **six** width/time-mode cases through digit transitions.
- [native.log.txt](native.log.txt), [isolation.log.txt](isolation.log.txt), [hud.log.txt](hud.log.txt): final clean native logs. Full import/fixture output and temporary configuration remain in ignored local results.
- [repository-review.json](repository-review.json): staging scope, sizes, source/assets hashes and credential-pattern review; preserves the 15 pre-existing untracked layer UIDs.

## Visual evidence

| Image | Evidence |
|---|---|
| [Controls](01-controls-focus-hover.png) | Native focused/hovered primary action, pressed/selected buttons, unavailable explanation, checkbox/radio, search, option, slider/spin, tree and list |
| [Numbers](02-numbers.png) | Exact int64 IDs/extrema, float64/subnormal display, visible invalid draft, focus ring, mono digits, narrow stacked property row |
| [Feedback](03-feedback.png) | All four semantic severities, status badges, known/unknown progress, durable notification and tooltip specimen |
| [Tokens](04-tokens.png) | Surface hierarchy, typography, semantic colors and logical metrics |
| [Slider focus](05-slider-focus.png) | Shared persistent focus ring around a native slider |
| [Popup menu](06-menu.png) | Native menu, selected item, checked item and unavailable item |
| [Dialog](07-dialog.png) | Embedded Window chrome, fixed title/actions, scroll body and focus |
| [100%](scale-1440x900-100.png), [125%](scale-1440x900-125.png), [150%](scale-1440x900-150.png), [200%](scale-1440x900-200.png) | Same 1440×900 physical target; scale changes logical working area, retains control/font metrics and reflows columns |
| [Small stress case](scale-1024x640-200.png) | 1024×640 at 200% (512×320 logical): visible navigation and scrolling rather than reduced type |
| [4K target](scale-3840x2160-200.png) | Actual 3840×2160 Godot SubViewport at 200%; not a physical 4K monitor test |
| [Production preserved](production-preserved.png) | Before/after production images are byte-identical; one copy retained, both original hashes in isolation evidence. Existing production styling is intentionally unchanged |

Images were inspected directly during implementation. The final dialog also verifies text against its actual title background. Input is programmatic native Godot input, not a human keyboard/mouse usability session. Scaling is not a physical mixed-DPI or cross-monitor test. No accessibility certification or release-wide performance claim is made.

## Reproduction

From the authoritative repository root, using Python with the project's dependencies and a Godot-capable display:

```bash
python3 tools/validate_ux2.py --godot /path/to/godot --output-dir results/ux2-new-review
python3 tools/validate_documentation.py --output-dir results/ux2-new-docs
```

The output directory must not exist. The runner imports resources, creates synthetic `.ssc` fixtures and independent reference bits, then runs the native foundation, production isolation and existing HUD checks sequentially. It rejects warnings/script errors even if the engine returns exit code zero. It sets writable XDG paths and uses the invoking Python for worker lookup. The final retained run used `/home/Nozba/Downloads/Godot_v4.7.2-stable_linux.x86_64` and `/tmp/perf003-analysis-runtime/bin/python` (Python 3.14.7), writing ignored output to `results/ux2-accepted-candidate/`; the directory name is a review candidate, not milestone acceptance.

No scientific benchmark/simulation was rerun. No new deterministic video encode, complete G4 suite, GPU performance benchmark or physical multi-monitor acceptance was performed. The scoped preservation evidence and unchanged production source support UX2 isolation only. See [UX2 report](../../UX2_REPORT.md) and [theme guide](../../UX2_THEME_LIBRARY.md) for limits and proposed adjustments.
