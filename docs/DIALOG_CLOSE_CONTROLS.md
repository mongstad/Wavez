# Dialog close controls

Wavez-owned top-right close controls share the main shell's 32 × 32 hit area,
16 × 16 close glyph, `IconAction` normal/hover/pressed/disabled styling and hover
motion. Keyboard focus remains visible: the close control draws its shared focus
ring inside that hit area, rather than using the generic input ring's four-pixel
outward expansion. Other controls retain their existing focus rings.

`viewer_shell.close_action()` creates the shared action. The scoped production
style in `violet_style_slice.style_close_action()` also styles the existing
Tools and Video controls, which are constructed before the shell. Dark and Light
consume the same dimensions and semantic ink; Light retains the cool-gray palette.

The shared treatment covers Global effects and every form in the Tools host,
Source details/failure details, Jobs, Export Video, About, Keyboard Shortcuts,
File Locations and Edit orbit center. The orbit editor uses the shared glyph
instead of a text multiplication sign. Dialog titles, content, positioning and
sizes, bottom actions, focus order, tooltips and dismissal callbacks are retained.
Native OS file pickers/decorations and Godot-owned embedded title-bar decorations
remain governed by their existing window integration.

Candidate **v0.1.0.82**, issue #314, awaits owner review. See
[before/after evidence and validation](evidence/issue-314/README.md).

## Focused validation

```sh
python tools/validate_dialog_close.py --godot /path/to/godot --renderer forward_plus --output-dir /tmp/close-forward
python tools/validate_dialog_close.py --godot /path/to/godot --renderer gl_compatibility --package --output-dir /tmp/close-package
```

Each run uses a small generated mixed WVZ1 fixture and isolated preferences.
`--headless` exercises the shared styles and keyboard/signal paths; native runs
also inject hover, mouse press/release and capture screenshots. `--baseline`
records accepted-source layouts without imposing the new presentation checks;
use `--source /path/to/accepted/source` and then `--compare-report` to verify
unchanged visible control geometry/content and initial focus. Only the About
build identity and orbit close glyph are allowed to differ. `--packaged-binary`
reuses an already exported review package for another renderer. The package
uses a validation entry scene with production resources; it is not a release
or distribution artifact.

## Owner verification

1. Open a small capture, select Dark, then View → Global effects. Compare the
   top-right X with the shell X at ordinary and compact window sizes. Tab to X,
   hover it, press/release it and confirm focus remains visible without the
   previous oversized outline. Reopen, dismiss with Escape and with the bottom
   Close action; verify focus returns to the initiating control.
2. Switch to Light with a dialog open and repeat. Check both styles at your
   physical KDE/4K scale and when moving between displays with different DPI.
3. Inspect Tools → Mapping and Performance (including scrolling), File → Details,
   Jobs, File → Export → Video, Help → About, and both preference dialogs. Check
   that their headers, content, window sizes and bottom actions retain their
   established behavior. Close an idle Video dialog without starting an export.
4. In Keyboard Shortcuts and File Locations, change an unapplied draft, dismiss
   with X/Escape, then reopen and confirm it was discarded without a warning.
   Open Navigate → Edit orbit center, adjust a draft and cancel with X; verify
   the prior camera view is restored.
