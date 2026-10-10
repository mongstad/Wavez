# AI-agent source access revision — PR #339

Addresses the [Part III owner refinement](https://github.com/mongstad/Wavez/pull/339#issuecomment-6102759069)
on the existing #95 branch. Candidate **v0.1.0.92** remains unchanged; owner
review is pending. Previous evidence is preserved as a historical record.

The guide and its copyable prompt now name the canonical repository URL.
The prompt checks for workspace docs/exporter source, retrieves missing files
through authorized repository access, and asks the user for necessary files if
access fails. Both explain that the private repository's URL alone grants no access.
The prompt retains scientific integration safeguards and reports unavailable checks.

## Validation

- [Documentation report](documentation.json): all **34** local guide links and
  anchors pass. The **132-word** prompt includes the access sequence, all five
  requested documents and the owner's integration/validation/reporting requirements.
- `gh repo view` confirms the canonical URL and current private status.
- `SceneCapture` exclusive output paths, strict `SceneReader`, `audit_identity()`,
  source precision, provenance and actual solver-time/independent-cadence rules
  were cross-checked against current source and authoritative contracts.
- Outside the AI-prompt section, the guide is byte-identical to review commit
  `1a648e0a2a7670b786932b8b6c446ce557f48727`. All **4,084** other preexisting
  tracked files are byte-identical, including the examples, technical documents,
  packaging, application version and historical evidence.
- `git diff --check` passed.

Python, renderer and package suites were not rerun for this prose-only revision.
Their [initial](../README.md) and [desktop revision](../revision-1/README.md)
results remain historical. No external AI-agent session or access-denied scenario
was executed; prompt compliance depends on the agent and access supplied by the user.

## Owner verification

Review the copyable prompt alone: it must identify the repository, explain private
access, request docs/source when unavailable, and retain the scientific safeguards.
The [desktop-neutral Linux revision](../revision-2/README.md) remains unchanged.
Stop for owner review; packaging work remains separate.
