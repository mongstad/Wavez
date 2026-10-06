# Keyboard focus navigation

Issue #146 introduces visibility-aware keyboard traversal in candidate build
`v0.1.0.65`, pending owner review. [Validation and owner checks](evidence/issue-146/README.md)
record the tested states and remaining desktop review.

Tab follows the current visible controls in reading order: the top bar's camera
actions, menus, pin and window actions; viewport-adjacent actions; the Simulation
header, category controls and selected object's sections; playback; then status
and Jobs. Shift+Tab follows the exact reverse order. At either end traversal wraps.
Section headers precede their expanded contents. The scroll container follows
focused Simulation controls so keyboard traversal exposes the current row.

Hidden, collapsed and auto-hidden descendants are absent. Disabled buttons,
non-editable sliders and numeric/text editors are skipped. Read-only TextEdit
surfaces remain reachable for inspecting and copying their contents. A SpinBox
contributes its internal text editor once. Availability is evaluated on each Tab;
enabling a control never pulls focus back to it.

When a focused region hides or its controls are removed, focus advances beyond
the **entire region**, to the next eligible control in the previously recorded
order. It wraps when necessary. If every old control was replaced, the first
eligible control in the new scope provides a recovery point. If no control is
eligible, focus remains in the viewport until another Tab can reach visible UI.
Showing a region alone never grabs focus or rewinds traversal. Categories,
selected objects, source reloads and collapsed sections use the same rule.

Fullscreen and the top/right/bottom pins consume the existing #117 visibility
state. Dwell remains 0.5 seconds, the grace period 0.35 seconds, and edge zones
10 logical pixels. Text editing, keyboard navigation and active interactions
retain their protection. Fullscreen exit preserves a current visible focus choice
through responsive reparenting, or restores the prior eligible choice when there
is no current one. See [edge reveal](WINDOW_EDGE_REVEAL.md).

Application-owned Windows contain traversal in the active dialog, including
Seek, About, Tools, Jobs, File Locations and nested confirmations. Keyboard
Shortcuts and the orbit editor have the equivalent boundary in their in-canvas
overlays. Dismissal restores the initiating control if eligible; otherwise it
advances past that control's hidden/removed region. Native PopupMenu navigation
and selection remain with Godot. Top MenuButtons are explicitly keyboard
focusable. During shortcut capture, the existing reserved Tab/Escape handling
takes precedence; cancelling the editor discards unapplied drafts as before.

`viewer/ui/shell/focus_navigation.gd` owns the policy. Explicit region roots
establish global order; live descendant traversal supplies each region's current
controls without numeric tab IDs. Focus snapshots hold weak references, order
and ancestor anchors for removal and restoration. Visibility/tree signals
coalesce into deferred handoffs; Tab reads current eligibility. Each application
Window gets a small pre-GUI input router so native traversal cannot advance
focus a second time. Responsive removal/reparenting of a still-eligible control
preserves its focus. There is no frame polling, processing loop or idle redraw.
Offline render instances do not install the manager.

The change supplies focus only. Existing callbacks retain control semantics,
scientific state, playback, camera transforms, theme tokens and window styling.

Run the focused native validation with an externally installed Godot and a fresh
temporary output directory for each renderer:

```sh
env -u WAYLAND_DISPLAY python tools/validate_focus_navigation.py --godot /path/to/godot --output-dir /tmp/focus-forward --renderer forward_plus
env -u WAYLAND_DISPLAY python tools/validate_focus_navigation.py --godot /path/to/godot --output-dir /tmp/focus-compatibility --renderer gl_compatibility
```

The runner creates tiny synthetic mixed/multi-object/fields-only sources,
isolates preferences, records actual native Tab/Shift+Tab orders, and checks
that source SHA-256 hashes and scientific state remain unchanged. It does not
start an export or apply preference drafts.
