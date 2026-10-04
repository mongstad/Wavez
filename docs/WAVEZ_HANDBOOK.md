# Wavez handbook

Wavez is a scientific capture viewer with a Python export layer and a Godot desktop viewer. Its job is to preserve declared data and make representation choices inspectable. A visually persuasive image is not a substitute for a numerical field, a conservation check or a declared boundary. The current implementation is `WAVEZ/`; see [current status](CURRENT_STATUS.md) for accepted scope and [evidence](EVIDENCE_INDEX.md) for measurements.

## Architecture and development history

The simulation advances its own state. Python exporters serialize samples into captures without owning the simulation's equations, units or physical interpretation. The Godot viewer reads committed samples, prepares display buffers and applies camera, mapping and layer settings. Rendering, inspection recipes and deterministic video use the same sampling and visual-state contracts. G4 numerical analysis runs on a bounded private Python worker using NumPy. Optional
full-grid isosurface extraction also uses scikit-image. Compression and external
engines have separate availability requirements.

| Stage | Delivered purpose | Evidence |
|---|---|---|
| G0 | Audit the particle viewer, compatibility, source preservation and real workload | [Historical state audit](CURRENT_STATUS.md) |
| G1 | Scientific particle inspection: signed/phase mapping, declared guides, physical-time inspection and recipes | [Inspection contract](<../INSPECTION_STATE.md>) |
| G2a / G2b | Bounded storage/index/cache and real playback work; typed lossless storage, explicit IDs, optional Zstandard | [Historical G2 storage report](<../G2_STORAGE.md>) |
| G3 | Native scenes with independently sampled particles, meshes and scalar grids; volume/slice/probe/surface rendering and export | [G3 acceptance](<../G3_REPORT.md>) |
| G3 maintenance | Refresh the live timeline's range as committed union timestamps change | Covered by current native timeline regression tests |
| G3 playback | Hidden-particle fast path, asynchronous preparation, startup/seek buffering and bounded RAM policies | [Performance maintenance](PERFORMANCE_MAINTENANCE_REPORT.md) |
| G4 | Selections, native-clock analysis, diagnostics, space-time plots, durable exports and matched runs | [G4 guide](G4_GUIDE.md), [accepted gate](G4_ACCEPTANCE.md) |

Earlier documents sometimes append new checkpoints above obsolete scope tables. This handbook and [current status](CURRENT_STATUS.md) resolve that chronology; a historical “G3 future” paragraph is not current truth.

## Viewer shell

With no capture loaded, the viewport retains its cinematic sky without decorative
star specks and shows a centered **Open File** button. Decorative stars have
also been removed from loaded scenes and exports; scientific particles remain.
Click it to open the desktop's native file picker, or use **File → Open file…**.
The picker accepts WAVEZ Scene Format (`*.wvz`) files. Its Open, Cancel,
bookmarks and Recent behavior follow the desktop environment.

The right-hand Simulation panel uses Particles, Fields and Meshes categories.
Opening a mesh-only file selects Meshes immediately, showing its object selector
and controls. Other file types retain the currently selected category; changing
an object's visibility does not change it. An explicit video-export workspace
selection remains authoritative for that export.

Open **Help → About → Documentation** to reach the repository README
and its guidance links. The in-app Handbook surface has been removed; this
repository handbook remains available as a documentation file. The separate
repository link and **Licenses and notices** remain in About.

**File → Exit** is the final File-menu command, below a separator. It is available
with or without a capture and uses the same shutdown function as the window's
close button. Normal reader, preparation, analysis and export cleanup runs;
active export workers receive the existing graceful cancellation request.
The current close path has no additional application-exit confirmation.
In Fullscreen, reveal the top bar to access File.

The accepted [issue-41 shell](UX3_SHELL.md) hosts the
[issue-42 persistent transport](UX3_TRANSPORT.md). The
[issue-43 status and Jobs surface](UX3_STATUS.md) is owner-merged.
[Issue-49 media timing](UX3_MEDIA_TRANSPORT.md) is pending owner review.
Use Open… in the command bar or empty view. Click the capture name for copyable
source details. State opens Save/Load view preset directly in the platform file picker; analysis bundles remain separate;
Export routes to PNG, video and numerical export. View and the viewport buttons
provide frame/reset, panel visibility and fullscreen.

**Help → About** shows the full application version, owner logo,
copyright, licensing summary and GitHub link. **Licenses and notices** provides
the full packaged project and third-party notices without an internet connection.
About replaces the temporary standalone Version entry and works without a capture;
see [About behavior](../viewer/ui/about/README.md) and [version policy](VERSIONING.md).

Scene retains the existing inspector. Appearance, Selection and Analysis provide
links into the same controls; choosing a workspace never binds a scientific
source or changes selection membership. Playback is now in the persistent bottom transport. Preparation budgets remain in the
inspector. The fixed header reports current capture context, not
a selected-object editor.

The right dock starts at 360 logical pixels, or 320 below 1200 pixels. Drag its
left edge to resize. The top bar, right panel and combined playback/status strip
each have one local pin. All start pinned. Unpin to auto-hide after leaving the
surface for 0.35 seconds; hover its window edge for 0.5 seconds to reveal it.
Menus, dialogs, dragging and focused text edits keep revealed surfaces available.
Pin again for persistent visibility. Playback and status always hide/reveal together.
These preferences last for the session and are not saved in portable view presets.
At narrow widths the right panel overlays the scene; pinning keeps it visible.
Failed-open details remain available until dismissed; failed replacement retains
the previous usable scene.

**View → Window → Fullscreen**, the default **F11** binding, or a double-click in the unobstructed
simulation viewport enters fullscreen with all controls initially hidden and the
three surfaces temporarily unpinned. Their 10px edge zones remain active for access.
**Esc**, the configured Fullscreen binding or viewport
double-click exits and restores the prior native window mode/geometry, pin states
and temporary visibility. Scientific overlays retain their enabled state.
There are no viewport recovery buttons, separate Immersive command, or View-menu
hide/show commands. F1 no longer toggles panel visibility. The default Shift+F11
alternate invokes the same Fullscreen action; both bindings are editable.
Text/numeric entry suppresses the entry shortcut; Esc recovery remains available.
Selection tools keep priority over viewport clicks. Camera interaction and playback
continue. See [edge reveal and fullscreen](WINDOW_EDGE_REVEAL.md) for validation,
interaction boundaries and owner review steps.

**Edit → Preferences → Keyboard Shortcuts** opens the compact violet shortcut
editor; Help no longer contains a static shortcut list. Select a binding and
press a key combination to stage it. Reusing a binding immediately unbinds its
previous action in the draft. Apply saves and activates changes while keeping
the editor open, then disables until another edit. Cancel, the shell-styled X,
or dismissal silently discards only unapplied edits. Escape cancels a listening
field first, and Tab/Shift+Tab navigate the editor. Clear and Reset Defaults also remain staged.
The application profile retains these preferences across restarts, separately
from captures, recipes, presets and video output. See
[defaults, action routes and owner checks](KEYBOARD_SHORTCUTS.md).

## Color legends

Legends start hidden: particle **Show legend** is unchecked at application
startup, and field/mesh layers without an explicit preference default to hidden.
Enable each legend with its existing **Show legend** control. Explicit recipe
visibility values still restore as saved. Particle visibility remains a session
preference when replacing captures; newly constructed field/mesh layers use the
hidden default. Recipes omitting layer preferences use that same default; an
omitted particle preference retains the live value, as before.

Enabled scalar legends show the color ramp above labeled **Object**, **Channel**,
**Colormap** and **Color range** values. The range includes the active linear,
log or cyclic mapping; particle legends also show **Range policy** using the same
wording as the panel. These are the existing effective display bounds, not a new
normalization calculation.

Two text columns keep ordinary field/mesh legends to two rows. Particle range
policy occupies a third row. Long values wrap without reducing the font size.
Cards share a width of up to 476 logical pixels including padding. Overflow
scrollbars sit outside the cards on the left, preserving aligned edges.
Cards stack above the playback controls with six-pixel gaps, grow upward, and
scroll when the layer collection exceeds its bounded viewport space. Each layer's
**Show legend** remains independent of panel visibility; hidden or ineligible layers
have no legend. Video exports retain the existing overlay inclusion control.
See [legend content and layout validation](LEGEND_CONTENT_LAYOUT.md).

## Playback transport

Previous sample, Play/Pause, Next sample and the **Sample index** slider are
available without scrolling or opening the dock. Hover or drag the slider to see
the sample index/count; there is no persistent index caption. Equal slider steps
select indices in the union of recorded samples, not equal elapsed-time intervals.
The transport stays visible when the dock is hidden and in interactive fullscreen. It is
64 logical pixels high at normal desktop width and reflows to two rows (104 pixels)
below 1200 logical pixels, without shrinking text.

The slider is flanked by one-decimal **elapsed playback time** and **total duration**.
Values adapt from `43.7` to `1:12.4` at a minute and `1:04:27.3` at an hour,
rounding to tenths before carrying into the next unit.
Click the right value to toggle **remaining duration**, shown with a leading minus
(unless rounded to `0.0`). Values are nominal playback seconds at 1×; they do not count wall-clock pauses/buffering or change with speed. Progress
follows only the committed visible position. Hover elapsed for exact displayed
source time and its declared unit; Requested time retains five-decimal presentation.
Internal clocks, recipes and Seek Target keep full precision. Choose
**Seek…** to open **Seek time**, edit **Target** in the declared time units (or
Source units if unknown), then click **Go**. Typing or pressing Enter commits
only the local number-field draft; it never seeks. **Cancel** submits nothing.
Escape while editing restores the field's committed text; Escape outside the
editor closes the form. Invalid or out-of-range targets retain the draft and show
an error. Opening another capture dismisses the old seek form.

While preparation is pending, **Requested time** shows the submitted target only
when different from the displayed clock and pending for at least 450 ms. Short
waits never show this transient label. Replacement, cancellation, commit or a
published preparation failure clears it immediately; replacements start a fresh
delay. Readiness and actual seek submission are never delayed. Changing a new draft does not replace
that request. Independent layer source times and held/interpolated/unavailable
states remain in Scene layers; they are not the common displayed clock.

Recorded time is the only playback clock; there is no playback-mode selector.
Opening a scene presents its first recorded sample with playback paused. The
clock remains there until Play is pressed. Automatic particle, field and mesh
preparation starts in the background while paused, including eligible layers in
mixed scenes; the prepared timeline and cache diagnostics show actual resident
coverage. Play uses that coverage when its existing readiness rules permit.
**Playback speed ×** uses 1× = 1 recorded unit per playback second. 0.5× halves
and 2× doubles progression. Negative speed reverses, zero holds, and Loop wraps
the recorded interval. Sample indices remain navigation/lookup positions, not
another playback mode. These rates do not set render or output video FPS.
Preparation still holds the visible scene. During active playback, Pause stays
enabled and can stop playback while waiting for frames. Once paused, Play waits
for readiness before resuming.
Numeric/text focus suppresses viewport shortcuts. Scientific inspection snapshots retain exact signed
speed; obsolete mode/index-rate fields are removed without migration support.

The playback slider contains a single buffered overlay. Blue shows resident
preparations for the selected visible field channels; teal shows the intersection
where all required visible-layer data is prepared. Dark gaps need preparation;
a narrow gap can look like a black vertical line and disappears as its samples arrive.
The overlay uses actual recorded source-time boundaries mapped to the slider's
union-sample axis, so irregular timestamps remain aligned with seeking. Hover
explains the colors. The native playhead remains on top. GPU staging can still
briefly wait; this is cache coverage, not a frame-rate guarantee.

The playback slider centres its circular playhead on the visible track endpoints;
prepared coverage uses the same axis. See [endpoint validation](TIMELINE_ENDPOINTS.md).

## Status and Jobs

The 40-pixel bottom status line shows one playback/preparation message:
**Preparing…** while paused without enough prepared coverage, **Ready** when
paused with sufficient coverage, **Playing** while advancing, or
**Buffering** only when required scientific content holds the committed playback
clock for at least 400 ms. It also retains **No capture**
and **Unavailable**. Background preparation does not replace Playing or add an
adjacent counter. Transient controller buffering flags, prefetch and upload waits
do not replace Playing while committed playback progresses. Actual transport wait
points are observed without changing playback; any committed-clock progress clears
the hold immediately. The existing 200 ms status refresh means a sustained hold
appears as Buffering after roughly 400–600 ms. At a non-looping recording boundary, it shows Ready rather than
leaving Playing stale; transport timing and playback intent are unchanged.

Automatic preparation uses an indeterminate message because its admitted window
and useful startup lead can change. For an explicitly requested preparation
interval, paused **Preparing — N%** means completed
field-sample preparations divided by the total field samples in that interval,
rounded down. While playing, the status remains simply Playing or Buffering;
preparation percentage and reason remain in Details. It is not elapsed-time or whole-capture progress. Planning and
unknown totals remain indeterminate. Memory-wait and detailed cache diagnostics
are available through Details and the existing Performance controls.
See [status presentation validation](STATUS_PLAYBACK_STATE.md).

A separate **Failed — details** notice
survives unrelated informational updates and successful work. **File → Details…**
opens copyable Status details with retained failures first. **Acknowledge
failures** appears there when retained notices exist and dismisses those notices
after review without cancelling jobs or results.
Current unavailability remains visible until the underlying condition resolves.
A successful capture load automatically clears the previous failed-open banner
and its retained load diagnostic. Failed retries, picker cancellation and unrelated
updates do not clear it; other job failures remain retained. The failed-open
Dismiss action acknowledges that open failure only.
Form validation remains beside its owning input; it is not a new global job.

**Jobs (N)** in the transport counts active operations from existing controllers.
It remains reachable with the dock hidden and in interactive fullscreen. Open
reopens the original video panel or the owning legacy form. Details exposes
progress, output/intermediate directories and existing diagnostic information.
The Jobs list shows compact category rows and their actions; progress, status and
explanatory text appear in each row's Details… view instead of beneath the row.
Its borderless panel follows the Video Export dialog's title, close control,
surface, button styles and compact spacing. The header close, footer Close and
window close all dismiss the overview without cancelling work.
Aggregate failure notices are handled through File → Details… rather than a
separate Jobs button.
An open active-job Details view updates as progress is published, then retains
the final state without following later jobs.
Cancel delegates to the operation's existing cancellation behavior. Video export
first asks **Cancel video export?**; **No** is initially focused, and only **Yes**
sends the request. Dismissal leaves the export running. Video and analysis
cancellation may wait for acknowledgement. Closing Jobs or the video
panel does not cancel. Minimizing the viewer does not stop video export; closing
the application retains its existing graceful cancellation behavior.

Video completion, missing-FFmpeg PNG recovery and failures retain the latest
session details even after reopening. No job history is persisted across launches.
Selection/analysis/matched-view and isosurface forms remain in the inspector;
Jobs provides access without migrating their scientific controls. Worker windows
may still have a separate taskbar entry on KDE/Wayland.

## Camera inspection

On a clean launch, **Free camera** is on and **Auto orbit** is off. Navigate
shows both current states. The existing O shortcut toggles Auto orbit; Free
Camera has an editable action in **Edit → Preferences → Keyboard Shortcuts**
and starts unbound. Opening a capture or resetting the camera preserves the
current navigation modes. A loaded view preset may explicitly restore either
mode; an inspection recipe restores its saved Auto orbit setting, while Free
camera is session-only. Shortcut preferences store bindings, not mode states.
The two toggles are independent: Free camera never changes Auto orbit, and
Auto orbit never changes Free camera or clears an inspection pause. If F is
assigned to Free Camera, its prior Frame Scene binding becomes Unbound; one
key event invokes one action. The Navigate menu uses the same independent
toggles.

Left-drag supports continuous yaw/pitch revolutions with no pitch clamp.
Right-drag in the viewport orbits sideways about the camera's current screen-up
axis, captured at right-button press. It keeps that axis, the target and camera
radius fixed during the drag; vertical pointer motion does nothing. A new press
captures a new axis after any left-drag tumble. It works without Auto Orbit or
an active layer selection, and gives finer angular movement when zoomed close.
A right drag temporarily suspends Auto Orbit; it resumes on release.
During left-drag tumble, horizontal motion rotates about world Y and vertical
motion rotates about the current camera right axis. The camera up axis follows
that tumble, including upside-down views, without a world-up flip at either pole.
Wheel zoom, free-camera WASD/Q/E movement, F (Frame scene), R (reset) and the
chosen orbit center retain their previous roles. O toggles automatic world-Y
orbit independently; manual dragging temporarily suspends it.

**Navigate → Edit orbit center…** opens a temporary world-space XYZ/radius
editor. Drag the labeled axis endpoints or enter coordinates; change the draft
radius with its −/+ buttons or wheel over the radius controls (Shift: fine).
**Place ahead** positions the draft along the current view direction. **Apply**
sets the existing orbit target and distance and removes the guide; **Cancel**
discards the draft. Ordinary viewport drag, wheel, Free-camera movement and Auto
Orbit retain their existing behavior during and after editing. Numeric focus
retains the usual keyboard-input protection. Viewport navigation performed during
editing remains navigation; Cancel only discards the proposal.

**Hide controls / Show controls** collapses the coordinate rows to make room for
the gizmo. Setup starts collapsed in windows shorter than 720 pixels. Apply and
Cancel remain visible.

The draft radius supports 0.000001–1e15 world units. Ordinary wheel zoom uses
10% inward steps and reciprocal outward steps, with scene-bound/clip-plane
limits. Fractional input produces smaller steps; custom radii recover without
snapping to fixed world-unit bounds. Reset/Frame replace the target normally and
close the draft. Screenshot capture also closes it; saved presets/video jobs
contain only the accepted camera. See [orbit-center usage and validation](ORBIT_CENTER.md).

Recipes retain the existing yaw, pitch, target, distance and full transform
fields. They can save pole and upside-down orientations without a new schema.
Deterministic video still rotates the saved camera about world Y using video
time. See [UI-003 validation](CAMERA_TUMBLE_VALIDATION.md) for coverage and limits.

## Scenes, layers and time

WVZ1 describes named particle, mesh and volume objects, with at most one particle object and 16 total objects in the current implementation. Each has declared units, geometry/transform semantics, identity policy where relevant, and its own samples. A static object has one reusable sample. The scene timeline is the sorted union of committed timestamps, while layer sampling is independent. A field does not acquire a new scientific sample merely because particles were saved.

| Situation at requested physical time | Display/sample behavior |
|---|---|
| Exactly on a layer sample | Use that exact recorded sample |
| Between particle samples, with compatible explicit persistent IDs | Interpolate matched positions; scalar/category/phase values remain held at the earlier source time |
| Anonymous particles | Hold recorded positions and channels; no inferred tracks |
| Stable-topology mesh, compatible ordered vertex IDs and topology | Interpolate compatible vertex positions; held channels |
| Mesh without compatible identity/topology | Hold geometry |
| Volume between samples | Hold full field; no temporal field interpolation |
| Before the first dynamic sample | Layer unavailable |
| After the last sample | Hold the last sample, labeled as such |
| Static object | Reuse its one sample |

Identity is a simulation-owned int64 ID, not row number, category, proximity or a guessed correspondence. IDs may reorder between particle records, but cannot be duplicated or recycled after removal. Births appear at their recorded sample; removed IDs hold until that transition. Trails require explicit identities and contiguous recorded history. A changing isosurface is a geometric level set with no persistent material identity.

Physical-time seek accepts fractional times. The slider still indexes **union timestamps**; its thumb is not a continuous physical-time fraction. The latest fix only synchronizes its extent with committed growth/truncation. Sample source times and exact/interpolated/held state must remain visible in inspection/export provenance.

## Coordinates and scientific meaning

Viewer world uses a right-handed coordinate system with Y up and forward toward −Z. Exported particle positions must already be in viewer world. Meshes and grids can carry an explicit affine `data_to_world`; the adapter owns any axis or unit transformation. There is no automatic scientific unit conversion or arbitrary vector-basis conversion. A storage-axis transpose is different from a physical transform; applying both as rotations can transform data twice.

Keep nominal domain faces, grid sample locations, absorber geometry, imposed regions, source-sample particle bounds and display reference guides distinct. Declare each known item. Unknown geometry stays unknown. Tracer extent, brightness and display extent do not determine a computational domain or absorber.

Stored channels are scientific data. Colormaps, clipping, opacity, marker sizes and GPU previews are representations. A passive probe is not automatically a mass element, a field cell or a volume integral. Density on a real grid must come from that grid; it cannot be recovered exactly from a tracer cloud.

## Inspection and rendering

Particles support declared scalar semantics and categories, explicit marker channels, signed mappings and cyclic phase mappings. Available range policies include automatic per sample, automatic symmetric, fixed manual, and bounds frozen from a chosen recorded interval. Interval scans inspect recorded samples, not unseen extrema. Constant finite values map to the midpoint; invalid-only data have no finite range. Ordinary log mapping excludes nonpositive/nonfinite values and is not a signed mapping. Automatic ranges must remain labeled; scientific comparisons should use fixed ranges.

Volumes use declared uniform-grid geometry, selected channels, transfer ranges/colormaps, opacity and world-distance ray steps. Ray integration clips to the grid and opaque geometry. Axis-aligned and oblique slices, world-coordinate probes and clipping support inspection of the field without inferring it from particles. The initial implementation allows one translucent volume and one derived isosurface; arbitrary overlapping transparent volumes are not composited. Additive particles do not supply opaque depth.

Volume color range and extinction now have independent mappings. **Linear scalar**
maps the selected source scalar between explicit zero/full-opacity thresholds;
**Magnitude • absolute scalar** uses its absolute value for extinction while
preserving sign for color. A non-negative zero threshold permits transparent
zero/near-zero space even with a symmetric color range. **Opacity / world unit**
scales this weight; **Ray step** remains a quality/performance control. These are
presentation settings, not calibrated scientific measurements. New views retain
linear opacity 0–1; old recipes copy their saved color range into independent
opacity thresholds to preserve their original rendering. The
[mapping contract and validation](VOLUME_OPACITY_MAPPING.md) describe persistence,
limits and examples. Color edits alone never change opacity.

Volume color normalization supports linear and explicitly selected logarithmic
mapping, independently of opacity. Bounds can be entered manually or frozen from
the current source sample using its symmetric extrema or selected percentiles.
All policies retain the resolved bounds across playback and recipe restoration.
The controls disclose endpoint clipping, source finite extrema and actual clipping
presence. Log requires positive bounds and positive finite sample values; an
ineligible sample is explicitly unavailable, with source probes still accessible.
These are display choices, not calibrated interpretations. See
[volume color policies and validation](VOLUME_COLOR_NORMALIZATION.md).

Quick setup was removed under #160. Use **Fields → Color Mapping / Opacity**
for manual display settings and **Tools → Derive range** for symmetric or
percentile sample ranges and independent color/opacity resets. Scene Viewing
presets and portable view presets remain available. The reusable volume preset
calculation API remains internal; there is no volume preset chooser in the UI.

Probes read full source arrays with trilinear spatial interpolation and explicit world-to-grid conversion. At source sample coordinates they recover the source value subject to arithmetic/coordinate precision. An arbitrary probe point is an interpolated value, not an extra recorded scientific sample. Out-of-domain probes and invalid interpolation neighborhoods report unavailable. Python uses float64 probe coordinates; Godot coordinates are float32, so its displayed decimal values are not a last-bit validation instrument.

The white three-axis cross belongs to **Scene layers → Source probe**, not the
camera or particle-selection overlay. **Show probe marker** hides/restores the
last valid explicit probe without clearing coordinates or the numeric result.
Playback and seeking retain that last probe; click **Probe selected volume** to
sample again. Probing while hidden updates the result without showing the cross.
An unavailable probe hides it even if the switch is on. Recipe loading preserves
the session's marker visibility, but recipes/PNG sidecars do not serialize this
session-only marker. Screenshots include the cross only when shown; deterministic
video excludes it. Auto-hiding the inspector does not hide this 3D marker. Reopening a capture
resets the probe session (switch on, no cross until a valid probe).

GPU grids are float32 previews, potentially reduced by endpoint-aligned power-of-two LOD under budget; the shader samples that preview. Source arrays remain full resolution. Isosurfaces use optional scikit-image Lewiner marching cubes over the full source grid after the algorithm's float32 conversion, with no smoothing or decimation. Nonfinite-corner cells are omitted. A surface is an approximate level set, not a material boundary, tracked particle population or discovered physical object. Extraction is debounced, bounded, cancelable on stale requests and cached by source/settings identity.

Meshes contain real indexed triangles and optional vertex/face channels. Surface and wireframe views are supported. Source CCW winding and normals are transformed explicitly, including reflection and inverse-transpose handling. Face colors may require expanded display geometry; display memory can exceed serialized array size.

Scientific rendering disables decorative effects. Forward+ and Compatibility can differ in blending/color behavior; neither output is calibrated radiance, and cross-renderer identical pixels are not promised.

## Recipes, PNG and deterministic video

**State → Save view preset… / Load view preset…** saves a small portable JSON
file in the chosen filename/location. It restores Wavez-owned viewport settings
(camera, particle presentation, current selected volume/mesh mapping, opacity,
legends, environment and render quality). It does not store source/object/channel
names, exact simulation time, selections, results or UI layout. Per-layer settings
apply to the current compatible selection; missing kinds/unsupported optional
controls are skipped with diagnostics. No source-name remapping or capture scan
is performed. Save and failed load preserve playback; successful load changes only
presentation. See the [complete field contract and validation](VIEW_PRESETS.md).

The separate Save/Load analysis workflow and inspection PNG/video sidecars retain
source-bound scientific state and verification. Those inspection bundles are not
portable view presets and are explicitly refused by Load view preset; no legacy
conversion is provided.

PNG sidecars can record the same state and an image hash. The screenshot destination is selected for the current session. Deterministic video renders a separate SubViewport at specified resolution and times, independent of interactive rendering speed; a real GPU renderer is required for image acceptance. The render worker minimizes
its noninteractive window and draws export frames explicitly, so rendering can
continue when it or the main viewer is minimized. Use the Export Video panel for
progress/cancellation; UI-launched jobs retain `renderer.log` alongside progress
and encoder diagnostics. A startup flash or taskbar entry can depend on the
platform.

For output frame `n`, requested capture time is `start + n × playback_rate / fps`; video time is `n / fps`. The interval is `[start,end)`, with a single frame for a zero-length interval. Samples use the same identity/held policies as inspection. Camera orbits advance by video time, not wall-clock render delays. Source identity and committed extent are pinned; unsupported source changes fail. Optional per-frame state survives successful PNG cleanup.

PNG sequences can be encoded with FFmpeg/H.264. Missing FFmpeg leaves useful PNGs; errors/cancellation retain recoverable job artifacts. Publication refuses overwriting an existing output. Timing is deterministic, while pixel identity across GPUs/drivers is not guaranteed. Full timing, cancellation, output and recovery details: [video contract](<../VIDEO_EXPORT.md>).

## Storage and performance

While playback is paused, an unchanged view redraws only when needed. Input,
preparation and status updates remain active. Paused Auto orbit renders at up to
60 FPS (or a lower existing frame cap); its angular speed still follows elapsed
time. Play restores the previous frame cap. Scientific samples, field resolution,
rendering settings and deterministic exports are unchanged by this policy.
See [paused rendering](PAUSED_RENDERING.md) for measured behavior and limits.

Typed WVZ1 channels preserve supported source bytes with optional lossless Zstandard. Compression is a storage choice, not a promise of faster playback. Normal viewer opening checks the format, object metadata and bounded fixed-size record headers, then loads the initial visible samples. It does not parse every future descriptor or build/write a full descriptor index. Requested reads retain descriptor/commit hashes, schema/bounds checks and bounded decoding, including background lookahead. Interactive playback skips stored/raw payload SHA comparisons. Readable payload corruption can therefore display incorrect scientific values without an error, including in native source probes. Run the [explicit integrity verifier](PLAYBACK_INTEGRITY.md) to check the whole capture. Python readers/analysis and offline video export retain strict payload checks. Decoded LRUs and source-generation checks still invalidate changed sources; file paths/stamps are not proof of integrity. No legacy format or sidecar reader is included.

The scene inspector's **Particle playback buffer** separates decoded sample RAM, prepared pair RAM and current GPU resources. **Automatic (safe RAM)** first requests a short startup window, then sizes validated particle descriptors on the existing CPU worker. It prepares the whole scene when conservative decoded/prepared cache accounting fits safe physical RAM, otherwise a bounded directional interval. Particle-only scenes have no fixed automatic 2 GiB or eight-pair ceiling. Scenes containing fields retain the existing at-most-2-GiB, eight-pair particle window to preserve RAM for the field playback runway. The existing physical-memory reserve, a 40% physical-RAM ceiling for particles, competing cache/worker allowances, per-job scratch and 5% allocation slack remain enforced. Opening presents the initial scene immediately after its required samples are ready; controls do not wait for background preparation. Uncached seeks retain the previous committed scene and wait only for the requested samples. Rapid seeks replace obsolete work; reverse playback and **Loop recorded interval** reorder the bounded window. Loop defaults off. Hidden particles skip preparation unless a guide, inspection or reveal needs their data.

Manual RAM choices also use rolling caches. The old explicit full-preload setting maps to Automatic. Every choice remains subject to the RAM guard. Budget reductions reclaim resident caches even when no new decode is needed. The Ready tooltip distinguishes visible-sample readiness from background cache completion: it reports resident prepared intervals and authoritative decoded/prepared cache charges, including a physical-headroom stop. These conservative charges count shared arrays more than once and are not process RSS. The timeline continues to show only resident prepared coverage. See [particle cache policy and validation](PARTICLE_CACHE_CAPACITY.md). A malformed requested record is rejected with its object, zero-based sample index and record sequence; playback pauses and the error advises reopening or re-exporting. A bad future prefetch does not block a valid current sample. Whole-capture verification is a separate, read-only diagnostic: `python tools/verify_wvz.py /path/to/capture.wvz`. It reads and verifies all records and may take time; it is never invoked by normal viewer opening. See [lazy loading](SSC_LAZY_LOADING.md) for timings and limitations.

Mixed playback can temporarily refill fields even while some field coverage remains. At higher playback speeds playback may consume the initial field cache faster than background preparation can replenish it. Background preparation still uses up to four field workers and a separate particle worker. The Buffering tooltip identifies a field refill holding playback. See [mixed playback, 2× buffering and memory observations](MIXED_PLAYBACK_BUFFERING.md).

Historical explicit-preload evidence on the 48 GB workstation: a retained 100k-particle capture prepared 81 pairs in 13.3 seconds, enabled Play after 0.78 seconds and used about 2.50 GiB process RSS. An isolated probe measured 18.67 MiB of retained Godot allocations per decoded 100k-particle sample and another 7.27 MiB per prepared pair without trails. Conservative cache charges are larger and count shared references again. CPU preparation does not create GPU resources for every cached pair.

**Performance → Playback preparation** defaults to **Automatic**. Opening prepares
as much useful directional coverage as safely fits, while measured throughput and
prepared lead control Play. Moving the playhead reuses overlapping preparations and
redirects missing work. Memory pressure reclaims eligible history before new
allocation is refused; current/staged samples and in-flight ownership stay protected.
A reasonable history allowance is retained when capacity permits. Pausing keeps
Automatic preparation active. A pause or elapsed idle time alone does not evict
prepared data; the existing source/configuration invalidation and physical RAM
admission policies still apply. Loading another scene closes the old workers and
releases their cache ownership.

**Selected interval (advanced)** and **From current position (advanced)** prepare
an explicit bounded interval before playback. It starts at the interval boundary
if the current time lies outside, pauses at its far boundary, and loops inside it
when Loop is enabled. Seeking outside pauses and returns to bounded navigation.
These controls are session-only; exports keep their explicit job sampling.
An interval includes each field's held sample at its start. If it cannot fit safely,
select a shorter interval or free RAM; source quality is unchanged.

All source channels and selected-channel display planes are retained within
combined cache/worker reservations and OS/renderer headroom. Repeat playback and
seeks reuse them. Compatible channel changes reuse validated arrays and statistics,
replacing only selected-channel planes. GPU staging remains current plus one future
texture per field. WVZ1 is the only supported capture format. See
[rolling playback](ROLLING_PLAYBACK_CACHE.md) for current validation and limits;
[continuous playback](SSC_CONTINUOUS_PLAYBACK.md) retains historical evidence.

Field CPU preparation uses a bounded pool with ordered publication and per-job
transient memory reservations. [Dynamic preparation](DYNAMIC_FIELD_PREPARATION.md)
is the default: unset or `auto` selects a pool capped at logical CPUs minus two,
clamped to 1–4, and starts at two active lanes (one when capped there). It measures
production rate and prepared lead, increases concurrency when needed, and backs
off for memory, swap or sustained presentation pressure. Idle lanes sleep.
Set `WAVEZ_FIELD_WORKERS=1`, `2`, `3` or `4` before launching for a fixed
diagnostic cap; live physical admission still may allow fewer jobs. Other values
use Auto. All-channel source reuse and adaptive cache semantics remain intact.

In Automatic preparation, Play starts from resident coverage when it provides
an appropriate runway. With three busy seconds of measured throughput, a producer
at least 1.10× demand needs three seconds of lead; near parity (at least 0.95×)
needs eight. Slower or unmeasured production prepares the admitted rolling window.
Current/next residency alone does not bypass this gate. Predicted depletion causes
an intentional pause; the same runway gate controls a clean resume. The
[rolling cache](ROLLING_PLAYBACK_CACHE.md) reclaims eligible history before retrying
physical admission, protects current/staged samples, and reuses overlapping data.
Missing data, direction/channel changes and resource pressure can require explicit
buffering again. Advanced selected intervals still prepare their
whole requested interval. Neither mode changes source cadence or quality.

Each visible field holds its current texture and at most one staged future texture. Their per-texture budgets split the existing layer GPU share; this can increase preview stride on large fields. GPU uploads occur on the main thread, at most one per process frame, ahead of source transitions where possible. Texture binding and shader state changes remain on the main thread. Cold seeks and underflow hold the committed physical clock, gate paused Play and pause background analysis until the required samples are ready. Stale source/configuration work is discarded. Initial opening, scientific inspection and deterministic export remain synchronous; large textures can still cause an upload callback stall. See the [PERF-001/002 report](PERFORMANCE_MAINTENANCE_REPORT.md) for exact guards, bounds and retained 02B/03B measurements.

Mesh playback uses at most four future source pairs per visible mesh in the current direction, including reverse loops. Its [adaptive CPU preparation allowance](MESH_PREPARATION_BUDGET.md) uses a quarter of safe physical-RAM headroom after other reservations, capped by the current/staged requirement and the five-pair workload. Active references and in-flight temporaries retain separate conservative reserves; field admission accounts for the mesh allowance. CPU RAM refusals identify the required and available allowance and recover when memory becomes available. A current mesh and at most one staged future mesh share each layer's GPU quota. At most one mesh upload runs per process frame. Cold seeks hold the committed clock until the pair is ready, and source/settings changes cancel obsolete preparation. GPU budget or float32 display refusals preserve the decoded scientific samples and report the unavailable preview.

Meshes with exactly matching stable vertex IDs and triangle topology use a relative position blend on the GPU. Changing topology or identity holds the earlier geometry. Source arrays remain typed and exact; vertex/face scalar colors hold the earlier sample. The material remains unshaded. Explicit inspection obtains the same float32 preview positions and recomputed deformed normals as synchronous sampling; it never treats a GPU preview as full precision source data. Large buffers may still stall during upload. The owner reviewed and accepted PERF-003 on 2026-09-13; [methods, retained 04B results and limits](MESH_PLAYBACK_MAINTENANCE_REPORT.md) are recorded separately from accepted PERF-001/002 evidence.

On the retained 100k-particle capture, prepared visible transitions measured about 20 ms versus 177–181 ms before optimization, and hidden transitions about 2.6 ms. Both renderers completed the tested matrix, longer replenishment, 2× playback and loop controls without ≥50 ms callbacks. Cold startup and uncached seeks still require an explicit buffer wait. The remaining visible callback is mainly position packing and GPU submission. These measurements do not establish the same latency with every field or trail enabled. See [performance maintenance](PERFORMANCE_MAINTENANCE_REPORT.md) for current methods, limits and regressions.

Earlier checkpoints measured a real ~100k-particle capture at roughly 11.8–11.9 source samples/s when requesting 12. The full analytic G3 demo measured about 19.2 completed samples/s, with median preparation/presentation around 32 ms and p95 around 145–149 ms including extraction barriers. GPU median was about 0.3 ms; CPU preparation and transitions dominated. These are historical host/workload measurements, not universal promises. See [performance evidence](EVIDENCE_INDEX.md) before extrapolating from already-decoded synthetic renders.

Budgeted decoded arrays, caches, graphics buffers, temporary transforms and worker memory are separate. They do not sum to a strict process RSS/VRAM ceiling, and the G3 surface cache has no automatic global disk cap. G4 has separate finite
worker, preview, exact-member and export quotas, including a 2 GiB default disposable
result cache; see [G4 schemas](G4_SCHEMAS.md). [Format/API limits](CAPTURE_FORMAT_AND_API.md) are the integration preflight reference. No simultaneous heavy CuPy/viewer contention benchmark has been accepted.

## Roadmap boundary

G0–G4 are implemented and accepted. G4 reads scientific source values, keeps
independent native clocks explicit and preserves exact identities; hidden or clipped
selections remain numerically usable. [The guide](G4_GUIDE.md) distinguishes source
traces, weighted statistics, field integrals, tracer estimates and exploratory periods.
G5 local control/optional MCP and G6 events/broader adapters/release work are
**NOT IMPLEMENTED and NOT STARTED**. No web/dashboard work is authorized.
New development targets `.wvz` / WVZ1 under the
[capture format policy](CAPTURE_FORMAT_POLICY.md). The
[historical roadmap](../SIMSCOPE_NEXT_DESIGN.md) and [historical acceptance registry](../SIMSCOPE_ACCEPTANCE_MATRIX.md)
do not independently authorize future milestones.
