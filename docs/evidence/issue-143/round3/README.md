# Round 2 review corrections — pending owner review

The owner reviewed `b9a2df3` and requested corrections before approving broad
propagation. This evidence is a new round on #143 / Draft PR #145. It preserves
the v1 `0d32d08` and Round 2 `b9a2df3` checkpoints, all 20 earlier evidence files,
and the complete earlier style-document text unchanged. Build `v0.1.0.10` remains
the candidate against accepted main `61f6a78` (build 9).

[Reasoning and exact owner checks](../../../UX5_STYLE_SLICE.md#owner-review--round-2-corrections)
and [compact results](summary.json) cover coherent disclosures, violet sliders,
whole-second seek clocks, native Fullscreen Tools dispatch and filename privacy.
Raw native logs, generated captures and export jobs remain outside the repository
under `/home/Nozba/Codex/SIMSCOPE/style-143/round3/`. Recorded absolute paths identify
this run; they are not repository assets.

## Unedited production screenshots

- Corrected panel and bottom filename: [Forward+ 1440×900](forward-1440.png),
  [Compatibility 1440×900](compatibility-1440.png),
  [Forward+ 1024×640](forward-1024.png), [Compatibility 1024×640](compatibility-1024.png).
- [Violet Exposure/Gamma](violet-exposure-gamma.png),
  [minimal playhead seek](seek-playhead.png), [malformed input feedback](seek-invalid.png),
  [input beyond a fractional recording endpoint](clock-invalid-end.png).
- Tools opened through the edge-revealed native Fullscreen toolbar:
  [Performance on X11](fullscreen-performance-x11.png),
  [Mapping on Wayland](fullscreen-mapping-wayland.png),
  [Source probe on Wayland](fullscreen-source-probe-wayland.png).

These are small complete synthetic captures. Fullscreen screenshots come from
actual native Fullscreen windows, with existing application-owned embedded
dialogs. Tools content remains outside broad style propagation.

## Reproduction

Use externally installed Godot 4.7.2 and FFmpeg. Run sequentially on both
`forward_plus` and `gl_compatibility`, with fresh output directories. The new
Fullscreen suite should additionally run on both `x11` and `wayland`:

```bash
python tools/validate_violet_review_corrections.py --godot /absolute/path/to/godot --output-dir /tmp/corrections-forward-x11 --renderer forward_plus --display-driver x11
python tools/validate_violet_round2.py --godot /absolute/path/to/godot --output-dir /tmp/round2-forward --renderer forward_plus
python tools/validate_violet_style_slice.py --godot /absolute/path/to/godot --output-dir /tmp/style-forward --renderer forward_plus
python tools/validate_viewer_transport.py --godot /absolute/path/to/godot --output-dir /tmp/transport-forward --renderer forward_plus
python tools/validate_viewer_shell.py --godot /absolute/path/to/godot --output-dir /tmp/shell-forward --renderer forward_plus
python tools/validate_edge_reveal.py --godot /absolute/path/to/godot --output-dir /tmp/edges-forward --renderer forward_plus
python tools/validate_render_pacing.py --godot /absolute/path/to/godot --output-dir /tmp/pacing-forward --renderer forward_plus
python tools/validate_video_current.py --godot /absolute/path/to/godot --output-dir /tmp/video-forward --renderer forward_plus
python tools/validate_viewer_status.py --godot /absolute/path/to/godot --output-dir /tmp/status-forward --renderer forward_plus
python -m unittest tests.test_application_version
```

The correction suite clicks the production MenuButton after the real 10px dwell
route reveals the bar, selects the existing PopupMenu command with Enter, checks
visible forms/bounds/focus and closes each through its focused Close button.
Performance, Mapping and Source probe run while the root native mode is
Fullscreen; View → Global effects and Help → Shortcuts cover additional Window
and AcceptDialog routes. Exact scientific state, camera/clock and saved
pins/visibility/timers are checked across the round trip. It also checks rebuilt
Fields/Meshes disclosure routing, filename tooltip
ancestry, nonzero/fractional source origins and fractional capture-end validation.
The adapted Round 2 suite retains both seek double-click gestures, native Enter,
Esc, click-away, dragging, speed presets and window/camera actions. Fractional
controller regression coverage remains separate from the whole-clock editor.

Scientific comparison uses all 437 tracked viewer files archived from accepted
main `61f6a78`, verified byte-for-byte in this round. The same complete mixed
capture and exact scientific export job run on baseline and candidate, changing
only the output path. Decoded RGBA frames and `timing.jsonl` are compared per
renderer. Exact GPU float32 plane readback remains a Forward+-only assertion.

## Diagnostics and limits

The first editor import caught a GDScript Variant-inference error in the clock
formatter; explicit floating-point typing corrected it. The first new test run
used incorrect test-only command/title names for Global effects/Shortcuts; those
assertions were corrected against the existing menu bindings. Final native
interaction checks pass.

Strict log checks rejected cached-shader recompilation warnings on the first
Compatibility Wayland and broad-shell runs. Clean reruns are retained separately;
the warnings were not silently accepted. The native Wayland harness records and
allows only the exact existing GTK decorator initialization warning. Status
validation retains the existing encoder-PID cleanup diagnostics while checking
cancellation and parent-close acknowledgement.

The paused suite explicitly permits live Performance diagnostics to settle.
One Forward+ Performance phase recorded one redraw and changed UI pixels; all
static paused phases stayed stable, and every phase's clock/camera and retained
versus forced full-quality render checks passed. The summary records actual
per-renderer draw counts rather than assuming every diagnostic phase was static.

Physical pointer drag/resize feel, KDE snapping, 4K/mixed-monitor quality and
production GPU power/utilization were not remeasured. The previous Round 2
desktop-chrome evidence and its inconclusive initial X11 state guard remain
historical; this round adds Fullscreen dialog coverage rather than rerunning
all desktop minimize/resize stages. Generated-file and renderer-specific equality
do not establish universal production performance. Broad Tools/Jobs/form/dialog
styling remains deferred. Draft PR #145 awaits owner review; no propagation,
merge, Ready transition, issue closure or auto-merge is authorized.
