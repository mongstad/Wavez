# Issue #190 — manual camera orbit review

The sole Ready item on Wavez Development Project 1 was #190 when selected on
2026-10-03. The owner-created branch
`190-ux-nav-add-manual-camera-orbit-around-the-current-scene-target` and
accepted `main` were both at `7544501d1163592415d15ec0f72b7c3a01a46096`
before editing; the working tree was clean. Remote refs were fetched and pruned.
The prior #175 PR #177 and the mesh-preparation predecessor #195 PR #196 were
owner-merged, and their work is present in `main`. No previous local issue
branch remained to remove. Candidate identity is **v0.1.0.26**; owner review is
pending.

## Input and implementation

The accepted input map already used left drag for fixed-sensitivity camera
tumble, left double-click for fullscreen, the wheel for zoom, and left drag for
active selection tools. Right drag was unused in the viewport. The new right
drag is a direct manual camera orbit, with no object/layer selection or mode.
It reuses `camera_target`, `camera_distance`, `yaw`, `pitch` and `_update_camera()`;
it never writes a scientific object transform or a second camera model. The
input starts only in the viewport, continues across chrome, and ends on right
release even over chrome or on focus loss. Existing left drag retains its
0.006-radian-per-pixel path.

The right-drag angular step is `PI / max(480, min(viewport width, height))`
times `0.2 + 1.6r / (r + 3.5)`, where `r` is current camera distance divided by
the larger of the last framed scene radius and camera near plane. The response
is continuous: close radii give finer movement, and distant radii approach a
bounded 1.8× gain. Pure orbit changes only yaw/pitch. Auto Orbit pauses while
either drag is held and resumes on release; its world-Y update remains the same.
The Navigate tooltip and current handbook/shortcut documentation explain the
gesture. No preference, recipe, capture, playback or export schema changed.

## Validation

Godot 4.7.2, Linux KDE/Wayland, NVIDIA RTX 3070 Ti. The focused camera suite
uses four tiny native SIMSCP4 fixtures. The viewport suite uses particles,
volume, mesh, mixed, tiny and large synthetic scenes plus the owner's 12-second
`cavity_collapse_torus_quick.ssc` outside the repository. Source SHA-256 hashes
were unchanged in every completed run. The native matrix exercised actual
1440×900 and 3840×2160 windows at content scales 1, 2 and 2.5, including
windowed/maximized/fullscreen transitions. The headless camera regression
passed **13,102 checks** with unchanged source hashes.

| Check | Forward+ | Compatibility |
| --- | ---: | ---: |
| Source cavity orbit, wheel, scene navigation | 225 PASS, including fullscreen | 210 PASS |
| Source synthetic category and fullscreen orbit | Included above | 198 PASS |
| Linux release package cavity orbit and wheel | 210 PASS | 210 PASS |
| Linux release package synthetic category and fullscreen orbit | 198 PASS | 198 PASS |

The camera suite checked right-press/release, shared yaw/pitch, finite distance,
unchanged target/radius and committed scientific sample, close/far sensitivity,
wheel composition, Frame Scene, Auto Orbit pause/resume, and particle/volume/
mesh/mixed scenes. Existing full-revolution left-drag/pole tests still pass
through the shared yaw/pitch update. The native suite delivered real viewport
events and checked mesh source vertices, scientific time, category changes,
fullscreen input and release over chrome. The quick cavity source hash remained
`9215baf4e475256b254916f290b5c569d17553e944c4778b17b74eed0ba0b10e`.
The untouched accepted-main Compatibility cavity run passed 160 checks.

Machine-readable reports are next to this file. Their absolute `/tmp` fixture
paths identify the validation run; generated captures and Linux packages were
not committed. Two application-version unit tests, Python compilation, Godot
imports and `git diff --check` passed. Final native logs contained only the
known Wayland libdecor GTK fallback diagnostic.

## Failed attempts and limits

An initial sandboxed Godot import could not create local sockets. The permitted
native rerun reached the test, exposed a test-driver variable typo, and passed
after the typo was corrected. An early viewport harness called Frame Scene
twice before orbiting the cavity; Compatibility source and Forward+ package
then timed out during teardown after all assertions passed. Removing that
redundant test setup produced clean cavity runs. A fixed test coordinate also
fell under chrome in scaled fullscreen; using the actual viewport center made
the fullscreen assertions pass.

One expanded Compatibility run combined the quick cavity with fullscreen orbit:
all 225 assertions passed, but the process timed out after writing the report.
The final Compatibility cavity run (210 checks) and separate fullscreen/category
run (198 checks) both exited cleanly. A clean combined-capture teardown remains
unverified, and the timeout is not classified as pre-existing. The untouched
`main` cavity run without the new gesture exited cleanly.

The full 240-second cavity capture, continuous playback while physically
dragging, subjective throat/surface feel, physical 4K/mixed-DPI pointer behavior,
multi-hour use, other operating systems and fresh video-export comparison were
not run. Automated camera state and quick-capture checks do not establish those
qualitative or long-session properties. The owner should follow the exact
[manual verification steps](../../MANUAL_CAMERA_ORBIT.md) before acceptance,
especially full-capture playback and Compatibility fullscreen/close.
