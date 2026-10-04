# Particle cache capacity — issue #229

Candidate **v0.1.0.36** is pending owner review. Automatic particle preparation
uses available safe capacity for the whole scene when it fits, and a contiguous
useful interval otherwise. Opening and Play do not wait for whole-scene completion.
Scenes containing fields keep the existing eight-pair / at-most-2-GiB automatic
particle window, preserving RAM for the large field runway. Field and mesh
preparation algorithms are unchanged.

## Why mixed scenes buffer particles and fields differently

A very large mixed recording can be much larger than RAM (for example, roughly
150 GB). Its field cache reserves enough prepared playback time to absorb slower
field preparation and sustain continuous playback. Particle preparation retains
a small rolling window around the playhead, leaving more RAM for that field
runway. Partial particle coverage is therefore intentional in a scene containing
fields; it does not mean field preparation has stopped or that RAM was overlooked.
The particle tooltip states this policy explicitly.
The eight-pair limit applies to the requested window; previously prepared particle
intervals may remain cached within the RAM budget. Coverage can therefore exceed
eight pairs after playback without background preparation filling the whole file.

A particle-only recording has no competing field runway. Automatic mode can cache
its whole prepared representation when it fits the safe budget. File size alone
never decides whether either kind of cache fits.

Temporary holds at 2× can also come from the existing field refill gate while
particles remain ready. See the [mixed playback investigation](MIXED_PLAYBACK_BUFFERING.md)
for the matched pre/post-#230 comparison and worker/memory observations.

## Admission and scheduling

The initial requested pair and a short lookahead retain the lazy opening path.
Once that window settles, the same low-priority CPU worker validates future
record descriptors without decoding their payloads. It retains compact per-sample
costs, not the descriptor trees. A cancelled/replaced source cannot publish sizing.
Invalid future descriptors keep conservative bounds and do not invalidate the
current visible sample; requesting the bad record still reports its normal error.

Validated shapes determine particle count independently of channel count. Sizing
includes retained native channel types (including u4 to f8 conversion), persistent
ID lookup charges, display positions/intensity, velocity magnitude, style buffers,
ID matches, and enabled trail history. These costs match or conservatively bound
`Typed.read`, `Prepare.frame`, and `Prepare.pair` accounting. Shared immutable
arrays and identity maps remain conservatively charged more than once.

For scenes without fields, automatic admission preserves the existing physical-memory policy: no swap
capacity, a 40% physical-RAM ceiling, 3% system reserve clamped to 512 MiB–2 GiB,
256 MiB renderer growth reserve, competing scene/mesh/field-work allowances,
per-pair transient space, and 5% allocation slack. The decoded/prepared shares
follow the measured representation instead of a fixed half-and-half split.
Budget checks continue while paused. Reduced budgets reclaim cached entries;
workers also check live physical headroom before allocation and current limits
before publication. Pressure stops preparation and retries as headroom returns.
Manual RAM choices retain their bounded rolling behavior.

The request order prioritizes the requested interval and direction, then history;
full preparation can fill both sides of a paused playhead. Startup remains usable
without complete coverage. Scientific data, particle quality, GPU resource counts,
source verification policy and field/mesh scheduling are unchanged.

## Status and timeline

**Ready** describes the ability to present the committed visible sample. The
particle tooltip additionally reports prepared intervals versus scene intervals,
background/full/pressure state, and authoritative decoded/prepared cache charges.
Those charges are conservative cache accounting, **not unique RAM or process RSS**.
The teal timeline still intersects actual resident prepared intervals across
visible layers; descriptor sizing alone never marks an interval prepared.

## Historical investigation

- Initial repository snapshot `35d405e` supported automatic full particle preload
  when safe. The historical `PERFORMANCE_MAINTENANCE_REPORT.md` records both its
  memory safeguards and its startup/full-preparation tradeoff.
- PR #101 (`573c097`, specifically review commit `f63b140`) deliberately changed
  particle preparation to at most eight requested pairs and a default 2 GiB
  decoded/prepared cache. `SSC_LAZY_LOADING.md` records the reason: an immediately
  usable initial scene and controls, avoiding a roughly 22-second whole-particle
  preparation wait, and deferring malformed/large future samples. Those are valid
  interaction/safety constraints; the evidence does not establish that background
  caching must permanently stop at eight pairs when a whole scene fits.
- PR #101 subsequently introduced full **field** preparation. PR #103 (`6d4df9a`)
  expanded adaptive field capacity, with 32.19 GiB resident field cache measured
  on the 48 GiB workstation class. Its production run still reported particle
  waits. PRs #110/#113/#130 (`7dc253e`, `0b3d3b4`, `fb75c8c`) advanced field
  concurrency/runway/reclamation; they did not expand the particle scheduler.
  This explains why fields could buffer large amounts yesterday while the
  particle-only path remained limited. Reserving most RAM for fields was an
  architectural effect in the reviewed code. During #229 the owner clarified the
  intended mixed-scene tradeoff: the large field buffer supplies enough runway
  for continuous playback of roughly 150 GB files while particles buffer around
  the playhead. This implementation preserves that policy for scenes with fields.
- The phrase “The committed visible sample is ready” was already present in
  PR #48 (`1976adc`). PR #129 (`309ec00`) unified status semantics, retained
  authoritative field tooltip details, and removed the adjacent preparation
  counter. It did not change caching. Particle cache details were available in
  the particle controller but were not connected to that tooltip.
- PR #216 (`dda54ae`) changed format identity to WVZ1 without changing these
  particle budget/scheduler files. PR #228 (`70fd282`, issue #204) made scene open
  paused and kept the shared scheduler pumping; it did not introduce this limit.
  Historical reports remain untouched. No recent regression in field buffering
  is claimed.

## Validation and owner review

Production measurements, final check counts, corrected test attempts and known
limitations are recorded in [issue evidence](evidence/issue-229/README.md).

Reproduce the focused check (the source is read-only; no simulation runs):

```sh
python tools/validate_particle_cache.py --godot /path/to/godot \
  --capture /absolute/path/cavity_collapse_recirculator_192_long.wvz \
  --renderer forward_plus --output-dir /tmp/particle-cache-review
```

Omit `--capture` for the smaller channel-rich persistent-particle fixture.
Use `--renderer gl_compatibility` for Compatibility, or `--packaged --godot
/path/to/review-package` for the temporary test-entry Linux package.

Before acceptance:

1. Open the production WVZ1 file with Automatic particle buffering. Confirm that
   the first scene and controls are usable immediately, time stays paused, and
   the teal prepared band grows to the complete 0–200 interval with sufficient RAM.
2. Hover Ready during preparation and after completion. Check the partial count,
   full-scene wording, and decoded/prepared cache charges. Do not compare those
   conservative accounting totals directly with the process RSS displayed by KDE.
3. Scrub to the middle and end, then back; press Play and Pause. Covered samples
   should reuse the resident cache. Leave paused and confirm coverage is retained.
4. Try a smaller particle file and a mixed particle/field/mesh scene. Confirm
   independent field preparation and normal scientific presentation remain usable.
5. Under normal competing workload, confirm bounded coverage and pressure reporting;
   release the workload and check recovery. Repeat in the renderer and normal
   packaged application you use. Physical desktop pressure and visual acceptance
   remain owner checks; automated injected-pressure tests do not allocate competing
   system RAM.
