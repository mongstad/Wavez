# UX3 persistent status and Jobs — issue #43

Current integration status: the slice is owner-merged; the [#44 milestone report](UX3_REPORT.md)
is pending owner review. Original issue review metadata and evidence below remain historical.

Implemented, **pending owner review**. #43 was the only Ready Project item.
The owner's linked branch
`43-ux3-status-001-implement-persistent-status-readiness-and-jobs-access`
started at accepted `main` `a976ec6` (PR #47). Its previous local issue branch
was already absent; the stale remote reference was pruned. No acceptance-only
branch/PR was created. Historical reports/evidence remain unchanged.

## Presentation and ownership

The shell now has a 40-logical-pixel status line below the existing 64/104-pixel
transport. A full 32-pixel **Jobs (N)** button joins the transport options.
Both remain visible with the dock hidden and in interactive fullscreen. The status
controls are vertically centered with padding for the unchanged theme focus ring,
including its outside expansion; normal, hover and focus states fit in the strip.
The scientific viewport, projection, rendering, sampling and clocks are unchanged.
Offline viewers construct the same production shell after #55/#59. Their automatic
presentation processing is disabled; the video worker refreshes it explicitly
after committed samples under the [export overlay contract](../VIDEO_EXPORT.md).

Status reads existing open/loading, particle/field/mesh readiness and committed
layer availability. No capture, Preparing…, Ready and Unavailable are distinct.
There are no fabricated percentages or combined memory totals. A separate durable
failure notice survives informational status changes and later successes. Details
provides current readiness, per-controller memory/status text and retained errors.
Jobs has explicit acknowledgement; Dismiss on the existing open-error banner
acknowledges only that open failure. Inline form validation stays contextual.

Jobs is a presentation adapter, not a task scheduler. It composes video export,
selection queries, background analysis/recipe/export work, matched rendering and
isosurface extraction. Preparing a video's selection recipe is counted once.
Reopening invokes the existing panel/form. Cancelling calls the existing owner
callback, including selection/analysis revision/overlay guards. Completed analysis
results and scientific controls stay in their original forms; UX4 migration is
not part of this issue.

The video dialog publishes its existing in-memory progress and latest terminal
snapshot. Jobs does not read progress files or poll processes a second time.
Running/preparing jobs reopen without resetting their forms. Idle video forms
use the canonical open path to refresh the current capture timeline; their
terminal diagnostics and separate Jobs snapshot remain available. Progress,
completed output, job/intermediate paths and diagnostics are retained. An open
Jobs Details view follows the same published in-memory row while its job is active,
including video progress notifications. It displays the terminal state once and
then stops updating; a later/replacement job cannot overwrite that record. Closing
it or opening a different details surface also ends the subscription. No file
polling or worker ownership is added.
Video Details uses the export dialog's shared presentation formatter: one
frame/percentage line, separate elapsed and approximate render-only remaining
time, and labeled Output/Temporary files paths. The existing 5 Hz refresh advances
wall time from the published snapshot; no additional file polling is used.
See [video progress semantics](../VIDEO_EXPORT.md) for initial, stale-progress,
encoding and terminal states.
Cancellation acknowledgement, parent shutdown, overwrite refusal, separate
worker architecture and FFmpeg recovery are unchanged. The worker taskbar entry
remains a KDE/Wayland platform limitation.

Failures are bounded session notices (latest per owner), not a persisted audit
history. Repeated failures replace that owner's retained diagnostic. Explicit
acknowledgement removes the notice; a still-unavailable source remains Unavailable.
Newly reported failures are shown again. Latest video details remain until the
next submitted export; on-disk worker files remain governed by existing cleanup.

Readiness refresh is capped at 5 Hz, with additional existing video progress
notifications. Widgets are constructed once. This adapter reads cached controller
fields and labels, never worker caches, files, sources or geometry. Particle
readiness exposes the error already read by its existing update path. No new
source scans, hashes, decoding, uploads, scientific jobs or persisted fields are
introduced. This UI has a small measured CPU cost, not a claim of literally zero
CPU cost or universal performance.

## Validation and limitations

The [owner-review revision](evidence/issue-43/review-1/README.md) records focus
containment and live Details coverage. See [original focused evidence](evidence/issue-43/README.md) for final counts and recorded
failures/skips. Native tests run on Fedora KDE/Wayland with Godot 4.7.2 and NVIDIA
RTX 3070 Ti, using small existing mixed-cadence fixtures, not solver reruns.
Native window state plus real worker output validates minimized-parent export;
it is not manual owner acceptance of every desktop interaction.

The task does not claim #44 integration/milestone acceptance, UX4, exhaustive
analysis/matched job permutations, all scale factors, mixed-monitor behavior,
long-session memory/performance, or production-scene benchmark parity.

## Owner verification

1. Launch standalone from Godot Project Manager **Run**. At 1440×900 and
   1024×640, confirm status text, transport and Jobs fit without clipping.
2. Open a normal retained `.ssc`; seek to a cold region and rapidly replace the
   target. Preparing must become Ready for the latest request; displayed time
   must stay committed until ready. Hide the dock and enter/exit fullscreen:
   status, Jobs and mouse recovery remain available.
3. Try a corrupt/non-capture file. Confirm the prior scene remains usable, the
   error survives unrelated information and details remain copyable. Dismiss
   that error or use Jobs → Acknowledge failures and confirm it clears.
4. Export a short video to a new path. Close the export panel, minimize/restore
   the main viewer, open Jobs, and reopen the same export. Confirm progress,
   one active video count, successful output and retained details. Reusing the
   same output must be refused without overwriting it.
5. Start another export; Cancel from Jobs and wait for acknowledgement. Inspect
   the retained intermediate directory and renderer/encoding diagnostics.
   Close the parent during a separate test export and confirm cancellation.
6. Start a selection query or analysis through its existing form; reopen it from
   Jobs and cancel. Confirm existing selections/results remain, and reopening
   alone neither submits nor cancels work. Check an existing matched-view or
   isosurface workflow when available.
7. Review failure/recovery screenshots and verify readability at your normal
   desktop scale. Owner review controls acceptance and merge.
