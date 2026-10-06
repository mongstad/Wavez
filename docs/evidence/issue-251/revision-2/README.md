# Issue #251 owner review correction: first Open… focus ring

The owner's close-up showed that the first Open… button's focus outline was
clipped at the top of the scroll viewport. The first candidate separated the
header from the viewport by 32 px but left the first row flush with the
viewport edge. The theme draws its focus ring outside the button, so that
viewport clipped its top edge.

The revised layout uses 8 px between the measured header and viewport, and
starts the rows 16 px inside the viewport. This shortens the header area while
leaving room around the focused button. The first row is 24 px below the
header's bottom edge, and its top is at least 12 px inside the viewport in
the focused native checks. Build `v0.1.0.56` is unchanged for this PR revision.

## Native screenshots

- [First Open… focused during a real video export](jobs-active-video.png): full top focus outline and aligned row actions.
- [Empty Jobs at 1024×640](jobs-idle-1024.png): disabled Video export row and focused Selections Open….
- [Compact Jobs](jobs-compact.png): title, rows, footer and scrollbar remain usable.
- [Enabled Video export presentation state](jobs-preparing-video.png): first-row focus at 1024×640; this state is injected in the focused layout test and does not represent a running worker.

## Validation

- Focused `test_jobs_layout.gd`: **218 checks passed in Forward+** and **218 in Compatibility**. The revised checks measure the first row against both the header and viewport edge, including when the first Open… button is focused; they also cover empty, reopened, compact, enabled-video, alignment and scrollbar states. Native screenshots were inspected for the complete focus outline.
- Existing `tools/validate_viewer_status.py` in Forward+: **324 checks passed**, including a real background video export and Jobs Open/Details/Cancel paths. Generated WVZ1 source hashes were unchanged. Its runner classified two known encoder PID cleanup diagnostics; there were no other errors or warnings.
- `python -m unittest tests.test_application_version`: **2 passed**. `python tools/application_version.py --json` reported build **56**. `git diff --check` passed.

Physical pointer hover, alternate desktop scaling and extended sessions still
need owner review. No packaged executable was built for this layout revision.
