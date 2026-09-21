# UX3 shell — issue #41

Shell accepted in owner-merged PR #45 (`884ea73`). Original baseline: `1043966`, PR #39.
The [issue-42 transport extension](UX3_TRANSPORT.md) is pending owner review.
Issue #41 was the sole Ready item on Project 1 before implementation. This is
only UX3-SHELL-001, not UX3 milestone acceptance. Historical design reports and
review evidence remain unchanged.

## Implemented behavior

- 48-logical-pixel Midnight Scientific command bar with 32-pixel controls:
  SimScope, Open…, capture/source details, State, Export, View and Help.
- State opens the existing **Capture / Export** or **Analysis export and state**
  controls. Their existing save/load rules remain authoritative, including v3
  promotion when selections exist. Export invokes the existing PNG picker and
  video dialog, or opens the numerical export controls. No duplicate forms.
- One right-hand dock: 360 pixels normally, 320 below 1200 logical pixels;
  drag the left edge between 320 and 560, constrained to retain at least 640
  pixels of unobscured scene. Four icon-and-label workspace choices become one
  chooser below 1200. Header/navigation stay fixed above a scrolling body.
- Scene retains the inspector and every legacy section/state key. Appearance,
  Selection and Analysis are bounded entry points to the same controls. The
  fixed header currently identifies the **capture**, with loading/preparation
  information. Object/channel editing belongs to the later workspace migration.
- Hide panel/F1 hides only the contextual right-hand dock and leaves Show panels.
  Frame scene, Reset camera and Navigate remain visible. At less than 970 logical pixels, the dock collapses;
  Show panels opens a temporary sheet that can be closed again. The 800×640 case
  is tested. Maximized windows keep the command bar. Fullscreen (View → Fullscreen
  or F11) hides the entire command bar and reclaims its space; exiting restores it.
  Camera controls and mouse-accessible Exit fullscreen remain visible.
  [Immersive fullscreen](UX3_FULLSCREEN.md) is a separate View action (Shift+F11):
  all application chrome is hidden, scientific overlays retain their visibility,
  and Esc restores the immediately preceding shell/native state.
- Frame scene, Reset camera and Navigate invoke existing camera behavior.
  Number/text input suppresses viewport shortcuts; a pointer release over chrome
  ends an existing camera drag. Hiding the dock restores valid prior focus on
  reopening. Source details use selectable/copyable text.
- Empty state provides Open without dummy scientific controls. Picker-driven
  opening yields for loading presentation before the existing synchronous open.
  Preparation text reads existing state; it does not invent a percentage. Failed
  replacement keeps the prior usable scene. Open-failure details remain available
  outside the scrolling inspector until explicitly dismissed, including after
  unrelated messages or a subsequent successful open.

## Boundaries and compatibility

This is overlay chrome around the **existing full-frame scientific viewport**.
The unobscured region grows when the dock closes; it is not a new SubViewport.
Camera transforms/projection, selection screen coordinates and offline rendering
retain their current ownership. No scientific image is resampled or cropped into
an independently sized viewport. Review the resulting framing with a wide scene.

The root window now uses its available logical size, retaining the configured
scale factor once, so shrinking the window activates compact layout rather than
shrinking a fixed 1440-pixel UI. The accepted theme and original repository-owned
provisional icon paths are consumed without changing tokens or finalizing artwork.
Long retained controls use the existing fitting helper and tooltips. Scientific
input precision, source names, stored labels and recipe keys are unchanged.

Playback has moved to the [persistent bottom transport](UX3_TRANSPORT.md).
Detailed readiness, scientific forms and their older labels remain in the inspector;
Persistent summary/Jobs access is composed by [issue #43](UX3_STATUS.md). Opening a workspace does not bind a source, change scientific
membership, run analysis or commit edits. No new persisted workspace fields,
background-job engine, decoder, cache policy or worker is introduced. The existing
`panel_width` and `overlay_visible` recipe fields remain readable; rendered dock
geometry is constrained by available space. Crossing the compact breakpoint
chooses its 320/360 default. The offline worker does not construct this shell and
retains its legacy overlay presentation. The original shell issue did not implement #42–44; #42 now extends it as linked above.
This shell contract does not implement #44,
UX4, Settings, new legends or other backlog polish.

## Validation

Native Godot 4.7.2, NVIDIA RTX 3070 Ti. Fresh synthetic `.ssc` fixtures only;
no scientific solver reruns. Commands are reproducible from the repository root:

```sh
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir results/new-shell-forward --renderer forward_plus
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir results/new-shell-compatibility --renderer gl_compatibility
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir results/new-shell-recipes --renderer headless
python tools/validate_camera_tumble.py --godot /path/to/godot --output-dir results/new-shell-camera --renderer forward_plus
```

The focused suite covers empty/picker cancel/open/failed replacement/successful
replacement, durable errors, native menu routing, dock focus/hide/recovery/resize,
fullscreen exit, numeric focus, frame/reset, v2 scene and worker-backed v3 recipe
round trips, source hashes, and zero instrumented scientific activity during shell
layout/navigation. Geometry assertions check actual logical dimensions and dock
child bounds, not just requested window size. Native screenshots show intentional
UI changes; they are not scientific pixel-equivalence claims.

Original review results and selected screenshots are in [the evidence index](evidence/issue-41/README.md).
The [owner-review revision](evidence/issue-41/review-1/README.md) records the actual
Fedora KDE/Wayland diagnosis, revised fullscreen screenshots and affected reruns.
The original 79-check runs below predate the revision and did not independently
validate compositor fullscreen geometry.

| Check | Result |
|---|---|
| Native shell, Forward+ | 79 passed |
| Native shell, Compatibility | 79 passed |
| Existing recipe ownership regression, headless | 3,051 passed |
| Existing camera tumble regression, Forward+ | 13,044 passed |
| Existing maintenance UI regression, headless | 28 passed |
| Final native import, Python syntax and Git whitespace | Passed |

The layout matrix is 1440×900 at 100% and 1024×640 at 100/125/150/200%.
The same native window is resized for each case; this is not physical mixed-DPI
monitor validation. Source capture hashes remain unchanged.

Initial sandboxed import failed on socket/settings permissions and one later
native launch was blocked from display access; both passed outside the sandbox. Development checks caught and corrected an initial script
parse error, excess command-bar padding and compact content overflow. A requested
1440×900 at 200% was capped by the window manager; it is excluded from the final
matrix rather than reported as a successful target-size check. The maintenance
harness initially failed because it assumed a fixed headless canvas and the old
scroll parent; its explicit size/scroll lookup now follows the production shell.
Review also corrected automatic-collapse legend visibility, with two focused
regression assertions.

Not run: physical 4K/mixed-monitor or assistive-technology review, long-session
comfort, full frozen external performance benchmark, full scientific regression
suite, complete video cancellation/FFmpeg matrix, and final icon-artwork review.
The shell test samples existing instrumentation and checks state/source invariance;
it does not establish a universal CPU/GPU performance bound. Broader worker/video
lifecycle acceptance remains in the separately gated status/integration slices.

## Exact owner verification before acceptance

1. Run the native viewer at 1440×900. Confirm the 48-pixel bar, readable labels and
   icons, four workspace choices, fixed capture header and independent scrolling.
   Repeat at 1024×640 and the normal desktop scale; check menus and numeric fields
   for clipping. Inspect keyboard Tab/Shift+Tab focus and button/menu activation.
2. Open a representative layered `.ssc`. Try Appearance → Scene layers,
   Selection → Selections and Analysis → Temporal analysis. Confirm the existing
   forms, budgets, volume mappings and playback are reachable and unchanged.
   Merely changing workspace must not alter the scene, selection or source binding.
3. Drag the splitter in both directions. Hide with the button and F1; recover
   using only Show panels. Maximize: the top command bar must stay visible.
   Enter fullscreen via View and then in a separate cycle via F11: the entire top
   bar must disappear, with no title bar or unused strip. Hide the dock, confirm
   Frame scene / Reset camera / Navigate remain, recover panels and exit using
   only the mouse. Confirm the command bar returns. Repeat F11 enter/exit. Repeat in an 800×640 window with the
   temporary sheet. Confirm focus returns appropriately.
4. Frame and reset a wide scene; tumble through a pole, zoom and use Navigate.
   Check framing while resizing/hiding the dock: projection remains full-frame.
   Type in numeric editors without triggering camera/playback shortcuts, then drag
   across the dock edge and release; camera motion must stop after release.
5. Cancel Open, open a valid capture, then choose invalid input. Confirm the old
   scene remains usable, Details explains the failure, and unrelated updates do
   not dismiss it. Dismiss explicitly and open another valid capture. Observe
   actual preparation on a cold capture; no invented percentage should appear.
6. Use State to save/load existing scene and analysis recipes. Check exact IDs,
   selections, probe visibility, volume mappings and paused restored playback.
   Use Export to save a PNG, reopen video export and reach numerical export.
   Confirm these use the existing dialogs and do not start work merely by opening.

Stop for owner review. Do not merge, auto-merge, close the issue, change Project
status or start another slice.
