# SimScope viewer

Godot scientific viewer for SIMSCP3 particles, meshes and scalar fields. Open
native `.ssc` scenes; older capture generations are unsupported.

Open `project.godot` in Godot 4.7 (validated with 4.7.2) and run, or pass:

```sh
godot --path viewer -- --capture=/absolute/file.ssc
```

See the [Quickstart](../QUICKSTART.md), [Python API](../SIMSCOPE_API.md),
[scene format](../G3_FORMAT.md), [G4 guide](../docs/G4_GUIDE.md), and
[capture format policy](../docs/CAPTURE_FORMAT_POLICY.md).

F1 hides/restores the resizable inspector and legend; Space pauses; Left/Right
steps; mouse drag orbits; wheel zooms; F11 toggles fullscreen. Capture / Export
opens files. Scalar colormaps use the bundled lookup data described in
[COLORMAPS_LICENSE.txt](COLORMAPS_LICENSE.txt).

Core rendering runs in Godot. G4 numerical analysis requires Python and NumPy;
optional isosurface extraction additionally requires scikit-image. Forward+
supports cinematic bloom; Compatibility also runs.

Interactive SIMSCP3 playback selects safe particle full preload automatically and
prepares temporal fields and meshes on bounded CPU workers, with GPU/main-thread
staging where required. See the
[performance maintenance report](../docs/PERFORMANCE_MAINTENANCE_REPORT.md) and
[mesh maintenance report](../docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md).
