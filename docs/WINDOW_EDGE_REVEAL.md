# Pinned edge reveal and Fullscreen

Issue #117, pending owner UX review. This supersedes the user-facing visibility
and fullscreen portions of the earlier UX3/UX4 contracts. Historical reports,
measurements and review wording are retained. Candidate application build: `v0.1.0.8`.

## Interaction contract

The top application bar, right simulation panel, and combined playback/status
strip each have one compact pin. They start pinned; filled upright pins mean
persistent visibility, outlined tilted pins mean auto-hide. Preferences are
session-only and absent from portable view presets and export-state dictionaries.
The existing source-independent preset schema and scientific controllers are unchanged.

Unpinned surfaces hide automatically after **0.35 seconds** away from the surface
and its active interactions. A continuous **0.5-second** hover within **10 logical
pixels** of the top, bottom or right client-window edge reveals a surface temporarily.
Leaving the edge before that deadline resets the dwell. Pinning reveals immediately;
unpinning grants the ordinary grace period rather than hiding during the click.
Fullscreen saves all pin/visibility/timer state, initially hides and unpins all three
surfaces, and keeps edge reveal active. Exiting discards pin changes made while
fullscreen and restores the original pre-fullscreen pin, visibility and timer state.

Open menus (including Godot internal popup nodes), dropdowns/dialogs, held mouse
buttons, panel resize, text/numeric editing and keyboard navigation protect the
revealed UI from hiding. Protection is conservative: an open dialog or ongoing
drag holds all currently revealed surfaces. It does not reveal hidden surfaces.
An idle slider's mouse-acquired focus does not keep its strip open indefinitely.
Mouse-only button focus also does not prevent normal auto-hide after leaving.
No edge input handler consumes camera input.

Transport and status share one visibility parent and pin, retaining their existing
controllers and Jobs state. The panel retains its normal overlay layout and width
rules; below 970 logical pixels a pinned panel remains visible as a sheet rather
than being forcibly collapsed. Hidden bottom chrome releases its reserved legend
space; scientific overlays retain their explicit enabled state.

There are no Hide/Show commands for these surfaces, no F1 visibility toggle, and
no viewport recovery buttons. Existing internal panel-opening/presentation callers
remain available. Pin state is not a new scientific or rendering setting.

## Fullscreen and input ownership

**View → Window → Fullscreen**, **F11**, and an unobstructed viewport double-click
all invoke the existing immersive implementation. **Esc**, F11 or another viewport
double-click restores the preceding native mode/geometry and shell state. Shift+F11
is the same F11 action, not a second mode. Native maximize/restore remains owned by
the compositor. The previous Exit fullscreen button and transient hint are not drawn.

Fullscreen initially hides all application chrome, including viewport camera controls,
while preserving explicitly enabled scientific overlays. The top bar, right panel
and complete bottom strip can then be revealed from their 10px edges. Their normal
interaction protection and auto-hide grace still apply. Playback and camera
controls continue. Esc recovery still runs before inspection-busy and GUI input
guards; text/numeric entry suppresses the entry shortcut. Native rejection or an
external compositor exit uses the existing recovery path.

Double-click detection runs after GUI and existing selection-tool input. It excludes
visible shell surfaces, dialogs, navigation controls and scientific legends, even
where those legends pass ordinary pointer input through. Active selection tools
retain their click/drag ownership. #120's proposed RMB-hold orbit setup does not
conflict with this left-button gesture; no orbit setup is implemented here.

## Validation

See [initial machine-readable evidence](evidence/issue-117/validation.json) and
[initial wider-zone checks](evidence/issue-117/wider-zones.json) and
[10px-zone checks](evidence/issue-117/ten-pixel-zones.json) and
[current fullscreen edge-access checks](evidence/issue-117/fullscreen-edge-access.json). Native tests
use Godot 4.7.2 on Linux/NVIDIA RTX 3070 Ti, tiny mixed SIMSCP4 fixtures, and unchanged
source SHA-256 checks. The deterministic edge tests inject elapsed time into the
same controller used by `_process`; real popup objects and viewport input dispatch
exercise input routing separately. This is timing/state evidence, not subjective
proof of physical hover feel.

| Check | Result |
|---|---|
| Edge/pin/input matrix | 210 PASS per renderer after fullscreen edge-access review |
| Complete shell/menu/state suite | 661 PASS per renderer |
| Transport regression | 210 PASS per renderer |
| Portable view presets, including zoom | 826 PASS, Forward+ |
| KDE/Wayland window restoration | 16 stages each; 69 Forward+ follow-up / 69 prior Compatibility checks |
| Monitor/taskbar check with legends | 6 Wayland + 3 partial X11 bottom-region comparisons match |
| Application version | 2 unittest cases PASS |
| Documentation | Local links + 3 executable examples PASS |
| Import, Python compile, whitespace | PASS |

[Pin placement](evidence/issue-117/pins.png) and
[fullscreen monitor capture](evidence/issue-117/fullscreen-monitor.png) show the
reviewed presentation. The initial Forward+ native run preceded the additional legend assertions; the
latest Forward+ fullscreen edge-access run and prior Compatibility run both include them.

The KDE/Wayland harness uses only its test PID, a temporary KWin script and
Spectacle. It checks actual compositor frame/client/output rectangles and exact
restoration, not just the Godot mode enum. Desktop logs contain a libdecor GTK
plugin fallback warning; native geometry checks succeeded. The harness also emits
a Python Gio deprecation warning. Neither is silently counted as a clean log.

Development failures were corrected: explicit GDScript typing for `busy`, internal
popup traversal, and obsolete tests expecting interactive fullscreen controls.
One Compatibility run passed all 104 assertions but failed the strict log gate
because Godot recompiled a cached shader; the clean rerun is recorded separately.
The first sandboxed import could not open editor sockets/write editor settings;
the authorized fresh import is checked separately. No production scientific
capture rerun, Windows/macOS/package validation or physical mixed-DPI acceptance
is claimed. #93's packaged export-launch limitation remains outside this issue.

## Owner-observed taskbar overlap

During the automated shell run the owner observed the fullscreen window/legend
behind the Linux taskbar. The broad tests use X11/XWayland by default; the native
geometry harness explicitly uses Wayland. Window-only screenshots cannot prove
absence of an overlaid taskbar, so the harness now also captures the current
monitor after verifying that the test PID is active and truly fullscreen.

With enabled particle and field legends, six native Wayland/Compatibility
fullscreen checkpoints had identical application/monitor pixels throughout the
bottom 220 rows; both legends were inside the viewport. Three X11/Compatibility
checkpoints also matched. The X11 run then aborted at `resized-fullscreen` because
the test window lost focus, before taking another monitor image. The owner reported
the later run looked better. The original overlap was not reproduced while the
window was verified active; focus loss during automated transitions is a hypothesis,
not an established cause. No speculative always-on-top or compositor-policy change
was added. Recheck physical F11 transitions during owner review.

## Owner verification

1. At your normal desktop scale, unpin each surface. Leave it, confirm automatic
   hiding, then hold its window edge for about half a second. Brief edge passes
   should not flash it open. Pin again; confirm the icon and persistent visibility.
2. Unpin playback/status and verify both always transition together. Open Jobs,
   edit a seek target, drag the timeline beyond the strip, use a dropdown, and
   navigate controls with Tab. Finish interaction and move away; check the grace.
3. Try all pinned, each individually unpinned, and all unpinned. Enter with F11
   and exit with F11 and Esc. Repeat while an unpinned surface is temporarily
   revealed. Confirm prior visibility/pins return. Inside Fullscreen, reveal each surface
   from its edge, use its controls, then leave it to auto-hide. Temporarily pin a
   surface there and verify exiting still restores the original preference.
4. Repeat from a restored window and maximized KDE window. Confirm exact previous
   geometry, no recovery buttons, and no changes to playback, camera or layer state.
5. Double-click an unobstructed viewport to enter/exit. Double-click on a legend,
   panel, slider, menu or dialog; Fullscreen must not toggle. Selection tools must
   retain their existing gestures.
6. Repeat during ordinary playback, with a running job and enabled legends.
   Save/load a view preset; check camera/zoom and scientific presentation. Review
   pin placement and the 0.35-second hide grace for comfort before acceptance.
