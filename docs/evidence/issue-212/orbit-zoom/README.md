# Orbit zoom reversal correction

Candidate v0.1.0.78, same issue #212 branch and PR #302. Prior reports remain historical.

The regression added to `test_orbit_gizmo.gd` fails 10 assertions against the
previous production code at `0e34a33`: a chosen orbit closer than the scene's
bounding radius can zoom out but cannot return inward, and zoom invalidates its
saved orbit plane. The scene-wide inward limit and pose/distance mismatch are
independent causes; no scientific geometry moves.

The applied observer orbit now consumes wheel zoom using near/far clipping limits
(two near clips to one far clip), updates its saved pose/radius, and preserves its
center, plane and angular phase. Existing distances outside the limits recover
progressively. Marker size remains independent and survives reopening after zoom.
Ordinary framing zoom, manual takeover, input sensitivity and clip planes are unchanged.

## Validation

- Before correction: 2,858 headless checks, 10 expected regression failures.
- After correction: 2,858 headless checks pass; 2,919 pass in each native renderer
  and each Linux release-template validation package (Forward+ and Compatibility).
- Each native/package run includes 36 rendered landmark comparisons. Source
  capture hashes are unchanged. Package hashes and counts are in `summary.json`.
- The 20 new checks cover three out/in cycles while orbit advances, a tilted
  plane, target facing, fractional wheel events, near-limit reversal, marker
  size retention and manual steering takeover. Events enter `_unhandled_input`.
- Existing Auto Orbit suite: 372 headless checks pass. Initial import stopped on
  cached UID regeneration warnings; unchanged retry passed. Warning log retained.
- Application-version unittest: 2 pass. An initial pytest invocation was unavailable
  because pytest is not installed; these tests ran through their native unittest runner.
- `git diff --check` passes.

Reproduce using `python tools/validate_orbit_gizmo.py --godot <Godot 4.7.2> 
--output-dir <fresh-directory> --renderer <headless|gl_compatibility|forward_plus>`.
Add `--export` for a Linux release-template validation entry package. Existing
Auto Orbit checks use `tools/validate_camera_tumble.py --suite auto-orbit`.

Package checks use a test entry scene with production modules; ordinary launcher,
worker and physical device mapping are not established by these runs. There is
no separate middle-button drag zoom handler; this correction covers mouse-wheel
zoom. Owner verification: Apply near a chosen research feature, scroll out and
back in repeatedly during orbit, and confirm the target and orbit plane persist
without needing WASD. Earlier known navigation timing and extreme-scale clipping
limitations remain documented in the previous reports; those suites were not rerun.
