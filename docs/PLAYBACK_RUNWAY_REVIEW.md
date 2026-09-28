# PR #130 adaptive-runway follow-up

Pending owner review on the existing #106 branch. Accepted main is `309ec00`
(including #111 / PR #113 at `0b3d3b4`); the initial PR checkpoint is `9130336`.
The production capture, settings and source identity are the same as the original
#106 validation. The existing issue-linked branch was used throughout.

## Reproduced cause and correction

`startup_state()` in `9130336` forced readiness whenever current/next directional
samples were cached, overriding measured production and required lead.
`_automatic_ready()` also allowed that pair to bypass a capacity wait, and
`observe_frame()` waited for lost contiguous readiness/zero lead. Consequently,
rebuffering repeatedly reopened after a minimal refill. The original #106 profile
filled the admitted window before pressing Play; its zero-hold result did not
exercise this path and cannot support an immediate-Play smoothness claim.

The correction preserves #111/#113's startup thresholds: after at least three
busy seconds of current-concurrency measurements, a producer at least 1.10×
consumption requires three seconds of lead; near parity (0.95–1.10×) requires
eight seconds. Slower or unmeasured preparation waits for the admitted rolling
window. Current/next readiness is still necessary, but never sufficient by itself.
The paused status presentation and Play use the same gate.

While playing, a measured producer deficit triggers a latched wait before the
runway is exhausted: lead below two seconds, or estimated time to exhaustion
`lead / (1 - producer/consumer)` below eight seconds. Unmeasured production also
waits below two seconds, allowing for the one-second policy cadence. Speed changes
recheck the startup gate. Resume goes through that same adaptive startup gate;
there is no low-water-mark release that would cause repeated tiny refills.
A ready admitted window and completed recording boundary remain playable. GPU
staging retains its short target wait without falsely resetting CPU preparation.

The gate-only correction exposed a second runway loss during budget contraction:
completed in-flight results could be rejected before eligible history was reclaimed.
Reclamation now also runs before the existing publication-budget check in Automatic
mode. The full outstanding batch remains reserved, and publication still refuses
results that cannot fit after eligible history is retired. This extends the existing
reclamation behavior without weakening admission or publication limits.

Frequent capacity/protection updates remain intact. Rolling plans reuse immutable
job metadata within the same source/channel/budget scope, copying only the mutable
charge/reservation envelope. History accounting stops once the bounded allowance
is covered instead of formatting keys for the entire recording each source sample.
This reduces main-thread planning work without reducing pressure responsiveness.

Current/next/staged/in-flight protections, memory guards,
directional history allowance, cancellation, all-channel source reuse, prepared
coverage and the single overlay remain intact. Resident overlap counts toward the
runway and is not recomputed. No new tooltip is introduced.

## Matched production comparison

The profiler presses Play immediately after synchronous open, without prefilling
the rolling window. Each native process uses Automatic concurrency and capacity,
Forward+ at 960×640, Scientific view, point particles, and no orbit. Runs are
sequential, on Godot 4.7.2 / RTX 3070 Ti / Ryzen 7 5800X / 46.94 GiB RAM.
No other native validation runs concurrently. Filesystem cache and desktop memory
remain uncontrolled; these are matched fresh-process observations, not repeated
cold-cache statistical trials.

Accepted-main and original-PR runtime sources are immutable `git archive`
snapshots outside the repository. Only the shared profiling script is overlaid
for identical instrumentation. The implementation remains on the owner's linked
branch. A native post-draw timer measures rendered frame intervals; per-frame
controller timings and displayed field-sample transition intervals expose pacing
separately from holds. Playback-only pacing excludes initial preparation; both
all-playback and advancing-only intervals are retained. Lead is sampled once per
second, and the initial actual lead is captured at release. CPU runway waits are
reported separately from brief field GPU-target waits. Source values for samples
0/100/800/1565 are compared against independent strict Python reads, and file stat
identity is checked before/after each run.

The first gate-only trial started with 10.69 s of lead but still had two CPU
runway holds totaling 7.08 s. Between approximately t=19.24 and t=25.20,
its rolling budget contracted from 35.18 GB to 27.55 GB: only five preparations
published while cancellations rose from two to 65. This exposed the publication
reclamation gap described above. The final comparison below includes that fix;
the gate-only trial is retained as diagnostic evidence, not the final outcome.
The publication correction then eliminated holds, but ordinary per-sample planning
still produced a 54.81 ms draw p99 versus main's 41.25 ms. The final trial also
reuses planning metadata; neither intermediate trial is the final outcome.

The [curated measurement ledger](evidence/issue-106/runway-review.json) records:

| Full 1× production run | Accepted main | Initial PR #130 | Corrected PR |
| --- | ---: | ---: | ---: |
| Open → playback start | 12.206 s | 1.172 s | 10.999 s |
| Actual prepared lead at start | 11.893 s | 0.193 s | 10.493 s |
| Busy producer samples/s (consumption = 10/s) | 10.718 | 9.916 | 10.771 |
| Minimum sampled lead, excluding final 8 s | 7.916 s | 0.002 s | 8.093 s |
| CPU runway holds / total duration | 0 / 0 s | 22 / 6.338 s | 0 / 0 s |
| Field GPU-target / particle holds | 0 / 0 | 0 / 0 | 0 / 0 |
| Full wall time, including startup | 168.718 s | 163.696 s | 167.511 s |
| Playback draw p95 / p99 | 32.93 / 41.25 ms | 40.80 / 52.48 ms | 36.64 / 46.29 ms |
| Displayed field interval p99 / maximum | 106.61 / 152.55 ms | 144.55 / 729.73 ms | 109.31 / 156.81 ms |
| Rolling evictions / cancelled jobs | 1,330 / 115 | 1,301 / 230 | 1,441 / 11 |
| Peak process RSS | 35.65 GiB | 35.08 GiB | 36.04 GiB |
| Sampled process swap | 0 | 0 | 0 |

All three runs reached the complete 156.5-second extent and observed all 1,566
field samples. Each passed five profile checks and all four independent strict
full-channel source oracles. Scientific resolution stayed at LOD 1. The initial
producer estimate was 11.61 samples/s on main, unmeasured on the original PR,
and 11.38 samples/s on the correction; the busy-rate row above covers all batches.
Original-PR field waits were all CPU runway holds, not GPU-target waits.

Across the entire run, sampled minimum leads were 0.428 / 0.002 / 0.050 seconds
respectively; reaching the recording end naturally drains the remaining lead.
The terminal-excluded row gives the useful comparison. Lead is sampled once per
second, so these are observed minima rather than a continuous-time lower bound.
The corrected run's charged cache ranged from 9.81–32.08 GiB under a
10.27–33.12 GiB adaptive budget; minimum sampled physical availability was 4.75 GiB.
No natural admission-pressure event was recorded in these three final comparisons.

The corrected displayed field cadence closely matches main and eliminates the
long starvation pauses. Its draw p99 remains about 5 ms higher than main, with
66 intervals over 50 ms versus main's 19 (initial PR: 156). This is not a claim
of identical rendering latency or perfectly even frame presentation. The full
overlay and per-sample reclamation/planning remain active; the owner's normal
viewport/renderer still needs visual acceptance.

## Validation and limitations

Final focused validation passed 3,416 checks: concurrency 109, parallel preparation
1,800, rolling cache 82 on each renderer, field sessions 342 Forward+ / 332
Compatibility, adaptive capacity 73, viewer status 231 on each renderer, field
budget 56 on each renderer, and production playback actions 22. The three full
comparisons add 15 passing profile checks (3,431 total), plus 12 strict source
oracles. The ledger records each run separately without counting development
repeats. Final editor import, Python compilation and whitespace validation passed.
The deterministic publication-shrink probe fails exactly the cancellation/re-read
assertion on `9130336` (one failure among six checks) and passes in the corrected
82-check rolling suite. It protects current/incoming entries and verifies the
reduced hard bound as well as avoiding recomputation.

- The gate-only and publication-only trials above are retained as diagnostics.
  An attempted one-second planning cadence then incurred real process swap and
  was stopped. That change was discarded: the final implementation retains
  per-sample capacity updates. Raw output remains outside the repository.
- Initial profiling/pacing prototypes needed explicit GDScript type annotations;
  a standalone old-code probe initially lacked its inherited wait helper. Those
  failed harness attempts were corrected before their final measurements.
- One test initially assumed a nearby seek needed more work when its admitted
  window was already complete. It now chooses the penultimate resident sample
  and verifies a real publication barrier, clock hold, and runway release.
- These are single sequential fresh-process comparisons. Filesystem cache,
  allocator behavior and other desktop memory are uncontrolled. They establish
  this capture/hardware observation, not cold-cache or cross-machine guarantees.
- Full comparative traversal uses Forward+. Focused Compatibility checks exercise
  the changed behavior; no equivalent full Compatibility pacing claim is made.
  Source decoding/integrity policy is unchanged. The original complete-file
  2,193-record strict verification remains historical evidence; this follow-up
  verifies full traversal, unchanged source identity and four strict source oracles
  per run without repeating that whole-file scan.

## Reproduction

```sh
python tools/profile_dynamic_preparation.py --godot GODOT --capture CAPTURE.ssc --output-dir OUTPUT --workers auto --renderer forward_plus
```

For a historical runtime comparison, add `--viewer-dir SNAPSHOT/viewer`, with
this revision's `viewer/layers/profile_dynamic_preparation.gd` copied into that
snapshot. Keep source runtime files unchanged, use a fresh output directory and
run one profile at a time. Raw native output and process telemetry stay outside
Git; the committed report contains curated measurement summaries only.

## Owner verification

1. Open the same 192³ production capture in Automatic mode and press Play promptly.
   It should intentionally prepare an adaptive runway rather than release after
   only current/next samples. Allowing preparation to finish before Play should
   still reuse that coverage immediately.
2. Let 1× playback complete. Watch the distance from the playhead to the prepared
   edge while old history rolls out. Compare visible pacing with accepted main.
3. Seek into retained coverage, then outside it; reverse direction. Existing
   prepared arrays must be reused and the final requested scene must win.
4. Increase speed enough to outrun preparation. A real shortage should hold the
   clock deliberately, rebuild the appropriate runway, then resume without rapid
   start/stop refills. Return to 1× and check recovery.
5. Check channel changes, Loop and an advanced interval. Confirm one overlay and
   the corrected track endpoints remain unchanged. Repeat on the owner's normal
   viewport and renderer before acceptance.
