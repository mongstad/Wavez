# SimScope deterministic video export

## Current contract and G4 extension

G0–G4 are implemented and accepted. The original version-1 job contract and
historical validation below remain applicable to that path. G4 adds **render job
v2** and **inspection recipe v3** without changing SIMSCP3 capture bytes. Current
code is in `viewer/video/` and `viewer/analysis/`; see [G4 schemas](docs/G4_SCHEMAS.md)
and [the G4 guide](docs/G4_GUIDE.md#save-restore-and-export).

G4 jobs pin the committed source prefix, exact selection members, sampling state
and highlight settings, then await sample/selection/surface barriers before each
frame. Later appends stay outside that prefix; mutation, replacement and truncation
refuse. PNG/state bundles and per-frame sidecars retain source IDs, units, native
clocks, held/interpolated support and image hashes. Matched runs prepare two
portable jobs with explicit time/value mappings and a comparison manifest; they
render sequentially and do not register or rescale geometry. Render and numerical
export quotas are finite. Export never measures values from GPU colors.

The following implementation investigation and acceptance measurements describe
their recorded checkpoints, not new post-G4 tests. G5 control/service work is
unstarted and outside this contract.

## Using Export Video

Open a capture and set its appearance/camera, then expand **Capture / Export →
Export Video…**. Choose entire capture, current position to end, or custom start/end
in recorded capture-time units. Select 1080p, 1440p, 4K, or even custom dimensions;
24/30/60 or custom integer FPS; and capture-time units per video second.

Choose current camera locked or orbit, current rendering state or a cinematic /
scientific override, overlays, trails, H.264 quality, and a new `.mp4` output path.
The dialog estimates video duration, exact output-frame count and approximate
uncompressed temporary storage (actual PNG size depends on image content).
Click **Start Export**. A second Godot process renders and encodes the video.
The worker keeps a real GPU display connection but minimizes its noninteractive
window and makes it unfocusable. It no longer needs a visible debug window to
render. A brief startup window/taskbar entry may still depend on the platform.
The regular viewer stays usable and may be minimized. The primary button changes
from **Start Export** to **Cancel export** while the worker runs; it stops after
the current frame, or stops FFmpeg during encoding. **Run in background** hides
the dialog and is enabled only while an export is preparing or running. **Cancel**
closes the dialog without cancelling an active export; its tooltip makes this
distinction explicit. Reopen through File → Export → Video or Jobs for progress.
During selection-recipe preparation, the primary action is disabled until worker
cancellation becomes available. Terminal jobs restore **Start Export** and disable
**Run in background**. Closing the parent viewer still requests cancellation.
The job directory retains `progress.json`,
`renderer.log` (UI-launched workers) and `ffmpeg.log` for diagnosis. If writing the
cancel request fails, the dialog reports the worker PID and retained job path.

**Jobs → Video export → Details** and the export dialog share one progress
summary, for example `Rendering frame 3000 / 12000 (25%)`. The integer percentage
uses the actual rendered frame count. Separate **Elapsed** and **Estimated
remaining** lines use `hh:mm:ss`; elapsed advances between worker updates.
The approximate remaining time uses observed frames and elapsed wall time and
covers rendering only, not encoding. It appears after at least two frames and
one second. A gap longer than the greater of ten seconds or three observed
average frame durations suppresses the estimate without declaring worker failure.
Starting/loading, encoding, cancelling, failed and cancelled states have no ETA.
Completed video or retained complete PNG sequences show zero remaining; terminal
elapsed time freezes. Partial failures/cancellations retain their actual frame
counts, and invalid counts show no percentage. **Output** labels the requested
MP4 path; **Temporary files** labels the job directory containing intermediates,
`job.json` and diagnostics. A failed/cancelled job does not imply the MP4 exists.

Existing output files are never intentionally replaced: choose a new filename.
The selected visual state is copied when Start Export is pressed. Later changes
in the interactive viewer do not affect the running job. Scientific rendering
suppresses trails even if their checkbox is enabled, as in the normal viewer.

## Architecture and installed Godot capabilities

Audited `main.gd`, `capture_reader.gd`, `project.godot`, existing docs and regression
tests before changes. The interactive viewer uses frames/second and realtime
camera motion; those update paths are disabled in the render instance. The
existing 1440×900 canvas-items window stretch configuration remains unchanged.

The installed engine is Godot **4.7.2-stable**, hash
`ed1daf0bf001b61586d9930840f2f1394092c079`. Its CLI supports `--write-movie` and
`--fixed-fps`. A real Movie Maker probe wrote exactly two 96×64 PNG frames at
30 FPS (with accompanying WAV). Runtime settings also expose OGV encoding
controls. PNG capability was exercised; OGV was not used for this feature.

Godot documents Movie Maker as a startup mode and supports PNG sequences as well
as movie containers. Its automatic writer captures viewport frames, including
startup iterations. For SimScope's explicit load/index/sample/save lifecycle,
we use a manually updated **SubViewport** and save its completed image directly.
This avoids startup frames in the video, AVI container limits, and coupling the
export's resolution to a desktop window. The separate process still uses
`--fixed-fps`; output timing comes from our frame index, not the supplied delta.
See the official [Movie Maker guide](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html)
and [SubViewport reference](https://docs.godotengine.org/en/stable/classes/class_subviewport.html).

Modules under `viewer/video/`:

- `render_job.gd`: version-1 and G4 version-2 JSON schemas, state snapshot/restore, validation,
  deterministic frame count and process arguments.
- `offline_timeline.gd`: timestamp-only index, binary-search sampling, bounded
  recorded history and a pure camera-path function ready for future keyframes.
- `render_worker.gd`: dedicated viewport, PNG writing, manifests, progress,
  cancellation, FFmpeg encoding and verified output publication.
- `export_dialog.gd`: settings, estimates, launch, nonblocking monitoring and cancel.

Normal Godot startup recognizes `--simscope-render-job=...` and dispatches to the
worker before building an interactive scene. Jobs serialize capture path/range,
frame bounds, output FPS/rate/size/path, camera transform/projection/target,
orbit, preset, particle appearance, mappings, normalization, filters, trails,
overlay/section state, environment properties and viewport quality settings.
No physics runs; capture access is read-only. Indexing freezes the available
complete frames for that job instead of live-tailing the capture.

## Exact timing semantics

For zero-based output frame n:

```text
capture_time = start_time + (n / output_fps) * playback_rate
video_time   = n / output_fps
frame_count  = max(1, ceil((end_time - start_time) * output_fps / playback_rate))
```

The interval is **[start,end)**: end is exclusive. A zero-length range produces one
still frame. Floating-point rounding at exact integer counts is handled with a
small epsilon. Resulting MP4 duration is frame_count/output_fps, so it can extend
by less than one video frame beyond an unaligned requested duration. Entire and
current-to-end ranges retain the exact float64 capture endpoints rather than
rounding them to the displayed spinbox precision.

Playback rate is in **recorded simulation/capture time units per video second**.
It is not the interactive frames/second slider. For convenience the dialog's
initial rate uses the current neighboring-frame interval × interactive FPS when
that interval is positive. Check this rate for captures with irregular spacing.

Frames are located by a timestamp binary search. Duplicate, decreasing or
nonfinite time axes are rejected for physical-time export. Positions interpolate
only between explicitly matching persistent IDs; all anonymous formats hold the
earlier sample. Scalar/category/phase channels also hold that sample. Births/deaths
occur at exact recorded times. Trails require explicit IDs and use up to five
preceding contiguous recorded frames, breaking at missing-ID gaps. Row order/count
changes do not imply identity. History is independent of output sample count.

Locked mode preserves the exact camera transform. Orbit rotates the initial
transform around the recorded camera target and world Y axis by
`orbit_speed * video_time`. Render speed, waiting, PNG compression and encoding
cannot change the sample or camera times. Tests insert deliberate per-frame
delays and compare the complete timing/camera manifests.

## 4K and rendering quality

A dedicated SubViewport allocates exactly the requested width and height,
independently of the small 640×360 process window. It renders once after each
sample is installed. The worker disables the automatic rendering loop, yields
for event processing/layout, then calls `RenderingServer.force_draw(false, 1/fps)`
without swapping a window buffer. GPU readback checks actual image size and
writes one PNG. This removes the dependency on minimized-window redraw signals. UI uses a proportionally scaled logical canvas while
the 3D render target remains native resolution. Tests verified **3840×2160** in
both PNG headers and the encoded MP4 via ffprobe on this workstation.

The same particle shaders, colormap LUTs, camera projection, environment and
quality settings are reused. **Include viewer overlays** now reuses the current
production shell (issue #55, single construction path after #59): command bar, camera controls, right workspace dock,
transport, status and Jobs. Workspace, scroll and total/remaining preference are
captured when export starts; section and visual settings use the existing snapshot.
The dock is included when this explicit checkbox is on, even if it was hidden on
the desktop. The normal command bar is included regardless of desktop fullscreen
or immersive state. No desktop exit/hint, tooltip, dialog, export progress window
or screenshot toast is recorded.

Application chrome and scientific overlays have different ownership. This existing
checkbox still gates the particle colorbar/legend together with application UI;
`show_legend` and channel eligibility continue to apply. Turning it off does not
turn off independently enabled scene guides, probe markers or selection annotations.
No scientific overlay is enabled merely by constructing the shell. This issue does
not introduce independent legend controls. Overlay-off pixels are regression-tested
against the earlier scientific-only path.

Transport labels follow each committed output sample. The worker is not an
interactive player: its Play button is paused, and status/Jobs describe its ready
scene rather than the parent application's live jobs or wall-clock export progress.
Playback-speed controls retain the captured viewer setting; the explicit video
Playback rate still owns output timing. The shell uses the existing 1440-wide
logical export canvas, scaled to the selected output size; 3D remains native
resolution. Export overlays are not a screen recording, title or annotation editor.
See [current overlay evidence and owner checks](docs/evidence/issue-55/README.md). Matching output aspect ratio preserves framing; changing
aspect ratio follows Godot's camera keep-aspect setting.

Forward+/Vulkan was tested on the RTX 3070 Ti. A functioning graphics display
connection is required by this installed build: `--headless` selects a dummy
renderer and is explicitly rejected. A 4K monitor is **not** required. Rendering
may use substantial GPU memory; resolution and trails affect cost. Timing is
deterministic; bit-identical pixels across GPUs, drivers or temporal-antialiasing
implementations are not guaranteed. This version does not add motion blur,
keyframe editing, audio, physical-time channel interpolation or network rendering.

## FFmpeg and temporary data

The dialog detects FFmpeg on PATH; MP4 encoding requires its `libx264` encoder.
Quality presets are CRF 18 (High), 21 (Balanced), and 25 (Compact), with the slow
encoding preset, yuv420p and faststart. Even dimensions are required. Commands
use argument arrays, not shell strings, so spaces in paths are supported.
FFmpeg is launched with nonblocking pipes; stderr is saved to `ffmpeg.log` and
shown on failure. Process status/exit handling follows Godot's
[OS process API](https://docs.godotengine.org/en/stable/classes/class_os.html).

Each export creates a unique hidden `.simscope-export-…` directory **beside the
selected MP4** so frame storage and final publication share the output filesystem:

```text
job.json                 complete reproducible job description
progress.json            atomically replaced status for the interactive viewer
frames/frame00000000.png lossless rendered sequence
timing.jsonl            one sample/camera record per output frame
encoding.json            FFmpeg executable, arguments and destination
encoding-progress.txt    FFmpeg progress records
ffmpeg.log               encoder diagnostics
encoded.partial.mp4      uncommitted output until verified
cancel                   cooperative cancellation marker, if requested
```

Missing FFmpeg results in `frames_ready`, with all PNGs retained and
an explanation. FFmpeg failure, interruption or cancellation preserves completed
PNGs and any isolated partial MP4. A nonzero exit code, empty output or missing
MP4 signature prevents publication. Only after successful encoding and output
verification is the staged MP4 published to the chosen destination. On Linux,
`/bin/ln -T` atomically creates a hard link at the destination and the staging
name is then removed. This closes the check-then-rename overwrite race, including
competing symlinks/directories. The output filesystem must support hard links;
otherwise the encoded file and PNGs are retained for recovery. On other platforms,
publication still uses a best-effort existence check followed by rename;
concurrent external writers to the same destination are not protected there. PNGs are removed only after successful publication and only if Keep PNGs is
off. Job metadata/logs remain for troubleshooting. No partial output is presented
as a completed final MP4.

Cancellation may wait for the current large frame/PNG write; it does not interrupt
an individual PNG write midway. During encoding the worker terminates FFmpeg.
Abrupt OS termination or power loss cannot run orderly cleanup; remaining job
files are retained for inspection/recovery rather than deleted on next launch.

To encode a retained complete sequence manually, use the FPS and frame count in
the job. For example:

```bash
ffmpeg -n -framerate 30 -start_number 0 \
  -i '/path/to/job/frames/frame%08d.png' -frames:v 150 \
  -an -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -movflags +faststart '/path/to/recovered.mp4'
```

Check the successful exit and resulting output before removing any intermediates.
The existing capture is not needed to encode already-rendered PNGs.

## Invocation and tests

The viewer launches the equivalent of:

```bash
godot --path /absolute/path/SimScope/viewer --resolution 640x360 \
  --fixed-fps 30 --disable-vsync --audio-driver Dummy -- \
  --simscope-render-job='/absolute/path/.simscope-export-ID/job.json'
```

A retained job can be copied into a new directory and edited for automation; use
a fresh output filename and empty frame directory. Version must remain 1. Do not
add `--write-movie` to this worker command: it would record the small process
window and setup iterations, not the export SubViewport.

For comparison, the installed Movie Maker PNG probe used:

```bash
godot --path /tmp/simscope-movie-probe --script probe.gd \
  --resolution 96x64 --write-movie probe.png --fixed-fps 30 --quit-after 2
```

Run the rendered acceptance suite from any directory:

```bash
python tools/validate_video.py --godot /path/to/Godot
# Focused follow-up coverage (includes the complete UX suite):
python tools/validate_video.py --godot /path/to/Godot --continuation
```

The full suite needs NumPy, a GPU-capable Godot, FFmpeg and ffprobe. It checks
1080p30/60, custom timing, playback rate, 4K dimensions, locked/orbit cameras,
mapping/preset preservation, overlays, variable counts/schemas, deliberate delays,
missing/failed encoding, cancellation during rendering and encoding, successful
cleanup, paths with spaces, and native particle captures. Source hashes are
checked for unchanged bytes. The Godot UX suite also checks session screenshot
selection/cancellation/reuse/reset, trails defaults/toggling/allocation, and an
actual child render launched while the parent remains usable. Logs and clips are
under the chosen `--output-dir` (or a fresh temporary directory). The focused follow-up additionally
checks 1440p24, custom 640×480 at 17 FPS, actual enabled/disabled trail instances
and differing rendered pixels, normalization restoration, screenshot filename
uniqueness, publication conflicts, malformed paths and frame-count overflow.

The native Python regressions run with `python -m unittest discover -s tests`.
Run the screenshot/export suite with `python tools/validate_video.py --godot /path/to/godot --output-dir results/check-video`. Desktop access/app-data permissions are needed when launching
Godot from a sandbox. Exported executable packaging and non-Linux platforms have
not been acceptance-tested in this task.

## Screenshot and trail UX changes

The first Save PNG (P) action each application session asks for a directory.
Cancelling saves nothing and does not select a fallback. After selection, later
screenshots use that directory, with unique timestamped filenames and a visible
saved-path confirmation. The directory is never persisted to configuration.

Recorded History (T) starts disabled. Presets do not turn it on. Disabled trails
retain no history and allocate no trail instances; T and the checkbox still
explicitly enable them when persistent IDs are present. Anonymous captures disable
these controls. Scientific mode suppresses trails as before.

## v1.0.3 inspection extension

UI-launched jobs pin the source SHA-256/committed extent and use the shared
physical-time sampler and visual-state module. Duplicate/reverse timestamps
remain inspectable in index mode but cannot be physically interpolated/exported.
The optional per-frame inspection JSON checkbox writes reproducible state records
in the job directory. Records retain image hashes if successful PNG cleanup is
requested. Existing end-exclusive timing and version-1 job compatibility remain.
See [INSPECTION_STATE.md](INSPECTION_STATE.md) for the state and geometry contracts.

### Source changes during export (G2a)

A job still pins its committed extent and uses the existing end-exclusive timing.
An append completed before the worker opens the capture does not expand that
snapshot. If the source changes while the worker is rendering, validated generic
reads fail the job and retain completed PNGs. Restart from the current source or
export a stable copy. Inspection PNG/state capture also refuses a source/data
mismatch. Cache metadata never replaces the committed-prefix SHA-256 identity.
