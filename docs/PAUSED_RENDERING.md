# Paused rendering — issue #118

Implementation and validation are **pending owner review**. #118 was the only
Ready item when selected. The existing owner-linked branch starts at `0b3d3b4`,
the accepted PR #113 merge. Historical preparation reports retain their original
review-time wording.

## Cause and rendering policy

The accepted viewer continuously renders paused scenes. On this 144 Hz display,
VSync was enabled, `Engine.max_fps` was zero, and even a stationary, pixel-identical
scene rendered about 144 times per second. There were no repeated field uploads
in the stable paused phases. Current-plus-one staging was bounded; becoming ready
did not trigger an upload or synchronization loop.

The owner's paused Auto orbit intentionally changes the camera. In the matched
close-up Forward+ baseline it consumed 85.0% whole-device GPU at 143.9 rendered
FPS. Pressing Play reduced rendering to 63.6 FPS and GPU utilization to 43.1%.
Mean main-thread processing rose from 1.34 to 12.79 ms per callback: the 20-second
playback phase included 598 particle interpolation/submission updates and 199
field texture uploads. Interpolation averaged 8.54 ms and field uploads 11.07 ms.
Playback supplied fewer frames to the GPU. Pausing again restored 143.9 FPS and
79.0% GPU. This reproduces the high paused load and drop on Play; it does not
reproduce the owner's exact 66%-to-100% preparation transition.

The implementation addresses both stationary and intentionally moving pauses:

- An unchanged paused view uses Godot's redraw-on-change mode. Input, workers,
  source-tail polling and UI callbacks continue. Seeks, camera movement, channel
  changes, window resizing and visible UI changes still draw.
- Paused Auto orbit renders at at most 60 FPS, respecting a lower supplied cap.
  Orbit angle still advances by elapsed time. Play restores the original cap.
- Free camera no longer submits a camera transform when no movement key is held;
  zero-speed Auto orbit likewise avoids unchanged transforms.
- The field preparation label builds its final text before assigning it. Its
  former intermediate strings invalidated the visible Performance dialog every
  callback even after preparation completed.

The policy uses
[`OS.low_processor_usage_mode`](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-property-low-processor-usage-mode).
It preserves the supplied low-processor setting, VSync and the configured sleep
interval. Interactive teardown restores the previous engine policy and cap.
Offline instances do not install the policy; deterministic export still draws
its frames explicitly. There are no shader, scientific sample, field resolution,
particle/mesh data, cache admission, integrity or recorded-time changes.

## Measurement conditions

Godot 4.7.2, Linux/X11 on KDE Wayland, Ryzen 7 5800X, RTX 3070 Ti, NVIDIA 615.71.09,
2560×1440 display at 143.91 Hz. Requested window 2546×1386; the window manager
constrained its actual viewport to 2546×1362. Cinematic, point rendering off,
all 50,000 particles colored by `color_value` using viridis and automatic
per-frame range; field `psi_imag`, linear color 0–1, magnitude opacity 0–1,
strength 0.25, ray step 0.5. Zoom is 0.15 of Frame scene distance (23.1575 units),
chosen to reproduce the close-up screenshot, not an exact recovered owner camera.

The read-only external source is `SIMSCP4_D192_T200_simscope.ssc`,
125,950,754,101 bytes, 1,566 full-resolution 192³ three-channel field samples,
627 particle samples, recorded time 0–156.5. Automatic preparation becomes ready
for its admitted RAM window; that is not preparation of the entire file.
The immutable baseline is a `git archive` of accepted `0b3d3b4`, not another
implementation branch. All production profiles run serially using the viewer's
real callbacks. There are no manual ticks or forced draws in measured phases.

GPU utilization/power/clocks are whole-device NVIDIA samples, including the
desktop. CPU 100% means one core. The first two seconds of each phase's GPU
readings are excluded to separate driver sampling windows. OS file cache,
desktop activity and memory admission are not controlled. Baseline pauses last
30 seconds; candidate pauses last 60. Moving phases cover different angles and
the full-playback phase spans different data from a 20-second baseline. These
measurements establish the pacing cause, not a universal percentage or frame-time
guarantee. Godot rendered-frame counts are not independent display scanout or
GPU timestamp measurements.

## Validation

Forward+ production validation completed with **46 checks, zero failures**.
Both stationary holds rendered zero frames for 60 s while about 145 callbacks/s
continued, with byte-identical images and unchanged sample/camera state. Every
paused orbit hold ran at 60 FPS without field uploads, including after full
playback, a distant seek and all three channel changes. GPU staging never
exceeded one future texture. Full playback displayed all 1,566 field samples,
reached time 156.5 in 156.58 wall seconds and had zero field/particle buffering
events. The 1,564 playback uploads follow the initial current-plus-one pair.
The normal uncapped playback policy was restored; the full run averaged 59.38
rendered FPS. Its main-thread p95 was 40.04 ms and maximum 200.51 ms, so this is
not a strict 33.3 ms pacing guarantee.

| Forward+ phase | Baseline FPS / GPU / power | Candidate FPS / GPU / power |
|---|---|---|
| Preparation while orbiting | 143.2 / 84.4% / 277.9 W | 59.8 / 38.4% / 136.2 W |
| Paused-ready orbit | 143.9 / 85.0% / 277.4 W | 60.0 / 38.2% / 141.4 W |
| Stationary ready | 143.9 / 83.2% / 278.1 W | 0.0 / 22.5% / 27.0 W |
| Playback (20 s baseline; full candidate) | 63.6 / 43.1% / 170.2 W | 59.4 / 37.4% / 141.3 W |
| Paused again, orbit | 143.9 / 79.0% / 269.0 W | 60.0 / 38.2% / 120.7 W |

The candidate's remaining paused orbit phases averaged 37.9–38.7% GPU; the final
stationary hold averaged 22.0% and 20.1 W. Peak process RSS was 35.01 GiB and
process swap stayed zero throughout this final Forward+ run. Strict Python reads
matched all three channel byte hashes at five selected field checkpoints; each
native preview used LOD 1. The complete source SHA-256 matched before and after:
`c782dcd65ffa6bf8a2e6b548e051a3f258b331802fcd18d3b63042f6763d6e24`.
Whole-file byte invariance and selected scientific oracles are separate claims;
this was not a new all-record payload-integrity verification scan.

Compatibility production validation completed with **45 checks, zero failures**,
five strict selected field checkpoints, unchanged source stat identity and zero
process swap. It repeated every 60-second pause, seek and channel check; its
playback comparison used 20 seconds rather than the full recording. Both
stationary phases again rendered zero frames with identical pixels. Paused
orbit stayed at 60 FPS with zero uploads; playback had zero field/particle
buffering. Peak process RSS was 34.48 GiB.

| Compatibility phase | Baseline FPS / GPU / power | Candidate FPS / GPU / power |
|---|---|---|
| Preparation while orbiting | 142.6 / 75.7% / 246.7 W | 59.9 / 38.1% / 121.8 W |
| Paused-ready orbit | 143.8 / 74.9% / 249.4 W | 60.0 / 37.7% / 114.1 W |
| Stationary ready | 143.8 / 74.7% / 247.9 W | 0.0 / 26.2% / 25.3 W |
| Playback, 20 s | 50.1 / 32.4% / 135.8 W | 57.7 / 41.2% / 146.6 W |
| Paused again, orbit | 143.8 / 70.0% / 242.6 W | 60.0 / 39.2% / 111.3 W |

[Compact production evidence](evidence/issue-118/rendering.json) retains clocks,
CPU/RSS/swap, callback rates, preparation/cache state, upload counts, scientific
hashes and timing distributions. Very short drain phases are not steady-state
FPS measurements. Percentiles use up to the first 8,192 instrumented callbacks;
means/counts/maxima cover the phase. Hardware, renderer and desktop differences
prevent universal GPU percentages or cross-renderer pixel-equality claims.

[Focused regressions](evidence/issue-118/regressions.json) passed **20,263 checks,
zero failures**, plus both one-frame exports. Documentation validation passed
119 Markdown files with no broken local links and all three executable API
examples. Both new Python tools compiled, and `git diff --check` passed.

| Check | Forward+ | Compatibility | Headless |
|---|---:|---:|---:|
| New native rendering policy and interactions | 290 | 290 | — |
| Camera tumble, motion, zoom and state | 13,044 | — | — |
| Layer legends | 37 + two one-frame MP4 exports | — | — |
| Persistent transport | 204 | — | — |
| Full-resolution 192³ field budget | 56 | 56 | — |
| Field sessions, cancellation and exact source/display planes | 342 | 332 | 330 |
| Preparation concurrency | — | — | 94 |
| Scene playback | — | — | 2,457 |
| Mesh playback | — | — | 2,731 |

The new regression covers particles, fields, meshes and mixed scenes; paused
open/play/seek/channel changes; drag/resize/legends/Performance; Free camera;
zero-speed orbit; elapsed-time orbit speed; lower supplied caps; teardown and
offline-policy isolation. It compares retained pixels with an explicit fresh
full-quality draw outside the measured idle interval. Synthetic capture hashes
remain unchanged. The export checks include overlays on/off and distinct output
hashes, not a comprehensive offline export audit. Existing field-session checks
use exact GPU texture readback on Forward+ only: Godot 4.7.2 Compatibility
readback quantizes/clips float 3D textures, so that backend uses exact CPU/prepared
plane oracles instead. Other GPUs/OSes, independent GPU timestamps and exhaustive
fullscreen/minimize combinations were not tested.

## Failed and superseded trials

- The first production profiler had an invalid GDScript type expression; it was
  repaired before measurement. A repeat ended before its completion marker while
  a separate owner reproduction viewer occupied about 35 GiB. It is excluded.
  The wrapper now refuses incomplete runs. Large benchmarks remained on hold
  until the owner closed that viewer and authorized resumption.
- Early close-up runs assigned particle color data without updating its shader
  mode. They still demonstrated the draw-rate cause, but are excluded from the
  matched owner-settings comparison. The corrected script uses the actual color
  selection path and records `particle_scalar_shader=true`.
- The first synthetic mesh fixture omitted stable vertex IDs; it was corrected
  before native testing. The native regression then exposed continuous redraws
  from the field Performance label and stationary Free camera; both were fixed.
  A single non-continuous Performance UI refresh also invalidated an overly strict
  whole-UI pixel assertion. The test allows occasional live diagnostic updates
  while still requiring bounded redraws, unchanged scene/camera state and exact
  equality between the retained image and a forced full-quality draw.
- A superseded baseline at zoom 0.4 reached about 1.48 GiB process swap during
  playback. Cache/memory policy is outside this change and remains unchanged;
  this work does not establish swap-free behavior for every capture or machine.

## Reproduction

```sh
python tools/profile_paused_rendering.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /fresh/paused-forward \
  --resolution 2546x1386 --orbit --owner-settings --zoom .15 \
  --seconds 60 --actions --full-playback --hash-source
# --viewer-dir accepts an imported snapshot of the accepted baseline.
# --disable-vsync is an explicit uncapped diagnostic, not the production default.
python tools/validate_render_pacing.py --godot /absolute/path/godot \
  --output-dir /fresh/pacing-forward
```

Run one production viewer at a time. Use fresh output directories. The profile
records preparation/staging, main-thread timings, rendered frames, callback rate,
source/channel state, paused image hashes and Linux/NVIDIA telemetry. Source file
stat identity is checked before/after every run. `--hash-source` adds whole-file
SHA-256 before and after the native run, outside measured phases. Strict Python
reads independently check selected field timestamps and all channel bytes.

## Owner verification before acceptance

1. Open the same production capture on this branch. Use the reported field and
   particle settings above, your usual maximized/fullscreen size and close zoom.
   Leave playback paused with Auto orbit on through preparation, then for 60 s.
   Confirm smooth orbit at its original speed and substantially reduced GPU load.
2. Turn Auto orbit off, wait 60 s and confirm a stable image with settled GPU load.
   Move/zoom the camera, use stationary Free camera and set orbit speed to zero.
   Open Performance and confirm its status remains correct without restoring
   continuous idle rendering. Check legends, menus and window resizing.
3. Play at 1×, pause again, seek to a distant time and wait for readiness. Switch
   `density`, `psi_real`, `psi_imag`, waiting at each paused-ready state. Check
   source/time labels, colors, opacity and responsiveness. Repeat on Compatibility
   and a particles-only/mesh scene if part of your normal workflow.

Owner acceptance, merging, branch deletion and Project completion remain with
the owner. Automated validation is not owner acceptance.
