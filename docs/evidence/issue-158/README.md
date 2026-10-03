# Issue #158 — continuous native resize

Build 28 is proposed for owner review. This investigation used KDE/Wayland on
the production desktop with Godot 4.7.2, an NVIDIA RTX 3070 Ti, Forward+ and
Compatibility. The supplied 411 MB
`cavity_collapse_torus_240s.ssc` stayed outside the repository. A separate
owner-operated trace used the 4.09 GB `cavity_collapse_torus_channels_240s.ssc`.
The source and generated test captures were opened read-only.

## Diagnosis

The owner operated the real viewer during capture playback, reaching 7,205
native size changes across 24 active seconds (peak 740/s). The longest
main-thread callback gap was 224 ms. The visible clock advanced and no sampled
row reported buffering or a scene error. Whole-device VRAM briefly reached
6,548 MiB; this is not a per-process or render-target allocation trace.

The owner then dragged a fresh empty viewer **before the changes below were
loaded**. It received 1,210 native size changes over three seconds (peak
562/s), with an 81 ms maximum callback gap. The owner reported that it felt
fine. Neither physical pass reproduced the originally reported 10–15 second
freeze, so the owner's perceived improvement cannot be attributed to this PR.

The traces identified two application costs under the native event flood:

- Empty startup retained `playing = true` without a capture. It ran the viewer
  without low-processor pacing. The transport also refreshed unchanged controls
  on every frame, forcing about 145 3D draws/s at rest. An isolation run showed
  that disabling only the transport's process callback reduced idle draws from
  146 to zero while leaving the viewer active. Godot's
  [low-processor mode documentation](https://docs.godotengine.org/en/stable/tutorials/ui/creating_applications.html)
  explains why its default 6,900 µs sleep interval can still allow roughly
  145 draws/s when a control keeps requesting redraws.
- Native `size_changed` invoked shell layout once per event, and the chrome
  refreshed separately. A 740-event second spent about 93 ms in shell layout
  (each call at most about 0.2 ms). This is avoidable work, though it does not
  itself explain a multi-second stall. No layout/minimum-size feedback loop was
  found in the controlled runs. The remaining resize pressure includes engine
  and compositor work outside the profiled shell; the GPU resource source of
  the VRAM spikes was not identified conclusively.

## Changes

- Empty startup now uses low-processor pacing when no capture is open. Auto
  Orbit remains animated at its existing 60 FPS cap; loaded playback retains
  its existing pacing.
- The transport stops polling its unchanged controls while there is no source.
  Source opening resumes normal updates. In a real Forward+ and Compatibility
  window, settled empty draws changed from about 145/s to **0/s**; Auto Orbit
  drew 60/s and returned to 0/s when stopped.
- Native size notifications and transport minimum-size notifications request
  one deferred shell layout for the latest viewport size. Immediate layout
  remains for direct panel actions. The shell's layout updates chrome grips and
  icons, removing the second per-event chrome refresh. The last drag size is
  always applied.
- Opt-in native telemetry and a PID-scoped KWin harness record event rates,
  layout cost, frame gaps, process/GPU load and post-resize scientific state.
  They do not change normal viewer behavior.

## Validation

The [compact measurements](summary.json) retain the per-phase native, layout,
draw, clock, camera/source and packaged-check results without copying raw
capture data or desktop logs into the repository.

| Case | Native sizes | Shell layouts | Draws | Longest callback gap |
| --- | ---: | ---: | ---: | ---: |
| Forward+ empty, top-right diagonal, 3 s | 1,046 | 253 | 252 | 22 ms |
| Forward+ paused, supplied torus, 3 s | 1,042 | 215 | 215 | 26 ms |
| Forward+ playing, supplied torus, 3 s | 1,044 | 42 | 42 | 120 ms |
| Compatibility empty, top-right diagonal, 3 s | 1,042 | 426 | 426 | 12 ms |
| Compatibility paused, supplied torus, 3 s | 1,045 | 425 | 424 | 19 ms |
| Compatibility playing, supplied torus, 3 s | 1,040 | 53 | 53 | 79 ms |

The automated corner gesture begins slowly, then accelerates and oscillates
horizontally and vertically. Its native resize initiation reported the
top-right edge and both dimensions changed. Forward+ torus playback advanced
from 4.86 s at drag end to 9.08 s afterward; Compatibility advanced from
4.78 s to 8.97 s. Neither reported a scene error or post-resize buffering.
Subsequent seek committed, source record count and camera target/radius stayed
unchanged. A generated multi-channel scene additionally completed channel
switching and preparation after resizing; the supplied 411 MB torus has no
alternate selectable color channel. SHA-256 of every tested `.ssc` was
unchanged.

- Focused pacing/layout test: 8 checks on both headless renderers. Its empty
  pacing checks failed on the original branch code and pass with this change.
- Real-window idle render test: 4 checks per renderer; draws were 0, 60, 0
  across empty, Auto Orbit, and empty again.
- Near minimum: actual top-right drag reached 970×600, 34 native size changes,
  12 ms maximum gap. A scripted 3840×2160 diagonal size run had 201 native
  changes and an 18 ms maximum gap. The 4K geometry was requested through KWin;
  this was not a physical 4K monitor drag.
- Optional X11/XWayland empty-viewer comparison: 201 scripted size changes,
  66 ms maximum gap.
- Native chrome: 76 checks and 18 KWin stages passed on both renderers,
  including maximize/restore, minimize/restore, fullscreen and close.
- Viewer shell: 659 checks passed on both renderers. The wrapper's stale
  `About WAVEZ` menu expectation was corrected to the accepted `About` label;
  the mismatch also exists on accepted `main` and was unrelated to resizing.
- Final temporary packaged Linux exports passed 44 empty/loaded visual checks
  per renderer; both recorded 0 idle draws in the empty scene. A normal
  packaged Forward+ startup with the default `playing = true` likewise
  reported no capture, low-processor mode on, and 0 draws in settled seconds.

The synthetic fixture and supplied capture checks do not replace the required
hands-on owner review. The owner should repeat fast top-right diagonal drags
with an empty viewer, a paused run, and active playback, then verify the
desktop remains responsive and playback, seek and channel switching recover.
Observe a real 4K display if available. This PR remains open for that review.
