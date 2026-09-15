# Development checkpoints

SimScope is the final name. Keep the project root unversioned. Git is the authoritative
history; preserve existing commits and use meaningful completed checkpoints, not trivial
per-edit commits. Push accepted checkpoints to the private origin. Never commit secrets,
local environments, raw scientific datasets, generated captures or profiling output.
Inspect `git diff --cached`, staged names and sizes before each commit.

Keep canonical documentation synchronized. G4 is accepted; post-G4 maintenance is authorized.
G5/G6 and web/dashboard work require separate authorization. Preserve accepted G0–G4
behavior and run focused relevant validation. New work targets `.ssc` / SIMSCP3 under
the [capture format policy](docs/CAPTURE_FORMAT_POLICY.md).

Version strategy: the pre-UX capture retirement advances the exporter to `2.0.0`
because removing public particle APIs is a breaking change. Use semantic package
versions and annotated `vMAJOR.MINOR.PATCH` tags for reviewed stable releases;
implementation alone does not create a release tag. Historical viewer directory
`v1.0.3` was not a package release. The descriptive `pre-g4-consolidation` tag
records a historical checkpoint without claiming a new release.
No force pushes or history rewrites without a documented need and authorization.
