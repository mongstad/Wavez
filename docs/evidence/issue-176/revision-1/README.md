# Issue #176 — owner-requested revision

This evidence covers the revised square-surface direction in #176, superseding
the original rounded implementation for review. Candidate `v0.1.0.19` remains
pending owner acceptance. The earlier parent-directory evidence is preserved as
historical evidence; its rounding assertions are not the current target.

The revision removes rounded shell style generation/swapping, restores the orbit
editor tonal surface and squares custom dialog/popup outer styles. The shared
body/header join remains flush. About contains its header in one square body and
uses the same `close_action` factory as the shell and shortcut editor: exact icon,
32 × 32 minimum size, IconAction variation, five style states and hover handling.
The former decorated header's 32 pixels move inside the body; content, footer,
scrolling, links, notices and dismissal remain available. No scientific controller,
capture format, camera or export code changes are included.

## Revised results

Godot 4.7.2 stable, Linux KDE. Focused source/package runs use native Wayland;
existing source regressions use their normal X11/XWayland harnesses.

| Validation | Forward+ | Compatibility |
|---|---:|---:|
| Focused square surfaces/seams/close, source | 184 PASS | 184 PASS |
| Focused Linux release package | 184 PASS | 184 PASS on fresh retry |
| Existing About behavior/content regression | 118 PASS | 118 PASS |
| Existing shell/menu/tool/scientific-state regression | 659 PASS | 659 PASS |
| Keyboard Shortcuts, restart/persistence and fixture hash | 213 PASS | 213 PASS |

Focused reports: [Forward+ source](forward-source.json),
[Compatibility source](compat-source.json), [Forward+ package](forward-package.json),
[Compatibility package](compat-package.json). Each verifies actual 1440 × 900,
970 × 600 and 3840 × 2160 windows at content scales 2.0 and 2.5.
Assertions sample both About seam edges and all four corners while shown, after
an 8 × 4 logical-pixel header drag, and after close-button focus/redraw. They
verify shared close resources and dismissal, square shell styles across normal,
maximized/fullscreen modes, unchanged camera/visual snapshots, square shortcut
and Tools bodies, original orbit styling and compact footer bounds.

Existing regressions: [Forward+ About](forward-about.json),
[Compatibility About](compat-about.json), [Forward+ shell](forward-shell.json),
[Compatibility shell](compat-shell.json), [Forward+ shortcuts](forward-shortcuts.json),
[Compatibility shortcuts](compat-shortcuts.json). Shell and shortcut fixtures
retain unchanged full-file hashes. Apply, Cancel, X, Escape and fresh-process
shortcut persistence are exercised by the existing shortcut suite.

Final import, Python compile, `git diff --check` and the application-version
unit suite (2 tests) passed. The source About logo-row variable was renamed after
the first focused runs to avoid shadowing the custom header member; final import
and later shell/shortcut source checks include that naming cleanup, as does the
Compatibility package retry. There is no second build increment.

## Diagnostics and limits

The first Compatibility package completed 184 assertions but timed out on process
completion at 160 seconds. It is not counted as PASS; see the retained
[assertion report](compat-package-timeout-assertions.json) and
[timeout record](compat-package-timeout.txt). Its cause is unestablished. A fresh
package retry returned successfully and passed the strict diagnostic gate.
The wrapper now preserves timeout stdout/stderr before rethrowing.

Full revised logs are beside their JSON reports. The focused native Wayland gate
retains only the exact accepted-main libdecor GTK fallback pair; the Compatibility
package also retains the existing embedded-window shutdown signal pair when
present. These diagnostics appear explicitly in each validation JSON. The shortcut Compatibility restart retains the exact two pre-existing texture
cleanup errors documented on accepted main, explicitly recorded in its validation
JSON and restart log. A first About Compatibility run had a shader-cache warmup
warning; its clean warm repeat is the reported result, and the first log remains
as `compat-about-warmup-native.txt`. A sandboxed final import hit editor socket and
profile-write restrictions (`sandbox-import-attempt.txt`); the isolated-profile
native repeat in `final-import.txt` is clean. Other
errors/warnings still fail the focused wrapper. Historical shader-cache/KDE results in
the parent report were not rerun and are not claimed as revised clean passes.

Automated corner pixels cover selected states, not continuous flicker on every
compositor. Physical 4K/compositor scaling, mixed monitors, real pointer drag/resize
feel, Windows/macOS and owner visual acceptance remain unverified. No new long
capture, production performance or export comparison was run for this revision;
the earlier scientific comparisons remain historical evidence. The scientific
viewport code is unchanged and current regressions preserve camera/state/hashes.

## Visual evidence and reproduction

Inspected [About normal](about-normal.png), [About Linux package at 4K](about-4k-package.png),
[square shell](shell-windowed.png) and [compact shortcuts](shortcuts-compact.png).
The About screenshots show square edges and a continuous header/body surface.

```sh
python tools/validate_rounded_surfaces.py --godot /path/to/godot --output-dir /tmp/square-source --renderer forward_plus --display-driver wayland
python tools/validate_rounded_surfaces.py --godot /path/to/godot --output-dir /tmp/square-package --renderer gl_compatibility --display-driver wayland --export
python tools/validate_about.py --godot /path/to/godot --output-dir /tmp/about --renderer forward_plus
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/shell --renderer gl_compatibility
python tools/validate_keyboard_shortcuts.py --godot /path/to/godot --output-dir /tmp/shortcuts --renderer forward_plus
```

The historical runner filename/output flag is retained to keep existing commands
and evidence links usable; its current assertions implement the revised square
scope. See [current behavior and owner checks](../../../ROUNDED_SURFACES.md).
Owner review controls acceptance and merge.
