# Getting started with the standalone viewer

## Install and launch

1. Extract the entire ZIP into a writable folder. Keep `WAVEZ.x86_64` and
   `WAVEZ.pck` together with the included documents and `licenses/` folder.
2. Use a graphical Linux x86_64 desktop and a Vulkan-capable GPU with working
   drivers. **Forward+ Vulkan is the sole supported renderer.**
3. Run `./WAVEZ.x86_64` from that folder. If execution is denied, restore the
   executable permission with `chmod +x WAVEZ.x86_64`. If startup still fails,
   check GPU/driver Vulkan support and keep the PCK beside the executable.

The package includes the Godot runtime; viewing requires neither a separate
Godot installation nor Python. Standard OS libraries/utilities and GPU drivers
remain system dependencies. Help → About shows the version; compare it with
`BUILD_MANIFEST.json`. With `SHA256SUMS.txt` beside the downloaded ZIP, run
`sha256sum -c SHA256SUMS.txt` before extraction.

## Open and explore

Choose **File → Open file…** or **Open File** in the empty view and select a
WVZ1 `.wvz` capture. Renaming an older format does not convert its payload.
The first usable sample appears paused while preparation continues. Use **Frame
Scene** (`F` by default) to bring objects into view. In the Simulation panel,
choose Particles, Fields or Meshes and adjust the selected object's presentation.

Use Play/Pause (`Space`), Previous/Next sample (arrow keys) or the sample slider.
If playback buffers, pause to allow preparation or try a slower speed. Prepared
coverage is not a guarantee of uninterrupted playback on every capture.

Drag with the left mouse button to navigate the view; right-drag steers in place.
In Free Camera, hold W/A/S/D to move and E/Q to move up/down by default. R resets
the camera; O toggles Auto Orbit. Preferences → Keyboard Shortcuts shows current
bindings and stages edits until Apply. Your saved bindings may differ.

Use F11 for fullscreen. Hover the window edges to reach hidden controls. File →
Close File returns to the empty viewer; finish or cancel operations that still
need the capture if closing is blocked. Exit asks for confirmation while jobs
are active; confirming cancels active work.

## Save images and video

Save Image (`P` by default) exports the current view. File → Export → Video opens
ordinary visual export; choose a time range, output path and settings. MP4 needs
external **FFmpeg with libx264**, discoverable through PATH or Preferences → File
Locations. If encoding fails, read the job details and check the FFmpeg path and
encoder availability. Jobs lets you reopen background work or request cancellation.

Independent experimental Selection/Analysis needs external Python and NumPy;
isosurface extraction additionally needs scikit-image. See the
[external dependency inventory](THIRD_PARTY_LICENSES.md). These tools are not
bundled. Stored source values, derived results and rendered colors have different
precision/meaning; independently verify scientific conclusions.

## Captures and detailed help

Creating captures requires the separately obtained Python exporter. Readers can
use the [full Getting Started guide](https://github.com/mongstad/Wavez/blob/main/GETTING_STARTED.md)
for dependency versions, executable examples and simulation integration, and the
[user handbook](https://github.com/mongstad/Wavez/blob/main/docs/WAVEZ_HANDBOOK.md)
for detailed controls and caveats. These are online/source references requiring
network access; public read/clone access does not require an invitation. No
exporter source, simulation data or evidence tree is
included in this standalone package.

## Notices offline

Open [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) for links and literal
filenames. If your Markdown reader blocks links, open the `.txt` files in
`licenses/` directly. Help → About → Licenses and notices contains the full texts
without network access. Return to the [package overview](README.md).
