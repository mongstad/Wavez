# Issue #323 / PR #324 — bounded Custom ranges

Follow-up to `bd90087`, implementing the owner's range-validation feedback and
confirmed general rule for including the final partial second. Accepted main is
`29037f6` / build 85; candidate **v0.1.0.86** remains unchanged through review.
The existing branch
`323-ux-video-show-human-readable-time-in-video-export-consistent-with-playback`
and PR #324 are retained. Previous
[whole-second evidence](../precision-refinement/README.md) and
[initial clock evidence](../README.md) remain historical checkpoints.

## Range behavior

Custom controls now enforce **0 ≤ Start ≤ End ≤ simulation duration** as edits
are committed, rather than accepting invalid settings until export starts.
Both native arrow buttons and keyboard Enter/Tab enforce source extent and the
opposite endpoint. Out-of-range edits select the exact valid boundary; an End
below fractional Start 30.0003 becomes exactly 30.0003. Equal exact endpoints
retain the one-frame still convention. Invalid text preserves the valid model.
Restored out-of-domain/inverted ranges are constrained by the exact range setter.

Controls, adjacent clocks and the visible **Exact range** use elapsed seconds
from the first source timestamp, matching playback's elapsed coordinate system.
Export settings retain original recorded float64 timestamps. Thus a source
spanning -1.125 to 3601.125 has elapsed bounds 0 to 3602.25; typing elapsed 30
selects recorded 28.875. Tooltips disclose exact elapsed and recorded seconds.
This mapping prevents negative controls without truncating negative/offset source
captures. Source payloads, sampling, worker/job algorithms and playback remain
[unchanged](checks/protected-files.json).

Whole-second display still uses nearest-second projection, capped at the final
whole second inside the simulation. **≈** and **Exact range** disclose any
fraction. Valid Full/Current/restored Custom endpoints are not rounded or
reconstructed from that projection on opening, refresh or unchanged focus/Enter.
Native arrow steps use a source-time anchor plus an integer step count, so
opposite steps restore the same float64 value even across a precision boundary.
A step reaching a bound selects that exact boundary.

The **remaining-fraction rule is general**, based on the capture duration:
explicitly typing End's final whole second, or stepping End into that second,
includes the remaining fraction through the exact final timestamp. It does not
pad beyond the simulation or change the exclusive-End sampling convention.
For 92.33 seconds, explicitly entered End **92** selects 92.33, displays
**≈01:32**, and shows exact **01:32.33**. For a subsecond capture, End **0** includes
its remaining fraction. An existing exact End 92 is preserved on reopen until
an explicit edit; restored ranges are never silently expanded. Tests also apply
this rule to 3602.25 seconds with a negative source origin and a high-precision
210.1234567790123-second duration with a positive source origin.

Start Export explicitly flushes native pending edits before creating its job;
this prevents a same-input-batch button press from reading an uncommitted draft.
One-second steps, no decimal places in controls, **1.0 ×** rate formatting,
frame-count/FPS duration, end exclusivity and rendering results are preserved.

## Validation

Godot 4.7.2, native Linux/NVIDIA RTX 3070 Ti, external FFmpeg/ffprobe. Each final
configuration exits cleanly with no ERROR/WARNING diagnostics:

| Configuration | Accepted-main checks | Candidate checks | Exact settings pairs | Rendered output |
| --- | ---: | ---: | ---: | --- |
| [Source Forward+](checks/range-general-source-forward/summary.json) | 59 | 227 | 42 | Three clips identical |
| [Source Compatibility](checks/range-general-source-compat/summary.json) | 59 | 227 | 42 | Three clips identical |
| [Package Forward+](checks/range-general-package-forward/summary.json) | 59 | 227 | 42 | Three clips identical |
| [Package Compatibility](checks/range-general-package-compat/summary.json) | 59 | 227 | 42 | Three clips identical |

Focused native tests cover negative/oversized values, both crossing directions,
fractional opposite endpoints, both arrow directions and fractional boundary
buckets, Enter/Tab/same-value edits, invalid text, unchanged reopen/focus,
source origins, subsecond and zero-duration captures, stills, arbitrary-duration
final fractions, pending-export draft submission, active/idle locks and compact
Light/Dark layouts. The 42 comparisons check complete settings, frame counts and
first/last samples for identical recorded intervals against accepted main. The
intentional elapsed-control mapping is checked separately from those comparisons.

Three actual 320×180, 4 FPS jobs compare every timing row, PNG pixel and decoded
MP4 RGB pixel against main in each configuration:

- `[0.125, 0.875)` at 0.75×: four samples, 0.125 / 0.3125 / 0.5 / 0.6875.
- `[0, 210)` at 420×: two samples, 0 / 105, excluding the end.
- `[91.875, 92.33)` at 1×: two samples, **91.875 / 92.125**. The frame after 92
  proves the final fraction is exported; every sample stays before 92.33.

FFprobe dimensions/FPS/counts and all six synthetic capture hashes also agree.
900- and 6,300-frame examples are checked numerically/visually, not rendered in
full. Two version tests, Python compilation, warm import and diff checks pass.
No captures, video binaries, packages or external runtimes are committed.

## Images and retained attempts

[Image hashes](checks/image-sha256.json) cover all four final configurations.
Each `images/range-general-*` folder retains ordinary/compact Light/Dark views,
whole and fractional ranges, arbitrary offset boundaries, subsecond/still bounds,
and `final-fraction-92.png` showing the actual remaining-fraction range/summary.

Early checks caught loss of the last timestamp bit after reversible steps across
32 seconds; anchored steps fixed it ([attempt](checks/attempt-float64-step.txt)).
A short-capture test sent Enter without focusing the field and activated Cancel;
the harness now focuses the field explicitly ([attempt](checks/attempt-short-focus.txt)).
Native Tab publishes same-value edited text after focus loss; deferred focus-loss
validation now commits it consistently ([attempt](checks/attempt-tab-flush.txt)).
The final-fraction image is taken after the UI's render refresh, so its clocks and
summary agree with the committed settings. Final runs pass these checks.

## Limits and reproduction

Packages use normal staged resources with a temporary review entry creating the
production viewer and dispatching job arguments to unchanged Main. Actual worker
render/encode execution is checked; the ordinary Start Export parent/child
lifecycle is not revalidated through that button. The focused audit verifies its
new pending-edit flush directly. The earlier mock dialog suite's missing viewer
API remains a known limitation, not a claimed passing suite. Physical input feel,
mixed-DPI/4K, other operating systems and long research captures remain owner
checks; synthetic native input is not physical acceptance.

Use the [initial baseline archive preparation](../README.md#reproduce-and-owner-review),
then run `tools/validate_video_time.py --godot /path/to/external/Godot --baseline
/path/to/imported/main --output /fresh/output --renderer forward_plus`. Repeat
with `gl_compatibility` and each renderer with `--package`. Native display/GPU
access, NumPy/Pillow, FFmpeg/ffprobe and Linux export templates are required.

## Final owner review

1. File → Export → Video → Custom. Try End below Start and Start above End using
   both arrows and typed values followed by Enter/Tab. Confirm the valid opposite
   endpoint is the limit, including fractional boundaries.
2. Enter negative and oversized values in both fields. Confirm zero and simulation
   duration are the limits; check a source with a nonzero/negative first timestamp.
3. Use any capture with a fractional duration. Enter End's last whole second and
   verify the remaining fraction appears in **Exact range**, with **≈** beside the
   clock. Export a short tail and verify the last frames include that fraction
   without any timestamp at/past the exclusive final boundary.
4. Reopen a valid fractional Custom selection without editing; confirm its exact
   range/count are unchanged. Check one-second steps, the 30–60 / 900-frame example,
   1.0× formatting, compact scrolling and both themes.

PR #324 remains open for final owner review. No merge, auto-merge, issue closure
or manual Project status transition is performed.
