# Wavez handbook

Use this guide to open a capture, explore its recorded scene and export a view.
For installation and Python integration, start with [Getting Started](../GETTING_STARTED.md).
For formats, algorithms, resource policies and validation, use
[Technical Documentation](TECHNICAL_DOCUMENTATION.md).

**Selection and Analysis and related scientific state workflows are experimental.**
They have known usability gaps and have not been comprehensively owner-tested
end to end. Independently verify results before using them for scientific conclusions.
A convincing image is not a substitute for source values or a physical check.

## In this guide

- [Open a capture and find the controls](#viewer-shell)
- [Show color legends](#color-legends)
- [Play, pause and seek](#playback-transport)
- [Understand status and manage jobs](#status-and-jobs)
- [Navigate and choose an orbit center](#camera-inspection)
- [Understand layer times](#scenes-layers-and-time)
- [Interpret coordinates and values](#coordinates-and-scientific-meaning)
- [Adjust appearance and probe a field](#inspection-and-rendering)
- [Save a view, image or video](#recipes-png-and-deterministic-video)
- [Handle preparation and large captures](#storage-and-performance)

## Supported contracts

Wavez opens **WVZ1 `.wvz`** captures containing particles, uniform-grid scalar
fields and triangle meshes. Renaming an older file does not convert it.
The currently validated desktop platform is Linux x86_64, with a working
Vulkan-capable GPU and drivers. Forward+ Vulkan is the supported renderer.
See the [installation guide](../GETTING_STARTED.md#part-i--installation--requirements)
if the viewer will not start.

## Viewer shell

1. Click **Open File** in the empty view, or choose **File → Open file…**.
2. Select a `.wvz` capture in your desktop's file picker.
3. The first usable sample appears paused. Use **Frame Scene** if you need to
   bring its objects into view, then press **Play** when ready.
4. In the right-hand Simulation panel, choose **Particles**, **Fields** or
   **Meshes** and select the object/channel you want to inspect. Only categories
   present in the capture are available. Expand the relevant control group to
   change visibility or appearance.

Drag the panel's left edge to resize it. The top bar, Simulation panel and bottom
playback/status area each have a pin: unpin to let that area hide, hover its window
edge to reveal it, and pin it again to keep it visible. Menus and text editing keep
revealed controls accessible. On a narrow window, the panel may cover part of the scene.

Use **View → Window → Fullscreen**, **F11**, or double-click an unobstructed
viewport to enter fullscreen. Hover the window edges to reach hidden controls.
**Esc**, the fullscreen binding or another viewport double-click returns to the
previous window layout. Selection tools take priority over viewport clicks.

**File → Close File** returns to the empty viewer while launched video exports
continue. If another operation still needs the capture, finish or cancel it and
retry. **File → Exit** or the window close button asks for confirmation while
jobs are active; confirming exit cancels active work. Closing a Jobs or export
panel alone does not cancel its operation.

**Edit → Preferences → Keyboard Shortcuts** lets you change bindings and the
LMB vertical-axis preference. Changes are staged until **Apply**. Reusing a key
unbinds its previous action; **Cancel**, Escape or dismissal discards unapplied
changes. Applied preferences survive restart. Consult
[Keyboard Shortcuts](KEYBOARD_SHORTCUTS.md) for defaults and editing behavior.
Typing in a value field takes priority over viewport shortcuts.

**Help → About** shows the application version. **Documentation** opens the
repository guidance; **Licenses and notices** works offline.

## Color legends

Legends start hidden. Enable **Show legend** for each layer you want to explain.
A legend identifies its object, channel, colormap and effective color range;
particle legends also identify the range policy. Saved views can restore legend visibility.

Volume legends describe opacity strength, mapping and thresholds. A slice-only
legend says **opaque slice**: slice visibility does not use volume extinction.
Opacity strength is a display setting per world unit, not a uniform pixel alpha
or a measured physical quantity. Legends can remain visible when controls hide.
Choose whether eligible legends appear in video using its overlay settings.

## Playback transport

Use **Previous sample**, **Play/Pause**, **Next sample** or the **Sample index**
slider. The slider selects recorded sample indices: equally spaced slider steps
need not represent equal intervals of simulation time.

The clocks show elapsed playback time and duration at 1×. Click the duration to
show remaining time. Pauses and preparation waits are not added to those clocks.
For an exact time, choose **Seek…**, edit **Target** in the capture's declared
units, then click **Go**. Enter commits the number field only; it does not seek.
Invalid/out-of-range input shows an error. **Cancel** submits nothing.
**Requested time**, when shown, distinguishes a pending target from the scene
currently visible. Wait for the displayed scene to reach it before interpreting that view.

**Playback speed ×** changes recorded-time progression: 0.5× is slower, 2× faster,
negative values reverse and zero holds. It does not set rendering or video FPS.
**Loop** repeats the recorded interval. At a non-looping endpoint the last scene
holds; Play can remain active to follow newly appended records. Press **Pause**
if you want to stop following, or reverse/enable Loop to move through the recording.
Advanced selected preparation intervals pause at their own boundary.

The teal timeline marks data currently prepared for all required visible layers.
Dark gaps need preparation; a diamond marks a ready interval too short to see
clearly on the track. Prepared coverage can change after seeking, changing layers
or reclaiming memory. It helps you choose a ready region, but is not a promise of
uninterrupted playback. Pause remains available during a playback wait; resuming
may require more preparation.

## Status and Jobs

| Status | What it means / what to do |
|---|---|
| No capture | Open a `.wvz` file. |
| Preparing… | The requested view or playback coverage is being prepared. Wait, or choose a prepared region. |
| Ready | The paused view has sufficient prepared coverage, or the recording has reached a held endpoint. Play or navigate when desired. |
| Playing | Recorded time is advancing. Background preparation may continue. |
| Buffering | Playback is waiting for required data. Wait; if it recurs, try a slower speed or pause to prepare more coverage. |
| Unavailable | The requested content cannot currently be shown. Read the accompanying explanation and Details. |

For an explicitly selected preparation interval, **Preparing — N%** reports field
sample preparation for that interval, not elapsed time or whole-capture progress.

Open **Jobs (N)** to see active work. **Open** returns to its controls;
**Details** shows progress, output locations and diagnostics. **Cancel** requests
cancellation; video asks for confirmation, and cancellation may take time.
Closing the overview or details leaves the job running. Minimizing the viewer
does not stop a video export. Job history is limited to the current session.

A **Failed — details** notice is separate from playback status. Use
**File → Details…** to read/copy it. **Acknowledge failures** dismisses reviewed
notices without cancelling work. A successful open clears an earlier open-failure
notice; picker cancellation does not. If replacement fails, do not assume the
previous scene was fully restored: reopen it if needed. See
[load-error recovery limits](LOAD_ERROR_STATUS_RECOVERY.md).

## Camera inspection

| Action | How to use it |
|---|---|
| Frame Scene | **F** brings current objects into view while keeping camera orientation. |
| Reset Camera | **R** frames the scene and restores the default orientation. |
| Look around | Left-drag tumbles the view; right-drag steers the heading in place. |
| Move in Free camera | Use **W/A/S/D** and the configured Up/Down actions (**E/Q** by default). |
| Zoom / movement speed | Use the mouse wheel to zoom and **+ / −** to adjust Free Camera movement speed. |
| Auto orbit | Toggle **O** or **Navigate → Auto orbit**. Movement keys or RMB steering take over manual navigation. |

Bindings are editable. Free camera starts on and Auto orbit off. Opening a
capture or resetting the camera preserves those modes. A saved view can restore
its navigation choices. Optional held orbit and roll actions start Unbound;
assign them in Keyboard Shortcuts. **Camera Roll Speed** changes how quickly
roll keys bank the view. Frame Scene keeps a banked orientation; Reset Camera clears it.
Camera controls change the view, not the scientific objects or source coordinates.

### Choose an orbit center

1. Open **Navigate → Edit orbit center…**. Auto orbit pauses while you place the guide.
2. Enter **World X/Y/Z**, or drag its labeled handles. If a handle points toward
   you and is hard to drag, move the camera or enter coordinates instead.
3. **Gizmo radius** makes the placement guide larger or smaller in world units.
   Use its −/+ buttons or wheel; Shift makes finer adjustments. It helps you see
   the chosen center without resizing data or setting the camera's orbit distance.
4. To place the center in front of the camera, set **Place ahead depth**, then
   press **Place ahead**. Changing depth alone does not move the guide.
5. **Apply** turns the camera toward that center and starts orbiting from the
   camera's current position. Its distance from the center sets the orbit size.
   Move farther away beforehand for a wider orbit, or use wheel zoom afterward.
   If the camera is exactly at the center, move away before applying.

The chosen center stays fixed as you navigate. **Hide controls / Show controls**
can make more room for the guide. **Cancel**, the close button or Escape restores
pre-edit camera/navigation state. If you need placement precision or numeric
limits, see [orbit-center reference](ORBIT_GIZMO.md).

## Scenes, layers and time

Each layer has its own recorded samples and units. The scene slider combines
their timestamps, but a field does not gain a new sample just because particles
were recorded. Check the layer's source time and exact/held/interpolated status
when comparing views.

| Requested time | What you see |
|---|---|
| Exactly on a layer sample | That recorded sample. |
| Between persistent particle samples | Compatible positions interpolate by supplied IDs; scalar/category/phase channels hold the earlier sample. |
| Anonymous particles | Recorded positions/channels hold; no inferred tracks. |
| Between compatible stable-topology mesh samples | Vertex positions interpolate; channels hold. Incompatible geometry holds. |
| Between field samples | The earlier full field holds; no temporal field interpolation. |
| Before a dynamic layer's first sample | That layer is unavailable. |
| After its last sample | Its last sample holds. |
| Static object | Its one recorded sample is reused. |

An interpolated position is not an extra scientific observation. Particle IDs
belong to the simulation, not row order or proximity; IDs cannot be recycled after
removal. Trails require explicit identity and contiguous history. A changing
isosurface has no inferred material identity.

## Coordinates and scientific meaning

Use the capture's declared units and coordinate conventions. Viewer world is
right-handed, with Y up and forward toward −Z. Wavez does not automatically
convert units or vector bases. If a capture's geometry looks wrong, verify the
exporter's axes, spacing and transforms rather than treating a camera change as a data fix.

Keep the computational domain, field sample locations, particle bounds and
reference guides distinct. Brightness or tracer extent does not establish a domain
boundary, absorber, density field or conservation result. Stored channels are data;
color, opacity, marker size and clipping are representations. A probe is not
inherently a mass element or a volume integral.

## Inspection and rendering

Choose the layer's channel and colormap, then set a range appropriate to its units.
For comparisons, use fixed ranges across views. Automatic per-sample ranges can
change as time advances. A range frozen from one sample stays fixed but may clip
values in other samples; check the active range policy before comparing brightness.
Ordinary logarithmic mapping
requires positive bounds and eligible positive finite values; it is not a signed
mapping. Constant values and unavailable/invalid data should not be mistaken for
new physical structure.

For fields, use **Fields → Color Mapping** and **Opacity** separately. Color
range changes do not change opacity thresholds. **Linear scalar** uses signed
values for opacity; **Magnitude** uses absolute values while color keeps the sign.
A nonnegative zero threshold can hide near-zero space. Thresholds must be finite
and increasing; choose them for the current channel's units/range. **Opacity
strength** and **Ray step** affect presentation and cost, not calibrated physical
measurements. Larger ray steps can miss fine structure. Use **Tools → Derive
range** for sample-derived ranges and separate resets; its result is not an
estimate of unrecorded extrema. See [opacity mapping](VOLUME_OPACITY_MAPPING.md).

Use **Tools → Slice** for axis-aligned/oblique slices and **Clipping** to restrict
the displayed region. One translucent volume and one derived isosurface may be
active; overlapping translucent volumes are not composited. Mesh surface and
wireframe views retain vertex/face channel association.

### Probe a field

Open **Tools → Source probe**, select the volume/channel, enter world XYZ and
press **Probe selected volume**. The channel must be available in the prepared
field sample; probing does not prepare hidden fields or change display channels.
The result refers to that source sample's time. After playback, seeking or changing
context, press Probe again; the previous result/marker is not a continuously
updated measurement. **View → Probe marker** only hides/shows the last valid
marker. An unavailable result hides it; video excludes it.

Probes calculate trilinear interpolation from full-resolution source arrays.
Arbitrary locations are derived values, not stored samples. Outside the domain
or with any nonfinite supporting corner, a probe is unavailable—even if that
corner has zero interpolation weight. Native probe coordinates have float32
precision; displayed decimals are not a last-bit validation instrument.
A finite-looking slice pixel does not prove a probe is valid.

GPU previews can use reduced resolution and float32 values while source arrays
remain unchanged. Isosurfaces are approximate level sets extracted after float32
conversion; cells with nonfinite corners are omitted. They are not automatically
material boundaries or tracked physical objects. Screenshots and colormap colors
are not numerical measurements. See [Technical Documentation](TECHNICAL_DOCUMENTATION.md#scientific-values-and-analysis)
for precision, interpolation, integrity and extraction limits.

## Recipes, PNG and deterministic video

- **State → Save view preset… / Load view preset…** saves/restores presentation:
  camera, styling, mappings and eligible legends. It does not save source identity,
  exact simulation time, selections, numerical results or UI layout. Settings apply
  to compatible current layers; read diagnostics for skipped settings.
- Scientific inspection/analysis bundles are separate source-bound workflows.
  They cannot be loaded as portable view presets and remain experimental.
- **File → Export → Image** saves the scientific viewport as PNG with eligible
  legends, without application controls. In fullscreen it uses the full scientific
  viewport. The image destination is session-selected or set in File Locations.
  An optional sidecar records inspection state; it does not make pixels a scientific measurement.
- **File → Export → Video** sets a recorded-time range, output FPS/resolution,
  camera and presentation. Ordinary video excludes Selection/Analysis overlays;
  it does not run numerical analysis. Explicit Matched Views is a separate experimental workflow.

Video uses its chosen recorded times rather than interactive rendering speed.
The ending time is excluded; a zero-length range makes a single frame. Camera
orbit follows video time. Source changes can fail an export instead of silently
using different data. Timing is deterministic; pixels need not match across GPUs/drivers.

MP4 encoding requires external FFmpeg with `libx264`. Missing FFmpeg leaves PNGs;
failed/cancelled exports retain recoverable artifacts. Existing output files are
not overwritten. Read Jobs/Details for progress, errors and output locations.
For full options and recovery, see [image export](IMAGE_EXPORT.md),
[video export](VIDEO_EXPORT.md) and [view presets](VIEW_PRESETS.md).

## Storage and performance

Leave **Tools → Performance → Playback preparation** on **Automatic** for
ordinary use. Preparation continues while paused and reuses ready data when possible.
Large captures, uncached seeks, changes of direction/channel and memory pressure
can need another preparation wait. More RAM can provide longer prepared coverage,
but does not guarantee sustained playback at every speed.

If playback repeatedly buffers, lower its speed, pause to build coverage or hide
unneeded layers. **Selected interval (advanced)** and **From current position
(advanced)** prepare a chosen interval before playback. They pause at its far
boundary or loop within it when Loop is on. If the interval cannot fit safely,
choose a shorter one or free RAM. These choices do not change stored source quality.
Use Performance/Details to understand an admission or availability message rather
than assuming a larger requested cache must fit.

A stationary paused/end-of-recording view redraws only when needed; navigation
and Auto orbit still redraw. Play can keep following live appends at a held endpoint.
A quiet GPU therefore need not mean the viewer is unresponsive.

Successful interactive opening is **not full integrity verification**: readable
payload corruption can appear in playback and native probes. For scientific use,
verify the capture separately; [Getting Started](../GETTING_STARTED.md#read-in-this-order)
links the verifier and lifetime identity audit. Python analysis and offline
readers retain strict payload checks, but do not establish physical truth.
Compression is lossless storage, not a promise of faster preparation.

Resource limits may refuse a view/export or reduce its preview quality; source
arrays stay unchanged. Cache budgets are not whole-process RAM/VRAM guarantees.
Use the [technical resource references](TECHNICAL_DOCUMENTATION.md#playback-and-resource-policies)
for exact budgets, preparation rules and measured limits.

## Roadmap boundary

Only the documented current workflows are available. Selection/Analysis remains
experimental; no automated physical-event detection, web dashboard or remote
control is provided. Future plans do not authorize or imply implemented features.
Consult [Technical Documentation](TECHNICAL_DOCUMENTATION.md) for supported scope,
contracts and the limits of existing validation.
