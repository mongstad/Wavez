# UX3-FULLSCREEN-001 — Immersive fullscreen

Current integration status: the slice is owner-merged; the [#44 milestone report](UX3_REPORT.md)
is pending owner review. Original issue review metadata and evidence below remain historical.

Issue #46. Implementation pending owner review. This extends the accepted
interactive fullscreen shell without changing the scientific or playback model.

## Modes and recovery

| Action | Persistent application chrome | Exit |
|---|---|---|
| Maximize using the window manager | Normal command bar, dock, transport/status | Window manager restore |
| View → Fullscreen / F11 | Command bar hidden; camera controls, dock/recovery, transport/status/Jobs remain | Exit fullscreen button / F11 |
| View → Immersive fullscreen / Shift+F11 | None | Esc; F11 or Shift+F11 also restore the preceding mode |

Interactive fullscreen remembers the native mode from each entry. F11 and the
mouse Exit fullscreen button return to maximized when entered from maximized,
or to the preceding manual window geometry when entered from windowed mode.
Geometry remains owned by the window manager. An intervening immersive round
trip preserves this interactive return mode. This is session-only state; see
[#86 validation and owner checks](FULLSCREEN_RESTORE_VALIDATION.md).

Immersive briefly shows **Press Esc to exit fullscreen** centered near the top.
It disappears after three seconds, does not accept focus or intercept the pointer.
Esc restores the immediately preceding native windowed, maximized or interactive
fullscreen mode. Dock preference, workspace, scroll and valid previous focus are
retained; responsive layout adapts to the restored window size. An external
compositor fullscreen exit restores usable chrome without re-entering fullscreen.
A rejected native fullscreen request also recovers chrome after a short grace period.

Focused text/numeric entry suppresses the entry shortcut. Immersive releases hidden
control focus. Esc recovery is handled before the normal GUI/inspection/selection
input guards. F1 cannot expose or change the dock while immersive. Existing camera
and playback shortcuts remain available; toggling chrome does not pause playback,
seek, reset/frame the camera, change speed, or change render settings.

## Scientific overlays, screenshots and exports

Only application controls are hidden. The existing colorbar/particle legend,
scene guides, probe markers and selection/analysis overlays retain their current
visibility. Immersive does not enable a hidden legend. In particular it does not
set the recipe's `overlay_visible` to false: that existing field also participates
in scientific legend visibility. Inspector HUD/readiness labels belong to the
application dock and disappear with it. The screenshot completion toast is also
suppressed while immersive; its status remains available after leaving the mode.

PNG retains its existing **current visible viewport** behavior and sidecar/state
semantics. A PNG taken during the three-second hint includes that hint; wait for
it to disappear for a clean view. Entering immersive does not rewrite the saved
scientific presentation, add recipe fields, or change offline video/numerical
export behavior. Video UI inclusion follows the explicit [export overlay contract](../VIDEO_EXPORT.md),
which reuses the production shell independently of desktop visibility.
Fullscreen is session-only and is not a new export preset.

## Validation and owner review

See [issue-46 evidence](evidence/issue-46/README.md) for exact runs, native geometry,
images, source integrity and limitations. The desktop harness uses the physical
Fedora KDE/Wayland session, synthetic Godot input, a PID-scoped temporary KWin
script and Spectacle screenshots. KWin must report fullscreen **and** matching
client/frame/output rectangles; a Godot mode value alone does not pass.

Owner verification before acceptance:

1. Launch SimScope using Godot Project Manager **Run** with a particle/volume
   capture. Set a recognizable camera, volume settings and playback position.
2. Maximize: the top menu remains. Use View → Fullscreen and separately F11:
   confirm native fullscreen with camera controls, dock, transport/status and
   mouse Exit fullscreen. Hide/reopen the dock.
3. From a normal window choose View → Immersive fullscreen. Confirm the hint,
   wait three seconds, then confirm no application chrome. Orbit/zoom and press
   Esc: the prior window and controls return, keeping your camera interaction.
4. From interactive fullscreen press Shift+F11, then Esc: interactive fullscreen
   returns. Repeat from maximized and dock-hidden states. Tab/Enter after exit
   must work on visible controls; numeric/text entry must not trigger entry.
5. Repeat with a scientific legend disabled, then explicitly enabled, and with
   probe/selection overlays. Their visibility must not change on mode entry/exit.
6. Play through cached and uncached frames, enter/exit immersive, and confirm
   playback continues with the same speed and can still be paused. Recheck the
   sample, source, volume controls, selections and recipes after leaving.
7. While immersive, use KDE's window action to leave fullscreen. Confirm the
   normal shell recovers. Capture a PNG after the hint and run a short existing
   video export: PNG reflects the current view; export settings/timing remain.
