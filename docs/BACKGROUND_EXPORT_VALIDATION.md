# VIDEO-001 — background GPU export validation

Issue #1 implementation; pending owner review. It was the sole Ready issue on
2026-09-19. No subsequent issue is included.

## Defect and change

The worker awaited the automatic `RenderingServer.frame_post_draw` signal for
each output frame. Godot can suppress that loop when its OS window is minimized.
An isolated copy of main (`0283e0d`) reproduced the problem: after minimizing at
frame 10, the count was still 10 three seconds later. The stalled test process
was terminated; its partial frames/progress remain in local test results.

The worker now disables its automatic render loop, yields for layout/events,
checks cancellation, and explicitly draws the export SubViewport with
`RenderingServer.force_draw(false, 1/fps)`. GPU readback completes before PNG
publication. Sample time and camera motion still derive from output frame index;
no window timing enters those calculations. The separate-process architecture,
GPU renderer, frame count, resolution and capture sampling are unchanged.

Godot rejects hiding its main window after startup. The worker instead requests
minimized mode, makes the window unfocusable and labels it **SimScope export
worker**. This suppresses the persistent black debug window without selecting the
dummy headless renderer. Startup flashes/taskbar presentation can depend on the
window manager. The main viewer remains responsible for progress and cancellation.
UI-launched jobs now retain `renderer.log`; failure to write a cancel request
reports the PID and job path rather than instructing users to close an inaccessible
window. Parent-close cancellation and FFmpeg cancellation paths are retained.

API reference: [Godot RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)
and [windowed application guidance](https://docs.godotengine.org/en/stable/tutorials/ui/creating_applications.html).
The installed Godot 4.7.2 runtime was used to verify behavior rather than relying
on documentation alone.

## Focused evidence

Environment: Linux KDE Wayland session, Godot **X11/XWayland** display driver,
NVIDIA RTX 3070 Ti; Forward+ Vulkan and Compatibility OpenGL.

- On **each renderer**, six 30-frame/640×360/30 fps/one-second MP4s completed:
  unmodified main reference, changed visible worker, minimize after frame 10,
  unfocus after frame 10, cover with another native window after frame 10, and
  production minimized/unfocusable configuration. Every corresponding PNG hash
  and complete timing manifest matched main exactly, including capture times,
  camera positions, sampling metadata and render settings. ffprobe verified
  dimensions, duration, frame count and rate.
- The minimized case recorded mode 1 from frame 11 through frame 30 and at
  completion (through encoding). The normal background configuration remained
  minimized and unfocusable. Native covering/unfocused windows caused verified
  focus loss and progress beyond frame 25. Cover geometry was requested to match
  the worker; desktop-level pixel occlusion was not independently captured.
- Both renderers cancelled the minimized background worker after ten frames,
  exited with the expected cancellation status/code and retained partial PNGs;
  neither published an MP4. Capture SHA-256 was unchanged across each matrix.
- Retained summaries: [Forward+](evidence/issue-1/forward.json),
  [Compatibility](evidence/issue-1/compatibility.json).
- Existing video continuation suite **PASS** on Forward+: **43 native UX checks**,
  including real UI process launch and completion/progress with the main viewer
  minimized; 1440p24, custom resolution/FPS, trails on/off, output cleanup,
  unchanged source bytes and expected malformed-path/frame-overflow refusals.
  Actual UI worker `renderer.log` exists and is clean.
- G4 selection-aware rendering **44 checks PASS** on Forward+: normal/delayed
  clips, exact membership/source/image hashes, time and position oracles, identical
  delayed pixels, and recipe-sidecar replay matching clip pixels. A rendered
  selection frame was visually inspected.
- Godot import generated the committed test UID. `git diff --check` passed.

Earlier attempts: direct main-window hiding failed at runtime and was removed;
a window-state assertion initially assumed synchronous compositor acknowledgment
and was corrected to check subsequent frames. The first minimized-main UX test
completed its MP4 but timed out awaiting an automatic draw during test teardown;
teardown now explicitly draws too. Final runs passed. The old implementation's
stall is expected reproduction evidence, not a passing export.

## Reproduction commands

Use the project Python environment, a native display, external Godot/FFmpeg, and
fresh output directories:

```sh
python tools/validate_video.py --godot /path/to/godot --output-dir results/video --renderer forward_plus --continuation
python tools/validate_background_export.py --godot /path/to/godot --fixture-dir results/video --output-dir results/background --renderer forward_plus --baseline-project /path/to/unmodified-main/viewer
python tools/validate_background_export.py --godot /path/to/godot --fixture-dir results/video --output-dir results/background-gl --renderer gl_compatibility --baseline-project /path/to/unmodified-main/viewer
python tools/validate_g4_render.py --godot /path/to/godot --output-dir results/selection-render --renderer forward_plus
```

Without `--baseline-project`, the window matrix compares against the changed
visible worker. The controlled worker subclass changes only window conditions;
it inherits production sampling, rendering, progress, encoding and cancellation.

## Limits and owner verification

Not run: native Wayland display driver, other operating systems/GPUs, KDE virtual
desktop switching, physical 4K/full video matrix, external simulations, full
G0–G4 suite, or cancellation specifically during FFmpeg encoding. The latter
code path is unchanged. Startup flash/taskbar behavior and complete desktop
occlusion need interactive owner verification. No claim of zero startup flash
or universal pixel identity across GPU drivers is made.

1. Export a short representative capture with at least 30 frames. Confirm the
   persistent black debug window is gone and the Export Video progress advances.
   Note any startup flash or unexpected taskbar/focus behavior.
2. After at least ten frames, minimize the main viewer and leave it minimized
   through rendering/encoding. Restore it; confirm successful MP4 completion.
3. If the worker is accessible via the window manager, restore/minimize it after
   ten frames and leave it minimized through encoding. Also test it unfocused,
   covered by another window, and on another KDE desktop where practical.
4. Compare against a normal export: frame count, duration, dimensions, sample
   timing and orbit path should match. Inspect the scientific appearance.
5. Cancel an active render, then a longer export during encoding. Confirm no
   final MP4 is published, partial artifacts remain, and worker/encoder exit.
   Verify the panel reports errors and the job directory retains diagnostics.

Stop for owner review. Implementation is not owner acceptance.
