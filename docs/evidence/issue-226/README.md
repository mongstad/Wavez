# Issue #226 File Locations review evidence

The [normal state](file-locations.png) shows the FFmpeg focus border below the
title bar. The [validation-error state](file-locations-error.png) shows every
location row and the error notice without a vertical scrollbar. Both native
Forward+ screenshots were captured by `tools/validate_file_locations.py` from
a 1440 × 900 desktop run with no picker covering the dialog.

Focused validation on a generated one-particle WVZ1 capture:

| Check | Result |
| --- | --- |
| File Locations, headless, Save Image follow-up | 50 checks pass with a test-only PNG writer |
| File Locations, native Forward+, before Save Image follow-up | 42 checks pass; normal and error screenshots retained |
| File Locations, native Compatibility, initial PR | 38 checks pass; no cleanup diagnostics in final initial run |
| File Locations layout follow-up, native Compatibility | Inconclusive: three runs timed out before a harness report |
| Existing Keyboard Shortcuts, headless | 272 checks pass, including fresh-process restart |
| Existing session logging, headless | 40 checks pass |
| Existing Video Export / Jobs status, native Forward+ | 317 checks pass; source hashes unchanged |
| Existing file-picker navigation, headless | 98 checks pass across eight processes |
| Application version | 2 unit tests pass; candidate `v0.1.0.43` |

The first native Compatibility runs passed all new assertions but emitted two
known Godot GL texture cleanup diagnostics after viewer teardown. A later
unchanged native run passed without them; the earlier logs remain in the local
test output. For the layout follow-up, three native Compatibility attempts
timed out after 120 seconds before writing a report, including one attempt
with Wayland selected directly. They provide no result for the revised layout.
The 42-check headless and Forward+ layout runs cover the minimum height,
visible FFmpeg focus border, and absence of a vertical scrollbar in both the
normal and validation-error states. The Save Image follow-up's headless run
checks direct use of the configured directory, an unavailable preference,
picker Cancel, and session-only folder reuse. Its tiny test PNG keeps path
routing independent of GPU screenshot availability; the owner will verify a
real screen capture. The wider native Wayland file-picker harness
completed its first four phases; `export_add` reported 18 passing checks but
its process timed out on shutdown, so the full native sequence is inconclusive.
The same sequence passed headlessly across eight processes.

The existing broad `validate_viewer_shell.py` run reached 668 checks with one
failing assertion: it expects exactly one `Play.pressed` connection. The
owner-merged session logger adds an observer connection on accepted `main`, so
that assertion predates this issue. Its full output is retained locally.
The new focused harness checks this issue's menu route and export controls.

The focused harness checks native `FileDialog.use_native_dialog` and drives its
selection signal. The owner should verify that each Browse button displays the
expected desktop picker and that a path selected through the desktop UI is
applied. No production-sized scientific capture or full render suite was run.
