# Issue #156 — Playback clock typography

Candidate v0.1.0.62, pending owner review. #156 was the sole Ready item at
preflight on 2026-10-06. The exact existing linked branch
`156-ux-match-elapsed-and-total-playback-time-typography` started clean at
accepted main `bec2b2bc785245b7b678913066fe919e439dbd4b` (owner-merged #273).
Local main, origin/main and linked branch matched; the completed #222 branch
was already absent after pruning. No historical evidence was rewritten.

## Change and focused validation

The production style installer applies the same NumericValue font and size
to the elapsed Label and total/remaining CompactButton in one loop. Current
shared typography is regular DejaVu Sans Mono, 13 logical pixels. Previously
the elapsed NumericValue used 13 while the button inherited the body size 14.
The existing font was already shared; this makes both properties explicit.
Button states, seek routing, formatting, timing and layout rules are unchanged.

| Check | Result |
| --- | --- |
| Native Forward+ transport | 260 checks, 0 failures; clean exit; no warnings/errors |
| Native Compatibility transport | 260 checks, 0 failures; clean exit; no warnings/errors |
| Version metadata/CLI | 2 tests, OK; candidate v0.1.0.62 = main build 61 + 1 |
| Whitespace | `git diff --check` passed |

Each renderer used `tools/validate_viewer_transport.py`, Godot 4.7.2, NVIDIA
RTX 3070 Ti on Linux/X11, and isolated XDG preferences. Logs and JSON reports
are in the renderer subdirectories. The existing transport suite exercises
committed seeks, invalid/cancelled drafts, Enter submission, total/remaining
click signals, recorded timing, formatting, pending seeks and desktop/compact
sizing. The added checks resolve the actual font resource and size and exercise
short, minute, hour and negative remaining strings at 1440×900 and 1024×640.
Long-clock snapshots intentionally replace presentation text while pausing UI
refresh; they are layout stress cases, not claims that the six-second fixture
contains an hour of scientific data. The UI refresh is restored afterward.

Both renderers preserved 64/104 px transport heights and slider/rate clearance.
Synthetic WVZ fixture hashes were unchanged. Generated scientific fixtures and
external runtimes are not committed. Selected screenshots show short desktop,
minute compact, hour desktop, negative remaining compact, seek and real toggle.
Visual inspection covered desktop and compact screenshots across both renderers.

The initial sandboxed editor import could not open its editor TCP socket or
save editor settings outside the workspace. Its log is retained as a failed
setup attempt. A retry with isolated preferences and permitted native access
completed without warnings/errors (`isolated-import.txt`). Five unrelated
newly generated resize-script UID files were removed; tracked UIDs were retained.

## Reproduce

Use fresh output directories, an externally installed Godot 4.7.2 executable,
and isolated `XDG_DATA_HOME` / `XDG_CONFIG_HOME`. On this Linux desktop unset
WAYLAND_DISPLAY to run the native X11 transport checks:

```sh
env -u WAYLAND_DISPLAY python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir /tmp/issue-156-forward --renderer forward_plus
env -u WAYLAND_DISPLAY python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir /tmp/issue-156-compatibility --renderer gl_compatibility
python -m unittest tests.test_application_version
```

Validation stayed within the affected transport and version boundary. Packaging,
other operating systems, physical mixed-DPI/4K, alternate desktop scaling and
long-session checks were not run. Unrelated scientific, camera, cache, video
and analysis suites were not run because this changes two typography overrides.

## Owner verification

1. Open a capture at desktop width. Compare elapsed (left of slider) with total
   (right): same family, size and weight. Seek to beginning, middle and end.
2. Click the right readout to remaining and back. Check the leading minus and
   zero endpoint. If available use a capture with minute/hour durations.
3. Double-click elapsed, edit a valid clock, press Enter, and confirm seek.
   Reopen and press Escape; confirm cancellation retains the committed time.
4. Resize to 1024×640, then restore desktop width. Check readouts, slider, rate,
   Loop and Jobs fit and retain their alignment. Tab to elapsed and duration;
   inspect focus outlines at your preferred desktop scaling in both renderers.
5. Review Help → About for v0.1.0.62; compare candidate BUILD with accepted main
   before merge. Passing checks do not constitute owner acceptance.
