# WVZ1 reader metadata capacity

WVZ1 keeps the established per-record limits: at most 1 MiB file metadata,
4 MiB per descriptor, 256 MiB decoded sample and 4 MiB raw chunks. There is
no aggregate descriptor export ceiling. Reader admission is a resource guard,
separate from format validity or scientific precision.

| Reader | Current control | Default and refusal |
|---|---|---|
| Python `SceneReader` | `metadata_bytes=` separately from `cache_bytes=` | 512 MiB; `MetadataCapacityError` |
| Python analysis `SourceSnapshot` | Optional `metadata_bytes=` within `Context(memory_bytes=...)` | Job budget; `AnalysisError.code == "memory_limit"` |
| Native viewer `SceneReader` | `metadata_limit` or `WAVEZ_METADATA_BUDGET_MIB` before launch | 4096 MiB conservative reservation; `error_code == "metadata_capacity"` |
| Whole-scene verifier | `python tools/verify_wvz.py scene.wvz --metadata-mib 1024` | 512 MiB; exit 2 means reader capacity is insufficient |

Python reserves `64 * JSON byte length + 4096` before parsing metadata or a
descriptor. It retains measured object size plus 4096 bytes of index/bookkeeping
per record. Native indexing reserves `64 * descriptor_length + 4096` per
record and applies the same formula to file metadata. These are admission
ceilings, not actual allocations. The one-million-record reader limit remains
separate from writer and file-format limits. Insufficient capacity does not
certify a source as valid or corrupt; reopening with adequate capacity still
performs ordinary validation.

The [original #102 report](SSC_METADATA_BUDGET.md) preserves measurements
and terminology from its SIMSCP4 test build. This page defines current WVZ1
controls without relabeling those historical results.
