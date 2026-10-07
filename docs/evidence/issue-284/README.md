# Tooltip-free panel pins — issue #284

Candidate `v0.1.0.69`, pending owner review. #284 was first and the only Ready
item. Its owner-linked branch `284-ux-pins-remove-tooltips-from-all-panel-pin-controls`
was checked out, clean and at accepted `main` `db198dc` (owner-merged PR #286).
Fetch/prune completed; the previous #285 branch was already absent. No branch
was created/switched and no Project transition was performed.

## Change and scope

`edge_reveal.update_pin()` now assigns an empty tooltip to the same top, right
and bottom pin controls, in both pin states. Creation, pin toggles, theme refresh
and Fullscreen restoration all use that path. The runtime diff is that single
text assignment plus the required build increment. No icon, style, action,
focus/traversal, timer, visibility/state persistence or unrelated tooltip code
was changed. Current WINDOW_EDGE_REVEAL.md and CURRENT_STATUS.md document the
behavior; the evidence index links this record. Historical reports remain as written.

## Focused validation

[Machine summary](summary.json), [Forward+](forward.json),
[Compatibility](compatibility.json), and clean native logs
([Forward+](forward-native.txt), [Compatibility](compatibility-native.txt)):

| Gate | Result |
|---|---|
| Native Forward+ pin/input/hover matrix | 276 checks, zero failures |
| Native Compatibility pin/input/hover matrix | 276 checks, zero failures |
| Application version | 2 tests PASS |
| Final warm Godot import / whitespace | PASS |

For this reversible text-only change, an external temporary pin-only review
uses the existing `test_transport_tooltips.gd` hover/click/key helpers. No new
permanent regression suite was added. The production empty viewer supplies the
actual three controls; no capture or scientific computation is needed.

The matrix hovers every pin for **0.8 seconds**, beyond the project's **0.5-second**
tooltip delay, while pinned and after unpin → hide → edge reveal. It verifies
both empty tooltip text and absence of a visible TooltipLabel popup, with the
GUI's hovered control matching the intended pin. It runs at 1440×900 and
1024×640, and repeats inside actual native Fullscreen entered from each size.
Fullscreen expands to the current 2560×1440 display; this is not a claim of
compact native Fullscreen geometry.

The same checks exercise mouse unpin, native Enter repin, live focus eligibility
and Tab order, pinned/unpinned icons, unchanged normal/hover/pressed/hover-pressed/
disabled/focus style resources, 0.35-second hide grace, 0.5-second edge dwell,
hidden/unpinned Fullscreen entry and exact pin/timer restoration on exit.
Deterministic `edge.tick()` increments verify dwell/grace; hover and button/key
input pass through the existing native GUI helpers. The intentional Loop tooltip
appears in all four window/Fullscreen contexts. Pin state stays outside export
presentation dictionaries. No broader scientific or playback suite was run:
the changed path only assigns text to the three pin buttons.

## Baseline, failures and limits

The accepted-main [baseline](baseline.json) reproduces pin tooltips in all 24
pin/state/size/mode combinations, yielding 48 expected empty-text/no-popup
assertion failures. Twelve Tab successor expectations also fail in that baseline
with pin tooltip popups present. Neither baseline subset is counted as passing;
no focus-system fix or causal explanation is claimed. The unchanged input checks
pass on the candidate without tooltips. No final native warnings/errors occurred.

Initial import regenerated five unrelated missing UID files from cache. The warm
final import is clean; incidental untracked sidecars were removed. No tracked UID
was altered and no new script was added.

Linux release packaging, other OSes, loaded-scene playback, multi-hour sessions,
4K/mixed-DPI, physical mouse/keyboard hover feel and monitor/taskbar screenshots
were not run. Package-specific paths are not involved in this assignment; native
window/input evidence is the proportional validation for this issue. Window-texture
captures show application UI and do not establish compositor overlays. The review
driver is retained only in this session's external `/tmp/wavez-issue-284/` directory;
the manual owner checks below are the durable verification procedure.

## Images

The retained native captures were visually inspected. Normal, compact and
Fullscreen pin hover states are unobstructed and tooltip-free; pin appearance
retains its existing upright/tilted state. The Loop control still shows its tooltip.

- [Before: top pin tooltip](baseline-tooltip.png)
- [Normal top](normal-top.png), [right](normal-right.png), [bottom](normal-bottom.png)
- [Compact unpinned right](compact-unpinned-right.png)
- [Fullscreen unpinned bottom](fullscreen-unpinned-bottom.png)
- [Compatibility compact unpinned top](compatibility-compact-unpinned-top.png)
- [Intentional Loop tooltip](intentional-loop-tooltip.png)

## Owner verification

1. At a normal window size, hover the top, right and bottom pin icons for at least
   one second each. Confirm no tooltip and the usual hover color.
2. Click each pin to unpin, move away to let its panel hide, then dwell at the
   corresponding window edge to reveal it. Hover the unpinned icon for one second;
   confirm no tooltip. Repin and confirm the ordinary icon/state behavior.
3. Tab to each visible pin; activate with Enter, then continue Tab traversal.
   Confirm focus outline and pin/unpin behavior; repeat mouse click activation.
4. Enter Fullscreen with F11. Reveal each edge and repeat pinned/unpinned hover
   and activation checks. Exit with F11/Escape and confirm prior panel state.
5. Repeat at a compact window size. Hover Loop and another intentionally explained
   control to confirm their tooltips still appear.
6. Review these limits before acceptance. The owner controls merge, branch deletion
   and Project completion; the agent stops after pushing and opening one PR.
