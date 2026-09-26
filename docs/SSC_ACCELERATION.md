# SSC generation and preparation investigation — issue #102

Pending owner review; baseline is owner-merged PR #101, `573c097`.
Historical reports/evidence remain unchanged. This branch proposes a clean
**SIMSCP4 / package 3.0.0** break, mandatory exact field statistics, contiguous
array chunks, resident source reuse across channel changes, and explicit finite
preparation intervals. The owner-authorized [adaptive cache follow-up](SSC_ADAPTIVE_CACHE.md)
replaces manual-first whole-timeline admission. It does not establish universal 30 fps or unlimited
streaming. The [parameter inventory](SSC_CAPTURE_PARAMETERS.md) separates solver
fidelity, capture policy, format efficiency and viewer work.

## Evidence and design decision

S0's accepted baseline spends roughly 309 s preparing its field timeline: 189 s
in scalar statistics, 75 s in stored/raw hashing, 18 s in brick assembly, 11 s in
decompression, 5 s in typed conversion and 2 s in image-plane copies. The fixed
record-header scan is already small. Channel changes previously invalidated the
selected preview and repeated all-channel reading, verification and decoding.

There is also a concrete format capacity failure. S0 has 864 committed records
(617 fields, 247 particle samples), charging **33,552,854 bytes** against the old
32 MiB descriptor allowance: only 1,578 bytes remain. Its saved producer summary
reports `failed_finalization`, `Index metadata ceiling`, `completed_t: 61.7`.
The final recorded field is 61.6. This explains the shorter extent noted in #101;
unrecorded samples cannot be recovered by changing the reader.

An initial optional-summary experiment could not fit S0 and was abandoned. The
owner explicitly removed old-format compatibility as a requirement before the
final design. No optional old-reader path, migration utility, legacy field-brick
assembly, or statistics fallback remains in the product. Both writers/readers,
analysis and generated fixtures now require version 4. Historical captures must
be re-exported to use this branch. A separate converter is not part of #102.

## Wire layout and implementation

See [the complete wire contract](../G3_FORMAT.md). SIMSCP4 retains independently
committed object records: 16-byte prefix plus bounded JSON metadata, 80-byte fixed
record header, descriptor, payload and 48-byte commit. The new magic, prefix/
metadata version and record/commit tags explicitly identify version 4. Timestamps
are binary float64; object clocks are independent and strictly increasing. Record
and channel order remain caller-defined. Exact little-endian f4/f8/i8/u4 source
values, identities, geometry, nonfinite data, codec choices and integrity checks
are retained. There is no quantization, delta encoding or channel removal.

All arrays now use consecutive 4 MiB C-order chunks (short final remainder).
Volume chunks no longer carry 32³-brick origins/shapes and need no spatial
reconstruction. Grid geometry still declares zyx shape, xyz origin/spacing and
centering; x remains fastest. Current consumers always need the full selected
grid, so the former brick granularity provided no sparse-access benefit.
Larger volume chunks change lossless compression grouping, not codec or level;
that layout effect is included in the measurements. No compression tuning,
new codec, dictionaries, temporal encoding or lossy path was added.

Every volume channel stores exact finite/nonfinite/nonpositive counts and binary
float64 extrema. NumPy computes these once at export. The schema validates count
and extrema consistency; descriptor/commit hashes bind summaries to each record.
The native viewer consumes them after validating payload checksums. The explicit
verifier recomputes them against source values. They accelerate display ranges;
scientific probes/percentiles/analysis still use source arrays. Checksums detect
accidental changes; they are not authenticity signatures against a producer that
intentionally forges internally consistent data and hashes.

The writer still spools one record before writing its descriptor and payload;
this permits checksums/lengths before the payload but costs temporary-file I/O.
Each commit flushes (no per-record fsync/resume). No global footer, padding,
alignment, on-disk directory or sidecar is introduced. Godot retains the bounded
fixed-header index and lazy descriptor validation; Python scans descriptors and
commits strictly. Both refuse unsupported versions and corrupt requested data.
A live incomplete tail is unavailable until committed, never a recovered sample.

Native decoding verifies stored SHA-256, bounded zstd frame, decoded SHA-256,
concatenates bytes, and makes typed packed arrays. Both hashes are deliberately
retained; skipping validation is not counted as a speed improvement. Float32
texture planes slice the same scientific layout. Float64 remains authoritative
in RAM, with the existing explicit float32 display conversion and overflow refusal.

## Shared preparation and playback scopes

A source-key index permits the bounded field worker to reuse immutable validated
all-channel arrays when only the selected channel changes. The scope includes
source stamp/generation, visibility and GPU budget. Replacement prepares only
selected-channel planes and geometry; no extra retained copy of all source
channels is created. Borrowed entries are atomically uncharged/replaced; cancelled
jobs restore useful old entries. Eviction favors entries outside the desired
range. Source-change invalidation, cancellation and conservative memory admission
remain active. The main thread retains current plus one future GPU texture per
visible field and uploads at most one future texture per process frame.

Performance defaults to **Automatic**: opening prepares forward from the playhead
within current safe physical RAM. Initial Play waits for admitted coverage and
does not require a full-timeline allocation. Scrubs preserve overlapping cached samples, prioritize
the requested time, and fill ahead; reverse and loop playback follow their direction.
The [adaptive cache report](SSC_ADAPTIVE_CACHE.md) defines admission, capacity waits,
measurement and remaining throughput limits. This changes no recorded data or format.

**Selected interval (advanced)** and **From current position (advanced)** still admit
an explicit range before playback. Intervals clamp or loop the clock; seeking outside
ends interval playback. Source timestamp precision and independent clocks remain.

## Alternatives considered

| Option | Decision and practical reason |
|---|---|
| Required statistics | Implemented; removes the dominant repeated native scalar pass at a measured export cost. |
| Shared immutable all-channel arrays | Implemented; practical channel switching without repeated payload I/O/validation while resident. All channels stay available to probes. |
| Contiguous full-array chunks | Implemented; much smaller descriptor footprint and no brick reconstruction for current whole-grid consumers. |
| Whole-timeline admission | Superseded as the default by automatic cache admission; advanced intervals still support complete-range preparation. |
| Selected / finite forward interval | Implemented; bounded full-quality work when a whole capture cannot fit. Interval results are separate scope experiments. |
| Adaptive playback cache | Implemented in the owner-authorized follow-up. Reuses overlapping windows without requiring a manual interval; consumption beyond prepared coverage can still buffer. |
| Paged global time/channel directory | Future large-record-count work. Existing header scan is cheap in measured captures. Paging may help extreme record counts and linear startup cost; it is not needed to remove the aggregate descriptor export ceiling. Reader memory admission is separate; see [the contained correction](SSC_METADATA_BUDGET.md). |
| Selected-channel-only retention | Deferred; reduces RAM but trades away instant alternate channels and requires probe/schema/cache changes. Full-quality multi-channel behavior takes priority. |
| Parallel validation/decode | Deferred; may reduce CPU preparation time but adds competing memory/I/O, cancellation and ordering work. Does not by itself fix GPU frame pacing. |
| mmap/alignment/GPU-ready auxiliary regions | Deferred; current Godot packed-array/Image/texture APIs still copy. A mapping alone does not make GPU upload zero-copy. Additional derived regions duplicate data and require validity/version management. |
| Skip hashes / trust previous file verification | Rejected. Resident immutable arrays may be reused; newly read source bytes are verified. |
| New compression/encoding or lower fidelity | Outside this change. No settings, samples, channels, particles, precision or spatial detail removed. |

## Measurement protocol and results

Measurements use the same retained S0 and S2 scientific arrays. The frozen
accepted checkout is an external benchmark oracle, not a shipped compatibility
reader. No solver was rerun. An external re-export harness verifies every record's
object, binary timestamp, geometry, names, associations, shapes, types and decoded
bytes with a canonical scientific SHA-256. Each new summary is independently
recomputed. Both writers use the existing zstd codec at level 1. Full capture
sample counts, field grids, channel lists, tracer populations and actual end times
are unchanged. The complete capture settings are retained in source provenance.

Three alternating-order writer trials use the same initial/middle/final field
arrays, with source reads outside the writer timer. Full re-export timings include
both a separately accumulated writer duration and total read/write duration; they
are not original solver-generation timings. Viewer profiling separates open/first
draw, preparation, source hash/decode stages, committed playback intervals, repeat
and channel-switch readiness. Native runs use Godot 4.7.2, Forward+, 1280×800,
full-resolution float32 fields, original render quality and speed. No OS cache
flush; other desktop load, monitor placement and refresh rate are uncontrolled.
Resource telemetry reports process RSS/CPU/read bytes and whole-GPU utilization/
VRAM, not an isolated GPU-process allocation.

The comparison below uses the same-session accepted S0 baseline and PR #101's
retained final S2 baseline. S2 baseline timing is historical, not a newly controlled
paired run. Full-playback figures are first runs; repeats and all distributions are
in the evidence.

| Measurement | S0 before → SIMSCP4 | S2 before → SIMSCP4 |
|---|---|---|
| Total file bytes | 14,878,413,684 → 14,805,987,333 | 11,542,897,957 → 11,537,704,660 |
| Aggregate descriptor charge | 33,552,854 → 2,701,425 | 23,070,039 → 3,016,893 |
| Median three-field-sample export | 0.2183 → 0.2407 s | 0.2163 → 0.2557 s |
| Open to first draw | 894.1 → 676.3 ms | 984.6 → 747.5 ms |
| Full preparation after Play | 310.57 → 111.01 s | 200.71 → 74.00 s |
| Open to playback ready, including fixed 2 s paused warmup | 313.47 → 113.69 s | 203.69 → 76.75 s |
| Complete playback wall time | 61.57 → 61.59 s | 200 s class → 200.01 s |
| Recurring preparation interruptions | 0 → 0 | 0 → 0 |
| Committed frame p95 / p99 | 38.37 / 40.36 → 38.48 / 39.87 ms | 38.49 / 40.58 → 38.46 / 40.91 ms |
| Worst committed gap | 133.21 → 41.97 ms | 47.61 → 55.69 ms |

Writer trials alternate version order and preserve all three complete source
channels. They show a **generation cost**, not faster generation: mandatory
statistics add roughly 10% (S0) and 18% (S2) on these three-sample medians. Full v4
writer calls accumulate 60.25 s / 51.11 s; including old-source reading takes
105.99 s / 89.59 s. These are re-export durations, not simulation runtimes or
paired full-export speedups. File-size savings are modest (0.49% / 0.045%).

S0's measured native statistics stage falls from 189.97 s to 0.0005 s of lookup;
assembly falls from 18.18 s to 9.27 s. Stored/raw hashing remains about 75 s, the
largest remaining preparation cost. Peak S0 process RSS is 22.65 → 22.22 GB with
zero process swap. Baseline physical reads are zero, while the new run records
16.0 GB, confirming the OS-cache states differ; neither is called a controlled
cold-cache trial. The new process CPU total is 203 s versus 409 s baseline,
although the new run also includes three channel switches and the baseline does
not, so these totals are not equal-duration utilization comparisons.

S0 prepared channel changes become visible in 28–35 ms and finish all 617 selected
planes in 5.58 s. Payload-read/hash counters stay 617 → 617 on every switch.
S2 channel changes become visible in 36–51 ms and finish all 401 planes in
3.74–3.75 s, with counters unchanged at 401. Repeat startup is about 20 ms for
both workloads. This proves reuse of already validated resident channels;
newly evicted or changed sources still incur verification. Baseline channel rework
is established by its implementation and retained #101 investigation; an identical
three-switch baseline timing run was not repeated here. CPU/GPU stage/resource
measurements and S2/range/seek details are recorded in the evidence.

The separate 10–20 s interval experiment prepares S0 in 18.59 s, then completes
both traversals with zero preparation interruptions; its three channel switches
finish the interval in 0.98–1.03 s. S2 prepares the same interval in 3.92 s,
completes both traversals without interruptions, and switches the prepared
interval in 0.253–0.255 s. This is a scope feature, not a format speedup
from recording fewer samples. The baseline has no interval-specific admission,
so a paired baseline interval-preparation timing was not claimed.

A separate paused-navigation probe measures initial middle/end visibility at
670/621 → 314/307 ms for S0 and 792/710 → 430/404 ms for S2. Repeated targets
range from 20–29 ms baseline to 20–220 ms new, depending on bounded-cache residency
and prefetch completion; a universal repeat-seek speedup is not claimed. Native
stage probes on initial/middle/final fields match source hashes, prepared plane
hashes, statistics and full-resolution LOD for all three channels in both files.
Rendered equality is covered by synthetic native regressions; real-capture visual
assessment remains an owner check.

Strict 33.3 ms committed pacing remains unmet. Preparation interruptions and
frame jitter are different metrics: these runs improve readiness substantially
while keeping complete playback at the same scientific speed and quality.

[Measurement summary for review](evidence/issue-102/summary.json) is the compact
machine-readable evidence; raw captures, native logs and profiler traces stay
outside the repository. The owner checks below remain required.

## Capacity and limits

SIMSCP4 keeps bounded 256 MiB decoded samples and 2–512 grid dimensions. The
inherited 32 MiB aggregate descriptor/export guard has been removed following
owner review. Python and native readers instead admit metadata under explicit
configurable memory budgets, with the existing separate million-record reader
capacity. Individual-record and integrity checks are unchanged. See
[accounting, configuration and above-boundary validation](SSC_METADATA_BUDGET.md).

The original S0-mix estimate reached the removed guard around 184 GB; it is no
longer an export stopping condition. Metadata residency and linear header scans
still scale with record count. A paged directory is not required for this
correction, and no SIMSCP4 layout/version change is involved.

A separate synthetic capacity check creates a valid 201,344,904,307-byte sparse
file with 8,000 128³, three-channel f4 samples and 18,312,000 bytes of descriptors.
Only 51 MB is physically allocated because the uncompressed payload is zero-filled
holes. Native opening takes 381 ms; full planning refuses 268.96 GB required RAM
against 27.54 GB safely available. Selecting t=500–501 admits exactly 11 samples,
uses 369.82 MB of field cache, prepares in 1.21 s, and reaches its boundary with
zero buffering, exact zero values and LOD 1. This tests 64-bit offsets, header
indexing, refusal and interval behavior beyond RAM; it is not a physical 200 GB
throughput benchmark, a representative scientific dataset or sustained streaming.

Whole-timeline preparation cannot fit a 100–200 GB decoded capture on this roughly
47 GiB machine. The follow-up now tests a physical 125.95 GB production capture with
automatic RAM-bounded caching; see its separate report. The original measurements
above used complete timeline or explicit interval preparation and remain historical.
Cross-machine performance guarantees and strict 33.3 ms pacing are not established.
Compression/storage bytes and decoded RAM are distinct quantities. Shader cost,
particle work, GPU uploads, driver scheduling and display synchronization remain
possible frame-pacing limits after preparation is accelerated.

## Owner verification

1. Review the format/API break and [capture parameter inventory](SSC_CAPTURE_PARAMETERS.md),
   especially independent solver, particle and field cadences. Confirm external
   integrations will use the new package; old SSC files are expected to refuse.
2. On regenerated equivalent S0/S2 captures, play the entire timeline twice at full
   quality, switch density/psi_real/psi_imag, and assess uninterrupted visual motion.
   Compare p95/p99/worst committed frame gaps, not only average fps.
3. Open the provided large SIMSCP4 capture with Automatic preparation; verify useful
   coverage builds while paused, Play uses that coverage, and overlapping/distant
   scrubs recover without manual ranges. Also check advanced interval boundaries.
4. Check low-memory refusal, channel-switch progress and GPU/display behavior on the
   actual monitor setup, and review the measured limits before accepting #102.

## Regression results and unsuccessful attempts

- Python discovery: 210 tests, zero failures. Scene storage/transform/NPZ/extraction:
  23 tests, zero failures. Documentation: all local links and three executable
  current API examples pass.
- Native field session: final headless 331 checks, zero failures (including clean
  version refusal, mandatory summaries and forbidden brick descriptors). Forward+
  336 and Compatibility 326 checks passed before the seven renderer-independent
  refusal checks were added. Both verify cancellation, source reuse, memory charges,
  interval boundaries and source/plane identity; rendered synchronous/prepared pixels
  match. Forward+ additionally verifies exact GPU float texture readback.
- Each renderer: scene playback 2,457 checks; field budget 56; lazy loading 217;
  opacity/video 98; performance maintenance 66 and lifecycle 51: all pass.
  Headless descriptor/identity optimization: 26,406 checks pass.
- Broad G3 rendering: 36 checks on each renderer and a four-frame deterministic
  video with exact recorded-time/layer-state checks pass. The first attempt lacked
  the required full-size generated scene fixture, hit its watchdog, and was rerun
  successfully after generating that fixture. Failed attempt logs remain external.
- Volume color: 138 checks per renderer, with the same two logarithmic midpoint/
  slice oracle failures seen on the accepted baseline; these remain unresolved.
  This branch does not claim those assertions pass or change unrelated shaders.
- Initial sandbox native-start attempts were unavailable; actual display validation
  used approved native execution. An earlier load-optimization invocation supplied
  an unsupported renderer argument; the correct invocation passes above.
- Physical cold-cache trials, other machines and indefinitely sustained streaming
  remain untested. The later [adaptive-cache follow-up](SSC_ADAPTIVE_CACHE.md) tests
  the physical 125.95 GB owner capture. The superseded optional-summary
  prototype results are not included as final SIMSCP4 performance evidence.
