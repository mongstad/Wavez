# Keyboard Shortcuts — issue #175

Candidate build 17, pending owner review. Selected from the sole Ready item on
the Wavez Development board on 2026-10-02. The existing owner-linked branch is
`175-ux-prefs-add-editable-keyboard-shortcuts-preferences-and-remove-help-shortcut-list`,
based on accepted `main` `0496d12` (owner-merged PR #174).

## Editing and persistence

Open **Edit → Preferences → Keyboard Shortcuts**, with or without a capture.
Help contains About; its old static Shortcuts list is removed.
The editor is a custom in-canvas Control with the accepted violet theme, a
640 × 560 logical-pixel maximum panel, a scrolling list and fixed footer.
The title leads directly into the list, with no permanent instructions above the
rows or footer; only a failed save displays an error. It fits smaller windows by
reducing its bounds; the production window minimum
remains 970 × 600. It creates no native or Godot Window/AcceptDialog chrome.

Activate a binding button with the mouse or keyboard, then press a key with
optional Ctrl, Shift, Alt or Meta/Super. The highlighted field says **Press a key…**.
Modifier keys alone are ignored. Escape cancels that capture operation; another
Escape closes the editor and discards the draft. Tab/Shift+Tab stay reserved for
focus traversal. Keyboard focus remains inside the editor, and following a row
scrolls it into view. Clear unbinds a row; Reset Defaults stages the accepted map.
Unavailable source actions explain their requirements in tooltips and remain
editable. Window-manager-reserved combinations may be intercepted before Wavez
receives them.

Assigning a duplicate immediately unbinds the previous row in the **draft**.
There is no warning or confirmation. **Apply** is disabled until the draft differs
from the active map, and disables again if all edits are reverted. Starting capture,
recapturing the current binding, or resetting an already-default map does not enable
it. Disabled Apply is skipped during keyboard navigation. **Apply** validates,
saves and activates the map and updates shortcut hints **without closing the
editor**. The applied map becomes the new clean draft and Apply disables until
another edit. The top-right **X** uses the main shell's close icon and control
styling. **Cancel**, X or dismissal silently discards only edits made since the
last successful Apply; already applied bindings stay active and saved. A save
failure keeps the editor open and the active map intact.
Viewport actions and free-camera movement cannot run through this modal editor.
Right-drag in the viewport orbits sideways about the camera's screen-up axis
captured at press time, around the current scene target. Vertical motion does
nothing; a new right press captures the then-current view. This mouse
gesture has no editable key binding; its hint appears on the Navigate control.
It works with Auto Orbit off and any visible scene type.
Existing text-entry, selection and busy-inspection guards remain authoritative.

The separate ConfigFile at `user://keyboard_shortcuts.cfg`, section `shortcuts`,
stores integer logical keycodes and modifier bits, including explicit `0` for
Unbound. Saving uses a temporary file and rename before activating the map.
There is no InputMap override or shutdown save of a cancelled draft. Invalid
individual stored values fall back to the action's default; manually edited
duplicates resolve deterministically in catalog order, with the last row winning.
An unreadable configuration retains defaults and reports the engine error.

Preferences are interactive-only. Offline rendering does not load this file.
Shortcut maps never enter SSC, capture metadata, inspection bundles, scientific
recipes, portable view presets or video jobs. Mouse navigation, free-camera
movement keys, focus navigation, and Escape recovery retain their existing roles.

## Defaults and action ownership

| Action | First-launch binding | Existing owner |
|---|---|---|
| Reset Camera | R | Viewer camera reset |
| Auto Orbit | O | Viewer orbit toggle shared with Navigate |
| Free Camera | Unbound | Navigate camera-mode toggle |
| Frame Scene | F | Viewer scene framing |
| Navigate | Alt+N | Existing Navigate menu |
| Play Pause | Space | Viewer transport toggle |
| Previous Sample / Next Sample | Left / Right | Viewer frame stepping |
| Loop Playback | Unbound | Transport's existing loop callback |
| Open File | Unbound | File's scene picker |
| Export Video | Unbound | File's existing export dialog |
| Save Image | P | Saves directly to the configured Image Exports directory; otherwise uses the native picker and current-session folder |
| Derive Range / Mapping | Unbound | Existing Tools commands and source eligibility |
| Recorded History / Point Rendering | T / V | Existing viewer toggles |
| Fullscreen | F11 | Existing shell fullscreen command |
| Fullscreen Alternate | Shift+F11 | Same fullscreen command; preserves the documented alternate |
| Pin Top Bar / Pin Right Panel / Pin Bottom Bar | Unbound | Existing edge-reveal pin states |
| Next Simulation Category / Previous Simulation Category | Unbound | Existing Particles, Fields, Meshes selection in that order, wrapping |

Actions without an accepted shortcut start Unbound to avoid inventing defaults.
Modifiers match exactly, so assigning Ctrl+R is independent of assigning R.
Both fullscreen defaults are explicit rows and can independently be reassigned
or cleared; there is no hidden hardcoded fullscreen alias. Escape remains recovery.
Menu shortcut columns are display-only: the viewer owns one dispatch path with
the existing input guards. Camera/transport callbacks are shared with their
buttons or Navigate controls; menu and tool shortcuts invoke the existing command
with its existing availability checks. Pins and category cycling add no new
scientific or playback implementation.

## Validation

Run the focused source-viewer checks on either renderer:

```sh
python tools/validate_keyboard_shortcuts.py --godot /path/to/godot \
  --renderer forward_plus --output-dir /tmp/shortcuts-forward
python tools/validate_keyboard_shortcuts.py --godot /path/to/godot \
  --renderer gl_compatibility --output-dir /tmp/shortcuts-compat
```

Add `--export` to import/export a temporary Linux release using the externally
installed export template, and run the same checks through its normal Main scene
with a validation-only autoload. Both source and packaged runs use an isolated
profile and a second application process to verify persisted preferences. The
test changes no owner preferences. No engine binaries/templates or generated
packages are committed. Results and limitations are recorded in
[issue evidence](evidence/issue-175/README.md). The subsequent Apply-state review
change has its own [validation evidence](evidence/issue-175/apply-review/README.md).
The later X/keep-open review change is recorded
[separately](evidence/issue-175/dialog-review/README.md).

## Owner verification before acceptance

1. Launch build 17 on the normal owner profile. Check Help has only About WAVEZ,
   and Edit → Preferences → Keyboard Shortcuts opens the custom editor. Review
   labels, grouped rows, violet surfaces, focus ring, fixed Cancel/Apply footer
   and scroll feel at normal KDE scaling, physical 4K and a 970 × 600 window.
   Apply must start disabled, enable after an actual binding change, and disable
   again when all changes are reverted. Tab/Shift+Tab must skip disabled Apply.
2. With Reset Camera bound to R, assign R to Frame Scene. Verify Reset Camera
   immediately says Unbound without a warning. Capture Ctrl+Shift+R for Reset
   Camera, then Cancel. Confirm the previously active bindings still work.
3. Repeat the two edits and Apply. Verify the dialog stays open with Apply disabled;
   edit/apply a different action, then make an unapplied change and close with X.
   There must be no warning, and the last applied map must remain intact. With a
   capture open, verify R frames the scene and Ctrl+Shift+R resets it. Restart Wavez with the same profile and verify both
   bindings and the unbound row persist. Clear a binding, Apply and restart again.
4. During capture, press Escape once: keep the editor open and retain the draft.
   Press Escape again: close and discard the draft. Use Tab/Shift+Tab and Enter
   to edit rows and reach Apply/Cancel, including the last row. Check Meta/Super
   combinations that KDE delivers to the application.
5. Bind and exercise Open File, Export Video, Free Camera, Auto Orbit,
   Play Pause, Frame Scene, Derive Range and Mapping. Confirm the existing picker,
   export, camera, transport and Tools behavior, including ineligible source
   actions and text/numeric input protection. Bind Loop Playback and compare it
   with the existing Loop switch while playing through the interval endpoint.
6. Bind the three pin actions and both category actions. Verify the existing
   pins toggle and categories wrap Particles → Fields → Meshes and back. Enter
   Fullscreen, reveal Edit, and open the editor; capture Escape must keep
   fullscreen active, while Escape after closing the editor restores the original
   fullscreen pin/visibility snapshot. Check both fullscreen binding rows.
7. Verify ordinary capture opening, seeking, preparation, playback and video
   export on both renderers and the Linux package. Reset Defaults stages a reset;
   Cancel leaves the saved profile unchanged. Owner acceptance remains pending.
