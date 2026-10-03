# Paused opening and automatic preparation — issue #204

Candidate build **v0.1.0.35** awaits owner review. A successful scene open
presents the first recorded sample with playback paused. Opening another scene
also resets any previous Play intent. The user starts the recorded clock with
Play. The existing shared scene tick continues to pump bounded particle,
field, and mesh preparation regardless of playback state, including eligible
layers in a mixed scene. The prepared timeline and cache diagnostics still
describe actual resident coverage.

The worker caches have no idle-release timer. Their existing limits, source
generation and configuration invalidation, explicit cancellation, and
physical-RAM admission continue to govern eviction. Pausing does not add an
unbounded preload policy. File replacement closes the prior workers and
releases their cache ownership. Recorded-time rates, seeking, and scientific
sampling remain on their existing paths.

## Validation

The focused `tools/validate_paused_preparation.py` generates WVZ1 particle,
field, mesh, and mixed fixtures. It checks paused first presentation, worker
eligibility, actual prepared coverage, a stationary source clock, bounded
per-controller RAM charges, elapsed-time retention, explicit Play, pause after
playback, paused seek, and replacement while playing. In the mixed scene, a
test barrier holds particle publication while field and mesh preparation
continues. Source hashes are checked before and after each run.

| Check | Forward+ | Compatibility |
| --- | ---: | ---: |
| Four-scene source matrix | 64 passed | 64 passed |
| Synthetic 192³ three-channel field and 256×256 mesh | 28 passed | 28 passed |
| Temporary packaged Linux validation scene | 64 passed | 64 passed |
| Existing rolling-cache pressure regression | 82 passed | 82 passed |

The 70-second source hold on Forward+ passed 62 checks with no failures;
the mixed scene retained its prepared coverage for the full hold. The
existing 192³ field budget regression passed 56 checks on Forward+. Source
import and package export completed without script errors. The package used a
temporary copy of the project with this same focused harness as its main
scene; the repository's normal entry scene was unchanged. Source editor import
reported five missing-UID warnings for unchanged resize scripts. Its generated
sidecars were removed from this branch.

An initial harness run stopped on an incorrect mesh-worker property in its
replacement assertion; the assertion now checks the mesh worker's thread
pool, and the final runs pass. Direct `--script` invocation on the exported
binary timed out without starting the harness; the temporary package entry
scene resolved that validation-path limit.

The large captures are synthetic, not the owner's retained production field
and mesh simulations. Physical multi-minute pauses, other display/compositor
setups, and resource pressure from simultaneous external workloads were not
exercised. A 70-second hold demonstrates elapsed-time retention on this host,
not unlimited residency under memory pressure.

## Owner verification

1. Open a particle, field, mesh, and mixed WVZ1 capture. Before pressing Play,
   confirm the first scene is visible, the transport reads Play, and recorded
   time stays fixed while the prepared timeline grows.
2. Leave a representative large field or mesh capture paused for several
   minutes. Check that cache coverage remains resident when RAM headroom is
   stable, then press Play and scrub into prepared coverage.
3. Pause after playback has advanced; wait again and confirm that covered
   samples remain available. Exercise normal memory pressure separately and
   verify that bounded eviction still occurs when required.
4. Open another capture while the first is playing. Confirm the new capture
   opens at its first sample, paused, and old preparation resources are gone.
5. Repeat the key observations on Forward+, Compatibility, and a normal
   packaged Linux build, including a genuinely large production capture if
   one is available.
