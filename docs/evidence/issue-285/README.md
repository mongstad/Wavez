# Video Export ETA evidence — issue #285

Candidate `v0.1.0.68`, pending owner review. The first/only Ready issue was #285;
its exact owner-linked branch was checked out and clean at accepted `main`
`a39d9ca` (PR #282 merged). Fetch/prune found no completed branch left to remove.
No branch was created or switched and no Project transition was performed.

## Result

The export dialog and Jobs Details share a presentation-only frame-cost estimate,
with five-second time-weighted smoothing and a 500 ms display cache. ETA stops
rising between unchanged worker snapshots. Job/stage changes invalidate it
immediately. No timer, callback, file read or worker polling was added. Counts,
elapsed, paths and diagnostics retain the existing formatter behavior.

[Machine summary](summary.json) and individual matrix records retain exact counts:

| Final gate | GDScript checks | Python checks | Result |
|---|---:|---:|---|
| Development Forward+, 210.760 s export | 52,728 | 33 | PASS |
| Linux release Forward+, 210.493 s export | 52,718 | 33 | PASS |
| Development Compatibility, short lifecycle | 52,601 | 33 | PASS |
| Linux release Compatibility, short lifecycle | 52,597 | 33 | PASS |
| Final headless presentation snapshots | 13,124 | — | PASS |
| Application version | — | 2 | PASS |
| Python compile / whitespace / final Godot import | — | — | PASS |

The repeated snapshot checks are numerical/publication cases, not independent
end-user scenarios. Matrix counts vary with the number of observed encoding
polls; the final headless gate also covers changed totals and regressing frame/time
snapshots. Both long exports produce 120 H.264 frames at 320×180/60 FPS. Decoded
source/release RGB pixels match exactly ([hash comparison](pixel-comparison.json)).
All observed frame/percentage lines match worker counts; terminal elapsed matches
the worker's frozen value; timing.jsonl retains exact n/FPS video/capture times;
source WVZ1 hashes are unchanged.

Over 6,000 synthetic 100 Hz jittering publications, raw ETA replacement count is
247; the new shared estimate changes 89 times, with at least 500 ms between
numeric changes. Identical snapshots keep a stable ETA while live elapsed advances.
Five seconds of sustained slower frame cost changes the estimate from 550 to
894 seconds; sustained faster cost changes it from 550 to 260 seconds. The tests
also cover stage transitions, stale suppression/recovery, invalid counts/time,
new job identity, initial waiting and hours beyond 24. One thousand duplicate
actual UI refreshes leave the Details TextEdit version/text untouched.

Each matrix exercises real worker completion, rendering cancellation, encoding
cancellation and encoder failure. Background/reopen retains the original worker.
Encoding removes the render ETA immediately; complete/cancelled/failed states
remain stable. Linux release runs use a baked parent test entry and a dialog
subclass supplying only the existing delay field. Children use the same release
executable/PCK, unchanged Main.tscn and unchanged production worker. Staging is
removed before execution; cwd/profile are isolated, no editor is on PATH.

The long runs externally pace the real child with SIGSTOP/CONT between frame
publications. Parent/UI processing remains normal. This establishes more than
three minutes of visible automated progress under controlled load; it is not a
benchmark of naturally expensive scientific rendering. Fast thousands-of-frame
cadence and sustained throughput shifts use deterministic snapshots. Godot and
FFmpeg are external; no third-party runtime or generated capture is committed.

## Images

The individual embedded-window captures were visually inspected: headings,
progress/time lines and wrapped paths remain readable and unobstructed. Cancellation
retains the copyable scrollable diagnostic surface.

| State | Development | Linux release |
|---|---|---|
| Live Details | [image](source-long-live.png) | [image](release-long-live.png) |
| Complete Details | [image](source-long-complete.png) | [image](release-long-complete.png) |
| Encoding cancelled | [image](source-long-cancelled.png) | [image](release-long-cancelled.png) |

## Failures, corrections and limits

Initial harness runs are not passing evidence: the default sandbox user-log
location was unwritable; the test delay counted fixed-FPS simulated time rather
than wall time; short jobs could skip the sampled rendering state; two modal
surfaces overlapped; and a screenshot attempted to read a hidden window texture.
Isolated profiles, external pacing, longer cancellation observation, modal
sequencing and reopening terminal Details corrected these harness failures.

An initial assertion expected elapsed to stay monotonic across launch/worker and
terminal handoffs. Existing presentation advances elapsed between publications,
then adopts the worker's own clock/final frozen value, so those handoffs can lower
a whole-second display. This unchanged contract was retained; final checks compare
non-ETA formatting, worker values and exact terminal elapsed rather than imposing
a new clock policy.

The accepted-main encoder PID cleanup diagnostic remains during encoding
cancellation, as established by issue #93's baseline. Each matrix records four
log occurrences: two engine events duplicated in parent and renderer logs.
The runner allows only the exact retained encoder PID/source diagnostic; there
are no other native warnings/errors in the final runs. No lifecycle fix is claimed.
Initial import regenerated five unrelated missing UID sidecars from cache;
the warm final import is clean and those incidental untracked files were removed.

No full camera/playback/analysis/scientific suite was rerun: modified runtime
paths are ETA presentation and status text assignment only. Natural expensive
research captures, multi-hour sessions, 4K/mixed-DPI/physical-display/input checks,
Windows/macOS and continuous human observation of flicker remain untested. Static
screenshots and automated traces support the candidate; owner perceptual review
on normal load/desktop scale remains required. Historical evidence was preserved.

## Reproduce and review

See [implementation, commands and exact owner verification](../../VIDEO_ETA.md).
Current VIDEO_EXPORT.md, UX3_STATUS.md and CURRENT_STATUS.md document the new
cadence. The owner controls final acceptance, merge, branch deletion and Project
completion. The agent stops after pushing this existing branch and opening one PR.
