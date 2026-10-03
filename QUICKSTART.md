# Quickstart

Run from the `WAVEZ` repository root with Python 3.11+ (the base library supports 3.10+)
and Godot 4.7.2, the accepted viewer validation version.

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install -e '.[analysis,zstd]'
python -m examples.scene_demo --small
# Use your Godot executable if it is not on PATH:
godot --path viewer
```

Open `results/g3/small.wvz` in the viewer. The first sample appears paused while
bounded preparation starts automatically; press **Play** when ready to advance
recorded time. Optional surface extraction uses scikit-image;
Zstandard uses the standard library on Python 3.14+ or the declared backport.
Use `SceneCapture` for all new integrations; see [integration](docs/SIMULATION_INTEGRATION_GUIDE.md)
and [public API](WAVEZ_API.md). G4 selections and analysis
use Python/NumPy; follow [the G4 guide](docs/G4_GUIDE.md) or generate its synthetic
walkthrough with `python -m examples.g4_demo --output results/g4-demo`.

Wavez does not require any scientific-simulation checkout. Optional external
integration work uses caller-supplied paths; see [repository boundaries](docs/REPOSITORY_BOUNDARY.md).

Small validation (no scientific production runs):

```sh
python -m unittest discover -s tests -v
python tools/validate_scene.py
python tools/validate_temporal.py --godot /path/to/godot --output-dir results/check-temporal
python tools/validate_maintenance_ui.py --godot /path/to/godot --output-dir results/check-ui
```

Choose fresh validation output directories. Use `--renderer gl_compatibility` or
`--renderer forward_plus` for actual maintenance UI images; `--resolution 3840x2160`
uses an exact GPU SubViewport with the existing export canvas scaling. Headless
checks establish behavior, not rendered appearance. Capture and regression
fixtures use WVZ1. Current storage, viewer, analysis and deterministic-export
validation are recorded in the maintained reports under `docs/`.

Generated `results/`, local environments, caches and captures are ignored by Git.
Historical comparison tools requiring archived baselines need those supplied explicitly.
