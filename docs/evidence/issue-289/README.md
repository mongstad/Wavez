# Issue #289 — application theme review

Candidate **v0.1.0.79**, based on accepted `main`
`407c35833c07a800f12e56aae1140ac08a822e63` (owner-merged #302).
Issue #289 was the sole Ready item; its existing linked branch was already
checked out, clean and equal to `main`. Remote references were pruned; no completed
local issue branch remained. No new branch was created. **Pending owner review.**

## Change and boundary

Edit → Preferences → Theme selects locally persisted Dark/Light chrome. The
existing base/violet builders retain metrics and interaction styles. Semantic
Light tokens, reversible local style/color overrides and event-driven refresh
cover current and deferred controls. Scientific legends/color bars are excluded;
shared dark resources remain intact. No controller, payload, colormap or renderer
algorithm changes are included. Native desktop pickers keep their OS theme.

The official 1254 × 1254 light About logo is copied unchanged from the owner's
`Wavez_ThemeBranding/Light_Mode/Wavez_Square_Logo_No_Slogan_No_Border_White.png`.
SHA-256: `fb48a4c75fb4c48800b21cad4541430611bccc83d46a4a580ff3d50bc39c8ddf`.
Its import is lossless/mipmapped; both logos are preloaded into the Linux PCK.
The original dark PNG and application icon are unchanged.

## Focused validation

| Check | Result |
| --- | --- |
| Source production-shell audit, Forward+ | 42,879 checks, 0 failures |
| Source production-shell audit, Compatibility | 42,879 checks, 0 failures |
| Final source fresh Light/Dark restarts, each renderer | 4 + 2 checks, 0 failures |
| Final Linux validation package, Forward+ | 42,879 + 4 + 2 checks, 0 failures |
| Final Linux validation package, Compatibility | 42,879 + 4 + 2 checks, 0 failures |
| Direct accepted-main/candidate Dark raster comparison | 0 differing pixels at 1440 × 900, Compatibility |
| Light native KWin controls/fullscreen/restoration | 76 assertions, 18 compositor stages, clean final wrapper pass |
| Existing deterministic PNG/video export regression, Light profile | 44 checks passed, Compatibility |
| Identical export job with Dark defaults | See `export-theme-pixels.json`: 3 PNG frames compared pixel-for-pixel |
| Application version tests | 2 passed; candidate build 79 = accepted build 78 + 1 |
| Final Godot import, notice sync, Python compilation, diff whitespace | Passed |

The shell audit covers 1440 × 900 and 1024 × 640, all three workspaces, About,
Mapping, Performance, Global effects, Source probe, Geometry, Data, Selection,
Jobs, Keyboard Shortcuts, File Locations, Video Export, Details and the embedded
file-picker fallback. Visible geometry/minimum sizes, fonts/sizes, tooltip text,
focus modes/order and scientific view state are compared across both directions.
Hidden controls' cached layout rectangles are not treated as visible geometry.
The audit checks no idle theme rebuilds, pin/edge state preservation, exact
scientific viewport pixels with chrome hidden, and preference/logo restarts.
The packaged runner additionally verifies the fixture hash remains unchanged.

Scope follows the presentation-only blast radius: shell/dialog state, geometry,
chrome integration, packaging and a focused export-pixel boundary. No unrelated
full scientific, cache, long-capture or analysis suite was run.

Reproduce source or packaged audits with:

```bash
python tools/validate_application_theme.py --godot /absolute/path/to/godot \
  --renderer forward_plus --output-dir /absolute/new/source-output
python tools/validate_application_theme.py --godot /absolute/path/to/godot \
  --package --renderer gl_compatibility --output-dir /absolute/new/package-output
```

Repeat with the other renderer. The package option follows the repository's
existing validation-entry approach: only the staged main scene changes, and the
exported release binary drives the same production viewer and packaged assets.
It runs outside the project with no development `--path`. The normal production
Linux build was also exported; its artifact hashes are in
`production-linux-build.json`. Runtime binaries/templates remain external.

## Review images

- [Normal Light](light-normal.png) and [unchanged Dark](dark-normal.png).
- [Expanded controls](light-expanded.png) and [compact, scrolled controls](light-compact-scrolled.png).
- Packaged fresh restarts: [Light About](light-about-restart.png), [Dark About](dark-about-restart.png).
- [Jobs](light-jobs.png) and [Video Export](light-video.png).

## Development failures and limits

Initial harness iterations exposed an unknown-token lookup (fixed), stale hidden
layout measurements (corrected), and a pixel comparison that still included the
sibling Simulation dock (corrected). Visual inspection caught pale menu/status
icons and About links; the final palette and restart assertions cover these.

A normal release-template launch ignored `--script` and opened the app; it was
stopped and not counted as a test pass. The exported validation-entry runs above
completed normally. Two KWin attempts completed their assertions but the strict
wrapper rejected `Failed to load cached shader, recompiling`; their result was
not counted as a clean pass. Accepted `main` then passed, followed immediately by
a clean unchanged candidate run in the warmed Wayland profile. The first warning
log is retained. The Gio test driver also prints its existing deprecation notice.

The first additional Dark export comparison omitted the job-local recipe bundle;
the worker correctly rejected its source/recipe boundary. The corrected job copied
the identical adjacent recipe and retained the same scientific state and source.
No application change was made for that harness error.

Physical 4K/KDE scaling, mixed-DPI displays, physical pointer/keyboard feel,
other operating systems and long sessions were not verified. Programmatic native
geometry/focus checks are not physical acceptance. Native KDE file-picker styling
follows system appearance by design. The actual deterministic export comparison
uses Compatibility; Forward+ has the exact viewport-pixel and package checks.
All older issue reports and historical review wording remain untouched.

## Owner verification

1. In the Linux build, use Edit → Preferences → Theme before opening a capture;
   confirm only the selected choice is checked. Restart in each theme.
2. Open a capture and switch Dark → Light → Dark without reloading. Compare
   particles, fields, meshes, legends and the scientific viewport.
3. Open About in each theme, reopen it, and confirm the official corresponding
   logo, unchanged size/layout, legible links, notices and close behavior.
4. Inspect expanded and scrolled Simulation controls, menus, tooltips, disabled
   states, focus traversal, Jobs, Video Export and preference dialogs at normal,
   compact and physical 4K/KDE scale.
5. Exercise playback/seek, pins, edge reveal, fullscreen enter/exit and window
   restoration; export the same scientific view under each theme.

Stop for owner review. No merge, auto-merge, issue closure or Project transition
has been performed.
