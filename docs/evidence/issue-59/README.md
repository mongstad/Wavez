# Issue #59 — retired UI cleanup evidence

Pending owner review. #59 was the sole Ready item; the owner-linked branch was
already checked out, clean and identical to `main` / `origin/main` at
`2fd44bae6198d83b0bfc2b7a8616c1b464293d3e`. PR #60 was verified merged at that
commit. Its stale remote ref was pruned; the old local branch was already absent.
No acceptance-only change, branch switch or Project write was made.

The [dependency map and UX4 handoff](../../UX3_UI_OWNERSHIP.md) records the audit
performed before deletion. Runtime changes remove the left-panel layout/style,
its resize callback and standalone F1 affordances, the offline UI switch, and the
hidden duplicate Playback/Seek/rate form. The production transport constructs its
actual controls directly. Neutral right-dock containers and every supported
scientific/control group remain. Offline harnesses now use production scroll and
explicit refresh/visibility instead of relying on the retired tree shape.

## Results

Godot 4.7.2 on Fedora KDE/Wayland, NVIDIA RTX 3070 Ti. Tiny synthetic SIMSCP3
fixtures only. [Machine-readable summary](validation.json) and individual reports
retain counts and source hashes; counts overlap where suites embed other tests.

| Check | Result |
|---|---|
| Shell, Forward+ and Compatibility | 160 PASS each: single event bindings, retained groups, Open/cancel/replace/failed-open, frame/reset/navigation, native interactive/immersive entry/recovery, scientific invariance, 1440×900 and 1024×640 layouts |
| Transport, Forward+ | 204 PASS: exact/union seeks, buffering/Pause, rate/Loop, time formats, fixed layout, zero instrumented scientific work from refresh |
| Status/Jobs, Forward+ | 67 PASS: live Details, failure persistence, native export completion/cancel/parent-close acknowledgement |
| Recipe/state, headless | 2,957 PASS: retained controls, full-precision rate, repeated restore, obsolete presentation omitted |
| Camera, headless | 13,032 PASS, particle/mesh/volume fixtures; no claim of GPU validation from this suite |
| Analysis/source protocol, headless | 160 PASS, including worker source probe |
| Selections, Forward+ | 32 PASS, including native retained controls |
| Selection-aware PNG/video, Forward+ | 44 PASS: actual markers, hashes, membership, exact samples, deterministic delayed repeat and replay |
| Probe, Forward+ | 33 PASS plus two four-frame exports: independent marker visibility, unchanged values/state and source hashes |
| Volume presets, Forward+ | 99 PASS plus three exports: retained control actions, mapping/opacity independence, oracle probes, state/pixel replay |
| Overlay video, each renderer | 111 PASS each, including 62 UI checks; 1080p/4K, interface on/off, workspace/remaining state, actual MP4/PNG dimensions, exact frame timing and same-renderer repeated PNG equality |
| Accepted-main comparison, Forward+ | Scientific-only 1440×810 pixels identical; visual snapshot differs only by removed `sections.Playback` and `sliders.Physical time units / second` |
| Import/static | Godot import, all 28 changed-script parse checks and whitespace checks pass; no runtime references to removed symbols; no previous evidence changed |

Screenshots: [1440×900](shell-1440.png), [1024×640](shell-1024.png),
[volume controls](volume-controls.png), [selection controls](selection-controls.png),
[Forward+ 1080p export](export-forward-1080p.png),
[Compatibility 4K export](export-compat-4K.png).
The shell screenshots include intentionally injected failed-open/inspection
messages from lifecycle tests; these are fixture states, not test failures.
Scientific legends in the export are intentionally enabled under #55's contract.

## Corrected checks and limitations

The first volume harness raised a type error because it treated the inspector's
direct parent as a `ScrollContainer`. The failed instance was stopped; its
scientific state/pixel replay assertions had already run. The harness now uses
`shell.scroll`, restores production chrome explicitly for its control screenshots,
and passes all 99 checks and three exports. Other harnesses with that parent
assumption were updated likewise.

The first baseline evidence assembly compared file hashes from independently
generated synthetic captures: their identities differed despite equal rendered
content. The final comparison reuses the exact accepted-main fixture bytes.
No production change was made to accommodate this evidence check.

No scientific solver/research capture rerun, full scientific/FFmpeg/performance
matrix, other OS, physical mixed-DPI or long-session validation. The native shell
tests exercise fullscreen and recovery, but no separate KWin geometry audit was
repeated. Auxiliary temporal/space-time/diagnostics/opacity/color/profile/HUD/UX1
collectors were updated for removed references; their full suites were not rerun.
All old screenshots/reports retain their original review-time contents.

## Reproduction

From the repository root, use the installed Godot executable and dev Python.
Output directories must be new. The suites generate their own small fixtures.

```sh
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/new-shell --renderer forward_plus
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/new-shell-compat --renderer gl_compatibility
python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir /tmp/new-transport --renderer forward_plus
python tools/validate_viewer_status.py --godot /path/to/godot --output-dir /tmp/new-status --renderer forward_plus
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir /tmp/new-state --renderer headless
python tools/validate_camera_tumble.py --godot /path/to/godot --output-dir /tmp/new-camera --renderer headless
python tools/validate_analysis_foundation.py --godot /path/to/godot --output-dir /tmp/new-analysis
python tools/validate_selections.py --godot /path/to/godot --output-dir /tmp/new-selection --renderer forward_plus
python tools/validate_g4_render.py --godot /path/to/godot --output-dir /tmp/new-selection-render --renderer forward_plus
python tools/validate_probe_marker.py --godot /path/to/godot --output-dir /tmp/new-probe --renderer forward_plus
python tools/validate_volume_presets.py --godot /path/to/godot --output-dir /tmp/new-volume --renderer forward_plus
python tools/validate_video.py --godot /path/to/godot --output-dir /tmp/new-video --renderer forward_plus --overlay-ui
python tools/validate_video.py --godot /path/to/godot --output-dir /tmp/new-video-compat --renderer gl_compatibility --overlay-ui
```

The accepted-main baseline was captured before editing with `video/test_ux.gd`
at the commit above. The same native command and fixture bytes were then used
on the issue branch; comparison is exact RGB byte equality, without tolerance.

## Owner verification before acceptance

1. Relaunch through Godot Project Manager **Run**. At 1440×900 and 1024×640,
   open a representative layered capture; replace it, then try an invalid file.
   The prior usable scene must survive failed replacement. Confirm there is no
   left inspector during any transition.
2. Scroll the right Scene inspector. Open particle mapping, field/volume and mesh
   settings; change and restore a range, opacity and visibility. Run a source
   probe. Visit Selection and Analysis shortcuts, define a selection and run a
   small analysis. Confirm all existing groups remain reachable without new UX4
   organization.
3. Play/Pause through an uncached interval, step Previous/Next, drag the timeline,
   use Seek, change speed and Loop. Confirm a single transport, stable buffering
   controls/readouts and sample-index tooltip. Hide/show the dock with mouse/F1.
4. Use Frame scene, Reset camera and Navigate. Enter/exit F11 interactive fullscreen;
   top bar hides, mouse recovery remains. Enter Shift+F11 immersive; application
   chrome disappears; Esc restores the prior mode and scientific state.
5. Save/load a scene/analysis recipe and save a PNG. Confirm camera, scientific
   settings, probe/selection behavior and output match the chosen state.
6. Export short 1080p and 4K clips with **Include viewer overlays** on, then off.
   On must show the current right-hand shell only; off must omit application chrome
   under the existing legend/overlay contract. Repeat a clip with identical settings,
   and check Jobs/live Details and cancellation. Confirm live state remains intact.

Stop here for owner review; #44 and UX4 have not been started.
