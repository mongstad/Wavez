# Video cancellation confirmation — #97

Pending owner review; candidate v0.1.0.6. #97 was the only Ready board item.
The existing owner-created branch was clean at accepted main `b6008e0` (merged
PR #139). Its #116 prerequisite was closed and the accepted export baseline
was present. Fetch/prune completed; the previous #138 local branch was absent.
The issue's old hold note refers to that already completed prerequisite.

## Behavior

**Cancel export**, including the video action in Jobs, opens **Cancel video
export?**. The prompt says that the export will stop and completed frames and
temporary files may be retained. **No** receives initial focus. **Yes** invokes
the existing cooperative cancellation method once. No, Escape, window dismissal,
and hiding the export dialog leave the worker running.

One prompt is reused. Cancellation is unavailable while acknowledgement is
pending, after terminal publication, or without an active preparation/worker.
The prompt is bound to its job directory and revalidates the current job on Yes;
completion or replacement invalidates it. Background/idle dismiss actions never
request cancellation. Settings remain locked until the existing lifecycle releases
them. Parent shutdown bypasses the interactive prompt and requests graceful
cancellation exactly as before.

Only the UI gate and action availability changed. Worker ownership, marker format,
retained artifacts, FFmpeg cancellation, progress/ETA, source sampling and
rendering code are unchanged. No external binary/template is committed.

## Validation

The status suite exercises real render workers and a real FFmpeg process paced at
input speed so encoding cancellation can be observed. It checks No/default focus,
window dismissal, duplicate requests/Yes, preparation, active rendering, Jobs,
background, terminal states, completion while prompting, retained intermediates,
encoding cancellation and parent-shutdown acknowledgement. Synthetic source
SHA-256 values must remain unchanged. Existing successful exports, missing/failing
FFmpeg, settings locks, status and playback checks remain in the suite.

Standalone validation builds a temporary Linux debug package with installed
Godot templates. Its test entry scene drives the same production viewer; child
render jobs use the normal Main scene/worker entry. It is an instrumented standalone
package, not a manual release-package acceptance test. The helper does not change
the repository's application entry scene or add distribution assets.

Results are recorded in [the evidence ledger](evidence/issue-97/validation.json).
Development Forward+ and Compatibility each passed **261 checks**, including
source invariance and parent-shutdown acknowledgement. Two application-version
unit tests passed. Packaged end-to-end validation failed:
the unchanged worker launch passes `--path`, which the installed standalone
template rejects before rendering. This reproduces the existing open #93
packaged-export boundary; it is not fixed inside #97. Packaged cancellation
parity is therefore **unverified**, not a passing acceptance criterion.

Development findings and limits:

- The first run found that emitting the confirmation window's close request did
  not dismiss it. Explicit close-request handling was added and rechecked.
- Four old status assertions expected a successful capture open to retain its
  previous load error. They were updated to the accepted #134 behavior documented
  in [load-error recovery](LOAD_ERROR_RECOVERY.md); no load-error runtime changed.
- Encoding cancellation can emit two existing `render_worker.gd` diagnostics
  when cleanup checks the encoder PID after killing it. Worker code is unchanged.
  The harness records these exact stack-specific diagnostics and still fails on
  every other error/warning. Cancellation acknowledgement and output invariants
  are checked independently. This cleanup diagnostic remains unresolved here.
- The first standalone attempt ignored `--script` and opened the ordinary app;
  it was stopped. The explicit test entry scene makes subsequent packaged runs
  execute the tests. No result is claimed for that first attempt. The second
  run executed 261 checks with 36 failures, primarily downstream worker-dependent
  checks because
  of the `--path` startup refusal. One earlier background-playback presentation
  assertion also failed in the package and was not investigated inside #97.
  The evidence retains the full failure list.
- `pytest` was unavailable; the version tests use their standard `unittest` runner.
- Linux x86_64 / Godot 4.7.2 / NVIDIA RTX 3070 Ti only. No Windows/macOS run,
  manual desktop keyboard/mouse acceptance, or production-size scientific rerun.
  This UI gate does not warrant another 118 GiB capture scan.

## Reproduction and owner checks

```sh
python tools/validate_viewer_status.py --godot /path/to/godot --output-dir /tmp/cancel-forward
python tools/validate_viewer_status.py --godot /path/to/godot --output-dir /tmp/cancel-compat --renderer gl_compatibility
python tools/package_status_validation.py --godot /path/to/godot --output-dir /tmp/cancel-package
python tools/validate_viewer_status.py --godot /tmp/cancel-package/SimScope.x86_64 --packaged --output-dir /tmp/cancel-standalone
```

1. Start an export long enough to interact with. Choose Cancel export: confirm
   the wording, Yes/No buttons and initial No focus. Press No and repeat with
   Escape and the window close button; export must continue.
2. Hide with Run in background, reopen through Jobs, then choose Cancel export.
   Choose Yes once; verify Cancelling followed by Cancelled and retained files.
   Repeated clicks must not create another prompt or request.
3. Repeat during encoding and selection-recipe preparation where applicable.
4. Let an export finish while the confirmation is open. It must disappear;
   finished/failed/cancelled jobs must not show a cancellation prompt.
5. Verify idle Cancel and dialog closing only dismiss; closing the parent app
   still cancels gracefully without requiring a confirmation response.
6. Check the same interactions in the owner's standalone build. Automated
   instrumented-package evidence does not replace desktop acceptance.

Stop for owner review. No merge, auto-merge, issue closure or Project changes.
