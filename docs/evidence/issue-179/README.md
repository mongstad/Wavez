# Issue #179 — Help → About

The top Ready issue was #179, “UX — Rename Help menu item from About WAVEZ to
About.” Work started clean on the existing owner-linked branch
`179-ux-rename-help-menu-item-from-about-wavez-to-about`, exactly at accepted main
`2e10f4c` (owner-merged PR #184). Fetch/prune completed; the completed #176 local
branch was already absent. No other Ready issue was selected.

Only the Help registration's visible label changes to **About**. The command key,
callback, ordering, focus restoration and existing About WAVEZ dialog remain.
No dialog runtime code, links, artwork or notices change. The sole application
metadata advances from accepted build 19 to candidate `v0.1.0.20` under the
repository build policy; the existing identity reader displays it. Owner review
is pending.

## Validation

Godot 4.7.2 stable, Linux KDE X11/XWayland, NVIDIA RTX 3070 Ti. External Linux
release templates are used; no engine, binaries, captures or caches are committed.

| Existing About regression | Forward+ | Compatibility |
|---|---:|---:|
| Source | 118 PASS | 118 PASS |
| Exported Linux release package | 118 PASS | 118 PASS |

Reports: [Forward+ source](forward-source.json), [Compatibility source](compat-source.json),
[Forward+ package](forward-package.json), [Compatibility package](compat-package.json).
All four final native logs are adjacent to the reports and contain no ERROR or
WARNING diagnostics. The existing menu assertion now requires exactly `About`,
and the existing route assertion also requires dialog title `About WAVEZ`.
The suite exercises opening without/with a capture, authoritative identity,
missing-version fallback, canonical license hashes, notices/back navigation,
links/error recovery, viewport fitting, Close/Escape and unchanged scientific
state and fixture SHA-256. Browser success uses the existing test opener; no real
browser final address is claimed.

Final viewer import, canonical notices `--check`, the application-version unit
suite (**2 PASS**) and `git diff --check` passed. Active UI source search found
no stale menu registration; retained About WAVEZ literals are its unchanged
window title, close tooltip and title assertion. Broader shell/export/performance
suites were not rerun for this label-only change.

## Failed attempts and visual evidence

An initial screenshot addition omitted an explicit Rect2 type. Package imports
failed parsing and source runs timed out at 120 seconds; their parse logs and
[first package import](initial-package-import-failure.txt) are retained. This
was corrected. An extra popup screenshot lifecycle then completed all 118
assertions but produced two shutdown signal-disconnect errors in both packages;
see the `*-capture-attempt.txt` logs. The same renderer packages from accepted
main with the original test flow passed cleanly (`*-baseline-package.txt`).
Removing that additional capture lifecycle from the committed regression test
made both candidate packages pass cleanly. The strict wrapper was not weakened
and those failed capture runs are not counted as PASS.

The inspected [Help menu screenshot](help-about-menu.png) was obtained from the
separate source capture attempt after layout settled. It shows About under Help;
its extra capture code is not part of the final test. The inspected
[About package screenshot](about-linux-package.png) comes from the final passing
Forward+ package and shows the unchanged About WAVEZ title/content and candidate
build. Historical evidence elsewhere retains its original labels and review-time
wording. Current README, handbook, version guide, shortcut guide, About navigation
note and status entry use the new menu label; historical report sections are
preserved.

## Owner verification

1. Launch candidate build 20 on Forward+ and Compatibility, including a Linux
   release package. Open Help and confirm the single item is **About**.
2. Select About with no capture and after opening a capture. Confirm the existing
   dialog opens with title **About WAVEZ**, identity **WAVEZ v0.1.0.20**, unchanged
   artwork, content, links and Licenses and notices.
3. Close with X, footer Close and Escape; confirm focus returns and normal capture
   interaction remains available.

Physical 4K/mixed-monitor scaling, Windows/macOS, real browser final addresses
and hands-on owner acceptance remain unverified. No broader UI redesign or
rounded-corner work is included. Stop for owner review; no merge, auto-merge,
manual closure, board transition or next-issue work is authorized.
