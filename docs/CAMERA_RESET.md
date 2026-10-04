# Reset Camera on the current scene (#211)

Reset Camera restores the default 38° yaw and 24° pitch, then frames the
currently loaded scene. The target and radius come from the same aggregate
particle, volume and mesh bounds used by Frame Scene. Frame Scene keeps the
current orientation, including a view-relative right-drag orbit; Reset clears
that orbit basis. Both close a pending orbit-center editor. Neither changes
scientific coordinates, playback samples, Free Camera or Auto Orbit state.

On accepted build 45, Reset Camera instead targeted world origin and forced a
minimum 30-unit radius. That path bypassed the aggregate bounds already used
by Frame Scene. Off-origin scenes moved out of view, and small scenes became
tiny. The existing 0.1-unit framing radius floor and fixed 0.05-unit near plane
also made very small scenes tiny or clipped. The current framing calculation
uses a smaller nonzero radius floor and scales the near/far planes for small
scenes; ordinary scene scales keep the established framing ratio and clipping
values. Nonfinite geometry points do not enter the bounds.

## Owner verification

1. Open a mesh capture with geometry away from world origin. Use **Frame Scene**
   and then **Reset Camera**. Both should show the mesh at a useful size; Reset
   should restore its default orientation. Repeat Reset and check that the view
   does not drift.
2. Repeat with particle-only, field-only and mixed captures. Try a small and a
   large scene, then Reset after close/distant wheel zoom, left-drag tumble,
   right-drag orbit and Free Camera movement. Keep Auto Orbit on for one reset;
   its mode should remain on.
3. After a right-drag orbit, use **Frame Scene** and confirm it preserves that
   orientation. Use Reset and confirm the default orientation returns. Check
   ordinary wheel zoom after each action.
4. Repeat in normal and fullscreen windows using Forward+ and Compatibility.
   Compare scientific object positions, source capture and playback state before
   and after camera actions.

The focused `tools/validate_camera_reset.py` fixture check covers these camera
contracts in synthetic particle, field, mesh, mixed, small and large scenes.
It can include an external capture using `--capture`. Its report, logs and
capture-hash comparison are written only to the selected output directory.

Accepted build 45 failed 38 of 84 focused headless checks on the off-origin
and scaled fixtures before the fix. The final candidate passed 109 checks in
each of Forward+ and Compatibility, in both source and Linux package runs,
including windowed/fullscreen reset and an available cavity-collapse torus
capture. All fixture and external capture hashes matched before/after each
run. The existing camera-tumble suite passed 13,798 headless checks, and the
wheel/orbit/window-mode suite passed 281 checks per renderer. The exact capture
from the original owner report was unavailable in this workspace; the owner
should repeat step 1 with it before acceptance.
