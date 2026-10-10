# Issue #314 — shared dialog close presentation

Candidate **v0.1.0.82** awaits owner review. Baseline is accepted `main`
`eb7b60bf57d1ebf2a6aa3e101e31f746216d8a8d` (owner-merged PR #315).
Issue #314 was the only Ready item on Wavez Development when implementation began;
its existing GitHub-linked branch was checked out, clean and equal to `main`.
PR #312's cool-gray Light palette and #315's shortcut-label change were present.
Remote references were pruned; no completed previous local issue branch remained.

## Diagnosis and change

Accepted-main Global effects already used a 32 × 32 action and the shell's
16 × 16 glyph. Its initial keyboard focus drew the generic input ring four pixels
outside each edge, producing the apparent 40 × 40 outlined X in the owner example.
The fix contains the ring in the shared 32 × 32 close area, preserving keyboard
focus and its visible two-pixel semantic ring. The same treatment applies to the
shell X, so keyboard-focused shell/dialog close controls remain identical.
Other inputs keep their existing expanding focus rings.

All Tools-host forms (including Global effects), Details, Jobs, Video, About,
Keyboard Shortcuts, File Locations and the orbit editor use the shared close
presentation and hover motion. Details/Jobs use the shell constructor; the early
Tools/Video controls retain their existing construction and callbacks but consume
its shared styling. The orbit editor replaces its text × with the shell glyph.
No dialog placement/sizing, title, content, bottom action or dismissal logic changed.

## Evidence

The full viewport images include the shell close reference. Before images come
from an archived copy of accepted `main`, imported before running the identical
harness; the implementation checkout was never switched. After images are native
Forward+ on KDE Wayland / RTX 3070 Ti, Godot 4.7.2.

| State | Before | After |
| --- | --- | --- |
| Global effects, Dark, 1440 × 900, initial X focus | [Before](before/global-dark-1440.png) | [After](after/global-dark-1440.png) |
| Global effects, Light, 1440 × 900, initial X focus | [Before](before/global-light-1440.png) | [After](after/global-light-1440.png) |
| Global effects, Dark, 970 × 600 | [Before](before/global-dark-970.png) | [After](after/global-dark-970.png) |
| Global effects, Light, 970 × 600 | [Before](before/global-light-970.png) | [After](after/global-light-970.png) |
| Orbit editor, Dark | [Before](before/orbit-dark-1440.png) | [After](after/orbit-dark-1440.png) |
| Orbit editor, Light | [Before](before/orbit-light-1440.png) | [After](after/orbit-light-1440.png) |

Interaction evidence: [Dark hover](after/global-dark-1440-hover.png),
[Dark pressed](after/global-dark-1440-pressed.png),
[Light hover](after/global-light-1440-hover.png),
[Light pressed](after/global-light-1440-pressed.png).
Simulated 3840 × 2160 at 2× scaling: [Dark](after/global-dark-3840-scale2.png),
[Light](after/global-light-3840-scale2.png). These are not physical-display approval.
Compact scrolled Performance: [Dark](after/performance-scrolled-dark-970.png),
[Light](after/performance-scrolled-light-970.png).
Other affected headers: [Details](after/details-light-1440.png),
[About](after/about-light-1440.png), [Jobs](after/jobs-light-1440.png),
[Video](after/video-light-1440.png), [Shortcuts](after/shortcuts-light-1440.png),
[File Locations](after/locations-light-1440.png).

## Validation

The focused runner is `tools/validate_dialog_close.py`, backed by
`viewer/ui/shell/test_dialog_close.gd`. It opens representative shared hosts and
all independently constructed X controls in Dark/Light at 1440 × 900 and 970 × 600,
plus Global effects at simulated 3840 × 2160 / 2×. Checks cover shell-equivalent
styles/ink/glyph/metrics, contained visible focus, native hover and mouse press/release,
forward/reverse Tab order, click/Escape/bottom Close/native-close dismissal,
initiator restoration, orbit cancellation restoring the camera, and unchanged
Tools scientific presentation. Fixture bytes are hashed before/after each run.

| Run | Result |
| --- | --- |
| Accepted-main native baseline | 87 checks, 0 failures; 42 layout/focus states recorded |
| Source headless | 755 checks, 0 failures |
| Source Forward+ | 759 checks, 0 failures; 42 unchanged layout/content/initial-focus states |
| Source Compatibility | 759 checks, 0 failures; 42 unchanged layout/content/initial-focus states |
| Linux release review package Compatibility | 759 checks, 0 failures; 42 unchanged layout/content/initial-focus states |
| Same review package Forward+ | 759 checks, 0 failures; 42 unchanged layout/content/initial-focus states |
| Python application-version tests | 2 tests, OK |
| Python compilation and git diff whitespace | Passed |

The geometry comparison permits only the About candidate build text and the orbit
close glyph change. All recorded visible control positions/sizes and initial
focus paths match accepted main. Package export/import passed; the package uses
an isolated review entry scene with the production resources, launched without
a source-project path. External Godot templates/runtime are retained only outside
the repository. Baseline and source Forward+ layout reports, plus per-run summaries and logs,
are under [checks](checks/).

Initial attempts are preserved separately: headless synthetic pointer targeting
failed (wrong viewport coordinates); a fresh archived baseline failed to preload
unimported assets and was stopped; sandboxed editor import failed to create its
local socket. The harness now imports fresh sources, routes embedded pointer events
through the parent viewport, and uses signal dismissal in headless mode. Corrected
native baseline and candidate runs completed cleanly. These initial attempts are
not counted as passing evidence.

This validation scope matches a presentation-only close-control change: affected
headers, direct input/dismissal/focus paths, renderer boundaries and package
resources. Unrelated playback, scientific-format, jobs/export-worker, camera
navigation and full application regression suites were not run.

## Limits and owner checks

Physical KDE/4K feel, mixed-DPI transitions, real keyboard/mouse comfort and
platforms other than Linux remain unverified. Automated 4K/scaling is simulated.
No new export-worker or active-job lifecycle validation was run; their callbacks
and architecture were not changed. Draft-edit persistence is an owner check;
the automated tests invoke the existing dismissal paths and check visibility,
focus and the orbit camera restore without saving preference edits.

Follow the exact [owner verification steps](../../DIALOG_CLOSE_CONTROLS.md#owner-verification)
before acceptance. Historical reports/evidence from earlier issues were preserved
as written. No owner acceptance, merge, auto-merge, issue closure or Project transition
is claimed.
