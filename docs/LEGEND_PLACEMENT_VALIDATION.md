# Legend placement — PR #91 review refinement

Pending owner review. This follow-up on the existing issue #85 branch addresses
the owner's Immersive screenshot: the legend retained the old dock/transport
insets because the Immersive layout returned before updating its position.

The shell now positions the colorbar and legend together against the lower-right
of the available scene area. Normal layout reserves space for the visible dock,
transport and status. Immersive uses the full viewport. Both use a 12-pixel margin;
the label uses its minimum text height rather than its old 90-pixel reserved box.
Window resize and mode changes use the same layout path. Legend preference,
recipe fields and scientific state remain unchanged.

## Validation

Native Godot 4.7.2 on KDE/Wayland, NVIDIA RTX 3070 Ti:

- Forward+: 985 assertions and 16 KWin geometry stages PASS.
- Compatibility: 985 assertions and 16 KWin geometry stages PASS.
- Both processes exited normally and fixture hashes remained unchanged.
- Added right-edge checks after repeated panel toggles at every native stage,
  plus actual Immersive entry from manual and maximized windows, visible-legend
  and 12-pixel right/bottom-margin assertions, screenshot capture and exit.
- Existing legend ON/OFF, recipe apply, scalar eligibility, scientific-state and
  window-restoration checks remain active.
- Immersive Forward+ screenshot visually inspected. Existing libdecor GTK plugin
  fallback and Gio deprecation warnings occurred; no Godot errors.

Run the commands from [the original report](LEGEND_VISIBILITY_VALIDATION.md) with
fresh output directories. The added checks run with the same `--legend-visibility`
flag. New evidence is in `docs/evidence/issue-85/placement/`; the original review
report and evidence remain unchanged. Video export, other platforms, production
captures and a full-suite run were not repeated for this presentation adjustment.

Owner check: enable a scalar particle legend, toggle panels repeatedly, and enter
Immersive with Shift+F11. The legend should move near the viewport's lower-right
corner. Esc should return it above the bottom controls and beside any visible
panel. Repeat from maximized and resized windows; Show legend OFF should still
hide it in all modes.
