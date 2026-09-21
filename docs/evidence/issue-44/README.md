# Issue #44 — final UX3 integration evidence

**Pending owner review.** Accepted baseline `c240024` (owner-merged PR #63).
See the [milestone report](../../UX3_REPORT.md) for workflow coverage, ownership,
results, failures, limits and exact manual owner acceptance steps.

All files here are fresh #44 evidence. No previous issue's screenshots, reports
or review wording were modified. [Validation/run ledger](validation.json) records
commands, exit codes and retries; [manifest](manifest.json) records artifact hashes.
Console text copies omit trailing empty lines only. The earlier attempts in that ledger remain identified, including failed attempts.

## Reports

- Shell: [Forward+](shell-forward.json), [Compatibility](shell-compat.json).
- Transport: [Forward+ and real source](transport-forward.json), [Compatibility](transport-compat.json).
- Status/Jobs: [Forward+](status-forward.json), [Compatibility](status-compat.json).
- Integration/profile: [mixed fixture](integration-fixture.json), [real Forward+](integration-real-forward.json), [real Compatibility final](integration-real-compat.json).
- Desktop: [Forward+](desktop-forward.json), [Compatibility](desktop-compat.json),
  [source integrity](real-source.json), scientific-region hashes
  [Forward+](scientific-roi-forward.json) / [Compatibility](scientific-roi-compat.json).
- Headless: [recipes](recipes.json), [camera](camera.json), [playback](playback.txt),
  [readiness/budgets](readiness.txt), [lifecycle](lifecycle.txt).
- Export: [Forward+](video-forward.txt), [Compatibility](video-compat.txt),
  [selection/image/state replay](selection-render.json), [volume controls](volume.json).
- Application main-scene reopen: [first process](app-reopen-0.txt), [second](app-reopen-1.txt).
- Corrected/retried checks: [initial test pause mistake](initial-harness-failure.txt),
  [Godot shader-cache warning](initial-shader-warning.txt),
  [initial compositor/readback comparison](initial-image-comparison.txt).
  [Desktop helper output](desktop-helper.txt) retains the PyGObject deprecation warning.

The initial native desktop passes checked state/geometry. Final `desktop-verified-*`
runs also require a bright scientific region and exact unchanged RGB bytes across
five stages, **independently for viewport readback and compositor capture**.
The methods are not required to match each other: the observed Compatibility
compositor/readback difference was at most one RGB step. No tolerance is used
within each method and no cross-renderer pixel equivalence is claimed.
KWin fullscreen/frame/client/output rectangles are retained in full; actual output
sizes reflect the desktop at each run (2560×1440 initially; 1920×1080 in later runs).
Native source and input checks use a physical Wayland session with synthetic input,
not a manually operated Nordic keyboard.

## Selected images

- Real source [1440×900](real-1440.png) and [1024×640](real-1024.png).
- [Interactive fullscreen](interactive-fullscreen.png) and [immersive fullscreen](immersive-fullscreen.png).
- [Live Jobs Details](live-details.png) and [compact status focus](status-focus-1024.png).
- [Actual Compatibility 4K overlay export frame](export-4k.png).

The real-source workflow images are paused after recipe restore, intentionally
showing its status notice. The small-fixture status image shows the test's current
scientific scene. The 4K frame includes the explicitly enabled particle legend
under #55's existing overlay contract. Rendered colors can differ by GPU backend.

## Reproduction

Run from the repository root with the external Godot executable and development
Python. Each output directory must be fresh. Never put generated captures or
videos into Git. `$GODOT` denotes the externally installed executable.

```sh
python tools/validate_viewer_shell.py --godot "$GODOT" --output-dir /tmp/new-shell --renderer forward_plus
python tools/validate_viewer_transport.py --godot "$GODOT" --output-dir /tmp/new-transport --renderer forward_plus --real-capture /path/to/retained.ssc
python tools/validate_viewer_status.py --godot "$GODOT" --output-dir /tmp/new-status --renderer forward_plus
python tools/validate_ux3_integration.py --godot "$GODOT" --output-dir /tmp/new-integration --renderer forward_plus
python tools/validate_ux3_integration.py --godot "$GODOT" --output-dir /tmp/new-real --capture /path/to/retained-particle-volume.ssc --renderer forward_plus
python3 tools/validate_immersive_desktop.py --godot "$GODOT" --output-dir /tmp/new-desktop --capture /path/to/retained-particle-volume.ssc --renderer forward_plus
python tools/validate_video.py --godot "$GODOT" --output-dir /tmp/new-video --renderer forward_plus --overlay-ui
python tools/validate_recipe_state.py --godot "$GODOT" --output-dir /tmp/new-recipes --renderer headless
python tools/validate_scene_playback.py --godot "$GODOT" --output-dir /tmp/new-playback --renderer headless
python tools/validate_performance_maintenance.py --godot "$GODOT" --output-dir /tmp/new-readiness --renderer headless
python tools/validate_camera_tumble.py --godot "$GODOT" --output-dir /tmp/new-camera --renderer headless
python tools/validate_g4_render.py --godot "$GODOT" --output-dir /tmp/new-render --renderer forward_plus
python tools/validate_volume_presets.py --godot "$GODOT" --output-dir /tmp/new-volume --renderer forward_plus
```

Repeat shell/transport/status/real-integration/desktop/video with
`--renderer gl_compatibility` and separate output directories. The desktop helper
requires system Python with PyGObject/Pillow, Qt6 qdbus, Spectacle and a KDE/Wayland
session; it affects only its own test PID and unloads its temporary KWin script.
Its image assertions assume the retained capture renders visible science in the
central test region. The integration probe requires particle and volume layers;
without `--capture`, it generates the existing small mixed fixture.

The real integration saves/reloads a temporary scene recipe, tests signed speeds
and a source probe, churns workspaces, captures PNGs and profiles short idle/play
cases. Hashing is streamed; sources are opened read-only and not copied into Git.
Profiles use a user-selectable 512 MiB particle policy and current scientific
rendering. Their evolving cache warmth precludes a causal dock-cost comparison.

Normal main-scene relaunch was run twice with `--quit-after 60` and the generated
mixed source. See [owner verification](../../UX3_REPORT.md#owner-verification-before-acceptance)
and [limits](../../UX3_REPORT.md#failures-limitations-and-deferred-work).
