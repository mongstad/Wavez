# Reader metadata capacity

Issue #102 / PR #103 removes the inherited 32 MiB aggregate descriptor/export
ceiling. SIMSCP4 framing, version, checksums, compression and scientific values
are unchanged. The writer spools one record and has no cumulative descriptor-byte
stopping condition. There is no global index, footer, paging or legacy reader.

The wire contract still limits metadata to 1 MiB, an individual descriptor to
4 MiB, a decoded sample to 256 MiB, and raw chunks to 4 MiB. Array, geometry,
identity and codec bounds remain enforced. None of the reader controls below
changes samples, timestamps, precision, spatial detail, channels or export cadence.

## Configuration and resource errors

| Reader | Configuration | Default and refusal |
|---|---|---|
| Python `SceneReader` | `metadata_bytes=` in bytes, separately from `cache_bytes=` | 512 MiB; raises public `MetadataCapacityError` (a `MemoryError`) |
| Python analysis `SourceSnapshot` | Optional `metadata_bytes=`; the enclosing `Context(memory_bytes=...)` always applies | Metadata allowance defaults to the job budget; `AnalysisError.code == "memory_limit"` |
| Godot `SceneReader` / viewer | Set `metadata_limit` in bytes before opening, or launch with `SIMSCOPE_METADATA_BUDGET_MIB` | 4096 MiB estimated reservation; `open()` returns false with `error_code == "metadata_capacity"` and an actionable message |
| Whole-capture verifier | `python tools/verify_ssc.py CAPTURE.ssc --metadata-mib 1024` | 512 MiB; exit 2 identifies reader capacity, independently of verification failure |

For example, `SceneReader(path, metadata_bytes=1024*1024**2)` selects a 1 GiB
metadata budget. `SIMSCOPE_METADATA_BUDGET_MIB=8192 godot --path viewer` selects an
8 GiB native reservation budget. The native environment setting is inherited by
viewer processes; it is not saved into captures or recipes. Invalid/nonpositive
settings refuse instead of silently disabling admission. Reopen after changing
the native budget; Python `refresh()` also re-admits the complete index.

A capacity error does not certify that the unread remainder is valid or corrupt.
It reports insufficient reader resources; retrying with an adequate budget still
performs the usual integrity checks. Raising a budget does not bypass validation.
The existing one-million-record reader capacity remains a separate resource
limit; it is not imposed on the writer or encoded by a SIMSCP4 length field.

## Accounting and lifetime

Python reserves `64 * JSON byte length + 4096` bytes **before** reading/parsing each
metadata object or descriptor. This workspace covers raw/text buffers, parsing,
checksum copies and the object-size traversal. After validation it replaces that
temporary charge with the measured Python object graph size plus 4096 bytes of
index/list/clock bookkeeping per record. Source arrays and decoded-cache bytes
remain separately budgeted. The retained index is eager, as before. Analysis uses
the same admission path and charges it against the enclosing job's memory pool,
including the existing 1 MiB fixed analysis bookkeeping/I/O allowance;
an explicit metadata allowance cannot bypass that pool or its cancellation checks.

Godot keeps its lazy header scan. At each header it reserves
`64 * descriptor_length + 4096`, plus the same formula for file metadata, before
adding the record. This intentionally conservative allowance covers eventual
parsed descriptors, preparation copies and parsing/hash scratch without reading
descriptors at startup. Materialization and whole/interval preparation use that
already admitted allowance. The 4096 MiB default is **an accounting ceiling, not
a 4 GiB allocation**. Actual residency is usually much smaller. This simple policy
may refuse a capture whose selected interval alone would fit; increasing the
reader budget is explicit. No eviction or paged-directory architecture is added.

Close, failed admission and refresh discard owned index state and release its
charges. Budgets are per reader, not a whole-process RSS/allocator guarantee;
caller-held references, concurrent readers, payloads, rendering and OS resources
have their own lifetimes. Lower-budget machines can still refuse large captures.
There is no universal file-size/duration guarantee, and full-timeline playback
still requires its separate prepared-array RAM admission.

## Focused validation

`python tools/validate_metadata_budget.py --godot /absolute/path/to/godot
--output-dir /absolute/external/new-directory` generates a capture with the real
writer: 1,316 samples, 64 float64 volume channels, 35,658,336 bytes of aggregate
descriptor charge (34.01 MiB), and a 41,048,878-byte file. These deliberately small
grids exercise metadata accumulation; this is not a 200 GB throughput benchmark.

Python checks every sample/channel bit-for-bit in the unit regression. The
cross-language harness verifies all payload checksums and mandatory statistics,
then checks native first/middle/last payload bytes and every descriptor/commit.
The fixture includes float64 detail beyond float32, NaN/Inf and signed zero.
Native validation passes 1,535 checks. Separate descriptor, commit and payload
corruptions beyond the former boundary still fail integrity checks; an oversized
individual descriptor still refuses. Small budgets, late admission failure,
exact native budget admission, reopening and cleanup are exercised.

Measured Python retained metadata is 135,953,571 bytes, parsing peak 137,580,315;
analysis peak charge is 146,451,619. Godot reserves 2,276,759,424 bytes without
allocating that reservation. These are accounting measurements, not peak RSS.
Compact evidence is retained in [metadata-budget.json](evidence/issue-102/metadata-budget.json).

S0's earlier ~184 GB extrapolation described the removed export guard. A 200 GB
capture at that measured mix needs about 34.8 MiB of serialized descriptor charge;
this is no longer a format/export refusal. It remains an extrapolation, not a
fresh long-running scientific export or complete 200 GB playback measurement.
Future paging can address extreme record counts and linear startup cost, but is
not required to remove the aggregate export limitation or change this policy.

The final full Python suite passes 214 tests; fresh scene/transform/export fixtures
pass 23. Native storage passes 109 checks, lazy loading 217, and full-field
preparation/channel switching 331. Uncompressed and zstd exports with a fixed UUID
are byte-identical to PR head `268fbd8`, confirming unchanged SIMSCP4 serialization.
The initial Python run exposed the lost fixed analysis allowance (restored); a
scene run encountered a stale SIMSCP3 fixture (fresh isolated fixtures pass);
a sandboxed Godot import lacked local IPC/settings access (permitted import passes).
No new physical 200 GB recording or GPU-renderer performance matrix was run.
