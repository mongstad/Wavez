# Violet filled pins — issue #288

Candidate **v0.1.0.71**, pending owner review. #288 was the first and only Ready
item. Its exact owner-linked branch
`288-ux-pins-keep-pin-icons-violet-in-both-pinned-and-unpinned-states`
was checked out, clean and based on accepted main `c570612` (owner-merged
PR #290). Required #284 tooltip behavior is present through merged PR #287.
GitHub linked-branch metadata, fetch/prune and branch/main ancestry matched.
The completed #283 branch was already absent. No branch was created/switched,
and no Project transition was performed.

## Change and owner direction

One `PinAction` theme assignment now gives resting unpinned icons the same
`accent.primary` (`#7270d8`) as pinned icons. Shared palette tokens, other icon
styles, hover/focus and disabled colors remain unchanged.

During implementation the owner additionally requested: “If possible, also fill
the pins with the same color in the unpinned state”. The unpinned SVG now has a
fill. XML comparison confirms that only its group fill attribute changed:
paths, stroke attributes, dimensions and 40-degree rotation are identical.
The theme normalizes the asset's ink to white before applying the pin tint, so
its fill and outline receive the same state color. Both glyphs are now filled;
upright versus tilted orientation still distinguishes pinned and unpinned.
This owner-directed fill updates the issue's original artwork-preservation scope.

No pin behavior, tooltip, timing, focus traversal, visibility or persistence
code changed. The build increments once from accepted main 70 to 71. Current
WINDOW_EDGE_REVEAL.md and CURRENT_STATUS.md document the final behavior; earlier
reports and review-time wording remain unchanged, including historical outlined
unpinned descriptions.

## Focused validation

[Summary](summary.json), [Forward+](forward.json),
[Compatibility](compatibility.json), and clean native logs
([Forward+](forward-native.txt), [Compatibility](compatibility-native.txt)).
[Accepted-main baseline](baseline.json) and its [clean log](baseline-native.txt)
record the old neutral resting-unpinned theme ink before editing.

| Gate | Result |
|---|---|
| Final Forward+ native pin matrix | 372 checks, zero failures |
| Final Compatibility native pin matrix | 372 checks, zero failures |
| Accepted-main focused baseline | 360 checks, zero failures |
| Unpinned SVG geometry/stroke/rotation comparison | Only fill changed |
| Application version | 2 tests PASS |
| Warm Godot import / whitespace | PASS |

This local presentation change uses a temporary review script that reuses the
existing test_transport_tooltips.gd mouse/hover/key helpers. The retained
[review script](pin-review.gd.txt) can be copied to a temporary `.gd` file and run
with `--path viewer --script /absolute/review.gd --rendering-method forward_plus
-- /absolute/existing/output-directory` (or `gl_compatibility`). No permanent
regression suite or scientific fixture was added.

The matrix covers all three pins at 1440×900 and 1024×640, then repeats them
inside actual native Fullscreen and after restoration. It checks normal/pressed
violet, accepted hover/focus and muted disabled ink, unchanged generic icon and
title/section palette colors, distinct pin/unpin textures, mouse unpin, grace,
dwell/reveal, Enter repin, Tab traversal, style identity, tooltip absence and
exact restored pin/timer state. Edge timers use deterministic ticks; mouse/key
input goes through the actual Godot UI. An unrelated Loop control still shows
its intentional tooltip. Screenshot capture explicitly checks DRAW_NORMAL after
leaving hover, so resting unpinned evidence is not a hover-state image.

## Screenshots and owner checks

- [Normal, all pinned](normal-pinned.png)
- Resting unpinned: [top](window-1440-top-unpinned.png),
  [right](window-1440-right-unpinned.png),
  [bottom](window-1440-bottom-unpinned.png)
- Compact unpinned: [Forward+](window-1024-right-unpinned.png),
  [Compatibility](compatibility-compact.png)
- [Fullscreen unpinned bottom](fullscreen-from-1440-bottom-unpinned.png)

Linux release packaging, physical pointer dwell feel and mixed-DPI/4K display
checks were not run. Validation stays on the affected theme/SVG and direct pin
interaction paths; unrelated export, playback and scientific suites were not
needed. Import first recreated five known untracked cache UIDs; a warm unchanged
import was clean and those incidental sidecars were removed.

Before acceptance, inspect all three pins in both states at your normal and
compact sizes. Confirm the unpinned glyph is filled violet and still tilted;
check hover/focus feedback, unpin → auto-hide → edge reveal → repin, then repeat
in Fullscreen and after restoration. Spot-check an unrelated icon and a dialog
heading. These results are implementation evidence, not owner acceptance.

Stop for owner review; no merge, auto-merge or manual issue closure is arranged.
