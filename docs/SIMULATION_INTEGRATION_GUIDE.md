# Simulation integration guide

**Wavez owns capture/storage/viewer mechanics. The simulation owns scientific meaning and declares its data truthfully.** Use native `SceneCapture` for new layered integrations. The adapter supplies objects, NumPy arrays, geometry and provenance directly; normal integration requires no manually authored mapping JSON.

Install and import the authoritative `WAVEZ` Python package; record its Git revision for provenance. [Current API](CAPTURE_FORMAT_AND_API.md) defines storage limits and compatibility; [source implementation](<../wavez_export/scene.py>) is the callable contract.

## Before connecting the writer

Declare the source coordinate system, units, axis order and sample geometry; state what each channel measures. Transform particle positions/vectors to viewer world in the adapter. Grids and meshes may instead declare a row-major 3×4 affine `data_to_world`. Object transforms do not perform scientific unit inference or general vector-basis conversion. Record any conversion explicitly and perform it once.

Supply host arrays in supported types: float32/64, uint32 or int64 as appropriate. Complex arrays must be exported as explicitly named real component channels. Preserve source precision for scientific field channels. Copy data from a GPU when necessary without writing back into the solver or consuming its random stream. Preflight total channels, staging copies, compression and viewer limits before allocating a large grid.

Objects require unique IDs, a kind and units. Current WVZ1 supports at most one particle object per capture (up to 16 total objects). Particle objects must explicitly choose `anonymous` or `persistent_i8`; mesh objects choose `none` or `stable_topology`. A volume requires origin, spacing and centering with each field sample. Record the model/version, parameter/configuration hash, source revision/hash, seed and seed interpretation, solver boundary conditions, channel formulas, coordinate transformation, precision, cadence policy and dependency versions in capture/run provenance. Metadata is descriptive, not a substitute for retaining executable sources and scientific configuration.

Units should be meaningful declarations such as simulation length, field amplitude or mass. If a unit is unknown, label it unknown/arbitrary and explain the limitation. Never invent mass from marker count, physical boundaries from particle extent, IDs from row order, vector transformations from scalar labels, or a true field from probes.

## Five independent clocks

| Clock | Owner and purpose | Recommended policy |
|---|---|---|
| Physics `dt` | Simulation integration accuracy/stability | Choose from numerical validation, never from desired movie speed |
| Diagnostics | Norm, energy, shape and event monitors | Choose to resolve numerical events; record actual measurement times |
| Particle visualization | Trajectory inspection | Independent explicit cadence; only interpolate identities the simulation guarantees |
| Volume visualization | Field inspection | Independent explicit cadence chosen for the source dynamics and storage/performance budget |
| Scientific archive | Exact full states/checkpoints, e.g. NPZ | Sparse requested scientific times plus required final/checkpoint states |

Keep these clocks separate for **every pattern below**, even if a simple run intentionally sets two cadences equal. Static meshes need only one sample. Each object's timestamps strictly increase; records for different objects may interleave. Write actual solver times, not the nominal due time when they differ. If output is emitted on the first solver step at or after a request, document that scheduling policy explicitly; do not silently split solver steps or fabricate intermediate scientific fields.

Native captures support inspection and retain declared scientific channel values. NPZ remains useful for full complex solver states, restart information, arrays unsupported by the viewer and independent numerical analysis. It is not a replacement for declared native scene semantics, nor does its sparse schedule need to dictate live field cadence. Use `allow_pickle=False` for ordinary numeric NPZ archives and preserve their configuration/source manifests.

## Integration patterns

The common coordinate, units, cadence and provenance rules above apply to each row. “Optional” channels are only appropriate if their scientific meaning is known.

| Pattern | Minimum native data | Optional channels and identity | Geometry and interpretation |
|---|---|---|---|
| A. Particle-only, anonymous | A `particles` object with `identity="anonymous"`; time and finite `(n,3)` positions | Velocity, mass, scalar/category, explicit display intensity/size; no IDs or inferred tracks | Positions already in viewer world; grid origin/spacing/centering not applicable. Held point clouds do not imply persistent material parcels. |
| B. Persistent particles | As A, but `identity="persistent_i8"` and simulation-owned nonnegative int64 IDs | Same channels; IDs unique within each sample and never recycled after removal | Row order may change. Birth/death semantics come from the simulation. Position interpolation/trails are allowed only through compatible identities. |
| C. Uniform scalar grid | A `volume` object; named real scalar array `(nz,ny,nx)`; origin `(x,y,z)`, positive spacing `(x,y,z)`, `cell` or `node` centering | Additional scalar channels on the same grid, each with units/semantics | Origin is the **first sample**, not automatically a face. Node bounds join first/last samples; cell faces extend half a spacing beyond samples. Declare affine if source axes differ. No particle IDs apply. |
| D. Complex scalar field | As C; export real and imaginary components with explicit names/formulas | Density `real²+imag²`, phase if meaningful; density units are amplitude squared | Store original complex field in NPZ when useful. Do not silently discard phase, normalize amplitudes, relabel components as vectors or average complex values to obtain density. |
| E. Field plus persistent tracers | One C/D volume and one B particle object, each on its own cadence | Interpolated source observables at tracer positions, alive/status flags; documented tracer estimator | Grid and particles must align after their declared transforms. Tracers sample a field; their count/brightness is not a field integral without an actual weight definition. |
| F. Mesh / stable-topology deformation | A `mesh` object; finite vertex positions and uint32 triangle indices | Vertex/face channels; normals; `stable_topology` requires explicit int64 `vertex_id` in vertex channels | For interpolation, ordered vertex IDs and topology must agree. Remeshed/derived surfaces use `identity="none"` and held geometry. Uniform-grid metadata is not applicable; transform vertices/normals consistently. |
| G. External engine | Extract engine time and positions into A or B | Velocity/mass only if supplied by engine; persistent IDs only under a verified lifetime policy | Declare engine units, frame and coordinate transform. Engine array index/hash is not automatically a valid unrecycled identity. Native WVZ1 is preferred for new layered work. |

For A/B/G, save scientific engine state separately if a capture omits restart variables. For C/D/E, archive full precision fields at scientific times while exporting fields often enough for inspection. For F, archive any topology/material state needed by the simulation; a displayed mesh alone may not be a restart. All patterns need provenance and actual timestamps even if only one layer is present.

## Small native example

This example exercises persistent tracers, a complex field represented as real channels, and a deforming stable-topology mesh. A second small capture demonstrates anonymous points, since the current format permits only one particle object per capture. It is a data example, not a physics solver. Run with NumPy and the authoritative package importable; the destination parent must exist and the filename must be new. `SceneCapture` refuses overwriting it.

```python
import numpy as np
from wavez_export import SceneCapture, SceneReader

objects = [
    dict(id="tracers", kind="particles", units="m", identity="persistent_i8"),
    dict(id="field", kind="volume", units="field amplitude"),
    dict(id="surface", kind="mesh", units="m", identity="stable_topology"),
]
xyz = np.array([[0, 0, 0], [1, 0, 0]], dtype="f8")
ids = np.array([100, 200], dtype="i8")  # allocated once by this example
vertices = np.array([[0, 0, 0], [1, 0, 0], [0, 1, 0]], dtype="f8")
triangles = np.array([[0, 1, 2]], dtype="u4")
vertex_ids = np.array([10, 20, 30], dtype="i8")
psi_zyx = np.ones((4, 4, 4), dtype="c16") * (1 + 2j)

with SceneCapture("example.wvz", objects=objects,
                  metadata={"purpose": "documented array example",
                            "time_unit": "s", "position_unit": "m",
                            "channel_metadata": {
                                "tracers": {"density": {"units": "amplitude squared"}},
                                "field": {"psi_real": {"units": "amplitude"},
                                          "psi_imag": {"units": "amplitude"},
                                          "density": {"units": "amplitude squared"}}}},
                  compression="none") as capture:
    for t in (0.0, 0.5, 1.0):
        capture.add_particles("tracers", t, xyz + [t, 0, 0], ids=ids,
                              density=np.array([5, 5], dtype="f8"))
        capture.add_mesh("surface", t, vertices + [0, 0, t], triangles,
                         vertex_channels={"vertex_id": vertex_ids})
        if t in (0.0, 1.0):  # independent field cadence
            capture.add_volume(
                "field", t,
                {"psi_real": psi_zyx.real, "psi_imag": psi_zyx.imag,
                 "density": psi_zyx.real**2 + psi_zyx.imag**2},
                origin=[0, 0, 0], spacing=[1, 1, 1], centering="node")

with SceneCapture("anonymous.wvz", objects=[
        dict(id="points", kind="particles", units="m", identity="anonymous")]) as capture:
    capture.add_particles("points", 0.0, xyz)
    capture.add_particles("points", 1.0, xyz + [1, 0, 0])

with SceneReader("example.wvz") as reader:
    reader.audit_identity()
    assert reader.probe("field", 0, "density", [0.5, 0.5, 0.5]) == 5.0
    assert reader.read_sample("field", 0)["psi_real"].dtype == np.dtype("f8")
```

G4 recognizes the exact metadata keys used above: `time_unit`, `position_unit`,
and `channel_metadata[object_id][channel]`. Arbitrary metadata aliases are not
unit declarations for analysis. This example declares amplitude-squared density,
not physical mass density; it cannot claim kilograms. See
[scientific metadata](../WAVEZ_API.md#metadata-and-g4-analysis) for explicit
physical declarations and [G4 schemas](ANALYSIS_SCHEMAS.md) for integral constraints.

At requested t=0.5, the particles/mesh have exact samples and the field is held at t=0. At t=0.25, persistent particle positions can interpolate; scalar density stays at t=0. The separate anonymous capture holds its point samples. The field is not temporally interpolated. `SceneReader.bracket()` reports source brackets; it does not itself implement the viewer's identity-aware interpolated geometry.

Open the result with Godot from `WAVEZ` using `godot --path viewer -- --capture=/absolute/path/example.wvz`. Use the installed Godot executable if it is not named `godot` on PATH. Inspect declared guides and source times before assessing the image. The [analytic scene example](<../examples/scene_demo.py>) and [G3 usage evidence](<SCENE_CAPTURE_GUIDE.md>) cover more rendering options.

## External-engine boundary

Use an explicit `SceneCapture` object and declared object IDs. External engines remain
outside the Wavez core; an adapter extracts only the engine-owned state required
for capture. Do not infer persistent identities from changing row order.

```python
with SceneCapture(path, objects=[particle_object]) as capture:
    capture.add_particles(
        "bodies",
        engine_time,
        positions,
        ids=persistent_ids,
        velocity=velocity,
        mass=mass,
    )
```

If the integration truly maintains lifetime IDs, declare `persistent_i8` and pass
that int64 array via `ids=`. Otherwise use anonymous/sample-local identity. Record
engine units, coordinate transforms and actual timestamps in capture metadata.

## External field-solver pattern

For a complex or scalar field solver, keep the solver authoritative and export
visualization snapshots independently of physics/diagnostic/archive clocks. Store
real/imaginary components or other source channels explicitly, declare grid
origin/spacing/centering and transform storage order separately from world-space
coordinates. Passive visualization tracers must never be confused with field norm
or material mass.

## Acceptance for a future adapter

Use a small asymmetric fixture with nonzero origin, unequal spacings and a nontrivial transform. Verify native round trips, source-grid probes, coordinate alignment, IDs/births/deaths, unequal layer cadences, incomplete trailing writes and export failure behavior. Compare the simulation with export enabled/disabled to ensure output changes neither numerical state nor random streams. Confirm scientific archives survive an export failure according to the simulation's documented policy. A headless parser test is useful but cannot establish rendered pixel correctness.

The explicit [NPZ importer](<../tools/import_grid_npz.py>) is for adapting **existing external archives** whose axes, geometry and derivations must be supplied. Its mapping requirement should not be imposed on normal native integrations, where those facts are already available in Python.
