# Field preparation memory budget

Historical implementation/measurement report. The default preparation and memory policy
are superseded by [adaptive playback caching](SSC_ADAPTIVE_CACHE.md) in PR #103.

Issue #98 (PERF-FIELD-004), verified top Ready on 2026-09-24. Implementation
is pending owner review, based on accepted main `9774623` (PR #92).

## Reproduction and accounting

A bounded synthetic SIMSCP3 fixture reproduces the reported workload: 50,000
particles, three recorded samples, and a visible 192³ float32 field with density,
psi_real and psi_imag channels, compressed with zstd level 1. The external
FreeCollapse adapter writes all three channels; displaying density does not
avoid decoding the other channels. No external solver or exporter was modified.

| Per-field quantity | Bytes | MiB |
|---|---:|---:|
| One float32 channel / full-resolution density preview | 28,311,552 | 27 |
| Three decoded source channels | 84,934,656 | 81 |
| Job charge: decoded + preview + 64 KiB overhead | 113,311,744 | 108.0625 |
| Required two-target allowance | 226,623,488 | 216.125 |
| Three distinct jobs in the test window | 339,935,232 | 324.1875 |

Before the fix, the 128 MiB ceiling rejected the 216.125 MiB allowance despite
40,140,681,216 bytes available physical RAM and 20,161,819,443 bytes conservative
safe-cache headroom on the test host (50,404,548,608 bytes physical RAM).
Even removing preview storage entirely leaves a decoded-only two-target cost
above 162 MiB: the old advice to reduce preview budget was insufficient here.

## Bounded policy and ownership

The existing physical-memory helper remains unchanged: available physical RAM
(excluding swap), a reserve of max(2 GiB, 15% physical RAM), another 1 GiB for
renderer/layer/transient overhead, and safe-cache headroom capped at 40% of
physical RAM. These are conservative allocation charges, not a measured RSS
limit or an allocation guarantee under concurrent memory pressure.

Before allocating field capacity, subtract the configured scene-reader cache,
particle decoded cache, particle prepared cache, particle working allowance
(two largest pairs), and the existing 256 MiB mesh cache/working reservation
when mesh preparation is enabled. Particle policy and its limits are unchanged.
Subtracting configured reservations even when already resident is intentionally
conservative; this can refuse work before all physical RAM is occupied.

Let T be the sum of visible target job charges, W the distinct current plus
four-lookahead job charges across visible fields, and R the remaining safe
headroom after those other reservations. The CPU cache ceiling is:

`min(max(2*T, W), floor(R/4))`

Admission still requires `2*T <= ceiling`. A quarter of R is available for
cached preparations; two further shares allow current/staged source references
and decode/conversion temporaries, with the fourth left unused. The workload
cap prevents a small field from claiming all host memory. No whole-capture field
preload was introduced. At most four future indices per visible field are
considered, and only jobs fitting the cache are admitted. Reverse/loop behavior
and de-duplication are unchanged.

Headroom is sampled on workload/reservation changes and at most once per second
otherwise, allowing refusal recovery and budget reductions. Before each decode,
the worker separately checks current available RAM against the OS/application
reserve, other reservations and three job charges. A reduced cache ceiling is
rechecked before publication, so an in-flight decode cannot publish above it.
This cannot undo memory already allocated by an in-flight job or other processes.

GPU preview limits remain separate: the selected channel uses the existing
preview/LOD budget, with a current texture and at most one future staged texture
per visible field, and at most one main-thread upload per process frame. The
192³ fixture retains its full-resolution 27 MiB preview. No scientific channel,
precision, field hold/interpolation, color/opacity, recipe schema or export
sampling changes are part of this patch.

Performance shows charged CPU cache usage/ceiling and required-versus-budget
refusal text. Its tooltip distinguishes cache capacity from process memory.
The profile report includes source/preview target charges, the headroom snapshot,
separate reservations, and current/staged GPU bytes. Free RAM or hide fields
when decoded data dominates; reducing GPU preview resolution cannot remove
source-channel decode costs. RAM-guard failures also show needed/available RAM.

## Validation and limits

Compact evidence is in [issue-98 validation](evidence/issue-98/validation.json).
Raw fixtures/logs remain outside Git under `/tmp/issue98-*`.

- Original cap: reproduced refusal, one check passed.
- Native 192³ regression: advance, held interval, seek, all-channel SHA-256,
  exact float32 preview, cache/lookahead/GPU bounds, unchanged particle limits,
  simulated reservation exhaustion/recovery, two visible fields, and reduction
  during worker publication. 56 checks per renderer, no failures.
- Existing scene playback: 2,457 checks per renderer, no failures.
- Maintenance and lifecycle: 66 + 51 checks per renderer, no failures.
- Existing field preparation: 32 checks per renderer using a small generated
  float64 plume oracle; exact source/probes and async/sync volume/slice pixels.
- Volume opacity: 98 checks per renderer plus actual MP4 export, identical pixels,
  preserved mapping sidecar and unchanged source bytes.
- Recipe restoration: 2,697 headless checks, no failures.
- Volume color: 138 checks per renderer with two failures (GPU logarithmic
  midpoint and slice logarithmic semantics). Both failures also reproduce in
  an isolated archive of unchanged accepted main `9774623`, on both renderers.
  The color validator stops before its export phase; opacity export coverage
  above passed. This patch does not alter that pre-existing color discrepancy.

An initial isolated-baseline run before Godot asset import was inconclusive;
imported baseline retries established the comparison. Sandboxed editor import
also reported restricted socket/settings access; native script runs are the
validation evidence, not editor startup. Retained 03B benchmark assets were not
available; the field suite used the generated oracle described above.

No full N=192, t_end=300 external simulation was run. This change addresses
SimScope async field preparation only, not the separately reported external
SSC export problem. Long production playback, low-RAM hardware, concurrent
simulation/viewer pressure, and real-dataset throughput remain owner checks.
Constrained tests alter reservation inputs, not actual host memory pressure.

Reproduce the focused large-field regression (fresh output directory required):

```sh
python tools/validate_field_budget.py --godot /path/to/godot \
  --renderer forward_plus --output-dir /tmp/field-budget-forward
python tools/validate_field_budget.py --godot /path/to/godot \
  --renderer gl_compatibility --output-dir /tmp/field-budget-compatibility
```

## Owner verification

1. Open the existing N=192 capture with particles and density visible, using the
   normal async playback path. Allow initial buffering to finish.
2. Open Performance/Details. Confirm the field budget exceeds the old 128 MiB
   cap when enough safe RAM remains, and no fixed-cap refusal appears.
3. Play through several recorded field changes, pause, seek forward/backward,
   then resume. Confirm density and particles retain the expected physical times.
4. Change field channel, hide/show the field, and exercise existing preview
   budgets. Check that source values/probes remain unchanged and preparation
   recovers when sufficient capacity is available.
5. Repeat on Compatibility if normally used, and export a short existing field
   view. Report any production-only refusal with its required/budget numbers.

Stop for owner review; no merge, issue closure or Project transition performed.
