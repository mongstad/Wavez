# Hidden legend defaults — issue #105

Pending owner review. #105 was the only Ready Project item. The exact existing
owner-linked branch is `105-ux-legend-001-start-with-legend-overlays-hidden-by-default`,
starting clean at accepted main `a97af18f44690cd6b31a9d0c74eee423c356fa4d`
(PR #134). Local main and linked remote branch matched; fetch/prune completed,
and the previous completed local branch was already absent.

## Behavior

Particle `show_legend` starts false and its checkbox reads that value. Field and
mesh controls and card eligibility use false when no per-object preference is
stored. This is a default-only change: no legend content, styling, placement,
rendering or unrelated overlay changes. The application candidate is `v0.1.0.4`.

Explicit true/false recipe values restore exactly as before. A missing per-layer
preference uses the new hidden default, including recipes without the optional
legend dictionary. Missing particle preference continues to retain the live
session value. Replacing a capture preserves the particle session preference;
new field/mesh controllers begin with unspecified preferences hidden. No reset
on every load, migration or new persistence mechanism is introduced.

The existing test for enabled legends now enables them through the real controls
before checking content/layout. The video fixture explicitly enables per-layer
legends rather than relying on the old default. The shell's enabled-legend
regression explicitly opts in too. Historical evidence remains unchanged.

## Validation

Godot 4.7.2, Linux x86_64, NVIDIA RTX 3070 Ti, tiny synthetic mixed SSC fixture:

- Focused layer legends: 78 assertions passed on each of Forward+ and Compatibility.
- On each renderer, one-frame MP4 exports with overlays on and off completed;
  frame hashes differ, preserving the explicit export inclusion gate.
- Recipe JSON roundtrip, independent controls, malformed preference rejection,
  scientific/sample/prepared-layer invariance, content, compact layouts,
  panel independence and immersive behavior remain covered.
- Existing shell suites: 679 assertions passed per renderer, with matching menu
  contracts and unchanged source hashes (1,514 native assertions overall).
- Both Python version tests, packaged-notice drift, documentation links and all
  three executable documentation examples passed. Godot import and whitespace
  checks were clean. No test failures were encountered.

See [validation ledger](evidence/issue-105/validation.json). No production capture
rerun, standalone packaged application, other OS or long-session performance test
was needed/performed for this preference change. Video exports use the installed
Godot runtime and external FFmpeg; neither is bundled in the repository.

Reproduce with fresh output directories, running native suites sequentially:

```sh
python tools/validate_layer_legends.py --godot /path/to/godot --output-dir /tmp/legend-forward --export
python tools/validate_layer_legends.py --godot /path/to/godot --output-dir /tmp/legend-compat --renderer gl_compatibility --export
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/shell-forward
```

## Owner verification

1. Launch a fresh viewer and load an SSC with scalar fields/meshes/particles.
   Confirm no legend is visible and Show legend controls are unchecked.
2. Enable each legend manually; confirm the same content, appearance and placement.
3. Toggle legends off/on independently and hide/show the simulation panel.
4. Save and restore explicit enabled/disabled recipe choices; confirm they restore.
   A fresh capture's field/mesh legends without preferences should remain hidden.

Current handbook/status documentation is synchronized. Historical review reports
are preserved. Passing checks are not owner acceptance; stop for owner review.
