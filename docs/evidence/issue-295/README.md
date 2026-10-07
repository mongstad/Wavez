# Issue #295 — Load-error recovery evidence

Candidate **v0.1.0.75**, pending owner review. #295 was the only Ready item.
The exact owner-created branch is
`295-bug-load-clear-stale-load-error-after-a-subsequent-wvz-opens-successfully`,
starting clean at accepted `61c38dd326fa3074719c7023aee083e345080f7a`
(PR #296 merged). The earlier load-cleanup implementation `a97af18` (PR #134)
is also in accepted main. The previous issue branch was absent locally/remotely;
references were refreshed without an acceptance-only commit or PR.

## Reproduction and correction

The original open cleanup already erased **Open file**. An initial-sample decode
failure was also observed as **Scene**, so its second notice survived a successful
open. [Accepted-main reproduction](baseline.txt) shows ordinary invalid-prefix
recovery works, duplicate IDs produce both notices, and a subsequent valid load
leaves **Ready • Failed — details**. [Candidate reproduction](candidate.txt)
shows the same sequences recovering to **Ready**.

The narrow status change avoids a duplicate Scene notice only when its nonempty
message exactly matches the currently retained Open file diagnostic. Other owners,
and independent Scene errors even with the same text outside a failed open, remain
retained. The existing loader/open cleanup and logging remain responsible for
recovery/history. There are no loader, Jobs, scheduler or scientific changes.

## Final checks

| Check | Forward+ | Compatibility |
| --- | --- | --- |
| Production open/status regression | 176 checks, 0 failures | 176 checks, 0 failures |
| Native engine errors/warnings | None | None |
| Layouts | 1440×900, 1024×640 | 1440×900, 1024×640 |
| Screenshots | 16 | 16 |
| Five input SHA256 hashes | Unchanged | Unchanged |

[Forward+ report](forward/report.json) and [stdout](forward/stdout.txt);
[Compatibility report](compatibility/report.json) and [stdout](compatibility/stdout.txt).
The report's cases retain the actual failure text and before/after owner sets.

Coverage includes failed empty-viewer opens, header-failure replacement of a
usable mixed scene, unsupported files, real initial-sample duplicate-ID failures,
repeated failure/success and success/failure/success cycles, current failure
Details, picker cancellation, informational updates, cleared banner/text/icon/
acknowledgement affordance, refresh stability, unrelated/identical-text owner
notices, an independently observed Scene error, published active video preparation
and Jobs count, and retained session history. Header-failure replacement checks
reader/layer identity, committed sample, camera/world transform, visual/legend
snapshot and cache limit. Successful loading retains paused-first-sample behavior.

Version metadata/CLI: **2 tests passed**. Python compilation and `git diff --check`
passed. [Final isolated Godot import](import-final-stdout.txt) exited successfully
without engine errors/warnings; new test UID is included.

This small status-observation change is covered by open/status interaction tests
and the renderer/layout matrix. It does not justify unrelated camera, playback,
field, mesh, export or full scientific-format suites.

## Review images

| State | Forward+ normal | Forward+ compact | Compatibility normal | Compatibility compact |
| --- | --- | --- | --- | --- |
| Current initial-sample failure | [image](forward/normal-failed-sample.png) | [image](forward/compact-failed-sample.png) | [image](compatibility/normal-failed-sample.png) | [image](compatibility/compact-failed-sample.png) |
| Successful recovery | [image](forward/normal-recovered-sample.png) | [image](forward/compact-recovered-sample.png) | [image](compatibility/normal-recovered-sample.png) | [image](compatibility/compact-recovered-sample.png) |
| Failure details | [image](forward/normal-failed-sample-details.png) | [image](forward/compact-failed-sample-details.png) | [image](compatibility/normal-failed-sample-details.png) | [image](compatibility/compact-failed-sample-details.png) |
| Recovered details | [image](forward/normal-recovered-sample-details.png) | [image](forward/compact-recovered-sample-details.png) | [image](compatibility/normal-recovered-sample-details.png) | [image](compatibility/compact-recovered-sample-details.png) |

Additional empty/header replacement images are retained in each renderer folder.
The status icon's actual texture is checked against the existing success/error
icon, and the unobstructed native images show the bottom strip.

## Failures, setup issues and limits

- **Pre-existing late-load rollback gap:** the duplicate-ID sample failure can
  replace a previously usable scene before failure. A clean accepted-main copy
  reproduces `prior_reader_retained=false`, `prior_sample_retained=false`, and an
  empty current sample in [this baseline](late-baseline-final-stdout.txt).
  This is not a passing recovery check or a new candidate regression. The supplied
  scope excludes loader architecture changes; #295 fixes superseded UI status
  only. [The baseline driver](late-failure-baseline.gd) and
  [status reproduction driver](reproduce.gd) are retained for inspection.
- The first synthetic fixture setup omitted required units; it was corrected
  before usable reproduction/validation. The first sandboxed editor import could
  not create its local socket or save external editor settings
  ([log](import-stdout.txt)); that import is not claimed as clean. The final import
  used isolated data/config directories with the required local access and passed.
  A fresh accepted-main copy was initially launched before importing SVG/font
  resources; that inconclusive run was stopped (exit 130), imported and rerun.
- An earlier candidate native run passed 170 checks in Forward+; the final harness
  adds recovery Details images and independent Scene-observer checks. Only the
  final 176-check matrix above is used as final evidence.
- Real background worker/export execution is not tested: published preparing/job
  state is injected for ownership preservation. The tiny fixture disables
  automatic preparation workers. No release package, physical-input, mixed-DPI/4K,
  other OS, long-session, large-capture or full-suite validation was run. No input
  devices were controlled by Python or other helpers.
- Screenshot review confirms the targeted status states, not universal renderer
  parity or owner acceptance.

Historical reports/evidence, including their review-time wording, are preserved.
Current usage and exact owner steps are in [Load-error recovery](../../LOAD_ERROR_STATUS_RECOVERY.md).
