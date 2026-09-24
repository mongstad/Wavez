# Video progress details — issue #52

Implemented on `52-video-ux-001-improve-export-progress-details`, pending owner
review. On 2026-09-24, #52 was the only Ready item. GitHub linked this existing
branch to #52; local HEAD, its remote and accepted main all began at `28b5358`
(owner-merged PR #76). Fetch/prune completed; the tree was clean and no completed
local issue branch remained to delete. No implementation branch was created or
switched. The issue specifies no additional predecessor dependency.

## Change

The export dialog and Jobs Details consume one presentation formatter over the
existing published in-memory job state. A single integer frame/percentage line
replaces the three overlapping summaries. Separate elapsed and approximate
render-only remaining times use `hh:mm:ss`. Output and Temporary files are labeled
once; worker failure/cancellation diagnostics remain available.

The monotonic presentation clock advances elapsed time between worker updates.
An ETA requires two completed frames and one elapsed second; lack of recent
progress suppresses it after max(10 seconds, three average frame durations).
Encoding and cancellation have no ETA. Complete/frames-ready states show zero
remaining, and terminal elapsed values freeze. Invalid frame counts do not
produce a percentage. Failed or cancelled exports retain actual partial counts.
All timing fields added here are session-only presentation metadata.

Worker ownership, polling cadence, render generation, source timing, encoding,
overwrite refusal and cancellation are unchanged. The worker, render-job schema
and offline timeline source files were not modified.

## Validation

Godot 4.7.2, NVIDIA RTX 3070 Ti, native GPU display, synthetic SIMSCP3 capture:

| Gate | Result |
|---|---|
| Native status suite, Forward+ | 103 checks PASS, zero failures |
| Native status suite, Compatibility | 103 checks PASS, zero failures |
| Parent-close cancellation | Worker acknowledged on both renderers |
| Capture integrity | Source SHA-256 unchanged within each run |
| 1,000 status refreshes | No scientific work or state/clock changes |
| Final Godot import | Clean, new script UID tracked |
| Whitespace | `git diff --check` passed |

The native suite covers real live Details/ETA, hidden-panel/minimized continuation,
successful MP4, stable terminal Details, reopening the original job, overwrite
refusal, cancellation, missing FFmpeg, encoder failure and parent shutdown.
Deterministic presentation snapshots additionally exercise 25% progress, live
elapsed/ETA between publications, initial insufficient progress, stale progress,
encoding, cancelling, failed/cancelled partial counts, invalid/zero/nonfinite
counts, no duplicated progress/paths and hours exceeding 24.

Commands (output directories must not already exist):

```sh
python tools/validate_viewer_status.py --godot /path/to/Godot --output-dir /tmp/issue52-forward --renderer forward_plus
python tools/validate_viewer_status.py --godot /path/to/Godot --output-dir /tmp/issue52-compatibility --renderer gl_compatibility
```

[Machine results](evidence/issue-52/summary.json),
[live Details](evidence/issue-52/live-details.png) and
[completed Details](evidence/issue-52/complete-details.png) retain this review's
evidence. The 1440×900 captures were visually inspected: progress, times and
wrapped paths fit the existing copyable Details surface.

## Failures and limits

The initial sandboxed import encountered local-socket/editor-settings access
errors and exposed a GDScript type-inference error in the new formatter. The
first native run also failed on that compilation error. An explicit boolean
annotation fixed it; the authorized import and final native runs passed without
warnings or errors. Intermediate corrected runs passed 102 checks per renderer
before the final real-worker ETA assertion was added.

This is not an accuracy guarantee for heterogeneous frame costs. ETA uses average
observed throughput including startup and excludes encoding; the stale-progress
threshold is a presentation heuristic, not failure detection. Long/stalled jobs
and invalid counts use deterministic snapshots rather than production runs.
Full 4K/video determinism, real research captures and long-session testing were
not rerun for this presentation-only change. No scientific solver was run.
Native shell layout coverage includes 1440×900 and 1024×640; the retained video
Details screenshots are at 1440×900. No owner acceptance is claimed.

Current `VIDEO_EXPORT.md`, `UX3_STATUS.md` and `CURRENT_STATUS.md` were updated
for this behavior. Existing historical reports and evidence were left untouched.

## Owner verification

1. Open a capture. Use File → Export → Video, choose a new output path and a
   range long enough to observe progress. Start Export.
2. Close the export panel; open Jobs → Video export → Details. Confirm exactly
   one `Rendering frame current / total (percent%)` line, separate live Elapsed
   and Estimated remaining lines, and labeled Output/Temporary files paths.
3. Observe the initial waiting estimate become an approximate render ETA.
   During encoding, confirm that no render ETA is presented as encoding time.
4. Minimize/restore the viewer while exporting. On completion, confirm 100%,
   zero remaining, a valid playable MP4 and a stable terminal elapsed time.
5. Reopen the export via Jobs; confirm its retained details. Attempt the same
   output path and confirm overwrite refusal.
6. Start another export to a new path and cancel through Jobs. Confirm worker
   acknowledgement, actual retained frame count, no ETA and retained temporary
   files. The previous terminal Details record must not become the new job.
7. On your normal desktop scale, inspect wrapping/readability of long paths.
   Review the recorded missing-encoder/failure checks and approximation limits
   before acceptance.

Stop boundary: owner review, merge and Project completion remain with the owner.
