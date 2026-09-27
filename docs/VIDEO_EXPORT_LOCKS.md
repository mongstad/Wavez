# VIDEO-UX-005 — export settings and active-job actions

Issue #125 was the only Ready item on the SimScope Development board when selected.
The owner-created linked branch is
`125-video-ux-005-lock-export-settings-and-simplify-actions-during-active-jobs`.
It started clean at accepted `main` `f867248a87a3f070c6744302027b86103729bbd8`,
which contains owner-merged PR #122. Remote refs were pruned; the previous local
#116 branch was already absent. No branch was created, renamed or switched.
Implementation is **pending owner review**.

## Behavior

The dialog uses its existing `preparing` / renderer PID ownership to lock all
settings while a job is active. Choices/checks/Browse become disabled; number and
path inputs become read-only. Configuration remains visible and the existing
worker snapshot remains immutable. Entering the locked state closes any settings
popup/file chooser; a late file-selection signal cannot replace the active output
path. Reopening from Jobs or the File menu preserves the same locked controls.

Active jobs show **Cancel export** and **Run in background**, with dismiss-only
**Cancel** hidden. In idle and terminal states, **Start Export** and **Cancel**
are shown; **Run in background** is hidden. The primary action reserves its label
width, and the secondary buttons share a minimum width and horizontal position.
No new action, confirmation, job state machine or cancellation protocol was added.
The window-manager close behavior and parent-exit behavior remain unchanged.

Control state is saved once on entry to active work and restored once ownership
ends. This preserves the difference between custom and preset ranges, resolution
and FPS. Controls remain locked through cancellation acknowledgement, even if a
progress message reports a failure while a worker still exists. Success,
PNG-only completion, failure and cancellation all restore normal dialog editing.
Existing diagnostic/result state remains available in the dialog and Jobs.

Only `viewer/video/export_dialog.gd` changes runtime behavior. Worker ownership,
rendering, scientific sampling, timing, source integrity and encoding are untouched.
#97 cancellation confirmation and #124 exit confirmation remain out of scope.

## Validation

Native Godot 4.7.2 (`ed1daf0bf`), Linux, RTX 3070 Ti, FFmpeg/ffprobe. Generated
SIMSCP4 fixtures, movies and full logs remain outside Git in
`/home/Nozba/Codex/SIMSCOPE/video-ux-125/`.

| Focused suite | Backend | Result |
|---|---|---|
| Production status/dialog and real job lifecycle | Forward+ | 164 checks passed |
| Production status/dialog and real job lifecycle | Compatibility | 164 checks passed |
| Accepted #116 actual-dialog startup/integrity regression | Forward+ | 55 checks passed |

Total: **383 passing assertions**, zero final failures. Earlier runs before the
additional custom-policy/second-success cases passed 155 checks on each backend;
those are not added to the final total. Godot import, Python harness compilation
and `git diff --check` also pass. Source fixture hashes remain unchanged.
Machine-readable results are retained in [evidence/issue-125](evidence/issue-125).

The expanded lifecycle test checks every settings widget immediately after launch,
locks during preparation, late picker rejection, background hiding without
cancellation, Jobs reopen, immutable serialized job configuration, preserved
custom/preset editability, completion, PNG-only completion, encoder failure,
cancellation through both controls and Jobs, a subsequent successful export, and
parent-close acknowledgement. Preparation UI cases inject the existing preparation
flag; they are not a new large portable-recipe performance test. Actual video
worker/encoder lifecycle cases use real separate processes.

Active and completed dialog screenshots were visually inspected, and the test
checks equal action-row position/width across launch. Existing viewport-layout
checks cover 1440×900 and 1024×640. No scientific render performance claims are
made. The 118 GiB production benchmark, other operating systems, display scaling
and packaged deployment were not rerun for this dialog-only change.

## Manual owner verification

1. Open a current capture and File → Export → Video. Before launch, verify normal
   editing, **Start Export**, **Cancel**, and no background button. Choose Custom
   range/resolution/FPS to check those numeric inputs; switch back to presets and
   verify their derived inputs remain read-only.
2. Choose a fresh output filename and start a clip long enough to inspect. Confirm
   all controls, including Browse and quota, are locked but visible. Only
   **Cancel export** and **Run in background** should appear in the action row.
3. Run in background, then reopen from Jobs. Confirm the same job/configuration,
   locked controls and active buttons. Let it finish: settings should unlock,
   **Cancel** return, **Run in background** disappear, and result details remain.
4. Change settings/output path and complete a second export. Separately start a
   longer export, click **Cancel export**, and wait for acknowledgement. Confirm
   editing/dismiss returns and cancellation diagnostics remain. Check Jobs
   cancellation as well if desired.
5. The automated failing-encoder case verifies failed-job cleanup without changing
   installed FFmpeg. To repeat it, run `python tools/validate_viewer_status.py
   --godot /path/to/godot --renderer forward_plus --output-dir
   /tmp/simscope-video-ux-review` from the repository, using the installed Godot
   path and a new output directory. Inspect the retained failure diagnostics.

Stop for owner review. Automated passes do not imply owner acceptance.
