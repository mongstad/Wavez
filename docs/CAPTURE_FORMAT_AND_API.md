# Capture format and API

For new layered work, use **WAVEZ Scene Format (`.wvz`, WVZ1)** and explicit `SceneCapture` / `SceneReader`. This is a current overview, backed by the [G3 wire contract](<WVZ1_FORMAT.md>) and [implementation](<../wavez_export/scene.py>). The [public API](../WAVEZ_API.md) documents the modern entry points.
The [capture format policy](CAPTURE_FORMAT_POLICY.md) defines the sole supported
capture generation. Readers require both `.wvz` and the exact WVZ1 magic and versions.

## Format and entry points

| Format | Purpose | Python entry points |
|---|---|---|
| WVZ1 | Independently timed particle, mesh and volume objects | `SceneCapture`; `SceneReader` |

## Current Python interface

```python
from wavez_export import SceneCapture, SceneReader

# Parent exists; path must not already exist.
capture = SceneCapture(path, objects=objects, metadata=metadata,
                       compression="none", compression_level=1)
capture.add_particles(object_id, time, positions, ids=ids, **channels)
capture.add_mesh(object_id, time, positions, triangles,
                 vertex_channels=vertex_channels, face_channels=face_channels)
capture.add_volume(object_id, time, fields,
                   origin=origin_xyz, spacing=spacing_xyz, centering="node")
capture.close()

# Use context managers in normal code to close on errors.
with SceneReader(path, strict=True, cache_bytes=256 * 1024**2,
                 metadata_bytes=512 * 1024**2) as reader:
    arrays = reader.read_sample(object_id, sample_index)
    source_bracket = reader.bracket(object_id, requested_time)
    reader.audit_identity()
    # For a volume object only:
    value = reader.probe(object_id, sample_index, channel, world_xyz)
```

These are interface sketches, not a single executable program for all object kinds. A complete small example is in the [integration guide](SIMULATION_INTEGRATION_GUIDE.md). `SceneReader.bracket()` returns `(a, b, alpha, status)` source indices/weight/status, or `None` before the first dynamic sample; the Godot viewer separately applies compatible identity-based position interpolation. `read_sample` and `probe` address an actual recorded sample, not a synthetic temporal field.

Scene metadata contains a generated capture UUID and 1–16 uniquely named objects, with at most one particle object. Each object declares `id`, `kind` (`particles`, `mesh`, `volume`), units, identity when applicable and optional static status/affine. The writer defaults `space` to `viewer_world`, static to false and affine to identity. Time is finite float64 and strictly increasing **per object**, not necessarily in global record order. Static objects have one sample.

Particle positions are already in viewer world, so their object affine must be identity. Mesh and grid transforms are invertible finite row-major 3×4 affines. Units are explicit declarations; no scientific conversion is inferred. G4 recognizes
`time_unit`, `position_unit` and `channel_metadata[object_id][channel]`; see the
[public API metadata reference](../WAVEZ_API.md#metadata-and-g4-analysis). Grid shape is zyx, origin/spacing are xyz, arrays are C-order with x fastest, and origin means first sample. All volume channels in a sample share geometry. A changed grid geometry is a discrete sample transition.

Typed WVZ1 arrays support `f4`, `f8`, `u4`, `i8`. Positions must be finite floating arrays; indices and IDs have their specific integer contracts. Scalar data retain their supported source values, including signed zeros and nonfinite payloads where permitted; renderers mark unavailable/invalid values explicitly. Arbitrary complex arrays are not a native channel type: export named components. Do not normalize or cast scientific fields merely to match a GPU preview.

Persistent particle identity requires explicit nonnegative int64 IDs, unique within each record and never reused after disappearance. The namespace includes capture/object identity. Mesh `stable_topology` requires explicit `vertex_id`; interpolation requires compatible ordered IDs and triangles. Anonymous particles and identity-free/changed meshes are held. Full identity history is checked by `audit_identity()`; a random-access sample read alone is not a full lifetime audit. Exact int64 IDs are represented as decimal strings where JSON precision would otherwise be unsafe.

## WVZ1 storage and recovery

The little-endian prefix `<8sII>` contains `WVZ1\0\0\0\0`, unsigned version 1 and JSON metadata length; metadata JSON has version 1. Each record has an 80-byte `<4sIQQdIIQ32s>` header with `FRM1`, descriptor and payload lengths, physical time, object index, array count, sequence and descriptor SHA-256. Array descriptors identify type, association and chunks. A 48-byte `<8sQ32s>` `COMMIT1\0` trailer commits the sequence and hash of header/descriptor. Chunks carry independent stored/raw SHA-256 checks; the descriptor/commit hash is not a replacement for payload checks. Interactive playback retains structural/descriptor/commit validation and bounded decoding but skips payload SHA comparisons. Readable scientific corruption can remain undetected there. Python analysis/readers and offline export retain strict payload checks; [explicit verification](PLAYBACK_INTEGRITY.md) checks the whole capture.

All arrays use canonical contiguous chunks of 4 MiB except the final remainder; grids are zyx C-order, x fastest. Mandatory exact volume statistics replace repeated display scans. Codec 0 is uncompressed (default); codec 1 is Zstandard, default level 1. Supported writer levels are 1–6. Compression is lossless and optional; unavailable requested codecs fail explicitly. No lossy “scientific compression” is implied.

A complete record becomes visible only after its commit. There is no required closing footer. An incomplete trailing record can be withheld in live/non-strict reads while earlier committed records remain available; detected corruption is an error, not a fabricated frame. Python `SceneReader(path, strict=False)` and `refresh(strict=False)` permit a growing committed prefix but still check payload SHA. Reopening/refreshing validates source changes; same path does not establish same source identity.

Writes are synchronous with bounded backpressure. There is no archive background queue, writer resume or per-record fsync guarantee. Flush/commit visibility is not a promise of power-loss durability. The WVZ1 writer opens exclusively and refuses an existing destination; choose a fresh destination for each export.

## Live time, indexes and provenance

The viewer's timeline combines committed times from every layer. The live-slider maintenance updates its index range as the union changes. Physical-time seeks still sample layers independently. Volumes/scalars remain held; no denser field cadence or field interpolation is invented by dragging a slider.

Inspection and indexes distinguish source identity from convenience caches. The
native WVZ1 reader builds a bounded header index and materializes requested
descriptors; it neither reads nor writes a disposable descriptor sidecar. Python
scans descriptors directly. Pinned scientific analysis/export also uses the
committed-prefix identity. A cache is never the authoritative scientific source,
and file paths or change-detection stamps never establish payload integrity.

Inspection recipe v3 adds G4 selections, analysis and exact member assets to the
v2 layer/v1 particle contracts, which remain readable. V3 recipes and render job v2
pin the committed source prefix: later appends are excluded, while replacement,
mutation or truncation refuses. Older recipes can reject an append that changes a
previously held bracket. Pinned video jobs wait for required surface/sample preparation;
a changed source cannot silently become a different reproducible inspection. The [inspection contract](<../INSPECTION_STATE.md>), [G3 specification](<WVZ1_FORMAT.md>) and [video contract](<VIDEO_EXPORT.md>) retain the detailed versioned provenance schemas.

## Limits and budgets

Per-record constraints remain format contracts. Aggregate metadata admission is
a reader resource policy, not an export or wire-size ceiling. See
[configuration, accounting and resource errors](WAVEZ_METADATA_BUDGET.md).
These budgets are not a whole-process memory estimate. MiB/GiB mean binary units.

| Resource | Limit/default |
|---|---|
| Metadata / record descriptor | 1 MiB / 4 MiB |
| Objects | 1–16 total; at most one particle object |
| Particles per sample | 10,000,000 anonymous; persistent IDs additionally capped at 1,000,000 |
| Decoded object sample, all channels | 256 MiB |
| Raw chunk / stored chunk | 4 MiB / raw + 64 KiB |
| Reader metadata | Configurable memory budget; 512 MiB Python / 4096 MiB conservative native reservation; separate 1,000,000-record reader capacity |
| Arrays per sample | 256 |
| Grid axes | Each 2–512, additionally constrained by the all-channel sample limit |
| Mesh geometry | 1,000,000 vertices / 2,000,000 triangles |
| Lifetime persistent IDs | 1,000,000 per object |
| Visible source pairs | 512 MiB of declared arrays |
| Decoded LRU | Default 256 MiB, UI range 0–2048 MiB; held/history allocations are additional |
| New mesh/grid/surface GPU buffers | Default 256 MiB, UI range 1–2048 MiB; reject mesh or reduce grid preview as applicable |
| Surface extraction | Conservative crossing-cell preflight plus final vertex/triangle checks |
| Linux surface worker | 2 GiB virtual-memory cap, 120 s CPU limit, 150 s viewer wait limit |

The GPU layer budget excludes some particle/framebuffer/driver allocations; replacement can temporarily overlap buffers. Decoded arrays, transform staging, worker memory, caches and GPU buffers have distinct lifetimes. The G3 surface cache has no automatic global disk cap. G4 numerical results have
a separate bounded disposable cache (2 GiB default), finite export quotas and
separate exact-member asset limits; see [G4 budgets](ANALYSIS_SCHEMAS.md). Large simultaneous solver/viewer allocations require separate preflight; acceptance does not certify CuPy concurrency.

## Exact source versus displayed representation

Source probes use full stored grids and spatial interpolation. Python/G4 worker
probe coordinates use float64; the G3 Godot world-coordinate readout uses float32. A probe readout is not a guarantee of last-bit equivalence to an arbitrary source coordinate supplied with more precision.

GPU volumes use float32 and may downsample to endpoint-aligned power-of-two LOD before shader interpolation. Source arrays and probe accuracy are not reduced to that LOD. Marching cubes uses full source resolution but a documented float32 algorithm, with no smoothing/decimation; its surface is approximate and has no persistent material IDs. Nonfinite-corner cells are omitted. Layer limitations include one translucent volume and one derived surface, with bounded ray steps and no empty-space acceleration. Low-level extraction/ray contracts are in [G3_FORMAT.md](<WVZ1_FORMAT.md>).

The distinction between stored values, spatial interpolation, temporal holds, GPU conversion and geometric approximation must remain explicit in future APIs and sidecars.
