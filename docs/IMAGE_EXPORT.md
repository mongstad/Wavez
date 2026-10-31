# Save Image

File → Export → Image and the Save Image shortcut save the current scientific
viewport presentation. The PNG uses the live camera and renderer, current layer
visibility and styling, and eligible scientific legends. In a normal window,
its boundaries are the visible scene area between the top bar, bottom
transport/status strips and the Simulation dock when those controls are shown.
The camera projection is not reframed for the crop.

In fullscreen/immersive mode, the PNG always uses the entire fullscreen
scientific viewport: 2560×1440 on a 2560×1440 viewport, for example. Transient or
pinned edge-reveal chrome contributes no crop footprint. The shortcut, File →
Export → Image and other Save Image controls produce the same composition.
Scientific legends use their unobstructed fullscreen positions in the image;
their interactive positions are restored immediately after capture.

Application chrome, including Tools, dialogs, notifications and the Edit Orbit
Center gizmo, is excluded. Capture leaves the camera, playback, source data,
scientific transforms and open editor state in place. If the inspection sidecar
option is enabled, its image dimensions and hash refer to the cropped PNG;
selection-aware saves use the same crop and verified bundle workflow.
Fullscreen edge-reveal, popup/focus state and double-click navigation remain
active after saving. Capture explicitly requests its draw even when the paused
viewer is rendering only on change; it does not wait for another input,
compositor event or fullscreen exit. Both ordinary and selection-aware captures
release the capture lock on completion or a reported failure.

The transient **Spectral band map** plane and its pinned legend are also excluded
from ordinary and selection-aware images. The source field uses its current
visibility, including any explicit change through the map's **Show source field**
control. Save Image does not enable a hidden reference field. Map visibility is
restored after capture; the map is not included in image inspection state or
offline video. See [the map contract](SPATIAL_BAND_MAP.md).

The File Locations preference still writes directly to a configured Image
Exports folder. Without one, Save Image uses the native folder picker and reuses
that folder for the current session. An unavailable configured folder reports an
error instead of choosing another destination.

## Owner checks

1. Open a particle, field, mesh or mixed capture. Change the camera, layer
   visibility, wireframe, channels or color controls; toggle an eligible legend.
   Save Image and compare the PNG with the scene area currently visible in the
   viewer. Check that the top bar, dock, transport, status and Tools are absent.
2. Hide and show the Simulation dock, then save again. Check that the PNG width
   follows the visible scene area without recentering objects.
3. Open Tools or Edit Orbit Center and save. Check that neither window nor the
   orbit gizmo appears in the PNG, and that the editor, camera and playback remain
   as they were after the save.
4. Save through the shortcut with a configured Image Exports folder, then clear
   it and check the native picker and session folder reuse. Try an unavailable
   configured folder and check the error.
5. With the inspection sidecar option enabled, check that a selected-particle
   save publishes its PNG and inspection bundle with the cropped image size.
6. On the physical desktop, pause playback, disable Auto Orbit, enter fullscreen
   and leave the application idle. Save via shortcut, then give it no additional
   mouse, keyboard or window activity. The PNG must appear while still
   fullscreen, without pressing Escape. Confirm full fullscreen resolution,
   then immediately double-click the viewport to exit.
7. Return to fullscreen with the same view. Reveal the top edge, use File →
   Export → Image and save. Compare dimensions and composition with the shortcut
   PNG: the 48 px top bar must not be subtracted or appear in the image. Try the
   other revealed edges too. Check that pins, popup/focus state and layout are
   restored; close the export dialog and double-click to exit fullscreen.

The live idle-render regression covers the diagnosed pacing path, but synthetic
command/input tests do not replace these physical owner checks on KDE/Wayland.
