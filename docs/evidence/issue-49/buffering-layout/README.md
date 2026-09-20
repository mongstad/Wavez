# Requested-time layout stability

Pending owner review in PR #51. The Requested time label used to participate in
the axis VBox minimum size. Its changing visibility shifted the centered controls.
It is now a clipped, anchored child below the slider, outside container sizing.
Its exact tooltip remains available. Compact rows use a fixed 16 px gap to fit the
readout; the desktop/compact panel heights stay 64/104 px. Playback, buffering and
committed/requested clock semantics are unchanged.

Final native Fedora KDE/Wayland, Godot 4.7.2 checks:

- Forward+: **152 passed**, source hashes unchanged ([report](forward.json)).
- Compatibility: **152 passed**, source hashes unchanged ([report](compatibility.json)).
- Both window sizes verify unchanged toolbar, actions, slider and options geometry
  while the readout appears, grows and clears, plus no overlap with the next row.
- Existing real cold-worker barrier and latest-seek tests still pass. Long-readout
  layout stress injects published pending state only; it is not a scientific seek.
- Screenshots inspected; whitespace checks passed. No test failures remain.

[Desktop pending](pending-layout-1440.png) · [Compact pending](pending-layout-1024.png)

Runs use `tools/validate_viewer_transport.py` with the external Godot binary,
renderers `forward_plus` and `gl_compatibility`, and output directories
`results/issue-49-stable-reviewed-forward` / `results/issue-49-stable-reviewed-compatibility`.
Earlier evidence is preserved. An initial geometry test was strengthened after
inspection showed periodic refresh could clear its directly assigned test label;
final tests keep pending state active and assert readout visibility explicitly.

Broader state/video suites were not repeated for this UI geometry fix. Physical
HiDPI and the owner's large capture remain manual checks. Play through uncached
frames and cold-seek: Requested time should remain readable without any control
movement. Check its exact tooltip, then repeat in the compact layout.
