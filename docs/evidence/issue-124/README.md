# Issue #124 — Warn before exiting with active jobs

Candidate `v0.1.0.66`, pending owner review. #124 was the sole Ready issue at
2026-10-06 preflight. Its exact existing linked branch was checked out clean:
`124-ux-jobs-001-warn-before-exiting-wavez-with-active-jobs`.
GitHub linkedBranches and local HEAD/main/origin/main all matched accepted
`e86603014eb596a95d0f5bd2cd2cc91252bcba42`, including owner-merged #279/#146.
Fetch/prune completed; the preceding completed branch was already absent. No
replacement branch or acceptance-only historical edits were made. A publishing
recheck found the same main baseline, no existing PR and #124 still Open; the
Project had moved from Ready to In progress independently of this agent.

## Implementation

See [the current exit contract](../../EXIT_WITH_ACTIVE_JOBS.md). The application
close gate refreshes the existing shared Jobs rows and reads their active flags.
It covers all represented owners, including preparation and pending cancellation
acknowledgements, without new job tracking. Terminal/idle work does not prompt.
Main close, File → Exit and the native Window close signal share the gate.
Native automatic quit is disabled only for the interactive viewer.

The compact themed modal has exactly Exit WAVEZ and Cancel; Cancel gets initial
focus, Enter on Cancel dismisses safely, and Escape/window dismissal have the
same behavior. Repeated close requests reuse the instance. Shared #146 focus
containment/restoration is consumed unchanged. Confirmed exit calls the original
SceneTree teardown. Export/matched cancellation, analysis cleanup, source cleanup,
worker launch and #97's separate Cancel video export confirmation are unchanged.

## Results

Godot 4.7.2, Linux/X11, NVIDIA RTX 3070 Ti. Linux debug packages use externally
installed matching templates and a temporary validation entry scene; child
render jobs use the normal Main scene. Fixtures/preferences/packages remain
outside the repository.

| Check | Result |
| --- | --- |
| Development dialog matrix, Forward+ | 183 checks, 0 failures |
| Development dialog matrix, Compatibility | 183 checks, 0 failures |
| Development lifecycle, Forward+ | 10 process cases pass; 5 real exports gracefully cancelled/stopped |
| Development lifecycle, Compatibility | 10 process cases pass; 5 real exports gracefully cancelled/stopped |
| Packaged dialog matrix, Forward+ | 183 checks, 0 failures; lifecycle not included in this pass |
| Packaged dialog matrix, Compatibility | 183 checks, 0 failures; lifecycle not included in this pass |
| Initial packaged lifecycle attempt, Forward+ | 3 idle close routes pass; first active-export case fails before confirmation |
| Accepted-main packaged reproduction | Same worker-launch failure on main e866030; not a candidate lifecycle pass |
| Application version metadata/CLI | 2 tests pass; build 66 = main build 65 + 1 |
| Final import, changed-document local links, whitespace | Passed |

Successful final dialog/development runs exit cleanly without warnings/errors.
Every completed runner verifies unchanged synthetic-source SHA-256. The dialog
matrix injects current owner state for video preparation, foreground selections,
analysis, foreground/background cancellation awaiting acknowledgement, matched
preparation, isosurface extraction and simultaneous video/selection work. It
checks terminal video states (complete/frames_ready/failed/cancelled), no active
job for idle workers/cache preparation, both 1440×900 and 1024×640, exactly two
focusable choices, safe default/Enter, forward/reverse containment, repeated close
attempts, Escape and window dismissal, restored initiator, and unchanged visual/
scientific state, committed sample, camera transform and playback.

The lifecycle harness uses actual subprocess exports. It covers menu, chrome
button and native Window close-signal routes when windowed, plus menu exit when
maximized/fullscreen, each with idle and active work. Active exports have no
cancel marker merely from showing the prompt, survive Cancel, and remain active
when backgrounded and reopened through Jobs. Confirmed exit runs normal teardown
and writes the existing cancel marker. The Python parent checks cancelled worker
progress and a stopped renderer PID with bounded deadlines. An exited zombie
counts as stopped; no running renderer is accepted. These cases exercise the
unchanged worker cancellation protocol rather than a replacement job engine.
They do not exhaust every analysis/matched/encoder phase.

`validation.json` holds final checks/fixture hashes. `lifecycle-cases.json`
consolidates each route's original native output, before/teardown/confirmation
records and process summary without dropping failed records. Screenshots show
the actual compact/desktop warning and safe focus. Earlier issue evidence and
review-time wording remain unchanged.

## Failures and limitations

The first development lifecycle attempt used a Node close notification, which
did not emit Window.close_requested and timed out on the idle native route.
`development-native-event-attempt/` preserves its passing 183-check dialog run,
two passed idle routes and failed third route. The corrected harness checks the
actual connected Window close signal; final development matrices pass all routes.
This is signal-path validation, not a physical window-manager close event.

The initial packaged run passed its dialog matrix and three idle close routes.
Its first active export failed because this installed Godot template was compiled
without path overrides: the existing worker launcher always supplies `--path`.
The same failure was reproduced with **unchanged accepted-main production code**
archived into a temporary project and the original main exit harness. Only a
matrix script was added for the temporary package entry to load; it was not run
in the baseline reproduction. Both raw logs report the same rejected argument,
then the harness reports that the export was not active at exit. See
`packaged-worker-attempt/` and `accepted-main-packaged-worker/`.

No worker-launch fix is included in this exit-confirmation issue. Real packaged
active-job cancellation/shutdown remains unverified with these templates. The
separate packaged dialog passes use `--dialog-only` and explicitly skip lifecycle;
they do not mask or relabel the failed package attempt.

The first editor import recreated five pre-existing missing resize-script UIDs
with warnings and no script errors. Raw output is preserved. The final import
is clean; incidental resize UIDs are excluded and the new scripts retain their
own UIDs. No runtime/template, package, capture, shader cache, worker output or
preference file is committed.

Wayland/physical KDE close gestures, 4K/mixed-DPI, other OSes and long sessions
remain untested. State injection verifies other job owners participate in the
gate; it does not rerun their full scientific job suites. No unrelated scientific,
playback, analysis, cache, theme or window-layout suites were run for this gate.

## Reproduce and owner verification

Use [the source/package commands](../../EXIT_WITH_ACTIVE_JOBS.md) with fresh
output directories. With the currently installed template, expect the package
lifecycle failure above. To independently check a previously built package's UI:

```sh
env -u WAYLAND_DISPLAY python tools/validate_exit_confirmation.py --godot /tmp/exit-package/wavez.x86_64 --output-dir /tmp/exit-package-dialog-forward --renderer forward_plus --packaged --dialog-only
env -u WAYLAND_DISPLAY python tools/validate_exit_confirmation.py --godot /tmp/exit-package/wavez.x86_64 --output-dir /tmp/exit-package-dialog-compatibility --renderer gl_compatibility --packaged --dialog-only
python -m unittest tests.test_application_version
```

1. With no active jobs, use File → Exit, main X and the desktop close gesture;
   each should exit immediately. Repeat with only terminal/retained job records.
2. Start a video export and run it in the background. Attempt each close route;
   verify the concise warning, exact Exit WAVEZ/Cancel choices and Cancel focus.
   Enter on Cancel, click Cancel, press Escape and dismiss the dialog separately;
   confirm the viewer and export continue with unchanged time/camera/science.
3. Reopen through Jobs, close its overview/Details/export form, and check work
   continues without an application-exit prompt. Close the application again;
   it must still warn. Repeat close attempts without dismissing; expect one modal.
4. With multiple active represented operations, confirm the warning covers all
   jobs and has no per-job choices. Test preparation and cancellation-wait states.
   Finish/fail/cancel jobs and confirm a new close request needs no warning.
5. Confirm Exit WAVEZ during a real export. Check cancellation acknowledgement,
   retained recoverable output and no remaining renderer/encoder work. Repeat
   windowed, maximized/fullscreen, both renderers and physical KDE/Wayland.
6. Review desktop/compact/4K focus outlines and spacing. Check package UI and,
   once a template supports the existing launch arguments, repeat real packaged
   active-job shutdown. Confirm About build 66 and reconcile main+1 before merge.

The PR remains for owner review. No merge, auto-merge, manual issue closure,
Project move or subsequent issue work follows from passing automated checks.
