# Constant violet pin ink — owner review revision

Candidate **v0.1.0.71**, still pending owner review in PR #292. The owner requested
removing the white unpinned-hover color and keeping the current purple in all
states, including focus/loss, while retaining the button animation/feedback.
This supersedes the initial review's brighter interaction and muted disabled
**pin icon** ink. The [initial evidence](../README.md) remains unchanged as a
record of the prior revision; its old color assertions are not the current test.

`PinAction` now explicitly maps normal, pressed, hover, hover-pressed, focused
and disabled icon colors to the same existing `accent.primary` (`#7270d8`). The
button styleboxes, hover surface, focus ring, interaction code and filled/tilted
artwork are unchanged. Generic icon hover colors and title/section ink remain
unchanged. The build stays 71 for this review update.

## Focused verification

- [Forward+](forward.json): **196 checks, zero failures**;
  [clean native log](forward-native.txt).
- [Compatibility](compatibility.json): **196 checks, zero failures**;
  [clean native log](compatibility-native.txt).
- Two application-version tests, clean warm Godot import and whitespace checks
  pass. Initial import recreated five known incidental cache UIDs, subsequently
  removed. An initial temporary review-script type annotation failed to parse;
  it was corrected before the completed GUI checks above.

The [retained review script](review.gd.txt) reuses actual Godot mouse/key helpers
and exercises every pin in both toggle states, at 1440×900 and 1024×640. It checks
all six theme colors, resting and hovered draw modes, focus acquisition/loss,
disabled draw mode with clicks refusing to toggle, and enabled clicks toggling.
It also checks tooltip absence and unchanged generic-icon/title/section colors.

Screenshots show the unpinned icon during [hover](hover-false.png),
[focus](focus-false.png) and [disabled state](disabled-false.png), plus the
[pinned hover](hover-true.png). Violet icon ink stays constant; button hover
background and focus outline remain available.

The earlier 372-check hide/reveal/Fullscreen matrix is retained as earlier
revision evidence. Those paths and artwork did not change, so this revision
checks the affected interaction-color paths rather than repeating timing and
Fullscreen tests. Linux release packaging, physical pointer feel and
mixed-DPI/4K review remain unrun. No unrelated regression suites were run.

Before acceptance, hover and focus/unfocus all three pins in both states. Confirm
that the icon never turns white or changes violet, while the button's hover and
focus feedback still appears. Retain the earlier hide/reveal/Fullscreen owner
checks. Stop for owner review; no merge or auto-merge is arranged.
