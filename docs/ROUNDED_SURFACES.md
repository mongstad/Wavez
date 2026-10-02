# Square outer surfaces and About close control

Issue #176 now requires square outer corners. The owner rejected the initial
rounded treatment after observing corner bleed/flicker. Candidate build
`v0.1.0.19` keeps that single PR build increment and is pending owner review.

The visible shell uses its original tonal top bar and square status surface in
all window modes. Rounded texture generation and mode-dependent style swapping
have been removed. Custom dialog, Window and popup outer styles have zero corner
radius; the shortcut editor is square and the orbit editor uses its original
static tonal surface. Nested buttons retain their existing control styling.
The scientific viewport remains rectangular and its controllers are unchanged.

The shared dialog body keeps a flush header join without a duplicated top border.
About uses one square body containing its header and existing scrollable content,
so there is no separate decorated-header boundary to expose black wedges.
Its upper-right X, the shell X and shortcut-editor X use `close_action`: the same
32 × 32 IconAction button, close icon, state styles and hover animation. About's
header supports dragging; X dismisses About without quitting Wavez. Footer Close,
Escape, notices, links and viewport fitting retain their behavior. Its former
32-pixel decorated header is included in the body size.

[Revision validation and limitations](evidence/issue-176/revision-1/README.md)
records both renderers, source and Linux packages, seam/corner pixel checks and
existing interaction regressions. The earlier evidence directory is preserved
as a historical record of the unaccepted rounded implementation.

## Owner verification before acceptance

1. Inspect square shell and dialog outer edges in normal, maximized and fullscreen
   modes on both renderers. Move, resize and restore windows; look for bleed or
   edge flicker on your physical displays.
2. Open About. Inspect both sides of the header/body join and compare its X with
   the shell X while idle, hovered, focused and pressed. Drag its header and
   dismiss with X, footer Close and Escape. Check notices and links.
3. Open Keyboard Shortcuts, orbit center, Details, Tools, video export and Jobs;
   check square outer surfaces and existing scrolling, actions and footer bounds.
4. Repeat on physical 4K KDE with your normal compositor scale and mixed monitors
   if used. Automated 3840 × 2160 windows do not establish physical monitor behavior.
5. Open a capture, play/pause, seek, switch channels and export a clip; scientific
   content must remain rectangular and behave as before.

Owner review controls acceptance and merge. No next issue is authorized here.
