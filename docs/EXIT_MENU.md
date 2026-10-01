# File → Exit (#153)

Pending owner review. Selected as the sole Ready issue on 2026-10-01, on the
owner-created `153-ux-add-exit-command-to-file-menu` branch. Baseline is accepted
main `f82a939` (PR #152, build 12); this candidate proposes `v0.1.0.13`.

Exit is the final File-menu command, below a separator, and remains enabled with
or without a capture. It calls `window_chrome.request_close()`, also used by the
window close button. That function retains the existing `SceneTree.quit()` call.
Normal `_exit_tree` cleanup still closes readers/preparation and requests graceful
cancellation of active export workers. The accepted close path has no extra
application-exit confirmation; this addition neither introduces one nor changes
individual job-cancellation confirmation. No teardown, worker or scientific code
is changed.

## Validation

On Linux/KDE Wayland, Godot 4.7.2 and NVIDIA RTX 3070 Ti:

- `validate_exit_menu.py`: six real process exits per renderer (windowed,
  maximized and fullscreen; each idle and with an active real export worker).
  Each process exits successfully through normal teardown. All three active
  workers per renderer acknowledge graceful cancellation. Exit placement,
  separator and availability are checked before activation. Capture hashes remain
  unchanged.
- `validate_viewer_shell.py`: 673 checks per renderer; menu hierarchy and existing
  scientific/UI behavior pass with unchanged fixture hashes.
- `validate_window_chrome.py`: 76 checks and 18 KWin stages per renderer.
- `python -m unittest tests.test_application_version`: two tests pass.
- Godot editor import and `git diff --check`: pass.

Results: **12 shutdown cases, 1,498 existing native regression checks and two
Python tests pass**, with zero assertion failures. The KWin harness emits its
existing `Gio.DBusConnection.register_object` deprecation warning and documented
libdecor GTK fallback. The first Compatibility chrome run passed its assertions
but failed the warning gate when Godot recompiled a cached shader; the unmodified
rerun passed. No new shutdown
warnings or forced process termination were introduced. Compact machine-readable
results are in `docs/evidence/issue-153/`.

Other operating systems and production-size workloads were not tested. No new
exit-warning behavior is claimed. Historical reports and evidence, including
#120, remain unchanged; current status and handbook reflect the accepted merge
and this candidate.

## Owner verification

Open File before loading a capture: check Exit appears last below the separator
and closes the viewer. Repeat with a capture and an active video export, checking
that the worker cancels cleanly. Compare with the window close button. Repeat
maximized and in Fullscreen (reveal the top bar), on Forward+ and Compatibility.
Stop for owner review; do not merge or enable auto-merge.
