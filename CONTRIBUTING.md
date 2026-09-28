# Development checkpoints

SimScope is the final name. Keep the project root unversioned. Git is the authoritative
history; preserve existing commits and use meaningful completed checkpoints, not trivial
per-edit commits. Push accepted checkpoints to the private origin. Never commit secrets,
local environments, raw scientific datasets, generated captures or profiling output.
Inspect `git diff --cached`, staged names and sizes before each commit.

Keep canonical documentation synchronized. G4 is accepted; post-G4 maintenance is authorized.
G5/G6 and web/dashboard work require separate authorization. Preserve accepted G0–G4
behavior and run focused relevant validation. New work targets `.ssc` / SIMSCP4 under
the [capture format policy](docs/CAPTURE_FORMAT_POLICY.md).

Application identity follows [the version/build policy](docs/VERSIONING.md):
`viewer/project.godot` → `application/config/version` is the sole source, displayed
as `vMAJOR.MINOR.PATCH.BUILD`. Every future accepted implementation PR must carry
exactly `main.BUILD + 1`; keep that candidate unchanged through review commits,
and reconcile with current accepted main before merge. BUILD never resets.
Only the owner declares MAJOR/MINOR/PATCH changes. No release automation is added.

The Python exporter package has its own compatibility version: #102 advances it
to `3.0.0` for the clean SIMSCP4 break. Application release tags normally use
`vMAJOR.MINOR.PATCH`; implementation alone does not create a release tag or GitHub
Release. Historical viewer directory
`v1.0.3` was not a package release. The descriptive `pre-g4-consolidation` tag
records a historical checkpoint without claiming a new release.
No force pushes or history rewrites without a documented need and authorization.

Commit Godot `.gd.uid` and `.gdshader.uid` sidecars with their source files.
They preserve resource identity across fresh imports and file moves; do not ignore
or regenerate existing tracked UIDs. Include the sidecar when moving or deleting
its script/shader. Godot's `.godot/` import cache remains ignored. Before opening a
PR, import the viewer and check `git status` for newly generated sidecars.
