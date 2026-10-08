# Wavez viewer

Godot scientific viewer for WVZ1 particles, meshes and scalar fields. Open
native `.wvz` scenes; older capture generations are unsupported.

Open `project.godot` in Godot 4.7 (validated with 4.7.2) and run, or pass:

```sh
godot --path viewer -- --capture=/absolute/file.wvz
```

See the [Quickstart](../QUICKSTART.md), [Python API](../WAVEZ_API.md),
[scene format](../G3_FORMAT.md), [G4 guide](../docs/G4_GUIDE.md), and
[capture format policy](../docs/CAPTURE_FORMAT_POLICY.md).

The [production shell](../docs/UX3_SHELL.md) adds Open, State, Export, View and
Help above one right-hand dock. Scene retains the inspector; the other workspaces
provide entry points to its existing control groups. The
[persistent transport](../docs/UX3_TRANSPORT.md) keeps playback, union sample index,
elapsed/total/remaining playback time, Seek…, Playback speed and Loop below
the viewport. Playback uses recorded time only. [Media timing](../docs/UX3_MEDIA_TRANSPORT.md) is nominal at 1×; exact
committed source time remains in the elapsed tooltip and Seek Target. Seek uses
a separate Target and explicit Go/Cancel; typing never changes the visible time.
The [40-pixel status line and Jobs action](../docs/UX3_STATUS.md) remain available
with the dock hidden. Details exposes readiness diagnostics; Jobs reopens existing
operations, exposes supported cancellation and retains output/failure details.

F1 hides/restores the resizable dock and legend; Space pauses; Left/Right
steps; left-drag tumbles continuously through full revolutions in either direction;
right-drag steers the camera heading in place on both axes under the accepted
#258 controls. Held Orbit Camera Left/Right keys provide target-relative
horizontal orbit about the current screen-up axis, across all scene types;
wheel zooms; F11 toggles fullscreen, hiding the top command bar until exit;
maximized windows keep the bar. F frames the scene and R resets the camera.
The [Invert Y Axis preference](../docs/LMB_Y_INVERSION.md) in Keyboard Shortcuts
adds a persistent On/Off toggle beside its hotkey field. It reverses only the
vertical LMB component; current RMB steering remains unchanged.

For left-drag, horizontal motion retains world-Y yaw and vertical motion carries
the camera up axis through the poles, allowing upside-down views without a snap.
On a clean launch Free camera is enabled and Auto orbit is disabled; O toggles
Auto orbit, and Free Camera is an unbound editable shortcut action under
Edit → Preferences → Keyboard Shortcuts. Each toggle leaves the other mode
unchanged, and assigning an existing key transfers it to one action.
Auto orbit remains a separate world-Y
rotation and pauses while dragging. Open… opens
files. Show panels and Exit fullscreen provide mouse recovery. Scalar colormaps use the bundled lookup data described in
[COLORMAPS_LICENSE.txt](COLORMAPS_LICENSE.txt).

The volume source-probe cross uses an orchid stroke with a dark navy outline,
independent of scientific colormaps. **View → Probe marker** hides/restores the
last valid cross without clearing coordinates or the result. It
stays hidden through playback/seeks and recipe loads. Screenshots reflect the
switch; recipes and deterministic video exclude this session-only marker.
See [marker styling and owner checks](../docs/PROBE_MARKER_VISIBILITY.md).

Core rendering runs in Godot. G4 numerical analysis requires Python and NumPy;
optional isosurface extraction additionally requires scikit-image. Forward+
supports cinematic bloom; Compatibility also runs.

Interactive WVZ1 playback selects safe particle full preload automatically and
prepares temporal fields and meshes on bounded CPU workers, with GPU/main-thread
staging where required. See the
[performance maintenance report](../docs/PERFORMANCE_MAINTENANCE_REPORT.md) and
[mesh maintenance report](../docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md).
