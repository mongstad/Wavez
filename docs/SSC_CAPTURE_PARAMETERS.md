# SSC capture fidelity and parameter inventory — #102

The measurement boundary is **simulation fidelity → capture/export policy → SSC
format efficiency → viewer preparation/rendering**. Changing an earlier stage
cannot be credited as an improvement in a later stage. This inventory covers the
current public Python writer, the explicit NPZ adapter, and the external Free
Collapse producer used for the S0/S2 benchmark captures. Arbitrary caller code can
introduce additional selection/derivation policies; those must be inventoried for
any new producer before comparing its captures.

Source audit: `simscope_export/scene.py`, `codec.py`, `storage.py`,
`tools/import_grid_npz.py`, and the read-only external
`VB_FreeCollapse_v0_2.py` / `freecollapse_scene.py` (including retained run copies). Both retained producer scripts match the audited
source SHA-256 `d5c33b17fa79db85fbff1864a63e9c11285d76829709ceb9cdddbfad077bf9db`.
The external simulation is not a supported product integration and was neither
modified nor rerun. Its pinned old exporter must be replaced for future SIMSCP4
recordings; retired imports in its adapter are not restored in SimScope.

## Reading the classification tables

S = scientific evolution (field solver or explicitly identified passive probes).
C = capture/export cadence or selection only, independently of the field solver.
F = SSC structure/schema/record layout. B = file size. W = preparation/loading
work. T = temporal coverage, sampling or meaning available to playback.
Y = direct effect, N = no direct effect, V = value/content-dependent effect
(including compressed size), I = indirect or conditional effect explained in the
row. A Y under C does not mean the setting has no effects in F/B/W/T.
All controls affecting source values are fidelity controls even when T is N.

## Public writer and caller policy

`SceneCapture` has no `simscopedt`, `simscope_dt`, solver timestep, implicit sampler,
channel selector, mesh decimator, field resampler, or precision-reduction option.
The caller chooses every sample and array. One successful add call writes exactly
one object sample. Controls below include the caller choices exposed by its API.

| Parameter / choice | What changes | S | C | F | B | W | T |
|---|---|---|---|---|---|---|---|
| add-call frequency and supplied `time` | Per-object float64 clock, sample count, gaps and interval; independent object clocks | N | Y | Y | Y | Y | Y |
| start/stop time, number of add calls, interruption/failed writes | Committed coverage; incomplete tails withheld, no fabricated samples | N | Y | Y | Y | Y | Y |
| `objects`, object inclusion, `kind`, `id` | Which particle/mesh/volume layers are recorded and identified | N | Y | Y | Y | Y | Y |
| object `static` | Exactly one sample for a static object; changing geometry cannot be encoded as static | N | Y | Y | Y | Y | Y |
| particle `positions`, row selection/count/order | Actual sampled particles and positions; no implicit decimation | N | Y | Y | Y | Y | Y |
| particle `identity`, `ids` | Persistent exact int64 identities vs anonymous rows; births/deaths/lifetimes, interpolation eligibility | N | Y | Y | Y | Y | Y |
| particle `**channels` and component counts | Which scalar/vector observations exist; `velocity` is explicit | N | Y | Y | Y | Y | Y |
| volume `fields` dictionary | All included scalar channels, their names, values and array order | N | Y | Y | Y | Y | Y |
| field array shape / caller grid sampling | Spatial resolution; writer stores supplied grid, never resamples it | N | Y | Y | Y | Y | I |
| caller derived fields, filters, thresholds, normalization | Scientific values/meaning and possible nonfinite values; no such transformation hidden in writer | N | Y | I | V | V | I |
| source array dtype (`f4`, `f8`, `u4`, `i8`) | Precision/type and bytes per value; no lossy cast by writer (IDs/topology checked for exact conversion) | N | Y | Y | Y | Y | I |
| `origin`, `spacing`, `centering` | Spatial interpretation/bounds, not voxel count by themselves | N | N | Y | I | I | N |
| object `data_to_world`, `space`, units/channel metadata | Affine coordinates and scientific interpretation; no implicit unit conversion | N | N | Y | I | I | N |
| mesh `positions`, `triangles`, caller topology/decimation | Vertices/faces and spatial detail; no built-in mesh reduction | N | Y | Y | Y | Y | I |
| mesh `vertex_channels`, `face_channels`, normals | Recorded per-vertex/per-face detail; supplied vs computed display normals | N | Y | Y | Y | Y | I |
| mesh `identity`, `vertex_id`, topology/order across samples | Whether position interpolation is scientifically supported; remeshed samples hold | N | Y | Y | Y | Y | Y |
| `compression` (`none`, `zstd`) | Lossless storage codec; no precision/sample change | N | N | Y | Y | Y | N |
| `compression_level` (1–6) | Existing zstd speed/ratio; ignored by codec none; does not alter decoded bits | N | N | I | Y | V | N |
| `metadata` / descriptive object fields | Provenance, interpretation and metadata bytes; version/UUID supplied by writer | N | N | Y | I | I | N |
| output `path`, exclusive creation, close/context lifetime | Destination; closing/failed output terminates recorded extent | N | I | I | I | I | I |
| memory layout/endianness of caller arrays | Explicit contiguous little-endian copy; values preserved | N | N | N | N | N | N |

In the final row, export CPU/copy work can change despite identical recorded bytes.
Dictionary order can affect storage traversal/locality, but never channel inclusion.
All channel values (including NaN/Inf/signed zero where allowed) are retained.
Nonfinite positions and unsupported scientific dtypes are refused, not silently fixed.

Format-owned constants are not scientific tuning parameters: 4 MiB canonical
contiguous chunks, mandatory per-volume statistics, 80-byte headers, 48-byte
commits, SHA-256 checks, 1 MiB prefix metadata, 4 MiB descriptors, 256 MiB decoded
samples, 32 MiB aggregate descriptor charge, at most one million records, 16
objects/one particle object, 256 arrays, 4096 chunks/array, grid dimensions 2–512,
mesh limits one million vertices/two million triangles, particle limit ten million
(also subject to 256 MiB/sample), and persistent identity lifetime limits. These
change refusal/capacity and structural overhead, not automatic sampling. Hitting
a limit is a failed export and must be reported; reducing fidelity to evade it is
a separate experiment. `storage.MAX_IDS` is one million distinct lifetime IDs.

The existing codec implementation fixes zstd `window_log=22`,
`content_size_flag=1`, `checksum_flag=1`, `nb_workers=0`; these affect format framing,
bounds, export work and stored bytes, not source fidelity or cadence. They are
unchanged in comparisons. No dictionary, quantizer or temporal predictor exists.

`SceneReader(strict, cache_bytes)`, analysis memory limits, viewer cache/GPU budgets,
selected channel, preparation interval, playback speed, interpolation, LOD and
render quality are downstream controls. They do not change SSC samples or size.
They do affect work, presentation, and potentially visible timing/spatial quality;
full-quality comparisons must fix them and report any LOD or buffering.

## Free Collapse benchmark producer

The requested spelling **`simscopedt`** is not a parameter in the audited producer
or current SimScope package. Its actual Python name is **`simscope_dt`**, exposed
as **`--simscope-dt`**. CLI names generally replace underscores with hyphens.
It controls **particle recording cadence**, not field cadence or solver `dt`.

The solver advances to `min((step+1)*dt, t_end)`; export deadlines never shorten its
step. Particle recording occurs on the first accepted solver step reaching the
next deadline. Multiple deadlines within one step collapse to one record. Field
recording occurs at requested snapshots OR the independent positive volume cadence.
Both layers also receive initial and (if not already recorded) final samples.
`simscope_volume_dt=0` disables periodic field export but still records snapshots,
initial and final fields. `save_fields=False` disables NPZ files, not snapshot-driven
SSC field records. These details prevent mistaking sparse fields for format speed.

| Parameter / choice | What changes | S | C | F | B | W | T |
|---|---|---|---|---|---|---|---|
| `dt` | Field integration and passive-probe Heun step; quantizes reachable export times | Y | N | I | I | I | Y |
| `t_end`, `max_steps`, interrupt/error | Simulation duration and finalization; shorter runs record less | Y | N | Y | Y | Y | Y |
| `N`, `L`, CLI `domain_preset` / `--N` / `--L` | Solver grid/domain and `dx=L/N`; field shape, spacing and probe spatial support | Y | N | Y | Y | Y | I |
| `precision` | complex64/128 solver and full f4/f8 field export; several tracer diagnostics explicitly cast f4 | Y | N | Y | Y | Y | I |
| `backend`, `--cpu` | NumPy/CuPy arithmetic and speed; possible rounding differences, same nominal grid/clock | Y | N | N | V | V | I |
| `case` | S0 forces zero initial noise; otherwise selects experiment labeling/configuration | Y | N | I | V | V | I |
| `alpha`, `g3`, `g5` | Field equation coefficients; alpha also enters probe current/velocity | Y | N | N | V | V | I |
| `A`, `R0`, `sigma`, `k_in` | Initial field amplitude, radial profile and inward phase | Y | N | N | V | V | I |
| `noise_amplitude`, `noise_seed`, `noise_modes`, `noise_lambda_min`, `noise_lambda_max` | Initial perturbation values/scales; scientific realization | Y | N | N | V | V | I |
| `sponge_width`, `sponge_gamma_max` | Absorbing field boundary and recorded probe sponge diagnostic | Y | N | N | V | V | I |
| `simscope` / `--no-simscope` | Enables SSC and passive probes; no feedback into field equation | probes | Y | Y | Y | Y | Y |
| `simscope_dt` / `--simscope-dt` | Particle sample interval; does not change probe integration or field solver step | N | Y | Y | Y | Y | Y |
| `simscope_volume_dt` | Additional periodic full-grid samples; zero retains snapshot/initial/final policy | N | Y | Y | Y | Y | Y |
| `snapshot_times` | SSC field deadlines AND optional NPZ/plots; snapped to accepted solver times; diagnostic emission can stop a failed run | I | Y | Y | Y | Y | Y |
| `simscope_tracers` / adapter `tracer_count` | Number of passive seed slots/IDs retained in every particle frame | probes | Y | Y | Y | Y | I |
| `simscope_uniform_frac` | Mixture of density-weighted seeds and uniform eligible-cell seeds | probes | Y | N | V | V | I |
| `simscope_density_floor_frac` | Eligible cells for uniform seeding relative to initial peak density | probes | Y | N | V | V | I |
| `simscope_seed` | Independent probe RNG realization, including subcell jitter | probes | Y | N | V | V | I |
| `simscope_rho_floor_frac` | Regularizes sampled velocity denominator; changes probe trajectories/velocity, not field | probes | N | N | V | V | Y |
| `simscope_speed_clip` | Optional velocity limit during probe integration; zero disables; changes paths | probes | N | N | V | V | Y |
| `simscope_visibility_floor_frac` | Recorded opacity fade only; keeps field density, particle slots and alive channel | N | N | N | V | I | N |
| `simscope_compression` (`auto`, `none`, `zstd`) | Auto resolves by installed codec availability; pin resolved codec for comparisons | N | N | Y | Y | Y | N |
| `simscope_compression_level` | Existing lossless compression effort/ratio | N | N | I | Y | V | N |
| `diag_dt` | Diagnostic schedule; nonlinear timestep check can terminate run, changing coverage | I | N | I | I | I | I |
| `analysis_radius`, `boundary_contact_frac` | Diagnostic sphere/contact reporting only; no field mutation | N | N | I | I | N | N |
| `vortex_dt`, `vortex_floor_frac`, `vortex_link_limit`, `spectral_dt` | Diagnostic cadence/criteria; separate outputs and warnings, no SSC channel selection | N | N | I | I | N | N |
| `save_fields` / `--no-fields`, `plots` / `--no-plots` | Separate NPZ/plot outputs; extra I/O can affect wall time, not nominal SSC fidelity | N | N | I | I | N | N |
| `legacy_vbc` | Additional external legacy file; does not remove SSC fields/channels | N | N | I | I | N | N |
| `output_root`, `label`, `simscope_launch`, `simscope_project`, `godot` | Paths/metadata/launching; potential competing viewer workload, no nominal sample changes | N | N | I | I | N | N |

I in metadata-only rows denotes configuration/provenance bytes, not extra arrays.
Any I/O failure can terminate the external run; this is not a nominal cadence policy.
The adapter `coord`, `dx`, `SOURCE_TO_VIEWER`, `origin`, `spacing`, cell centering,
axis transpose `(2,1,0)` and `y_up` determine spatial interpretation. Its `metadata`
records scientific provenance; `compression`, `compression_level`, `legacy` and
`path` map to the rows above. Field derivations are fixed: density=real²+imag²,
psi_real, psi_imag, all at full solver resolution and source real precision.
There is no field/channel/mesh decimation setting in this adapter; no meshes are
produced. Stable int64 probe IDs include dead slots (`alive=0`), so death does not
reduce recorded particle count. Initial seed jitter is ±0.45 cell, positions are
clipped to the interior; these fixed policies are part of the sampling provenance.

Fixed particle channels are position, velocity, density, phase, radius,
current_magnitude, radial_velocity, wave_vphi, specific_wave_lz, color_value,
visual_brightness, opacity, alive, particle_type, sponge_gamma and particle_id.
Brightness/opacity are recorded visual channels, not replacements for density.
Changing this list, derivations or explicit f4 casts is a fidelity/schema experiment.

## Explicit NPZ grid importer and fixtures

| Parameter / choice | What changes | S | C | F | B | W | T |
|---|---|---|---|---|---|---|---|
| mapping `snapshots`, each `file`, `time`, order | Which source grids/times are recorded; no inferred missing snapshots | N | Y | Y | Y | Y | Y |
| mapping `fields` names and each `array` | Channel inclusion/source selection | N | Y | Y | Y | Y | I |
| field `axes` | Explicit storage axis transpose, not decimation | N | N | I | V | I | N |
| field `derive` (`none`, `real`, `imag`, `abs2`) | Recorded scientific quantity and real precision inherited from source | N | Y | Y | V | V | I |
| mapping/per-snapshot `geometry` | Origin/spacing/centering; override is per sample | N | N | Y | I | I | N |
| mapping `object`, `name`, metadata/provenance | Object identity, affine/units and provenance | N | N | Y | I | I | N |
| source array shape/dtype/values | Full supplied spatial grid and scientific content | N | Y | Y | Y | Y | I |
| `--compression`, output path | Same writer codec/destination controls above | N | N | Y | Y | Y | N |

The importer has no stride, timestep, spatial reduction or channel inference.
Its 256 MiB source limit and bounded NPZ/mapping tables refuse oversized inputs.
Example/test generator controls (`scene_demo --small`, particle counts, mesh/grid
sizes, number/times of frames, channels, dtype, random seeds and codec) define
fixture content. Small fixtures are for regressions, not evidence that production
loading became faster. Analysis isosurface level/smoothing/selection and result
export choose newly derived scientific data; they are not alternate SSC compression.

## Derived mesh exporter

`tools/extract_surface.py` also writes SSC. Its job `source`, pinned `extent` and
`sha256`, `object`, sample `index`, and scalar `channel` select the exact source
observation; `threshold` chooses the level set and can drastically change vertex/
face count, geometry, file size and workload. All have S=N, C=Y, F=Y, B=Y, W=Y,
T=I (sample selection changes recorded time/coverage). `cache` selects a derived
output location (S/C/T=N, F/B/W=I for metadata/caching only); `request` is correlation
metadata, not scientific selection. Output is one static mesh at source time with
identity none. These are derived scientific outputs, not alternative encodings of
the original field.

Fixed extraction policies are Lewiner marching cubes, float32 algorithm input and
positions (overflow refusal), uint32 faces, source spacing/origin/affine, descent
winding, no degenerate faces, and omission of cells with any nonfinite corner.
There is no smoothing or decimation; the algorithm's default step size is one.
Vertex/triangle preflight ceilings refuse overly complex results. Changing these
policies changes derived spatial/scientific detail and must be a separate study.

## Actual benchmark settings

| Recorded property | S0 | S2 |
|---|---|---|
| Solver `dt`; grid; precision | 0.005; 128³; single | 0.005; 128³; single |
| Domain `L`; spacing | 64; 0.5 | 64; 0.5 |
| `simscope_dt` | 0.25 | 0.5 |
| `simscope_volume_dt` | 0.1 | 0.5 |
| Field records / particle records | 617 / 247 | 401 / 401 |
| Particles in every recorded frame | 50,000 | 100,000 |
| Field channels / dtype | density, psi_real, psi_imag / f4 | Same |
| Recorded interval | 0–61.6 | 0–200 |
| Configured `t_end` | 300; export failed at 61.7 | 200 |
| Resolved codec / level | zstd / 1 | zstd / 1 |
| Snapshot list | 0,5,10,12,14,16,20,30,40,60,80 | Same |

Full configs are retained in compact evidence, with path-only launch/destination
settings omitted. Different S0/S2 configs define different workloads; performance
ratios compare each workload only against its own equivalent re-export.

## Fair before/after protocol

1. Freeze producer source/configuration, resolved codec+level, object/channel list,
   shapes/dtypes/geometry, particle/mesh identities/topology, sample order and exact
   float64 timestamps. Record actual completion/error status as well as intended end.
2. Prefer re-exporting the same authoritative arrays through the two writers. Use
   the accepted revision's reader only in an external benchmark harness to recover
   old test inputs; no old-format parser ships in the new runtime.
3. Compare a canonical SHA-256 over every record's object/time, geometry,
   name/dtype/shape/association and every decoded source byte. Verify statistics
   independently. Format/version/UUID may differ; source provenance stays intact.
4. Separate source reading, writer CPU/wall time, total I/O, file/descriptor bytes,
   viewer open/first draw, preparation, switches, seeks and committed playback.
   Hold native renderer/window, quality, selected channel, LOD, speed and interval
   fixed. Report OS cache/other desktop activity and timing noise.
5. Full-timeline comparisons retain every sample. Selected-range comparisons use
   the same interval in each variant and are explicitly labeled scope experiments.
   Changing `simscope_dt`, field cadence, channel inclusion, resolution, precision,
   tracer population or end time cannot count as a format optimization.

S0's intended end is not its recorded end: the retained producer summary reports
`Index metadata ceiling` at t=61.7; SSC ends at 61.6. Equivalent re-export preserves
that exact prefix and does not invent the missing remainder. S2 records through
200. The evidence report supplies counts, resolved settings and bitwise checks.
