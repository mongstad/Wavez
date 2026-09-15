# Native scene inspection

Inspection operates on SIMSCP3 particles, meshes and scalar fields with independent
source clocks. Scene recipes use version 2; G4 durable inspection uses version 3
with exact selections, groups, analysis results, bookmarks and source provenance.
These state versions are independent of the capture format. See
[G4 schemas](docs/G4_SCHEMAS.md), [the G4 guide](docs/G4_GUIDE.md) and
[the handbook](docs/SIMSCOPE_HANDBOOK.md).

## Try a native scene

```sh
python -m examples.scene_demo --small --output results/inspection-scene.ssc
# Use a fresh output filename on later runs.
godot --path viewer -- --capture=/absolute/path/to/results/inspection-scene.ssc
```

Pause, seek a physical time, select a particle mapping or field slice, and inspect
the layer source times. Explicit particle IDs and stable mesh topology permit
matched position interpolation. Anonymous particles and scalar/field values hold
their source samples. The timeline slider addresses the union of recorded sample
times. Unknown geometry remains unknown; display guides do not define a domain.

Use Copy Inspection State or Save inspection recipe for the current sample and
visual state. Enable PNG inspection JSON sidecars to bind a screenshot to its
source hash, committed extent, layer sampling, geometry and mappings. The first
Save PNG action chooses a destination; cancelling writes nothing. That destination
lasts for the current session only.

G4 selection-aware inspection uses the durable workflow described in the G4 guide.
Restore validates source identity, exact sampling, selected assets and state before
applying the recipe. An appended capture does not expand a saved committed prefix.
Missing, changed or corrupt source data must be refused rather than relabeled.

## Regression checks

```sh
python -m unittest discover -s tests -v
python tools/validate_maintenance_ui.py --godot /path/to/godot --output-dir results/check-inspection
python tools/validate_video.py --godot /path/to/godot --output-dir results/check-video --renderer gl_compatibility
```

Use fresh directories. Actual screenshots/video require a graphics session and
FFmpeg for MP4 encoding. Current inspection and export validation is recorded in
the maintained regression tools and reports; retired formats are not current guidance.
