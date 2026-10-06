# Jobs row clearance — issue #251

Candidate application build `v0.1.0.56` places the Jobs list below the actual
header container, with 8 logical pixels of vertical separation. The row
content also starts 16 pixels inside the scroll viewport. This space keeps the
first Open… button's outside focus ring fully visible, including its top edge.
The same layout applies when the video row is disabled or enabled, after
reopening, and when the list scrolls in a compact window.

The five Jobs rows retain their order, action widths and aligned Cancel column.
The title, close paths, focus selection, job owners, enabled states and
background work behavior are unchanged. The current [issue #251 evidence](evidence/issue-251/README.md)
contains native screenshots and validation results, including the owner's
focus-ring correction. The earlier
[#237 review record](evidence/issue-237/README.md) remains historical.

## Owner checks

1. Open Jobs with no capture. Verify the disabled Video export row sits clearly
   below the title/header, while Selections Open… receives focus with its full
   outline visible. Close and reopen Jobs; the spacing should stay the same.
2. With a capture open, inspect the normal dialog at 1440×900 and 1024×640.
   Check that all five rows and Close fit, and that Open…, Details… and Cancel
   remain aligned with readable spacing.
3. Start a short video export, leave it running in the background, and reopen
   Jobs. Video export Open…, Details… and Cancel should be enabled as before;
   the focused Open… outline and its top edge should be visible. Reopen the
   running export and cancel through the existing confirmation path if desired.
4. Reduce the available window height. Verify the Jobs list scrolls, the
   first row stays below the title, the Cancel column clears the scrollbar,
   and later rows remain reachable. Check header Close, footer Close, Escape
   and window-close dismissal.
