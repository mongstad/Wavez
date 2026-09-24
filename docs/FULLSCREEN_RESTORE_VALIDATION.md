# Fullscreen return mode — issue #86

Implemented on the existing owner-linked branch
`86-fullscreen-restore-should-preserve-maximized-window-state`, pending owner
review. #86 was the only Ready issue verified on 2026-09-24. The branch, local
main and origin/main began at `7e656e2`, the owner-merged PR #87. Fetch/prune was
completed; the tree was clean and the previous local branch was already absent.
No additional predecessor dependency is specified by #86.

## Behavior

Interactive fullscreen previously always requested windowed mode on exit.
It now remembers the native mode immediately before each entry and restores that
mode through either F11 or the mouse Exit fullscreen button. Window geometry
remains owned by Godot/the window manager. The return mode is session-only and
does not enter recipes or export state. No rendering or scientific code changes.

Immersive's separate immediate return mode remains unchanged. Entering immersive
from interactive fullscreen and exiting with Esc returns to interactive fullscreen;
the subsequent fullscreen exit still returns to the original maximized/manual mode.

## Reproduction and validation

Using the original windowed-exit behavior with the new harness reproduced the
reported bug on KDE/Wayland: `max-restored-0` reported windowed mode 0 instead of
maximized mode 2. KWin independently reported a 1100×700 client rather than the
preceding maximized 2560×1370 client. The fixed behavior passed the same check.

Godot 4.7.2 on NVIDIA RTX 3070 Ti, physical 2560×1440 KDE/Wayland output:

| Run | Result |
|---|---|
| Forward+ | 51 checks, 16 KWin geometry stages PASS |
| Compatibility | 51 checks, 16 KWin geometry stages PASS |
| Source integrity | Synthetic SIMSCP3 SHA-256 unchanged in both runs |
| Final Godot import | PASS; new test UID tracked |
| Python syntax and Git whitespace | PASS |

Coverage includes:

- Manual 1100×700 → fullscreen via F11 → mouse exit, with exact restored native geometry.
- Maximized → fullscreen → F11 exit; repeated entry and mouse exit.
- Menu fullscreen entry, nested Shift+F11 immersive entry and Esc recovery,
  then mouse exit restoring maximized geometry.
- Restore from maximized, resize to 1200×760, menu fullscreen entry and F11 exit.
- Maximize again and a direct immersive/Esc round trip.
- Unchanged scientific visual state and committed sample at every checkpoint.
  Responsive panel width is excluded because it intentionally adapts to window size.

KWin must independently confirm fullscreen and exact frame/client/output geometry
while fullscreen. On restoration, frame and client rectangles must exactly match
the corresponding pre-entry reference. Checks target only the test process PID;
the temporary KWin script is unloaded after each probe.

[Summary and reproduced baseline failure](evidence/issue-86/summary.json),
[Forward+ stages](evidence/issue-86/forward_plus.json),
[Compatibility stages](evidence/issue-86/gl_compatibility.json), and
[restored maximized screenshot](evidence/issue-86/maximized-restored.png).
The restored screenshot was visually inspected for normal chrome and native
maximized window geometry.

Reproduce with a small SIMSCP3 fixture (output directory must be new):

```sh
python tools/validate_immersive_desktop.py --godot /path/to/Godot --capture /path/to/fixture.ssc --output-dir /tmp/fullscreen-restore --window-restore --renderer forward_plus
```

Repeat with `--renderer gl_compatibility` and another output directory. The harness
requires a physical KDE session, qdbus, Spectacle, PyGObject and Pillow.

## Failures, warnings and limits

Early harness runs stopped because the visual snapshot included responsive panel
width, which legitimately changed on resize/fullscreen. The harness now settles
initial layout and excludes that presentation field from scientific invariance.
It then reproduced the original maximized-restore defect before the fixed runs.

Both native runs emitted a libdecor GTK-plugin initialization warning and used
fallback decoration. The Python harness emitted its existing Gio registration
deprecation warning. Compatibility also reported a cached-shader recompilation.
All final assertions passed with no Godot script errors; these warnings are not
presented as warning-free runs.

Validation is limited to KDE/Wayland on one display. Windows, macOS, X11, other
compositors, mixed-DPI/multiple displays, and rapid transitions before the compositor
settles were not tested. No production scientific runs or full export/recipe
regression suites were rerun for this native-window-mode fix. No pixel-equivalence
claim is made across different window sizes.

Current fullscreen behavior and current status documentation were updated.
Historical issue #46/#44/#52 reports and evidence retain their original wording.

## Owner verification

1. Launch SimScope and maximize using the window manager. Press F11 twice.
   Confirm the window returns to maximized, with the normal menu and panel.
2. Repeat entry with F11 and exit with the on-screen Exit fullscreen button.
   Repeat several times; maximized state must persist.
3. Restore to a manually sized window. Move and resize it, enter via
   View → Fullscreen, then exit via F11 and separately via the mouse button.
   Confirm the prior position and size return.
4. Maximize again and repeat step 1 to ensure the saved return mode updates.
5. From maximized, enter F11 fullscreen, press Shift+F11, then Esc. Confirm
   interactive fullscreen returns. Exit fullscreen and confirm maximized returns.
6. Enter immersive directly from maximized and exit with Esc. Confirm the existing
   recovery behavior, camera, playback position and scientific settings remain intact.

Owner review and merge remain pending. No further issue is authorized by these tests.
