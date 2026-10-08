# LMB vertical-axis preference

Open **Edit → Preferences → Keyboard Shortcuts**, under **Navigation**.
**Toggle Invert Y Axis** has an **On/Off toggle beside its hotkey field**:

- **Off** uses the accepted left-drag vertical response.
- **On** reverses only the vertical component of left-drag tumble. Downward drag
  produces the opposite pitch response; upward drag reverses correspondingly.
- Horizontal left-drag sensitivity/direction and continuous pole traversal/full
  revolutions retain their behavior in both states.

Choose either state and **Apply**. The editor stays open. Cancel, X and Escape
silently discard unapplied state/binding edits. **Reset Defaults** stages **Off**
and an **Unbound** toggle hotkey, taking effect only after Apply. Clearing the
hotkey leaves the selected inversion state intact.

You can also bind **Toggle Invert Y Axis** to a convenient unused key. The existing
one-key ownership rule transfers a conflicting key in the draft. Once applied,
that shortcut immediately toggles and saves the preference. Neither applying the
preference nor pressing its shortcut moves, resets or reorients the camera.
The initial default is **Off**, with the action **Unbound**; the user's choice
and assigned hotkey persist across application restarts.

Current **#258 RMB free-look steering remains unchanged on both axes**, as directed
by the owner. The earlier #190 RMB-orbit semantics referenced in the original
#214 specification are not restored. Wheel zoom, W/S/A/D/Q/E translation, Auto
Orbit, held orbit keys, framing/reset, orbit-center editing and translation speed
retain their accepted roles. Scientific object transforms and source data stay
unchanged. There is no extra Navigate or HUD toggle.

This is an interactive application preference. The existing atomic shortcut
ConfigFile at `user://keyboard_shortcuts.cfg` stores its boolean in the
`navigation` section as `invert_y_axis`, alongside the `shortcuts` section. State
and binding drafts are saved and activated together; a failed save keeps both
active settings intact. Offline viewers retain defaults and do not load the
owner's shortcut profile. The preference is excluded from scientific visual
snapshots, recipes, capture metadata and video jobs.

Candidate **v0.1.0.76** proposes issue #214, pending owner review. See
[focused source/package evidence](evidence/issue-214/README.md).

## Owner verification

1. Open Keyboard Shortcuts at normal and compact sizes. Find **Toggle Invert Y
   Axis** once under Navigation. Set On, Cancel and reopen: the previous state
   remains. Set On and Apply: the editor stays open with On selected.
2. Bind an unused key, Apply, close the editor and toggle with that key. Confirm
   the next vertical LMB drag reverses, while horizontal/diagonal motion changes
   only its vertical component. Make full turns across both poles; toggling the
   setting itself must not move the view.
3. Exercise RMB steering horizontally and vertically, wheel, translation, Auto
   Orbit, held orbit keys, Frame Scene, Reset Camera and orbit-center editing.
   Repeat with particles, fields, meshes and mixed captures in Fullscreen and
   normal windows. The scientific objects must keep their world transforms.
4. Restart and confirm the chosen state and key. Clear the key and Apply: the
   state stays selected. Reset Defaults then Cancel: settings stay unchanged;
   Reset Defaults then Apply restores Off and Unbound.
5. Repeat in Forward+ and Compatibility, including the Linux release. Assess
   physical mouse/key feel on the owner's normal desktop.

## Focused validation

Run from the repository root with an external Godot executable and fresh output
directories. Every run uses isolated preferences and a second process for restart:

```sh
python tools/validate_invert_y_axis.py --godot /absolute/path/to/godot \
  --renderer headless --output-dir /tmp/invert-headless
python tools/validate_invert_y_axis.py --godot /absolute/path/to/godot \
  --renderer forward_plus --output-dir /tmp/invert-forward
python tools/validate_invert_y_axis.py --godot /absolute/path/to/godot \
  --renderer gl_compatibility --output-dir /tmp/invert-compatibility
python tools/validate_invert_y_axis.py --godot /absolute/path/to/godot \
  --renderer forward_plus --output-dir /tmp/invert-release --export
python tools/validate_invert_y_axis.py --godot /absolute/path/to/godot \
  --renderer gl_compatibility --output-dir /tmp/invert-release-compatibility \
  --packaged-binary /tmp/invert-release/WAVEZ.x86_64
```

Export requires the external Linux template. Generated fixtures, profile, staged
export project and executable/PCK stay in the output directories; they are not
repository assets.
