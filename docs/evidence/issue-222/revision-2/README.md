# Issue #222 review: compact form and internal mesh telemetry

Owner feedback requested removing the mesh-prefetch sentence below GPU budget
and reducing the excess dialog height. Candidate build remains **v0.1.0.61**,
on the existing issue branch/PR #273, pending owner review.

The mesh diagnostic label is hidden but remains updated by its original worker
status path. Worker metrics, budget state and errors remain available internally.
No preparation/allocation logic changed. Performance measures its visible form
after row layout and wrapping settle, then resizes vertically within existing
window/desktop bounds. Other Tools windows use their original sizing path.

## Focused results

- Mesh-only review: **34 checks passed**, zero failures, including hidden but
  populated mesh telemetry, compact opening, existing budget callback/clear
  behavior, source reload, normal/minimum widths and 1.5× scaling. Dialogs
  measured 560×240, 320×240 and 440×240 respectively.
- Mixed particle/field/mesh review: **59 checks passed**, zero failures, preserving
  the fuller form's row bounds, original editors, budgets, cache clear and reload.
- Both Forward+ / X11 runs shut down cleanly. `git diff --check` passed.

[Mesh report](mesh-report.json), [mixed report](mixed-report.json),
[mesh output](mesh-native.txt), [mixed output](mixed-native.txt).
[Normal](performance-mesh-normal.png), [minimum](performance-mesh-minimum.png),
[1.5× scaling](performance-mesh-scale-1.5.png).

[Mesh script](mesh_review.gd) and [mixed script](mixed_review.gd) use the initial
fixture/reproduction method with `/tmp/wavez-222-r2` (mesh-only fixture) and
`/tmp/wavez-222-mixed-r2` (mixed fixture) output/profile directories. A first run
exposed a missing explicit Vector2 annotation in the sizing helper; it was
corrected before the clean runs above. That initial run is not counted as a pass.

Initial evidence remains unchanged. Renderer/package/physical-display and
long-session limits remain as recorded in the initial report. No unrelated
scientific, mesh preparation or playback suites were run for this presentation
change. The checks verify retained diagnostic state, not an LLM integration.

Owner checks: open a mesh capture and Tools → Performance; confirm only the
budget configuration remains, without mesh-prefetch text or a large blank area.
Resize to minimum width, edit/restore both budgets, clear decoded cache, then
close/reopen and reload. With a mixed capture, confirm additional preparation
controls still fit and scroll. See [current guide](../../../PERFORMANCE_DIALOG.md).
