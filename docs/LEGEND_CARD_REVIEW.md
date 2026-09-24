# Particle legend card — PR #92 review refinement

Pending owner review. The owner spotted that the particle legend had no container
while field/mesh legends used cards. The particle legend now has the same shared
surface/border style, with 8-pixel horizontal and 6-pixel vertical padding. Its
outer edge retains the 12-pixel viewport/control clearance. The field/mesh stack
clears the top of this panel. The panel follows particle legend visibility and
ignores mouse input; existing legend controls, recipe values and scientific state
are unchanged.

Validation: 35 multi-layer checks passed on each renderer, including card enclosure
and hide/show behavior. Compatibility overlays ON/OFF MP4 smoke exports passed;
source hashes were unchanged. The longer native first-open/panel/fullscreen regression reached 130 passing
assertions, then its screenshot guard stopped because the window lost focus. This
is an incomplete run, not a full 989-check pass. Its margin assertions now target
the outside of the card rather than its padded contents. The completed focused
35-check suites include Immersive entry/exit. The interactive
screenshot was visually inspected. Existing libdecor/Gio warnings remained in the
KWin harness; no new script errors were reported.

New evidence is under `docs/evidence/issue-37/particle-card/`; previous evidence is
preserved. Recipe and full video suites were not repeated for this styling change;
the focused tests still cover state restoration and actual overlay exports.

Owner check: show particle and field legends together, confirm matching borders
and backgrounds, hide/show the particle legend, and enter/exit Immersive. The
particle card should disappear with its legend and retain clearance above playback.

## Typography and horizontal-gap follow-up

The owner requested identical typography and a smaller horizontal gap, keeping
the existing vertical gap. The particle label now uses the same shell theme as
field/mesh labels. Legend bounds use the right panel's edge directly, removing
the extra 8-pixel resize-handle allowance for legends only. The outer particle
card and field/mesh collection now clear the right panel by 12 pixels, matching
the unchanged 12-pixel playback clearance. Other controls are not moved or resized.

The expanded focused suite passed 37 checks on each renderer, including explicit
font-resource/font-size equality and measured 12-pixel horizontal/vertical gaps.
Compatibility multi-layer MP4 exports with overlays ON/OFF also passed; source
hashes remained unchanged. The new Forward+ screenshot was visually inspected.
The longer desktop and recipe suites were not repeated for these two changes.
New evidence is under `docs/evidence/issue-37/typography-spacing/`.
