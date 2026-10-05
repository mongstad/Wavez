# PR #260 fullscreen review follow-up

The owner observed a 2192 × 1288 Save Image PNG on a 2560 × 1440 fullscreen
viewport and a failed fullscreen double-click immediately after saving. The
capture now uses edge-reveal state and actual on-screen visibility for crop
bounds. It leaves the shell itself mounted and visible during the clean redraw;
only chrome that can overlap the scientific image is briefly hidden. Embedded
windows under hidden ancestors are not toggled.

The revised [Forward+](forward-review-followup.json) and
[Compatibility](compatibility-review-followup.json) native runs each passed 64
focused checks. Both captured a 2560 × 1440 PNG with all fullscreen chrome
hidden; the [Forward+ PNG](fullscreen-save.png) is retained here. Each run sent
the physical Save Image shortcut, compared immersive, edge-reveal, popup,
visibility and focus state before and after, then sent a viewport double-click
and exited fullscreen. A controlled stale-local-visibility case verified that
hidden fullscreen bar/dock/strip rectangles do not reduce the output size.
The normal 1440 × 900 window still crops to 1072 × 748 with its dock and strips
visible. Particle, field, mesh, mixed and sidecar checks remained in the run,
and fixture source hashes stayed unchanged.

The owner's failed double-click did not reproduce in a simple scripted
fullscreen session before the change. The follow-up removes the whole-shell
hide/show operation that could disturb input state and now exercises the
post-save double-click sequence. Owner retesting in the original desktop
interaction remains the decisive check. No packaged-app or unrelated full-suite
run was performed.
