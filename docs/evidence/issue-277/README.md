# Issue #277 — Stable elapsed clock focus

Candidate v0.1.0.64, pending owner review. #277 was the sole Ready item at
2026-10-06 preflight. Exact existing linked branch:
`277-ux-transport-preserve-elapsed-time-focus-border-color-after-seek-time-closes`.
It started clean at accepted main `ead0ebe09f6263ff38be993a1af1ad518f11da6d`,
including owner-merged #276 and #274. Local main, origin/main and linked branch
matched. Fetch/prune completed; the previous #275 branch was already absent.
No branch switching or historical acceptance-only edits were made.

## Cause and local fix

The elapsed Label's focus-enter callback supplies the accepted violet ring as
its `normal` style. Godot can draw Label's separate native `focus` style instead
after popup focus restoration. That slot previously fell back to a neutral ring.
The production style installer now explicitly supplies the existing violet
`focus()` resource to that slot on the elapsed Label only. The old mouse-focus
callbacks remain intact. No global focus color, focus-return callback, editor,
parsing, timing, typography, layout or duration-button style is changed.

Godot's [Label draw implementation](https://github.com/godotengine/godot/blob/master/scene/gui/label.cpp)
confirms the separate normal/focus paths. The installed runtime's behavior was
verified locally with pixels and native input, not inferred from master alone.

## Baseline and focused candidate results

The same new test harness ran first against unchanged accepted production code
(build 63). It returned 114 checks with 12 failures, all rendered-border checks
after Enter, Escape or outside-click dismissal at normal and compact widths.
Mouse focus initially showed 64 violet edge pixels and no neutral pixels; after
each dismissal it showed zero violet and 64 neutral pixels. Seek, cancel,
focus ownership, typography, layout and total/remaining checks passed. Baseline
failure logs/reports/screenshots are preserved under `baseline/`.

| Check | Result |
| --- | --- |
| Forward+ candidate native focus test | 114 checks, 0 failures, clean exit |
| Compatibility candidate native focus test | 114 checks, 0 failures, clean exit |
| Python application version metadata/CLI | 2 tests, OK; v0.1.0.64 = main build 63 + 1 |
| Whitespace | git diff --check passed |

Both candidate native logs contain no warnings/errors. Godot 4.7.2 ran on
Linux/X11, NVIDIA RTX 3070 Ti, with isolated XDG preferences. In each candidate
run all 16 focused samples had 64 violet edge pixels and zero neutral pixels.

`viewer/ui/shell/test_elapsed_focus.gd` samples rendered central top-edge pixels,
excluding glyphs/corners/adjacent controls, against the existing focus-ring token
with a small antialiasing tolerance. It verifies no neutral border appears.
Each renderer uses native double-click, Enter, Escape and outside clicks for
12 dismissal cycles: two repetitions of each path at 1440×900 and 1024×640.
Enter commits 00:02/00:04; cancellation retains the exact committed sample.
Focus returns to elapsed, Tab still visits timeline then duration, moving focus
clears the outline, and refocusing restores violet. Actual geometry, 64/104 px
transport heights, font resource/size, tooltip absence, total/remaining behavior
and duration state-style identities are checked too.

Selected screenshots show before/after dismissal and repeated compact cycles.
Visual review covered baseline violet-to-neutral drift and candidate desktop/
compact violet outlines, including Compatibility compact focus. The new harness
and its UID are committed. Synthetic fixtures, external runtime and isolated
preferences stay outside the repository.

Editor import completed with five pre-existing missing resize-script UID
warnings and no script errors (`baseline/import.txt`). Incidental generated
resize-script UIDs were removed; existing tracked UIDs are unchanged.

## Reproduce

Create a fresh output directory, then write its `scene.wvz` with the existing
`tests.g4.fixtures.scene` synthetic fixture helper. Use externally installed
Godot and isolated XDG data/config with normal native display access:

```sh
env -u WAYLAND_DISPLAY /path/to/godot --path viewer --rendering-method forward_plus --audio-driver Dummy --resolution 1440x900 --script ui/shell/test_elapsed_focus.gd -- /tmp/issue-277
```

Repeat with `gl_compatibility` and a separate output directory. Version check:
`python -m unittest tests.test_application_version`.

## Limits and owner verification

Only the focus/seek/neighboring transport boundary was tested. Full transport,
scientific, cache, camera, video and analysis suites were not rerun for this local
style override. Packaging, other OSes, Wayland, physical mixed-DPI/4K, alternate
scaling, physical input feel and long sessions were not tested.

1. Open a capture, click elapsed and note its violet outline. Double-click,
   enter a valid clock and press Enter; compare the restored outline and time.
2. Reopen, edit another clock and press Escape; compare the outline and confirm
   the committed time is retained. Reopen and dismiss by clicking outside.
3. Repeat each path several times. Tab to timeline/duration, then return to
   elapsed; check focused and unfocused states and unchanged duration styling.
4. Repeat at desktop and compact widths and preferred display scaling in each
   renderer. Check typography and spacing remain consistent and clock tooltips
   stay absent. Toggle total/remaining and confirm normal behavior.
5. Confirm About shows v0.1.0.64 and reconcile BUILD with accepted main before merge.
