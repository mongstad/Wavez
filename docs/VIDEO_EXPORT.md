# Wavez deterministic video export

## Source, inspection and selection ownership

Current video jobs require WVZ1 `.wvz` sources and `wavez-export-source`
identities. Ordinary jobs use version 1; selection-aware jobs use version 2 and
inspection recipe v3. Current code is in `viewer/video/` and `viewer/analysis/`;
see [analysis schemas](ANALYSIS_SCHEMAS.md) and
[the analysis guide](ANALYSIS_GUIDE.md#save-restore-and-export).

Selection-aware jobs pin the committed source prefix, exact selection members, sampling state
and highlight settings, then await sample/selection/surface barriers before each
frame. Later appends stay outside that prefix; mutation, replacement and truncation
refuse. PNG/state bundles and per-frame sidecars retain source IDs, units, native
clocks, held/interpolated support and image hashes. Matched runs prepare two
portable jobs with explicit time/value mappings and a comparison manifest; they
render sequentially and do not register or rescale geometry. Render and numerical
export quotas are finite. Export never measures values from GPU colors.

Historical measurements are linked as review records; they do not establish a
new renderer/platform guarantee. Network/control services remain outside scope.

## Using Export Video

Open a capture and set its appearance/camera, then choose **File → Export →
Video**. Settings are arranged in titled **Range**, **Video**, **Camera**,
**Presentation** and **Output** groups. Range **Mode** offers **Full**, current
position to end, or **Custom** in recorded capture-time units. Its **Start** and **End**
rows show whole-second playback clocks (`MM:SS`, or `HH:MM:SS` beyond an hour)
alongside whole-second numeric controls marked **s**, with one-second steps.
For example, Custom Start **30 s** / **00:30** and End **60 s** / **01:00** at
30 FPS and 1.0× give **Duration: 00:30 · 900 frames**.

Whole-second controls are a projection, separate from the exact float64 export
endpoints. Full/Current presets and existing Custom selections retain their
timestamps when opened, refreshed, focused, or accepted with unchanged Enter/Tab.
Fractional endpoints display the nearest whole second (ties toward the later
second), marked **≈**, and a visible **Exact range** line shows the interval that
will actually be exported. Tooltips also give the precise seconds. A range such
as `[30.0003, 60.0003)` still exports that exact interval; the controls show
**30 s** / **60 s**, clocks **≈00:30** / **≈01:00**, and the exact range is disclosed.

In Custom mode, arrow buttons shift the selected exact endpoint by one second,
retaining its fractional offset. Explicit keyboard edits choose an absolute
whole-second endpoint; fractional numeric input rounds to the nearest second
using the native control's rounding (ties toward the later second). Retyping a
whole number deliberately commits that number even when the displayed number was
already the same. An unchanged field never performs this normalization. Existing
bounds and end-before-start validation remain. Programmatic/restored ranges use
`set_range_times(first, last)` to retain exact endpoints within those bounds.
These are recorded source timestamps, including signed/offset clocks; playback's
elapsed clock remains relative to the first sample. The End tooltip explains
that the endpoint is exclusive and a still exports one frame. Select 1080p,
1440p, 4K, or even custom dimensions;
24/30/60 or custom integer FPS. **Playback rate** is simulation-time units
per second of exported video: lower values play more slowly and sample time
more closely, while higher values play faster. Its **×** suffix identifies a speed
multiplier. The numeric timing is unchanged.

The summary shows video duration and frame count, for example **Duration: 03:30 ·
6,300 frames** for 210 seconds at 30 FPS and 1×. Duration comes from the existing
frame count divided by FPS, including its final-frame convention. Fractional
durations display up to milliseconds; **≈** marks rounding, and the tooltip gives
the precise duration in seconds. Export processing time remains separate in job
status. Summary/frame calculations always use the exact endpoint model.
See [issue #323 precision refinement](evidence/issue-323/precision-refinement/README.md) for focused
source/package comparisons and owner-review limits.

Enabled volume legends include the applied opacity strength and ramp, or identify
opaque slices. The existing **Overlays** control gates those cards with the other
legends; see [volume legend opacity](VOLUME_LEGEND_OPACITY.md).

Choose current camera locked or orbit, current rendering state or a cinematic /
scientific override, overlays, trails, H.264 quality, and a new `.mp4` output path.
**Browse…** opens an MP4 save dialog with the current output filename, or a
capture-based `.mp4` suggestion on first use. The native desktop request offers
only **H.264 MP4**, preventing filename typing from selecting an All files
filter. Selecting an extensionless name appends `.mp4`; the chosen absolute
directory and filename populate **Output MP4**. Cancel leaves the previous
output untouched. Directory-only and relative picker returns are ignored;
manually entered invalid paths still receive the existing absolute-MP4 error.
The built-in fallback resets its MP4 filter on each Browse. Other file pickers
retain their existing behavior.

The lower **Export summary** shows video duration, exact output-frame count and
a compact **Temporary storage** estimate for uncompressed frames (actual PNG
size depends on image content). During a job or with retained job status it
becomes **Export status**. Long status text scrolls within that lower area,
while settings scroll independently. During normal rendering and after success,
the status omits the destination already shown under **Output MP4** and the
temporary directory. Failures, cancellation and FFmpeg-unavailable recovery
show the working directory; **Jobs → Video export → Details** retains both
paths for diagnosis. The source sample count and successful
FFmpeg discovery are not shown; missing FFmpeg still produces an actionable
error when Start Export is pressed.

Successful dialog exports remove temporary PNG frames after publishing the MP4.
Failure, cancellation and FFmpeg-unavailable states retain frames and other
intermediates for recovery. Ordinary exports can optionally save per-frame
inspection JSON from the collapsed **Advanced** section in Output. Selection-aware
version-2 exports always write these per-frame inspection records as provenance;
the optional control is hidden when selections are present. Those JSON records
remain in the job directory after successful PNG cleanup and retain the PNG
identity with `retained_after_encode:false`.
Click **Start Export**. A second Godot process renders and encodes the video.
The worker keeps a real GPU display connection but minimizes its noninteractive
window and makes it unfocusable. It no longer needs a visible debug window to
render. A brief startup window/taskbar entry may still depend on the platform.
The regular viewer stays usable and may be minimized. The primary button changes
from **Start Export** to **Cancel export** while the worker runs. Choosing it
opens **Cancel video export?**, with **Yes** and **No**; **No** receives initial
focus. Only **Yes** requests cancellation after the current frame, or stops
FFmpeg during encoding. **No**, Escape or closing the confirmation leaves the
export running. Jobs cancellation uses the same confirmation. Repeated clicks
do not send duplicate requests; completed jobs do not prompt. **Run in background** hides
the dialog and is visible only while an export is preparing or running. All
configuration controls remain visible but read-only during that time, including
output Browse and selection quotas. Reopening through File → Export → Video or
Jobs preserves the locked configuration. A late file-picker result cannot change
an active job's output path.

The dismiss-only **Cancel** button is hidden during active work. After success,
PNG-only completion, failure or acknowledged cancellation, **Start Export** and
**Cancel** are available again and **Run in background** is hidden. Settings regain
their previous editability: preset dimensions/FPS and automatic range endpoints
remain read-only until their corresponding Custom mode is selected. The two
secondary actions occupy the same position/width to limit layout movement.
**Cancel** dismisses the idle/terminal dialog only; it never cancels the job.

During selection-recipe preparation, confirmed **Cancel export** requests cancellation of
the existing background analysis job before any renderer is launched. Controls
remain locked until preparation ends or the worker exits; a terminal-looking
progress message alone does not release an active worker's configuration. Closing
the parent viewer still requests cancellation through the existing protocol.
See [the #125 validation and owner checks](VIDEO_EXPORT_LOCKS.md) and
[confirmation validation](VIDEO_CANCEL_CONFIRMATION.md).
The job directory retains `progress.json`,
`renderer.log` (UI-launched workers) and `ffmpeg.log` for diagnosis. If writing the
cancel request fails, the dialog reports the worker PID and retained job path.

**Jobs → Video export → Details** and the export dialog share one progress
calculation, for example `Rendering frame 3000 / 12000 (25%)`. The integer percentage
uses the actual rendered frame count. Separate **Elapsed** and **Estimated
remaining** lines use `hh:mm:ss`; elapsed advances between worker updates.
The approximate remaining time uses completed-frame snapshots, with recent
seconds-per-frame observations smoothed over a five-second time window. The
shared dialog/Details estimate refreshes at most twice per second and keeps the
same text when the displayed whole-second value is unchanged; it does not rise
between identical worker snapshots. Frame counts and live elapsed retain their
existing refresh behavior. The estimate covers rendering only, not encoding,
and appears after at least two frames and one observed second. New jobs reset
the estimate; stage transitions clear it immediately. This presentation uses
existing refresh calls, with no additional timer or worker polling. See
[ETA validation and owner checks](VIDEO_ETA.md). A gap longer than the greater of ten seconds or three observed
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

The worker uses the same scene reader and scientific state with offline timing.
Interactive playback/preparation and realtime camera motion are disabled in the
render instance. The output SubViewport owns the requested image dimensions.

The installed engine is Godot **4.7.2-stable**, hash
`ed1daf0bf001b61586d9930840f2f1394092c079`. Its CLI supports `--write-movie` and
`--fixed-fps`. A real Movie Maker probe wrote exactly two 96×64 PNG frames at
30 FPS (with accompanying WAV). Runtime settings also expose OGV encoding
controls. PNG capability was exercised; OGV was not used for this feature.

Godot documents Movie Maker as a startup mode and supports PNG sequences as well
as movie containers. Its automatic writer captures viewport frames, including
startup iterations. For Wavez's explicit load/index/sample/save lifecycle,
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

Normal Godot startup recognizes `--wavez-render-job=...` and dispatches to the
worker before building an interactive scene. Jobs serialize capture path/range,
frame bounds, output FPS/rate/size/path, camera transform/projection/target,
orbit, preset, particle appearance, mappings, normalization, filters, trails,
overlay/section state, environment properties and viewport quality settings.
No physics runs; capture access is read-only. Indexing freezes the available
complete frames for that job instead of live-tailing the capture.

For standalone Linux release builds, use the [packaged video guide](PACKAGED_VIDEO_EXPORT.md).
The parent starts its own executable without a project-path override. Selection-aware
exports use Wavez-owned Python resources packaged by `tools/package_linux.py`;
Python/NumPy and FFmpeg remain external. Each UI launch retains `launch.json`,
and worker metrics record the actual executable, renderer and user arguments.

## Offline sampling and validation

[The #116 audit and validation](VIDEO_REGRESSION.md) records its historical
development-checkout baseline. [Linux package evidence](PACKAGED_VIDEO_EXPORT.md)
covers its later launch/resource paths; neither report is a new test run here.

The worker resolves the source sample/schema at the requested export start before
restoring appearance. A particle or field channel introduced later in a capture
therefore remains selectable for a segment starting there. A visible layer that
fails display preparation (for example, mesh GPU budget or float32 field display
range) fails the export with its layer/time/reason instead of publishing a video
with that layer missing. Completed intermediates remain available for diagnosis.

Offline readers retain strict payload checks for records they read. The worker
uses the current synchronous scene sampler and bounded decoded cache; interactive
preparation workers and startup gates are disabled. This does not prepare the
whole capture or change its bytes, clocks, channel precision or cache architecture.
Explicit whole-capture verification remains `python tools/verify_wvz.py CAPTURE.wvz`.

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
The dialog initializes it from the current positive playback speed, or 1×
when the viewer is paused at zero speed or playing in reverse. “Current position
to end” starts at the committed scene time, including mixed scenes whose particle,
field and mesh clocks differ; an uncommitted seek target is not exported.

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
quality settings are reused. The **Video Export dialog** selects the rendering
state: Current state retains its applicable live presentation; Cinematic and
Scientific apply their defined export presets. Its range, rate, camera/orbit,
resolution, FPS, trails, quality and temporary-output settings remain job
settings. The viewport defines which content can enter the frame; it does not
replace those selections with the current interactive viewer state.
When the selected state includes the Cinematic sky, its gradient remains fixed
to the output frame as the export camera orbits. See the
[cinematic background guide](CINEMATIC_BACKGROUND.md).

The offline SubViewport now contains scientific scene content and eligible
viewport legends only. **Include enabled viewport legends** gates particle,
field and mesh legends according to their saved visibility and channel state;
turning it off hides those legends even if the interactive viewer shows them.
Independent scene guides, probe markers and selection annotations retain their
own settings. The exported legends use the existing viewport text and color
mapping, positioned against the full output frame. See [Layer legends](LAYER_LEGENDS.md).

Menus, navigation controls, the right workspace dock, transport, timeline,
status/Jobs, dialogs, desktop decorations and other application chrome remain
outside the video on both overlay settings. Workspace, scroll and remaining-time
preferences may still be present in an existing job record, but do not affect
frame pixels. The existing 1440-wide logical canvas scales to the selected
output dimensions while 3D renders at native resolution. Matching output
aspect ratio preserves framing; a different aspect ratio follows the camera's
keep-aspect setting. [Issue #55's overlay evidence](evidence/issue-55/README.md)
records the earlier production-shell composition and remains historical. See
the [current viewport export evidence and owner checks](VIDEO_VIEWPORT_EXPORT.md).

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

Each export creates a unique hidden `.wavez-export-…` directory **beside the
selected MP4** so frame storage and final publication share the output filesystem:

```text
job.json                 complete reproducible job description
launch.json              UI launch executable, arguments and renderer
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
godot --path /absolute/path/Wavez/viewer --resolution 640x360 \
  --fixed-fps 30 --disable-vsync --audio-driver Dummy -- \
  --wavez-render-job='/absolute/path/.wavez-export-ID/job.json'
```

A retained job can be copied into a new directory and edited for automation; use
a fresh output filename and empty frame directory. Preserve its recorded job version and source identity fields; selection-aware
jobs require their version-2 fields. Do not add `--write-movie` to this worker command: it would record the small process
window and setup iterations, not the export SubViewport.

For comparison, the installed Movie Maker PNG probe used:

```bash
godot --path /tmp/wavez-movie-probe --script probe.gd \
  --resolution 96x64 --write-movie probe.png --fixed-fps 30 --quit-after 2
```

Run focused rendered checks from the repository root:

```bash
python tools/validate_video.py --godot /path/to/Godot
# Extended continuation coverage, only when the changed export path requires it:
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
Godot from a sandbox. See [the Linux package guide](PACKAGED_VIDEO_EXPORT.md) for packaged launch checks.
Other OSes require separate validation; historical tests do not certify them.

## Image and recorded history ownership

[Save Image](IMAGE_EXPORT.md) describes the current composition and configured
Image Exports/session-folder ownership. It is separate from the offline video
range, resolution and output settings.

Recorded History starts disabled. Presets do not turn it on. Disabled history
allocates no trail instances; the configured shortcut and checkbox enable it
explicitly when persistent IDs are present. Anonymous captures disable these
controls. Scientific mode suppresses trails. No trail inference creates IDs.

## Ordinary job inspection and source binding

Ordinary UI-launched jobs bind local source identity and committed extent (see
below), and use the shared
physical-time sampler and visual-state module. Duplicate/reverse timestamps
remain inspectable in index mode but cannot be physically interpolated/exported.
The optional per-frame inspection JSON checkbox writes reproducible state records
in the job directory. Records retain image hashes if successful PNG cleanup is
requested. Existing end-exclusive timing and version-1 job compatibility remain.
See [INSPECTION_STATE.md](../INSPECTION_STATE.md) for the state and geometry contracts.

### Source changes during export

Ordinary exports bind WVZ1/version, scene UUID, metadata SHA-256, the ordered
80-byte record-header fingerprint, indexed committed extent/record/frame counts,
and the existing local filesystem stamp (device, inode, size, nanosecond mtime and
ctime). Path is only a locator. Startup never reads/hashes the complete payload
prefix. Stamps are checked before and after identity generation, on worker open,
around every requested sample, after readback, during encoding and before MP4
publication. Any change, including append or equal-size replacement, refuses the
ordinary job; restart from the current source. There is no persistent trust store.
The accepted reliable stamp implementation currently supports Linux local
btrfs/ext2/ext3/ext4/xfs/tmpfs/overlayfs via `/usr/bin/stat`. Unsupported/coarse
stamps fail explicitly, rather than falling back to a slow whole-file hash or
path-only identity. This is a current platform limitation.

This identity is a mutation binding, **not** a whole-capture integrity certificate.
Every record actually decoded offline still validates descriptors, commit proofs,
bounds, codecs, structure, stored-chunk and decoded-chunk SHA-256. Unused corrupt
payloads need not block an unrelated clip. Use `tools/verify_wvz.py` explicitly to
verify all records. Normal video inspection sidecars reuse the same local binding;
restore requires that same unchanged source inode. They are not portable
whole-source certificates. Explicit portable inspection/selection recipes retain
their content-hash contract and pinned append semantics. Their existing analysis
verification can still be long; the renderer no longer duplicates that hash before
asking the portable validator to verify the recipe. Explicit SHA-bound jobs use a
chunked cancellable verifier.

Cancellation is checked during indexing, between record decode chunks and
particle-ID batches, between explicit prefix-hash chunks, and at rendering/encoding
boundaries. Individual codec/hash calls, field preparation, draw/readback and PNG
writes remain bounded synchronous operations. Parent-close requests the same
worker cancellation. `metrics.json` separates snapshot/worker identity, opening,
sampling, readback, PNG and encoding timings. `WAVEZ_VIDEO_PROFILE=1` adds bounded
strict-read/I/O/hash/decode counters; those nested timings overlap sampling/opening.
See [the startup regression evidence](VIDEO_STARTUP_116.md).
