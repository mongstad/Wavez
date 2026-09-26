# Adaptive playback cache — issue #102 / PR #103

Owner-authorized follow-up to the accepted SIMSCP4 implementation and contained
metadata-capacity correction at `824f87d`; pending owner review. SIMSCP4, Python
export settings, checksums and recorded scientific values are unchanged.

## Normal operation

Opening a capture commits its first visible scene and immediately starts a CPU
worker preparing ahead from the playhead. **Automatic** is the default in
Performance. It fills as much useful forward coverage as safely fits in current
physical RAM, even while paused. If Play is pressed early, its clock waits for the admitted
window; it never requires an allocation for the complete remaining recording.
After that initial preparation, moving windows replenish in the background. Large captures open paused so useful coverage can build before the first Play;
recordings fitting the initial window retain the existing transport state. The status badge shows background progress without declaring
an otherwise usable scene unavailable.

A scrub prioritizes its target and a new forward window. Cached overlapping samples
keep their all-channel source arrays and selected preview; only missing samples are
read, checked and decoded. Cold entries outside the wanted window are evicted first
when room is needed. Backward playback fills toward earlier times; loops wrap at the
recording bounds. Each visible field follows its own clock, including a held sample
at the playhead. The cache refreshes as playback advances and at least once per
second while the controller is active. Completed captures that fit stay reusable.

Compatible channel changes retain all scientific source channels and replace only
the selected display planes. Current plus one future GPU texture remain bounded
per visible field; at most one field upload occurs per process frame. Cold targets
retain the last committed scene and clock until ready. Corrupt requested records
still pause with their contextual integrity error; corrupt future prefetch does
not invalidate an already valid displayed scene.

**Selected interval (advanced)** and **From current position (advanced)** retain
explicit interval preparation and its boundary/loop behavior. No interval entry
is needed for ordinary large-capture use. A capacity shortage says **Waiting for
available memory**, trims cold cache entries, and retries automatically; it is not
an invalid-capture condition. Pausing transport keeps useful automatic preparation
running. Closing the scene stops its worker and releases owned cache entries.

## Physical-memory admission

`playback_memory.gd` centralizes physical RAM information for field, particle and
mesh workers. Linux uses `/proc/meminfo` **MemAvailable**, not swap capacity, and
reads process RSS, peak RSS and VmSwap from `/proc/self/status`; other platforms
use Godot's `OS.get_memory_info()` physical/free values. Process and driver pages
already reduce available physical RAM and are not subtracted again.

| Allowance | Policy and purpose |
|---|---|
| System reserve | 3% of physical RAM, clamped to 512 MiB–2 GiB; modest desktop/OS growth headroom rather than a large fixed share on large hosts |
| Renderer reserve | 256 MiB future driver/UI growth; existing allocations are already excluded from available RAM |
| Other caches | Only unallocated parts of scene, particle decoded/prepared and mesh allowances, plus particle working space; occupied pages are already excluded |
| Field transient/reference allowance | Three times the largest target charge, or aggregate simultaneous visible-target charge if larger; covers decode/copy work and current/staged references |
| Allocation slack | 5% beyond explicit cache accounting for allocator, array, image and descriptor overhead |
| Owned cache credit | Still-owned source-array and preview bytes, reduced by process swap on Linux; never historical RSS peaks or a released-cache high-water mark |

Field capacity is `max(0, (available + physical owned credit - system reserve -
renderer reserve - pending other allocations - transient allowance) / 1.05)`.
The normal automatic field cache has no fixed GiB ceiling. Existing particle and
mesh workload limits remain. A controller-only `cache_cap_bytes` ceiling exists
for focused tests; zero is the product default. It changes cache coverage only.

Admission uses conservative fixed-header charges before a descriptor is needed.
After validating a descriptor, the worker charges exact retained arrays plus
selected display planes and 64 KiB of bookkeeping. The forward plan expands as
exact charges become known; it may leave less than one conservative next-sample
charge unused. Source arrays, precision, resolution and channels are never reduced
to make a window fit. Existing explicit display-quality controls are unchanged.

The controller recalculates capacity from current state, including owned cache
credit. Each worker job independently checks live physical headroom before large
allocation. A smaller budget cancels over-budget publication and evicts on the
worker, preserving UI responsiveness. Capacity guards do not replace per-record
allocation bounds or stored/decoded checksum validation.

The old field-session formula reserved `max(2 GiB, 15% physical) + 1 GiB`, all
configured other cache allowances (including already occupied pages), three
samples of scratch and another 15% margin. The new policy removes stacked and
duplicate reserves. This remains a cooperative admission policy, not an OS-enforced
process limit: other programs can allocate between checks. Unknown/exhausted
physical capacity admits no new preparation. Container/cgroup-specific ceilings
are not independently discovered; non-Linux platform telemetry needs native
validation before claiming equivalent headroom behavior there.

## Measurement and validation

Measurements and the final validation ledger are recorded below and in
[evidence](evidence/issue-102/adaptive-cache.json). The owner-provided recording is
125,950,754,101 bytes, with 1,566 field samples and 627 particle samples ending at
approximately t=156.5. The directory label includes T200; measurements use the
actual committed extent. Every field has three 192³ float32 channels (81 MiB
source plus 27 MiB selected display planes, before bookkeeping); particles retain
50,000 identities and their original channels. No capture was re-exported and no
solver or cadence setting changed.

The repeatable native probe is:

```sh
python tools/profile_adaptive_cache.py --godot /path/to/godot \
  --capture /path/to/capture.ssc --output-dir /fresh/output \
  --renderer forward_plus
```

It fills the automatic window, measures overlapping and distant scrubs, records
RSS/headroom/swap and source reads, and exercises four seconds of actual-time 4×
playback. Python independently verifies all three channels of the reported source
sample. Source stat identity is checked before/after; this is not a whole-file hash
of the 125.95 GB capture. Generated regression fixtures do use before/after hashes.
The diagnostic read trace is opt-in, capped at 4,096 keys, and disabled in normal use.

### Recorded results

On Godot 4.7.2 Forward+ / RTX 3070 Ti, with 46.94 GiB physical RAM,
a 960×640 window and the existing Scientific view (point particles, no decorative
bloom/backdrop), with orbit disabled:

| Observation | Result |
|---|---|
| First scene / automatic window complete | 1.62 s / 200.40 s |
| Initial prepared cache | 305 samples, t=0–30.4, 32.19 GiB |
| Same-state capacity: previous / new formula | 23.96 / 32.32 GiB |
| System + renderer reserve: previous / new | 8.04 / 1.66 GiB |
| Other pending cache/work allowance | 1.95 GiB |
| Field transient allowance / allocation slack | 0.32 / 1.62 GiB |
| Minimum observed available physical RAM | 4.63 GiB across preparation and exercise |
| Peak process RSS / observed process swap | 34.47 GiB / 0 bytes |
| Overlapping target / distant t=120 target | 45 ms / 791 ms |
| Cached overlapping samples reread | 0; 13 new reads while the adaptive boundary changed |
| Independent scientific oracle | All three full-resolution source channels match Python SHA-256 |

This supports a smaller explicit reserve on this desktop: peak process RSS stays
within the combined cache and other allowances, with several GiB of physical
headroom and no observed process swap. The 3% bounded system margin scales across
RAM sizes without retaining 15% of large machines; synthetic 4/8/16/48/128 GiB
policy cases and constrained/recovered capacity are tested. This is an initial
measured policy, not a proof against arbitrary concurrent allocation or every GPU.
The previous/new capacity comparison applies both formulas to the **same** RAM
snapshot and pending reservations; it does not claim a paired baseline throughput
measurement. Desktop and OS file-cache activity were not controlled.

In four seconds of actual-time 4× playback, the displayed clock advanced 15.14
source seconds. **Field preparation waits: zero; particle-buffered callbacks: 65
of 419.** Main callback p95 was 24.88 ms and maximum 37.96 ms. These are callback
measurements, not presentation-frame guarantees. Existing particle preparation
therefore still prevents a universal uninterrupted whole-scene claim. Changing
particle scheduling is outside this contained field-cache follow-up.

Regression coverage includes automatic open/fill, overlap read counts, distant and
rapid seeks, exact f32/f64 source bytes, channel-array reuse, reverse/loop ordering,
advanced-scope transitions, low-capacity trim/recovery and the worker's independent
live-headroom refusal. Existing full-interval/channel regressions, 192³ GPU budget,
requested/future corruption, mixed particle/mesh scenes and readiness UI also pass;
counts and corrected initial attempts are in the evidence ledger. Import and
current documentation/API examples are checked before the PR update.

## Limits and owner review

A finite RAM cache cannot guarantee uninterrupted indefinite playback when disk,
checksumming, decoding or rendering is slower than consumption. It buffers at an
uncached target while preserving full quality and the committed clock. Automatic
coverage removes the manual interval requirement; it does not establish unlimited
throughput, 30 fps on every system, or full-run 200 GB residency. No paged/global
index, new storage layout, lossy path or compatibility reader is introduced.

For owner review, open the provided capture paused, allow useful coverage to build,
then play and scrub both within and beyond that coverage. Check full-quality channel
switches, direction/loop controls, background progress, and desktop responsiveness.
Advanced interval behavior remains available for deliberately restricted playback.
