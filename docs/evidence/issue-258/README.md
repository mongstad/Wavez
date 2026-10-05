# Issue #258 — free-look steering and target-relative orbit

Candidate **v0.1.0.52**, awaiting owner review. The sole Ready item was
**UX-NAV — Separate free-look steering from target-relative orbit controls**.
The existing GitHub-linked branch is
`258-ux-nav-add-turn-camera-left-right-shortcuts-for-free-flight-navigation`,
starting at accepted `main` `3c6e211` (owner-merged PR #260). The checkout and
remote branch matched this baseline and were clean before implementation.
Required navigation predecessors #200/#256 were already present; optional
shortcut UI issues #255/#259 were still open and are outside this change.

## Implementation decisions

- RMB now changes camera heading on both local view axes at a fixed position,
  including rolled views and pole crossings. Sensitivity is `0.003` radians per
  mouse pixel and never uses the translation-speed multiplier.
- The existing full-basis/target/radius representation is retained. After
  steering, its target is synchronized one existing radius ahead along the new
  heading. This is a navigation reference change; no scientific/source transform
  is changed. It lets wheel, orbit, presets, Frame Scene, Reset Camera and the
  orbit-center editor continue to use the accepted camera representation.
- Orbit Camera Left/Right reuse the accepted view-relative orbit math. A held
  shortcut captures screen-up and turns around the current target at 90°/second.
  Left moves the camera toward screen-left; Right mirrors it. The radius and
  target stay fixed, frame delta controls elapsed rotation, and opposite held
  directions cancel. Key/modifier release, focus loss and input guards clear
  held state. Framing/reset commands also end the old hold to avoid a stale step.
- RMB and the new orbit keys disable Auto Orbit on their first input, leaving it
  off on release. LMB tumble, wheel and W/A/S/D/Q/E retain their accepted paths.
  Mouse dragging takes precedence over held orbit shortcuts. Translation speed
  remains separate from all angular controls.
- The two actions are Unbound by default in the authoritative Navigation
  catalog, using the existing editor, conflict transfer and persisted profile.
  No existing default binding changes. The [native screenshot](orbit-shortcuts-forward.png)
  shows the test profile after applying F6/F7; those are test bindings, not new
  application defaults.

The former RMB-orbit checks were moved from the tumble suite into the new
navigation suite, where the same full-circle/view-up/target/radius invariants
are exercised through held keys. Connected Auto Orbit and wheel tests now use
the revised interaction contract. Prior issue evidence remains untouched.

## Focused validation

Godot 4.7.2 on the local Linux desktop. Native runs use the source viewer and
isolated preference profiles; they are automated input checks rather than
physical owner acceptance.

| Focused check | Result |
|---|---|
| Steering, held orbit, movement, state, framing and input guards | [1,346 headless](navigation-headless.json) |
| Same checks plus normal/fullscreen viewport mouse dispatch | [1,687 Forward+](navigation-forward.json), [1,687 Compatibility](navigation-compatibility.json) |
| New shortcut rows, conflict, Apply/Cancel/Clear/Reset and fresh-process restart | [25 headless](shortcuts-headless.json), [25 Forward+](shortcuts-forward.json), [25 Compatibility](shortcuts-compatibility.json) |
| Auto Orbit, center crossing and Edit Orbit Center Apply/Cancel | [364 headless](auto-orbit-headless.json) |
| Accepted translation-speed defaults, bounds, steps and hold cadence | [97 headless](speed-headless.json) |
| Existing LMB revolutions/poles, framing and camera persistence | [13,046 headless](tumble-headless.json) |
| Wheel and view-relative orbit through explicit native Wayland dispatch | [234 Forward+](wheel-wayland.json) |
| Application version | 2 unit tests; CLI reports v0.1.0.52 |

The navigation suite covers particle, field, mesh and mixed fixtures, all six
translation axes after steering, through-flight, arbitrary orientations, complete
steering/orbit revolutions, mirrored directions, 12/120 Hz orbit integration,
opposite keys, release/modifiers/focus/modal/busy guards, a live process-loop
hold, preset round trips, Frame Scene and Reset Camera. Camera position is fixed
during pure RMB input. Scientific world transforms, committed sample/playback
state and source hashes stay unchanged. Editor tests use a second application
process to prove persisted bindings are restored and dispatch correctly.

The shortcut reports record the native X11 backend. The separate explicit
Wayland run covers normal and synthetic 3840×2160 layouts at 2×/2.5× scaling;
these are not physical mixed-DPI/4K display checks. It retains the existing
nonfatal libdecor GTK initialization warning in its report. No native cleanup
errors occurred in the focused shortcut runs.

Python compilation, the modified wheel-test parser check and `git diff --check`
passed. The first camera-run import stopped on cached missing-UID warnings for
five pre-existing unrelated scripts; Godot restored their sidecars, and repeat
imports/tests completed cleanly. Those incidental sidecars are not part of this
issue. No packaged-app run, production capture rerun or unrelated full suite was
performed. Physical mouse/keyboard feel remains for owner verification.

## Reproduce

Use a new output directory for each run; `$GODOT` names the externally installed
engine executable. Fixtures and preferences are generated outside the repository.

```sh
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer headless --output-dir /tmp/wavez258-navigation-headless
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer forward_plus --output-dir /tmp/wavez258-navigation-forward
python tools/validate_camera_tumble.py --godot "$GODOT" --suite navigation --renderer gl_compatibility --output-dir /tmp/wavez258-navigation-compatibility
python tools/validate_keyboard_shortcuts.py --godot "$GODOT" --orbit-only --renderer forward_plus --output-dir /tmp/wavez258-orbit-keys-forward
python tools/validate_keyboard_shortcuts.py --godot "$GODOT" --orbit-only --renderer gl_compatibility --output-dir /tmp/wavez258-orbit-keys-compatibility
python tools/validate_wheel_zoom.py --godot "$GODOT" --renderer forward_plus --output-dir /tmp/wavez258-wheel-native
```

The other camera boundary checks use `--suite auto-orbit`, `--suite speed` and
`--suite tumble` with `--renderer headless`; the shortcut check also accepts
`--renderer headless`.

## Owner verification

1. In representative particles, fields, meshes and mixed captures, steer with
   RMB on both axes at outside and close/interior viewpoints. Check in-place
   turning and no press/release snap. Fly toward a filament, field feature,
   along a mesh surface or through a toroidal cavity while steering; W/S should
   follow the new heading, with A/D and Q/E remaining camera-relative.
2. Compare steering at minimum/default/maximum translation speed. Bind the two
   Unbound orbit actions to convenient unused keys; hold each around a chosen
   target before and after an arbitrary LMB tumble. Check full turns, stable
   target/radius, mirrored direction and immediate release. Angular behavior
   must not change with translation speed.
3. With Auto Orbit on, RMB or either orbit key must take control on the first
   input and leave Auto Orbit off on release. Check LMB and wheel, Frame Scene,
   Reset Camera and Edit Orbit Center Apply/Cancel after steering.
4. Exercise shortcut conflict transfer, Cancel, Apply, Reset Defaults and a real
   restart. Repeat the navigation in fullscreen and both renderers, and assess
   physical KDE/Wayland input feel. Scientific geometry and playback state must
   remain unchanged.

Stop boundary: one issue branch and one PR; acceptance and merge remain with the
owner. Passing these tests is not recorded as owner acceptance.
