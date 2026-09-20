# Adaptive duration formatting

Pending owner review in PR #51. Elapsed, total and remaining share a pure display
formatter: `43.7`, `1:12.4`, `1:04:27.3`. Remaining adds `-` except at rounded zero.
The value is rounded to tenths before splitting units, allowing clean minute/hour
carry. No stored time, sampling, speed, seek, slider or export behavior changes.

Native Fedora KDE/Wayland, Godot 4.7.2:

- Forward+: **182 checks passed**, source hashes unchanged ([report](forward.json)).
- Compatibility: **182 checks passed**, source hashes unchanged ([report](compatibility.json)).
- 30 formatter assertions cover positive/remaining values at zero, sub-tenth zero,
  43.7, 59.9, 59.94, 59.96, 60.0, 72.4, 763.6, 3599.9, 3599.94, 3599.96,
  3600.0, 3867.3 and 36000.0. Existing transport regressions remain included.
- Whitespace and documentation-link checks passed. No failed focused checks.

Commands use `tools/validate_viewer_transport.py --godot "$GODOT"` with renderers
`forward_plus` / `gl_compatibility` and output directories
`results/issue-49-format-forward` / `results/issue-49-format-compatibility`.
Broader state/video suites were not repeated for this pure presentation change.
Historical evidence remains unchanged.

Owner check: seek near minute/hour boundaries on a sufficiently long capture,
verify elapsed/total formatting and toggle remaining. Exact source time should
remain unchanged in the tooltip and Seek editor. Acceptance remains with owner.
