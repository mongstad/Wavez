# Active Pause during buffering

Pending owner review in PR #51. During active playback, transport and particle,
field and mesh readiness updates leave Pause enabled. The existing toggle now
allows pausing during a buffering wait; paused Play still refuses to resume until
ready. Empty-source and inspection guards remain. Frame preparation, committed
clock behavior and cache ownership are unchanged.

Native Fedora KDE/Wayland, Godot 4.7.2:

- Forward+: **188 transport checks passed**, source hashes unchanged ([report](forward.json)).
- Compatibility: **188 transport checks passed**, source hashes unchanged ([report](compatibility.json)).
- Headless readiness maintenance: **66 passed**; playback lifecycle: **51 passed**.
- Six new assertions hold a real worker publication barrier, exercise all three
  readiness UI writers, verify active Pause/icon/tooltip, click Pause, and verify
  premature resume is refused. Existing startup/cold-seek guards remain covered.
- Whitespace/local documentation links passed. No failed focused checks.

Commands use `tools/validate_viewer_transport.py --godot "$GODOT"` with
`forward_plus` / `gl_compatibility` and output directories
`results/issue-49-pause-forward` / `results/issue-49-pause-compatibility`.
`tools/validate_performance_maintenance.py --godot "$GODOT" --renderer headless
--output-dir results/issue-49-pause-maintenance` runs the readiness/lifecycle cases.

No large-capture, full scientific or video reruns for this button interaction.
Earlier reports remain historical. Owner check: play through uncached frames;
Pause must stay enabled without flickering. Click it while waiting, confirm
playback pauses, and resume after readiness returns.
