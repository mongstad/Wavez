# Owner-review refinement: passive time precision

Pending owner review of PR #47 / #42. Displayed time and Requested time now use
five fixed decimal places, matching the existing HUD. Tooltips keep exact float64
text. Seek Target, internal clocks, persisted state and controller behavior are
unchanged. Original review evidence is preserved.

Focused native validation: **62 checks passed on Forward+ and 62 on Compatibility**;
zero failures, unchanged synthetic source hashes. Reports: [Forward+](forward.json),
[Compatibility](compatibility.json). Tests cover rounded displayed time, requested
time during a real worker hold, trailing zeros, exact tooltips, unrounded controller
values, and the existing exact editor, seek, buffering and recipe synchronization
checks. Git whitespace validation passed.

Runs used `tools/validate_viewer_transport.py`, Godot 4.7.2, and output directories
`results/issue-42-precision-forward` / `results/issue-42-precision-compatibility`.
No failed final checks. Broader scientific/performance/video suites and real-capture
replays were not rerun for this label-only revision.

Manual review: seek to a time with more than five decimal places. Confirm the
passive label rounds to five places, its tooltip retains the exact value, and
reopening Seek retains the full value. During buffering, Requested time must use
the same five-place format while Displayed time remains the committed clock.
