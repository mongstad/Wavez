# Issue #377 — mixed particle preparation runway

Candidate **v0.1.0.101**, pending owner review. Accepted baseline is build 100,
PR #380 / `096670dfa8869642d69ccc9f2d05ac6c5aea81e9`. #377 was the sole Ready issue;
the owner's exact linked branch was already checked out at that accepted commit.
Previous completed #378 branch was absent after fetch/prune. No replacement branch,
main implementation commit, merge, issue closure or Project transition was made.

## Cause and change

Accepted mixed scenes reserved at most 2 GiB, half decoded / half prepared, but
requested only eight particle pairs while paused. On the owner's retained capture,
that used 234 MiB of a 1 GiB prepared allowance and stopped at four source seconds,
while fields prepared 26.8 seconds. The particle worker was idle at that boundary;
its measured busy throughput exceeded the two-pair/second 1x consumption rate.
This is a request-window limit, rather than evidence of insufficient total RAM
or a particle CPU-throughput deficit on this capture.

Mixed Automatic now uses the existing compact descriptor-sizing pass after the
lazy startup window. It budgets actual per-pair costs in direction first, then
history, within the **same** mixed reservation and 50/50 split. Two largest-pair
charges protect rolling transitions involving unequal older pinned pairs; an
initial target-sized margin was caught thrashing by the variable-size loop test
and corrected before the final capture comparison. Mixed full-preload remains
false. Opening/Play do not require full-file residency. Manual request windows,
particle-only allocation, field/mesh scheduling, physical-pressure guards, source
validation, scientific arrays and the accepted scene-ready publication are retained.
The only production logic change is in `particle_playback.gd`.

## Matched heavy capture

Owner-selected source:
`/home/Nozba/Downloads/VB_FreeCollapse_v0_2/runs_free_collapse_v0_2/S0_20261004_013659_785112/free_collapse.wvz`
(54,283,866,848 bytes; 150 particle samples at 0.5 s, 746 field samples at 0.1 s;
0–74.5 s). Fresh processes, sequential, Godot 4.7.2, Forward+ Vulkan, RTX 3070 Ti,
46.94 GiB physical RAM, 960×640, normal initial display, orbit off, loop off,
Automatic capacity/concurrency, 1x. No synthetic RAM reservations, scientific
simulation reruns, parallel viewers or renderer changes. Each run fills its
admitted window while paused, waits two settled seconds, then traverses the whole
recording and scrubs in both directions.

| Observation | Accepted main | Candidate |
| --- | ---: | ---: |
| Paused requested/published particle pairs | 8 / 8 | 33 / 33 |
| Paused particle / scene runway | 4 / 4 s | 16.5 / 16.5 s |
| Paused field runway | 26.8 s | 27.9 s |
| Paused particle decoded / prepared charge | 115 / 234 MiB | 435 / 964 MiB |
| Paused field cache charge | 28.28 GiB | 29.44 GiB |
| Peak observed RSS, including scrubs | 32.28 GiB | 33.29 GiB |
| Process swap | 0 | 0 |
| Source time 1–60: particle minimum / median lead | 1.49 / 3.05 s | 10.45 / 14.41 s |
| Source time 1–60: scene minimum / median lead | 1.49 / 3.05 s | 10.45 / 13.31 s |
| Source time 1–60: field minimum / median lead | 8.52 / 10.52 s | 12.51 / 13.95 s |
| Playback wall time for 74.5 s | 74.519 s | 74.518 s |
| Playback readiness wait segments / prepared misses | 0 / 0 | 0 / 0 |
| Particle completions / evictions before scrubs | 150 / 116 | 158 / 123 |
| Resident particle pairs at playback end | 34 | 35 |
| Traced successful particle busy rate | 11.29 pairs/s | 11.85 pairs/s |
| Measured field producer, paused / end | 9.54 / 9.98 samples/s | 9.35 / 10.95 samples/s |
| Playback CPU tick p95 / maximum | 35.31 / 187.64 ms | 27.53 / 236.12 ms |
| Playback frame wall p95 / maximum | 39.06 / 194.44 ms | 30.81 / 238.94 ms |
| Scrub to 37.25 / 0 / 67.05 / 18.625 s | 451 / 553 / 60 / 711 ms | 461 / 553 / 39 / 547 ms |

Both reached requested/committed 74.5 s, with no worker/scientific errors,
no preparation cancellation and unchanged source stat identity. Scrubs all
committed their exact target. Both remained aggressively memory-adaptive:
source-time 1–60 particle limits ranged 1202–2048 MiB before and 1383–2048 MiB
after. The additional eight candidate completions are rolling re-preparation
under changing headroom; this change does not promise zero eviction/rebuilding.
Field cache remains productive; the comparison provides no reason to reduce its
allocation. Cache charges conservatively count shared arrays and are not unique
RAM; RSS cannot be obtained by adding those charges.

**Claim boundary:** the measured improvement is useful prepared runway. Both heavy
runs had zero readiness holds, so stall reduction was not demonstrated. CPU tick
spikes remained despite ready samples. Frame wall includes scheduling/rendering
and instrumentation and is **not GPU hardware time**; this is not a GPU-pacing fix
or a claim that every visual stall is cache underflow. Busy-rate traces exclude
idle time and cover 147 / 155 completed jobs (early startup jobs precede trace
activation); worker completion counters are authoritative. Lead is sampled at
one-second intervals; wait-reason transitions are observed every tick. A reason
such as `Required scientific sample` can span advancing presentations, so segment
wall duration is not automatically a continuously frozen playhead duration.

Filesystem cache and desktop memory were uncontrolled. These are single matched
runs, not repeated cold-cache statistical trials or a guarantee for every capture,
immediate Play, long soaks, heavier configurations, other GPUs or platforms.
Production source identity checks use size/mtime/ctime; the 50 GB payload was not
fully rehashed. Runway, particle-cache and timeline fixtures are fully SHA-256 checked.

## Representative independent-channel comparisons

Both versions also replayed existing read-only captures sequentially:

| Observation | Accepted main | Candidate |
| --- | ---: | ---: |
| Particle-only `cavity_particles_only.wvz`: paused pairs / lead | 488 / 97.60 s | 488 / 97.60 s |
| Particle-only automatic cache limit | 17.36 GiB | 17.36 GiB |
| Particle-only observed RSS peak | 4.32 GiB | 4.29 GiB |
| Particle-only 20 source seconds / readiness waits / prepared misses | complete / 0 / 0 | complete / 0 / 0 |
| Particle-only scrubs to 105 / 0 / 189 / 52.5 s | 23 / 104 / 103 / 36 ms | 25 / 103 / 103 / 36 ms |
| Field-only N320 `vb_phi_N320_longrun.wvz`: paused lead / cache charge | 3.696 s / 27.35 GiB | 3.696 s / 27.35 GiB |
| Field-only observed RSS peak | 28.80 GiB | 28.83 GiB |
| Field-only complete 8.448 source seconds, wall traversal | 30.663 s | 29.191 s |
| Field-only sampled wait-reason segments | 23 | 19 |
| Field-only measured producer, paused / end | 6.53 / 6.70 samples/s | 6.41 / 6.64 samples/s |
| Field-only scrubs to 4.224 / 0 / 7.6032 / 2.112 s | 556 / 730 / 74 / 656 ms | 706 / 678 / 82 / 639 ms |

All scrubs committed, source stat identities stayed unchanged, no worker errors
or swap occurred. Particle-only coverage/allocation is identical; its 210-second
recording was traversed for **20 source seconds**, then scrubbed, not played to the
end. The field-only capture was played to its end. Its producer remains below
roughly 30.3 samples/second consumption; both versions show existing field refill
and scientific-presentation waits. Counts/times vary between individual runs and
are not attributed to this change, which has no enabled particle controller in a
field-only scene. No field-throughput or GPU-pacing improvement is claimed.

## Focused verification

Final results and secondary capture comparisons are in [summary](summary.json).

- Mixed runway: **44/44** headless, **44/44** source Forward+, **44/44** temporary
  Linux release Forward+; valid-source SHA-256 unchanged.
- Particle-cache sizing/reuse/live admission guard: **38/38** source Forward+.
- Scientific playback buffers, ID matching, trails and independent clocks:
  **2,457/2,457** headless.
- Rolling field pressure/ownership/source fidelity: **81/81** headless.
- Accepted scene-ready timeline contract: **77/77** headless.
- Mixed/field wait reasons, source fidelity and cache maintenance: **70/70** headless.
- Version metadata/CLI: **2/2** Python tests; Python profiler/validator syntax passes.
- Lifecycle: **50/51** after replacing the two obsolete eight-pair assertions
  with byte-admission checks. The remaining `incomplete append cannot publish a
  source timestamp` assertion also fails **50/51** on immutable accepted main.
  This is a recorded existing limitation, not a passed suite. The initial candidate
  run was **48/51** (two old scheduler assumptions plus this same append failure).
  No reader/live-append production change was made in #377.


The variable-size fixture checks automatic growth, bounded actual charges,
directional ordering, resident/distant scrubs, reverse and looping, pinned-pair
retention, manual policy, pressure reclamation/recovery, trails, visibility and
truthful required-scene intersection. The existing tiny timeline fixtures now
explicitly choose a manual rolling window to preserve their particle-limited
precondition; Automatic can naturally fit them. Timeline publication is unchanged.
Connected particle-cache, scientific playback, rolling-field pressure and
wait-reason/lifecycle checks cover the affected contracts. Unrelated camera,
video, filtering and broad shell suites were not run. Compatibility is outside
#377's Forward+-only scope.

Development attempts retained externally: first fixture rejected reused persistent
IDs before starting Godot; next harness had an explicit-type parse error; two
runs reported one real loop-edge settling failure. These are not passes. The
corrected runway runs settle with no worker errors or source changes. The separate
lifecycle limitation above remains explicitly failed.

## Reproduction and owner verification

```sh
python tools/profile_particle_runway.py --godot /path/to/godot \
  --capture /absolute/path/free_collapse.wvz --wall-limit 240 --scrub \
  --output-dir /tmp/runway-candidate
# Add --viewer /absolute/path/accepted/viewer for an immutable main snapshot.
python tools/validate_particle_runway.py --godot /path/to/godot \
  --renderer forward_plus --output-dir /tmp/runway-contract
# Add --export to run a temporary Linux release test entry with real controllers.
```

Raw traces/native logs, accepted source archive, test fixtures and external runtime
binaries remain outside Git under `/home/Nozba/Codex/Wavez/runway-377/`.
The [manifest](raw-manifest.json) records their path, byte size and hash; no capture
or third-party runtime is bundled. The release validation swaps only its temporary
entry scene, because Linux release templates ignore `--script`.

Before acceptance:

1. Open the retained free-collapse capture with Automatic particle buffering and
   default field Automatic. Confirm immediate usable paused scene and responsive
   controls; wait for preparation. Inspect the real teal scene band and particle
   diagnostics: runway should expand beyond eight pairs while fields retain RAM.
2. Play from 0 to 74.5 at 1x, then Pause/Play; monitor RAM/swap and the exact Buffering
   reason. Judge visual pacing separately from prepared coverage and record any
   remaining field, particle or display stall with its time/settings.
3. Scrub to 37.25, 0, 67.05 and 18.625; check the committed target and recovery.
   Try reverse, looping, trails and hidden/revealed particles. Do not interpret
   queued work or a sizing estimate as prepared coverage.
4. Check a particle-only and field-only capture, a manual particle budget, and
   Help → About candidate build 101. Repeat normal interactive and standalone
   capture opening on the owner's display; the 50 GB comparison used source
   replay, not a full heavy release replay or physical input test.

Stop for owner review. No owner acceptance is claimed.
