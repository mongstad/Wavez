# PERF-003 mesh playback maintenance record

Implemented 2026-09-13 against accepted SimScope baseline
`808ff5a1bd88679c948a05bae258e72d2fffbf8b`. **Reviewed and accepted by the owner
on 2026-09-13**, based on this report and the retained regression evidence.
Accepted implementation checkpoint: `7974c78553042260b6fa920389de61e8389f5567`.
The exporter API/package remains 1.0.0. G5/G6 and benchmark 05 remain unstarted.

## Accepted regression benchmark and preservation

The owner accepted benchmark 04A/04B package **1.0.0**, based on
**v1.2.0-rc.1**, and it was promoted to private stable benchmark suite **v1.2.0**.
The stable tag points to `a5b61d2`; the pushed publication audit is `2e2c4b2`.
The benchmark repository remains private. Its scientific package, definitions,
reports, limitations, hashes, provenance, original tags and original assets
remain byte-identical. The stable release mirrors only the two existing archives,
with independent download/hash verification; the original asset manifest still
points to the original private review assets.

04B validates **deforming exterior-surface mesh representation backed by retained
full volumetric tetrahedral topology**. Neither acceptance nor PERF-003 claims
native interactive full-volume tetrahedral visualization. The retained workload
has 8,281 vertices, 41,472 source tetrahedra, 5,184 exterior triangles, and 21 load
factors from 0 to 1. This is a quasistatic load sequence, not physical dynamics.
The capture SHA-256 remains
`631660193ee215f059a9f731ee120ec24d473ed9e30c8bc45fce1b2defcaa409`.
No scientific generator was rerun. All new results use fresh sibling directories.

## Resulting behavior

Previously, interactive mesh sampling read and validated both source frames,
packed positions, recomputed normals, mapped colors, expanded face associations,
and rebuilt the surface on the playback callback. Repeated interpolation within
the same source pair repeated that CPU work.

A dedicated CPU worker now checks source stamps and chunk hashes, validates exact
vertex IDs and triangle bounds, and prepares immutable source pairs and display
arrays. It requests the current pair and up to four future pairs per visible mesh
in playback direction. Only exactly matching stable IDs and triangles interpolate;
changing topology or identity continues to hold the earlier geometry. Source
float64 arrays, int64 IDs, original vertex order, source-cell/face mapping, scalar
values, units and independent layer clocks are preserved.

The main thread stages at most one mesh upload per process frame and one future
surface per visible mesh. Once a stable pair is resident, playback updates a
relative position blend weight, using Godot's
[ArrayMesh blend shape API](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html).
The CPU computes endpoint differences and bounds; GPU interpolation uses float32.
Vertex and face colors hold the earlier source sample. The unshaded material and
winding/reflection convention are unchanged. GPU morph normals retain the base
surface normals because lighting is not used; explicit inspection recomputes the
same deformed normals as the synchronous path. Original-order preview positions
are also materialized on demand for inspection/framing.

Initial opening, explicit scientific sampling and deterministic export keep the
synchronous path, sharing the same CPU preparation code. Cold or superseded seeks
hold the committed clock until all required layers are ready. Mesh underflow joins
the existing Play/analysis guard. Hidden meshes do not request source payloads.
Source replacement clears stale display, and source/settings changes cancel
obsolete work. Closing joins the private worker; large packing loops check
cancellation cooperatively. GPU-budget and float32 display refusals keep valid
scientific source data and report the unavailable preview.

Particle and field cache/preparation policies are unchanged. Their only edits are
to include mesh underflow in the common Play-button guard. No scientific exporter,
source format, sampling policy, analysis kernel or future milestone was changed.

## Bounds and remaining costs

The mesh CPU cache is capped at `min(128 MiB, safe physical-RAM allowance / 4)`.
Charges include both decoded samples, temporary exact-ID maps, original and
expanded display arrays, morph input/output and overhead. Current target charges
must fit within half that limit, leaving room for active/in-flight data. Future
pairs fit only inside the cache limit; obsolete pairs are retired on the worker.
Before each job, the existing physical-RAM guard additionally reserves three job
charges. It excludes swap on Linux. These are conservative allocation charges,
not a whole-process RAM guarantee.

Current and staged meshes share the existing per-layer GPU quota; each receives
at most half. Morph buffers increase the per-surface charge by 128 bytes per rendered vertex
in addition to the base charge, reserving backend ping-pong/output buffers and
motion-vector headroom, accounting for the [OpenGL backend blend buffers](https://github.com/godotengine/godot/blob/master/drivers/gles3/storage/mesh_storage.cpp). This is not isolated VRAM telemetry. Unlike fields, meshes
refuse an oversized preview rather than reducing its topology. GPU creation and
submission still run on the main thread, so very large meshes may stall during
upload. Scientific inspection and on-demand positions/normals can also take time.
GPU submission, explicit scientific inspection and some renderer/event-loop costs
remain synchronous and outside PERF-003’s accepted scope.
There is no new native deformation exaggeration, shaded-mesh mode, combined
surface/wireframe control, interior-cell selection, or full-volume visualization.

## Retained 04B measurements

Both revisions used the same retained capture, identical instrumentation, Godot
4.7.2, NVIDIA RTX 3070 Ti / driver 610.57.04, OpenGL compatibility, 1280×800,
VSync off, fixed camera, earlier-sample face stress colors, and 12 seconds per run.
Each run had a fixed 0.5-second warmup. Tests were not run concurrently with timing;
OS disk/page-cache state was not flushed and the desktop was not otherwise isolated.
The baseline is a separate archive of the accepted commit with only the identical
profiling harness added. Rates below are load-factor units per wall second; the
UI's Physical-time mode does not turn this quasistatic sequence into dynamics.

| Workload | Callback p99 before → after | Maximum before → after | Underflow after |
|---|---:|---:|---:|
| Surface, 256 MiB decoded cache, 0.2 load/s | 23.441 → **2.805 ms** | 35.065 → **7.083 ms** | 0 |
| Wireframe, 256 MiB decoded cache, 0.2 load/s | 24.741 → **2.785 ms** | 36.294 → **7.564 ms** | 0 |
| Surface, 0 MiB decoded cache, 0.2 load/s | 46.903 → **2.800 ms** | 58.299 → **5.851 ms** | 0 |
| Surface, 256 MiB decoded cache, 0.4 load/s | 23.417 → **2.860 ms** | 48.273 → **6.924 ms** | 0 |
| Wireframe, 256 MiB decoded cache, -0.2 load/s | 24.841 → **2.793 ms** | 37.169 → **6.144 ms** | 0 |

All **45 timing assertions passed**. Every after run visited all 20 retained
intervals, had zero underflow and zero callbacks ≥50 ms, and advanced
99.83–99.86% of the requested wall-time load progression.
Exact terminal frames are covered separately by native equivalence and benchmark checks.
The mesh cache retained **28.80 MiB** within
its 128 MiB cap, with one future GPU surface. End process RSS was
**295.74–297.62 MiB**, with zero reported process swap.

Application callbacks are not monitor FPS or isolated GPU timing. The unchanged
full benchmark harness still observed longer event-loop gaps (about 144 ms) outside
the measured callback, so PERF-003 does not claim to eliminate every renderer/OS
gap. Its explicit synchronous mesh preparation measurement remains about 21 ms;
the gain comes from moving interactive work and avoiding repeated pair rebuilding.

## Validation

- **3,933 checks on each renderer** (OpenGL compatibility and Forward+), including
  every 04B source sample and midpoint, all original-order preview positions, exact
  source channels/IDs, oriented topology, held scalar colors, affine transforms and
  recomputed inspection normals. Both vertex and face associations are covered.
- **12 image pairs per renderer matched byte for byte**, including retained 04B
  surface/wireframe start, interpolated and terminal views. The predeclared allowance
  was ≤0.1% differing image components and ≤2e-6 preview-position rounding; actual
  images had zero differing components. The focused harness omits unused sky work
  on its plain background; the original full benchmark harness remains unchanged.
- **3,551 headless mesh checks**, including changing/no identity, changing topology,
  >2^53 IDs, empty meshes, reflected/mixed layers, cancellation barriers, latest seek,
  hidden/reveal, reverse loops, source replacement, tiny CPU/GPU budgets, source
  preservation on preview refusal, and synchronous inspection superseding requests.
- The original **04B native harness passed 174,666 assertions and 42 G4 trace rows**
  with exact source values/units and source-bound inspection images and bundles.
- Existing particle playback: **2,457 checks**; PERF-001/002 maintenance: **66 checks**;
  particle lifecycle: **38 checks**; existing G3 GPU suite: **36 checks per renderer**.
- Python suite: **225 tests passed**, including the optional extraction test using
  the isolated analysis runtime. Benchmark repository integrity verifies all
  **1,190 retained Git evidence files and 828 external files**, unchanged.

The [compact validation record](evidence/mesh-playback-maintenance/validation.json)
retains source/code fingerprints, unrounded timing summaries, renderer comparisons
and source checks. The [raw evidence manifest](evidence/mesh-playback-maintenance/raw-evidence-manifest.json)
records the new local review archive and every member hash; its contents were
independently read back and verified. Raw callbacks, new native images/bundles and
logs remain outside production Git. Original benchmark release assets are untouched.
The archive remains the unchanged local evidence assembled for review; its manifest
retains that provenance. Owner acceptance is recorded separately in this document
and the compact validation record. No new release archive was created.

## Reproduce without scientific generators

From the SimScope root, with a Godot 4.7.2 executable and Python/NumPy available:

```bash
python3 tools/validate_mesh_playback.py --godot /path/to/godot \
  --renderer gl_compatibility --output-dir /fresh/output/mesh-gl \
  --capture ../SimScope-Benchmarks/benchmarks/04_FEniCSx_DeformingMesh/frozen/04B/simscope/mesh.ssc
# Repeat with --renderer forward_plus and a different fresh output directory.
python3 tools/profile_mesh_playback.py --godot /path/to/godot \
  --baseline-viewer /separate/808ff5a/viewer --output-dir /fresh/output/mesh-profile \
  --capture ../SimScope-Benchmarks/benchmarks/04_FEniCSx_DeformingMesh/frozen/04B/simscope/mesh.ssc \
  --extended
python3 -m unittest discover -s tests
```

The profiling tool adds only its identical small harness to the separate baseline
viewer and verifies source hashes before/after. The optional G3 extraction tests
need the declared `analysis` extra (scikit-image 0.26); install it in an isolated
runtime. The benchmark's unchanged `run_viewer.py frozen/04B --output /fresh/path`
runs its native source/inspection checks using `SIMSCOPE_PROJECT` and `GODOT_BIN`.

## Repository and acceptance state

The benchmark acceptance repository is clean, private and pushed through `2e2c4b2`.
PERF-003 is complete and owner-accepted. Its implementation and this acceptance
record are promoted on production `main` to the private origin, following the
PERF-001/002 acceptance workflow. The existing licensing commit `f4e6bf5` is
preserved. No new production release tag or package/API version change is made.
The 15 pre-existing untracked Godot `.uid` files remain untouched. The workspace
maintenance queue marks PERF-003 complete. Acceptance changes only documentation
and acceptance metadata; retained source/code hashes, measurements, raw evidence,
scientific provenance and private benchmark release assets are preserved. Scientific
generators and regression/performance workloads were not rerun for promotion.
Work stops after acceptance; G5/G6 and benchmark 05 remain unstarted.
