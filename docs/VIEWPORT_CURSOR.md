# Viewport cursor visibility (#261 and #263)

When the pointer is inside the scientific viewport, 2.5 seconds without a
mouse interaction hides it. Movement, button press or release, dragging, wheel
input and double-clicks restore it immediately and restart the full interval.
The pointer remains in place: Wavez uses hidden cursor mode, without warping,
recentering or capturing the mouse.

The idle rule applies only to the scientific viewport. Application bars,
Simulation dock, transport/status controls, menus, Jobs, Tools, preferences,
native file dialogs and the orbit-center editor keep the cursor visible.
Leaving the viewport, opening a dialog, leaving fullscreen or losing window
focus restores it. A held mouse button or active drag prevents idle hiding.
The same rule applies in windowed and fullscreen modes; moving toward a hidden
fullscreen edge restores the cursor before edge controls become interactive.

RMB free-look steering from #263 has its own immediate rule. Pressing RMB in
the scientific viewport hides the cursor at once and keeps it hidden while
steering, even if the idle rule would otherwise show it. Releasing RMB restores
the cursor and starts a fresh idle interval. LMB, wheel, orbit shortcuts and
Free Camera translation do not cause an immediate hide. Cursor visibility is
session-only and does not change camera, scientific, playback or saved state.

## Owner verification

1. Rest a visible pointer inside the scientific viewport. Confirm it remains
   visible before 2.5 seconds and hides afterward. Move the mouse; it should
   reappear immediately at the same position. Repeat with a move, click, wheel
   and double-click before the deadline to confirm each restarts the interval.
2. Hold and drag LMB. The cursor should not hide mid-interaction. Hold RMB:
   immediate hiding and normal steering should continue. Release RMB and check
   immediate return, then the full 2.5-second idle interval.
3. Move from the viewport to the top bar, Simulation dock, transport/status,
   Jobs, Tools, Keyboard Shortcuts, orbit-center editor and a native file
   dialog. Confirm the cursor stays visible over each surface. Alt-tab while
   hidden and confirm the cursor returns.
4. Repeat in fullscreen. Move toward a hidden edge and confirm the cursor
   returns before the edge controls appear. Exit fullscreen and try the
   viewport double-click toggle after idle hiding.
5. Spot-check particle, field, mesh and mixed scenes in Forward+ and
   Compatibility for unchanged camera interaction and scientific content.

Focused evidence: [issue #261](evidence/issue-261/README.md). The accepted
immediate RMB behavior is documented in [camera steering](MANUAL_CAMERA_ORBIT.md).
