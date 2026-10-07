# Issue #291 — Editable value focus

Candidate `v0.1.0.73`, pending owner review. Issue #291 was the first and only
Ready item when work began. The exact GitHub-linked branch was already checked
out and clean, based on accepted main
`3d45b33ec4b4f807a5c06290d4d9bb81acdc6ae3` (owner-merged PR #293).
Historical review-time reports remain unchanged.

The shared focus callback sets Godot's native `select_all_on_focus` flag from
the current LineEdit editability/selection policy, including internal SpinBox
editors. Native editing owns selection timing and subsequent caret behavior.
There are no new per-control handlers or polling loops. Validation, layout,
traversal order, scientific state and commit/cancellation callbacks are unchanged.
See [current behavior](../../EDITABLE_VALUE_FOCUS.md).

## Clean final validation

Linux desktop, externally installed Godot 4.7.2 (`ed1daf0bf`), NVIDIA RTX 3070 Ti.
Forward+ used Vulkan; Compatibility used OpenGL. All four GUI runs exited 0
with no native errors/warnings. Input was generated inside Godot using its
Window/Input APIs; these runs did not control physical input devices.

| Check | Forward+ | Compatibility | Retained result |
| --- | --- | --- | --- |
| Editable-value matrix | 187 checks, 0 failures | 187 checks, 0 failures | [Forward+](selection-forward/report.json), [Compatibility](selection-compatibility/report.json) |
| Existing focus-navigation regression | 1,496 checks, 0 failures | 1,496 checks, 0 failures | [Forward+](navigation-forward/report.json), [Compatibility](navigation-compatibility/report.json) |
| Application identity | 2 tests passed | Same source | [Version output](version.txt) |
| Editor import | Unchanged warm rerun clean, exit 0 | Renderer-independent import | [Warm log](import-warm.txt) |

The 17 matrix editors cover Simulation particle bounds; Performance; Source
probe, Selection, Diagnostics, Space time, Matched runs and Data Tools; Video
Export numeric and path editors; Seek; File Locations; orbit coordinates and
radius; volume color/opacity bounds and strength. Each receives real GUI focus
and Godot-generated key/mouse events: Tab/Shift+Tab, first-click selection and
immediate overwrite, second-click insertion, arrows and repeated focus requests.
Additional checks cover Shift+Arrow and drag substring replacement, Ctrl+A/C/V,
SpinBox Enter commit and arrow/wheel increments, preset/read-only fields, Seek
invalid Enter/Escape, File Locations draft cancellation, orbit validation and
dismissal, dialog restoration without repeated selection, and no focus polling.

Snapshots retain the committed sample, camera transform, scientific settings
and paused state across focus/draft interactions. Selection fixture hashes match
the unchanged external references in [source hashes](selection-source-hashes.json).
The existing regression reports independently retain unchanged SHA256 hashes
for four generated WVZ sources and check normal/compact traversal, dynamic
Simulation sections/categories, hidden/collapsed/pinned states, reparenting,
Fullscreen, dialogs/nested confirmations, shortcuts capture and restoration.
These are focused tests for the shared UI focus boundary, not a new scientific
format, rendering, playback or export validation claim.

## Visual review

Images were inspected after capture; no tooltips obscure the selected value.
The compact screenshots retain the existing scroll-container clipping/layout.
Dialog placeholder text `123.45` is temporary synthetic draft content.

- [Normal 1440 × 900 Simulation](simulation-1440.png): selected manual minimum.
- [Compact 1024 × 640 Simulation](simulation-1024.png): selected value in its visible scroll region.
- [Compact scrolled volume controls](volume-color-bound.png): selected plain numeric LineEdit.
- [File Locations](file-locations.png): selected editable destination, read-only FFmpeg display.
- [Scrolled Video Export](video-path.png): selected output path.
- [Orbit editor](orbit-coordinate.png): selected coordinate, established controls retained.
- [Seek](seek.png): selected recorded-time editor.

## Earlier failed/inconclusive attempts

These attempts are **not passing acceptance evidence**. Raw failed assertions
are retained in [diagnostic attempts](diagnostic-attempts.json).

| Attempt | Checks / failures | Disposition |
| --- | --- | --- |
| Initial matrix | 159 / 12 | Decorated SpinBox suffix expectations and an already-focused Seek field made assertions unreliable; corrected expectations/focus setup. |
| Second matrix | 158 / 7 | An abandoned unconditional SpinBox flag experiment failed the read-only expectation. Reverted to editability checked on focus entry; remaining synthetic input timing/delivery needed correction. |
| Third matrix | 158 / 71 | Global synthetic mouse routing used dialog-local coordinates incorrectly; inconclusive GUI coverage. |
| Python native-pointer experiment | 220 / 73 | Desktop input-device permission was unavailable/requested. Stopped the helper, told the owner permission could be denied, and abandoned physical-input testing. |
| State-aware matrix | 158 / 59 | Keyboard input reached the wrong Window; corrected routing. |
| Direct Window matrix | 158 / 16 | Missing Window-level Escape emission and buffered mouse-state handling. |
| Flushed matrix | 158 / 12 | Press/release in one synchronous frame ran ahead of deferred SpinBox editing; corrected frame timing, embedded-dialog coordinates and Window events. |

Earlier setup attempts also called a nonexistent test helper and cleanup property;
those stalled harness runs were stopped and corrected. A corrected 158-check
intermediate run passed before the final 187-check matrix added volume editors.
Final mouse events synchronize Godot button state, dispatch once to the owning
Window and allow a frame between press/release. The test-only event blocker
prevents duplicate routing; production code has no input interception change.

The first editor import reported five missing UID sidecars recreated from the
existing cache ([initial import](import.txt)). The unchanged warm import was
clean. Those unrelated generated sidecars were removed from the working tree;
no tracked UID changed and no new production script was added.

## Reproduction

From the repository root, generate fresh tiny fixtures outside Git, copy the
retained temporary [review script](selection-review.gd.txt) to a `.gd` path,
then run externally installed Godot. No Python pointer/input helper is required.

```sh
python - <<'PY'
from pathlib import Path
from tests.g4.fixtures import scene
from tools.validate_simulation_panel import fixture
import shutil
out = Path('/tmp/wavez-291-review')
out.mkdir(exist_ok=False)
scene(out / 'scene.wvz')
fixture(out / 'mixed.wvz', ['particles', 'volume', 'mesh'])
shutil.copyfile('docs/evidence/issue-291/selection-review.gd.txt', '/tmp/wavez-291-review.gd')
PY
env -u WAYLAND_DISPLAY XDG_DATA_HOME=/tmp/wavez-291-review/profile/data XDG_CONFIG_HOME=/tmp/wavez-291-review/profile/config /path/to/godot --path viewer --display-driver x11 --rendering-method forward_plus --audio-driver Dummy --resolution 1440x900 --script /tmp/wavez-291-review.gd -- /tmp/wavez-291-review
env -u WAYLAND_DISPLAY python tools/validate_focus_navigation.py --godot /path/to/godot --output-dir /tmp/wavez-291-navigation --renderer forward_plus
python -m unittest tests.test_application_version -v
```

For Compatibility, use fresh output/profile paths and `gl_compatibility` for
both runners. Fixtures, runtimes, profiles and caches are not committed.

## Limits and owner verification

Packaged Linux, OS-native picker widgets, physical keyboard/mouse input,
mixed-DPI/4K and sustained sessions were not validated. The initial Python
pointer experiment does not prove desktop pointer behavior. No full unrelated
scientific, camera, playback or video-export suite was run for this selection
change. Owner acceptance remains pending.

1. Open a capture. Click once into a Simulation numeric field, type a replacement
   immediately, and use its existing commit action. Tab/Shift+Tab into another
   numeric field and confirm the same selection. Repeat with a plain field
   color/opacity bound and a mesh numeric value when available.
2. Click the focused value again, place the caret near a decimal, then edit only
   a substring using arrows, Shift+Arrow and mouse dragging. Confirm focus
   recovery does not repeatedly select all; check Ctrl+A/C/V.
3. Check Performance/Tools, Video Export custom range/resolution and output
   path, Seek, File Locations and orbit coordinates/radius. Close a dialog
   opened from an editor and confirm restored focus selects once. Check at
   normal and compact sizes after scrolling to a lower editor.
4. Use SpinBox up/down arrows and wheel, and a nearby slider. Confirm their
   established increments/adjustments; read-only presets and FFmpeg display
   retain normal read-only behavior.
5. Try valid and invalid Enter submissions. Cancel Seek and File Locations
   drafts, and dismiss orbit changes. Confirm the established validation and
   Apply/Cancel rules and unchanged camera/playback until an intended commit.
