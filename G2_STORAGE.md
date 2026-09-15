> Historical G2 implementation record. Development-copy paths, future-milestone
> statements and original commands below describe those checkpoints, not current
> work instructions. G0–G4 are now accepted; use [current status](docs/CURRENT_STATUS.md)
> and the [capture format policy](docs/CAPTURE_FORMAT_POLICY.md).

> 2026-09-11: G3 is implemented in the same copy. Its separate SIMSCP3 contract and
> measurements are in G3_FORMAT.md / G3_REPORT.md. The accepted particle-only path
> and G2b wire format remain; real-capture regressions pass.

# G2 storage: G2b complete — 2026-09-10

G2a is user-approved. G2b is implemented and validated in the independent v1.0.3
copy. The bounded codec spike preceded the wire-format implementation. The explicit
historical typed-storage work is superseded by the current [SIMSCP3 contract](G3_FORMAT.md).

SIMSCP2 is opt-in, with f4/f8/u4/i8 channel buffers, independent <=4 MiB none/Zstandard
chunks, checksummed record descriptors and commit trailers, exact persistent IDs,
interrupted-tail recovery, and disposable shared Python/Godot indexes. Existing
VBCOSM1/SIMSCP1 remain readable and writer defaults remain v1. Source coordinates
and scientific values are not normalized, quantized or otherwise made lossy.

**User policy amendment:** all interpolation/trails require explicit IDs. Anonymous
legacy, v1 and v2 captures use sample-and-hold. The supplied real capture has no
IDs; conversion preserves that fact. Categories are not identity. Shared IDs match
through reordered rows/count changes; births/deaths occur at recorded times and
missing-ID gaps break history. Scalars/categories/phase hold the earlier sample.
Inspection exposes an exact decimal-string identity preview, not a selection API.

## Bounded codec spike, before adopting the format

Host: Fedora/Wayland, Ryzen 7 5800X, 48 GiB RAM, RTX 3070 Ti; Python 3.14.7 with
stdlib compression.zstd/libzstd 1.5.7; Godot 4.7.2 native PackedByteArray decoder.
No GDExtension, cloud dependency or Python-per-frame decoder is required. Python
<3.14 can use the optional backports.zstd extra; that fallback was not installed
or tested on this host. None remains usable without importing an optional codec.

The real input is 4,080,410,529 bytes, 600 frames, 100k particles, 13 channels,
4,080,000,000 scientific payload bytes. Each codec processed all payload chunks.
Times below are separately accumulated stages, not interchangeable with total
wall time. Write includes fsync in the spike. Values are single local runs with
uncontrolled OS page-cache warmth; they are not cold-device throughput claims.

| Codec | Stored payload bytes | Raw/stored | Compress CPU s | Write+fsync s | Python decode s | Godot native decode s | Python peak RSS MiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| none | 4,080,000,000 | 1.000 | 0.002 | 4.596 | 0.076 | 0.003 | 44.4 |
| Zstd 1 | 1,982,235,285 | 2.058 | 8.161 | 2.868 | 4.343 | 3.295 | 50.0 |
| Zstd 3 | 1,894,358,509 | 2.154 | 14.631 | 8.028 | 4.063 | 3.410 | 48.5 |
| Zstd 6 | 1,848,727,455 | 2.207 | 34.652 | 2.077 | 3.576 | 2.951 | 51.5 |

Godot I/O stage was 0.308/0.190/0.178/0.169 s and SHA-256 verification about 10.7 s
per real case. Godot process high-water RSS was 183.3 MiB including all loaded chunk
manifests; this was one process, so the high-water value is cumulative, not separate
codec peaks. Compression/write/decode rates can be computed against the common
3,890.99 MiB raw payload (e.g. Zstd1 compression ~477 MiB/s, native decode ~1,181 MiB/s).

The random 100k fixture achieved only ~1.108× at all three Zstd levels. Exact-byte
fixtures cover signed zero, NaN payloads, float64 values and int64 boundary bytes.
Actual data content matters; higher compression is not assumed to improve playback.
Evidence: `results/g2b/codec-measurements.json`, `codec/godot-measurements.json`,
`codec-exact.log`, `codec-godot.log`; probes: `tools/codec_spike.py` and
`viewer/data/codec_spike.gd`.

## Complete real-capture conversions and read speed

Both outputs were created separately, with no inferred IDs or changed source arrays.
All 600 timestamps and all 7,800 channel arrays compare dtype and bytes exactly to
the original in both conversions (`results/g2b/full-lossless.json`).

| Output | Complete file bytes | Original/file | End-to-end conversion s | Raw MiB/s | Writer process peak RSS MiB |
|---|---:|---:|---:|---:|---:|
| `results/g2b/real-none.ssc` | 4,082,614,603 | 0.99946 | 10.497 | 370.7 | 54.4 |
| `results/g2b/real-zstd.ssc` | 1,984,844,746 | 2.05578 | 14.735 | 264.1 | 55.2 |

These conversion times include input read/decode, validation, chunk hashes,
compression, file-backed frame spooling and buffered output flush. They do not
include a final fsync and must not be presented as durable-device write bandwidth.
Full byte verification peaked at 95.1 MiB RSS. The converter refuses existing
outputs, unknown optional channels and legacy frame-metadata conversion; legacy
captures remain directly readable.

Godot reader measurements: median of four independent opens per mode, prefetch
disabled, source frame 250, OS cache not controlled. Uncompressed duplicate hashing
was removed after measuring it: both stored/raw expected hashes are still checked
against the same one hash when the bytes are identical. Uncached none reads fell
from ~45 to ~28 ms; Zstd still checks both different byte buffers.

| Format | No-index open ms | Validated-index open ms | First read ms (warm-index case) | Cached read ms |
|---|---:|---:|---:|---:|
| SIMSCP1 (G2a measurement) | ~13 | ~13 | ~14 | ~2.2 |
| SIMSCP2 none | 267.3 | 284.2 | 28.5 | 2.09 |
| SIMSCP2 Zstd1 | 277.2 | 285.4 | 40.7 | 2.25 |

V2's per-chunk descriptors/integrity checks cost more than v1. Its validated index
is not a faster-open claim: reopen verifies actual source headers/descriptors and
commits. It never decodes prior payloads just to seek. Per-channel Python reads
skip unrelated chunks; the viewer reads one complete requested particle frame.

## End-to-end playback and measured costs

Actual 1440×900 Vulkan Forward+ renderer, sequential isolated runs, seven 8-second
cases per format, no concurrent codec/conversion/GPU tests. Final reports are
`results/g2b/playback-{v1,none,zstd}.json`; `playback-summary.json` omits raw wall-frame
samples. Content gaps use changes in the held source sample for anonymous data,
not requested clock changes or blank redraw FPS. Earlier G2a interpolation-era
content-gap measurements are therefore not directly comparable.

| Real capture case | v1 source FPS / p95 content gap ms | v2 none | v2 Zstd1 |
|---|---:|---:|---:|
| Cinematic, frame 250, requested 12 FPS | 11.91 / 98.7 | 11.91 / 96.0 | 11.92 / 89.7 |
| Scientific, frame 250 | 11.91 / 94.0 | 11.89 / 96.2 | 11.94 / 88.3 |
| Dense beginning | 11.94 / 101.6 | 11.93 / 121.3 | 11.93 / 138.2 |
| Physical time | 11.87 / 105.2 | 11.88 / 105.8 | 11.88 / 103.9 |
| Velocity coloring | 11.92 / 99.8 | 11.92 / 95.9 | 11.91 / 97.6 |

All formats maintain the accepted ~12 source-FPS progression. The dense beginning
still coalesces some styled frames: v1/none/Zstd presented 89/87/83 distinct samples
in the measured interval, with 6/8/12 coalesced style updates. Compression is not
advertised as a smoothness improvement. Mid-capture cached requests have no decode
misses; read-ahead supplies subsequent samples. Dense none p95 improved from 140 to
121 ms after eliminating redundant hashing. Original v1 remains the default.

Representative mid-capture Zstd mean stage times per transition/task: file I/O
0.52 ms, channel conversion 3.54 ms, decompression 6.62 ms, chunk integrity hashing
26.14 ms, worker source-stamp checks 4.70 ms. These worker costs overlap rendering.
Main-thread source validation is ~2.22 ms per read; style ~42.81 ms includes range
normalization and particle packing. Held-position buffer packing is ~10.8 ms when
the displayed sample changes; submit ~2.47 ms; GPU ~0.70 ms per rendered draw, HUD
~0.03 ms and mapping UI ~0.14 ms. None chunk hashing is ~18.2 ms. Full-prefix scientific
SHA-256 is absent from ordinary playback; inspection/export retains that separate
synchronous operation. Stage totals overlap and should not be summed as a frame
budget. The real capture has no IDs, so identity matching is correctly unused.

## Memory, mutation, recovery and exact identity

Limits are enforced before decode: 4 MiB raw chunk / raw+64 KiB stored, 256 MiB raw
frame and Godot expanded numeric-frame ceiling, 4 MiB descriptor, 1 MiB metadata,
32 MiB aggregate frame-index wire metadata and <=1m frame entries. Parsed JSON
adds overhead proportional to that bounded metadata. Readers/writer fail clearly
at the metadata ceiling; start another capture instead of accumulating indefinitely.
The disposable index file also has a 32 MiB ceiling. Explicit identity is limited
to 1m distinct lifetime IDs, in [0,2^63-1]. No whole-capture decoded preload occurs.

The 256 MiB LRU accounts for arrays, containers and a conservative 160 bytes/ID
lookup reserve. Current pair/history, sorted writer/audit sets, assembled channel
buffers, worker scratch, renderer/GPU and filesystem cache are additional memory.
A multi-chunk channel may briefly exist in assembled and decoded forms; 4 MiB is
not a promise about total process RSS. Input arrays must stay unchanged until the
synchronous add_frame returns. No asynchronous archival queue or preview-drop mode
is implemented; writes block the caller, retain supplied times and fail visibly on
I/O failure. Flush is not power-loss durability. Writer-resume is not implemented.

Four cycles of 344 reader seeks hold exactly 37 real frames, 254.32 MiB reserved;
engine static allocation changes by only ~2 KiB after fill. Four cycles of 160 GPU
seeks per codec hold the same cache: none RSS 1065.6→1082.9 MiB, Zstd RSS
1087.4→1094.1 MiB; engine static increases ~28 KiB, GPU constant ~174 MiB. Allocator
retention causes small RSS drift, with no growth proportional to source history.
A separately generated 40-frame/100k-ID Zstd fixture holds 245.73 MiB reserved;
RSS 919.4→907.4 MiB, engine GPU 171.98 MiB over 160 GPU seeks. This tests ID-cache
working memory, not a claim about 100k-ID interpolation FPS. The real capture was
never assigned synthetic identities. Evidence: `reader-*/storage-benchmark.json`,
`seeks-{none,zstd,ids}/rendered-seeks.json` and corresponding cache-control PNGs.

Per-frame readers validate ID uniqueness/range. The writer and Python
`validate_identity_history()` reject reuse after absence over the full history;
a random seek cannot certify unread history. Trails intersect continuously present
IDs through recorded history and never connect reappearance gaps. Anonymous trail
recipes are refused. Unsupported optional channels are visibly labeled unavailable;
unsupported required codecs/types/objects/versions fail clearly. Unrepresentable
float64 display coordinates fail visibly while stored/decoded scientific arrays
retain their exact precision. Source mutation invalidates workers, caches and scene
generations; a failed decode clears displayed particles and permits a valid earlier
seek. A completed append becomes visible only after its commit arrives.

## Acceptance evidence

| Check | Result | Evidence under `results/g2b/` |
|---|---|---|
| Python old/new readers/writers, bit patterns, optional codec, commit/growth, malformed bounds/cache, injected write failure | 28 PASS | `python.log`, `acceptance.log` |
| Native typed storage/worker/codec guards | 34 PASS | `typed-storage.log` |
| Actual rendered ID reorder/birth/death/gaps, anonymous all-format policy, exact JSON preview, failure/reseek, f8 display bounds, unavailable HUD | 23 PASS on Forward+ and Compatibility | `typed-viewer.log`, `typed-compatibility.log` |
| Python → Godot → Python v2 indexes | 3-frame none/Zstd and both complete real 600-frame conversions, every timestamp exact | `acceptance.log`, `interop-*.log` |
| G2a reader/worker and real source mutation/controls | 31 + 25 PASS; v1 600-frame index interoperability PASS | `g2a-storage.log`, `g2a-storage-viewer.log`, `g2a-interop.log` |
| G1 differential positions/provenance/pixels | 34 PASS at exact recorded samples under new ID policy | `equivalence.log` |
| Inspection and pinned signed video | 58 + video PASS | `inspection.log` |
| Generic / legacy / Compatibility | 30 / 6 / 30 PASS | `generic.log`, `legacy.log`, `compatibility.log` |
| Full video + focused continuation | PASS, native 4K, actual ID trails on/off, timing, cancellation/FFmpeg/error recovery | `video.log`, `video-continuation.log` |
| Original project and real source preservation | 60 original hashes and supplied capture SHA-256 unchanged | `preservation.json` |

Pixel equivalence is asserted at recorded samples, not the deliberately removed
anonymous interpolation states. The analytic inspection/video interpolation fixtures
now explicitly export simulator-owned IDs. Full video artifacts remain under
`results/video tests/acceptance t60vdzhq/` and continuation `acceptance u7abrmiv/`.
The user withdrew the Jellyfish joke; no invented compliance suite is claimed.
D04–D11 and particle portions of D12–D14 are exercised. Mesh/topology/field geometry,
preview dropping and simultaneous solver resource contention are outside this slice.

## Reproduce / continue

```bash
python examples/identity_demo.py
python tools/validate_typed.py --godot /path/to/godot --real
python tools/validate_storage.py --godot /path/to/godot
python tools/validate_playback.py --godot /path/to/godot
python tools/validate_inspection.py --godot /path/to/godot
python tools/validate_video.py --godot /path/to/godot --continuation
```

Open `results/identity-demo.ssc`, choose Physical time, and enable Recorded History.
The small demo visibly reorders rows and introduces/removes lifetimes. Real converted
files are also ready to open. `--real` expects the existing full conversions; omit
it for the small suite. GPU access is required for rendered acceptance; `--headless`
skips only the rendered identity suite. Use retained profile jobs for timing and
keep benchmark runs isolated. Code manifest/archive: `results/g2b/source-sha256.json`
and `code-checkpoint.tar.gz`. Next staged work is G3, not implemented here.

---

## Historical G2a contract and measurements

The following is the accepted earlier checkpoint. Its interpolation-era display-gap
numbers and 14-test Python count describe that checkpoint, not the G2b policy above.

### G2a index/cache contract

Work only in the v1.0.3 copy. Source captures are read-only; no v1 writer or wire
format change. This contract precedes implementation and its acceptance results.

- Persistent indexes are disposable versioned JSON in this copy's `.simscope-cache`
  (overridable). An envelope checksums an exact JSON body. Offsets, sizes and filesystem
  identity are decimal strings; timestamps in frame entries store the exact eight little-endian bytes as hex
  strings, avoiding JSON parser rounding.
  Schemas store the original descriptor JSON once, shared by frame entries.
- Reuse requires matching local device/inode/size/mtime/ctime with nanosecond precision
  and source-header SHA-256. Supported local Linux filesystems use GNU stat; unsupported
  identity providers disable decoded/persistent caching rather than trust coarse mtime.
  This is local cache invalidation, not a cryptographic source identity. Inspection and
  export continue to hash the complete committed prefix.
- Warm indexes additionally verify every saved frame header and descriptor against the
  source, and bounds/contiguity before use. This protects against incorrect local index
  contents without reading payloads. Parsing/validating repeated schemas is avoided.
- Replacement, truncation, or any detected metadata change invalidates decoded data
  and worker generations. Old v1 files cannot prove a pure append from size alone:
  changes conservatively rescan/revalidate structure, then resume at the current index
  when available. Partial tails never advance the committed offset. Same-size in-place
  writes with restored mtime are detected by ctime. Unsupported/remote/coarse filesystems
  take the uncached scan path. The trust boundary excludes hostile kernel/root metadata
  manipulation; finite checks do not provide an immutable snapshot of an actively edited
  file. Reads are checked before/after and changes fail closed or retry on refresh.
- A 256 MiB default byte-bounded LRU holds decoded generic frames; 0 disables it.
  Entries reserve array and container overhead. One low-priority prefetch task at most
  holds an independent file handle and immutable request metadata. A per-frame allocation
  ceiling rejects excessive payload/decoded requests before allocation. Scene/GPU changes
  stay on the main thread. Every task is joined on supersession/close; late generations
  cannot enter the cache. Existing UI pair/history/GPU working sets are additional bounds.
- Index writes use unique same-directory temporaries and atomic rename. Failed writes,
  corrupt/version-mismatched indexes and interrupted temporaries fall back to scanning.
  The original capture is always sufficient to rebuild. Legacy fixed strides need no
  persistent offset table; their existing reader/format remains compatible.
- Acceptance: independent cold-index/warm-index opens, source mutation fixtures, cross-
  reader cache interoperability, cache eviction and delayed prefetch rejection, real GPU
  rendering/export, and repeated seeks on the supplied 4.08 GB capture. OS cache warmth
  is reported separately; no cold-disk claim without controlling it.

API references: [GNU stat precision](https://www.gnu.org/software/coreutils/manual/html_node/stat-invocation.html),
[Godot worker lifecycle](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html),
[thread restrictions](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Delivered behavior

The **Data cache** inspector exposes budget, read-ahead, clear-cache, byte use,
hits and pending/ready-frame status. The default is 256 MiB and one prefetch worker.
Zero disables both decoded storage and read-ahead. The worker has its own file
handle, cooperative cancellation (including large uint32 channel loops), and no
scene/GPU access. The main thread joins and validates results before publication.

This implementation targets local Linux btrfs, ext2/ext3, XFS, tmpfs and overlayfs
with GNU `/usr/bin/stat`. It does not provide accelerated caching on Windows,
macOS, remote storage or coarse timestamps. Those paths use uncached reads/scans.
The source stamp is checked on frame requests; no Python process decodes viewer
frames. Godot's uint32 values remain exact in existing float64 category arrays;
this does not add persistent particle IDs.

Python uses `CaptureReader(path, cache_dir=..., cache_bytes=...)` to opt in.
Default Python opens do not create indexes or retain decoded frames. NumPy data
buffers remain read-only; callers have separate dictionaries and array views, so
changing one result's shape does not alter the next cached result. Python and
Godot share envelope version 1 / parser `SIMSCP1/g2a-2`. The timestamp field is a
16-character lowercase hex string of the source IEEE-754 little-endian double.
Godot decimal JSON parsing was experimentally shown to change
`1.0000000000000007` by one ULP; storing the bytes fixes exact reopen and cross-reader
agreement without relaxing comparisons.

Changing a capture clears the reader generation, held pair, history and shared
physical-time sampler. Frozen interval extrema are invalidated; replacement or
changed header also clears source-specific geometry/category/mapping overrides.
An already-running export fails on detected source mutation and retains PNGs.
The established job snapshot still excludes an append made before worker startup.
Inspection rejects a stale source/data pairing and a source change during hashing.
Full cryptographic source hashing remains synchronous and unchanged; the index
checksum or filesystem stamp is never substituted for scientific identity.

## Acceptance — 2026-09-10

Godot 4.7.2; Fedora/Wayland; RTX 3070 Ti; Vulkan Forward+ at 1440×900, plus real
Compatibility renderer regression. Supplied capture:
`D128_isolation_long_simscope.vbc`, SIMSCP1, 600 complete frames, 100,000 particles,
13 channels, 4,080,410,529 bytes. Payload per frame: 6,800,000 bytes.
SHA-256 remains `2219325de375bb04aa2ca93a34130ccd577e49001f82bd222a67985ece41217b`.
All 60 recorded original-project file hashes also remain unchanged.

| Check | Result | Evidence |
|---|---|---|
| Python readers/writers and cache boundary/mutation tests | 14 tests PASS | `results/g2/python.log` |
| Actual Godot reader/worker tests | 31 checks PASS | `results/g2/storage.log` |
| Real viewer mutation and cache controls | 25 checks PASS | `results/g2/storage-viewer.log` |
| Python → Godot → Python persistent index | All 600 real timestamps exact; decoded cache positions exact | `results/g2/interop.log` |
| Rendered data/pixel comparison against retained G1 | 34 checks PASS, identical pixels | `results/g2/equivalence.log` |
| Inspection and pinned signed video | 58 checks plus video PASS | `results/g2/inspection.log` |
| Generic / legacy / Compatibility | 30 / 6 / 30 checks PASS | `results/g2/{generic,legacy,compatibility}.log` |
| Full video, including native 4K and failure/cancellation recovery | PASS | `results/g2/video.log`, `results/video tests/acceptance ds8sw62k/` |
| Large-capture cache/seek memory | Bounded over 344 reader seeks and 160 rendered seeks | `results/g2/{storage-benchmark,rendered-seeks}.json` |

Mutation cases include equal-size in-place writes with restored mtime, same-name
replacement, truncation, partial and completed append, malformed index JSON,
wrong parser version, forged timestamps with a recomputed envelope checksum,
interrupted index temporaries, caller mutation, byte eviction and zero budget.
A semaphore delays a real worker until after source mutation to prove that stale
results cannot enter the next generation. Sparse 280 MB payload fixtures verify
allocation refusal without allocating that payload. Render tests inspect actual
MultiMesh positions, shared time interpolation and inspection publication.

D01–D03/D13 pass for the existing generic particle path. This is not a new typed
format or a field/mesh implementation. Legacy fixed strides do not gain a separate
persistent table or background viewer decoder.

## Measurements

Four independent cold-index opens (the disposable index removed before each),
then four independent validated warm-index opens. OS file-cache warmth was not
controlled: these are **not cold-disk measurements**. Timings include precise
source checks; the microbenchmark disables prefetch to isolate decoded-cache hits.

| Median, milliseconds | Cold index | Warm index |
|---|---:|---:|
| Open/index | 13.08 | 13.45 |
| First requested frame decode | 14.56 | 13.99 |
| Same frame from decoded cache | 2.18 | 2.22 |

A cached frame request is about 6.4× faster than a first decode in this run.
Warm indexes do not materially improve open time over the new deduplicated-schema
scan on this homogeneous-schema capture. Both validate source headers/descriptors;
no speedup is claimed by omitting validation. The complete viewer's warm open was
272 ms versus 275 ms in the prior accepted run, including first-frame setup/style.

Real playback, seven 8-second cases, same job/resolution as the accepted slice:

| Case | Source FPS | Content-gap median / p95, ms |
|---|---:|---:|
| Cinematic, requested 12 | 11.91 | 68.4 / 81.8 |
| Scientific, requested 12 | 11.93 | 64.7 / 74.0 |
| Cinematic, requested 1 | 0.99 | 33.6 / 42.2 |
| Inspector hidden, requested 12 | 11.94 | 62.9 / 72.4 |
| Dense initial frames, requested 12 | 11.90 | 92.0 / 106.2 |
| Physical time at rate 12 | 11.87 | 68.3 / 85.2 |
| Velocity coloring, requested 12 | 11.89 | 78.5 / 85.1 |

The accepted main case was 67.4 / 83.4 ms; dense initial frames were 90.8 / 102.9 ms.
Cadence is preserved, with normal run-to-run variation. In the main case all 96
source transitions used prefetched decoded data; no foreground payload misses or
identity hashes occurred. Mean source transition: 48.57 ms; style: 43.11 ms;
foreground source check: 2.35 ms. Background means: I/O 1.04 ms, channel decode
6.29 ms, two source checks together 4.68 ms. Interpolation packing: 11.95 ms;
buffer submission: 2.52 ms; GPU render: 0.49 ms; HUD: 0.035 ms. These stages have
different call counts and overlap; do not sum them as an end-to-end frame cost.
Buffer submission measures CPU copy/enqueue, not isolated GPU DMA.

The 256 MiB LRU holds 37 real frames: 266,674,688 reserved bytes (254.32 MiB).
Four cycles of 86 spaced reader seeks each leave identical cache size, with
49/135/221/307 evictions. Engine allocation changes by only 2.3 KiB as the result
log grows. Four cycles of 40 actual GPU viewer seeks each show:

- Process RSS: 1132.9, 1131.9, 1131.9, 1133.0 MiB.
- Engine allocation: 359.72–359.75 MiB.
- Engine-reported video allocation: constant 174.86 MiB.

No sustained memory growth is visible after cache fill. RSS is total process
memory; engine video allocation is not total driver VRAM. This cache intentionally
adds RAM relative to the prior held-pair viewer. No concurrent CuPy solver was
measured. The cache budget is adjustable; the frame pair, trail history, raw decode
temporaries, one worker and GPU buffers remain additional working memory.

## Reproduce and resume

Run from this version's root (GPU commands need desktop access):

```bash
python tools/validate_storage.py --godot /path/to/godot
/path/to/godot --headless --path viewer --script data/benchmark_storage.gd
/path/to/godot --path viewer --resolution 1440x900 --audio-driver Dummy --disable-vsync --script data/benchmark_seeks.gd
/path/to/godot --path viewer --resolution 1440x900 --audio-driver Dummy --disable-vsync --script scene/profile_playback.gd -- --profile-job='results/g2/playback-job.json'
```

Use the existing playback/inspection/video validators for regression. The final
code manifest is `results/g2/source-sha256.json`; the prior accepted playback
manifest remains in `results/playback-profile/source-sha256.json`. The next gate
is the bounded none/Zstandard Python-write/Godot-read codec spike and explicit
G2b wire-format/ID contract. No `simscope2` writer option is shipped in G2a.
