# Issue #401 standalone package review record

Accepted baseline: `ec3386efcbffd31b30b70003989bdc89aa7a49f4`, v0.1.0.109,
owner-merged #399 / PR #400; #397 / PR #398 is an ancestor. Candidate:
**v0.1.0.110**, one BUILD increment. Owner review and publication remain pending.

## Prior archive and exact 21-link classification

The unpublished prior ZIP has 177 members, 40,507,490 bytes and SHA-256
`efc4ba7d203f66b0f1c621d778613c5fae0c7b394fb8b47f01a13bdb39af519c`.
Its bytes/checksum were verified, not replaced, renamed or reused. The complete
prior member list is in [previous-members.json](previous-members.json).
The 21 reported failures belong to source/developer/status consumers. Source API
and inspection-state contracts can help advanced users in the source archive,
but are not needed to launch/use the standalone viewer. No license/runtime path
was among these failures. Existing README/governance local links passed; those
source documents nevertheless depend on developer material outside a small
end-user package and are replaced there by dedicated usage guidance.

| Referring document | Exact unresolved target | Classification | Resolution |
|---|---|---|---|
| `docs/TECHNICAL_DOCUMENTATION.md` | `../WAVEZ_API.md` | Source API/state or developer setup reference | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/TECHNICAL_DOCUMENTATION.md` | `../INSPECTION_STATE.md` | Source API/state or developer setup reference | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-94/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-94/iteration-2.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-94/iteration-3.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-382/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-377/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-378/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-343/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-340/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-331/vertical-movement/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-329/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-335/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-326/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `evidence/issue-95/README.md` | Historical review evidence | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `../WAVEZ_API.md` | Source API/state or developer setup reference | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `../QUICKSTART.md` | Source API/state or developer setup reference | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `../INSPECTION_STATE.md` | Source API/state or developer setup reference | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `documentation-audit/README.md` | Developer audit/provenance | Exclude referring developer document from standalone; retain source link unchanged |
| `docs/CURRENT_STATUS.md` | `../PROVENANCE.md` | Developer audit/provenance | Exclude referring developer document from standalone; retain source link unchanged |
| `AGENTS.md` | `viewer/ui/about/README.md` | Source API/state or developer setup reference | Exclude referring developer document from standalone; retain source link unchanged |

## Inclusion and exclusion rationale

The explicit file policy is `tools/distribution_files.py`. Its 15 members comprise
the executable/PCK, generated install/manifest, two package-specific user guides,
three root legal/inventory files and six canonical notice/provenance files.
Runtime assets remain inside the PCK. No canonical license, attribution, pinned
notice digest or offline About text changes. Repository README, handbook, policy,
agent safeguards and historical reports are preserved as source guidance.

Package-context templates live in `docs/standalone/` and map to root README and
Getting Started. They cover installation/recovery, opening WVZ1, basic controls,
image/video export, optional external dependencies, experimental scientific
limits and offline notice access. Detailed guides/developer access are explicit
online source URLs; no broken local substitute is offered. The source archives
remain subject to repository permission. No public-access promise is introduced.

New source documentation cannot enter a ZIP through globbing. Exact membership,
canonical copies, manifest coverage, executable/PCK build hashes and all extracted
Markdown offline links are enforced together. New regression cases reject broken
files/images/reference links/anchors, package-escaping paths, and manifest-covered
internal additions. Actual export/extracted-package results follow below.

## Actual candidate-package validation

Fresh review archive built from clean committed issue implementation checkpoint
`a1a46a439f5900fb24ef6ba82944df132323cdf7`. The later evidence-only commit records these results;
it changes no package input. This is not a final accepted-main release. After
owner merge, build a new final archive from accepted main; retain this review
archive and the prior v0.1.0.109 artifacts unchanged.

- PASS: 13 focused distribution/version tests, including existing legal/integrity
  negative gates and new allowlist/extracted-link gates.
- PASS: headless Godot 4.7.2 import/export/assembly; no errors/warnings in final
  build or notice logs. Seven exported offline About texts match source.
- PASS: actual ZIP extracted outside the repository; all 15 members match staged
  bytes and manifest hashes; all canonical files match mapped committed source.
- PASS: **15 offline document links**, **8 intentional external/source links**,
  zero unresolved offline files/anchors. No internal docs/evidence/source files
  enter the ZIP.
- PASS: actual extracted PCK reports `EXPORTED_APPLICATION_VERSION=v0.1.0.110`
  and `EXPORTED_NOTICE_RESOURCE=PASS` headlessly; no Main/viewer/GPU started.
- PASS: pinned legal texts/digests, inventory literal paths, About resource,
  repository policy and older historical evidence are unchanged from baseline.
- PASS: ZIP checksum verification; previous v0.1.0.109 ZIP/checksum unchanged.

Final inventory/results are in [review-verification.json](review-verification.json).
Review artifact location outside Git:
`/home/Nozba/Codex/Wavez/issue-401-review/package/` (ZIP, SHA256SUMS.txt,
BUILD_MANIFEST.json, extracted contents, build/notice/version logs).

`Wavez-v0.1.0.110-linux-x86_64.zip`: **37,728,097 bytes**, SHA-256:
`213eb40b0d9d3c26fa7e82490e88cb1f1fb0c9657f60423e1f15193d3fd12b05`.

No GUI/GPU, capture-loading, scientific or long-session regression run was
performed: this change affects document selection and archive verification, not
scientific/runtime paths. External web URLs were counted, not fetched; repository
access and Markdown reader navigation remain owner checks. No tag, publication,
asset upload, visibility change, issue closure or owner acceptance is implied.

## Owner verification

1. Review `tools/distribution_files.py` and the inclusion-policy table; confirm
   the 15-member boundary meets standalone user/legal needs.
2. Extract the review ZIP outside the source checkout. Read README and Getting
   Started; follow all offline links, or open literal notice filenames directly.
3. Confirm developer/source links are explicitly online and permission-bound;
   developer status/evidence trees are absent while full license texts remain.
4. Review all 21 prior-link classifications and the exact old/new inventories.
5. Before merge, confirm BUILD remains accepted main + one. After acceptance,
   build a fresh final package from accepted main and separately authorize any
   release publication. The release hold remains active.
