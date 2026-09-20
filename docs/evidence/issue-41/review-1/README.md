# PR #45 owner-review revision — 2026-09-20

Pending owner review; this is not owner acceptance. Earlier issue-41 evidence is
preserved as written. This revision changes fullscreen presentation and the dock
header wording only. Playback placement (#42) and legacy control migration (UX4)
remain unchanged.

## Diagnosis on the owner's desktop

Fedora Linux 44 KDE Plasma, Wayland session, KWin/Plasma 6.7.5-1.fc44,
Godot 4.7.2 stable (`ed1daf0bf`), NVIDIA RTX 3070 Ti. Monitors: primary
2560×1440 at (0,0); secondary 1920×1080 at (2560,360), both scale 1.
The owner launches **Run in Godot Project Manager**. Its process command was
`/home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --path /home/Nozba/Documents/Codex/SIMSCOPE/SimScope/viewer`.
That executable and the external executable used in validation have identical
SHA-256: `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`.

While the owner left the reported failing state open, a temporary read-only KWin
script observed that specific new viewer PID. [Owner observation](owner-before.json)
shows `fullScreen=true` and identical client, frame and monitor rectangles of
(0,0,2560,1440). This was real compositor fullscreen, not ordinary maximization.
The owner's subsequent screenshot and clarification identified the actual UX
requirement: **the entire SimScope top command bar must disappear in fullscreen**;
maximized mode must retain it. The old fullscreen toggle already used the same
native mode calls as before the shell revision, so those calls are preserved.

## Revised result

Fullscreen now hides the complete command bar, reclaims its 48 logical pixels,
and restores it on exit. Frame scene / Reset camera / Navigate, Exit fullscreen,
and dock hide/recovery remain available. The header says **Hide panel** and only
hides the right-hand contextual dock. Hidden command-bar focus moves to Exit
fullscreen. Asynchronous window configure events schedule a fresh layout pass.
No camera, rendering, playback or legacy inspector controls were changed.

A standalone diagnostic SceneTree loaded the normal `Main.tscn`, with production
processing enabled. It dispatched View menu Enter via `Input.parse_input_event`
(native Wayland) or F11 through the same input API (XWayland), then invoked the
Exit fullscreen button's action. A temporary KWin script filtered the test PID
and independently collected fullScreen, client/frame geometry and the containing
monitor rectangle; scripts were unloaded after each observation. Godot's own
mode report was supporting data, not the proof. Scientific visual-state snapshots
matched before, during and after the transitions.

| Native backend | Fullscreen client = frame = monitor | Top bar / exit | After exit |
|---|---|---|---|
| [Wayland](wayland.json), View menu | (2560,360,1920,1080) | hidden / visible | 1440×900, bar restored |
| [XWayland](xwayland.json), F11 | (0,0,2560,1440) | hidden / visible | 1440×900, bar restored |

Spectacle captured the active native Wayland window, including window-manager
decorations when present; these are not viewport-only captures. XWayland was not
active, so its desktop screenshots were intentionally skipped.

- [Windowed](wayland-windowed.png)
- [Fullscreen — top bar hidden, mouse exit retained](wayland-fullscreen.png)
- [Restored window and command bar](wayland-restored.png)

## Focused regression reruns

Run from the repository root with the existing external Python environment:

```sh
/home/Nozba/Documents/Codex/SIMSCOPE/.venv-dev/bin/python tools/validate_viewer_shell.py --godot /home/Nozba/Documents/Codex/SIMSCOPE/Godot_v4.7.2-stable_linux.x86_64 --output-dir results/issue-41-review-final-forward --renderer forward_plus
/home/Nozba/Documents/Codex/SIMSCOPE/.venv-dev/bin/python tools/validate_viewer_shell.py --godot /home/Nozba/Documents/Codex/SIMSCOPE/Godot_v4.7.2-stable_linux.x86_64 --output-dir results/issue-41-review-final-compatibility --renderer gl_compatibility
```

Both native suites: **97 checks passed**, unchanged synthetic capture hashes.
Includes maximized bar visibility; menu/F11 fullscreen hiding and restoration;
panel recovery with camera controls still visible; scientific-state invariance;
and the existing shell, layout, source replacement and v2/v3 recipe checks.
Reports: [Forward+](shell-forward.json), [Compatibility](shell-compatibility.json).

Limitations/failed attempts: initial synthetic menu input used `push_input` on the
popup and did not activate the item; corrected window-targeted `parse_input_event`
did. An initial normal-scene probe read `current_scene` before the scene-change
signal and failed; the corrected wait passed. Native Wayland logged a libdecor GTK
plugin initialization warning but the window and compositor checks succeeded.
The Gio observer logged a deprecation warning. These are recorded separately
from the warning-free focused shell suite. The first owner observation matched
an older process; the recorded owner-before report uses the newly launched PID.

No full scientific suite, performance benchmark, physical 4K/mixed-DPI or complete
video/FFmpeg matrix was rerun for this presentation-only revision. Broader results
in the original evidence remain historical. Synthetic input/action invocation is
not a substitute for the owner's physical mouse/keyboard acceptance pass.

## Exact owner verification

1. Close/relaunch the viewer through Project Manager **Run** to load this revision.
   Maximize it: the entire top command bar must remain visible.
2. Enter fullscreen via **View → Fullscreen**. Confirm the top command bar is
   completely absent, the native window fills its monitor, and no blank bar-sized
   strip remains. Frame scene / Reset camera / Navigate must remain visible.
3. Click **Hide panel**: only the contextual right dock disappears. Click
   **Show panels** to recover it, then **Exit fullscreen**. The top command bar
   must return and remain usable.
4. Repeat enter/exit with **F11**, both from a normal window and after maximizing.
   Repeat with a representative loaded capture paused; camera settings, rendering,
   playback placement and legacy controls must remain unchanged.

Stop for owner review. No merge, auto-merge, issue closure, board movement or #42 work.
