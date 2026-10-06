# Issue #251 Jobs first-row clearance

Candidate build `v0.1.0.56` awaits owner review. The Jobs title and list now
share a vertical container with 32 logical pixels of separation measured from
the header's bottom edge. The first row's entire box begins below that edge;
the five rows, action widths, Cancel alignment, scrolling, close controls and
job ownership remain in place. The earlier [#237 evidence](../issue-237/README.md)
is retained as a historical review record.

## Native screenshots

- [Empty Jobs at 1440×900](jobs-idle-1440.png) and [1024×640](jobs-idle-1024.png): disabled Video export controls, focused Selections Open…, and a clear title-to-first-row gap.
- [Loaded Jobs at 1024×640](jobs-1024.png): the same spacing with a generated WVZ1 capture open.
- [Compact Jobs](jobs-compact.png): header stays above the list, the Cancel column clears the scrollbar, and later rows remain scrollable.
- [Active video export](jobs-active-video.png): a real worker enables Video export Cancel while the header and rows remain separated.

The screenshots were captured on Linux in native Forward+ mode. The capture
and export inputs are small generated fixtures, not production data.

## Validation

- Focused `test_jobs_layout.gd`: **179 checks passed** in Forward+ and **179 checks passed** in Compatibility. It checks the whole first row against the measured header at normal and compact sizes, every row's structure and action widths, disabled and enabled Video export controls, focus, reopening, footer fit and scrolling. The first Compatibility invocation recompiled a cached shader; the unchanged warm run had no warning.
- `python tools/validate_viewer_status.py --godot /home/Nozba/Codex/Wavez/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-251-status-forward --renderer forward_plus`: **324 checks passed** with unchanged source hashes. This directly exercises existing Jobs Open/Details/Cancel paths, active video and background lifecycle, focus/close paths, and loaded/empty dialog states. The runner classified two known encoder PID cleanup diagnostics; there were no other errors or warnings.
- `python -m unittest tests.test_application_version`: **2 passed**. `python tools/application_version.py --json` reported build **56**. `git diff --check` passed.

Physical pointer hover, alternate desktop scaling and extended sessions remain
for owner review. No packaged executable was built for this local layout change.
