# Playback validation and explicit integrity verification

Issue #107 separates interactive decoding from cryptographic payload verification.
Implementation and measurements are pending owner review. SIMSCP4, exporter
settings, scientific arrays and #103's cache retention/admission policy are unchanged.

## Decision and investigation

The accepted baseline is PR #103, squash commit `6d4df9a`. Before changing the
decoder, the #107 probe prepared field samples 100–163 from the supplied 192³
capture, retaining all three f32 channels and preparing density at LOD 1. It then
exercised 1×/2×/4× playback with a 2 GiB field-cache ceiling. The capture has
1,566 field samples at approximately 0.1 s cadence and 627 particle samples;
its committed end is 156.5 s, regardless of the external T200 directory label.

Baseline preparation took 36.519 s for 64 samples: 1.753 samples/s. Stored SHA-256
took 13.067 s and decoded SHA-256 13.639 s (73% of preparation wall time), versus
1.183 s reading files. Descriptor work took 25 ms across the 64 samples. These are
fresh measurements, separate from the historical #102 profile.

Before #107, synchronous native scene reads and the field/mesh workers hashed
each stored chunk and each decompressed chunk. The particle worker did the same
through `typed_decode.gd`. Uncompressed chunks reused one SHA computation for
both comparisons. Reading a sample again after eviction repeated this work;
resident sample/channel reuse avoided it. Other hashes cover the small scene
header, requested descriptor and header-plus-descriptor commit proof. Analysis,
recipes, derived artifacts and offline exports also have their own integrity
work; these are not normal playback optimizations.

The contained choice is to skip **payload SHA recomputation only** on interactive
reads and the three interactive workers. Native standalone readers remain strict
by default; the normal viewer constructs a structural reader, while offline
rendering keeps a strict reader. The policy is fixed at reader construction, so
there is no mode switch that can promote an unverified resident sample to verified.
Low-level decoders retain strict defaults for tooling. Python readers, analysis,
writer checksums and the full verifier are unchanged. No persistent trust cache,
new UI mode, index architecture or format change is needed.

## Checks retained on the playback path

- Magic/version, metadata/object schema, record framing, sequence and time order.
- File bounds, descriptor/sample/array/chunk/geometry ceilings and metadata admission.
- Descriptor SHA and commit proof, required checksum syntax, byte totals,
  supported types/codecs, canonical contiguous chunks and geometry consistency.
- Actual stored length, bounded zstd frame/window/content-size/block checks,
  native decompression success and exact decoded length.
- Exact int64 ID validation and mesh topology bounds.
- Source-change checks before/after preparation, generation cancellation and
  publication checks; existing cache and transient-memory budgets.

Malformed requested data still refuses with object/sample/record context. Future
prefetch failures leave a valid current scene available. An unfinished trailing
record remains unavailable under the existing live-capture policy.

These checks **do not prove scientific payload integrity**. Readable altered float
values, valid substituted compressed content, changed but legal particle IDs,
in-range altered mesh indices, or a mismatch between values and descriptor
statistics can pass interactive decoding. Such bytes are neither repaired nor
reconstructed. Playback may show incorrect scientific values from a damaged file.

The current writer enables zstd's content checksum. Native decoding still checks
it when present, but it is a 32-bit noncryptographic checksum, not a substitute
for SHA-256. Zstd frames can also omit that checksum. See the upstream
[Zstandard frame specification](https://github.com/facebook/zstd/blob/dev/doc/zstd_compression_format.md#zstandard-frames).
Neither a successful decode nor a checksum establishes scientific truth or an
author's authenticity; the file's internal hashes detect inconsistency, not a
coordinated rewrite of both data and its proofs.

## Verify a capture explicitly

From the repository root, in the environment containing SimScope dependencies:

```bash
python tools/verify_ssc.py /absolute/path/capture.ssc
```

This read-only command scans all committed records strictly, checks descriptor
and commit hashes, compares every stored and decoded payload SHA, validates sample
constraints, and recomputes required field statistics. It rejects an incomplete
tail. Success reports the record count; exit 1 reports verification failure,
and exit 2 reports metadata capacity (increase `--metadata-mib` as appropriate).
Full lifetime identity auditing remains the separate `SceneReader.audit_identity()`
contract. Verification does not certify data that are changed afterwards.

Playback never invokes this whole-file scan automatically. Native numeric probes
use the displayed source arrays and share the interactive integrity limitation;
Python scientific analysis and offline video readers retain their strict checks.

## Source changes and paths

There is no pathname, directory or filename allowlist and no persisted verified
flag. Moving/renaming a capture requires no revalidation database entry. The
existing Linux device/inode/size/high-resolution mtime/ctime stamps are invalidation
hints, **not content identities or evidence of prior integrity verification**.
The existing `reader.trusted` name denotes availability of those local-filesystem
change hints, not trust in file content. Unsupported platforms/filesystems retain
the existing synchronous/reload fallback and the same structural playback policy.
Payload changes that evade all source-change hints may remain undetected in fast
playback; no adversarial concurrent-writer guarantee is claimed.

## Validation and performance

The reproducible workloads are `tools/profile_payload_integrity.py` and
`tools/validate_payload_integrity.py`. Raw captures, logs and telemetry stay outside
the repository. [Compact measurements](evidence/issue-107/integrity.json) retain
the matched results. Historical #102 reports/evidence remain unchanged.

The final pair used Godot 4.7.2 Forward+, Ryzen 7 5800X (8 cores / 16 threads),
46.94 GiB physical RAM and RTX 3070 Ti, at 960×640 in Scientific presentation with
points and orbit disabled. Both ran against the **same unmodified capture**, with
the same field samples 100–163, all three 192³ f32 channels, original timestamps,
LOD 1 and identical compression/export settings. No solver or exporter ran.

| Sequential preparation metric, 64 samples | Accepted #103 | #107 |
|---|---:|---:|
| Total wall time | 36.013 s | 8.925 s |
| Prepared field samples/s | 1.777 | 7.171 |
| Recorded seconds prepared / wall second | 0.178 | 0.717 |
| Stored SHA | 13.119 s | 0 s |
| Decoded SHA | 13.785 s | 0 s |
| Decompression | 3.836 s | 3.851 s |
| File reads | 0.505 s | 0.464 s |
| Byte assembly | 3.091 s | 3.020 s |
| Typed conversion | 0.903 s | 0.876 s |
| Plane copies | 0.613 s | 0.580 s |
| Descriptor materialization | 0.026 s | 0.026 s |
| Sampled CPU usage (100% = one core) | 99.4% | 100.2% |
| Sequential peak RSS | 692.4 MiB | 693.0 MiB |
| Whole probe process high-water RSS | 5.219 GiB | 5.088 GiB |
| Observed process swap | 0 | 0 |

The measured speedup is **4.04×**, with hashing no longer the dominant cost.
Decompression (43% of the new wall time) and byte assembly (34%) now dominate.
This justifies the contained correction, but it does **not** establish sustained
real-time playback: consumption needs 10, 20 and 40 field samples/s at 1×, 2× and
4× respectively. The measured producer covers only 72%, 36% and 18% of those rates.
A prepared buffer still eventually drains. Larger initial caches extend coverage;
they do not change that measured sustained deficit.

All six ten-second playback trials started with exactly **18 field samples /
2,039,611,392 cache bytes**, under the same 2 GiB test ceiling. This intentionally
forces replenishment quickly while retaining the real #103 cache policy. The
initial small probe stopped on the first readiness signal; the final matched
probe instead waits for adaptive planning to settle, avoiding unequal cold-cache
coverage. The full 125.95 GB capture is not prepared into RAM.

| Speed | Recorded seconds advanced, before → after | Field wait seconds, before → after | Field-wait callbacks, before → after | Particle-wait callbacks |
|---|---:|---:|---:|---:|
| 1× | 3.590 → 9.191 | 6.475 → 0.947 | 933 → 136 | 0 → 0 |
| 2× | 3.597 → 9.175 | 8.280 → 5.895 | 1198 → 857 | 0 → 0 |
| 4× | 3.694 → 9.522 | 9.137 → 7.959 | 1324 → 1176 | 0 → 0 |

Wait durations are sampled from controller state between callbacks and are not
an exact partition of wall time. Callback p95/p99/max and per-phase CPU/RSS are
in the evidence JSON. More field transitions now occur in the same wall time;
callback percentiles are not a matched-frame rendering comparison. These are
short trials, not presentation-pacing or indefinitely uninterrupted-playback
acceptance. Prior #102 particle waits are not invalidated by zero particle waits
in this smaller bounded test.

No privileged OS-cache drop was performed. These final runs were warmed by prior
probes and are not cold-storage benchmarks. The comparable file-read times make
the dominant SHA savings directly visible. Telemetry samples Linux process memory
at 100 ms intervals; system swap already held other processes' pages, so zero
**process** swap is not a claim that system swap was empty. Hardware/backend and
long-run variability remain unmeasured outside this workstation.

The production capture also passed the unchanged **whole-capture verifier: all
2,193 records**, every stored/raw chunk checksum and required field statistic.
That separate run took 363.53 s and peaked at 312.55 MiB RSS (`time -v`); no process
swaps were reported. Source device/inode/size/mtime/ctime remained unchanged through
the final check. This is full per-record verification, not a new whole-file
fingerprint or persistent trust entry.

| Focused validation | Result |
|---|---|
| Integrity, exact values, malformed data, IDs/topology, rename, same-path mutation, gated publication, offline strict reads | 473 checks each on Forward+ and Compatibility; zero failures |
| Independent strict corruption fixtures | 63 rejected cases; valid fixtures verify; source bytes unchanged |
| Lazy/deferred structural corruption | 217 checks, headless |
| Adaptive cache, overlap, reverse/loop, capacity recovery | 73 checks, headless |
| Field sessions, all-channel reuse and f64/LOD fidelity | 330 checks, headless |
| Particle playback / exact IDs / packed GPU data | 2,457 checks, headless |
| Mesh playback / topology / lifecycle | 2,731 checks, headless |
| Maintenance and source/playback lifecycle | 66 + 51 checks, headless |
| Matched production profiles | 141 checks before and 141 after; independent Python byte oracles match |
| Python suite | 214 tests passed; existing third-party NumPy deprecation warnings |
| Godot import, Python compile, Markdown links and executable examples | Pass; three API examples; UID sidecars included |

The native regression total is 6,871 checks, excluding the 282 profile assertions.
No final validation failures remain. Full end-to-end video export, other operating
systems, physical monitor behavior, fresh/cold OS-cache performance and prolonged
high-speed playback were not tested here. Offline refusal was tested through the
actual offline viewer reader; the export pipeline itself is unchanged.

Earlier attempts are retained outside the repository and excluded from the final
numbers. A fixture initially used the wrong mesh API argument. The first worker
error test omitted controller pumping, and the first publication test conflated
retained startup entries with new publication; the final test gates a fresh worker
using the actual viewer job. A fresh baseline snapshot needed asset import before
UI profiling. Compatibility teardown initially reported two texture leaks; letting
the transient offline test viewer render before destruction and draining GPU frees
resolved them. The older maintenance assertion also failed on accepted `6d4df9a`:
it set the retired manual `cpu_limit` and expected all GPU staging to disappear.
The test now uses #103's existing `cache_cap_bytes`, verifies CPU refusal, and keeps
the accepted current-plus-one GPU bound. **No cache-policy product code changed.**

For a matched run:

```bash
python tools/profile_payload_integrity.py --godot /absolute/path/godot \
  --capture /absolute/path/capture.ssc --output-dir /absolute/path/fresh-results \
  --renderer forward_plus --samples 64 --first 100 --cache-mib 2048 --play-seconds 10
```

The supplied production capture has object `field` and channel `density`, as this
focused probe expects. It prepares each source sample in sequence, releases it
before the next, and times metadata, reads, hashing, decoding, assembly, conversion
and density plane creation separately. Three independent full-channel Python SHA
oracles run outside those timers. Playback starts a fresh viewer per speed, uses
the existing adaptive policy with the same test capacity ceiling, and waits for
two seconds of stable readiness before advancing. Fill times include that deliberate
stability wait; they are not pure decoding times. CPU utilization is sampled from
Linux `/proc` (100% means one core), with process RSS/high-water/swap telemetry.
The optional `--viewer-dir` targets an imported baseline source snapshot. Before
#107 that snapshot's probe uses the old decoder signature; no baseline product
code is modified.

## Owner verification

1. Open the supplied large capture normally, leave Automatic preparation selected,
   and compare initial preparation with the accepted #103 experience.
2. Play at 1×, 2× and 4×; seek within and beyond prepared coverage, reverse direction,
   and switch density / psi_real / psi_imag. Expect explicit buffering if consumption
   overtakes preparation; resolution and source timing must not change.
3. Run `tools/verify_ssc.py` on the capture and check its final record count. This
   explicitly verifies integrity and is not implied by successful playback.
4. If reviewing failure behavior, use the disposable fixtures generated by
   `tools/validate_payload_integrity.py`: a `*-sha_only.ssc` file is deliberately
   readable in playback and must fail the verifier; `*-offset.ssc` must stop when
   sample 3 is requested. Never mutate a retained production capture for this check.

No #106 timeline/retention redesign, format changes, persistent trust database,
compression change or additional workers are included.
