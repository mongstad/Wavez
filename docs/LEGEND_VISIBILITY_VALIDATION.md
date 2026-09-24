# Independent legend visibility — issue #85

Implementation is pending owner review. Issue #85 was the top Ready item on
2026-09-24. The existing owner-linked branch is
`85-legend-visibility-should-be-independent-of-panel-visibility`, based on accepted
`main` at `a6a34c53abf59b12091b33385f368958f3329dba` (PR #90).
Fetch/prune completed, the initial tree was clean, and no previous local issue
branch remained to remove.

## Change

The particle legend's visibility predicate no longer depends on `overlay_visible`.
Show legend controls both the legend text and colorbar even with panels hidden.
Existing eligibility remains: a loaded scene and a scalar color channel are needed;
fixed and visual-color mappings still have no scalar legend. Recipe fields,
restore logic, panel actions, legend content and positioning are unchanged.

## Validation

Godot 4.7.2, NVIDIA RTX 3070 Ti, native KDE/Wayland:

| Run | Result |
|---|---|
| Baseline before the production fix | Four expected failures at the first manual-window checkpoint: enabled legend/colorbar hidden with panels hidden, including recipe restore |
| Forward+ particle fixture | 787 assertions, 16 native KWin window/geometry stages PASS; normal process exit; source SHA-256 unchanged |
| Compatibility particle fixture | 787 assertions, 16 native KWin window/geometry stages PASS; normal process exit; source SHA-256 unchanged |
| Headless editor import | PASS; new script UID generated and tracked |

The regression extends the existing fullscreen restoration test. At each stage it
checks all four combinations of Show legend and panel visibility, three repeated
panel toggles per combination, recipe restoration after changing the preference,
and fixed/visual-color exclusion. Native stages include manual sizes, maximized,
interactive fullscreen and restoration after interactive/immersive nesting.
Existing scientific state, sample and exact restored-window geometry checks remain.
Recipe checks exercise the canonical snapshot/apply path; file serialization is
unchanged and was not separately rerun. Screenshots of all four combinations were
captured in the manual window; retained evidence shows panels hidden with the
legend enabled and disabled.

The initial mixed particle/volume run reached all 787 passing assertions and
16 desktop stages but stalled during teardown and was terminated. It is not a
complete passing run; its cleanup cause was not resolved in this visibility fix.
An overlapping Compatibility attempt failed the shared KWin/DBus probe; final
runs were performed sequentially. That initial Compatibility attempt also logged
a cached-shader recompilation warning. Final runs logged the existing libdecor
GTK plugin fallback and Python Gio deprecation warning, with no Godot errors.

Reproduce using the tiny particle fixture from the existing helper:

```sh
python -c "from pathlib import Path; from tools.validate_simulation_panel import fixture; fixture(Path('/tmp/legend-particles.ssc'), ['particles'])"
/usr/bin/python tools/validate_immersive_desktop.py --godot /path/to/godot --capture /tmp/legend-particles.ssc --output-dir /tmp/legend-forward --legend-visibility
/usr/bin/python tools/validate_immersive_desktop.py --godot /path/to/godot --capture /tmp/legend-particles.ssc --output-dir /tmp/legend-gl --legend-visibility --renderer gl_compatibility
```

Run sequentially in a KDE desktop session. Output directories must not exist.
Reports and source hashes are retained in [evidence](evidence/issue-85/summary.json).
No production captures, other platforms, video exports, physical 4K or full-suite
runs were included. Historical reports/evidence were preserved unchanged.

## Owner verification

1. Open a particle capture and select a scalar Color by channel under
   Simulation → Particles → Color Mapping (not fixed or visual color).
2. Enable Show legend. Hide/show panels with F1 several times: text and colorbar
   should remain visible, and the checkbox should stay enabled.
3. Disable Show legend and repeat: both text and colorbar should remain hidden.
4. Repeat both cases in a manually resized window, maximized window and F11
   fullscreen, including returning from fullscreen.
5. Save a recipe with Show legend enabled and panels hidden. Change both, reload,
   and verify the legend is visible while panels are hidden. Repeat with the
   legend disabled and panels visible.

Then review the PR; acceptance and merging remain owner actions.
