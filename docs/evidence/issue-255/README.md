# Issue #255: Keyboard Shortcuts without tooltips

Candidate build `v0.1.0.57` removes tooltip text from controls inside
**Edit → Preferences → Keyboard Shortcuts**. The shell and other windows retain
their tooltips. Historical issue #175 evidence remains unchanged.

## Focused evidence

- [Native Forward+ report](native-report.json): **10 checks passed**. The focused
  run inspected every Control in the dialog when first opened, while listening
  for a key, after Clear, after a conflicting binding, after Reset Defaults, and
  after scrolling to the final action. It confirmed that an outside shell
  control still has a tooltip and that the key transfer remains staged.
- [Hovered Reset Camera binding](shortcuts-hover-no-tooltip.png): native X11
  screenshot after the pointer rested on the binding button for 0.7 seconds.
  No tooltip obscures the dialog.
- [Headless shortcut validation](headless-validation.json): **300 checks passed**
  across the initial and fresh-process restart runs, including editing,
  conflicts, Clear, Apply, Cancel, Reset Defaults, focus, scrolling, and
  persisted bindings. Generated fixture hashes were unchanged.

The existing broad native shortcut runner reached the added tooltip assertions
but stopped at its unrelated Save Image picker assertion. That native run is
not counted as a pass. The focused native run above completes cleanly without
entering the image picker.

Owner review should hover the remaining visible controls and later rows,
exercise the editing flow on the usual desktop profile, then confirm the shell
tooltips still appear. Packaged and other-platform builds were not run for this
dialog-only change.
