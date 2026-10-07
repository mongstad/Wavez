# Editable value focus

Issue #291 proposes this shared behavior in build `v0.1.0.73`, pending owner
review. [Evidence and owner checks](evidence/issue-291/README.md) record native
Forward+ and Compatibility validation and the remaining desktop checks.

Entering direct text editing selects the current editable value, so the first
typed character replaces it. This applies to a first click, Tab/Shift+Tab,
programmatic editor focus and restoration after closing an application dialog.
It covers application-owned LineEdit controls and the text editors inside
SpinBox controls: Simulation particle/field/mesh values, Tools and Performance,
Video Export numeric values and output path, Seek Time, File Locations and the
orbit-center coordinate/radius editor. Dynamically built and reparented controls
use the same policy.

Selection happens on entry into editing. While the editor retains focus, a
second click places the caret, arrows move it, mouse dragging and Shift+Arrow
select a substring, and Ctrl+A/C/V remain native editing actions. Reconciliation
or another focus request for the already-focused control does not reselect text.
SpinBox arrow/wheel actions still adjust the value by the existing step without
being turned into select-for-replacement actions. Sliders retain their behavior.

The existing focus manager sets `LineEdit.select_all_on_focus` in its
`Window.gui_focus_changed` callback, before native focus-entry editing starts.
It reads the editor's current `editable` and `selecting_enabled` values on each
entry, including SpinBoxes enabled by switching from a preset to custom values.
Godot handles selection timing and SpinBox arrow interaction. There is no new
selection signal handler, deferred reselection, frame polling or idle redraw.
See the official [LineEdit property](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit-property-select-all-on-focus)
and [SpinBox text editor](https://docs.godotengine.org/en/stable/classes/class_spinbox.html#class-spinbox-method-get-line-edit) documentation.

Read-only and selection-disabled LineEdits do not receive automatic selection.
Read-only TextEdit surfaces (such as notices and job diagnostics) keep their
existing selection/copy behavior. Non-text controls and OS-native file-picker
widgets are outside this policy. No editable value control needs an exception
for a separate established caret contract.

Selection changes no parsing, units, range, step, scientific value, camera or
playback state by itself. Each control retains its existing text submission,
focus-loss, Apply and cancellation rules. For example, invalid Seek text still
shows its error and Escape cancels without seeking; File Locations cancellation
still discards drafts; orbit dismissal restores the previous camera. This does
not introduce a new universal Enter/Escape rule for numeric controls.

The focused evidence checks native GUI events generated through Godot APIs,
not physical mouse/keyboard devices. Packaged Linux, physical desktop input,
mixed-DPI/4K and sustained editing sessions remain owner verification items.
