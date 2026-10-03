# Issue #201 — owner review revision 1

The first [review report](../README.md) remains a record of the initial
candidate. Owner review found that pressing a bound Free Movement key also
turned on Auto Orbit.

## Cause and correction

Shortcut matching already resolved one keypress to one action, and the
Preferences conflict rule already gave a binding one owner. The coupling was
in the shared viewer toggle: `_toggle_free_camera()` assigned both
`free_camera` and `orbit_enabled`. It now changes only `free_camera`.
`_toggle_auto_orbit()` changes only `orbit_enabled` and retains the current
inspection-pause state. Both Navigate menu entries call these same independent
methods. No additional shortcut or camera input path was added; LMB/RMB/wheel,
target, radius, and scientific geometry code is unchanged. Candidate build
remains `v0.1.0.27` on the existing issue branch and PR #203.

## Validation

Godot 4.7.2 on Linux. The existing keyboard validation now stages and Applies
F for Free Camera after Reset Defaults, checks that Frame Scene loses F, and
sends actual F and O key events with both navigation states on and off. It
transfers F to Frame Scene and back to verify one key owner, invokes both
Navigate menu actions, and repeats the F/O sequence in a fresh process with
the saved profile. Existing Apply/Cancel, conflict, reset, fullscreen and
scene-type checks remain. The [summary](summary.json) records each run and
unchanged synthetic fixture SHA-256 hashes.

| Run | Checks passed |
|---|---:|
| Headless source | 268 |
| Forward+ source | 274 |
| Compatibility source | 274 |
| Forward+ Linux release package | 274 |
| Compatibility Linux release package | 274 |

The focused camera-tumble and view-relative RMB suite passed 13,798 headless
checks. Native wheel/RMB input passed 258 checks per renderer. Recipe-state
restoration passed 2,663 headless checks. All tested capture hashes remained
unchanged. The final source/package runs passed their assertions and exited
cleanly. Compatibility shortcut shutdown retained the two previously
documented texture-cleanup diagnostics; each package run retained the two
previously documented window-signal cleanup diagnostics. The native wheel
runs emitted the existing Wayland `libdecor-gtk` initialization diagnostic.

## Owner verification

1. Start with Free Movement on and Auto Orbit off. In Preferences, assign F to
   Free Movement and Apply. Verify Frame Scene becomes Unbound.
2. Press F twice: Free Movement turns off and on while Auto Orbit stays off.
   Turn Auto Orbit on with O; press F twice again and verify Auto Orbit stays on.
   Press O twice with Free Movement on, then twice with it off; Free Movement
   must stay unchanged in both cases.
3. Use each Navigate menu entry while the other state is on and off. Check that
   each entry changes only its named state and the checkmarks match.
4. Transfer F to Frame Scene through Preferences, then back to Free Movement.
   Confirm only the current owner responds. Restart and repeat the F/O checks
   with the saved binding.

Physical owner key and mouse feel, 4K/mixed-DPI, long sessions, and full
production capture playback remain unverified. Stop at PR #203 for review.
