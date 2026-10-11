# Rendering at a held recorded boundary — issue #382

Candidate **v0.1.0.102** is pending owner review, based on accepted build 101.

When non-looping playback reaches its committed last timestamp (or the first
when reversing), the viewer keeps the exact held presentation and uses the same
redraw-on-change policy as a manually paused stationary view. It avoids resampling
and submitting that identical endpoint on every display tick. Play remains active:
source polling can discover newly committed records and resume progression without
another Play action. Background preparation and physical-memory guards continue.

Reverse, Loop and new data restore active pacing when the clock can advance. UI
scrubbing still pauses and commits its requested target; Play can then resume.
Advanced field intervals retain their existing automatic Pause at their selected
end. Pending terminal preparation must commit before the held endpoint qualifies.
Offline render/export instances do not use the optimization.

Camera movement, Auto Orbit, manual navigation, resize and UI changes still draw.
Paused/held Auto Orbit keeps its accepted at-most-60-FPS cap and elapsed-time speed.
A dense ray-marched volume can legitimately be expensive while the view changes,
especially at a close camera pose. This change does not reduce volume resolution,
ray-march quality, brightness, postprocessing, scientific values or navigation
speed. A stable view after input stops should return to demand-driven rendering.

The defect was continuous endpoint rendering: accepted build 101 clamped the clock
at 74.5 while retaining active render pacing and repeatedly sampling/submitting the
same final frame. The tested view drew about 144 frames/second throughout two idle
minutes. Manual pause at the same time stopped those draws without changing the
particle-buffer hash or field upload count. #377 did not change the pacing/endpoint
paths; its owner-reviewed PR #381 tree is identical to accepted build 101.

The exact owner-reported gradual climb to 94–100% was not reproduced. Whole-device
GPU telemetry includes the desktop and is not Wavez-only attribution. See [matched
measurements, scope and remaining limits](evidence/issue-382/README.md).

For owner verification, play the dense mixed capture to its endpoint and leave the
camera still. Check stable timestamp/prepared runway and reduced redundant rendering.
Move with the normal controls, release input, and verify stationary idle resumes.
Then reverse, enable Loop, scrub/Play, and close the capture. GPU use during motion
must be assessed separately from the stationary held state. No additional owner-side
experiments were required to implement this fix.
