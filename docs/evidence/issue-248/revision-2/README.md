# Issue #248 owner follow-up evidence

The [initial review evidence](../README.md) remains as captured before this
follow-up. These native Forward+ screenshots show the revised dialog:

- [Idle, normal size](video-groups-idle.png) — Playback rate label and unchanged estimate.
- [Idle, minimum size](video-groups-compact.png) — settings remain scrollable.
- [Output, Advanced collapsed](video-output-collapsed.png) — ordinary controls without PNG retention or inspection options.
- [Output, Advanced expanded](video-output-advanced.png) — optional v1 inspection JSON.
- [Active, minimum size](video-groups-active.png) — progress without duplicated output or temporary paths.
- [Cancellation confirmation](video-cancel-confirmation.png) — retained concise Yes/No prompt.

Wayland scaled the saved pixels relative to the logical dialog dimensions.

## Inspection trace

For ordinary version-1 jobs, `inspection_sidecars` is genuinely optional: the
worker snapshots local visual/source state and writes `inspection-NNNNNNNN.json`
only when true. The dialog keeps this choice under collapsed Advanced when no
selections are present. For selection-aware version-2 jobs, the worker writes a
per-frame v3 inspection record regardless of that flag. It carries exact
selection-frame evidence, recipe reference, image dimensions and PNG hash;
the job created by the dialog now states `inspection_sidecars:true` explicitly.
The optional control is hidden while selections are present.

On successful MP4 publication, dialog jobs use `keep_frames:false` and the
worker removes staged PNGs. Inspection JSON, timing, recipe and diagnostics
remain in the job directory; sidecars identify removed PNGs with
`retained_after_encode:false`. If encoding is unavailable, fails or is
cancelled, the worker retains intermediates for recovery.

## Validation

| Check | Result |
| --- | --- |
| Focused dialog, native Forward+ | 54 checks pass |
| Focused dialog, native Compatibility | 48 checks pass without screenshot capture; an earlier 54-check run printed all checks as passed but stalled during shutdown |
| Video export/Jobs lifecycle, native Forward+ | 324 checks pass; generated source hashes unchanged; successful PNG cleanup confirmed |
| Selection-aware v2 render with one job's `inspection_sidecars:false` | 44 checks pass; mandatory per-frame records verified |
| Video UX regression, native Forward+ | 76 checks, one Wayland minimized-window assertion fails; the worker completed and all changed-setting checks pass |
| Same Video UX regression on accepted `main` | The same 76 checks and minimized-window failure, confirming it predates this PR |

The Compatibility screenshot run was stopped after all assertions printed; an
unchanged retry without screenshot capture exited cleanly. The six retained
screenshots are from the final Forward+ run.

The owner should check the desktop output picker, ordinary Advanced option,
selection-aware Advanced visibility, and a short real export. Packaged Linux
and physical mixed-DPI/4K layout were not run for this dialog follow-up.
