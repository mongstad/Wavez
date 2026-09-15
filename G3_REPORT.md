> Historical checkpoint report; original scope, paths and measurements below
> describe that run. See [current status](docs/CURRENT_STATUS.md) and
> [retained evidence](docs/EVIDENCE_INDEX.md) for the accepted G0–G4 implementation.

# G3 implementation and measured acceptance — 2026-09-11

The reported HUD flicker is fixed, and G3a/G3b now provide actual meshes, scalar
volumes, movable slices, source probes, derived isosurfaces and simultaneous scene
layers. Work stayed in `SimScope`. The original 60-file baseline and supplied
4.08 GB capture still match their hashes (`results/g3/preservation.json`). G4–G6
were not started. See [G3_GUIDE.md](G3_GUIDE.md) and [G3_FORMAT.md](G3_FORMAT.md).

## Overlay fix

The interpolation phrase changed wrapping at exact and interpolated samples. The
HUD now installs its full text once and uses four short, stable lines; detailed
sampling policy remains in inspection state. The actual viewer test covered widths
290/366/600, both playback modes, exact/interpolated times and birth/death boundaries.
Before: 4/6 configurations moved controls or changed HUD height by 26 pixels.
After: 0/6 changed layout. Evidence: `results/hud-fix/{before,after}.json` and PNGs.
The check was rerun after integration.

## Delivered behavior

SIMSCP3 is an explicit layered format with independently committed typed samples,
none/optional Zstandard compression, grid bricks, checksums and allocation ceilings.
Python writes and reads it; Godot reads it and maintains disposable local indexes.
Existing capture bytes/defaults and the accepted particle-only prefetch path remain.

Static and deforming meshes support vertex/face scalars, normals, reflected transforms
and wireframes. Interpolation requires explicit vertex IDs and matching topology;
particles retain G2b ID-only matching and trails. Volumes use actual 3D scalar textures,
physical-step opacity, opaque depth, clipping and camera-inside rays. XY/XZ/YZ and
arbitrary planes use the declared grid transform. Source probes remain independent
of preview LOD. Field-only captures do not expose the internal empty UI-clock carrier
as a scientific particle layer.

Ranges and thresholds accept scientific notation without fixed spin-box rounding.
Display normalization handles the tested 1e-24 field; scientific storage stays
unchanged. Sidecars emit full-precision numeric text. Native decimal parsing can
differ at the final float64 bit; unchanged editor text preserves the original model.

Optional Lewiner extraction assembles the full source grid across bricks, omits
invalid cells, applies preflight/output limits, cancels stale requests and validates
cached surfaces. Parameters/provenance accompany the result. Recipes and video
share the layer sampler; video pins the source extent and waits for the correct
surface before drawing. NPZ imports require explicit axes, geometry and derivations,
use no pickle, and record source hashes. No wave solver was changed.

## Rendering and geometry evidence

`tools/validate_scene.py`, `viewer/layers/test_scene_storage.gd` and
`tools/validate_scene_render.py` reproduce the new checks. Machine-readable reports
and GPU logs are under `results/g3/`. Final counts: 23 Python tests, 251 native
storage checks, and 36 rendered checks on each backend, all passing.

| Acceptance area | Result |
|---|---|
| V01/V04 source probes | Non-cubic, anisotropic, translated/reflected grid; Python error tolerance 1e-11, Godot coordinate tolerance 3e-5 |
| V02 actual data | Direct grids drive rendering; NPZ real/imag/abs² mappings tested; particle-only sources report fields unavailable |
| V03/V04 rendered slices | Axis and oblique pixels match independently probed source values; max grayscale error below .003 |
| V05 slab opacity | World steps .05/.2/.7 give identical 8-bit center values per renderer; expected physical opacity agrees within .025 |
| V06 visibility | Camera-inside integration, opaque occlusion and refusal of a second translucent volume pass |
| V07 budgets | Texture LOD downgrade and source-probe invariance pass; lowering a cached mesh budget releases it |
| V08/I14 cadence | Changed grid geometry replaces textures; unavailable/held/static layers retain correct source times; stale textures are released |
| V09/V10 meshes | Explicit vertex IDs, topology changes, face/vertex association, normals, reflections and invalid indices/size limits tested |
| V11/V12 surfaces | Sphere max radial error .00667; torus .00881 source units; no artificial boundary edges in closed fixtures |
| V12 missing regions | Explicit holes remain at masked regions; no zero-valued scientific replacement |
| V13 async/cache | Threshold supersession and validated cache reuse/rebuild pass |
| V14 target demo | 128³ field + 100k ID tracers + mesh + guides + slice + level set rendered and measured below |
| V15 export | Fresh 640×640 H.264, four frames at .5/.75/1/1.25; each layer and surface has its correct source time/range/colormap |

The torus includes brick boundaries. Source-less tracers cannot supply a true field;
the provided large real capture has no grid. A direct-grid comparison against that
specific simulation therefore remains unavailable. The demo and geometric oracles
are explicitly analytic fixtures. There is no claim of a physical discovery.

## Storage and end-to-end measurements

Target: Ryzen 7 5800X, RTX 3070 Ti, 48 GiB system RAM, Fedora/Wayland, Godot 4.7.2,
Python 3.14.7. The layered fixture has 14 object records / 9 clock times, 100,746,624
raw array bytes: nine 100k-particle samples, three two-channel 128³ samples, two mesh
samples. Same arrays were rewritten with both codecs. These are single-host cached
filesystem runs; buffered close/flush is included, final fsync is not.

| Storage | File bytes | Raw/file | Rewrite including source read | Read/decode all records | Peak rewrite/read RSS |
|---|---:|---:|---:|---:|---:|
| None | 100,867,774 | 0.999× | .542 s | .157 s | 96.7 / 116.3 MiB |
| Zstd1 | 37,231,134 | 2.706× | .525 s | .193 s | 100.0 / 116.9 MiB |

`storage-benchmark.json` and the bitwise Python/Godot interop report retain the
measurements. The small write-time difference is not evidence of a durable-disk
speedup; Zstd decode is slower here.

The following 1280×720 Forward+ test presents 121 deterministic samples with all
layers, including an extraction barrier when the source grid changes. It measures
complete scene presentation throughput, not empty redraw FPS. No other renderer
ran concurrently. The scientific preset and test camera are recorded in the profiler.

| Scene storage | Sample CPU median / p95 | GPU median / p95 | Presented median / p95 | Mean completed throughput |
|---|---:|---:|---:|---:|
| None | 30.86 / 143.54 ms | .296 / 1.179 ms | 31.85 / 144.62 ms | 19.18 samples/s |
| Zstd1 | 30.74 / 147.76 ms | .300 / 1.375 ms | 31.73 / 148.84 ms | 19.23 samples/s |

This path is CPU-bound. ID matching/interpolation/style and new-sample decode produce
spikes; full extraction barriers reach approximately .59 s. Initial surface wait
is about .32 s for the compressed fixture. Interactive playback can keep rendering
while its worker runs and labels the pending surface. This is not a guarantee of
steady 30 FPS for the full G3 scene. Compression reduces storage, with no measured
playback benefit. Future optimization should target measured CPU sample preparation
and cancellable layer read-ahead.

Viewer peak/final RSS was about 886 MiB; engine-reported video memory about 158.3 MiB.
New mesh/grid/surface buffers accounted for 9.17 MiB, and the decoded cache for
236.9 MiB. Last full-grid extraction peaked at 77–78 MiB worker RSS. Total device
usage includes the desktop and is recorded separately in the profiler JSON. Worker
`ru_maxrss` inherited roughly 713 MiB from the Godot launcher; Linux VmHWM provided
the useful worker-only measurement. These are measurements of this fixture, not
promises of free RAM/VRAM or a process-wide cache ceiling.

The original real capture regression still delivers 11.82–11.90 source FPS with 12
requested. Cinematic/scientific/velocity p95 content gaps are 93/86/95 ms; the dense
opening is 105 ms (previous checkpoint approximately 102 ms). Full-prefix hashing
is absent from ordinary playback. Existing storage, typed IDs, recorded-pixel
comparisons, inspection/video, generic/legacy and HUD suites pass; detailed logs
are in `results/g3/regression/`.

## Explicit limits

One translucent volume and one derived surface; no correct intersecting-volume
compositing. Compatibility blends color in sRGB while Forward+ uses linear output;
both match their documented slab oracle. Probes use source values but Godot float32
locations. Surface extraction/display conversion is a declared derived approximation.
The uniform-grid adapter does not provide AMR, arbitrary vector-basis transforms,
CAD/skeletal meshes or reconstruction from particle samples.

Layer decoding is synchronous. CPU/GPU working buffers exist outside the decoded
cache, and GPU replacement can temporarily retain old and new resources. Persistent
cache disk size is not automatically capped. No writer resume, per-record fsync,
background archival queue or CuPy contention result is implied. Source identity,
allocation limits, cache disposal and replay constraints are specified in
[G3_FORMAT.md](G3_FORMAT.md).
