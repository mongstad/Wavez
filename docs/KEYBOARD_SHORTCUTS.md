# Keyboard Shortcuts

Open **Edit → Preferences → Keyboard Shortcuts** to view or change bindings,
with or without a capture open. **Unbound** means no key is assigned.

## Change a shortcut

1. Select the key button beside an action. When it says **Press a key…**, press
   the key you want, optionally with Ctrl, Shift, Alt or Meta/Super.
2. Select **Clear** to leave an action Unbound. Assigning a key already used by
   another row automatically clears that other row in your pending edits.
3. Select **Apply** to save and activate your changes. The editor stays open;
   applied preferences survive restarting Wavez.

**Reset Defaults** stages the defaults below; select Apply to save them.
**Cancel**, **X** or **Escape** closes the editor and discards changes since your
last Apply. While capturing a key, Escape first cancels capture; press it again
to close the editor. Apply is enabled only when something has changed.

Tab/Shift+Tab move between controls and cannot be assigned. Modifier keys alone
cannot be assigned. Some desktop shortcuts may be intercepted before Wavez
receives them. Modifiers distinguish bindings: **R** and **Ctrl+R** are separate.

<img width="636" height="555" alt="Wavez Keyboard Shortcuts editor" src="https://github.com/user-attachments/assets/65e9050a-91b8-48fe-9a48-fd03b2b02118" />

## Default shortcuts

These are the defaults; your applied bindings may differ. Actions still need
an appropriate scene or view to be available.

### Navigation

| Action | Default |
|---|---|
| Reset Camera | R |
| Auto Orbit | O |
| Free Camera | Unbound |
| Toggle Invert Y Axis | Unbound |
| Increase Camera Movement Speed | + |
| Decrease Camera Movement Speed | − |
| Move Camera Up | E |
| Move Camera Down | Q |
| Orbit Camera Left | Unbound |
| Orbit Camera Right | Unbound |
| Roll Camera Left | Unbound |
| Roll Camera Right | Unbound |
| Frame Scene | F |
| Navigate | Alt+N |

### Playback

| Action | Default |
|---|---|
| Play Pause | Space |
| Previous Sample | Left arrow |
| Next Sample | Right arrow |
| Loop Playback | Unbound |

### File

| Action | Default |
|---|---|
| Open File | Unbound |
| Export Video | Unbound |
| Save Image | P |

### Tools

| Action | Default |
|---|---|
| Derive Range | Unbound |
| Mapping | Unbound |
| Recorded History | T |
| Point Rendering | V |

### Interface

| Action | Default |
|---|---|
| Fullscreen | F11 |
| Fullscreen Alternate | Shift+F11 |
| Pin Top Bar | Unbound |
| Pin Right Panel | Unbound |
| Pin Bottom Bar | Unbound |
| Next Simulation Category | Unbound |
| Previous Simulation Category | Unbound |

## Camera keys and keyboard layouts

- **Hold** Up/Down to move along the camera's vertical axis. In Free Camera,
  **W/A/S/D** move forward/left/backward/right. Those four physical movement keys
  are fixed: assigning another action to one of them does not remove its movement.
- Hold an assigned **orbit** key to move around the navigation target. Hold an
  assigned **roll** key in Free Camera to bank the view; **Camera Roll Speed**
  adjusts the rate. Roll also works while right-dragging to steer in place.
  Orbit keys and right-drag steering turn Auto Orbit off.
- **Toggle Invert Y Axis** reverses only left-drag vertical motion. Its On/Off
  control starts Off. Apply saves this setting and Camera Roll Speed alongside
  bindings; Reset Defaults restores their defaults too.
- Tap **+ / −** to change movement speed, or hold to repeat. Use the character
  your layout produces: **Shift+=** produces + on a US keyboard; some Nordic
  keyboards have a dedicated + key.

For mouse controls and orbit-center placement, see the
[handbook's camera guidance](WAVEZ_HANDBOOK.md#camera-inspection).
Camera navigation changes your view, not the scientific data.

<!-- Preserve the incoming historical fragment without restoring engineering
history to this guide. Its original text is archived verbatim in
 evidence/issue-389/keyboard-shortcuts-before.md (relative links there retain
 their original docs/ context). -->
<a id="original-175-owner-verification-record"></a>
