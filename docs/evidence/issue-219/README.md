# Issue #219 Jobs overview review evidence

Candidate build `v0.1.0.39` is pending owner review. The Jobs overview now shows one heading and the existing Open…, Details… and Cancel actions per category. The per-job detail string remains the source for Details…, live updates, and terminal diagnostics. A shared 8-pixel right inset keeps Cancel clear of a visible scrollbar. Issue #217 remains a separate Backlog item; its Project state was not changed.

## Native snapshots

- [Idle Jobs at 1440×900](jobs-idle.png): five compact rows without repeated status text.
- [Active video export](jobs-active-video.png): active Cancel and no inline frame progress.
- [Constrained-height Jobs with scrollbar](jobs-scrollbar.png): aligned action columns and visible right spacing.

## Focused validation

`python tools/validate_viewer_status.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-219-status-review --renderer gl_compatibility` passed 277 checks. It exercised live video progress in Details…, terminal and failure details, worker cancellation, all five row structures, category access, 1440×900 and 1024×640 fit, and a constrained-height scrollbar. Generated WVZ1 source hashes were unchanged. The native log had no unclassified errors or warnings.

`python -m unittest tests.test_application_version` passed 2 tests, and `python tools/application_version.py --json` reported build 39. `git diff --check` passed.

The Jobs presentation path is shared by both renderers, so Forward+ and packaging were not run for this local UI change. Physical hover, keyboard navigation, desktop scaling, and longer live sessions remain for owner review.
