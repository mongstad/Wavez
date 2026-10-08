# Issue #212 — view-relative Auto Orbit center placement

Candidate **v0.1.0.78**, pending owner review. Accepted baseline is PR #300,
`6bd497d60c75c435f38cdffe1dd87d8cdd56bc97` / build 77. #212 was the sole Ready
issue; the clean owner-created branch
`212-ux-nav-make-edit-orbit-center-view-relative` matched main/origin before edits.

The owner clarified: **preserve RMB steering; this edits the new position of
Auto Orbit only**. #212's older #190 RMB wording does not restore the retired
RMB orbit gesture. Current #258 steering and held orbit hotkeys remain unchanged.

## Changes and contracts

The editor captures the current full camera basis at entry. Right/Up/Toward
handles move its draft world-space center along that reference; the end-on
Toward direction gets an explicit diagonal screen handle. Absolute numeric XYZ
retain their world-space meaning. Untouched fields preserve their exact draft
values rather than reparsing rounded display text. Apply retains the actual
current camera basis, commits center/radius and starts the existing Auto Orbit.
Cancel restores the saved complete camera/navigation state.

Production behavior changes are confined to the editor/guide. Main camera/input,
steering, held orbit, LMB/inversion, zoom, Free Camera, automatic orbit, scientific
layers, playback, data and export code match accepted main. The older handle test
now checks view-axis movement. A focused new driver/runner and stable UID cover
the new semantics. Build identity increases once under the existing policy.

Current usage: [Auto Orbit placement](../../ORBIT_CENTER_VIEW.md). The earlier
#120/#190/#234 reports and all prior evidence remain unchanged.

## Completed focused checks

The matrix covers **64 cases per complete run**: particles/field/mesh/mixed ×
small/large scale × normal/fullscreen × LMB, LMB→RMB, LMB→RMB→LMB, and combined
steering/held orbit/Free Camera positioning/zoom. The fixtures differ by 100,000
in world scale. It checks captured-view drag direction through real viewport
event routing, independent world numeric coordinates, draft-only state,
placement navigation, full-basis Apply, unchanged radius, radius-only edits,
five repeated unchanged Apply/Cancel cycles, exact untouched fields, resumed
Auto Orbit, RMB in-place steering, resulting view-up for held orbit, committed
samples and scientific transforms. Inputs are synthetic events inside Godot,
without OS input-device control.

| Run | Checks / result | Report |
| --- | --- | --- |
| Headless editor matrix | **3,472 PASS**, zero failures/diagnostics | [headless](headless.json) |
| Native Forward+ matrix | **3,474 PASS**, zero failures/diagnostics | [Forward+](forward.json) |
| Native Compatibility matrix | **3,474 PASS**, zero failures/diagnostics | [Compatibility](compatibility.json) |
| Linux release validation package, Forward+ | **3,474 PASS**, zero failures/diagnostics | [package Forward+](package-forward.json) |
| Same release validation package, Compatibility | **3,474 PASS**, zero failures/diagnostics | [package Compatibility](package-compatibility.json) |
| Connected Auto Orbit suite, headless | **364 PASS**, unchanged fixture hashes | [Auto Orbit](connected-auto-orbit.json) |
| Version unit tests | **2 PASS**, CLI `v0.1.0.78` | Existing `tests/test_application_version.py` |
| Strict WVZ1 verifier | **8 captures / 24 records PASS** | [strict verifier](strict-verification.json) |
| Protected source comparison | **1,914 accepted files byte-identical**, including all old evidence; main camera/input exact | [source contract](source-contract.json) |

Completed logs: [headless](headless.txt), [Forward+](forward.txt),
[Compatibility](compatibility.txt), [package Forward+](package-forward.txt) and
[package Compatibility](package-compatibility.txt).

Every matrix run checks all eight capture SHA256s remain unchanged. First-party
Python/library/resource staging uses the existing packager, without external
runtime vendoring. A normal production release also builds successfully:
[production build manifest](production-release-build.json). The validation
package differs only in a temporary test entry scene; it loads the compiled
production Viewer/editor/resources and the same first-party Python archive.
It is not a claim of testing the normal application's startup through a release
`--script` flag. Executables, PCKs and fixture captures stay under `/tmp`.

Representative normal/fullscreen screenshots (1440×900 / 2560×1440):

- Native Forward+: [normal](forward-normal.png), [fullscreen](forward-fullscreen.png).
- Native Compatibility: [normal](compatibility-normal.png), [fullscreen](compatibility-fullscreen.png).
- Release package Forward+: [normal](package-forward-normal.png), [fullscreen](package-forward-fullscreen.png).
- Release package Compatibility: [normal](package-compatibility-normal.png), [fullscreen](package-compatibility-fullscreen.png).

These tiny mixed fixtures emphasize guide/control visibility, including a bright
particle/field region. They do not establish physical feel in a research scene.

## Baseline reproduction, failures and limits

The same focused probe on an untouched accepted-main source archive completed
**256 checks with 56 expected failures**: 48 fixed-world-axis mismatches and
eight unchanged-Apply drift failures. [Baseline report](baseline-reproduction.json).
It is failing reproduction evidence, not a passing baseline suite.

The connected navigation runner remains **FAIL** in both candidate and accepted
main: headless **1,393 checks / 1 identical failure**, Forward+ **1,747 checks /
1 identical failure**. Both fail `Real process loop advances the held orbit shortcut`.
The assertion occurs before editor usage and the camera/input code is unchanged.
Candidate [headless](connected-navigation.json) / [native](connected-navigation-forward.json)
and accepted [headless](baseline-connected-navigation.json) /
[native](baseline-connected-navigation-forward.json) retain those results/logs.
Failure logs: candidate [headless](connected-navigation.txt) /
[native](connected-navigation-forward.txt), accepted [headless](baseline-connected-navigation.txt) /
[native](baseline-connected-navigation-forward.txt).
No partial run is relabeled PASS and no unrelated navigation fix is included.

[Intermediate failures](intermediate-failures.json) record the initial field-reader
typed-array error and its cascading assertions, then a test gesture outside the
usable viewport after placement steering. Both are corrected in the completed
matrix runs. Initial sandbox imports lacked local editor sockets; required access
resolved that environment failure. Five unrelated UID sidecars were recreated
from accepted cache state and excluded from the change.

The first two production-template package attempts ignored `--script`, produced
no completed report and were explicitly stopped. A temporary release test entry
scene fixed the harness; completed package results above supersede those attempts.

No OS/physical mouse/key control, subjective feel, other OS, mixed-DPI/4K layout,
large research capture, sustained playback or video encoding is claimed. Existing
Godot world-vector precision/clipping limits remain. No scientific reader/writer,
solver or wire changes justify unrelated full-suite or production reruns.

## Owner verification

1. Navigate to a strongly tilted view with LMB, RMB and their combination. In
   **Navigate → Edit orbit center…**, drag Right/Up/Toward and verify that numeric
   XYZ remain absolute world coordinates. Check small/large particle, field,
   mesh and mixed scenes.
2. Apply a new center with radius untouched: orientation must retain its complete
   basis and Auto Orbit must start around the new point. Repeat radius-only and
   unchanged Apply cycles. Confirm RMB still steers in place and held orbit keys
   use the resulting screen-up.
3. Edit and navigate during placement, then Cancel: compare the full prior pose,
   center, radius and navigation mode. Repeat open/cancel without drift.
4. Repeat normal/fullscreen, Forward+/Compatibility and the Linux build with a
   physical mouse. Use Hide controls/Place ahead if a handle is covered or offscreen.
   Scientific objects and capture data must remain unchanged.

Review [the current guide](../../ORBIT_CENTER_VIEW.md) for the exact reproduction
commands. No merge, auto-merge, issue closure or Project transition is performed
by the implementation; owner acceptance remains pending.
