# Production UI ownership — issue #59

This dependency audit distinguishes retired presentation from canonical controls.
Issue #59 is pending owner review; UX4 migration and #44 integration acceptance
remain separate work.

| Candidate / category | Construction / consumer before cleanup | Ownership | Action |
|---|---|---|---|
| Left panel position, rounded style, width/height layout and resize callback (A) | `main.gd::_build_inspector`, `_layout_inspector`; offline viewers only after #55 | Presentation only | Remove. Neutral dock/scroll/inspector containers use `ViewerShell.layout` exclusively. |
| Standalone F1 hide/show buttons (A) | Inspector builder; offline-only Hide and always-hidden Show | Duplicate presentation | Remove; shell Hide panel / Show panels remains canonical. |
| Playback section and hidden transport `legacy` container (C) | Inspector builder; transport reparents three buttons/slider, hides the rest | Duplicate seek/rate controls and presentation | Construct buttons/slider directly in transport; remove old Seek spin/button/rate slider, callback and commit-time synchronization. Controller references still point at the actual transport controls. |
| Offline/export shell switch (D) | `export_shell` in main and video worker | Chooses obsolete left UI for other offline instances | Remove. Every fully constructed viewer uses the production shell; offline only disables desktop input/automatic presentation refresh. Video explicitly refreshes after committed samples. |
| Dock/scroll/inspector VBox (B) | Main creates; shell owns layout and workspace routing | Neutral ownership of canonical controls | Retain without left-panel style/geometry. |
| HUD, status message, field availability, cache controls (B) | Main builder; visible right inspector, Source details and status diagnostics | Canonical information/cache bindings | Retain for UX4. |
| Rendering, Color Mapping, Size/Brightness, Camera, Trails, Filters, Post-processing (B) | Main builder; right inspector and workspace shortcuts | Canonical scientific/controller bindings | Retain all reachable controls, including existing camera/export shortcuts. |
| Geometry, source probe, scene-layer particle/mesh/field/volume controls (B) | Main geometry builder and `scene_layers.gd` | Canonical layer/probe state | Retain for UX4. |
| Selections, temporal/space-time analysis, diagnostics, matched runs, results/export/state (B) | Selection/analysis controllers attach sections | Canonical controllers/jobs and their controls | Retain without changes to ownership or science. |
| Capture / Export, recipes, PNG sidecar and help (B) | Main inspection builder and video dialog | Reachable supported controls | Retain for UX4; shell command shortcuts call the same actions. |
| Scientific colorbar/legend (B) | Sibling CanvasLayer controls; shell places them | Scientific presentation, existing visibility gates | Retain; not obsolete application chrome. |

## UX4 handoff

The retained inspector groups above still originate in `main.gd` (now
`_build_inspector_controls`) or canonical layer/selection/analysis builders. UX4
must migrate those actual widgets or replace their bindings deliberately; this
cleanup neither copies widgets nor organizes new workspaces. Existing section
keys remain for these groups. The removed hidden Playback disclosure and rate
slider are no longer emitted in visual presentation snapshots. Recorded-time
rate, seek, union index, buffering and scientific recipe semantics are unchanged.

Interactive and offline viewers share one construction path. Offline shell
refresh is explicit, using `prepare_export` / `refresh_export`; there is no
left-panel fallback. Tests that need scientific-only images explicitly hide production chrome (or
use the export visibility helper), instead of selecting a retired UI architecture.
