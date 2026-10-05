# Free Camera movement speed (#200)

Free Camera translation starts at **70%** of the accepted build 48 rate. Its
existing movement formula and camera-relative W/A/S/D/Q/E directions are
unchanged; one session-only speed multiplier scales the resulting translation.
The multiplier starts at `0.7` and stays between `0.1` and `4.0` times the
former rate. These bounds preserve close-range control and faster traversal.

Press `+` to multiply the current rate by `1.05`, or `-` to multiply it by
`0.95`. The first step occurs on the initial press. Holding the key applies
another step no sooner than every **200 ms**, at most once per processed frame.
OS key-repeat events add no extra steps; release, focus loss, or opening the
shortcut editor stops the hold. The next free-camera translation uses the new
rate immediately. The rate itself is session-only; shortcut bindings persist.

Both actions appear under **Edit → Preferences → Keyboard Shortcuts** with
default logical `+` and `-` bindings. The produced plus character resolves the
same way on a dedicated Nordic `+` key and US Shift+=. The shortcut editor
handles rebind, duplicate transfer, Apply, Cancel, Reset Defaults, persistence
and restart through its existing machinery. Movement W/A/S/D/Q/E retains its
physical-key behavior. Godot's [key-event contract](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html)
distinguishes layout-aware keycodes and produced Unicode characters from US
physical key positions.

Speed adjustment changes free-camera translation only. LMB tumble, RMB orbit,
wheel zoom, Frame Scene, Reset Camera, Auto Orbit, orbit-center editing,
scientific/world transforms, and playback do not use this multiplier.

## Focused validation

`tools/validate_camera_tumble.py --suite speed` checks the default rate against
the accepted formula, exact first and held 5% steps, throttling and release,
bounds, default key layouts, runtime rebound keys, camera direction/orientation,
Auto Orbit transition, and unchanged world transforms across particle, field,
mesh and mixed fixtures. `tools/validate_keyboard_shortcuts.py` checks the
visible rows, conflict transfer, Apply/Cancel/Reset, a fresh-process restart,
and the Linux package. The connected Auto Orbit and camera tumble suites check
accepted mouse, wheel, framing and orbit behavior.

The automated key-layout checks synthesize Godot key events for both a dedicated
`+` key and Shift+= producing `+`. Physical use on the owner's Nordic keyboard
remains a manual owner check.
The [Forward+ Keyboard Shortcuts view](evidence/issue-200/keyboard-shortcuts-forward.png)
shows both new Navigation rows without a transient overlay.

Results: the speed matrix passed **93 headless** checks and **97 checks per
native renderer**. The focused shortcut editor and movement path passed **16
checks each** headless, native Forward+, native Compatibility, and in a temporary
Forward+ Linux package; each run included a fresh-process persistence check.
The broader Keyboard Shortcuts suite passed **283 headless** checks. Auto Orbit
passed **364 checks per renderer** (headless, Forward+, Compatibility), and the
connected camera tumble suite passed **13,798 headless** checks. Two application
version tests, the `v0.1.0.49` CLI and whitespace checks passed. Generated WVZ1
fixtures retained identical SHA-256 hashes in the focused suites.

The broader native Keyboard Shortcuts suite stops at its Save Image assertion
on both this branch and a disposable archive of accepted `main` in Forward+.
The same assertion stops the candidate Compatibility run. It is an existing
native test limitation outside the speed path; the focused native and package
checks above complete cleanly. A Compatibility Linux package and physical Nordic
key presses were not run.

## Owner verification

1. In a normal window, fly through a scene with W/A/S/D/Q/E. Compare build 49's
   starting pace with accepted build 48. Press and hold `+` and `-` on the
   Nordic keyboard; confirm immediate 5% steps and a deliberate ~200 ms hold
   cadence. Release each key to stop changes.
2. Rebind both actions in Keyboard Shortcuts. Exercise conflict transfer,
   Cancel, Apply, Reset Defaults and restart with the same profile. Check that
   the on-screen bindings match the actual Nordic keys.
3. Repeat movement and adjustment in fullscreen and in particle, field, mesh
   and mixed scenes. Check LMB, RMB, wheel, Frame Scene, Reset Camera, Auto Orbit
   and Edit Orbit Center before and after speed changes. Scientific objects and
   playback should remain stationary in world/scientific coordinates.
