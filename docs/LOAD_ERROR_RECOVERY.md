# Failed capture-load recovery — issue #104

Pending owner review. #104 was the only Ready item in SimScope Development when
selected. The existing owner-linked branch is
`104-ux-status-001-clear-stale-status-bar-errors-after-a-successful-ssc-load`.
It started clean at accepted main `f6191e0af4a3a432c870bd8455cdd3e532a99640`
(PR #133). Main and the linked remote branch matched; fetch/prune completed and
the previous local issue branch was already absent.

## Change

The shell's `finish_open()` deliberately retained the failed-open notice even
after a later successful load. This left both the banner and the status adapter's
`Open capture` diagnostic attached to the previous failure.

A successful load now hides the failed-open banner, empties its stored details,
erases only the `Open capture` failure and refreshes the status presentation.
Normal readiness continues to come from the current capture. Failed attempts
still replace the load diagnostic; cancelling the picker and unrelated updates
still leave it available. Other job failures retain their existing acknowledgement
behavior. SSC validation, reader behavior, scientific state and playback gates
are unchanged. The application candidate is `v0.1.0.3`, accepted main BUILD + 1.

The handbook and current status describe the new behavior. Historical UX3 status,
About and other review-time reports/evidence retain their original wording.

## Validation

The new recovery regression produced **five expected failures** against accepted
main before the fix (679 total assertions). These covered stale banner/details,
retained status failure, stale failure in Details and repeat recovery/current status.

The final native shell suites use Godot 4.7.2 on Linux x86_64 / NVIDIA RTX 3070 Ti.
Both renderer suites passed **679 assertions each (1,358 total)**, with no native
errors/warnings, matching menu contracts and unchanged capture hashes. Both Python
version tests, packaged-notice drift checking, Markdown links, three executable
documentation examples, Godot import and whitespace checks passed.
[Failed load](evidence/issue-104/load-error-current.png) and
[successful recovery](evidence/issue-104/load-error-recovered.png) screenshots were
visually inspected. Results are recorded in
[the validation ledger](evidence/issue-104/validation.json).
The regression covers invalid → valid, invalid → rejected retry → valid, picker
cancellation, actionable details, retained unrelated export failure and another
invalid → valid cycle without acknowledgement. Existing shell tests also verify
that failed replacement preserves the prior reader/sample/scientific state and
that unrelated informational updates do not erase errors.

Reproduce with fresh output directories, running native suites sequentially:

```sh
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/status-forward --renderer forward_plus
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/status-compat --renderer gl_compatibility
python -m unittest tests.test_application_version -v
```

No production capture rerun or standalone export was performed for this small
shell-only state correction. Native source-viewer tests use generated SSC fixtures;
the unrelated job-failure retention check injects a diagnostic rather than running
an actual failing export. Other operating systems and long-session performance
were not tested. Passing automated checks are not owner acceptance.

## Owner verification

1. Open an invalid/broken `.ssc`; confirm the load error and actionable Details.
2. Without dismissing it, open a valid `.ssc`. Confirm the banner disappears and
   the lower-left status returns to the new capture's normal status.
3. Open another invalid file; confirm its error is shown again and the prior
   usable capture remains. Cancel the picker; the error should remain.
4. Open a valid file again; confirm automatic recovery. Independently retained
   job failures should remain available until acknowledged.

Stop for owner review; no merge, auto-merge, manual issue closure or board change.
