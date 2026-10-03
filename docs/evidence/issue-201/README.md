# Issue #201 — navigation defaults and shortcut audit

Selected as the first **Ready** item on the Wavez Development board on
2026-10-03. Owner-merged PR #199 is present in accepted `main` at
`d5e187391c1c822fc66f17f4639c1388e5598861`; the clean existing
`201-ux-nav-default-to-free-movement-enabled-and-auto-orbit-disabled` branch
started from that commit. The candidate application version is `v0.1.0.27`.

The viewer now starts with Free Camera enabled and Auto Orbit disabled. The
existing `free_camera` and `auto_orbit` actions remain the only editable
actions: Free Camera starts Unbound and Auto Orbit retains O. Their dispatch,
menu checks, editing, persistence, and conflict handling stay on the existing
paths. Scene opening and Reset Camera do not replace the navigation modes.
Explicit view presets can restore both; inspection recipes restore their saved
Auto Orbit value, while Free Camera remains session-only.

## Validation

Godot 4.7.2 on Linux. Each shortcut run also exercised a fresh process restart,
editable rows, Apply/Cancel, conflict transfer, Reset Defaults, four generated
scene types, explicit and partial preset precedence, and unchanged fixture
SHA-256 hashes. Native runs covered the normal window and fullscreen paths.
The [summary](summary.json) records the individual runs and hashes.

| Run | Checks passed |
|---|---:|
| Headless source | 233 |
| Forward+ source | 239 |
| Compatibility source | 239 |
| Forward+ Linux release package | 239 |
| Compatibility Linux release package | 239 |

Additional unchanged-navigation and saved-state regressions passed: camera
tumble and view-relative RMB orbit, 13,798 headless checks; wheel and RMB native
input, 258 checks in each renderer; view presets, 814 headless checks; recipe
state, 2,663 headless checks; application version, 2 unit tests. All generated
capture hashes remained unchanged. `git diff --check` passed.

The initial sandboxed native attempt had no X11/Wayland display. The camera
import initially could not create Godot's local editor socket in the sandbox.
An initial view-preset run completed all 814 assertions but could not write
Godot's user log. Native/display-access and isolated-profile reruns passed.
The final Compatibility shortcut run reported the previously documented pair
of engine texture-cleanup messages at restart; packaged runs reported the
previously documented pair of window-signal cleanup messages. The wheel runs
reported a Wayland `libdecor-gtk` initialization diagnostic. These diagnostics
are retained in the run logs and counted in the summary; no assertion failed.

## Owner review

1. Launch with a clean shortcut profile and no view preset. Open Navigate:
   **Free camera** should be checked and **Auto orbit** unchecked. Repeat after
   opening representative particle, field, mesh, and mixed captures.
2. Press O twice: Auto Orbit should turn on, then off. Under **Edit →
   Preferences → Keyboard Shortcuts**, verify one Auto Orbit action bound to O
   and one Free Camera action initially Unbound. Bind Free Camera, Apply, toggle
   it off and on, restart, then Reset Defaults and check both bindings.
3. In a normal window and Fullscreen, left-drag, right-drag after an arbitrary
   tumble, and wheel zoom. Check that the #190 view-relative RMB path and
   existing movement directions and sensitivity still feel right.
4. Save a view preset with deliberate nondefault navigation modes, change the
   live modes, reload it, and check the saved modes win. Check that an
   inspection recipe restores its Auto Orbit state without changing the
   session-only Free Camera state.

Physical owner mouse feel, 4K/mixed-DPI, long sessions, and full production
capture playback were not run. Historical #190 and #175 review-time evidence
remains unchanged.
