# Free-look steering, manual orbit and camera roll (#258, #331)

Free Camera starts enabled. W/S translate forward/backward, A/D strafe and Q/E
move vertically in the camera's current basis. Geometry has no collision barrier.

Hold **RMB** in the viewport and move the mouse to steer in place. Horizontal
motion turns the heading left/right; vertical motion looks up/down. Both axes
follow the current view, including tilted or upside-down views. The camera
position and radius stay fixed. Releasing RMB, losing window focus, opening
Keyboard Shortcuts or starting an inspection capture ends the gesture.
RMB uses a fixed `0.003` radians per pixel, independent of translation speed.
While RMB steering is active in the scientific viewport, the cursor hides
immediately. It returns at the same pointer position on release. Focus loss,
opening menus or dialogs, inspection capture, leaving fullscreen and any manual
navigation cleanup also restore it. This uses hidden cursor mode, so mouse
movement continues to steer without pointer capture, warping or recentering.
LMB, wheel, orbit shortcuts and Free Camera translation do not immediately hide
the cursor. The [general viewport inactivity rule](VIEWPORT_CURSOR.md) can hide
it after 2.5 seconds without mouse interaction. Active RMB steering always
keeps it hidden; release restores the pointer and restarts the idle interval.

**Orbit Camera Left** and **Orbit Camera Right** move the camera around its
current navigation target. Both start **Unbound** in **Edit → Preferences →
Keyboard Shortcuts**, under Navigation. Rebind, conflict transfer, Apply,
Cancel, Clear, Reset Defaults and restart persistence use the existing editor.
Existing default bindings are unchanged.

Hold an orbit key to travel left or right around the camera's screen-up axis,
which is captured at the start of that orbit. This is the view-relative
horizontal orbit previously assigned to RMB. Target, radius and the captured
up axis stay fixed; world-space elevation can change when the view is tilted.
The rate is **90°/second**, independent of frame rate, translation speed, zoom
and Auto Orbit speed. Release stops immediately. Opposite orbit keys cancel;
releasing one resumes the other from the current view. Focus loss, a changed
modifier chord, text-entry focus, Keyboard Shortcuts or a busy inspection
capture ends a held shortcut. Mouse dragging takes priority over held orbit keys.

RMB or an orbit key immediately disables Auto Orbit and applies manual control
on that same input. Auto Orbit remains off after release until explicitly
re-enabled. W/A/S/D/Q/E retains its accepted immediate transition to Free Camera.
LMB keeps its existing two-axis tumble and sensitivity; it still temporarily
suspends Auto Orbit while held. The [Invert Y Axis preference](LMB_Y_INVERSION.md)
reverses only LMB vertical drag when enabled, with an On/Off toggle and hotkey
in Keyboard Shortcuts. RMB steering remains unchanged. Wheel zoom and the `+`/`-`
translation-speed controls keep their accepted behavior.

## Camera roll (#331 candidate)

**Roll Camera Left** and **Roll Camera Right** are separately editable Navigation
actions in Keyboard Shortcuts. Both start Unbound, preserving current shortcuts.
With Free Camera enabled, hold either key to bank at **90°/second** about the
camera's current local view axis. Left banks the camera up axis toward its left;
right mirrors it. Position, forward direction, navigation target and radius stay
fixed. Opposite keys cancel; releasing one resumes the other. The rate uses elapsed
time and is independent of translation speed, zoom and Auto Orbit speed.

Roll takes manual control from Auto Orbit using the existing steering transition
and leaves Auto Orbit off after release. With Auto Orbit already off, roll does
not enable a disabled Free Camera. Release, changed modifiers, window focus loss,
focused controls, menus/dialogs, mouse dragging, inspection work, changed bindings
and capture replacement stop a held roll. Mouse gestures retain their existing
priority. After banking, W/A/S/D/Q/E translation and RMB steering use the rolled
local axes. Simultaneously held manual orbit carries the new bank into its next
step while retaining its captured orbit axis.
Rolling after an orbit-center Apply also retains that Apply-time observer plane,
center and radius; re-enabling Auto Orbit resumes from the banked basis.

Frame Scene and reopening a capture retain the chosen orientation; Reset Camera
intentionally restores the default heading. Portable view presets and image/video
state already store the full transform, including bank. Offline workers ignore
interactive key bindings. Camera roll never rotates scientific objects, world
axes, source arrays or numerical exports. The cinematic backdrop stays fixed in
screen coordinates while scene geometry banks.

## Camera-state synchronization

The existing target/radius/full-basis representation is retained. RMB changes
the full camera basis at the current position, then places the navigation target
one existing radius ahead along the new viewing direction. As with Free Camera
translation, this changes a navigation reference, never scientific coordinates.
It keeps later orbit, wheel, framing and state restoration continuous without a
broader camera rewrite. A manually chosen target can be set again through
**Edit orbit center…**; Apply starts Auto Orbit there and Cancel restores the
complete pre-edit state. Frame Scene retains the heading; Reset Camera restores
the default orientation and current scene framing.

## Owner verification

1. In representative particle, field, mesh and mixed captures, steer with RMB
   horizontally and vertically, including near/inside geometry and tilted views.
   The camera must turn in place without a press/release snap. Release RMB and
   confirm subsequent pointer motion does nothing.
2. Fly with W/S while steering toward a filament, field feature, mesh surface or
   through a toroidal cavity. Check A/D and Q/E remain camera-relative, with no
   collision or center barrier. Try both ends of the `+`/`-` speed range; steering
   sensitivity must stay the same.
3. Bind the orbit actions to convenient unused keys. Hold each, make a full
   revolution about a chosen target, and repeat after an arbitrary LMB tumble.
   Check opposite directions, key release, stable target/radius and screen-up.
   Test conflict transfer, Cancel, Apply, Reset Defaults and restart persistence.
4. Enable Auto Orbit, then steer with RMB or press either orbit key. The first
   input must take manual control; release must leave Auto Orbit off. Check LMB,
   wheel, Frame Scene, Reset Camera and orbit-center Apply/Cancel afterward.
5. Repeat in fullscreen and in both renderers. Assess physical mouse/key feel on
   KDE/Wayland. Scientific objects and playback state must remain unchanged.
6. While steering with RMB, confirm the cursor hides on press and returns on
   release without moving position. Try opening a menu, Keyboard Shortcuts and
   a Tools dialog, then alt-tab and leave fullscreen while RMB is held; the
   cursor must return immediately. LMB, wheel, orbit keys and W/S/A/D/Q/E alone
   must leave it visible. Double-click fullscreen must still work afterward.

Current evidence: [issue #258](evidence/issue-258/README.md).
Cursor-specific evidence: [issue #263](evidence/issue-263/README.md).
The earlier RMB-orbit design and its results remain in the historical
[issue #190 revision 2 report](evidence/issue-190/revision-2/README.md).

## Roll owner verification (#331)

1. In Keyboard Shortcuts, confirm both roll actions initially say Unbound.
   Bind unused keys, Apply, close the editor, and hold each with Free Camera on.
   Check smooth opposite banks, immediate release, 90°/180°/360° orientation,
   stable position/heading and cancellation when both directions are held.
2. After banking 90°, fly with W/A/S/D/Q/E and steer with RMB. Controls should
   follow the banked camera axes. Check LMB tumble, wheel zoom, held orbit,
   Auto Orbit takeover, Frame Scene, Reset Camera and orbit-center Apply/Cancel.
3. Rebind, Clear, transfer a conflicting key, Cancel unapplied edits and restart.
   Test focus in text/numeric fields, the shortcut/orbit editors, menus and
   alt-tab. No pending hold should resume after these interruptions or opening
   another capture. Check Dark/Light and fullscreen.
4. Repeat in representative particle, field, mesh and mixed captures. Save/load
   a banked view preset and review an image/video made with the fixed camera.
   Scientific coordinates, time selection and numerical outputs should stay
   unchanged. Assess physical key feel on the owner's KDE/Wayland setup.

Candidate evidence and practical limits: [issue #331](evidence/issue-331/README.md).
