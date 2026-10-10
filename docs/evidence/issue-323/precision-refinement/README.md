# Issue #323 / PR #324 — whole-second controls

Review refinement of commit `9b716a3`, responding to the
[owner's comment](https://github.com/mongstad/Wavez/pull/324#issuecomment-6096591112).
Accepted main remains `29037f6` / build 85. Candidate **v0.1.0.86** remains unchanged:
review commits do not consume another build. The existing issue-linked branch is
`323-ux-video-show-human-readable-time-in-video-export-consistent-with-playback`.
This checkpoint is pending final owner review. Earlier [clock evidence](../README.md)
remains historical and has not been rewritten.

## Mapping and explicit edits

Changing native SpinBox `step` also snaps its `value`; using that snapped value as
an export timestamp would silently alter a fractional Custom range. See the
[Godot Range step contract](https://docs.godotengine.org/en/4.7/classes/class_range.html#class-range-property-step).
The export-only SpinBox subclass therefore owns a separate float64 **timestamp**.
Its numeric value is a whole-second projection. Settings/summary read the exact
timestamp model, not that projection.

- Controls have step **1**, no decimal places and the **s** suffix. Adjacent clocks
  use whole `MM:SS` / `HH:MM:SS`; **1.0 ×** rate formatting is retained.
- The projection rounds to the nearest second, ties toward the later second.
  **≈** marks a fractional endpoint, and a visible **Exact range** line gives the
  actual interval. A separate tooltip gives exact decimal seconds. Signed clocks
  and subsecond ranges crossing a minute remain explicit.
- Opening/reopening, refreshing, Full/Current → Custom, unchanged Enter, and Tab
  focus changes do not normalize an endpoint. Existing ranges retain exact values.
- Arrow buttons add/subtract **one second from the exact selected endpoint**,
  preserving its fractional phase. Opposite steps restore the original timestamp.
- Explicit numeric keyboard edits choose an absolute whole-second endpoint,
  including retyping the already displayed number. Fractional numeric input is
  intentionally rounded by the native one-second control, also with ties toward
  the later second. Invalid input and unchanged fields preserve the prior model.
- Programmatic/restored ranges use `set_range_times(first, last)` to avoid the UI
  projection. The existing ±1e30 bounds still apply to Custom. Integration test
  fixtures now seed their exact ranges through this API, rather than assigning
  scientific times to the UI's integer `value`.

For `[30.0003, 60.0003)`, the controls show **30 s / 60 s**, clocks
**≈00:30 / ≈01:00**, and **Exact range: 00:30.0003 → 01:00.0003**. At 30 FPS/1×,
the summary is **Duration: 00:30 · 900 frames**, computed from the unchanged exact
interval. Retyping both controls as 30 and 60 deliberately changes the interval
to `[30, 60)`, removes the approximation markers/extra range line, and still gives
900 frames. This is intentional editing, not normalization on opening.

End exclusivity, stills, mode indices, source timestamps, frame calculations, job
serialization, worker rendering and processing-time presentation are unchanged.
[Protected files](checks/protected-files.json), including playback/clock code,
are byte-identical to the initial PR checkpoint.

## Native review images

Images capture production controls, including native keyboard focus, without
transient overlays. Both ordinary 700×650 and compact 560×360 dialogs are shown
inside a 1440×900 application. Compact settings retain scrolling; the exact range
stays visible in the fixed summary. The [image manifest](checks/image-sha256.json)
retains hashes.

| State | Source Forward+ | Packaged Compatibility |
| --- | --- | --- |
| Owner's 30–60 example | [source](images/refinement-source-forward/owner-30-60.png) | [package](images/refinement-package-compat/owner-30-60.png) |
| Fractional range preserved | [source](images/refinement-source-forward/fractional-preserved.png) | [package](images/refinement-package-compat/fractional-preserved.png) |
| Dark, ordinary | [source](images/refinement-source-forward/fractional-dark-700.png) | [package](images/refinement-package-compat/fractional-dark-700.png) |
| Light, ordinary | [source](images/refinement-source-forward/fractional-light-700.png) | [package](images/refinement-package-compat/fractional-light-700.png) |
| Dark, compact | [source](images/refinement-source-forward/fractional-dark-560.png) | [package](images/refinement-package-compat/fractional-dark-560.png) |
| Light, compact | [source](images/refinement-source-forward/fractional-light-560.png) | [package](images/refinement-package-compat/fractional-light-560.png) |
| Precise source endpoints | [source](images/refinement-source-forward/precise-endpoints.png) | [package](images/refinement-package-compat/precise-endpoints.png) |

Compatibility source and Forward+ package images are retained in their matching
`images/refinement-*` folders, including hour-plus and tiny Custom ranges.

## Validation and results

Godot 4.7.2, Linux/NVIDIA RTX 3070 Ti, external FFmpeg/ffprobe. The revised focused
audit runs the production viewer against an archived accepted main. Each final
run exited cleanly with no ERROR/WARNING diagnostics:

| Configuration | Main UI checks | Candidate UI checks | Exact settings comparisons | Actual output |
| --- | ---: | ---: | ---: | --- |
| [Source Forward+](checks/refinement-source-forward/summary.json) | 57 | 154 | 42 | Both jobs identical |
| [Source Compatibility](checks/refinement-source-compat/summary.json) | 57 | 154 | 42 | Both jobs identical |
| [Package Forward+](checks/refinement-package-forward-final/summary.json) | 57 | 154 | 42 | Both jobs identical |
| [Package Compatibility](checks/refinement-package-compat/summary.json) | 57 | 154 | 42 | Both jobs identical |

The matrix covers Full, Current, restored fractional Custom, whole-second keyboard
edits, stills; zero, signed/hour-plus and high-precision offset sources;
24/30/60 FPS and 0.5×/1×/2.5×. Complete settings, frame counts and first/last sample
times match main for the same exact interval. Native regressions additionally
cover both arrow directions on Start/End, keyboard/Enter/Tab, same-value edits,
explicit fractional rounding, unchanged reopen/focus, invalid input, bounds,
half-second steps across zero, subsecond ranges around 60 seconds, compact theme
layouts and active/idle control locks.

Two short 320×180, 4 FPS jobs retain every timing JSON row, PNG pixel and decoded
MP4 RGB pixel exactly versus main, in each configuration. `[0.125, 0.875)` at
0.75× gives four samples (0.125, 0.3125, 0.5, 0.6875). `[0, 210)` at 420× gives
two samples (0, 105), excluding the end. Probe dimensions/FPS/counts and fixture
hashes also agree. 900- and 6,300-frame examples are checked numerically and
visually; those full videos were not rendered. No scientific captures, binaries,
MP4s or third-party runtimes are committed.

Two version tests, Python compilation, warm source import and diff checks passed.
The standalone [native rounding probe](checks/native-rounding-probe.txt) confirms
that 0.5→1, -0.5→0, 30.5→31 and -30.5→-30 for the installed one-second control.

## Failures and limits

The first two source attempts caught failure to commit a whole endpoint when
the projected numeric value was unchanged. Their logs are retained as
`checks/attempt-same-value-enter*.txt`. Native Enter can bypass the underlying
LineEdit submission in that case; the control now also defers a commit until
after native Enter validation. The revised tests pass that exact path.

The initial Forward+ package headless import reported native dummy-renderer
`texture_2d_initialize` with a null texture; its [failed log](checks/attempt-package-forward-import.txt)
is retained. An unchanged fresh retry imported/exported and passed the complete
package audit. No product change was made in response to that import diagnostic.
Source import initially regenerated the same five incidental cached UID files;
the warm import was clean. Only the new export-control UID is retained.

The old mock dialog suite's missing viewer API remains as described in the
initial evidence; it is not claimed as passing. Its scientific fixtures and the
other affected integration fixtures were updated to use the exact range setter;
unrelated complete suites were not rerun. The focused production audit is the
validation for this change.

Packages use normal staging/resources plus a temporary review entry that creates
the production viewer and dispatches render-job arguments to unchanged Main.
The ordinary Start Export parent/child lifecycle was not revalidated through that
button. Physical input feel, mixed-DPI/4K, other OSes and long research captures
remain owner checks. Synthetic native input is not physical acceptance.

## Reproduction and final owner steps

Use the [initial archive preparation commands](../README.md#reproduce-and-owner-review),
then run `tools/validate_video_time.py` with `--baseline` pointing to imported
accepted main, an external `--godot` and a fresh `--output`. Run `--renderer
forward_plus` and `--renderer gl_compatibility`; repeat each with `--package`.
NumPy/Pillow, native GPU/display access, FFmpeg/ffprobe and Linux export templates
are required.

1. Open a capture covering 30–60 seconds. File → Export → Video → Custom; enter
   Start **30**, End **60**, press Enter, and choose 30 FPS / 1.0×. Confirm **30 s**,
   **60 s**, clocks **00:30 / 01:00**, and **Duration: 00:30 · 900 frames**.
2. Click each time control's up/down button. Verify one-second changes, correct
   counts, and restoration when reversed. Check keyboard entry/Tab and rate text.
3. Use a source with fractional first/last timestamps, or Current at a fractional
   recorded sample. Verify **≈** and the visible **Exact range**. Switch to Custom,
   close/reopen, focus/Enter without editing, and confirm the exact interval and
   frame count persist. Arrow steps must retain each fractional offset. Retyping
   a whole number intentionally chooses that whole endpoint.
4. Check both themes, compact scrolling and summary visibility. Export a short
   clip, inspect its frame count/timestamps and exclusive end, and review playback.

PR #324 remains open for owner acceptance and merge. No manual Project transition,
issue closure, merge or auto-merge is performed.
