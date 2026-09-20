# PR #48 owner-review revision

Pending owner review. The earlier issue-43 evidence remains as originally recorded.
This revision fixes the clipped Details focus ring and makes active Jobs Details
follow published progress.

- Status is now 40 logical pixels (or its larger natural minimum), with a normal
  28-pixel compact button, 6-pixel vertical margins and centered controls. The
  theme's external focus expansion remains intact and inside the strip.
- Open job details reads the same in-memory row as the Jobs overview. Video
  notifications refresh that row; other owners use the existing bounded refresh.
  The terminal row is displayed once and then stops updating. Closing/changing
  the details surface or replacing the job ends the watch. No files, processes,
  worker ownership or scientific semantics were added/changed.

Native Fedora KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti:

| Check | Result |
|---|---|
| Status/Jobs Forward+ | [67 passed](forward.json) |
| Status/Jobs Compatibility | [67 passed](compatibility.json) |
| Transport Forward+ | [62 passed](transport.json) |

Both status runs exercise real active export progress, terminal completion and
isolation from a later export; native outline containment and centering at
1440×900 / 1024×640; existing cancellation, error and minimized-parent lifecycles;
unchanged source hashes and zero scientific activity from 1,000 status refreshes.

Screenshots: [focused Details at 1440](focus-1440.png),
[hover and focus at 1024](hover-focus-1024.png), [live export Details](live-details.png).

Commands used `tools/validate_viewer_status.py` with fresh output directories
`results/issue-43-review1-forward2` / `results/issue-43-review1-compatibility`,
and `tools/validate_viewer_transport.py` with `results/issue-43-review1-transport`.
Raw logs/exports stay in ignored results. The first native test stopped on an
unsupported test-only StyleBox method; it was corrected to inspect actual style
expansion margins. Final runs passed. Broader scientific, full video, HiDPI,
mixed-monitor and production-capture suites were not rerun for this UI revision.

Owner checks: Tab to status Details and hover it at both desktop sizes; its entire
outline should fit within the strip. Start a sufficiently long video export,
open Jobs → Video export → Details, and leave it open: progress must update,
then retain the terminal result. Start another export and confirm the prior
terminal detail view does not switch to it. Close/reopen to inspect the new job.
