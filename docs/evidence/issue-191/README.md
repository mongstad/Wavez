# Issue #191 — adaptive mesh preparation review

**Pending owner review.** Candidate `v0.1.0.23`, based on accepted main
`cbe46ec31a5bd5f46f473683e7dd8de6581ee368` (owner-merged PR #189).
Issue #191 was the only Ready item, first in Wavez Development, and its existing
linked branch was already checked out, clean and equal to current main:
`191-perf-mesh-replace-hard-128-mib-mesh-preparation-cap-with-adaptive-ram-budget`.
Remote references were pruned; the completed #187 local branch was already absent.

## Reproduction and result

The real `cavity_collapse_torus_channels_240s.ssc` is 4,093,738,157 bytes and contains
2401 stable-topology samples, each with 256 × 256 vertices, vertex IDs and multiple
scalar channels. No external simulation ran and no source capture is committed.
Source SHA-256 before and after all four final runs:

`fa64ef312dec6d3cf55a45b197c0a4963e1fc21ef7eac25937b58739bc1b27c3`

The unchanged accepted-main snapshot [reproduced](baseline.log) the reported error.
Its conservative pair charge was 214,653,520 bytes (204.7 MiB), requiring
429,307,040 bytes (409.4 MiB), above the 128 MiB ceiling. The new policy admits
1,073,267,600 bytes (1023.5 MiB), capped by five pairs, on this 50,404,560,896-byte
physical-memory host. Charges deliberately overcount shared/temporary allocations;
they are not process RSS. [Exact source, budget and test data](summary.json).

The [policy](../../MESH_PREPARATION_BUDGET.md) retains the shared physical reserve,
working shares, finite prefetch, CPU worker and GPU staging boundaries. Fields
consume the actual mesh reservation. CPU refusal text identifies RAM and holds
committed source state; GPU refusal remains a separate preview condition.

## Validation

Linux KDE/Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti, driver 615.71.09.
Final source and release-package scripts match the reviewed implementation;
source hashes and runtime `v0.1.0.23` are recorded in `summary.json`.

| High-resolution acceptance run | Checks / failures | Callback p99 / max (ms) | Peak RSS (MiB) |
|---|---:|---:|---:|
| Source Forward+ | 174 / 0 | 15.175 / 18.283 | 846.2 |
| Source Compatibility | 174 / 0 | 10.708 / 12.569 | 455.6 |
| Linux release Forward+ | 174 / 0 | 14.644 / 16.941 | 842.3 |
| Linux release Compatibility | 174 / 0 | 10.272 / 12.853 | 424.6 |

The matrix covers physical-RAM scaling, unknown/exhausted headroom, aggregated
visible demand, real-capture opening, at most five CPU pairs, one future GPU
stage, repeated-request reuse, exact independently decoded channel hashes at
indices 0, 1, 400, 1200, 2399 and 2400, forward/reverse playback transitions,
rapid seeks, hide/reveal, low-memory refusal/recovery, GPU-only refusal/recovery,
windowed/fullscreen operation, in-flight budget reduction and close while active.
A generated high-resolution mesh/particle/field fixture checks shared reservations
and cache bounds. No global memory pressure or swap settings were changed.

All four runs measured zero viewer swap and zero system `pswpin`/`pswpout` delta.
Existing system swap occupancy is not counted as viewer use. Measured sample/tick
callbacks had zero ≥50 ms events. Active-worker close took 0–1 ms in these runs.
These are workload measurements, not universal pacing or latency guarantees.

| Existing regression | Checks / failures |
|---|---:|
| Mesh playback headless | 2731 / 0 |
| Mesh playback Forward+ | 3001 / 0 |
| Mesh playback Compatibility | 3001 / 0 |
| 192³ field admission, Forward+ | 56 / 0 |
| 192³ field admission, Compatibility | 56 / 0 |
| Particle playback, headless | 2457 / 0 |
| Rolling field cache, headless | 81 / 0 |
| Field parallelism, headless | 1800 / 0 |
| Field concurrency, headless | 109 / 0 |
| Performance maintenance, headless | 66 / 0 |
| Python application version | 2 tests / 0 failures |
| Scene playback lifecycle, headless | 51 / **1 baseline failure** |

Full strict verification [passed all 2401 records](strict-verification.log):
descriptors, commit proofs, decoded payload checksums and sample constraints.
The complete source file hash is unchanged. Godot import, Python compilation and
`git diff --check` passed.

### Failures and limitations

- The lifecycle assertion **incomplete append cannot publish a source timestamp**
  fails identically on [accepted main](lifecycle-baseline.log) and the
  [candidate](lifecycle-candidate.log). It is not marked passing or fixed here.
- An initial new-oracle run had 24 hash failures because the test widened float32
  channels; the oracle was corrected to preserve native packed precision. The
  corrected headless run passed 170 checks before adding renderer/build checks.
- A first Compatibility package import emitted dummy-texture shutdown errors.
  The [diagnostic excerpt](initial-import-diagnostics.txt) is retained; an unchanged
  warm retry passed. Both final package imports and native runs passed. Native
  Wayland's known libdecor GTK fallback is retained verbatim in final logs.
- Initial sandbox-only attempts could not save default Godot settings or open
  editor sockets. Isolated settings and authorized native runs resolved those
  environment errors; no such error is hidden in the final results.
- Low-memory cases use deterministic tightened snapshots/reservations; actual
  system OOM, OS swap forcing and a physically low-RAM machine were not tested.
- Real playback tests use representative intervals and endpoint seeks. Every
  record was strictly verified, but a continuous four-minute playback/long soak,
  every scalar-channel presentation, physical mixed-DPI/4K review and Windows/macOS
  packages were not tested. Final physical high-memory owner review remains open.
- No deterministic video export matrix was rerun: this change is limited to the
  interactive mesh preparation path; the existing synchronous/GPU scientific
  comparisons run in the mesh suite. No scientific accuracy or universal smoothness
  claim is inferred from the GUI checks.

## Owner verification before acceptance

1. Launch candidate build **v0.1.0.23** on the high-memory host and open the full
   `cavity_collapse_torus_channels_240s.ssc`. Confirm the visible mesh appears and
   status reaches Ready. Open **Tools → Performance**: CPU cache should exceed
   the old 128 MiB limit when headroom permits; GPU budget remains a separate
   control. Compare [the recorded Performance view](cpu-budget.png).
2. Play forward and reverse, scrub near the start/middle/end, hide and reveal the
   mesh, and change scalar channels/wireframe. Confirm correct source times,
   geometry and colors. Repeat in Fullscreen and return to the ordinary window.
3. Exercise both Forward+ and Compatibility, including the Linux package. Start
   an uncached seek and immediately close or open another capture; confirm prompt
   recovery/exit without a crash. Observe RAM/swap over a complete playback.
4. In a controlled low-memory environment, confirm a clear **CPU preparation**
   refusal holds the last committed sample and recovers after RAM becomes
   available. Separately lower the GPU layer budget to trigger the distinct GPU
   preview refusal, then restore it. Do not force system-wide OOM to perform this check.

[Windowed capture](cavity-ready.png) · [Fullscreen capture](cavity-fullscreen.png).
Owner acceptance is not claimed. Do not merge or enable auto-merge automatically.

## Reproduce the focused matrix

Use a fresh output directory for each renderer/package combination:

```sh
python tools/validate_mesh_budget.py --godot /path/to/Godot --capture /absolute/path/cavity_collapse_torus_channels_240s.ssc --output-dir /tmp/mesh-budget-source --renderer forward_plus
python tools/validate_mesh_budget.py --godot /path/to/Godot --capture /absolute/path/cavity_collapse_torus_channels_240s.ssc --output-dir /tmp/mesh-budget-package --renderer gl_compatibility --export
python tools/verify_ssc.py /absolute/path/cavity_collapse_torus_channels_240s.ssc
```

Run the first command with each renderer, and repeat both with `--export` for
Linux packages. Godot and export templates remain external installations.
Current handbook/status/cache guidance was updated; historical PERF-003, field
budget and earlier review reports/evidence were intentionally preserved.
