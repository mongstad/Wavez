# Legend first-open positioning — PR #91 review follow-up

Pending owner review. The owner reported legend text underneath the playback panel
on first capture open and requested a position-only fix, followed by a comparison
on the main monitor.

The legend can grow when Godot shapes newly assigned or wrapped text after the
shell's layout pass. The shell now remembers the available scene bounds and
repositions only the legend/colorbar when the label emits `resized`. The callback
does not set any control or panel size. Existing layout sizing is unchanged.

## Reproduction and checks

The initial short-label fixture did not reproduce the owner's exact capture.
A focused late-text-growth regression did reproduce the overlap: disconnecting
the new position callback failed one of four first-open assertions. Reconnecting
it preserves 12-pixel clearance without panel toggles. The test opens a synthetic
particle capture from an empty viewer, shows its scalar legend, then exercises
wrapped text; it verifies dock and playback panel rectangles remain unchanged.
The owner's production capture was not used.

The full native regression includes these four first-open checks plus the prior
visibility, recipe, positioning, immersive and window-restoration checks.
Main monitor: DP-1, 2560×1440, scale 1; native KDE/Wayland, Godot 4.7.2,
NVIDIA RTX 3070 Ti. KWin reports confirm all Forward+ desktop stages on the main
monitor. The successful Compatibility retry performed first-open checks on the
main monitor, but the compositor placed its second viewer (the 16-stage matrix)
on DP-2, 1920×1080. No display settings were changed.

- Forward+: 989 checks and 16 KWin geometry stages PASS.
- Compatibility: 989 checks and 16 KWin geometry stages PASS, with the monitor
  placement distinction above.
- Source hashes unchanged; normal exits.

An earlier unrestricted-monitor full run lost desktop focus after its first-open
checks. The first main-monitor Compatibility run reached all 989 assertions but
lost focus at its final screenshot check. Both were stopped by the screenshot
harness and are not complete passing runs. Existing libdecor GTK fallback and Gio deprecation warnings remain. No
full-suite, video-export or production-capture run was added.

Reproduce the full matrix using the original report's commands with `--screen 0`
and fresh output directories. For the focused four-check comparison use:

```sh
/path/to/godot --path viewer --display-driver wayland --screen 0 --rendering-method forward_plus --audio-driver Dummy --script ui/shell/test_legend_visibility.gd -- --review-capture=/tmp/legend-particles.ssc --first-open-only
```

The focused main-monitor run passed all four checks with exactly 12 pixels of
clearance and unchanged panel rectangles. A `--screen 1` comparison request was
ignored by the compositor: the geometry log still identified screen 0 at (0,0),
2560×1440. It is not evidence of a secondary-monitor comparison. Always verify
actual placement in the logs rather than assuming the screen request was honored.
Historical reports/evidence remain unchanged; new results are in
`docs/evidence/issue-85/initial-layout/`.

Owner check: launch fresh on the main monitor, open the capture, and enable its
scalar legend without toggling panels. All legend text should clear the playback
panel. Repeat with the right panel hidden and in Immersive, then exit Immersive.
Panel and control sizes should remain as before.
