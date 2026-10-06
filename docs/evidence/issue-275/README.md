# Issue #275 — Tooltip-free playback clocks

Candidate v0.1.0.63, pending owner review. #275 was the sole Ready Project item
at preflight on 2026-10-06. Exact owner-created linked branch:
`275-ux-transport-remove-tooltips-from-elapsed-and-totalremaining-time-controls`.
It started clean at accepted main `c9aecc3316da12e5c1d063cfe3913c659c94cef2`,
including owner-merged PR #274 / #156 shared typography. Local main, remote main
and linked branch matched. Previous #156 branch refs were already removed;
fetch/prune completed. No historical acceptance-only edits were made.

## Implementation

The duration button clears the shared button constructor's default tooltip on
creation. Transport refresh no longer assigns tooltip text to elapsed or duration.
These are the only production UI changes. Shared typography, formatting, native
seek/toggle/focus signals, state styles, spacing and playback logic are untouched.
Existing intentional tooltips elsewhere, including the seek input, remain.

## Focused results

| Validation | Result |
| --- | --- |
| Native Forward+ tooltip/input test | 54 checks, 0 failures, clean exit |
| Native Compatibility tooltip/input test | 54 checks, 0 failures, clean exit |
| Existing Forward+ transport suite | 260 checks, 0 failures; fixture hashes unchanged |
| Python application version contract | 2 tests, OK; v0.1.0.63 = main build 62 + 1 |
| Whitespace | git diff --check passed |

Native logs contain no warnings/errors on the completed runs. Godot 4.7.2 ran
on Linux/X11, NVIDIA RTX 3070 Ti, with isolated XDG preferences. The new
`viewer/ui/shell/test_transport_tooltips.gd` delivers viewport mouse motion,
click/double-click, and native Enter/Escape/Tab input. It waits 0.8 seconds for
hover and verifies both actual hovered control and visible TooltipLabel popups.
Elapsed, total and remaining show no popup; Loop provides a positive control
that still displays its existing tooltip. Play and timeline retain tooltip text.

Native clicks toggle total → negative remaining → total without changing time.
Double-click opens seek, Enter commits 00:02, Escape discards an edited 00:04,
and elapsed regains focus. Tab visits timeline then duration. Existing duration
style resources and elapsed focus behavior stay intact. Both clocks stay
hover-tooltip-free while focused at 1440×900 and 1024×640, retaining 64/104 px
transport heights, clock alignment, slider clearance and speed fit.

The existing transport test had an assertion requiring the now-removed elapsed
tooltip. That assertion and the fractional-seek tooltip assertion were updated
for the new contract, then the component suite ran once in Forward+; unrelated
application regression suites were not run. Both new hover/input runs and the
existing suite completed cleanly. Selected screenshots show clock hover, remaining,
compact focus and an intentionally retained Loop tooltip. Visual review covered
Forward+ hover/focus/Loop and Compatibility compact elapsed focus.

## Development failure preserved

The initial Forward+ focused run produced 54 checks with 12 failures: removing
refresh assignments alone left the duration constructor's “—” tooltip visible.
Elapsed hover, seek, toggle and focus paths passed. `initial-attempt/` preserves
the failed report, log and duration-hover screenshot. Clearing only the duration
constructor tooltip resolved all 12 failures; passing evidence is separate.

Editor import completed with five pre-existing missing resize-script UID warnings
and no script errors. The import log is retained in `initial-attempt/import.txt`.
Those unrelated generated UIDs were removed; the new test's UID is committed.
No runtimes, preferences or generated scientific fixtures are committed.

## Reproduce

Create a fresh output directory and use `tests.g4.fixtures.scene` to write
`scene.wvz` there. Run externally installed Godot with isolated XDG data/config,
normal native display access, and these arguments:

```sh
env -u WAYLAND_DISPLAY /path/to/godot --path viewer --rendering-method forward_plus --audio-driver Dummy --resolution 1440x900 --script ui/shell/test_transport_tooltips.gd -- /tmp/issue-275
```

Repeat with `--rendering-method gl_compatibility` and a separate output directory.
For the existing transport suite use `tools/validate_viewer_transport.py` with
`--godot`, a fresh `--output-dir`, and `--renderer forward_plus`.

## Limitations and owner checks

Packaging, other OSes, Wayland, physical mixed-DPI/4K, alternate desktop scaling,
physical mouse/keyboard feel and long sessions were not tested. No scientific,
cache, camera, video or analysis suites were run for this tooltip-only change.

1. Open a capture and hover elapsed, total and remaining beyond the tooltip delay:
   no tooltip should appear. Click total → remaining → total.
2. Double-click elapsed, enter a valid clock and press Enter. Reopen, edit another
   clock and press Escape; the committed time must remain unchanged on cancel.
3. Tab through elapsed → timeline → duration. Check both clock focus outlines.
4. Compare normal and compact widths and preferred desktop scaling: readouts,
   timeline, speed, Loop and Jobs must retain their presentation and interactions.
5. Hover Loop, Play and timeline; their intentional tooltips should remain.
   Confirm Help → About shows v0.1.0.63 and reconcile BUILD with main before merge.
