# Save Image

File → Export → Image and the Save Image shortcut save the current scientific
viewport presentation. The PNG uses the live camera and renderer, current layer
visibility and styling, and eligible scientific legends. Its boundaries are the
visible scene area between the top bar, bottom transport/status strips and the
Simulation dock when those controls are shown. The camera projection is not
reframed for the crop.

Application chrome, including Tools, dialogs, notifications and the Edit Orbit
Center gizmo, is excluded. Capture leaves the camera, playback, source data,
scientific transforms and open editor state in place. If the inspection sidecar
option is enabled, its image dimensions and hash refer to the cropped PNG;
selection-aware saves use the same crop and verified bundle workflow.

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
