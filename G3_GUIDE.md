# G3 quick guide

Work in the authoritative `SimScope` repository. Bulk historical material is in the external backup.
Generate a small analytic field, explicit-ID tracers, a deforming mesh and declared
demonstration guides. Captures are not shipped in Git. These are synthetic data,
not a reconstruction from a real tracer capture. New work targets `.ssc` / SIMSCP4
under the [capture format policy](docs/CAPTURE_FORMAT_POLICY.md).

```bash
python -m examples.scene_demo --small
/path/to/godot --path viewer -- --capture="$PWD/results/g3/small.ssc"
```

Use **Scene layers → Settings** for visibility, scalar channel, range, colormap,
volume opacity mapping/strength/step, slice orientation/distance, clipping and
isosurface threshold. Volume color ranges and opacity thresholds are independent.
For signed fields, choose **Magnitude • absolute scalar**, a non-negative
**Zero-opacity threshold**, and a larger **Full-opacity threshold**. Values at or
below the zero threshold are transparent; the full threshold reaches the selected
**Opacity / world unit** strength, not necessarily an opaque pixel. Use a symmetric
color range and a diverging colormap to distinguish sign. This is an explicit
display choice; it changes neither source values nor probes. Fresh views use
linear opacity thresholds 0–1. See [volume mapping](docs/VOLUME_OPACITY_MAPPING.md)
for the exact formula, persistence and legacy recipe behavior.

Volume color bounds remain fixed across playback. Edit them manually, or use
**Freeze symmetric range from sample** / **Freeze percentile range from sample**
to derive a frozen range from the currently displayed source sample. Percentiles
are explicit display choices; clipping and the source finite range are disclosed
beside the controls. **Logarithmic color** requires positive bounds and positive
finite source values; invalid samples are unavailable rather than silently
remapped. **Reset color • linear 0–1** preserves opacity settings. See
[volume normalization](docs/VOLUME_COLOR_NORMALIZATION.md) for policy, limits and
validation, including the distinction between frozen and interval-derived bounds.
For explicit starting views, select **Dense core**, **Faint structure** or
**Signed field**, then **Apply volume display preset from sample**. Dense core
uses the full finite range; Signed field uses symmetric color and magnitude
opacity. Faint structure uses the displayed percentile entries (set them
explicitly, for example 1 and 99); both its color and opacity can saturate cores.
These opt-in actions freeze explicit color/opacity settings, preserve strength
and ray step, and leave manual controls available. They do not change particles
or the scene Viewing preset. See [display presets](docs/VOLUME_DISPLAY_PRESETS.md)
for exact settings, evidence and limitations. Expand **What do these controls
change?** for the distinction between the five display concerns.

The three plane-normal controls also allow arbitrary orientations. Source probes
accept world xyz and draw a crosshair. Layer labels show source time/status and
preview LOD. Use Physical time to see independent layer cadences. The **Scientific**
preset removes decorative effects. Capture / Export uses the same layer state.

Isosurfaces use an optional dependency. Install the analysis extra into your chosen
Python environment:

```bash
python -m pip install '.[analysis]'
```

Extraction requires Python ≥3.11 and scikit-image 0.26.x. The viewer worker currently
targets the tested Linux Python runtime. NumPy capture writing/reading and Godot
meshes, volumes, slices/probes work without this extra. Missing dependencies produce
an extraction error while the rest of the viewer remains usable.

G4 adds selections, full-source numerical analysis and durable result export;
see the [G4 guide](docs/G4_GUIDE.md). Its Python/NumPy worker does not require
the optional surface-extraction extra.

## Write actual data

```python
import numpy as np
from simscope_export import SceneCapture, SceneReader

# Array is z,y,x with x fastest. Origin is the first sample, not the box corner.
z, y, x = np.meshgrid(np.arange(8), np.arange(6), np.arange(10), indexing="ij")
field = (x + 2*y + 3*z).astype("f8")
with SceneCapture("new-scene.ssc", objects=[
    dict(id="field", kind="volume", units="scalar units"),
    dict(id="tracers", kind="particles", units="world units", identity="persistent_i8"),
], metadata=dict(time_unit="s", position_unit="world units",
                 channel_metadata={"field": {"value": {"units": "scalar units"}}}),
   compression="none") as capture:
    capture.add_volume("field", 0.0, {"value": field},
                       origin=[1, 2, 3], spacing=[.5, 2, 1.5], centering="node")
    capture.add_particles("tracers", 0.0,
                          np.array([[1, 2, 3]], dtype="f4"), ids=np.array([123], dtype="i8"))
    capture.add_particles("tracers", 0.25,
                          np.array([[2, 2, 3]], dtype="f4"), ids=np.array([123], dtype="i8"))

with SceneReader("new-scene.ssc") as reader:
    print(reader.probe("field", 0, "value", [1.5, 4, 4.5]))  # 6
```

Choose a new output: `SceneCapture` refuses overwrites. Use `compression="zstd"`
for optional lossless compression. Add a mesh with `add_mesh(id, time, positions,
triangles, vertex_channels=..., face_channels=...)`. Positions are float Nx3;
triangle indices are integers Mx3. For fixed-topology animation declare
`identity="stable_topology"` and provide explicit int64 `vertex_id` in vertex_channels.
No IDs means held samples. Read [G3_FORMAT.md](G3_FORMAT.md) for precise limits.

## Import saved NPZ grids explicitly

The importer uses `allow_pickle=False`, checks uncompressed sizes/headers before
loading, and requires an axis/geometry mapping. Example mapping alongside `raw.npz`:

```json
{
  "version": 1,
  "name": "Saved raw density",
  "object": {"id": "density", "units": "density units"},
  "fields": {"rho": {"array": "rho", "axes": "xyz", "derive": "none"}},
  "geometry": {"origin": [-16, -16, -16], "spacing": [0.25, 0.25, 0.25], "centering": "node"},
  "snapshots": [{"file": "raw.npz", "time": 0.0}]
}
```

```bash
python tools/import_grid_npz.py mapping.json imported.ssc --compression zstd
```

`axes="xyz"` explicitly transposes existing Nx,Ny,Nz data into z,y,x. Use `zyx`
when already canonical. `real`, `imag` and `abs2` are explicit derivations for complex
input; export real/imaginary channels when phase must remain recoverable. Input hashes,
mapping and derivations are recorded as provenance. This adapter does not modify a
solver or infer a field from particle samples. Each NPZ snapshot is limited to
256 MiB uncompressed data.

## Reproduce checks

To generate both demos, run `python -m examples.scene_demo --small` and
`python -m examples.scene_demo` first (skip any you already generated).
They refuse to overwrite existing captures. Then:

```bash
python tools/benchmark_scene.py
python tools/validate_scene.py
/path/to/godot --headless --path viewer --script layers/test_scene_storage.gd
python tools/validate_scene_render.py --godot /path/to/godot
```

GPU validation prepares a job under `results/g3/video-check/`, then exports into a
fresh `results/g3/video-final-*/` directory. `results/g3/video-acceptance.json` points
to the latest completed MP4 and job; per-frame source states remain alongside it.
The tests use disposable fixtures/cache files under results and do not alter the
supplied real capture.
