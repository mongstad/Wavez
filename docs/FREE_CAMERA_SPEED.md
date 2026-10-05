# Free Camera movement speed (#200, #256)

Free Camera translation starts at **70%** of the accepted build 48 rate. Its
existing movement formula and camera-relative W/A/S/D/Q/E directions are
unchanged; one session-only speed multiplier scales the resulting translation.
The multiplier starts at `0.7` and stays between `0.02` and `2.5` times the
former rate. These bounds preserve close-range control and faster traversal.

Press `+` to multiply the current rate by `1.10`, or `-` to multiply it by
`0.90`. The first step occurs on the initial press. Holding the key applies
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

Speed adjustment changes free-camera translation only. LMB tumble, RMB steering,
manual orbit angular rate, wheel zoom, Frame Scene, Reset Camera, Auto Orbit, orbit-center editing,
scientific/world transforms, and playback do not use this multiplier.

The #256 tuning changes only those two bounds and per-step factors. It keeps
the #200 default, key handling, repeat cadence, and translation-only path.

## Issue #256 candidate validation

The focused speed suite passed **97 headless** checks and **101 checks each**
in native Forward+ and Compatibility. It covered the unchanged `0.7` default,
10% single taps and holds, 200 ms throttling, release and focus loss, the new
0.02/2.5 bounds without overshoot, rebound keys, normal and fullscreen modes,
and unchanged camera/world transforms in particle, field, mesh and mixed scenes.
Generated WVZ1 fixture hashes remained unchanged.

The focused Keyboard Shortcuts path passed **16 checks each** headless,
Forward+ and Compatibility, including conflict handling, Apply/Cancel/Reset,
rebound actions and fresh-process persistence. The connected Auto Orbit suite
passed **364 checks each** headless and Forward+, covering W/A/S/D/Q/E,
LMB/RMB, wheel and orbit transitions. The directly affected broader Keyboard
Shortcuts suite passed **283 headless** checks, including restart. Two
application-version tests, the `v0.1.0.50` CLI and whitespace checks passed.

The physical Nordic keyboard, a Linux package, and a real production capture
were not rerun for #256; the shortcut mapping, packaging path and scientific
scene handling are unchanged from #200. No unrelated full-suite run was made.

## Issue #256 owner verification

1. In a particle, field, mesh and mixed scene, confirm the default Free Camera
   pace still matches accepted build 49. Tap `+` or `-` once and check that
   each step is clearly more noticeable than before. Hold either key, then
   release it to confirm the deliberate 200 ms cadence stops immediately.
2. Step down to the new fine-control floor and up to the reduced ceiling. Check
   that further presses stay at the bound, both in a normal window and fullscreen.
3. Confirm the Nordic `+`/`-` keys and rebound shortcuts after restart. Check
   W/A/S/D/Q/E, LMB/RMB, wheel, Auto Orbit and Edit Orbit Center while moving
   among the scene types. Scientific objects and playback should keep their
   world state.

---

The original #200 validation and owner-verification record below is retained
as a historical build 49 checkpoint; its 5% figures describe that checkpoint.

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
