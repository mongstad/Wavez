# Issue #259: grouped Keyboard Shortcuts

Candidate build `v0.1.0.59` renders one shared titled group for each category in
the shortcut catalog. Rows retain catalog order inside Navigation, Playback,
File, Tools and Interface. The groups scroll above the existing fixed footer.
Binding dispatch, defaults and storage are unchanged; the #255 tooltip-free
dialog behavior is retained.

## Focused validation

- [Headless shortcut report](headless-validation.json): **346 checks passed**
  across initial and fresh-process runs. This includes every action's capture,
  conflict handling, Clear, Apply, Cancel, Reset Defaults, focus, scrolling,
  persistence and source-fixture hash preservation. The added assertions check
  category membership/order and conflict transfer from Navigation to File.
- [Native Forward+ group report](native-group-validation.json): **276 checks
  passed** across initial and fresh-process runs on X11. The focused run checks
  every group and row, keyboard focus across category boundaries, cross-category
  binding transfer, no dialog tooltip text, scroll behavior and focus-outline
  clearance at 1440 × 900, 970 × 600 and 640 × 480.
- [Normal](grouped-normal.png), [compact](grouped-compact.png),
  [scrolled normal](grouped-scrolled-normal.png) and
  [scrolled compact](grouped-scrolled-compact.png) native screenshots show the
  sections, fixed footer and unobstructed final focused row.
- `python -m unittest tests.test_application_version`: **2 passed**;
  `python -m py_compile tools/validate_keyboard_shortcuts.py` passed;
  `git diff --check` passed. Godot editor import completed cleanly after a
  normal-access rerun; a sandboxed first import could not open its local socket
  or save editor settings. Unrelated generated UID sidecars were removed.

The broad native shortcut runner reached 326 checks but reported one failure at
its Save Image picker assertion. This is the same unrelated native-run stopping
point recorded in the [historical #255 report](../issue-255/README.md); the
failed broad run is **not** counted as a pass. The focused native group run
completes cleanly without entering that picker. The full headless run completes
the shortcut semantics and restart paths.

Compatibility comparison was not required because the group layout uses the
same Godot Control tree and theme under both renderers. Packaged Linux, physical
4K/mixed-DPI displays, and a direct runtime injection of a future catalog
action were not checked. The grouping loop consumes each action's category
field directly and reuses an existing section for any later action with that
category.

## Owner verification

1. Open **Edit → Preferences → Keyboard Shortcuts** and confirm Navigation,
   Playback, File, Tools and Interface each appear once with their expected
   actions. Confirm Orbit Camera Left/Right are under Navigation.
2. Scroll to Interface at the normal window size and at 970 × 600. Tab through
   the last row and verify its focus outline and the fixed footer do not clip
   or overlap. Check normal KDE scaling and the preferred physical display.
3. Rebind one action in Navigation, transfer its key to an action in File, then
   use Reset Defaults, Apply and Cancel. Restart Wavez and check saved bindings.
4. Hover row controls, section titles and footer actions: the Keyboard
   Shortcuts window should remain tooltip-free.

The PR remains pending owner review. Historical #175 and #255 reports are
preserved as their original review-time records.
