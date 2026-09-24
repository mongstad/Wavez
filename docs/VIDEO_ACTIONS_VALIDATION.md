# Video export actions — issue #65

Implemented on the existing owner-linked branch
`65-video-export---change-button-contenttext`, pending owner review. #65 was the
only Ready issue verified on 2026-09-24. HEAD, local main and origin/main began at
`a3c6c50`, the owner-merged PR #89. Fetch/prune completed, the tree was clean, and
the previous local issue branch was already absent. No additional dependency is
specified by #65.

## Behavior

The dialog has three actions:

| Action | Behavior |
|---|---|
| Start Export / Cancel export | One button dispatches to the existing start or worker-cancel operation according to the active process. |
| Run in background | Enabled only while an export is preparing or has an active worker; hides the dialog without restarting or cancelling work. |
| Cancel | Closes only the dialog. Its tooltip states that active work continues. |

The primary action is disabled while selection-recipe preparation is pending,
because the existing renderer cancellation operation is not yet available.
Background and dialog-close actions remain available. Reopening during preparation
preserves the current draft/timeline. On termination, the primary action returns
to Start Export and background becomes disabled. An unavailable capture disables
Start Export. Worker launch, published progress, encoding, cancellation markers,
parent-shutdown cancellation and output rules retain their existing ownership.

## Validation

Godot 4.7.2, NVIDIA RTX 3070 Ti, synthetic SIMSCP3 fixture:

- Forward+: **121 checks PASS**.
- Compatibility: **121 checks PASS**.
- Capture SHA-256 unchanged and parent-close cancellation acknowledged on both.
- Final Godot import and Git whitespace checks passed.
- No final test failures, script errors or warnings.

The native status suite exercises the primary button to launch and cancel real
workers; both idle and running Cancel dialog-close actions; Run in background;
Jobs reopening and cancellation; live Details/ETA; minimized continuation;
completion; missing/failed FFmpeg; overwrite refusal; stable terminal records;
and shutdown. It checks exactly three action buttons, idle/running/terminal
enabled states, and that the row is reachable through the existing scroll area.
Preparation presentation is tested by controlled state injection without launching
an analysis-preparation worker. Earlier runs passed 119 checks per renderer before
the two scroll-reachability assertions were added.

[Machine summary](evidence/issue-65/summary.json),
[idle action row](evidence/issue-65/export-idle.png), and
[running action row](evidence/issue-65/export-running.png).
Both screenshots were visually inspected after scrolling to the action row.

```sh
python tools/validate_viewer_status.py --godot /path/to/Godot --output-dir /tmp/video-actions-forward --renderer forward_plus
python tools/validate_viewer_status.py --godot /path/to/Godot --output-dir /tmp/video-actions-compatibility --renderer gl_compatibility
```

Output directories must be new. No full 4K/export-determinism suite, production
research capture, cross-platform desktop or real selection-recipe preparation
run was repeated for this dialog-action change. The existing scroll layout and
button styling were retained. Scientific solvers were not run. Current video and
status documentation was updated; historical reports and evidence were untouched.

## Owner verification

1. Open a capture and File → Export → Video. At the action row, confirm Start
   Export, disabled Run in background, and Cancel. Cancel should close the dialog.
2. Reopen, select a new output path and start a sufficiently long export. Confirm
   the same primary button says Cancel export and Run in background is enabled.
3. Click Run in background, then reopen through Jobs. Confirm the original export
   continues. Click Cancel to close the dialog; confirm it also leaves work running.
4. Reopen and click Cancel export. Confirm the normal cancellation acknowledgement
   and retained temporary files; Start Export returns and background is disabled.
5. Start another short export and let it complete. Confirm a valid MP4, terminal
   Details, restored Start Export, disabled background, and normal overwrite refusal.

Owner acceptance and merge remain pending; stop after this review handoff.
