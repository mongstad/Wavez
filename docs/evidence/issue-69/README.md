# Issue #69 review evidence

Synthetic fixtures, external Godot 4.7.2, Linux desktop, NVIDIA RTX 3070 Ti.
Baseline: owner-merged #68 / PR #75 at `b2f0384`. Pending owner review.
See [the focused-tool report](../../UX4_TOOLS.md) for ownership, limitations,
validation results and exact manual acceptance steps.

The JSON files retain each gate's actual report, including generated fixture
hashes and temporary run paths. No captures, result bundles or third-party
runtimes are included. Headless reports may contain the engine's configured
backend name; that does not turn them into native renderer evidence.

## Native screenshots

These are the focused Window viewport contents, without operating-system title
bars. The suffix records the application window width, not the tool width.
All retained tool images are from the final Forward+ run.

- [Selection at 1440×900](selection-1440.png)
- [Selection at 1920×1080](selection-1920.png)
- [Conditional definition and shared selection context](selection-section-2.png)
- [Temporal shared request](temporal-section-2.png)
- [Matched runs](matched-runs-1440.png)
- [Quick setup](quick-setup-1440.png)
- [Buffered Performance](performance-buffered.png)
- [Probe with retained source-time stamp](source-probe-1440.png)
- [Probe scrolling fallback at 1024×640](source-probe-1024.png)

The fixture includes two fields, two meshes and exact particle IDs above 2^53.
Empty selection/result lists represent a freshly bound source; captures with
prepared data are used for explicit probes. Probe evidence intentionally advances
to a different source sample to show stale context. Full stamp content remains
reachable by scrolling at compact size. Normal buffered Performance is captured
separately from the synchronous deterministic navigation checks.

## Reproduction

Use an externally installed Godot executable and fresh output directories:

```sh
python3 tools/validate_focused_tools.py --godot "$GODOT" --renderer gl_compatibility --output-dir /tmp/ux4-tools-gl
python3 tools/validate_focused_tools.py --godot "$GODOT" --renderer forward_plus --output-dir /tmp/ux4-tools-forward
python3 tools/validate_recipe_state.py --godot "$GODOT" --output-dir /tmp/ux4-tools-recipes
python3 tools/validate_viewer_shell.py --godot "$GODOT" --renderer gl_compatibility --output-dir /tmp/ux4-tools-shell
python3 tools/validate_viewer_status.py --godot "$GODOT" --renderer gl_compatibility --output-dir /tmp/ux4-tools-status
python3 tools/validate_selections.py --godot "$GODOT" --output-dir /tmp/ux4-tools-selection
python3 tools/validate_temporal.py --godot "$GODOT" --output-dir /tmp/ux4-tools-temporal
python3 tools/validate_space_time.py --godot "$GODOT" --output-dir /tmp/ux4-tools-space
python3 tools/validate_diagnostics.py --godot "$GODOT" --output-dir /tmp/ux4-tools-diagnostics
python3 tools/validate_probe_marker.py --godot "$GODOT" --renderer gl_compatibility --output-dir /tmp/ux4-tools-probe
python3 tools/validate_g4_matched.py --godot "$GODOT" --renderer gl_compatibility --output-dir /tmp/ux4-tools-matched
```

The existing `validate_simulation_panel.py`, `validate_maintenance_ui.py`,
`validate_volume_color.py`, `validate_volume_opacity.py` and
`validate_volume_presets.py` gates also ran on Compatibility with fresh output
folders. Their reports are retained here. Source hash checks passed.

Initial failures and corrections are recorded in the report. No failed or
intermediate screenshot is presented as final evidence. Desktop interaction,
external captures, physical monitor scaling and final UX4 milestone acceptance
remain owner/later-issue checks.
