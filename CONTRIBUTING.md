# Development and Maintenance Policy

Wavez is a private, owner-directed scientific visualization project. Repository
access, issue submissions, code contributions, branches and pull requests require
explicit owner authorization or invitation. No public contribution intake is
currently offered. This policy does not change GitHub repository visibility or
access settings.

## Authorized development

The owner prioritizes issues in the **Wavez Development** GitHub Project. Work
only on the authorized issue and its agreed scope; the **Ready** lane is the
implementation queue. Use the existing owner-created issue-linked branch based
on current accepted `main`. If the branch is missing, incorrect or stale, stop
and report the problem rather than creating or choosing a replacement.

Keep one focused pull request targeting `main`, describe the changes and relevant
validation results, and follow [developer guidance](AGENTS.md) and the
[version policy](docs/VERSIONING.md). Do not push directly to `main`. The owner
controls review, acceptance and merging; completion or passing checks does not
constitute acceptance. Stop for owner review after pushing the branch and opening
or updating the pull request. Do not merge, enable auto-merge, manually close the
issue or begin another issue without owner direction.

Submit reports, questions or proposals only when invited or authorized by the
owner. For an authorized bug report, include the Wavez version, relevant system
details, reproduction steps, expected and actual results, and useful logs or a
small example. Share only material you are permitted to share; remove secrets
and sensitive information.

## Licensing and releases

Original Wavez material uses the [PolyForm Noncommercial License 1.0.0](LICENSE).
It is **source-available**, not OSI-approved open source. Source availability is a
licensing distinction, not a promise of public repository access. Commercial use
requires a separate agreement. Third-party components retain their
[own licensing terms](THIRD_PARTY_LICENSES.md), and the name and artwork follow
the [branding policy](TRADEMARKS.md).

This policy creates no contributor license agreement, copyright assignment or
additional legal permission. Development authorization does not authorize tags,
release publication or artifact uploads; those require separate explicit owner
authorization.
