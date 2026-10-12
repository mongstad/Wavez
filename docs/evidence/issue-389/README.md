# Issue #389 quick-reference review record

Candidate v0.1.0.105; owner review pending. Selected issue #389 as the only
Ready item on Wavez Development on 2026-10-12. GitHub linkedBranches confirms
`389-docs-ux-rewrite-keyboard-shortcuts-as-concise-user-quick-reference`;
its starting commit `4adb69c` matches accepted origin/main and includes merged
PR #386. Fetch/prune removed the completed remote branch; its local branch was
already absent. Local main was advanced to that accepted baseline without
switching the implementation checkout.

## Editorial scope

The active guide now contains practical editing instructions, all 32 catalog
actions grouped into five categories, and essential held-camera/layout notes.
The owner confirmed the screenshot was added today; its URL and dimensions are
retained, with descriptive alt text. Camera guidance links to the user handbook.
No shortcut behavior or saved preferences changed. The mandatory version policy
accounts for the sole application-setting edit.

[The complete previous guide](keyboard-shortcuts-before.md) is preserved
byte-for-byte from the accepted baseline, including historical review wording.
Its relative links retain their original `docs/KEYBOARD_SHORTCUTS.md` context;
consult that Git baseline for those original link destinations. Existing evidence
files remain untouched. The active guide retains the legacy incoming
`original-175-owner-verification-record` fragment as an invisible anchor; the
original verification instructions now reside in the archived guide.

## Focused validation

- PASS: all 32 action labels/defaults and five categories compared with
  `viewer/ui/keyboard_shortcuts.gd`.
- PASS: editing, conflict transfer, Apply/Cancel/Escape, default reset and saved
  settings instructions checked against the binding/editor source; held movement,
  orbit, roll and physical W/A/S/D checked against viewer navigation source.
- PASS: active handbook link and target heading, legacy incoming fragment,
  screenshot retention, removal of engineering narrative and byte-identical
  archive checked with a one-off Python audit.
- PASS: `python -m unittest tests.test_application_version` — 2 tests.
- PASS: `git diff --check`.

Source review verifies documentation against implemented behavior; it is not a
new interactive runtime test. GPU, packaging, scientific-data and full runtime
suites were skipped because their behavior is unchanged. No new screenshot was
captured or rendered; screenshot recency is confirmed by the owner.

## Owner verification

1. Read the quick-reference and confirm its length, table grouping and retained
   screenshot are useful to a new user.
2. Open Edit → Preferences → Keyboard Shortcuts and compare the row names and
   defaults (existing saved assignments may differ).
3. Assign a duplicate key, confirm the previous row becomes Unbound, Apply, make
   another edit and Cancel; only the applied edit should remain. Restore your
   preferred bindings afterward.
4. Follow the handbook camera link and check the + key explanation against your
   keyboard layout.

Stop boundary: one PR targeting main, left for owner review. No owner acceptance,
merge, issue closure or Project completion is claimed.
