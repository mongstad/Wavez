# Screen-fixed cinematic background

Issue #205 proposes **v0.1.0.55** for owner review. The Cinematic background
stays in the same orientation within the scientific viewport while the camera
changes view. LMB tumble, RMB steering, held view-relative orbit, Free Camera
translation, Auto Orbit, zoom, Frame Scene and Reset Camera continue moving the
scientific view normally. The background also follows the viewport's size and
aspect through normal, maximized and fullscreen windows.

The visible sky shader now derives its presentation ray from `SCREEN_UV`, the
viewport aspect ratio, the existing 55-degree camera projection and the
accepted default camera orientation. Its belt, cloud, dust and color formula
are unchanged. The sky's cubemap pass still uses its world-space direction;
scientific lighting, particle/field/mesh rendering, camera state and source
coordinates are untouched. The same viewer and shader are used by the offline
video worker, so Cinematic exports retain the screen-fixed presentation as
their camera moves. Scientific mode retains its plain background.

The accepted shader has no `TIME` input or other independent animation clock.
Its cloud/dust pattern and intensity remain as before; the apparent motion
during navigation came from sampling a camera-dependent direction. This change
does not add or alter a timed effect.

[Focused evidence](evidence/issue-205/README.md) records native and Linux
package checks on Forward+ and Compatibility, four small WVZ1 scene types,
window sizes through 4K, and actual Cinematic video frames. Historical reports
remain as recorded at their original review checkpoints.

## Owner verification

1. Open a representative scene in Cinematic mode. Record a normal view, then
   tumble past upside-down and orbit from different planes. Check that the
   scene moves while the background gradient keeps its original orientation.
2. Steer with RMB, translate with Free Camera, enable Auto Orbit for substantial
   motion, zoom, then use Frame Scene and Reset Camera. Check the background
   remains fixed and the camera controls keep their accepted feel.
3. Repeat in a normal window, maximized window and fullscreen. Check a 16:9
   view and, if available, a physical 4K or mixed-DPI display.
4. Switch between Cinematic and Scientific. Export a short Cinematic clip with
   camera orbit on Forward+ and Compatibility; inspect the sky through the
   clip and confirm scientific content moves without application chrome.
5. Try particle, field, mesh and mixed captures, including a representative
   production capture. Check colors, contrast and any expected ambient motion
   against the accepted appearance.
