# Issue #271: resting pinned-icon color trial

The owner requested trying the pinned panel icon color when the control is not
focused. Both hierarchy tokens now use `#7270d8`. Production theme resolution
aliases `text.title`/`text.section` to `accent.primary`, the same source used by
`PinAction.icon_pressed_color`. The brighter hover/focus color is not used.
Titles and sections share ink; existing font size/weight supplies title emphasis.
Ordinary labels and controls retain their neutral and state-specific colors.
Build remains **v0.1.0.60**, pending owner visual review on PR #272.

## Validation

- [Native Forward+ shortcut groups](native-shortcut-groups.json): **276 checks
  passed** at normal/compact sizes, including group order, focus/scrolling,
  conflicts, tooltips, restart and unchanged fixture hashes.
- [Theme/scaling review](hierarchy-report.json): **79 checks passed**. Both
  headings exactly match the resting pinned icon's resolved color. Comparing
  against accepted main still finds only three changed theme color assignments;
  constants/font sizes match, with live Shortcut/Video group inheritance and
  contained footer at 1×/2× scaling.
- Contrast is recorded rather than asserted at the earlier 4.5:1 threshold:
  this exact requested color yields **4.08:1** against dialog `surface.3`, lower
  than the previous brighter lavender. It differs in hue from disabled text
  and neutral ordinary text. Owner review should judge this darker trial's
  readability on the preferred display.
- The temporary script initially retained the previous brightness ordering
  assumption; the resting pin color is darker than disabled ink. That assertion
  was corrected to verify separate colors and the requested exact pin match.
  The clean final report contains no failures. `git diff --check` passed.

[Normal shortcuts](shortcuts-normal.png), [compact shortcuts](shortcuts-compact.png),
[scrolled focus](shortcuts-scrolled.png), [2× shortcuts](shortcuts-scale-2.png),
[Video Export](video-export.png), [2× Video Export](video-scale-2.png).

The [review script](hierarchy_review.gd) follows the initial reproduction method
with separate revision paths. Initial and revision-2 evidence remain unchanged.
The no-capture Video view exposes neutral and disabled fields. Only focused UI
checks were repeated for this color trial; earlier full semantics/real dialog
results remain historical. Physical 4K/mixed-DPI, packaging, other OSes,
accessibility and long-session checks remain unverified. Requested 3840×2160
was desktop-constrained to 2560×1394 at 2×. Separate Compatibility comparison
was not needed for the shared Control/theme text path.

Owner check: compare headings against a pinned panel icon with the pointer away
and no focus. Inspect Shortcut groups and Video Export at normal/compact and
preferred scaling, confirming neutral rows and distinct focus/disabled states.
See [current owner steps](../../../DIALOG_HIERARCHY.md).
