# UI-004 — independent source-probe marker visibility

Issue #4 implementation; pending owner review. Confirmed as the only Ready issue
on 2026-09-19. This report records implementation-time evidence.

## Ownership and behavior

The white cross is the three-axis line mesh created by the **Probe selected
volume** action in `viewer/layers/scene_layers.gd`. Its node is now explicitly
named `SourceProbeMarker`, a `MeshInstance3D` child of the scene-layer controller.
It is independent of the inspector's F1 visibility and particle-selection overlays.

**Show probe marker** controls only this mesh's visibility. The initial preference
is on, but no marker exists until an explicit probe. Hiding/restoring retains
coordinates, the numeric label and the last marker geometry. A new valid probe
while hidden changes the result/geometry without showing it; an unavailable
probe cannot resurrect an old cross when visibility is enabled.

Existing last-explicit-probe semantics remain: playback and seeking do not
recompute the numeric label or move the cross. Recipe restoration rebuilds the
controls while preserving session probe state, including the switch. Opening a
capture resets that session. No scientific sampling or recipe schema changed.

Screenshots capture the current marker visibility. Recipes and PNG sidecars do
not serialize the session probe or its visibility, so loading a sidecar does not
reconstruct its cross. Deterministic video uses a fresh viewer and excludes this
session-only marker, as before, regardless of the interactive switch. The UI
tooltip and current user documentation state these distinctions.

## Validation

```sh
python tools/validate_probe_marker.py --godot /path/to/godot --output-dir results/probe-forward --renderer forward_plus
python tools/validate_probe_marker.py --godot /path/to/godot --output-dir results/probe-compatibility --renderer gl_compatibility
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir results/probe-recipes
```

Use the project Python environment and a fresh output directory for each run.
Godot 4.7.2 / NVIDIA RTX 3070 Ti:

- **33 native checks PASS on Forward+ and 33 on Compatibility**, with clean
  import/runtime logs. A two-sample float64 affine volume provides an independent
  numeric oracle (12 at the origin initially, 22 in the second sample).
- Actual checkbox toggles preserve the result, mesh, decoded source values and
  committed sample. Covered: no prior probe, repeated toggles, recipe restoration
  with either preference, seeking, playback, probing while hidden, out-of-domain
  probe recovery and reopening a capture.
- PNGs with sidecars: central viewport pixels change when the cross is shown;
  hiding it matches the pre-probe reference exactly. Visually inspected retained
  Forward+ [shown](evidence/issue-4/shown.png) and
  [hidden](evidence/issue-4/hidden.png) images.
- **Four actual MP4 exports PASS** (shown/hidden session on each renderer), each
  640×480, four frames, 4 fps, one second. Within each renderer all corresponding
  retained PNGs are byte-identical and timing manifests equal. First-frame central
  pixels match the pre-probe reference. ffprobe confirms encoded dimensions,
  frame count, frame rate and duration. Serialized render states are identical.
- SHA-256 of each capture is unchanged before/after the whole suite. Reports:
  [Forward+](evidence/issue-4/forward.json),
  [Compatibility](evidence/issue-4/compatibility.json).
- Existing v2/v3 recipe ownership regression: **2,987 checks PASS** headless.
- `git diff --check` passed; generated Godot UID is included.

The first test run failed two literal label-format assertions; the numeric
formatting expectations were corrected, retaining exact numeric oracle checks.
The production implementation did not change to accommodate those assertions.

## Limits and manual owner verification

No external simulation, full G0–G4 suite, full 4K/video matrix, or long-session
interactive review was run. The pixel comparisons cover the central viewport,
not the inspector text. Native playback coverage here is a controlled synchronous
tick; worker-buffered playback should also be checked interactively. Selection
and comparison-specific video paths were not rerun; they do not serialize this
session probe. Owner acceptance remains outstanding.

1. Open a volume `.ssc`; under Scene layers choose a volume and in-domain world
   coordinates, then click **Probe selected volume**. Confirm a value and white
   cross appear.
2. Turn **Show probe marker** off/on repeatedly. Confirm only the cross disappears
   and returns; coordinates and numeric result remain intact. F1 should continue
   to affect the inspector separately.
3. Hide the marker, play and seek, then save/load a recipe. Confirm the switch
   stays off and the last probe is retained. Run a new probe while hidden;
   confirm its result updates, then show its marker.
4. Probe out of bounds. Confirm Unavailable and no cross even after toggling on.
   Return to valid coordinates and probe again.
5. Save screenshots with the switch on and off; confirm the cross appears only
   in the former. Export a short video with it on: the session cross should be
   absent. Reopen the capture and confirm no cross until the first valid probe.
