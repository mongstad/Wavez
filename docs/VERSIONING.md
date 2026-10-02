# Wavez application version and build policy

Issue #131 established the application identity (owner-merged in PR #132). The sole
mutable source is `application/config/version` in
[`viewer/project.godot`](../viewer/project.godot). Godot runtime and exported
project settings consume that value. Help → About displays the identity
with or without a capture. #96 consolidates the temporary Version menu into About;
version ownership and the numbering convention are unchanged.

The display form is exactly `vMAJOR.MINOR.PATCH.BUILD`. Each component uses
canonical decimal digits without leading zeroes; release components are
non-negative, and BUILD is positive. BUILD has no three-digit ceiling.

## Initial identity

The starting identity was **v0.1.0.1**. This establishes a pre-1.0
application development family and makes acceptance of #131 build 1. Earlier
merges are not numbered retroactively. The number does not imply a public release,
stability guarantee, or a change to the project's compatibility policy.

## Accepted merges and releases

- BUILD is the lifetime integration counter. Every future accepted merge to
  `main` increases it by exactly one, including documentation-only changes.
  It is independent of issue numbers, PR numbers, commit count and GitHub Releases.
- A PR proposes `current accepted main.BUILD + 1` in the authoritative setting.
  Do not increment again for fixes, review commits or pushes on that PR. A branch
  shows a candidate identity; only owner acceptance/merge makes it an accepted
  build. An abandoned PR consumes no number.
- Before owner merge, compare with current accepted main. If another PR merged
  first, reconcile this PR to the new `main.BUILD + 1` and rerun version checks.
  Never resolve a version conflict by keeping a stale or skipping build number.
  This is a documented review step, not automatic merge enforcement.
- Ordinary merges change BUILD only. MAJOR/MINOR/PATCH change only when the owner
  explicitly declares a release-level change. PATCH marks published maintenance,
  fixes or polish. MINOR marks significant features/milestones and normally resets
  PATCH to zero. MAJOR marks a product/architecture or compatibility generation
  and resets MINOR/PATCH as appropriate. BUILD never resets during these changes.
- Public release tags/GitHub Releases normally use `vMAJOR.MINOR.PATCH`, such as
  `v0.2.1`. Internal landmarks may use descriptive names. Creating a release or tag
  requires separate owner authorization; this issue creates neither.

For example, an ordinary merge may move `v0.1.0.36` to `v0.1.0.37`. A subsequent
owner-declared maintenance release would be `v0.1.1.38`; a later feature release
could be `v0.2.0.76`. Crossing build 999 produces build 1000, not a reset.

Git commit SHAs and PR links remain provenance, separate from the application
number. Record `git rev-parse HEAD` alongside the identity in build/review records;
do not generate the application BUILD from Git history or a PR identifier.

## Runtime and tooling

[`application_version.gd`](../viewer/application_version.gd) validates the live
project setting and provides the full identity, public release version and BUILD.
About explicitly says **Wavez version unavailable** with a
metadata diagnostic if the setting is missing or malformed; it does not invent a
default version or prevent opening a scientific capture.

Packaging/release tooling can consume the same source without Godot or NumPy:

```sh
python tools/application_version.py
python tools/application_version.py --release
python tools/application_version.py --json
python tools/application_version.py --project /path/to/viewer/project.godot
```

The default prints the full identity. JSON returns `full`, `release` and `build`
as strings, preserving large BUILD values exactly. Malformed or missing metadata
returns a nonzero exit status with a diagnostic on stderr and no version on stdout.
There is no duplicated version literal to synchronize in scripts, UI or a separate
manifest. Godot carries the normal project setting into exports; custom non-resource
files/export inclusion filters are unnecessary. No packaging or release automation
is introduced. The application identity is separate from the Python exporter
package's existing compatibility version and from the SIMSCP4 file-format version.

## Validation and owner verification

The [initial validation report](VERSIONING_VALIDATION.md) records runtime/export
checks, the source-change experiment, existing-test corrections and limitations.

Run the Python metadata/CLI contract checks with:

```sh
python -m unittest tests.test_application_version
```

The existing `tools/validate_viewer_shell.py` suite exercises Help → About,
changes the live source setting, checks explicit missing/malformed fallback and
restores it before continuing existing viewer regressions. Both supported renderers
must pass. Source metadata changes need no duplicate manual UI edit.

Owner verification: open Help → About before and after opening a capture;
check the full four-component identity against the project setting.
Check ordinary startup, capture opening and playback. Review the initial numbering
and future merge/release convention before accepting this issue.
