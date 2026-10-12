# Issue #94 — focused user-facing editorial cleanup

Implements the [owner's next focused pass](https://github.com/mongstad/Wavez/pull/386#issuecomment-6129930874)
on existing draft PR #386, 2026-10-12. Based on `da151c7`; candidate remains
**v0.1.0.104**, pending another owner editorial review.

## Changes

- README's visible Development status is now one short experimental/incomplete
  Analysis note with independent verification advice. Detailed #341/#342 backlog
  links and repeated workflow-problem explanations are removed.
- Handbook's panel resize/pin/hover/narrow-window paragraph is deleted. Routine
  navigation-mode defaults and duplicate job-panel closing prose are trimmed;
  background export wording is direct rather than teaching window minimization.
- Color legends now explain object/channel, colormap, numeric range, particle
  range policy and volume opacity/threshold meaning. Default visibility and
  ordinary visibility-setting instructions are removed.
- The complete Roadmap boundary section is removed. Handbook introduction keeps
  a brief experimental-analysis caveat without the repeated usability discussion.

Fullscreen edge access remains as Wavez-specific recovery for hidden controls.
Close File allowing video exports to continue, active-job exit cancellation,
closing a Jobs panel without cancelling work, explicit cancellation and failure
recovery remain because they affect use. Scientific meanings, units, sampling,
precision/integrity and export limitations are unchanged.

## Preserved direction and checks

Existing branding, hero/comparison placeholders, core feature selection,
dependency and provisional hardware guidance, technical index and substantive
scientific handbook sections are untouched. Historical assets and earlier review
records remain byte-identical; runtime/build is unchanged.

Focused checks pass for **102 local Markdown references** and **3 existing inbound
handbook anchors**, removed text/issue links, retained scientific/job caveats, Markdown-only
scope and whitespace. No new runtime/import/benchmark suite or remote Markdown
rendering is needed for this small prose-only pass. Final GitHub visual/editorial
review and owner selection of screenshots remain pending; no new feature or
scientific-policy decision is required.
