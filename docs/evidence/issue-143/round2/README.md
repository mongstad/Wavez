# Round 2 representative slice — pending owner visual review

This evidence extends the unchanged v1 checkpoint at `0d32d08` on #143 / Draft
PR #145. The owner approved the overall violet/dark direction and requested
refinement before broad propagation. Banner styling is subsequently deferred;
the plain SimScope wordmark remains. Build `v0.1.0.10` is still the candidate.

[Reasoning, scope and owner checks](../../../UX5_STYLE_SLICE.md#owner-review--round-2)
and [compact results](summary.json) describe the verified behavior and limits.
Raw native logs, synthetic captures and video jobs remain outside the repository
under `/home/Nozba/Codex/SIMSCOPE/style-143/round2/`; recorded paths identify this
run rather than promising those files in another checkout.

## Screenshots

- [Forward+ 1440×900](forward-1440.png) and [1024×640](forward-1024.png).
- [Compatibility 1440×900](compatibility-1440.png) and [1024×640](compatibility-1024.png).
- [Eight speed presets](speed-presets.png), [playhead seek](seek-playhead.png),
  and [invalid seek feedback](seek-invalid.png).
- [Source details](source-dialog.png), [About](about-dialog.png), and
  [cancellation confirmation](confirmation-dialog.png).
- [Native KDE/Wayland restored window](wayland-restored.png).

These are unedited screenshots of the production UI on small synthetic fixtures.
The confirmation screenshot demonstrates the production dialog's representative
styling; the status suite separately exercises actual active-job cancellation,
No/Yes/Esc/close handling, repeated requests and worker cleanup. Focus rectangles
shown after dialog dismissal are intentional keyboard focus.

## Reproduction

Use externally installed Godot 4.7.2 and FFmpeg. From the repository root, run each
native suite sequentially against both `forward_plus` and `gl_compatibility`,
using a new empty output directory per invocation:

```bash
python tools/validate_violet_round2.py --godot /absolute/path/to/godot --output-dir /tmp/round2-forward --renderer forward_plus
python tools/validate_violet_style_slice.py --godot /absolute/path/to/godot --output-dir /tmp/style-forward --renderer forward_plus
python tools/validate_viewer_transport.py --godot /absolute/path/to/godot --output-dir /tmp/transport-forward --renderer forward_plus
python tools/validate_viewer_shell.py --godot /absolute/path/to/godot --output-dir /tmp/shell-forward --renderer forward_plus
python tools/validate_edge_reveal.py --godot /absolute/path/to/godot --output-dir /tmp/edges-forward --renderer forward_plus
python tools/validate_render_pacing.py --godot /absolute/path/to/godot --output-dir /tmp/pacing-forward --renderer forward_plus
python tools/validate_video_current.py --godot /absolute/path/to/godot --output-dir /tmp/video-forward --renderer forward_plus
python tools/validate_viewer_status.py --godot /absolute/path/to/godot --output-dir /tmp/status-forward --renderer forward_plus
python tools/validate_window_chrome.py --godot /absolute/path/to/godot --output-dir /tmp/chrome-wayland-forward --renderer forward_plus --display-driver wayland
python -m unittest tests.test_application_version
```

The desktop harness additionally requires KDE/KWin, qdbus6, PyGObject and
Spectacle. Run its Wayland and X11 variants on both renderers. It uses PID-scoped
temporary KWin scripts, probes only its own test window, restores/unminimizes
only that window, and captures only when that window is active. It verifies
native geometry/state transitions and the production Close handler. Native
physical pointer dragging, resize feel, snapping, mixed-monitor scaling and 4K
visual quality remain owner checks; routed drag/resize API calls alone do not
establish those results.

Scientific output equality uses an archive of accepted `main` at `61f6a78`,
the same complete generated mixed capture, exact saved state and two half-open
960×540 output frames. Only the output path changes. Compare decoded RGBA bytes
and `timing.jsonl`, rather than encoded MP4 bytes. This is renderer-specific
synthetic evidence; it does not claim universal visual/performance equivalence.
Exact uploaded float32 plane readback is verified only on Forward+.

## Diagnostics and remaining review

Strict startup-log checks initially rejected Compatibility runs that completed
their checks but emitted Godot's cached-shader recompilation warning. Their logs
are retained externally and clean reruns are recorded in the summary. The
Wayland harness retains and allows the system's exact GTK decorator-plugin
initialization warning while rejecting other Godot errors/warnings. The status
suite retains its existing encoder-PID cleanup diagnostics after killing the
synthetic encoder; cancellation and parent-close acknowledgements still pass.

Iteration fixed the native seek editor leaving edit mode after Enter/reopen,
and Wayland dropping maximization or fullscreen restoration after minimization.
An initial X11 harness assertion incorrectly required KWin to clear its
fullscreen flag while minimized. The corrected check permits that platform flag
to remain set, requires actual minimization, and verifies fullscreen on return.
Another X11 run failed the combined visual-state/clock guard after fullscreen
exit. That original run did not record the changed key, so its cause is unknown.
The harness now records exact state differences and clock equality at every
stage; successful diagnostic reruns are retained with the original failed log.
An XTest pointer attempt was inconclusive and is not used as physical-drag
evidence. A temporary speed-label formatting attempt did not complete the
native harness; the final explicit labels and both renderer reruns pass. An
initial pytest invocation was unavailable; the repository's two version tests
were run successfully with unittest. No dependency was installed.

Production GPU utilization/power and large-capture performance were not measured.
Tools/Jobs content and remaining application forms/dialogs await propagation
after owner acceptance. The current slice is not accepted for broad propagation.
No merge, auto-merge, issue closure, Project movement or next issue is performed.
