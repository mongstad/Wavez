# Issue #222 review: focus-outline clearance

Owner screenshots showed the Decoded cache and GPU budget focus outlines
clipped by the scroll surface. Performance now reserves 8 px of internal
padding on every side. Its fitted height includes this padding, retaining a
compact **560×254** mesh-only form. The shared Tools scroll surface removes
this override when another form opens. Focus styling and existing callbacks
remain unchanged. Build remains **v0.1.0.61**, pending owner review on PR #273.

The [focused native script](focus_review.gd) completed **47 checks with zero
failures** on Forward+ / X11. It includes the previous mesh-only budget/clear,
diagnostic-retention, compact-size, repeated-open and reload checks, plus:

- actual LineEdit focus for both budget fields at 560 px, 320 px and 1.5× scaling;
- focus StyleBox expansion bounds fully inside the scroll clip for each field;
- focused outlines clearing the Close action row;
- opening Mapping removes the Performance-specific scroll padding.

[Report](report.json), [native output](native.txt),
[Decoded cache focused](decoded-focused-560-scale-1.0.png),
[GPU budget focused](gpu-focused-560-scale-1.0.png),
[minimum-width GPU focus](gpu-focused-320-scale-1.0.png),
[1.5× GPU focus](gpu-focused-440-scale-1.5.png).
Both budget focus states were visually inspected. The run shut down cleanly;
`git diff --check` passed. Reproduction uses the original mesh-only fixture
method with `/tmp/wavez-222-r3` output and isolated profile directories.

Earlier evidence remains unchanged. Renderer/package/physical-display and
long-session limitations remain as recorded. The fuller mixed-source suite
was not repeated for this local focus padding change; the affected clip and
size calculations were checked directly. No unrelated scientific/cache suites
were run.

Owner check: Tab/click into Decoded cache and GPU budget at normal/minimum sizes,
confirm a complete outline on all sides, then hover Clear decoded cache and
focus Close. Check preferred display scaling and a fuller Performance form's
scrolling. See [current guide](../../../PERFORMANCE_DIALOG.md).
