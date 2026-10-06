# Issue #271: stronger hierarchy accents

Owner feedback requested immediately visible structure instead of the initial
barely perceptible tint. Candidate build remains **v0.1.0.60** on the same
issue-linked branch and PR #272, pending owner visual acceptance.

Only the shared tokens change: title `#c3bde2` → `#c5a6ff`, section `#aaa6c5` →
`#aa91df`. The stronger violet chroma distinguishes headings from ordinary
neutral text; the title retains greater emphasis than sections. Layout,
interaction styling and disabled/semantic/scientific colors are unchanged.

## Focused revision validation

- [Native Forward+ shortcut groups](native-shortcut-groups.json): **276 checks
  passed**, including compact layouts, focus, scrolling, group order, conflict
  transfer, tooltip absence, restart and unchanged fixture hashes.
- [Theme and scaling review](hierarchy-report.json): **79 checks passed**,
  comparing accepted-main theme colors/constants/font sizes, readability above
  4.5:1 against the dialog surface, distinct brightness levels, and live Shortcut
  and Video group inheritance at 1×/2× scaling. The comparison confirms only
  the three intended hierarchy color assignments differ from accepted main.
- `git diff --check` passed. Visually inspected normal and compact Shortcuts,
  Video Export and simulated 2× scaling.

The same commands and temporary review method as the [initial record](../README.md)
were used with separate revision output/profile directories. The updated
[review script](hierarchy_review.gd) records those directories. Initial evidence
is preserved; its results and pre-existing old Video test failure remain
historical. Full semantics and real File/Tools routes were not repeated because
this revision changes only two color values; focused checks cover their live
inheritance and immediate UI paths.

## Screenshots and limits

[Normal shortcuts](shortcuts-normal.png), [compact shortcuts](shortcuts-compact.png),
[scrolled focus](shortcuts-scrolled.png), [2× shortcuts](shortcuts-scale-2.png),
[Video Export](video-export.png), [2× Video Export](video-scale-2.png).

The Video screenshots use the no-capture state to expose neutral labels and
disabled controls. Physical 4K/mixed-DPI, packaged Linux, other OSes,
accessibility and long-session checks remain unverified. The desktop constrained
the requested 3840×2160 window to 2560×1394 at 2×; this is simulated scaling.
Separate Compatibility comparison remains unnecessary for this theme-only path.

Owner checks: open Keyboard Shortcuts at normal/compact sizes, scan all five
headers, Tab/hover/capture/Escape through rows, and inspect all Video Export
groups with a capture open. Judge immediate hierarchy visibility and neutral
labels on the preferred physical display. See the [current guide](../../../DIALOG_HIERARCHY.md).
