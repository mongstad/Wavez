# Development checkpoints

WAVEZ is the application brand; use Wavez in ordinary prose. Keep the project root unversioned. Git is the authoritative
history; preserve existing commits and use meaningful completed checkpoints, not trivial
per-edit commits. Push accepted checkpoints to the private origin. Never commit secrets,
local environments, raw scientific datasets, generated captures or profiling output.
Inspect `git diff --cached`, staged names and sizes before each commit.

Keep canonical documentation synchronized. G4 is accepted; post-G4 maintenance is authorized.
G5/G6 and web/dashboard work require separate authorization. Preserve accepted G0–G4
behavior and run focused relevant validation. GPU validation and supported launches
use Forward+ Vulkan only; see [renderer requirements](docs/RENDERER_REQUIREMENTS.md).
Historical Compatibility reports remain provenance, and headless checks validate
CPU contracts only. New work targets `.wvz` / WVZ1 under
the [capture format policy](docs/CAPTURE_FORMAT_POLICY.md).

Application identity follows [the version/build policy](docs/VERSIONING.md):
`viewer/project.godot` → `application/config/version` is the sole source, displayed
as `vMAJOR.MINOR.PATCH.BUILD`. Every future accepted implementation PR must carry
exactly `main.BUILD + 1`; keep that candidate unchanged through review commits,
and reconcile with current accepted main before merge. BUILD never resets.
Only the owner declares MAJOR/MINOR/PATCH changes. No release automation is added.

The Python exporter package has its own compatibility version: WVZ1 advances it
to `4.0.0` for the clean format break. Application release tags normally use
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

About packages canonical licensing notices as a preloaded resource. After editing
LICENSE, THIRD_PARTY_LICENSES.md, TRADEMARKS.md or the bundled font/colormap notices,
run `python tools/sync_about_notices.py`, then verify with `--check`. See
[About resources](viewer/ui/about/README.md). Do not independently edit generated
notice text or copy externally installed runtimes into the repository.
