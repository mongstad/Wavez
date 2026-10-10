# Issue #325 — dialog action audit and review evidence

Candidate **v0.1.0.87**, from accepted main
`896e63ea470c07b2b32bddc4c2ea6160c025b2e5` (PR #327).
The exact issue-linked branch is
`325-ux-dialog-ensure-dialog-action-buttons-look-clickable-when-unfocused`.
Owner visual review is pending.

The active Video Export dialog's “Run in background” action used SecondaryButton,
whose borderless normal surface matched its dialog body. Default Button actions
in other owned dialogs had transparent normal surfaces. The two opt-in dialog
roles use the existing `surface.2` fill and `border.control` one-pixel outline.
Only their normal style changes. The original action roles supply every other
state, font, color, corner, margin and focus metric. The existing focus ring
now overlays the new normal underlay when focused without hover; its outline
and expansion are unchanged. No orange annotation is added to the application.

## Inspected dialogs and changes

The production audit opened all 23 Tools host routes, both Video Export states,
Source/job Details, Jobs, About/licenses, File Locations, Keyboard Shortcuts,
export cancellation and active-job exit confirmation in both themes and sizes.
The machine inventory records 180 neutral action instances per theme/size,
including repeated/shared and hidden actions; these are not 180 unique controls.
AcceptDialog's internal actions are inspected explicitly. Existing hidden native
OK buttons in custom Details/Jobs remain hidden. Neutral buttons in hidden Tools
pages receive the same role, so they are recognizable when that page is selected.

| Dialog / route | Neutral actions changed |
| --- | --- |
| Tools → Bookmarks | Save time and camera bookmark, Go to bookmark, Use bookmark as manual offset, Delete bookmark, Time mapping, Close |
| Tools → Camera | Close |
| Tools → Clipping | Close |
| Tools → Compare | Use current series as left, Use current series as right, Clear left and right, Common schedule settings, Add current series to shared plot, Clear shared plot, Results, Close |
| Tools → Data | Close |
| Tools → Derive range | Freeze symmetric, Freeze percentile, Reset color, Reset opacity, Freeze, Cancel, Close |
| Tools → Diagnostics | Choose CSV, Close |
| Tools → Geometry | Load override, Clear override, Close |
| Tools → Global effects | Close |
| Tools → Image | Close |
| Tools → Isosurface | Extract, Remove, Close |
| Tools → Load analysis | Close |
| Tools → Mapping | Close |
| Tools → Matched runs | Left recipe…, Right recipe…, Render, Cancel, Close |
| Tools → Performance | Clear decoded cache, Close |
| Tools → Period | Advanced • Sampling assumptions, Results, Edit range, Close |
| Tools → Results | Remove result, Show plot, First data page, Next data page, Recompute, Close |
| Tools → Save analysis | Close |
| Tools → Selection | Rename selection, Duplicate selection, Delete selection, Toggle highlight, Select generated surface, Save current members as cohort, Group selected entries, Rename group, Delete group, Save group union, Save group intersection, Use current capture, Cancel, Close |
| Tools → Slice | Close |
| Tools → Source probe | Probe, Close |
| Tools → Space time | Results, Use full layer range, Plot, Close |
| Tools → Temporal | Results, Use full layer range, Cancel, Close |
| About / licenses | Close, Licenses and notices, Back to About |
| Cancel video export | No |
| Source / job details | OK, Acknowledge failures, Close |
| Exit with active jobs | Cancel |
| Jobs | OK, Open…, Details…, Cancel, Close |
| File Locations | Browse…, Reset Defaults, Cancel |
| Keyboard Shortcuts | Binding capture buttons, Clear, Reset Defaults, Cancel |
| Video Export (idle and active) | Browse…, Run in background, Cancel |

Primary/destructive actions (including Start Export, Cancel export, Yes, Exit
WAVEZ, Apply and the Tools primary footer action), selected shortcut capture,
header X controls, links, selectors and boolean controls retain their roles.
The inline orbit editor is a panel, and Seek belongs to transport; both are
outside this dialog issue. Main bar, dock/category and transport button contracts
are compared against the accepted archive. Native filesystem pickers and their
Godot fallback are excluded from the opt-in helper and remain unchanged. No
callbacks, actions, content, tooltips, dismissal paths or export calculations
are changed. See [current contract](../../DIALOG_ACTIONS.md).

## Before and after

These unobstructed Forward+ captures use a small synthetic WVZ1 scene and the
production preparation-state presentation. The elapsed status naturally advances;
these images are not evidence of a long research export. Root sizes are
1440×900 / 1024×640, with Video dialogs at 700×650 / 560×360 respectively.
Each normal target was asserted unfocused and unhovered before capture.

| Export state | Accepted main | Candidate |
| --- | --- | --- |
| Dark, normal | [Before](before/dark-1440-video-normal.png) | [After](after/dark-1440-video-normal.png) |
| Dark, compact | [Before](before/dark-1024-video-normal.png) | [After](after/dark-1024-video-normal.png) |
| Light, normal | [Before](before/light-1440-video-normal.png) | [After](after/light-1440-video-normal.png) |
| Light, compact | [Before](before/light-1024-video-normal.png) | [After](after/light-1024-video-normal.png) |

Representative audit comparisons (normal / compact):

| Dialog | Dark before → after | Light before → after |
| --- | --- | --- |
| jobs | [Before](before/dark-1440-jobs.png) → [After](after/dark-1440-jobs.png) / [Before](before/dark-1024-jobs.png) → [After](after/dark-1024-jobs.png) | [Before](before/light-1440-jobs.png) → [After](after/light-1440-jobs.png) / [Before](before/light-1024-jobs.png) → [After](after/light-1024-jobs.png) |
| mapping | [Before](before/dark-1440-mapping.png) → [After](after/dark-1440-mapping.png) / [Before](before/dark-1024-mapping.png) → [After](after/dark-1024-mapping.png) | [Before](before/light-1440-mapping.png) → [After](after/light-1440-mapping.png) / [Before](before/light-1024-mapping.png) → [After](after/light-1024-mapping.png) |
| locations | [Before](before/dark-1440-locations.png) → [After](after/dark-1440-locations.png) / [Before](before/dark-1024-locations.png) → [After](after/dark-1024-locations.png) | [Before](before/light-1440-locations.png) → [After](after/light-1440-locations.png) / [Before](before/light-1024-locations.png) → [After](after/light-1024-locations.png) |
| shortcuts | [Before](before/dark-1440-shortcuts.png) → [After](after/dark-1440-shortcuts.png) / [Before](before/dark-1024-shortcuts.png) → [After](after/dark-1024-shortcuts.png) | [Before](before/light-1440-shortcuts.png) → [After](after/light-1440-shortcuts.png) / [Before](before/light-1024-shortcuts.png) → [After](after/light-1024-shortcuts.png) |
| about | [Before](before/dark-1440-about.png) → [After](after/dark-1440-about.png) / [Before](before/dark-1024-about.png) → [After](after/dark-1024-about.png) | [Before](before/light-1440-about.png) → [After](after/light-1440-about.png) / [Before](before/light-1024-about.png) → [After](after/light-1024-about.png) |
| cancel-export | [Before](before/dark-1440-cancel-export.png) → [After](after/dark-1440-cancel-export.png) / [Before](before/dark-1024-cancel-export.png) → [After](after/dark-1024-cancel-export.png) | [Before](before/light-1440-cancel-export.png) → [After](after/light-1440-cancel-export.png) / [Before](before/light-1024-cancel-export.png) → [After](after/light-1024-cancel-export.png) |

Target state comparisons preserve the existing hover, pressed and disabled pixels
exactly. The focus comparison checks the existing expanded ring outside the
button bounds; the normal underlay inside those bounds intentionally changes.

| State | Dark before → after | Light before → after |
| --- | --- | --- |
| hover | [Before](before/dark-1440-video-hover-target.png) → [After](after/dark-1440-video-hover-target.png) | [Before](before/light-1440-video-hover-target.png) → [After](after/light-1440-video-hover-target.png) |
| pressed | [Before](before/dark-1440-video-pressed-target.png) → [After](after/dark-1440-video-pressed-target.png) | [Before](before/light-1440-video-pressed-target.png) → [After](after/light-1440-video-pressed-target.png) |
| focus | [Before](before/dark-1440-video-focus-target.png) → [After](after/dark-1440-video-focus-target.png) | [Before](before/light-1440-video-focus-target.png) → [After](after/light-1440-video-focus-target.png) |
| disabled | [Before](before/dark-1440-video-disabled-target.png) → [After](after/dark-1440-video-disabled-target.png) | [Before](before/light-1440-video-disabled-target.png) → [After](after/light-1440-video-disabled-target.png) |

## Validation

Godot **4.7.2**, Linux desktop, NVIDIA GeForce RTX 3070 Ti. Tests run with isolated
application profiles. External Godot, export templates, FFmpeg and Python remain
outside the repository. The accepted archive is imported before comparisons.
Each mode checks 978 paired action contracts across Dark/Light and normal/compact
sizes: visible sizes, all minimum sizes, focus paths, availability, existing
tooltips, fonts/ink and all six style states. Only 720 normal-style records change;
the other 5,148 style-state records match exactly. Hidden controls' stale allocated
sizes are excluded from visible-layout comparisons; their minimum sizes, other
properties and styles are still compared. The first exploratory harness had
incorrect embedded input coordinates; the retained passing runs route embedded
mouse input through the parent viewport.

Real injected hover/press/release and keyboard Tab/Shift-Tab/Enter exercise
Run in background and preserve the active preparation record. Cancel/Escape,
Jobs Close/focus return, license navigation, discarded preference/shortcut drafts
and selected shortcut capture are exercised through production owners.
Each mode compares 12 hover/pressed/disabled target images and four focus-ring
images with identical pixels, and verifies unchanged fixture bytes.

| Configuration | Baseline / candidate checks | Evidence |
| --- | ---: | --- |
| Source Forward+ | 313 / 2,473 | [Summary](source-forward/summary.json), [baseline log](source-forward/before-run.txt), [candidate log](source-forward/after-run.txt) |
| Source Compatibility | 313 / 2,473 | [Summary](source-compatibility/summary.json), [baseline log](source-compatibility/before-run.txt), [candidate log](source-compatibility/after-run.txt) |
| Linux PCK Forward+ | 313 / 2,473 | [Summary](package-forward/summary.json), [baseline log](package-forward/before-run.txt), [candidate log](package-forward/after-run.txt) |
| Linux PCK Compatibility | 313 / 2,473 | [Summary](package-compatibility/summary.json), [baseline log](package-compatibility/before-run.txt), [candidate log](package-compatibility/after-run.txt) |

All four runs exit normally without runtime errors or warnings. The normal owner
package separately imports/exports cleanly: [build metadata and artifact hashes](owner-package-build.json),
[import](owner-package-import.txt), [export](owner-package-export.txt).
The canonical version tests pass **2 tests**, and the CLI reports `v0.1.0.87`.

The additional existing export/job lifecycle suite is **not a clean pass**:
accepted main and candidate source Forward+ each complete **324 checks: 322 pass,
two fail** at the old expectation that loaded Jobs initially focuses Video
export's Open action. The accepted runtime instead retains focus on the header X;
[baseline](lifecycle/accepted-main-report.json) and
[candidate](lifecycle/candidate-source-report.json) show exactly the same failures.
The disposable Linux Compatibility lifecycle package has the same
[322 passes / two failures](lifecycle/candidate-package-report.json). No focus
behavior is changed to satisfy that old assertion. Runtime logs remain available
for [main](lifecycle/accepted-main-run.txt),
[source](lifecycle/candidate-source-run.txt) and
[package](lifecycle/candidate-package-run.txt).

The other lifecycle checks exercise real renderer/FFmpeg processes, background
completion, reopening, locked settings, retained Details, preparation/rendering/
encoding cancellation and failure recovery. All three parent-close scenarios
[acknowledge cancellation](lifecycle/parent-close-comparison.json). Two completed
source Forward+ exports have [identical decoded MP4 pixels, dimensions, frame
counts and frame rates](lifecycle/decoded-output-comparison.json) on main and
candidate.

The legacy packaged runner's `--script` option is ignored by the release template,
so that attempt opened the normal app and timed out without running tests. The
successful lifecycle execution uses a disposable validation scene instead:
[build recipe](lifecycle/build-status-package.py.txt),
[entry dispatch](lifecycle/package-entry.gd.txt),
[clean import](lifecycle/package-import.txt), [clean export](lifecycle/package-export.txt).
Render-job arguments route to the unchanged production `Main.tscn`. One earlier
scratch import emitted a dummy-renderer texture initialization diagnostic; an
unchanged rebuild imported/exported cleanly. These are validation harness limits,
not changes to the normal owner package or production exporter architecture.

Reproduce the focused audit from this checkout with the accepted archive and an
external Godot executable:

```sh
git archive 896e63ea470c07b2b32bddc4c2ea6160c025b2e5 -o /tmp/wavez-main.tar
mkdir -p /tmp/wavez-main
tar -xf /tmp/wavez-main.tar -C /tmp/wavez-main
/path/to/godot --headless --path /tmp/wavez-main/viewer --editor --import
python tools/validate_dialog_actions.py --godot /path/to/godot --baseline /tmp/wavez-main --output /tmp/dialog-forward --renderer forward_plus
python tools/validate_dialog_actions.py --godot /path/to/godot --baseline /tmp/wavez-main --output /tmp/dialog-compatibility --renderer gl_compatibility
python tools/validate_dialog_actions.py --godot /path/to/godot --baseline /tmp/wavez-main --output /tmp/dialog-package-forward --renderer forward_plus --package
python tools/validate_dialog_actions.py --godot /path/to/godot --baseline /tmp/wavez-main --output /tmp/dialog-package-compatibility --renderer gl_compatibility --package
python -m unittest tests.test_application_version -q
```

## Limits and owner review

Synthetic desktop/short-export checks do not replace physical owner review of
real research captures, long exports, assistive technology, 4K/mixed-DPI displays
or other operating systems/display backends. Native filesystem picker appearance
belongs to the desktop. Historical dialog/theme/export reports are untouched.
The local normal Linux review build is
`/tmp/wavez-325-review/owner-package/WAVEZ.x86_64` with its adjacent `WAVEZ.pck`;
this is a local review artifact, not a release.

1. Launch that build and confirm Help → About shows **v0.1.0.87**. In Dark and
   Light, open Video Export at normal and compact window sizes. Start an export
   from a disposable capture/output. Move the pointer away and focus another
   control: Run in background should have a visible neutral surface and border.
2. Hover, press and Tab/Shift-Tab through the actions. Check the existing focus
   ring and disabled appearance. Run in background should hide the dialog while
   export continues; Jobs → Open should return to its progress. Cancel export →
   No/Escape should preserve the job; Yes should use the existing cancellation.
3. Inspect Jobs, Source/job Details, About/licenses, File Locations, Keyboard
   Shortcuts and representative Tools dialogs (Mapping, Diagnostics, Image,
   Performance and Selection pages) in both themes/sizes. Judge neutral actions'
   clickability. Exercise Close/X/Escape and draft Cancel; verify selected key
   capture, Apply, primary/destructive actions and the excluded panels/transport.
4. With an active job, inspect Exit's Cancel action and dismiss it without exiting.
   Review the known initial Jobs-focus expectation mismatch above. Recheck main's
   version before merging if another PR has landed meanwhile.

Stop for owner review; final acceptance and merge belong to the owner.
