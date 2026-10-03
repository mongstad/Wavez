# Manual camera orbit (#190)

Hold the right mouse button and drag inside the viewport to move the camera
around the current framed scene target on a horizontal orbit about world Y.
Horizontal motion changes yaw continuously through a full circle; vertical
motion is ignored. The camera keeps its current elevation and looks at the
target throughout. Release the button to stop. The Navigate control also shows
this gesture in its tooltip.

This uses the existing camera target, radius, yaw and pitch. It works with
particles, volumes, meshes and mixed scenes without selecting a layer or object.
The target, radius, viewing elevation, zoom level, scientific geometry and
playback state stay the same during pure orbit. Left-drag retains its existing
two-axis, fixed-sensitivity tumble.
The wheel zooms along the current view direction; F frames the scene again.

The right-drag angular step uses pointer travel relative to the shorter viewport
dimension. Its distance response is smooth: close views move more finely, while
distant views cover more angle per drag. It has no separate camera mode or saved
preference. With Auto Orbit enabled, a held right drag pauses automatic yaw;
automatic motion resumes on release. Losing window focus ends the drag.

## Owner verification

1. Open the cavity-collapse torus and press F. With Auto Orbit off, right-drag
   left and right to travel around the torus, including its opposite side and a
   full return to the starting view. Look through its throat from several sides.
   Confirm the mesh stays fixed, the camera's distance and elevation do not drift,
   and the view does not progressively tilt or turn upside down.
2. Right-drag vertically, then diagonally. Vertical-only motion should leave the
   view unchanged; diagonal motion should produce only horizontal orbit. Confirm
   left-drag still tumbles freely in both axes.
3. Zoom near a surface and into the throat; repeat the same pointer travel.
   Check fine control there, then zoom far out and check useful angular travel.
4. Zoom before and after right-dragging, press F, then repeat with Auto Orbit on.
   Automatic motion should pause only while the right button is held.
5. Repeat with particle-only, volume-only and mixed scenes, including changes to
   the selected Simulation-panel category. Check playback, fullscreen and the
   existing left-drag, wheel and selection-tool controls in Forward+ and
   Compatibility. Assess physical KDE/Wayland mouse feel on the owner display.

Implementation and validation evidence: [issue #190 revision report](evidence/issue-190/revision-1/README.md).
