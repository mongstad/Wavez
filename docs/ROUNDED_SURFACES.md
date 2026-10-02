# Restrained outer corners

Issue #176 proposes the accepted About reference radius of **six logical pixels**
for Wavez-owned outer dialog surfaces and visible normal-window shell chrome.
Candidate build `v0.1.0.19` is pending owner review.

`wavez_theme.gd` owns `OUTER_RADIUS` and the shared embedded-dialog body style.
Embedded Window decoration owns the outer header corners; the body joins the
header with square top corners and no duplicated top border. This fixes the
About header/body seam wedges without rounding that internal boundary.
Existing content, dimensions, focus and action semantics remain authoritative.

| Surface | Treatment |
|---|---|
| About, Details, confirmations, video/Jobs and other themed AcceptDialog bodies | Square header join; six-pixel outer bottom corners; Window owns outer top corners |
| Tools window body and reusable DialogShell | Shared body primitive; flush header join, outer bottom corners |
| Keyboard Shortcuts | One six-pixel outer surface, same accepted padding and fixed footer |
| Orbit center editor | Static rounded tonal surface, same padding and editor behavior |
| Seek popup | Existing six-pixel outer PopupPanel treatment retained |
| Main top bar / bottom status | Only outer top / bottom corners round in normal windowed mode |
| Maximized / fullscreen shell | Cached square styles; flush screen edges |
| Scientific viewport and shell/viewport internal joins | Rectangular; no mask, clip, resize, projection or output change |

The shell treatment is on the **visible Wavez chrome surfaces**, not an OS window
shape/desktop transparency mechanism. The compositor retains its rectangular
native window bounds and existing resize grips. A tiny cached texture preserves
the top bar's tonal surface; cached styles swap only when native mode changes.
There is no new shader, animation or per-frame texture generation. Hidden chrome
exposes the unchanged rectangular scientific viewport; it is never rounded to
simulate an OS-shaped window.

#161 remains open and is a separate dialog revamp. Its coordination is conditional
on landing first, so this issue consumes the current shared styles and #175 editor;
it does not redesign forms, sizes, controls or File/Tools routing. Real OS-owned
filesystem dialogs retain their existing platform behavior. Nested controls,
panels and viewport boundaries are not given new radius styling.

[Validation and limitations](evidence/issue-176/README.md) include native Wayland,
actual 3840 × 2160 rendered windows at scales 2.0/2.5, Linux release packages,
KDE window transitions and accepted-main scientific/performance comparisons.
Physical 4K monitor/compositor scaling and real pointer resize/drag remain owner checks.

## Owner verification before acceptance

1. Launch candidate build 19 on Forward+ and Compatibility, including Linux
   release packages. In a normal window, inspect the outer top-bar and bottom
   status corners; internal viewport joins must stay square.
2. Open Help → About WAVEZ and inspect both header/body seam edges closely.
   No black wedges, transparent slivers or notches should remain. Open its
   notices view, File → Details, Tools → Mapping/Diagnostics, video export and
   Jobs; confirm continuous outer surfaces and unchanged content/actions.
3. Open Edit → Preferences → Keyboard Shortcuts and Navigate → Edit orbit
   center. Check consistent restrained corners, focus, scrolling, Apply/Cancel,
   content padding and footer visibility at 970 × 600 and normal sizes.
4. Drag/resize the normal window using its existing edges. Double-click blank
   top-bar space or use Maximize, then restore; maximize must sit flush. Minimize
   and restore. Enter Fullscreen and press Escape; no corner gaps or lost pin state.
5. Repeat on physical 4K KDE at your normal compositor scale and mixed monitors
   if used. The automated 4K images exercise rendered window size/content scale,
   not physical monitor configuration.
6. Open a capture, play/pause, seek, switch field channels and export a clip;
   confirm scientific content remains rectangular and behaves as before.

Owner review controls acceptance and merge. No later Ready issue is authorized here.
