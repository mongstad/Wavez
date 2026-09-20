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

The [production shell](../docs/UX3_SHELL.md) adds Open, State, Export, View and
Help above one right-hand dock. Scene retains the inspector; the other workspaces
provide entry points to its existing control groups.

F1 hides/restores the resizable dock and legend; Space pauses; Left/Right
steps; mouse drag tumbles continuously through full revolutions in either direction;
wheel zooms; F11 toggles fullscreen. F frames the scene and R resets the camera.
Horizontal drag retains world-Y yaw; vertical drag carries the camera up axis
through the poles, allowing upside-down views without a snap. Auto orbit (O)
remains a separate world-Y rotation and pauses while dragging. Open… opens
files. Show panels and Exit fullscreen provide mouse recovery. Scalar colormaps use the bundled lookup data described in
[COLORMAPS_LICENSE.txt](COLORMAPS_LICENSE.txt).

In **Scene layers → Source probe**, **Show probe marker** hides/restores the
last valid volume-probe cross without clearing coordinates or the result. It
stays hidden through playback/seeks and recipe loads. Screenshots reflect the
switch; recipes and deterministic video exclude this session-only marker.

Core rendering runs in Godot. G4 numerical analysis requires Python and NumPy;
optional isosurface extraction additionally requires scikit-image. Forward+
supports cinematic bloom; Compatibility also runs.

Interactive SIMSCP3 playback selects safe particle full preload automatically and
prepares temporal fields and meshes on bounded CPU workers, with GPU/main-thread
staging where required. See the
[performance maintenance report](../docs/PERFORMANCE_MAINTENANCE_REPORT.md) and
[mesh maintenance report](../docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md).
