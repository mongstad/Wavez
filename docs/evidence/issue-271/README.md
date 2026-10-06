# Issue #271: shared dialog hierarchy accents

Candidate `v0.1.0.60` on the existing issue-linked branch is pending owner review.
Preflight found #271 as the sole Ready item in Wavez Development. The linked
branch, local `main` and `origin/main` matched accepted `e0b2771` (owner-merged
shortcut grouping PR #270); the tree was clean. Remote references were pruned
and no completed local issue branch remained.

## Focused results

- [Headless shortcuts](headless-shortcuts.json): **346 checks passed**, including
  capture/conflicts, Apply/Cancel, restart persistence and unchanged fixture hashes.
- [Native Forward+ shortcut groups](native-shortcut-groups.json): **276 checks
  passed**, including category order, focus across categories, tooltip absence,
  conflict transfer and scrolling at 1440 × 900, 970 × 600 and 640 × 480.
- [Real File/Tools dialog routes](dialog-report.json): **118 checks passed** on
  Forward+, including Video Export and its cancellation confirmation, desktop
  bounds and unchanged synthetic fixture bytes.
- [Temporary theme/scaling review](hierarchy-report.json): **79 checks passed**.
  An accepted-main theme snapshot and the candidate production theme differed
  only at `PanelTitle.font_color`, `SectionTitle.font_color` and
  `Window.title_color`. Existing constants and font sizes matched. Both accent
  labels exceeded 4.5:1 against the dialog surface; brightness ordered disabled,
  section, title, ordinary text. Live Shortcut and Video group labels inherited
  the new color, with the shortcut footer contained at 1× and 2× scaling.
  Requested 3840 × 2160 at 2× was constrained by the available X11 desktop to a
  2560 × 1394 window; this is simulated high scaling, not physical 4K proof.
- Godot 4.7.2 editor import completed cleanly. Five unrelated generated UID
  sidecars were removed. `python -m unittest tests.test_application_version`:
  **2 passed**. `git diff --check` passed.

Commands used the external Godot executable with isolated test profiles:

```sh
python tools/validate_keyboard_shortcuts.py --godot /absolute/path/godot --renderer headless --output-dir /tmp/issue-271-headless
python tools/validate_keyboard_shortcuts.py --godot /absolute/path/godot --renderer forward_plus --group-only --output-dir /tmp/issue-271-groups
python tools/validate_dialog_coherence.py --godot /absolute/path/godot --renderer forward_plus --output-dir /tmp/issue-271-dialogs
```

The [temporary review script](hierarchy_review.gd) is retained for reproduction.
Before running it with `--script`, save accepted `main`'s
`viewer/ui/theme/wavez_theme.gd` to `/tmp/wavez-theme-271-before.gd`, and save
accepted `main`'s `violet_slice_theme.gd` to `/tmp/wavez-violet-271-before.gd`
with its parent path changed to that baseline file. The script writes to
`/tmp/wavez-271-review`; set isolated `XDG_DATA_HOME`/`XDG_CONFIG_HOME` directories.
These are temporary evidence paths, not production resources.

Native checks used X11. Validation targets the shared typography and directly
inheriting dialog surfaces. Playback, scientific integrity, rendering, camera
and export-worker suites were not warranted by these color-only assignments.
Compatibility comparison was not required: the change uses the same Control
text/theme path with no renderer-dependent code. Packaged Linux, other OSes,
physical 4K/mixed-DPI, assistive technology and long-session checks were not run.

## Incomplete older test

The older `video/test_export_dialog_group.gd` run is **not a pass**. Its fake
viewer lacks `_clear_manual_navigation`, so `open()` stops before initializing
the timeline, followed by nil `times`/missing `start_time` errors and a stalled
process. The same failure reproduced on an isolated `git archive main` snapshot
at `e0b2771`; it is pre-existing. The candidate process was stopped; the baseline
run used a 12-second timeout. See [candidate log](old-video-test-candidate.txt)
and [accepted-main log](old-video-test-main.txt). The real-viewer dialog check
above completed cleanly. The temporary theme comparison initially missed newly
explicit inherited color keys; its comparison was corrected to use the union
of theme keys, then completed with 79 checks and no failures.

## Visual evidence

- [Normal shortcuts](shortcuts-normal.png), [compact shortcuts](shortcuts-compact.png),
  [scrolled focused row](shortcuts-scrolled.png), [2× shortcuts](shortcuts-scale-2.png).
- [Video Export](video-export.png), [2× Video Export](video-scale-2.png).
- [Mapping](mapping.png), [cancel confirmation](cancel-confirmation.png).

Images show subdued lavender headings, neutral rows and separate focus/disabled
states. Review steps are in [the current guide](../../DIALOG_HIERARCHY.md).
Historical #143/#161/#248/#259 reports and their review-time wording are preserved.
