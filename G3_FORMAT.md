# G3 — SIMSCP3 layered capture contract

Implemented in the authoritative `SimScope` repository. `SceneCapture` / `SceneReader` are
the supported writer/reader APIs. See [G3_REPORT.md](G3_REPORT.md) for historical
acceptance, [G3_GUIDE.md](G3_GUIDE.md) for examples and the
[current capture policy](docs/CAPTURE_FORMAT_POLICY.md) for the native-only contract.

## Wire and scientific data

All numbers on disk are little-endian. Prefix `<8sII>` is magic `SIMSCP3\0`,
version 3, metadata byte length, then at most 1 MiB UTF-8 JSON. Metadata has version,
a hexadecimal UUID and 1–16 unique objects. Each object declares `id`, `kind`
(particles/mesh/volume), `units`, `space: viewer_world`, `static`, and affine
`data_to_world` (row-major 3×4). The writer supplies identity transform/static=false
when omitted. Required unknown kinds fail; this version has no optional-kind skip.
Additional descriptive metadata, including channel units/provenance, is retained.

One record per object sample uses `<4sIQQdIIQ32s>` (80 bytes): `FRM3`, descriptor
length, stored bytes, decoded bytes, exact float64 timestamp, object-table index,
array count, global sequence, descriptor SHA-256. Descriptor JSON contains `geometry`
and `arrays`. Payload follows. The 48-byte `<8sQ32s>` commit has `COMMIT3\0`, sequence,
and SHA-256(header + descriptor). No footer is needed. Object timestamps strictly
increase; records for different objects can be interleaved independently. A static
object has one sample. Incomplete trailing records remain unavailable; corruption
is an error, not a fabricated recovered frame.

Arrays declare name, dtype (`f4`, `f8`, `u4`, `i8`), shape, association and chunks.
Each chunk has decimal-string offset/stored/decoded lengths, codec 0/1, and raw/stored
SHA-256. Codec 0 is none (default); codec 1 is independent Zstandard, default level 1.
No dictionaries or preceding samples are required. Existing bounded codec checks
apply. Compression is lossless; no scientific-value normalization is performed.
NaNs, signed zero and source float precision survive round trips. There is no lossy
storage option in this release.

Particles/meshes use contiguous chunks of at most 4 MiB. Grid scalar channels use
canonical 32³ bricks, shortened at edges, each with z,y,x origin and shape. Grid
arrays are C-order `(Nz, Ny, Nx)`, x fastest. Readers validate exact brick coverage,
byte totals and commit/checksums before accepting data. Complete grids are assembled
for display/analysis; brick boundaries do not become extraction boundaries.

## Geometry and identity

Grid geometry declares shape in zyx, spacing in xyz, origin of the **first sample**
in xyz, and centering `node` or `cell`. Node bounds end at the first/last sample;
cell faces extend half a spacing past sample centers. `data_to_world` maps these
local coordinates into viewer-world coordinates. Numeric probes use source array
values, not GPU previews. Python coordinate math is float64; this Godot build uses
float32 Vector3 coordinates, so viewer probe-location accuracy is limited accordingly.
Decimal UI/JSON parsing can differ at the last float64 bit in this Godot build;
unchanged numeric text does not overwrite its model value. Binary array/timestamp
storage remains exact. Probe results outside the domain or involving any nonfinite corner are unavailable.

Mesh `position` is float `(N,3)`; `triangles` is uint32 `(M,3)`. Other arrays explicitly
associate with `vertex` or `face`. Optional `normal` is float `(N,3)`. Stored faces
are CCW as seen from the outward normal. Godot winding conversion accounts for
reflections. Render normals use supplied normals at held/exact samples, or normals
computed from the current geometry during interpolation; engine transforms use the
inverse transpose. Face colors are expanded to avoid unintended interpolation across
faces. Surface and wireframe views are supported.

Mesh identity is `none` or `stable_topology`. The latter **requires explicit int64
`vertex_id`**. Position interpolation requires identical ordered vertex IDs and
identical topology in the adjacent samples. Other transitions hold discretely;
scalars hold. The writer rejects duplicate/recycled IDs. Extracted level sets have
identity `none`: remeshing does not create trackable identities.

Particles require identity `anonymous` or `persistent_i8`; the latter requires
`particle_id`. Positions must already be in viewer-world coordinates (identity
object transform). Exact IDs, matching, birth/death and gap rules follow G2b. No
array-index or nearest-neighbor identity is inferred. ALL interpolation/trails
require explicit IDs, including older captures. Random seeks cannot certify unseen
lifetimes; `SceneReader.audit_identity()` checks the complete recorded history.

Object `units` describes its primary values (positions for mesh/particles, scalar
values for a volume); declare grid-coordinate units separately in descriptive metadata
when they differ. Per-channel units can also be recorded. No unit conversion is inferred.

## Sampling, inspection and rendering

The scene clock is the union of recorded timestamps. Each layer independently
chooses an exact sample, an ID-compatible interpolation or a held sample. Source
time and status appear in the inspector and sidecars. Dynamic layers before their
first sample are unavailable; after their last sample they hold with that timestamp.
Explicit static geometry is reusable throughout the scene. Grid geometry changes
replace textures discretely. No temporal grid interpolation or reconstructed field
from sparse particles is implied. Particle-only captures say fields are unavailable.

SIMSCP3 uses version-2 inspection recipes with actual layer manifests and layer
visual state. Version-1 particle recipes remain supported. Restore validates source
identity, channel/state schema and referenced samples before applying state. A recipe
can refuse an appended source when new samples alter the formerly held bracket;
it does not silently reinterpret the old sample. Export pins the committed byte
extent and layer records, uses the same sampler, and waits for the requested surface
before drawing. Mid-export source changes fail rather than relabeling stale pixels.

One translucent volume and one derived isosurface may be active. Multiple opaque
meshes/slices can coexist. A second translucent volume is explicitly refused;
intersecting translucent-volume compositing is not implemented. Particle additive
rendering retains its existing appearance and does not write opaque depth. Opaque
meshes and slices do occlude volume rays.

The volume shader integrates `alpha = 1 - exp(-opacity * mapped_scalar * world_step)`.
It clips to the grid and opaque depth, including camera-inside rays. At most 1024
steps are used, increasing the effective step on long rays; early termination is at
alpha > .995. These display approximations are recorded in layer state. No empty-space
acceleration is currently used. Transfer function, numeric range, opacity, ray step,
world-plane clipping, axis/oblique slices and source probes are available.

Full-resolution storage stays unchanged. GPU previews use float32 and a labeled
power-of-two LOD when the texture budget requires it. Reduced previews use nearest
source samples on an endpoint-aligned grid, then shader trilinear sampling. Numeric
probes and extraction use full source resolution. Float64 conversion uses bounded
arrays; unrepresentable display coordinates/values are reported as unavailable.

Forward+ uses a linear framebuffer; Compatibility uses sRGB output. Volume color
blending therefore differs even with identical integrated opacity. Recipes/sidecars
record the renderer and compositing convention. These are visualization colors,
not a calibrated measurement of radiance. Godot documents the output-space distinction
in its [spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
Texture and depth implementation follows the native [3D texture API](https://docs.godotengine.org/en/4.7/classes/class_imagetexture3d.html)
and [depth reconstruction](https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html).

## Derived surfaces and allocation ceilings

Optional Python worker: scikit-image 0.26.x Lewiner marching cubes, no smoothing or
decimation. Full source grids are assembled across bricks; float32 algorithm input
is an explicit derived-analysis approximation. Cells with any nonfinite corner are
omitted. A surface is a chosen level set, not automatically a material boundary.
Source hash/extent, object, channel, time, geometry, transform, threshold and algorithm
identify the cache. Cached derived files are checksummed and parsed again. Threshold
changes debounce for .25 s; changes/seek/close cancel or supersede stale jobs. Only
one extraction process is queued. The [algorithm API](https://scikit-image.org/docs/stable/api/skimage.measure.html)
is optional; export/reading/slicing require no scikit-image.

| Resource | Enforced limit / accounting |
|---|---|
| Decoded object sample | 256 MiB total across its channels |
| Chunk / descriptor | 4 MiB raw chunk; stored ≤ raw + 64 KiB; 4 MiB descriptor |
| Index wire metadata | 32 MiB aggregate; 1 million records; 256 arrays/sample |
| Grid | Each dimension 2–512, also subject to sample-byte ceiling |
| Mesh | 1 million vertices; 2 million triangles |
| Identity | 1 million lifetime IDs per identity-bearing object |
| Visible source pairs | 512 MiB declared array bytes; refuse larger combinations |
| Decoded LRU | Default 256 MiB; UI 0–2048 MiB; additional held pairs/history exist |
| New mesh/grid/surface GPU buffers | Default 256 MiB total; UI 1–2048 MiB, divided among visible views; meshes refuse, grids reduce/release |
| Extraction | Preflight ≤1m vertices / ≤2m triangles using conservative 13/12 per crossing-cell bounds; actual output checked too |
| Worker process | Linux 2 GiB virtual-memory ceiling; 120 s CPU; 150 s viewer wait limit |

GPU accounting covers new layer buffers, not framebuffers, particles, driver allocations
or temporary old/new resources during upload. Allow up to another layer-budget amount
for replacement resources pending GPU retirement. CPU caches are not a process-RSS
ceiling: source pairs, IDs, conversion/brick buffers, JSON, meshes and the renderer add
memory. Measurements include actual process and engine usage. Worker peak RSS uses
Linux VmHWM because `ru_maxrss` can retain the launcher's pre-exec fork peak.

G3 layer reads are synchronous and bounded; the accepted particle-only reader/prefetch
path remains intact. Godot `.sidx3.json` indexes are disposable and checked against
actual record headers/descriptors/commits. Python v3 scans directly; it does not share
those indexes. `.simscope-cache/surfaces/` and job results can be deleted and rebuilt.
Cache disk size is not automatically capped. Writer flush commits support interrupted
file recovery; writer resume, per-sample fsync and background archival queues remain
outside this version. GPU/CuPy contention was not tested.
