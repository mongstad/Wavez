# Issue #94 — handbook and technical-index editorial revision

Implements the [owner's iteration-1 feedback](https://github.com/mongstad/Wavez/pull/386#issuecomment-6129092295)
on existing draft PR #386, 2026-10-12. Based on first-draft commit `db59df3`;
candidate remains **v0.1.0.104**. This is another editorial review, not acceptance.

## Changes

- Root README retains its branding, screenshot placeholders, feature selection,
  early experimental Analysis caveat, dependencies and provisional requirements.
  Its direct scientific-contract link is replaced with **Technical Documentation**.
- New `docs/TECHNICAL_DOCUMENTATION.md` has a sectioned table of contents for
  scientific values/analysis, capture/API integration, saved state/exports,
  playback/resources, viewer/runtime and development/validation. References are
  selected by purpose, not an uncurated list of evidence reports.
- The handbook is edited throughout for ordinary users: task instructions,
  expected results and actions for Preparing/Ready/Playing/Buffering/Unavailable;
  status percentages retain their field-interval meaning. Jobs/failures, camera,
  appearance, probing and export/recovery stay actionable. Its whitespace word
  count drops from **7,084 to 2,831** (594 to 328 lines).
- Pixel dimensions, status delays, worker/concurrency thresholds, CPU/GPU ownership,
  benchmarks, exact cache allocations and shader/schema details are removed from
  the handbook. Useful detail already remains in the linked technical references:
  `STATUS_PLAYBACK_STATE.md`, `ORBIT_GIZMO.md`, preparation/cache guides and contracts.
  Those references are not rewritten.
- The former orbit paragraph conflated marker size with applied camera distance.
  User instructions now follow the current `ORBIT_GIZMO.md` and
  `viewer/ui/shell/orbit_center_editor.gd`: Gizmo radius sizes the guide;
  Place ahead uses its separate depth; Apply starts from the current camera position;
  camera-to-center distance determines orbit size. No navigation behavior changes.
- Active opacity instructions use current Fields → Color Mapping / Opacity,
  Magnitude, Opacity strength, Rendering → Ray step, and Tools → Derive range →
  Reset opacity labels checked against `viewer/layers/scene_layers.gd`.
  The old `controls.png` embed/caption is removed, not the historical file.

## Retained scientific meaning and untouched material

Every handbook chapter received an editorial pass; no substantial chapter was
deliberately left verbatim. The layer-time table keeps exact/interpolated/held,
anonymous/static and incompatible-topology meanings. Explicit identities, units
and coordinates, source-versus-derived values, nonfinite probe support, preview
precision, approximate isosurfaces, independent color/opacity, verification limits,
experimental Analysis, export time/pixel limits and recoverable outputs remain.
The handbook's established major headings are retained, so existing inbound
anchors continue to resolve.

Canonical scientific/format/API/state/resource references, licensing, branding
assets, runtime and the original first-draft evidence are untouched. In the opacity
document, only current controls/navigation and the obsolete embed change; historical
validation text, other historical images, old format/renderer findings and review-time
wording remain as written. The preserved obsolete image SHA-256 is
`0b35da5c0baa9fa2c998d605fd1e204695d1b7f0b889cf72c1ea17229c171733`.

## Focused verification

All **151 local Markdown references** and **3 existing inbound handbook anchors**
resolve. GitHub's GFM renderer is exercised for README, handbook
and opacity guide; the technical index receives local Markdown structure/link
validation instead. Automatic approval review rejected sending the new technical
index to GitHub's Markdown API as an unapproved private-content export. That
endpoint was not retried or bypassed. The authorized existing-branch/PR update
continues; the index's final GitHub visual review remains an owner step.
The obsolete screenshot is absent from the
active guide, its historical bytes match, and accepted wordmarks/placeholders
are unchanged. Whitespace and staged text/size/credential-pattern checks apply.
All changes in this iteration are documentation; build remains 104.

No new automated test, runtime/import/rendering suite, package build, simulation
or screenshot pipeline is needed for these prose/link changes. First-draft version
tests and import evidence retain their original scope and are not counted as fresh
runtime validation. Raw rendering/check output stays outside Git under
`/home/Nozba/Codex/Wavez/readme-94/iteration-2/`.

## Owner review / remaining decisions

Review the handbook's task flow and retained scientific caveats, and whether the
technical index's grouping/depth serves its audience. Final current-shell showcase
and matched-data/time Python/Wavez comparison images still need owner selection;
the agreed placeholders remain. No new application behavior or scientific-policy
decision is required by this revision. Continue editorial rounds on this same PR.
