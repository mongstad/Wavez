# Transient seek status delay — issue #53

Implemented, **pending owner review**. #53 was the sole Ready item. Its exact
owner-linked branch `53-ux3-transport-003-delay-transient-seek-status` started clean
at accepted main `195bd9053182800924484f488c66d62074a4bd91` (PR #51). Local main and
origin/main matched it. The prior local issue branch was already absent; its stale
remote reference was pruned. No acceptance-only branch/PR or Project write occurred.

## Presentation contract

Requested time below the slider waits **450 ms** before appearing. A request that
resolves before then never shows this label. Once shown, it remains until the
published request resolves, is replaced/cancelled, or reports a preparation error.
A replacement starts a fresh delay and clears both old text and its exact tooltip.
Changing the capture generation also resets the delay. Explicit Go resets the
presentation timer even when resubmitting the same target. An edited draft does
not reset the already submitted request. Same-target preparation across layer
controllers remains one continuous wait.

The transport observes existing published pending targets and errors on refresh,
using the monotonic Godot clock. No worker polling, timer callback, I/O or new job
owner is introduced. The fixed readout area remains outside container sizing.
Only this label is delayed: the status strip/readiness, underlying seek, committed
and requested clocks, source timestamps, cache preparation, Pause availability,
sampling, Hold/interpolation, recipes and export remain unchanged.

## Threshold choice

Native scripted waits of 100 ms and 350 ms stayed hidden; a 550 ms wait displayed
the status. A real cold worker barrier measured actual first visibility near the
450 ms threshold in both renderers; exact measurements are in the evidence.
450 ms suppresses the split-second waits exercised here while giving feedback
before a sustained 550 ms wait finishes. A 300 ms threshold would expose the
350 ms case briefly; a 600 ms threshold would hide the entire 550 ms case.
Those candidate comparisons are an inference from the measured wait durations,
not a claim of a production workload benchmark or owner usability acceptance.

## Validation and owner review

[Focused native evidence](evidence/issue-53/README.md) includes delay boundaries,
real cached and cold seeks, latest-target replacement, failure/cancellation,
geometry, playback controls and the existing scientific regression baseline.
Historical #49 evidence remains unchanged.

1. Play through short uncached waits. Requested time should not flash; readiness
   and Pause remain immediately available as before.
2. Cold-seek to an uncached target taking more than half a second. The label should
   appear after roughly 450 ms, then disappear when the latest scene commits.
3. While visible, replace the target rapidly. Old text must disappear immediately;
   only the final target may appear after its own delay. Editing without Go must
   leave the submitted target unchanged.
4. Cancel/reset the pending operation or open another capture. No old label should
   remain. Existing failure details must still be accessible on failure.
5. Check normal/compact windows, dock hidden and fullscreen: geometry remains stable,
   exact Seek/tooltips and elapsed/remaining still describe committed source time.

The owner controls acceptance/merge. No later Ready or backlog issue is included.
