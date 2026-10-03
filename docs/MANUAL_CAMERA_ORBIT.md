# Manual camera orbit (#190)

Hold the right mouse button and drag inside the viewport to move the camera
sideways around the current framed scene target **relative to the view on
screen**. On each right-button press, the camera's current screen-up direction
is captured in world space and held as that drag's orbit axis. Horizontal
pointer motion carries the camera around that axis continuously through a full
circle. Vertical motion is ignored. Release to end the gesture; the next press
captures a new axis from the then-current view. The Navigate control also shows
this gesture in its tooltip.

This uses the existing camera target, radius and full camera orientation. It works with
particles, volumes, meshes and mixed scenes without selecting a layer or object.
The target, radius, screen-up direction, zoom level, scientific geometry and
playback state stay the same during pure orbit. World-space elevation may change
when the captured view-up axis is tilted relative to world Y. Left-drag retains
its existing two-axis, fixed-sensitivity tumble and can establish a different
orientation before the next right drag.
The wheel zooms along the current view direction; F frames the scene again.

The right-drag angular step uses pointer travel relative to the shorter viewport
dimension. Its distance response is smooth: close views move more finely, while
distant views cover more angle per drag. It has no separate camera mode or saved
preference. With Auto Orbit enabled, a held right drag pauses automatic yaw;
automatic motion resumes on release. Losing window focus ends the drag.

## Owner verification

1. Open the cavity-collapse torus and press F. Use left-drag to tumble to an
   obviously arbitrary orientation that does not align with world Y. Release
   left, then right-drag left and right around the torus, including its opposite
   side and a full return to the starting view. Confirm the mesh stays fixed,
   camera radius does not drift and the screen-up direction does not roll.
2. Right-drag vertically, then diagonally. Vertical-only motion should leave the
   view unchanged; diagonal motion should use only horizontal travel. Release
   right, tumble to a completely different orientation with left-drag, then
   right-drag again. The new orbit plane should match the newly visible view.
3. Zoom near a surface and into the throat; repeat the same pointer travel.
   Check fine control there, then zoom far out and check useful angular travel.
4. Zoom before and after right-dragging, press F, then repeat with Auto Orbit on.
   Automatic motion should pause only while the right button is held.
5. Repeat with particle-only, volume-only and mixed scenes, including changes to
   the selected Simulation-panel category. Check playback, fullscreen and the
   existing left-drag, wheel and selection-tool controls in Forward+ and
   Compatibility. Assess physical KDE/Wayland mouse feel on the owner display.

Implementation and validation evidence: [issue #190 revision 2 report](evidence/issue-190/revision-2/README.md).
