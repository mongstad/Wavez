# Issue #237 Jobs window review evidence

Candidate build `v0.1.0.40` awaits owner review. The Jobs overview adopts the Video Export dialog's borderless surface, compact spacing, title, close icon, and button roles. Its five category rows and Open…, Details…, and Cancel callbacks remain attached to their existing controllers. The header, footer, window-close, and Escape paths dismiss Jobs without cancelling work and return focus to the transport Jobs button. Issue #217 remains separate Backlog work. Historical [issue #219 review evidence](../issue-219/README.md) is preserved as written.

## Native screenshots

- [Idle Jobs, 1440×900](jobs-idle-1440.png): focused first action, aligned compact rows, and shell chrome.
- [Idle Jobs, 1024×640](jobs-idle-1024.png): dialog fits the narrower viewer.
- [Constrained-height Jobs](jobs-scrollbar.png): vertical scroll and action-column clearance.
- [Active video export](jobs-active-video.png): Cancel is enabled while the video worker runs.

Screenshots came from the native Forward+ validation run on Linux. They are generated with synthetic WVZ1 sources, not production captures.

## Focused validation

- `python tools/validate_viewer_status.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-237-final-forward --renderer forward_plus`: 310 checks passed. The suite covers empty and active Jobs states, compact/narrow rows, scrollbar alignment, Open/Details/Cancel ownership, video worker cancellation, retained diagnostics, header/footer/window/Escape close paths, and focus return. Generated source hashes were unchanged.
- The same status command with `--output-dir /tmp/wavez-issue-237-verified-compat --renderer gl_compatibility`: 310 checks passed; source hashes unchanged.
- `python tools/validate_violet_style_slice.py --godot /home/Nozba/Desktop/Godot_v4.7.2-stable_linux.x86_64 --output-dir /tmp/wavez-issue-237-style-compat --renderer gl_compatibility`: 53 checks passed; confirms the Jobs surface is bound to the shared violet theme. Source unchanged.
- `python -m unittest tests.test_application_version`: 2 tests passed. `python tools/application_version.py --json` reported build 40. `git diff --check` passed.

The existing native display harness ran; a standalone packaged build was not made for this local Jobs presentation change. Physical pointer hover, desktop scaling, and longer live sessions remain for owner review.

## Owner correction: first-row clearance

The owner found that the first row's control area appeared to intrude into the title region in an empty Jobs view. The scroll area now starts 22 px below the header, and opening Jobs focuses the first enabled Open action instead of the disabled Video export action. Row button tooltips were removed because their labels already identify the actions and a hover popup can overlap the compact header. Job ownership and callbacks did not change.

- [Corrected empty Jobs](revision-2/jobs-empty.png): disabled Video export Open is unfocused; Selections Open is focused below the header.
- [Corrected 1024×640 Jobs](revision-2/jobs-idle-1024.png): all rows and the footer remain inside the dialog.
- [Corrected constrained-height Jobs](revision-2/jobs-scrollbar.png): the first row clears the header while vertical scrolling remains available.

Native `tools/validate_viewer_status.py` passed **322 checks in Forward+** and **322 checks in Compatibility** on the correction. The added checks cover first-row bounds and title clearance in empty and loaded views, enabled-action focus in the empty view, and absence of redundant row tooltips. Synthetic source hashes were unchanged. The earlier screenshots and results above remain the initial review record.
