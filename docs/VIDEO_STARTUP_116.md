# #116 / PR #122 — owner-review startup blocker

Pending owner review. This corrects the normal video-export startup regression
found on the real `SIMSCP4_D192_T200_simscope.ssc` (125,950,754,101 bytes,
2,193 indexed records / 1,879 union-clock samples). The capture was not rewritten.
The authoritative SIMSCP4 reader, sampler, renderers and separate-worker design
remain in place.

## Root cause and replacement

At `ffa5e95`, `export_dialog.start_export()` called
`Inspection.identity(viewer)` synchronously on the viewer thread. That hashed the
entire committed prefix before a child process even existed. The worker then
called `Inspection.digest()` over the same prefix again. Enabling ordinary frame
inspection JSON could trigger a third pass. The initial #116 production test
launched a worker directly without `job.source`; its 4.12-second result did not
exercise these hashes and was not evidence of interactive launch performance.

Normal jobs now bind the format/version, intrinsic capture UUID, metadata SHA-256,
ordered fixed-record-header SHA-256, committed extent, record/frame counts, and
accepted high-resolution local source stamp. The stamp contains device, inode,
size, nanosecond mtime and ctime as lossless strings. Path only locates the input.
For this capture, each index fingerprint covers **175,440 header bytes**, not
125.95 GB of payload. Identity generation checks the stamp on both sides; the
worker independently indexes and compares the binding. There is no persistent
trust database, payload-verification bypass, or path-based trust decision.

Descriptor SHA, commit proofs, bounds, codecs, structure, stored-chunk SHA and
raw-chunk SHA remain mandatory for every record actually read by the offline
exporter. The existing bounded decoded cache remains. Unread corrupt payloads
need not prevent an unrelated short clip; explicit `tools/verify_ssc.py` still
checks the whole capture. Cached samples do not bypass source-change detection:
stamps are checked around sampling, after readback, during encoding and before
publication. Appends and replacements require a new ordinary job.

Ordinary inspection sidecars reuse this binding, eliminating their additional
full hash, and restore against the same unchanged local file. They are explicitly
local provenance, not portable whole-source integrity certificates. Portable
G4 selection recipes retain their existing content-verification contract and
pinned append behavior. The renderer now delegates their source proof to the
existing analysis binding/recipe validator instead of first repeating the same
prefix SHA itself. Other explicit SHA-bound jobs use a cancellable chunked hash.

## Real-capture measurements

Linux development viewer; Godot 4.7.2 `ed1daf0bf`, Forward+/Vulkan, RTX 3070 Ti,
NVIDIA 615.71.09, FFmpeg 8.1.3. Both matched runs invoke the actual production menu,
dialog Start Export signal and process launcher, with a 1280×800 parent window;
Scientific preset, fixed particle color, full-resolution `psi_imag` with linear
opacity mapping, deterministic orbit 0.08 rad/s,
overlays/history off, high/CRF18. Export: **[20,25), rate 0.25, 2560×1440, 60 FPS**.
No solver or replacement capture was generated.

| Measurement | Old `ffa5e95` | Corrected matched run | Corrected full run |
|---|---:|---:|---:|
| Start Export callback returns | 332.108 s | 0.026 s | 0.037 s |
| Start Export → ready observed by parent | not separately exposed | 3.081 s | 3.881 s |
| Start Export → first frame observed | 670.550 s | 3.268 s | 4.088 s |
| Longest parent SceneTree update gap | 332.114 s | 0.031 s | 0.047 s |
| Completed frames | 1, then cancelled | 1, then cancelled | 1,200 |

Matched runs disable unrelated interactive prefetch in the harness; the full run
retains the normal viewer with interactive preparation enabled. All runs use the
normal development viewer, not a headless/dummy renderer or a worker-only shortcut.
The parent observations have approximately 200 ms progress-poll granularity and
include engine launch. Worker-internal ready/first-frame times in the full run are
2.254/2.483 s after `_ready`, excluding process initialization. This is a local
warm-system measurement, not a controlled cold-cache or cross-platform benchmark.
The baseline was frozen outside the checkout; small fixture regressions overlapped
part of its second hash, so do not interpret the ratio as a storage benchmark.

The two matched first-frame PNG SHA-256 values are identical:
`839d7a4fe281f8bc6a785027e9d56dbb4d9caf562e768ae663e5824c1dbabe69`.
The full export contains exactly 1,200 frames, 2560×1440 at 60 FPS, duration 20 s;
all manifest times equal `20+n/60*0.25` within 1e-12, ending at 24.9958333333333.

### Full-run stage timings

| Stage | Time |
|---|---:|
| Parent source identity only | 10.543 ms |
| Worker source identity/pinning | 17.957 ms |
| Worker opening (includes initial strict reads) | 1.142 s |
| Strict reader calls (includes cache hits/source checks) | 39.650 s |
| Actual channel decode within those calls | 31.039 s |
| Stored payload SHA within decode | 10.915 s |
| Raw payload SHA within decode | 11.622 s |
| Payload file I/O within decode | 1.385 s |
| Sampling/preparation inclusive | 54.796 s |
| Forced rendering + GPU readback | 25.167 s |
| PNG compression/writes | 125.044 s |
| FFmpeg encoding/publication/cleanup | 12.998 s |
| Worker total | 230.136 s |

Nested reader/decode/hash timings overlap opening and sampling; **do not add all
rows together**. Seventy-five strict record decodes consumed 4,187,510,325 stored
payload bytes. PNG writing now dominates this case; no source quality, field LOD,
precision, sampling or render settings were reduced for speed. The old callback
measurement includes launch bookkeeping plus its synchronous hash; old worker
loading/hash/first frame was not split by instrumentation and took approximately
338 s after the parent returned. No invented per-stage baseline is claimed.

Full-file SHA before (old job identity) and after all production tests matches:
`c782dcd65ffa6bf8a2e6b548e051a3f258b331802fcd18d3b63042f6763d6e24`.
The explicit post-test SHA took 104.915 s and was outside export startup/timing.

## Cancellation, mutation and regression evidence

- Real capture, cancellation during `loading`: zero rendered frames, no MP4,
  cancelled worker observed exited in **413 ms**; parent maximum update gap 33 ms.
- Explicit SHA-bound production job: cancel during chunked prefix verification,
  exited in **356 ms**, without rendering or publishing an MP4.
- Reader tests cancel index construction and refuse partial strict sample reads.
  Selection-recipe preparation now exposes the existing background cancellation
  operation through the dialog and Jobs action.
- Actual dialog-path fixtures reject used payload corruption, permit a clip not
  reading that corrupt record, and reject equal-size mutation with restored mtime
  both during rendering and encoding. Local sidecars round-trip on unchanged
  sources; identical-byte different-inode sources do not match identity.
- Existing rendering/encoding cancellation and parent-close lifecycle, G4 pinned
  append, source mutation, quotas and portable recipe replay remain covered.

| Refreshed suite | Backend | Assertions |
|---|---|---:|
| Current SIMSCP4 layer/export fixtures | Forward+ | 235 |
| Current SIMSCP4 layer/export fixtures | Compatibility | 225 |
| Full particle/video/FFmpeg acceptance | Forward+ | 142 |
| Overlay/repeat/4K | Compatibility | 111 |
| Jobs/progress/lifecycle | Forward+ | 124 |
| G4 selection render/replay | Forward+ | 44 |
| G4 pinned append/mutation/quota/cancel | Forward+ | 20 |
| Identity + actual dialog startup/corruption/mutation/sidecar | Forward+ | 55 |

Machine-readable evidence is in [evidence/issue-116/startup](evidence/issue-116/startup).
Generated captures, movies and full logs remain outside Git under
`/home/Nozba/Codex/SIMSCOPE/video-startup-116/`. The final suite table totals
**956 assertions**; repeated common assertions count per suite. Production
acceptance above is additional. The first G4 wrapper invocation omitted its
required renderer option and exited at argument parsing; corrected invocations
are the suite results retained here.

## Remaining limits and owner review

The cheap binding currently requires the existing reliable Linux local-filesystem
stamp implementation. Unsupported/coarse stamps refuse explicitly; this change
does not claim Windows/macOS/network-filesystem coverage. Local sidecars cannot
be rebound to a copied/replaced source. Explicit portable recipes still run their
existing potentially long analysis verification; this is not a redesign of G4
content-addressed provenance. Individual codec/hash calls, field preparation,
render/readback and PNG writes are bounded synchronous calls; cancellation cannot
interrupt them mid-call. Whole-capture export, production 4K throughput and other
hardware remain unmeasured. Source-change guards detect ordinary local mutations;
they are not a defense against privileged tampering with filesystem metadata.

Re-test the owner appearance/settings with a fresh output filename and the same
20–25 range. Confirm prompt progress, responsive viewer and cancellation. PR #122
must remain open for owner review; no merge or automatic acceptance is requested.
