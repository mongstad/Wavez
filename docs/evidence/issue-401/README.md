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
