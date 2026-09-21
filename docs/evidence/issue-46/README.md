# Issue #46 — immersive fullscreen review evidence

2026-09-21. Pending owner review; no owner acceptance is claimed.
Baseline accepted main: `deb6b87d8fc32b108e27fe93f4eb6508fc10eb1f` (PR #57).
Only issue #46 was Ready. Its owner-linked branch was already checked out at that
baseline. The previous local issue branch was absent; the stale remote ref was pruned.
Historical evidence for earlier issues has not been rewritten.

## Native desktop result

Fedora 44, KDE Plasma 6.7.5, Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti.
The real `free_collapse_simscope.ssc` capture contains recorded particles and a
volume field. It was opened read-only at its existing initial sample; no solver
was rerun. [Source path and SHA-256](source.json) were checked before/after both runs.
This is one simulation family, not a broad scientific-dataset validation.

Both **Forward+** and **Compatibility** passed **11 Godot assertions and 8
independent KWin geometry checks**. The physical desktop test window occupied the
secondary monitor at `(2560,360)`, `1920×1080`. KWin reported `fullscreen=true`
and identical frame/client/output rectangles for interactive and immersive modes.
Windowed recovery restored a `1440×900` client with native decoration. These are
compositor measurements, not conclusions based only on `DisplayServer`.

The agent visually inspected native Spectacle screenshots: interactive controls
remain; immersive initially shows the hint; the hint disappears and no persistent
application chrome remains. Existing hidden legends remain hidden. Esc returns
from immersive to interactive fullscreen. Removing fullscreen through KWin on the
test PID restores usable windowed chrome. Input was injected through Godot and
menu signals; this is not a claim that the owner physically pressed every key.

- [Forward+ native state/geometry](forward-desktop.json)
- [Compatibility native state/geometry](compat-desktop.json)
- [Forward+ interactive](forward-interactive.png), [hint](forward-immersive-hint.png),
  [clean immersive](forward-immersive-clean.png), [WM recovery](forward-wm-recovered.png)
- [Compatibility interactive](compat-interactive.png), [hint](compat-immersive-hint.png),
  [clean immersive](compat-immersive-clean.png), [WM recovery](compat-wm-recovered.png)

The different backdrop/glow between renderers is existing renderer behavior;
fullscreen does not change their scientific/presentation snapshots.

## Focused checks

Final run results are recorded in [validation.json](validation.json):

| Suite | Result |
|---|---|
| Shell, Forward+ | 148 checks PASS |
| Shell, Compatibility (warm cache) | 148 checks PASS |
| Transport, Forward+ | 204 checks PASS |
| Status/Jobs, Forward+ | 67 checks PASS |
| Recipe/state, headless | 2,998 checks PASS |
| PNG/UI + video continuation, Forward+ | 86 assertions PASS |
| Real capture, each renderer | 11 assertions + 8 KWin checks PASS |
| Godot import / Python compile / diff whitespace | PASS |

The [video log](video-validation.txt) includes intentional malformed-path and
oversized-frame-count cases that correctly fail export; those are passing
negative tests, not failed validation. Shell coverage includes
windowed/maximized/interactive restoration, hidden dock, both hidden and visible
scientific overlays, three-second hint, text focus guard, hidden focus release,
busy-inspection Esc recovery, active play-state preservation, canonical immersive
PNG capture, toast suppression, external mode loss, camera wheel input and the
existing shell geometry/recipe/source lifecycle regressions.

The tiny-fixture test deliberately displays the legend and colorbar in its
visible-overlay case. Those displays are test setup, not a production side effect.
The complementary hidden-overlay assertions and real-capture screenshots verify
that immersive does not enable them.

Profile checks permit only the selection controller's existing idle
`g4_overlay_tick` / `g4_worker_poll` callbacks during awaited frames. No other
instrumented stage or counter may occur merely from immersive transitions/layout.
The harness stops the realtime clock for deterministic state comparisons; it
checks that `playing=true` remains true rather than simulating sustained playback.

## Reproduce

Use the external Godot executable and repository development Python for the usual
`validate_viewer_shell.py`, `validate_viewer_transport.py`,
`validate_viewer_status.py`, `validate_recipe_state.py` and `validate_video.py
--continuation` runners. All output directories must be new paths outside Git.
The video continuation run uses external FFmpeg/ffprobe.

For the physical desktop run use system Python with PyGObject:

```sh
python3 tools/validate_immersive_desktop.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --capture /path/to/free_collapse_simscope.ssc \
  --output-dir /tmp/issue46-real-new --renderer forward_plus
```

Repeat with `--renderer gl_compatibility`. This runner requires KDE, Wayland,
Qt6 qdbus and Spectacle. It filters KWin access to its own Godot process, changes
only that test window's fullscreen property for recovery coverage, unloads the
temporary script, and rejects ambiguous/inactive windows before screenshots.

## Failed attempts, warnings and limits

- Initial shell attempts failed three profiler assertions because the test counted
  existing idle selection callbacks as new work. The test was corrected as
  described above; no production scientific callback was changed to make it pass.
- The first sandboxed Godot import could not open sockets/save editor settings.
  A small sandboxed visibility probe likewise could not write Godot user logs;
  its top-level-child visibility result was false as expected. The native import
  rerun completed without errors. A sandboxed Plasma version query
  failed; the installed RPM confirms `plasma-workspace-6.7.5-1.fc44`.
- One Compatibility shell run passed all 148 assertions but its strict wrapper
  rejected a shader-cache recompile warning; a warm-cache rerun is recorded below.
- Native Wayland logs report unavailable `libdecor-gtk` initialization, with
  successful fallback and compositor-confirmed geometry. Compatibility additionally
  reported a cached shader recompile. The Python desktop helper reports a
  PyGObject `register_object` deprecation warning. None failed native assertions.
- Windows/macOS, other compositors, mixed-DPI monitor migration, and the complete
  scientific/performance/4K export suites were not run for this presentation change.
- Physical owner keyboard/mouse acceptance and sustained real-capture playback
  through uncached frames remain owner checks. No acceptance claim follows from
  automated passes. Follow the exact [owner checklist](../../UX3_FULLSCREEN.md#validation-and-owner-review).
