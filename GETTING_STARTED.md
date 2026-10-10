# Getting Started with Wavez

Wavez opens recorded particles, scalar grids and triangle meshes so you can
explore them together over time. This guide takes you from launching the viewer
to recording your own Python arrays. The supported capture format is **WVZ1**,
with the filename extension **`.wvz`**.

## Part I — Installation & Requirements

### Run the standalone viewer

The verified standalone build is **Linux x86_64**, built with the Godot 4.7.2
release template. Keep `WAVEZ.x86_64` and `WAVEZ.pck` in the same directory.
If the executable permission is missing, restore it, then launch:

```sh
cd /path/to/wavez-linux
chmod +x WAVEZ.x86_64
./WAVEZ.x86_64
```

The packaged executable contains the Godot runtime. You do **not** need a
separately installed Godot editor/engine, Python, NumPy or the source checkout
to open an existing capture. You do need a graphical Linux desktop and working
graphics drivers. The normal renderer is Forward+; if your graphics hardware
cannot run it, try Compatibility:

```sh
./WAVEZ.x86_64 --rendering-method gl_compatibility
```

Use **File → Open** to select a `.wvz` file. It opens at the first usable sample,
paused, while preparation continues. Press **Play** to advance recorded time.
The Simulation panel exposes **Particles**, **Fields** and **Meshes** according
to the objects in the file.

This is a verified review-package workflow, not a public installer/download
announcement. Windows, macOS, other Linux architectures and minimum hardware
requirements have not been established by this guide's validation. The tested
Linux release template has known Popup signal diagnostics during some menu/dialog
interactions; see [the investigation](docs/ROOT_WINDOW_SIGNALS.md).

### Choose dependencies for the work you want to do

| Work | Requirements |
| --- | --- |
| Open and play existing captures in the Linux package | Executable + PCK, graphical desktop and graphics drivers |
| Generate captures with Python | Python **3.10+**, `wavez-export` from this repository, **NumPy >=1.23** |
| Write/read Zstandard-compressed captures in Python | Python 3.14's standard-library Zstandard, or the optional `zstd` extra on older Python |
| Python analysis/source-selection workers in the viewer | External Python + NumPy, configured in **Edit → Preferences → File Locations** |
| Extract an isosurface | The optional `analysis` extra: scikit-image **>=0.26,<0.27**, declared for Python **3.11+** |
| Encode MP4 video | External **FFmpeg**, on PATH or configured in File Locations |
| Run the viewer from source | External **Godot 4.7.2** (the tested engine), source checkout and graphics drivers |
| Build the Linux package | Python, Godot and matching Linux export templates; see [packaging](docs/PACKAGED_VIDEO_EXPORT.md#build-and-run) |

The four examples below use only the base Python package and NumPy. They use
uncompressed, lossless output. No simulation framework, GPU Python library,
FFmpeg or scikit-image is needed to generate or view them.

### Install the Python exporter

Start in the root of your Wavez checkout, where `pyproject.toml` is located.
Create a virtual environment so installation stays separate from other projects:

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install .
python -c "from wavez_export import SceneCapture, SceneReader; print('Ready')"
```

On Windows, the environment activation command is `.venv\Scripts\activate`
in Command Prompt, or `.venv\Scripts\Activate.ps1` in PowerShell. These are Python
environment commands; they do not establish Windows viewer support. If `python`
is not your Python 3 executable, use its actual command or absolute path.

Install extras only when needed, from the same checkout:

```sh
python -m pip install ".[zstd]"
# Python 3.11+ for the declared scikit-image dependency:
python -m pip install ".[analysis]"
```

`pip` obtains the declared build backend (`setuptools>=61`) and runtime
dependencies. A normal installation may need network access. Package metadata
is authoritative: [pyproject.toml](pyproject.toml). The Python package version
and the viewer's application build number are separate identities.

For source development, launch your externally installed engine from the root:

```sh
/absolute/path/to/Godot --path viewer
```

To build a standalone review package yourself, use the existing
[Linux build instructions](docs/PACKAGED_VIDEO_EXPORT.md#build-and-run).
Building requires the engine and export templates; running the result does not.

## Part II — Integrating Your Python Simulation

### Try four complete examples

Run these commands from the checkout root with the virtual environment active.
Each source file is complete and can run independently:

```sh
python -m examples.getting_started_particles
python -m examples.getting_started_field
python -m examples.getting_started_mesh
python -m examples.getting_started_combined
```

The scripts print the absolute output path and create their parent directories.
They refuse to overwrite an existing capture. To run again, choose a fresh path:

```sh
python -m examples.getting_started_particles --output /tmp/particles-second.wvz
```

| Source | Default output | What to look for after File → Open |
| --- | --- | --- |
| [Particles only](examples/getting_started_particles.py) | `results/getting-started/particles.wvz` | Three points move upward over 0–1 seconds. The same explicit IDs remain attached to them. Use Particles. |
| [Scalar field only](examples/getting_started_field.py) | `results/getting-started/field.wvz` | A scalar mound shifts along x on a 5×7×11 grid. Use Fields and the named `amplitude` channel; volume/slice settings change its presentation. |
| [Mesh only](examples/getting_started_mesh.py) | `results/getting-started/mesh.wvz` | One triangle's top vertex moves sideways. Stable vertex IDs and unchanged triangle indices permit geometry interpolation. Use Meshes. |
| [Combined scene](examples/getting_started_combined.py) | `results/getting-started/combined.wvz` | Three moving points, a scalar mound and a static triangle beneath the grid. Inspect each Simulation category. At 0.5 seconds the field still shows its sample from 0 seconds. |

These are synthetic array demonstrations, not physical simulations. Coordinates
use explicitly declared **example length** units; the scalar amplitude is
dimensionless and is not density or mass. Seconds label the example clock.
No relation between the points, field and mesh is inferred.

If the view is hard to find, use **Frame Scene** (its binding is listed in
**Edit → Preferences → Keyboard Shortcuts**). Opening pauses playback; **Play**
shows motion. Fields hold their recorded values between samples. The viewer
may interpolate compatible persistent particle positions and stable mesh
geometry, but that does not add scientific observations.

### Connect arrays from your own simulation

1. **Describe the objects.** Give each a unique ID, kind and truthful units.
   Choose anonymous or persistent particle identity and none or stable mesh
   topology. Use IDs only when your simulation guarantees their lifetimes.
2. **Open a new capture.** Create the destination parent, then use
   `with SceneCapture(path, objects=objects, metadata=metadata) as capture:`.
   Record coordinate conventions, channel meanings and source provenance.
3. **Write samples at actual solver times.** Call `add_particles`, `add_volume`
   or `add_mesh` with the corresponding object ID and arrays. Each object's
   timestamps must strictly increase; objects can have different cadences.
4. **Finalize.** Leaving the context closes the file, including on exceptions.
   A failed write needs explicit error handling; there is no writer resume.
5. **Open and inspect.** Open the `.wvz` in Wavez, check geometry and source
   times, then explore the relevant Simulation categories.

Particle/mesh positions are finite float32/float64 arrays shaped `(N,3)`.
Persistent particle IDs and stable mesh vertex IDs are nonnegative, unique
int64 values and must not be recycled after removal. Particle positions must
already be in viewer-world coordinates. A triangle array is exact nonnegative
integer `(M,3)` indices, stored as uint32.

A scalar grid uses named float32/float64 arrays shaped **`(nz,ny,nx)`**.
Its **origin and spacing are xyz**, with positive spacing. Origin is the first
sample; `node` and `cell` centering describe different boundaries. All channels
in one volume sample share geometry. Declare coordinate units separately when
they differ from scalar units.

Extra channels, compression, static objects, mesh/volume transforms and derived
surfaces are optional. Persistent IDs are optional for anonymous particles but
required for `persistent_i8`; vertex IDs are required for `stable_topology`.
There is at most **one particle object** and **16 total objects** per capture.
Consult Part III before adapting nontrivial geometry or channels.

Keep export separate from numerical integration: do not change solver timesteps,
random streams, units or source arrays to suit a movie. Use independent recording
cadences, retain scientific checkpoints separately where needed, and review
copies/transfers from GPU arrays. Wavez does not infer scientific meanings.

## Part III — Technical Integration Reference

### Read in this order

1. [Capture format policy](docs/CAPTURE_FORMAT_POLICY.md) establishes WVZ1-only
   support and the supported writer/reader boundary.
2. [Python API](WAVEZ_API.md) supplies signatures, capture lifecycle, failures,
   exclusive paths, identity requirements and `SceneReader` behavior.
3. [Simulation integration guide](docs/SIMULATION_INTEGRATION_GUIDE.md) supplies
   coordinate, provenance and independent-cadence rules for real simulations.
4. [WVZ1 wire contract](docs/WVZ1_FORMAT.md) defines metadata, records, array
   types/associations, commit proofs, geometry, sampling and allocation limits.
5. Check the exact installed source: [scene.py](wavez_export/scene.py),
   [storage.py](wavez_export/storage.py), [codec.py](wavez_export/codec.py) and
   [the native reader](viewer/layers/scene_reader.gd). For presentation behavior,
   consult [scene sampling](viewer/layers/scene_layers.gd).

The policy defines supported scope, the API/wire documents define the contract,
and the source determines executable behavior for the version you use. If they
disagree, stop and reconcile the discrepancy before integration. This beginner
guide and the synthetic examples do not override those contracts. Frozen review
records describe the versions they tested.

### Find the exact rule you need

| Topic | Authoritative entry |
| --- | --- |
| Lifecycle, new paths, closing, I/O failure, reader errors and capacity | [API: write/read](WAVEZ_API.md), [reader budgets](docs/WAVEZ_METADATA_BUDGET.md) |
| Metadata, records, chunks, checksums, committed prefixes | [WVZ1: wire and scientific data](docs/WVZ1_FORMAT.md#wire-and-scientific-data) |
| Particle positions, IDs, births/deaths and anonymous identity | [API contracts](WAVEZ_API.md#write-a-scene), [geometry and identity](docs/WVZ1_FORMAT.md#geometry-and-identity) |
| Grid axes, shape, origin, spacing, centering and mesh/volume affines | [Geometry and identity](docs/WVZ1_FORMAT.md#geometry-and-identity), [integration](docs/SIMULATION_INTEGRATION_GUIDE.md) |
| Mesh vertices, triangles, winding, topology and vertex/face channels | [Geometry and identity](docs/WVZ1_FORMAT.md#geometry-and-identity) |
| Named channels, numeric shapes/types, units and provenance | [API](WAVEZ_API.md#write-a-scene), [metadata](WAVEZ_API.md#metadata-and-g4-analysis), [integration](docs/SIMULATION_INTEGRATION_GUIDE.md) |
| Transforms, timestamps, independent sampling and source precision | [Integration](docs/SIMULATION_INTEGRATION_GUIDE.md), [sampling and rendering](docs/WVZ1_FORMAT.md#sampling-inspection-and-rendering) |
| Limits, display approximations and unsupported features | [Allocation ceilings](docs/WVZ1_FORMAT.md#derived-surfaces-and-allocation-ceilings), [current boundaries](docs/CURRENT_STATUS.md#scientific-and-resource-boundaries) |
| Full-file integrity versus interactive opening | [Playback integrity](docs/PLAYBACK_INTEGRITY.md), [verifier](tools/verify_wvz.py) |

Verify a generated file from the checkout root:

```sh
python tools/verify_wvz.py results/getting-started/combined.wvz
```

This checks every record's payload checksums and required field statistics.
For lifetime identity checks, use `SceneReader.audit_identity()` as well.
Successful interactive opening alone is not full scientific-integrity proof.
Inspect an asymmetric fixture in the viewer and compare source coordinates,
arrays, units and timestamps before trusting an adapter. Follow the integration
guide's [adapter acceptance checks](docs/SIMULATION_INTEGRATION_GUIDE.md#acceptance-for-a-future-adapter).

### A prompt for an AI coding assistant

> Read GETTING_STARTED.md Part III, WAVEZ_API.md, docs/WVZ1_FORMAT.md,
> docs/SIMULATION_INTEGRATION_GUIDE.md and docs/CAPTURE_FORMAT_POLICY.md against
> the current wavez_export source. Inspect the simulation source I provide.
> Add WVZ1 capture output using SceneCapture without changing its numerical
> behavior. Ask about unknown units, identities, axes or channel meanings.
> Use actual solver times and explicit independent recording cadences. Keep
> source precision and provenance, require a new output path, and validate a
> small fixture with strict reading, identity auditing and viewer inspection.
> Report changes, tests and remaining uncertainty for my review.

Review generated changes yourself, especially units, provenance, channel
formulas, ID lifetime guarantees, time/cadence policies, coordinate transforms
and output paths. An assistant cannot establish those facts from appearance.

An optional, explicitly invoked setup helper could check dependencies and offer
commands for a user-selected virtual environment. It should show its actions
before installing anything. This is a follow-up proposal only; this issue adds
no dependency installer or startup changes.
