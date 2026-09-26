# PR #101 channel-switch stability triage

The reported failure is a regression in PR #101's full-field preparation
lifecycle. It is a handled RAM-admission refusal that pauses playback; the
native viewer stays alive. Unchanged accepted main did not reproduce it.
This correction remains within #100 / PR #101 and is pending owner review.

## Reproduction and comparison

The production recording is the owner's
`S0_20260925_060202_938955/free_collapse_simscope.ssc` under
`/home/Nozba/Documents/VB_FreeCollapse_v0_2/VB_FreeCollapse_v0_2/runs_free_collapse_v0_2/`.
It contains 617 full-resolution 128³ fields and 50,000 particles per particle
sample, spanning 0–61.6 recorded time units. Its scalar channels are `density`,
`psi_real` and `psi_imag`; it has no `psi_mag` channel.
Production probes run the native Forward+ viewer and emit the actual channel,
mapping, colormap and transport controls' signals. They do not substitute a
headless renderer or reduced dataset for the production comparison.

The owner reproduced `psi_imag → density` during preparation at 2.0× speed.
The retained visible sample was still `psi_imag`, float32 / stride 1, with
Magnitude opacity and linear color normalization. The actual diagnostic was:

> Continuous field playback needs 19.3 GiB prepared RAM; 16.0 GiB is safely available. Free RAM and retry. This workload cannot be declared ready with only a short prefetch window.

The same failure was independently captured on PR head
`4ecba4f95b3cdc294a0ec902edfd6ca151859051`: complete preparation and playback
at 2.0×, return to the beginning, resume, select `psi_imag`, and allow the new
plan to finish. It reported **19.3 GiB required / 6.8 GiB safely available**.
The amount depends on how much of the previous preparation was completed.
The viewer reported `Unavailable` and stopped the playback clock. Godot exited
normally when the probe closed it; no native crash stack was emitted.

The identical probe on unchanged accepted main
`d42a4dcd295718357d7bca068e57b1b644311c75` completed the full interval at
requested 2.0× and then switched through
`density → psi_imag → density → psi_imag → density → psi_real → density`
without a controller or engine error. Main uses rolling preparation and still
buffers during playback; this result concerns stability, not playback speed.
All 339 tracked viewer files in the baseline snapshot matched their Git blobs.

Separate paused probes exercised 30 selections across both scalar alternatives
on each revision without failure. Rapid switching after full PR preparation
also missed the failure because it cancelled each replacement plan before its
admission decision. These passes do not supersede the failing settled case.
An early main probe pressed Play during initial buffering and did not complete
playback; `main-s0-reprepare` supersedes that attempt.

## Immediate cause and correction

On the failing PR run, the full field-cache charge was 19.319 GiB. Channel
invalidation immediately purged that cache before replacement admission.
Godot's live-allocation counter fell from 20.325 GiB to about 0.7–0.95 GiB,
but the process retained roughly its former resident footprint and Linux
reported only 18.396 GiB available. This distinguishes allocator-retained pages
from live references keeping the entire prepared cache alive.

The replacement planner then credited **zero resident field bytes** and
subtracted the existing OS/renderer reserve, competing caches, working space
and allocation slack from that low available-memory reading. Its computed
capacity was 7,272,205,200 bytes, below the unchanged 20,743,520,256-byte field
requirement. This is the source of the failure, before replacement GPU uploads;
colormaps and opacity mappings are not part of the failing admission calculation.

The fix keeps one bounded, already-admitted cache across channel changes in
the same source, visibility and texture-budget scope. Replacements evict obsolete
entries incrementally, so still-owned arrays/planes remain charged and receive
their existing, conservative admission credit. There is no second full cache.
Paused switching also retains the owned allocation; cancelling partial
preparation retains only the allowance covered by completed cache entries.

Acquisition and publication continue to check the channel generation. Obsolete
entries are evicted before current-session entries, conflicting stale keys are
removed before replacement, and GPU staging remains current plus one future
texture. Source/visibility/budget invalidation and closing release retained
preparations. The available-physical-RAM guard and full-quality source data are
unchanged; no allowance is invented for freed allocator pages.

## Validation and evidence

The new repeated-switch cache assertions failed 19 checks against the original
PR implementation. With the correction, field/session validation passed
280 checks headless, 292 on Forward+, and 282 on Compatibility. It exercises
both alternative scalar channels, paused switches,
2.0× playback settings, complete replacement readiness, exact source hashes,
LOD 1, LRU/byte-accounting consistency and overlapping cancellation while an
old preparation is held at its publication barrier. Prepared image planes are
compared with independent Python-generated float32 byte hashes on every backend;
Forward+ also reads back each replacement GPU texture and verifies those bytes.

Related headless checks passed: scene playback 2,457; lifecycle 51;
performance maintenance 66; lazy loading/corruption 217. Native field-budget
checks passed 56 on each of Forward+ and Compatibility.

The native production stress run completed initial density playback, full
`psi_imag` replacement, repeated `density ↔ psi_imag` and `density ↔ psi_real`
switches during preparation, six end-to-middle slider drags, Magnitude/Linear
scalar changes, and colormap changes. Final density preparation reached 617/617,
and a complete 2.0× replay reached 61.6. All recorded controller errors were
empty, LOD remained 1, byte accounting agreed, and staging stayed at one future
texture. Peak process RSS was 21.261 GiB, with no swap; maximum field-cache
charge was 19.319 GiB. Replacement admission credited 19.2 GiB of still-owned
data and computed about 23.1 GiB safe capacity. Source SHA-256 remained
`c76d2cc2e9909dcfac5ed90a5526c8873cafb4b3d0d37ea949b135fe4a27e22a`.

A final focused production run on the final code switched `psi_imag → density`
at 256/617 prepared samples with Magnitude mapping and 2.0× speed. Density
reached 617/617 and completed playback to 61.6 without errors. Admission retained
7.97 GiB of owned cache credit and computed 23.60 GiB safe capacity. Peak process
RSS was 21.448 GiB, with no swap; cache accounting agreed, LOD remained 1 and
staging stayed at one future texture. All 136 viewer script hashes matched the
tested source after the run.

Compatibility's `ImageTexture3D.get_data()` is not a byte-exact float oracle
on this Godot 4.7.2 / NVIDIA setup. A standalone eight-value texture upload,
using the unchanged main project and **no SimScope code**, also returned clipped,
8-bit-quantized values: for example, `-2 → 0`, `5 → 1`, and
`0.125 → 0.1254902`. This does not establish the precision of shader sampling.
Exact GPU-readback assertions therefore apply to Forward+; Compatibility keeps
source/plane hashes, renderer pixel equivalence, lifecycle and staging checks.
This independent readback limitation is documented, not changed in #101.

Local raw evidence, external probes, native logs, screenshots and memory samples:
`/home/Nozba/Codex/SIMSCOPE/channel-switch-triage-20260926/`.
Key directories are `pr-s0-reprepare`, `main-s0-reprepare`, `regression-before`,
`regression-after`, `pr-s0-fixed-stress` and `pr-s0-final-partial`.
`production-summary.json` summarizes the runs; `checks-final.json` records the
final renderer checks. `readback-main.json` isolates the Compatibility limitation.
`manual-error.txt` preserves the owner's diagnostic. These captures and generated
artifacts are not committed.

Owner review should repeat the S0 path at 2.0×, including switching back to
`density` while another channel prepares, Magnitude/Linear scalar changes,
colormap changes and end-to-middle slider scrubbing. No merge or issue closure
is authorized by this report. The prior report's frame-pacing and
larger-than-admitted-memory limitations remain in effect.
