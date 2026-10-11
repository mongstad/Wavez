# Issue #382 — recorded-end GPU workload

Candidate **v0.1.0.102**, pending owner review, on the owner's exact linked branch
`382-bug-perf-gpu-investigate-rising-gpu-utilization-after-playback-reaches-end`.
#382 was the sole Ready item. Accepted baseline is build 101 / owner-merged PR
#381 (`9ddab596e19b93f1598e8314427b03114741f4fc`). Its tree matches the reviewed
PR #381 head `065ea5253d98a8426017d2fdbbb6598e8153affa` exactly. Fetch/prune,
previous branch cleanup and accepted-main synchronization were verified before
implementation. The initial checkout was `main`; work stopped under the user's
branch rule until the owner switched to the linked branch. No replacement branch,
main implementation commit, owner acceptance, merge or Project transition is claimed.

## Established cause and targeted correction

Ordinary, non-looping playback clamps at the final recorded timestamp while Play
remains active. It previously continued sampling/submitting that exact endpoint
at the display cadence, and `playing` kept normal continuous render pacing active.
The advanced field-interval path has its own existing automatic Pause transition.
The ordinary held edge also supports following a growing capture, so replacing it
with unconditional Pause would change accepted behavior.

The fix recognizes an **already committed, non-buffering recorded boundary**.
It skips redundant display sampling there and applies the same redraw-on-change
policy as manual pause. Source polling, worker pumps, UI/input, manual navigation
and orbit remain active. Play stays active; appended data, reverse and Loop can
restore progression. Advanced selected intervals and offline workers are excluded.
Scientific timestamps/arrays, field resolution, shaders/ray step, postprocessing,
particle/field/mesh preparation and the #377 RAM/runway policy are unchanged.

The implementation is limited to `scene_layers.gd` and the main pacing predicate.
#377 changed neither of those pacing/terminal paths: `git diff 096670d 9ddab59 --
viewer/main.gd viewer/layers/scene_layers.gd` is empty. The reviewed #381 candidate
and current accepted main have the same tree. This establishes that the redundant
endpoint path predates #377; a separate production replay of pre-#377 main was not
run after the owner asked to resolve the established bug without expanding the
investigation.

## Matched real-callback comparison

Existing read-only capture:
`/home/Nozba/Downloads/VB_FreeCollapse_v0_2/runs_free_collapse_v0_2/S0_20261004_013659_785112/free_collapse.wvz`
54,283,866,848 bytes; 0–74.5 source seconds, 150 particle and 746 field samples.
Godot 4.7.2 / Linux / Forward+ Vulkan / RTX 3070 Ti / 46.94 GiB physical RAM,
1920×1080 viewport, VSync enabled, initial Frame Scene camera, orbit off, default
field density ray march enabled, **ray step 0.25**, default color/opacity/quality,
Automatic preparation/concurrency/RAM, 1x, Loop off. Both roots use the same profiling
script and isolated writable settings, in separate sequential processes.

The real `main.gd` callbacks run normally. No manual playback ticks, forced draws,
artificial RAM competition, GPU filters or scientific reruns occur in measurement.
After paused preparation settles, the profile plays the entire recording, observes
**120 seconds** after committed end, manually pauses at the same timestamp, reverses
for three seconds, scrubs to the middle, runs five seconds of Auto Orbit, then closes
the capture and observes 20 seconds. Whole-device NVIDIA utilization/power/clocks
are sampled roughly twice per second; the first two seconds of each phase are
excluded from summary GPU statistics. Godot per-viewport GPU/CPU render timing and
actual draw counts distinguish application rendering from desktop GPU activity.

Exact measurements, limits and final validation are in [summary](summary.json).
Raw paths/hashes are in [manifest](raw-manifest.json). The accepted runtime is an
immutable `git archive` outside Git; its sources were not changed by the fix.

The baseline held 74.5 seconds with `playing=true` at **143.85 draws/second** for
both idle minutes. Manual pause at the same time produced **zero draws**, the same
particle MultiMesh byte hash, and the same **745 field uploads**. During the entire
natural-end hold, field uploads, particle completions (167), texture bytes
(176,552,960) and GPU buffer bytes (32,580,148) remained constant. This is redundant
rendering of a stable endpoint, not observed growing GPU resources or continuing
field uploads. The baseline end frame's viewport GPU cost was about 2.2 ms per
rendered frame; performing it at roughly 144 Hz kept unnecessary GPU work active.

| Observation | Accepted build 101 | Candidate build 102 |
| --- | ---: | ---: |
| Paused scene / field lead | 16.5 / 27.9 s | 16.5 / 27.9 s |
| Full 74.5-second traversal wall time | 74.764 s | 86.822 s |
| Natural-end hold | 120 s | 120 s |
| Natural-end draw rate | 143.85 FPS | 0 FPS |
| Draws across sampled stationary end hold | continuous | 0 |
| Natural-end whole-device GPU, mean / range | 38.36% / 29–48% | 32.26% / 15–65% |
| Same-end manual pause draw rate / GPU mean | 0 FPS / 18.17% | 0 FPS / 31.71% |
| Closed-capture draw rate / GPU mean | 0 FPS / 21.34% | 0 FPS / 32.94% |
| Auto Orbit at held/paused source | 60 FPS | 60 FPS |
| Peak process RSS (VmHWM) | 32.75 GiB | 32.77 GiB |
| Swap during playback / natural-end hold | 0 | 0 |
| Peak observed swap later in scrub/orbit/close | 0 | about 103 MiB |

Both committed exact 74.5 seconds, kept field uploads fixed at 745 through the
end hold, and had the **same** terminal particle-buffer SHA-256
`814d52aba2b42182106f6ef50202722a76d52e39e86441cbdb0fd7e9b7969740`.
Both reverse/scrub/close actions completed. Candidate natural end had no new draw
or render-time samples for the held presentation; a zero-sample interval is not
reported as a measured zero-millisecond GPU frame.

**Playback comparison limit:** the candidate had one field-refill wait near source
time 54.79 (roughly 12 sampled seconds); the baseline had none. Available physical
memory, worker concurrency and desktop activity differed, and late candidate
phases also encountered process swap. The hold is recorded rather than claiming
identical or uninterrupted production throughput. The new hold branch only runs
at an already committed recorded edge; active playback remains continuously paced.
The measured initial #377 runway and memory policy are unchanged, with deterministic
runway/scientific/transport regressions checked separately. These single uncontrolled
runs cannot establish a statistical playback-performance comparison.

The application-specific result is removal of redundant end draws/submissions.
Whole-device utilization stays close to the candidate's own paused baseline
(30.60%) and manual pause (31.71%), and does **not** fall further after closing an
already non-drawing scene. This ambient device activity is explicitly separated
from Wavez's zero recorded draws/uploads; no process-only GPU percentage is claimed.

The owner's exact gradual rise to 94–100% was **not reproduced**. Baseline natural
end averaged **38.36% whole-device GPU** (29–48%), versus **18.17%** after manual
pause and **21.34%** after closing. Desktop readings fluctuate even when Wavez
records no new draws; those percentages are not process-attributed GPU load.
The owner noted that moving around after the end may have affected the observation.
Movement changes draw demand and the volume ray path/cost. Focused tests exercise
real physical-key state through the normal free-camera callback, release input,
and verify unchanged-view idle resumes. The exact owner's close camera pose and
motion trajectory were not recreated; no extra owner experiments were requested.

## Validation scope and limits

The endpoint suite exercises particles, fields, meshes and mixed scenes using real
callbacks: forward/reverse committed edges, no duplicate display/GPU submission,
stable scientific clock/camera/buffer and pixel/fresh-draw equivalence, Loop,
UI seek/Pause then Play, held-end Auto Orbit and free-camera movement, closing,
source-tail resumption after a committed append, advanced interval auto-Pause,
gated terminal preparation and offline exclusion. It checks source SHA-256 and a
temporary Linux release entry using the same production resources/controllers.
The normal render-pacing suite covers connected paused/interaction/offline/cap
restoration paths; scientific playback and the accepted mixed-runway contract
cover the changed tick boundary. Unrelated camera redesign, filters, shader,
video, analysis, broad shell and Compatibility suites are outside this fix.

Final checks:

- **199/199** endpoint checks in source Forward+ Vulkan and **199/199** in the
  temporary Linux release, including input release/idle and full-quality pixels.
- **124/124** headless endpoint checks before the added movement assertions.
- **290/290** normal Vulkan pacing/interaction/offline/cap-restoration checks.
- **2,457/2,457** headless scientific playback checks.
- **44/44** headless accepted mixed particle-runway checks.
- **2/2** application version tests; Python syntax and whitespace checks pass.

The first normal pacing run was **289/290**: its 120-FPS assertion set Play on an
empty viewer. Accepted main independently retains its 60-FPS orbit cap in that
state because no source is open. The test now opens its existing particle fixture
before checking active-playback cap restoration; the complete rerun passes. No
production cap policy was weakened.

Development attempts are retained externally, not counted as passes: the first
import required an explicit bool annotation on the pacing predicate; the first
endpoint harness incorrectly assumed UI scrubs keep Play active and hashed empty
particle buffers in field/mesh-only scenes. Task-owned failed diagnostics were
stopped, those harness assumptions corrected, and the final checks rerun. The
original 124-check headless pass preceded the extra input/movement assertions;
final native/package runs include them. No failing check was suppressed.

Whole-production-file hashing, repeated cold-cache statistics, physical human input,
the owner's exact camera/memory-pressure state, Windows/macOS and long multi-hour
soaks were not run. Production size/mtime/ctime is unchanged; the small regression
captures are fully hashed. Selected sample/buffer and rendered-pixel comparisons
are distinct from whole-file scientific verification. GPU percentages include the
uncontrolled desktop and OS cache conditions. A moved/close dense volume can still
legitimately saturate the GPU while rendering; this fix targets redundant stationary
recorded-end work and does not lower visual quality or cap ordinary playback.

## Reproduction and owner review

```sh
python tools/profile_end_gpu.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse.wvz --end-seconds 120 \
  --output-dir /tmp/end-gpu-review
# Add --viewer /absolute/path/accepted/viewer for an immutable baseline.
python tools/validate_recorded_end_idle.py --godot /path/to/godot \
  --renderer forward_plus --output-dir /tmp/end-idle-contract
# Add --export for the temporary release validation entry.
```

Release templates ignore `--script`; the temporary test entry is converted to a
Node scene outside Git. No third-party runtime or scientific capture is vendored.
External traces, logs, accepted archive and test/runtime artifacts remain under
`/home/Nozba/Codex/Wavez/end-gpu-382/`.

Owner review after implementation:

1. Open the dense mixed capture, enable the owner's volume/ray step 0.25 settings,
   and play 0–74.5 at 1x with Loop off. Leave the camera still: the endpoint should
   remain exact, Play/live-follow remain available and redundant draws subside.
2. Move/steer/zoom with existing controls, release input and verify stationary idle
   resumes; judge legitimate ray-march cost during movement separately. Check
   reverse, Loop, UI scrub/Pause then Play, preparation/runway and responsive tools.
3. Close the capture and confirm an empty viewer and no continuing scene draws.
   Whole-device GPU may remain busy due to other desktop work. Check candidate
   build 102 in About and the standalone application on the owner's display.

Stop for owner review. Passing checks do not imply owner acceptance.
