# PR #73 Particle Filters placement

At the owner's request, the Particle layer visible checkbox is removed. The
existing Particle Filters expander and its body now occupy that position inside
Rendering, immediately after Point rendering. Filter callbacks and disclosure
keys are unchanged. The particle visibility model remains available to existing
recipes and exports; only its redundant presentation checkbox is removed.

- Compatibility shell: **515 checks PASS**, including checkbox absence and exact
  filter parent/order, menu routes, exports and startup behavior; source unchanged.
- Headless recipe suite: **2,697 checks PASS**. Particle visibility is still set
  and compared as model state; no test references the removed checkbox. The count
  is lower than the original recipe run because the preceding Advanced refinement
  retired two disclosure buttons while retaining their inert recipe keys.
- Godot import and whitespace checks: PASS. Forward+ was not rerun for this move.

Owner check: open Rendering; Particle Filters should immediately follow Point
rendering, with no Particle layer visible checkbox. Expand it and toggle a type
filter. No wider #68 redesign is included. Pending owner review.
