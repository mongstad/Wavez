# Issue #299 documentation audit

**Candidate build 77, pending owner review.** #299 was the sole Ready item on
2026-10-08. The exact owner-created branch is
`299-docs-cleanup-audit-and-retire-obsolete-simscopemilestone-documentation-before-public-readme`,
clean at accepted `ca220d30163d4a76efd652933c8c963a564c315d` (PR #298, build 76)
before edits. Main/origin/branch matched, fetch/prune completed, and the previous
issue branch was absent. No acceptance-only PR or new branch was created.

## Inventory and decisions

The [content inventory](CONTENT_INVENTORY.md) contains one row for each of the
**248 baseline Markdown files**: path, inspected purpose, current/historical
classification, incoming-reference count, authoritative replacement and action.
The [complete CSV](inventory.csv) records all **1,747 baseline documentation files**,
including evidence logs, screenshots, JSON, scripts and legal text, with size,
SHA256, complete incoming text/link references and rationale. It was generated
before any retirement. References were mapped across all tracked text, including
AGENTS/README/CONTRIBUTING, tools, tests, code and frozen evidence.

Decisions use contents and dependencies, not filename age. A current spec is
renamed/updated; an obsolete checkpoint is retired only after its live contracts
have destinations. Bare paths in frozen JSON/logs remain recorded provenance.
Navigable historical links use the exact accepted Git tree when needed.

| Candidate | Classification / decision | Live contract destination / reason |
| --- | --- | --- |
| `G2_STORAGE.md` | Delete obsolete storage/checkpoint narrative | [WVZ1 wire](../WVZ1_FORMAT.md) and [format/API](../CAPTURE_FORMAT_AND_API.md) retain typed lossless chunks, identity, sampling, allocation and commit checks. Codec/timing measurements remain in the accepted Git tree. |
| `G3_REPORT.md` | Delete obsolete implementation report | Wire/render semantics remain in WVZ1 and current guides; the [evidence index](../EVIDENCE_INDEX.md) links its original report. |
| `G3_TIMELINE_FIX.md` | Delete completed bug checkpoint | Object-native/union timeline semantics remain in format/API and native timeline tests; original cause/results remain in Git. |
| `G4_REPORT.md` | Delete slice chronology | [Original accepted ledger](../G4_ACCEPTANCE.md) plus retained g4a–g4f JSON keep counts/limits; current analysis guide/schemas retain behavior. |
| `PLAYBACK_PERFORMANCE.md` | Delete obsolete baseline report | [Rolling cache](../ROLLING_PLAYBACK_CACHE.md), [particle admission](../PARTICLE_CACHE_CAPACITY.md), [mesh preparation](../MESH_PREPARATION_BUDGET.md) and retained performance reports govern current preparation. Old measurements are not new performance claims. |
| `SIMSCOPE_NEXT_DESIGN.md` | Delete obsolete roadmap | [Current boundaries](../CURRENT_STATUS.md), scientific analysis/acceptance and AGENTS retain live requirements; unimplemented service/event ideas remain in its Git record. |
| `G3_FORMAT.md` | Rename to `docs/WVZ1_FORMAT.md` | Canonical wire/scientific sampling body is identical except link destinations; remove milestone-shaped routing. |
| `G3_GUIDE.md` | Rename to `docs/SCENE_CAPTURE_GUIDE.md` | Preserve executable examples and geometry/units; route through current Simulation categories. This is the existing deeper guide, not #95 onboarding. |
| `G4_DESIGN.md` | Rename/modernize as `docs/SCIENTIFIC_ANALYSIS.md` | Retain selection/identity/topology, picking, clocks, precision, quadrature, worker/revision, export/state requirements and independent oracles. Replace old pre-implementation reconciliation, proposed budgets and completed sequencing with current source ownership/schema links. |
| `SIMSCOPE_ACCEPTANCE_MATRIX.md` | Rename/modernize as `docs/SCIENTIFIC_ACCEPTANCE.md` | Preserve all **74 B/I/D/V/A IDs**; clarify WVZ1, current Image Exports ownership, bounded header indexing and synchronous archival writing. Retire unimplemented G5/G6 proposal tables to Git, without claiming tests. |
| `docs/G4_SCHEMAS.md` | Rename to `docs/ANALYSIS_SCHEMAS.md` | Preserve exact schemas/limits; only preface, links and one future-tense description change. |
| `docs/G4_GUIDE.md` | Rename to `docs/ANALYSIS_GUIDE.md` | Preserve scientific walkthrough; correct `.wvz` demo filename and Tools → Selection route. The demo's generated guide receives the same documentation-string correction. |
| `VIDEO_EXPORT.md` | Rename/modernize as `docs/VIDEO_EXPORT.md` | Preserve timing formula, source binding, deterministic barriers, composition, quotas, cancellation and recovery. Correct retired verifier/profile names, job-version directions and Image Exports ownership. |
| `UX_IMPLEMENTATION_PLAN.md` | Replace at `docs/UX_WORKFLOW.md` | Preserve scientific/presentation isolation, design-source ownership, review gates and deferred-work boundaries. Remove completed milestone checklists and obsolete capture instructions; Project/issue authorization governs work. |

Retained candidates include WAVEZ_API, QUICKSTART, INSPECTION_STATE, AGENTS,
CONTRIBUTING, current format policy, handbook/status, legal and attribution docs.
Existing operational guides remain where they have unique semantics or recorded
measurements. SSC-era reports and the old About/UX1 inventory get explicit
historical prefaces with current destinations; their bodies are not rewritten.
Truthful SimScope references in PROVENANCE/legal/branding records remain.
No bulk format/name substitution or compatibility feature is introduced.

## Contract preservation and before/after overview

- Root Markdown files: **21 → 9**. Exactly **6 documents retired** and **8 live
  guides/specs moved/modernized** (six root documents and two existing docs guides).
  Total Markdown: **248 → 244**, including these two audit pages.
- `CURRENT_STATUS.md`: **804 → 101 lines**, with the accepted baseline, current
  source-of-truth table, resource/scientific limits and authorization/release
  boundaries. README and handbook lose stale milestone status routing.
- **1,586 historical evidence artifacts are byte-identical**. Two evidence
  Markdown files change only link destinations; recorded bodies/labels/outcomes
  remain identical. No old log, JSON, screenshot, patch or evidence script is removed.
- WVZ1 normative body matches accepted main after stripping link destinations.
  Analysis-schema body matches after the same normalization and one
  `will contain` → `contains` correction. The 74 scientific IDs survive.
  Exact-ID lifetime, contiguous topology epochs, native-clock support, float64
  source precision, cell/node quadrature and both 288/72 hand oracles remain.
- Application/library runtime code and scientific tests are unchanged. Exceptions
  outside Markdown are the mandated build **76 → 77**, two documentation audit
  tools (paths/anchor/provenance checks), and one generated-guide string.
  All 38 Python library files in the wheel and 40 release archive inputs match
  accepted main. AGENTS/CONTRIBUTING and canonical legal/provenance text are unchanged.
- #94 public README and #95 onboarding remain separate. No branding regeneration,
  repository visibility/admin change, solver rerun, release/tag, merge or auto-merge.

The living source-of-truth map is in [current status](../CURRENT_STATUS.md).
Retired full documents remain recoverable from the accepted Git tree; historical
incoming Markdown links point there. Frozen raw log/JSON paths remain meaningful
within that recorded revision rather than being silently rewritten.
The retained `docs/evidence/issue-14/check_review.py` is an original review-script
artifact tied to that old tree, not a current validation command. Its old plan
paths remain provenance; live tools/tests have no unresolved retired-document dependency.

## Focused validation

Commands run from the repository root; outputs/packages/profiles stay under
`/tmp/wavez-issue-299`. No captures, wheels, runtimes or third-party build assets
are committed.

- `python tools/validate_documentation.py --output-dir NEW_DIRECTORY`: all current
  **244 Markdown files, 1,961 local links and 10 fixed Git permalinks**, plus three source API
  examples with source hashes/declared units checked. [Final report](validation/documentation.json).
- `python tools/audit_branding.py --output OUTPUT.json`: remaining old-format/name
  references classified; no unclassified active identities or historical-body
  mutations. [Summary](validation/branding.json).
- Python wheel build via `pip wheel --no-deps`, with isolated build dependencies;
  install into a temporary target and run the same **3 examples from that wheel**.
  All create valid WVZ1 captures and preserve source hashes. [Report](validation/wheel.json).
- Documented small scene and analysis demo commands execute. Strict verifier checks
  **14 and 11 records** respectively, including payload/commit/sample constraints.
  The generated analysis guide uses the corrected Tools route.
- Linux resource staging: **40 first-party inputs**, exact accepted-main hashes,
  archive contents verified, external dependencies unvendored. [Report](validation/package-stage.json).
  This is resource/package wiring validation, not an exported executable run.
- Version unit suite: **2 PASS**; CLI reports `v0.1.0.77`. About notices `--check`,
  Python compilation, warm Godot import, AGENTS/local-path checks, contract/evidence
  preservation, diff whitespace and staged scope/size/credential checks pass.
  [Preservation report](validation/preservation.json),
  [exact contract/inventory comparisons](validation/contracts.json),
  [focused checks and limits](validation/focused-checks.json),
  [audit-tool negative controls](validation/audit-tools.json),
  [version test log](validation/version-tests.txt),
  [initial import](validation/import-stdout.txt) and
  [clean warm import](validation/import-final-stdout.txt).

This scope tests renamed documentation consumers, executable examples, package
metadata/resources, version identity and historical preservation. No application
behavior changed, so unrelated scientific, playback, GPU or video suites were not run.

## Failed/intermediate checks and limits

The original file-only link validator and three source examples passed before
edits. During drafting, four links to this not-yet-created report were temporarily
unresolved. The enhanced anchor check also found **two pre-existing broken anchors**
in UX2/shortcut evidence; their destinations are repaired without outcome edits.
[Baseline anchor evidence](validation/anchor-fixes.json) records both. Final checks
supersede those intermediate failures; no incomplete run is called a pass.

The first import recreated five unrelated missing UID sidecars from accepted cache
state; the unchanged warm import is clean. Those incidental files are excluded.
The host Python lacked setuptools/wheel, so wheel verification used pip's
isolated temporary build environment; nothing was installed into the user environment.

No GUI navigation/physical input, Forward+/Compatibility rendering, exported Linux
binary, other OS, large/research capture, long playback or video encoding run is
claimed here. External web links were not fetched; fixed repository Git permalinks
were verified against local Git objects, while relative file/heading links were
checked directly. Existing hardware/platform limitations remain in their reports.

## Owner verification

1. Review the six deletion decisions against the inventory and accepted Git
   permalinks. Confirm no unique live wire, inspection, analysis or UX requirement
   is lost, especially the 74 criterion IDs and the independent quadrature oracles.
2. Follow README → current status/format/API, handbook → analysis/video, and About's
   repository documentation route. Inspect the new guide locations, repaired
   anchors and historical evidence links in GitHub's rendered Markdown.
3. Run `python tools/validate_documentation.py --output-dir /tmp/OWNER_NEW_DIRECTORY`
   and `python tools/audit_branding.py --output /tmp/OWNER_NEW_REPORT.json`.
   Optionally repeat the small documented demos in fresh temporary destinations.
4. Confirm #94/#95 are still separate work and the repository remains private.
   Accept or request changes through the PR; implementation is pending owner review.
