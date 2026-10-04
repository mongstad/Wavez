# Issue #248 Video Export dialog review evidence

Native Forward+ screenshots from the focused Video Export dialog harness:

- [Idle at 700 × 650](video-groups-idle.png): titled setting groups and a separate Export summary.
- [Idle at 560 × 360](video-groups-compact.png): settings scroll while the summary and actions remain visible.
- [Active at 560 × 360](video-groups-active.png): status text scrolls inside Export status; settings and actions remain reachable.
- [Cancellation confirmation](video-cancel-confirmation.png): one question with spaced Yes/No actions and No focused.

The Wayland desktop scaled the saved image pixels relative to the logical dialog
dimensions. The harness uses a generated three-sample timeline and a simulated
active status for these screenshots; the separate native export lifecycle check
exercised a real worker. No production capture or physical mixed-DPI display
was used for this layout change.

| Check | Result |
| --- | --- |
| Focused dialog, native Forward+ | 46 checks pass |
| Focused dialog, native Compatibility | 46 checks pass |
| Existing video export/Jobs lifecycle, native Forward+ | 317 checks pass; generated source hashes unchanged |
| Diff whitespace check | Pass |

The focused checks cover group membership, numerical estimate, range timing,
resolution/FPS presets, camera/output job values, active locking, focus movement,
minimum-size scrolling, and confirmation wording/default focus/button widths.
The lifecycle check covers real worker launch, completion, background state,
cooperative cancellation and configuration locking. The owner should inspect
the normal and minimum dialog sizes and try the native output picker, then
start a small export and verify the status and No/Escape cancellation paths.
