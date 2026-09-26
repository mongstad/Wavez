# SimScope Python API

**New integrations use `SceneCapture` and `SceneReader`, writing `.ssc` files in
SIMSCP4 format.** This reference follows [the current source](simscope_export/scene.py).
Install `simscope-export` from this repository; import it as `simscope_export`.
See [Quickstart](QUICKSTART.md) for dependencies and the native viewer.

## Write a scene

```text
SceneCapture(path, *, objects, metadata=None,
                       compression="none", compression_level=1)
capture.add_particles(object_id, time, positions, *, ids=None, **channels)
capture.add_mesh(object_id, time, positions, triangles, *,
                 vertex_channels=None, face_channels=None)
capture.add_volume(object_id, time, fields, *, origin, spacing, centering="node")
capture.close()
```

The signatures above describe the interface; use the executable example below.
Both classes support context managers. `close()` releases resources and can be
called again. Paths accept strings or `Path` objects; the parent must exist.
`SceneCapture` opens exclusively and refuses an existing destination. Expand `~`
yourself with `Path(...).expanduser()`; this API does not expand it automatically.

Each successful write flushes one committed object sample. Times are finite
float64 and strictly increase **per object**; records from different layers may
interleave. Writes are synchronous. There is no writer resume, archive queue or
per-record fsync promise. An I/O failure makes the writer unusable; retain the
committed prefix and choose a new destination.

Volume statistics are mandatory and computed once during export. The current
viewer consumes them after source validation; no legacy reader or optional summary
fallback is included. `tools/verify_ssc.py` recomputes summaries. Source arrays,
timestamps and precision are unchanged. See [format decisions](docs/SSC_ACCELERATION.md)
and the [complete capture-policy inventory](docs/SSC_CAPTURE_PARAMETERS.md).

| Argument | Contract |
|---|---|
| `objects` | 1–16 unique objects; at most one particle object. Each declares `id`, `kind`, `units`; particles/meshes declare identity as below. |
| `kind` | `particles`, `mesh` or `volume`. Unknown kinds refuse. |
| Particle `identity` | `anonymous` or `persistent_i8`; persistent particles require `ids=` on every sample. |
| Mesh `identity` | `none` or `stable_topology`; stable topology requires `vertex_channels["vertex_id"]`. |
| Optional object fields | `static=False`, `space="viewer_world"`, identity `data_to_world` are defaults. Static objects have one sample. Affines are row-major 3×4. |
| `positions` | Finite float32/float64 `(N,3)` arrays. Particle positions are already in viewer world and require identity affine. |
| `ids` / `vertex_id` | Nonnegative int64, unique per sample, never recycled after removal. Do not infer IDs from row order. |
| `triangles` | Exact nonnegative integer `(M,3)` indices within vertices, stored as uint32; source winding is CCW. |
| Particle channels | Scalar `(N,)` or vector `(N,3)` / `(N,4)` supported arrays; `velocity` is a named vector, not `velocities=`. |
| Mesh channels | Separate vertex and face dictionaries; array lengths match their association. |
| Grid `fields` | Nonempty dictionary of real scalar `(nz,ny,nx)` arrays sharing one geometry. |
| Grid geometry | `origin`/positive `spacing` are xyz; origin is the first sample. `centering` is `node` or `cell`; cell faces extend half a spacing. |
| Source dtypes | `f4`, `f8`, `u4`, `i8`, serialized little-endian. Unsupported dtypes refuse; use explicit real components for complex values. Scientific values are not normalized or narrowed for display. |
| Compression | `none` (default) or lossless `zstd`, level 1–6. Python 3.14 has native Zstandard; older Python uses the optional backport. |

The all-channel decoded sample limit is 256 MiB, with additional geometry,
identity, chunk and index limits in [G3_FORMAT.md](G3_FORMAT.md) and the
[format overview](docs/CAPTURE_FORMAT_AND_API.md). Nonfinite scientific channel
values remain explicit where supported; positions must be finite. Scalar numeric
broadcasting and implicit channel aliases are not part of `SceneCapture`.

## Read recorded values

```python
from simscope_export import SceneReader

reader = SceneReader(path, strict=True, cache_bytes=256 * 1024**2)
arrays = reader.read_sample(object_id, sample_index)
bracket = reader.bracket(object_id, requested_time)
value = reader.probe(volume_id, sample_index, channel, world_xyz)
reader.audit_identity()
reader.refresh(strict=False)
reader.close()
```

`read_sample` returns a dictionary of read-only NumPy arrays for one **object-local
sample index**, preserving source types. It reads all channels of that sample.
Use `.copy()` for independent editable arrays. `reader.objects` maps IDs to object
metadata; `reader.samples[id]` lists records for that object; `reader.records`
retains file order; `reader.times` is the sorted union of times.

`bracket` returns `(a, b, alpha, status)` or `None`. It reports source indices and
weight, not interpolated arrays. Static samples return `(0,0,0.0,"static")`;
exact times return an exact pair; between/after recorded times are `held`; before
the first dynamic sample is unavailable. The viewer separately interpolates
compatible ID-based particle positions and stable mesh geometry. Scalars and
volumes hold. Analysis counts native observations once, without inventing samples
from the union navigation clock.

`probe` is a spatial trilinear lookup in a recorded source grid using a float64
world coordinate and the declared affine. It returns a scalar or `None` outside
the domain or for any nonfinite corner. It uses full scientific values, never GPU
LOD or colors. `audit_identity()` checks the complete recorded ID history and
returns `True` on success; reading one sample only validates that sample's IDs.

`strict=False` withholds an incomplete trailing record while preserving preceding
commits; it does not accept corruption. Source changes require `refresh()` before
ordinary reads. The decoded cache is disposable and bounded separately from arrays
held by the caller. G4 uses an internal pinned-prefix adapter for reproducible
analysis/export; it does not change `SceneReader` into a public selective reader.

## Minimal executable example

Run in a directory where `example.ssc` does not exist:

```python
import numpy as np
from simscope_export import SceneCapture, SceneReader

objects = [
    dict(id="particles", kind="particles", units="m", identity="persistent_i8"),
    dict(id="field", kind="volume", units="kg/m^3"),
]
metadata = dict(
    time_unit="s", position_unit="m",
    channel_metadata={"field": {"rho": {
        "units": "kg/m^3", "quantity": "mass_density",
        "physical": {"mass_unit": "kg", "length_unit": "m", "scale": 1},
    }}},
)
xyz = np.array([[0., 0., 0.], [1., 0., 0.]], dtype="f8")
ids = np.array([7, 9007199254740993], dtype="i8")
with SceneCapture("example.ssc", objects=objects, metadata=metadata) as capture:
    capture.add_particles("particles", 0., xyz, ids=ids)
    capture.add_volume("field", 0., {"rho": np.full((2, 2, 2), 2., dtype="f8")},
                       origin=[0, 0, 0], spacing=[1, 1, 1], centering="cell")
    capture.add_particles("particles", 0.5, xyz + [0.5, 0, 0], ids=ids)
with SceneReader("example.ssc") as reader:
    assert reader.audit_identity()
    assert reader.read_sample("particles", 1)["particle_id"].tolist() == ids.tolist()
    assert reader.probe("field", 0, "rho", [0.5, 0.5, 0.5]) == 2.0
    assert reader.bracket("field", 0.5) == (0, 0, 0.0, "held")
```

Open with `godot --path viewer -- --capture=/absolute/path/example.ssc`.
[Mesh/field integration examples](docs/SIMULATION_INTEGRATION_GUIDE.md) and
`python -m examples.g4_demo --output NEW_DIRECTORY` cover more workflows.

## Metadata and G4 analysis

Metadata remains descriptive; the writer adds format version, generated UUID and
normalized object declarations, but does not invent simulation provenance or units.
For G4 use the exact keys `time_unit`, `position_unit`, and
`channel_metadata[object_id][channel_name]`. Channel declarations may contain
`units`, `semantic`, `quantity`, `physical` and `basis`. Unknown units stay unknown;
G4 never infers physical mass from a channel name or tracer density.

`time_units`, object `coordinate_units` and object `channel_units` may be retained
as arbitrary metadata but are **not** substitutes for those G4 declarations.
`channel_descriptors` belongs to the existing particle display/range metadata;
it is separate from G4 scientific channel declarations. See
[G4 schemas](docs/G4_SCHEMAS.md) for exact metadata and result provenance.

Selections, statistics, traces, CSV diagnostics, comparisons, inspection recipes
and exports are described in [the G4 guide](docs/G4_GUIDE.md).
`simscope_export.analysis` and `tools/analyze_selection.py` are internal worker
interfaces, not a public command service. G5 is not implemented.

## Supported package contract

Package **3.0.0** exports `SceneCapture` and `SceneReader` for SIMSCP4 scenes.
Capture magic/version, explicit object declarations and source dtypes determine
validity. No particle-only writer/reader or implicit conversion API is exported.
Use the [native integration guide](docs/SIMULATION_INTEGRATION_GUIDE.md) for
engine callbacks and [capture policy](docs/CAPTURE_FORMAT_POLICY.md) for the
supported contract. Package 3.0.0 records the intentional breaking change to a
SIMSCP4-only public API.
