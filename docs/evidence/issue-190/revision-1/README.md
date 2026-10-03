# Issue #190 — horizontal camera orbit revision

The owner's first physical review found that right-drag modified pitch as well
as yaw and therefore resembled left-drag tumble. This revision makes right-drag
a horizontal camera orbit about world Y. Horizontal pointer travel changes yaw;
vertical travel is ignored. The existing pitch sets a fixed viewing elevation,
and `_update_camera()` keeps the camera at the current radius looking at the
current target. Yaw is not clamped or wrapped, so either drag direction can pass
the opposite side and continue around the full circumference. Left-drag keeps
its two-axis tumble. No simulation geometry, capture format, playback or camera
recipe schema changed. Candidate identity remains **v0.1.0.26** on the existing
issue branch and PR #199, pending owner review.

The original [review-time report](../README.md) and its machine-readable
results remain untouched. They describe the superseded two-axis right-drag
candidate and are not acceptance evidence for this revision. The owner's
horizontal-only correction supersedes the original issue's vertical right-drag
wording; vertical orbit remains available through the accepted left-drag tumble.

## Validation

Godot 4.7.2 on Linux KDE/Wayland with NVIDIA RTX 3070 Ti. The focused camera
suite passed **13,714 checks** across particle, volume, mesh and mixed SIMSCP4
fixtures. It verified yaw-only diagonal right-drag, exact pitch/transform
invariance for vertical-only right-drag, fixed target/radius/elevation and
committed scientific sample, the opposite side at half a turn, and return to
the same transform after a full right-drag revolution in **both directions**.
The existing left-drag three-revolution and pole-continuity checks passed.
Fixture source hashes were unchanged.

| Native viewport check | Forward+ | Compatibility |
| --- | ---: | ---: |
| Source, quick cavity capture | 230 PASS | 230 PASS |
| Source, synthetic categories and fullscreen | 222 PASS | 222 PASS |
| Linux release package, quick cavity capture | 230 PASS | 230 PASS |
| Linux release package, synthetic categories and fullscreen | 222 PASS | 222 PASS |

The viewport suite delivered right-button events through the real window input
route. It checked yaw change with invariant pitch, vertical-only no-op, current
target and radius, committed scientific time, unchanged mesh source vertices,
category changes, zoom/Frame Scene, fullscreen and release over chrome. The
matrix exercised 1440×900 and 3840×2160 windows at content scales 1, 2 and
2.5. Generated and quick-cavity source hashes were unchanged in every completed
run. The quick cavity SHA-256 remained
`9215baf4e475256b254916f290b5c569d17553e944c4778b17b74eed0ba0b10e`.
Two application-version unit tests passed. Godot imports and exports succeeded
in the final runs; `git diff --check` passed.

Each row's detailed machine-readable report is adjacent to this file. The
`/tmp` fixture paths in those reports identify local validation runs; generated
captures, package binaries and screenshots were not committed.

## Diagnostic attempts and limits

An initial Forward+ package synthetic/fullscreen run failed four assertions at
high content scales: its test pressed the center of the entire scaled window,
which lay under the simulation dock. The same failure repeated unmodified.
The test now selects and asserts an unobstructed viewport point; the final
Forward+ and Compatibility package matrices pass at all three layouts. One
Compatibility package import emitted Godot dummy-renderer texture errors; an
unchanged rerun imported, exported and passed its native checks. Final native
logs retain only the known Wayland libdecor GTK fallback diagnostic. The older
combined Compatibility cavity/fullscreen teardown timeout was not retested;
the final cavity and fullscreen matrices ran separately and exited cleanly.

The full 240-second cavity capture, continuous playback during a physical drag,
subjective throat/surface feel, physical 4K/mixed-DPI pointer behavior,
long-session use, other operating systems and a new video-export comparison
were not run. Automated state checks and quick-capture screenshots do not
establish those properties. Physical owner acceptance remains required.

## Owner verification

1. Open the full cavity-collapse torus, press F, disable Auto Orbit and
   right-drag left and right through at least one complete circle. Inspect the
   opposite side and return to the starting view. The torus must stay fixed;
   camera distance, elevation and upright orientation must not drift.
2. Right-drag vertically, then diagonally. Vertical-only motion must leave the
   camera unchanged; diagonal motion must orbit horizontally only. Left-drag
   must still tumble freely in both axes.
3. Repeat at whole-scene, close-surface and inside-throat zoom. Check wheel
   zoom and F before and after orbit. With Auto Orbit enabled, right-drag should
   pause it only while held.
4. Check particle-only, field-only, mesh-only and mixed scenes while changing
   Simulation categories and selected objects. Repeat during playback and
   fullscreen in Forward+ and Compatibility, including the Linux package;
   release over chrome and close the window.
