# Issue #226 File Locations review evidence

The [native Forward+ screenshot](file-locations.png) shows the new File Locations
dialog with no file picker or transient overlay covering its rows. It was
captured by `tools/validate_file_locations.py` from a 1440 × 900 desktop run.

Focused validation on a generated one-particle WVZ1 capture:

| Check | Result |
| --- | --- |
| File Locations, headless | 38 checks pass |
| File Locations, native Forward+ | 38 checks pass; screenshot retained |
| File Locations, native Compatibility | 38 checks pass; no cleanup diagnostics in final run |
| Existing Keyboard Shortcuts, headless | 272 checks pass, including fresh-process restart |
| Existing session logging, headless | 40 checks pass |
| Existing Video Export / Jobs status, native Forward+ | 317 checks pass; source hashes unchanged |
| Existing file-picker navigation, headless | 98 checks pass across eight processes |
| Application version | 2 unit tests pass; candidate `v0.1.0.43` |

The first native Compatibility runs passed all new assertions but emitted two
known Godot GL texture cleanup diagnostics after viewer teardown. A later
unchanged native run passed without them; the earlier logs remain in the local
test output. The wider native Wayland file-picker harness completed its first
four phases; `export_add` reported 18 passing checks but its process timed out
on shutdown, so the full native sequence is inconclusive. The same sequence
passed headlessly across eight processes.

The existing broad `validate_viewer_shell.py` run reached 668 checks with one
failing assertion: it expects exactly one `Play.pressed` connection. The
owner-merged session logger adds an observer connection on accepted `main`, so
that assertion predates this issue. Its full output is retained locally.
The new focused harness checks this issue's menu route and export controls.

The focused harness checks native `FileDialog.use_native_dialog` and drives its
selection signal. The owner should verify that each Browse button displays the
expected desktop picker and that a path selected through the desktop UI is
applied. No production-sized scientific capture or full render suite was run.
