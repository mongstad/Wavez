# Issue #394 — contribution guide editorial review

Owner review pending. Issue #394 was the sole Ready item on Wavez Development.
The checkout already used the exact GitHub-linked branch
`394-docs-contributing-replace-internal-engineering-instructions-with-a-human-friendly-contribution-guide`,
clean at accepted main `0d920d4c326719f5ef3ac3207f061690e136605e`. PR #393 was
verified merged; its content is in main and completed branch references are
already absent. Fetch/prune and main/origin comparison showed zero divergence.

## Changes and retained guidance

CONTRIBUTING.md is a 300-word human guide for repository-access holders, covering
reproducible bug reports, questions, ideas and contributions by prior arrangement.
Live GitHub metadata confirms the repository is private, Issues enabled and
Discussions disabled. The guide links to Issues and makes no promise of review,
acceptance or merging. Existing source-available PolyForm terms are described
without a CLA, copyright assignment, royalty promise or additional permission.

| Previous internal guidance | Current location |
|---|---|
| Branding, authoritative root, unversioned paths, Git history/checkpoints | Existing AGENTS.md |
| Accepted scope, scientific/capture constraints, owner-controlled workflow | Existing AGENTS.md and linked capture policy |
| BUILD increments and release authorization | Existing AGENTS.md and docs/VERSIONING.md |
| Python exporter identity and historical release context | Existing capture/version policies and Git history |
| Forward+ GPU scope, headless CPU limits, historical Compatibility reports | Added AGENTS.md source-resource section |
| UID sidecar identity and source/resource import checks | Added AGENTS.md source-resource section, subject to risk-based validation |
| Canonical notice synchronization and external runtime boundary | Added AGENTS.md source-resource section, existing licensing safeguards |
| No unapproved force push or history rewrite | Added to existing AGENTS.md history safeguard |

The technical-documentation index distinguishes the contributor guide from
agent/developer guidance. Historical reports/evidence are unchanged; the previous
CONTRIBUTING.md remains in accepted Git history. No unrelated cleanup is included.

The owner explicitly resolved the issue's documentation-only wording versus the
existing version policy: increment **v0.1.0.106 → v0.1.0.107**, with no exception.
The corrective release will use the latest accepted identity after this PR is
merged. No tag, release, package or release-note change is part of this issue.

## Focused validation

- PASS: all 53 local links/anchors in the edited documents resolve; the Issues
  route agrees with enabled live repository metadata.
- PASS: Markdown heading spacing and manual prose review; contributor guide is
  free of milestone/build/commit archaeology and internal test/packaging mechanics.
- PASS: policy-retention check for renderer, UIDs, notice sync, history,
  versioning, privacy and owner-review safeguards.
- PASS: `python -m unittest tests.test_application_version -v` — 2 tests.
- PASS: `python tools/sync_about_notices.py --check`.
- PASS: `git diff --check`.
- PASS: unchanged LICENSE, TRADEMARKS, third-party legal texts, notice resource
  and packaging implementation checked against the accepted baseline.

An initial one-off link checker treated same-document anchors as a directory;
its interpretation was corrected and the complete check rerun successfully.
No product link defect was attributed to that checker failure.

This documentation change plus required version metadata has no runtime logic
blast radius. GPU, scientific, playback, camera, packaging and full regression
suites were skipped. No browser rendering or interactive viewer testing was run.

## Owner verification

1. Read CONTRIBUTING.md as a newcomer with repository access: confirm realistic
   participation options, prior arrangement and licensing language.
2. Follow README, Getting Started, handbook and Issues links. Confirm no
   Discussions or unrestricted PR process is promised.
3. Review the internal-policy retention map above and the AGENTS.md additions.
4. Confirm candidate v0.1.0.107 follows the standing policy. Handle any corrective
   release separately after accepting this PR; no publication is performed here.

Stop for owner review: no merge, auto-merge, issue closure, Project transition or
subsequent Ready issue work is authorized by passing checks.
