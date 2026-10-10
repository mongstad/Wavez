# Video Export time-control tooltip removal — issue #326

Candidate **v0.1.0.91**, based on owner-merged PR #336 / accepted **v0.1.0.90**
at `d2b0bf453b2ae0d301decde2e22251316f482be0`. Issue #326 was the only Ready
item in [Wavez Development](https://github.com/users/mongstad/projects/1).
Its exact existing linked branch was checked out, clean, and equal to accepted
main before edits. Required predecessor #323 / PR #324 was merged and its
commit was an ancestor of main. No existing PR matched this branch.
See [preflight metadata](preflight.json).

## Change and tooltip inheritance

The repeated `update_time_readout` call assigned the oversized hint to each
Start/End SpinBox and its adjacent clock Label. The native SpinBoxLineEdit had
an empty own tooltip, but inherited the SpinBox text; the arrows hit that same
SpinBox. Accepted-main positive hover checks reproduce both delayed popups.

The candidate removes the generator and those assignments. Numeric editors,
arrow controls, clocks, permanent Start/End labels, the range Mode selector and
their Control ancestors have empty hints. The delayed native hover audit checks
all eleven target positions in each Dark/Light × 700×650/560×360 state.
Compact targets are scrolled into view before probing; actual hit controls and
viewport containment are checked so clipped End controls cannot falsely pass.
Native pointer positioning keeps hover valid through scrolling.

Visible clock formatting, the **≈** marker and the **Exact range** line remain.
No endpoint model, bounds, step/edit handler, export calculation or scientific
payload code changed. Other existing Video Export tooltips remain, including
Playback rate and the precise-duration summary.

The exact permanent instruction already existed in accepted main's root
`AGENTS.md`; [the focused check](owner-rule.txt) verifies it occurs **once**:

> Never add tooltips to panels, controls, buttons, labels, or other UI elements unless the owner explicitly instructs you to add a tooltip for that specific element.

It is preserved without adding a duplicate. Current Video Export guidance and
status documentation now describe the tooltip-free endpoints. Earlier issue
#323 and #335 evidence remains unchanged.

## Validation results

External Godot 4.7.2 (`ed1daf0bf`) and FFmpeg on Linux / NVIDIA RTX 3070 Ti:

| Runtime | Baseline checks | Candidate checks | Result |
| --- | ---: | ---: | --- |
| [Forward+ source](forward-plus/summary.json) | 190 | 383 | PASS, clean logs |
| [Compatibility Linux release](linux-release-compatibility/summary.json) | 190 | 383 | PASS, clean logs |

Each run checks 44 delayed candidate hover targets and reproduces the accepted
popup on both the editor and its up arrow. Reports retain each hit control,
ancestor hint and visible-popup result. Exact range editing, Enter/Tab focus,
reversible one-second arrows, mutual/source bounds, fractional final-second
inclusion and still-frame behavior pass. Each settings comparison matches all
**42** cases, including frame counts and first/last sample times.

Three small exports per runtime match accepted main: fractional (4 frames),
full at fast playback (2), and the final 92.33-second remainder (2). Timestamp
records, staged PNG pixels and decoded MP4 pixels are identical; 320×180 / 4 FPS
metadata matches. All six generated input-capture hashes remain unchanged.
UI/worker logs contain no `ERROR:` or `WARNING:`. Disposable release import and
export pass; [artifact hashes](linux-release-compatibility/artifacts.json) identify
that review package. [Both version tests](version-tests.txt) and `git diff --check`
pass. The legacy fake-viewer grouping suite and unrelated full suites were not run;
the production viewer harness covers the affected controls and export boundary.

Initial harness iterations are retained in [diagnostic logs](harness-iterations/):
a missing type annotation, incorrect embedded mouse routing, clipped compact End
probes, and native hover loss after scroll. The final harness corrects each and
passes both runtimes without weakening hit-target or popup assertions. Initial
editor import recreated four unrelated missing cached resize UIDs; those generated
files were removed and are not part of this change.

## Screenshots

| State | Source Forward+ | Linux release Compatibility |
| --- | --- | --- |
| Dark, normal | [700×650](forward-plus/after/tooltip-free-dark-700.png) | [700×650](linux-release-compatibility/after/tooltip-free-dark-700.png) |
| Dark, compact | [560×360](forward-plus/after/tooltip-free-dark-560.png) | [560×360](linux-release-compatibility/after/tooltip-free-dark-560.png) |
| Light, normal | [700×650](forward-plus/after/tooltip-free-light-700.png) | [700×650](linux-release-compatibility/after/tooltip-free-light-700.png) |
| Light, compact | [560×360](forward-plus/after/tooltip-free-light-560.png) | [560×360](linux-release-compatibility/after/tooltip-free-light-560.png) |

[Accepted-main popup](forward-plus/before/accepted-time-tooltip.png) shows the
removed multiline hint. Candidate screenshots retain readable labels, ≈ clocks,
Exact range and actions with no popup covering them.

## Reproduction

Archive accepted main into a disposable directory, import its viewer with the
external Godot runtime, then run from the repository root:

```sh
python tools/validate_video_time.py --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 --baseline /absolute/path/to/accepted-archive --output /tmp/issue-326-source --renderer forward_plus
python tools/validate_video_time.py --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 --baseline /absolute/path/to/accepted-archive --output /tmp/issue-326-package --renderer gl_compatibility --package
python -m unittest tests.test_application_version -v
git diff --check
```

The baseline mode's two old pre-#323 assumptions now use the presence of the
exact-range API, so accepted main can be compared without expecting retired
timestamp/edit behavior. Baseline and candidate still compare the same settings
matrix, frame counts and sample boundaries. Release review uses a disposable
entry scene that drives the production viewer/dialog and production worker;
Godot/FFmpeg binaries and generated captures/videos remain outside the repo.

## Limits and owner review

This is focused synthetic native input and GPU evidence, not owner physical
acceptance. No unrelated playback, camera, mesh, field or analysis suite was
run. Windows/macOS, mixed DPI/4K displays, physical typing/hover feel and long
research-capture sessions remain untested. The accepted Godot release Popup
signal limitation documented under issue #335 remains outside this issue.

For owner review, open Video Export → Custom in each theme; hover both editors,
up/down arrows and clock labels, scrolling End into view at compact size. Confirm
there is no delayed popup, permanent labels and Exact range remain readable,
Enter/Tab and one-second steps retain their behavior, and a short export retains
its range/results. The PR remains for owner review; no merge, auto-merge,
manual issue closure or Project transition is performed.
