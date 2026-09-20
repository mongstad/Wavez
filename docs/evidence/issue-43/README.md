# Issue #43 review evidence

**Pending owner review.** #43 was the sole Ready issue at preflight. A later
read-only board check showed In progress; this task made no Project-state writes.
Baseline is owner-merged transport PR #47, `a976ec6`. No acceptance-only PR or
branch was created. Earlier issue evidence is intentionally preserved as written.

Native host: Fedora KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti. Small existing
mixed particle/mesh/field fixtures were generated, not scientific solver runs.

| Check | Result | Evidence |
|---|---|---|
| Final status/Jobs Forward+ | 52 checks passed; source unchanged; parent-close worker acknowledged cancellation | [report](forward.json) |
| Final status/Jobs Compatibility | 52 checks passed; source unchanged; parent-close worker acknowledged cancellation | [report](compatibility.json) |
| Existing native shell Forward+ | 97 checks passed | [report](shell.json) |
| Existing native transport Forward+ | 62 checks passed; expected bottom offset includes new status line | [report](transport.json) |
| Existing readiness/performance maintenance, headless | 66 checks passed | [summary](validation.json) |
| Existing playback lifecycle, headless | 51 checks passed | [summary](validation.json) |
| Existing video continuation Forward+ | 83 assertions passed, including 43 native PNG/export UI checks | [summary](validation.json) |

The focused native suite exercises a real cold-seek worker barrier, latest-request
readiness, real selection-worker launch/reopen/cancel routing, real video start,
close/reopen, minimized-parent completion, overwrite refusal, cancellation,
missing/failed FFmpeg and parent-close acknowledgement. Open-failure and mesh
unavailability presentation tests inject diagnostic state; real corrupt-open
regression is in the existing shell suite. Analysis failure notification is a
signal-injection check, not a claim to have exercised every scientific job.

1000 synchronous status refreshes produce zero scientific instrumentation stages
or counters and leave visual/committed state unchanged. Reports retain measured
refresh cost; idle refresh is bounded to five per second. This is a focused
side-effect/cost check, not a before/after GPU benchmark or universal performance
claim. No worker polling, file reads or source scanning is added by Jobs.

- [1440×900 status/transport](loaded-1440.png)
- [1024×640 compact layout](loaded-1024.png)
- [Completed job access](jobs-complete.png)
- [Durable export failure](jobs-failed.png)

## Commands and retained local logs

Run from the repository root with the externally installed Godot binary:

```sh
python tools/validate_viewer_status.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-43-reviewed-forward
python tools/validate_viewer_status.py --godot "$GODOT" --renderer gl_compatibility --output-dir results/issue-43-reviewed-compatibility
python tools/validate_viewer_shell.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-43-shell
python tools/validate_viewer_transport.py --godot "$GODOT" --renderer forward_plus --output-dir results/issue-43-transport-dev
python tools/validate_performance_maintenance.py --godot "$GODOT" --renderer headless --output-dir results/issue-43-maintenance
python tools/validate_video.py --godot "$GODOT" --renderer forward_plus --continuation --output-dir results/issue-43-video
```

Use fresh output directories to rerun. Raw captures/videos/native logs remain in
ignored `results/`. The summary lists development failures and skipped coverage.
Initial inferred-type import errors, an inherited status-control height, and a
wrong test PNG filename were corrected. One development run timed out waiting
for `frame_post_draw` after minimize/restore; evidence capture now uses explicit
forced drawing, as the existing background-worker harness does. This harness
change does not alter production rendering. Final native runs passed.

Full 4K video, retained production benchmark comparison, production real-capture
suite, exhaustive scientific-job variants, HiDPI/mixed-monitor and long-session
soak were not run. The worker taskbar-entry limitation remains. Historical
02B/03B measurements are not newly rerun evidence. Owner manual checks and the
review boundary are in the [current status/Jobs contract](../../UX3_STATUS.md).
