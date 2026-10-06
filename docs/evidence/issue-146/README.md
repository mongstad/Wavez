# Issue #146 — Visibility-aware Tab focus

Candidate `v0.1.0.65`, pending owner review. #146 was the sole Ready issue at
2026-10-06 preflight. Exact owner-created, checked-out linked branch:
`146-ux-a11y-001-make-tab-focus-traversal-visibility-aware-and-logically-ordered`.
It started clean at accepted main `a84f3483810d7dfd7324bee654a3db996c8c0443`,
including owner-merged PR #278 and prerequisite #117. Local main, origin/main
and the branch matched. Fetch/prune completed and the preceding completed
branch was already absent. No replacement branch or historical acceptance-only
changes were made. Before publishing, main remained at that baseline, #146
remained Ready/Open and no PR existed for the linked branch.

## Policy and implementation

See [the current contract](../../FOCUS_NAVIGATION.md). A small event-driven
manager supplies global visual region order and evaluates the live rendered
control tree on Tab/Shift+Tab. Weak focus/order/ancestor snapshots anchor handoff
beyond whole hidden regions and restoration from dialogs. Visibility/tree
events coalesce into deferred reconciliation; responsive reparenting preserves
a still-eligible focus choice. Top menus are explicitly keyboard focusable.
Window input is consumed in the pre-GUI phase, avoiding double advancement by
Godot's default traversal. Shortcut/orbit overlays have equivalent containment.
Native PopupMenus and shortcut capture retain their existing input ownership.
No frame polling or idle redraw is introduced; offline instances omit the manager.

## Final validation

Godot 4.7.2, Linux/X11, NVIDIA RTX 3070 Ti. Native fixtures and preferences were
isolated outside the repository. All final native runs exited cleanly.

| Check | Result |
| --- | --- |
| New focus matrix, Forward+ | 1,496 checks, 0 failures; source hashes unchanged |
| New focus matrix, Compatibility | 1,496 checks, 0 failures; source hashes unchanged |
| Existing edge reveal/Fullscreen, Forward+ | 210 checks, 0 failures; source hashes unchanged |
| Existing edge reveal/Fullscreen, Compatibility | 210 checks, 0 failures; source hashes unchanged |
| Existing shortcut grouping/focus/capture + restart, Forward+ | 276 checks, 0 failures; source hashes unchanged |
| Existing elapsed rendered focus/Seek boundary, Forward+ | 114 checks, 0 failures |
| Application version metadata/CLI | 2 unittest cases, OK; build 65 = main build 64 + 1 |
| Final editor import | Passed with no script errors or warnings after warmup |
| Whitespace and changed-document local links | Passed |

The new matrix records actual native input traversal paths in each `report.json`,
checks every eligible control is reached once, checks exact reverse traversal and
global region order, and verifies focus traversal leaves visual/scientific state,
committed sample, camera transform and playback unchanged. It covers 1440×900
and 1024×640; each side hidden/revealed; all sides unpinned; deterministic dwell
and grace injection; collapsed sections and keyboard disclosure activation;
Particles/Fields/Meshes; two field/mesh objects; fields-only source with an
unavailable mesh selector; source replacement; disabled and re-enabled Play;
Fullscreen entry, edge visibility and exit; native menu Enter/Escape; Seek
Enter/Escape/outside click with both visible and hidden initiators; About,
Performance, Jobs, File Locations, shortcut/orbit overlays and nested Video
Export confirmation restoration. Window actions are checked reachable without
automatically minimizing or terminating the validation process.

An idle interval verifies no repeated focus reconciliation. SHA-256 verifies all
four synthetic captures unchanged. The new runner isolates preferences, creates
fixtures and rejects native warnings/errors. No export is started and no draft
preferences are applied. The connected suites cover the unchanged #117 timing,
editing/pin/Fullscreen protection, existing shortcut grouping/capture/restart and
#277 violet rendered elapsed focus after repeated Seek dismissal. Validation
scope follows the shared focus path; unrelated scientific, cache, camera,
analysis, video-rendering and packaging suites were not rerun.

Screenshots are unobstructed compact shell states with the focused rate selector;
the recorded native orders and assertions provide the changing-state evidence.
All preceding issue reports and historical review wording remain unchanged.

## Preserved development evidence

- `development-initial/`: 768 checks, 8 failures. Fullscreen exit replaced a
  current focus choice after responsive reparenting; Window input followed by
  default GUI traversal skipped the Jobs footer and broke reverse order. These
  were fixed by retaining current visible focus and routing Tab before GUI input.
- `development-routing-fix/`: 954 checks, 0 failures, before the expanded audit.
- `development-expanded-audit/`: 1,495 checks, 3 failures in test expectations.
  The test incorrectly required immediate handoff when disabling an otherwise
  visible button (Godot retains that focus until Tab), and incorrectly expected
  Tab to create a shortcut binding. Existing shortcuts reserve Tab; Escape first
  cancels capture, then dismisses the editor. Final tests assert those accepted
  semantics, including next-Tab skip and unchanged active bindings after discard.

The first editor import recreated five pre-existing missing resize-script UIDs
with warnings and no script errors. Its output and later clean imports are
retained. Incidental resize UIDs were removed; new focus scripts retain their
own UIDs and tracked UIDs are unchanged. Synthetic captures, shader caches,
runtime binaries and temporary profiles are excluded from the commit.

## Reproduce and owner verification

Use the two commands in [focus navigation](../../FOCUS_NAVIGATION.md) with fresh
output directories. Connected suites:

```sh
python tools/validate_edge_reveal.py --godot /path/to/godot --output-dir /tmp/focus-edge-forward --renderer forward_plus
python tools/validate_edge_reveal.py --godot /path/to/godot --output-dir /tmp/focus-edge-compatibility --renderer gl_compatibility
python tools/validate_keyboard_shortcuts.py --godot /path/to/godot --output-dir /tmp/focus-shortcuts --renderer forward_plus --group-only
python -m unittest tests.test_application_version
```

Use native display access and isolated XDG preferences for the existing suites.
The existing elapsed test takes a fresh directory containing a
`tests.g4.fixtures.scene`-generated `scene.wvz`:

```sh
env -u WAYLAND_DISPLAY /path/to/godot --path viewer --rendering-method forward_plus --audio-driver Dummy --resolution 1440x900 --script ui/shell/test_elapsed_focus.gd -- /tmp/focus-elapsed
```

Physical 4K/KDE, Wayland, preferred scaling/mixed-DPI, other platforms, packaged
execution and long-session input feel remain untested. Native menu/window-manager
reserved keys and OS file-picker traversal need desktop review. No automated
test substitutes for those physical checks.

1. In both renderers at 1440×900 and 1024×640, Tab through the complete visible
   shell and Shift+Tab back. Confirm menus, pins, window controls, category
   selectors, headers, expanded controls, playback and Jobs appear in reading
   order. Activate a category, disclosure and menu with the keyboard.
2. Unpin each side and then all three. Check ordinary grace/dwell and editing
   protection. Reveal the next side by its edge; confirm hidden controls are
   skipped, focused-region hiding advances beyond that whole region, and reveal
   does not steal focus. Repeat in Fullscreen and check exit focus.
3. Collapse a section containing focus; switch categories/objects/channels and
   open a replacement or fields-only source. Check no stale/hidden control
   retains focus and disabled controls are skipped without restarting traversal.
4. Open Seek and use Enter, Escape and click-away; compare time and the violet
   elapsed outline. Open About, Performance, Jobs and preferences. Tab/Shift+Tab
   should remain contained and dismissal should return to the visible initiator;
   hide its region while Seek is open and check fallback to the next region.
5. In Keyboard Shortcuts, capture then press Tab and Escape; check the existing
   reserved-key behavior. Edit a binding, Cancel/X/Escape without Apply and
   confirm it is discarded. Apply should retain the existing open-editor contract.
   Review a real confirmation dialog without accepting an unintended operation.
6. Repeat on the owner's physical 4K/KDE setup and preferred scaling, including
   native minimize/maximize/restore, OS file pickers and focus-outline visibility.
   Confirm About shows build 65 and reconcile with accepted main before merge.

The PR stops for owner review. No merge, auto-merge, issue closure, board move or
later issue work is authorized by these passing tests.
