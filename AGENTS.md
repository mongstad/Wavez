# Wavez development

WAVEZ is the application brand; use Wavez in ordinary prose. This directory is the sole authoritative root.
Read README.md, docs/CURRENT_STATUS.md and CONTRIBUTING.md before making changes.

- Preserve accepted G0–G4 behavior. Post-G4 maintenance is authorized; G5/G6 and web/dashboard work require separate authorization.
- Support WVZ1 / SceneCapture / SceneReader only; see docs/CAPTURE_FORMAT_POLICY.md. Do not restore retired capture APIs.
- Backward compatibility is not a project requirement unless the owner explicitly states otherwise for a specific issue or interface. Prefer clean current architecture over legacy support, compatibility shims, fallback parsers, migration layers, or preserving retired behavior. If a change would break existing files, APIs, formats, recipes, or workflows, document the break clearly and update the current writer/reader/tests/docs together. Do not add backward-compatibility complexity proactively. Separate one-time migration/conversion tooling may be proposed when old data has clear value, but it is not required by default.
- GitHub Issues, milestones and the Wavez Development project are the authoritative operational work queue. Work only on an issue that has been explicitly placed in a state that authorizes implementation; do not start unrelated issues opportunistically.
- Keep the Wavez Development project status synchronized with the actual issue workflow. The expected lifecycle is **Ready → In Progress → Review → Done**:
  - when an agent selects an authorized issue from **Ready** and begins work, move that issue to **In Progress** immediately;
  - while implementation, validation, documentation, commits, or PR preparation are ongoing, keep it in **In Progress**;
  - when implementation is complete, the branch is pushed, and the pull request is open and ready for owner review, move the issue to **Review**;
  - agents must not move an issue to **Done** merely because their implementation work is complete. **Review → Done** remains owner-controlled through acceptance/merge or another explicit owner instruction.
  - if work is paused or blocked before a reviewable PR exists, do not misrepresent it as **Review**; keep it **In Progress** unless the owner explicitly chooses another project state.
- For each authorized issue, create a dedicated branch from the current `main` baseline before making code or documentation changes. Prefer names such as `issue-<number>-<short-slug>`. Keep one issue per branch unless the owner explicitly approves a combined change.
- Never commit directly to `main`. Never push changes directly to `main`. Never merge a branch or pull request into `main`. `main` is owner-controlled and may change only through explicit owner review and approval.
- Push work only to the dedicated issue branch, then open or update a pull request targeting `main`. Reference the issue in the pull request, summarize implementation and validation, and stop for owner review. Do not enable auto-merge or otherwise arrange for unattended merging.
- Do not close an issue merely because implementation is complete. Leave final acceptance/closure to the owner or to the reviewed merge workflow explicitly approved by the owner.
- Never change repository visibility. Do not make the repository public, private, or otherwise alter visibility under any circumstance. Do not rename, transfer, archive, delete, or change the default branch of the repository, and do not modify repository administration, access, security, branch-protection or ruleset settings unless the owner gives an explicit instruction for that exact administrative change.
- Git is authoritative history. Commit meaningful completed checkpoints on the active issue branch and push reviewable work to the private origin. Synchronize canonical docs; use semantic versions and tags, never versioned folders.
- Follow `docs/VERSIONING.md`: the sole application identity is `application/config/version` in `viewer/project.godot`. After #131 establishes the starting build, each future implementation PR proposes exactly the accepted `main` BUILD plus one, once per PR rather than per review commit. Reconcile against current main before owner merge; BUILD never resets. Change MAJOR/MINOR/PATCH only on explicit owner release instruction. Do not create tags or Releases without authorization.
- Inspect staged content, sizes and secrets before committing. Never commit credentials, environments, caches, captures or large scientific results. Preserve useful history.
- Keep external simulations and research projects outside this repository. Use synthetic fixtures or explicit external paths for optional integration tests. Do not duplicate exporters.
- Validate relevant changes with small generated fixtures; avoid production scientific reruns for housekeeping.

### Risk-based validation

Validation scope must be proportional to the change and its plausible blast radius. Do not run the full application regression suite automatically for every issue.

- **Small/local UI or text changes:** run focused tests for the modified component and its immediate interaction paths only.
- **Subsystem changes:** run the affected subsystem tests plus directly connected integration boundaries.
- **Cross-cutting runtime changes:** run broader regressions covering the systems plausibly affected.
- **Scientific format, reader/writer, rendering architecture, playback/cache core, or release-critical changes:** use comprehensive validation appropriate to the affected contracts, including renderer/package checks where relevant.

Prefer the **smallest test set that provides strong evidence for the actual change**.

Do not run unrelated camera, playback, field, mesh, video, analysis, packaging, or scientific-integrity suites merely because they exist.

Expand validation when a focused test reveals a regression, the changed code is shared by multiple subsystems, or investigation demonstrates a wider blast radius.

Examples:

- Changing file-dialog wording/filtering → file-dialog/open/cancel/filter tests and packaged/native integration where relevant; **not** the full playback/rendering suite.
- Changing button spacing → focused UI/layout checks.
- Changing camera-state code → camera/navigation tests and directly affected persistence/export paths.
- Changing WVZ1 reader/writer → comprehensive scientific-format/integrity/runtime validation.
- At the end of an authorized issue, report the branch, commit(s), files changed, validation performed, failures/skips, known limitations and pull-request state, then STOP and await owner review unless explicitly instructed otherwise.
- Preserve third-party licensing boundaries. Do not vendor, copy, commit, or redistribute third-party tools, executables, runtimes, libraries, fonts, datasets, or other assets unless the repository explicitly documents them as bundled and their license obligations have been reviewed. In particular, dependencies listed in THIRD_PARTY_LICENSES.md as external/not vendored — including Godot Engine and FFmpeg — must remain externally installed and must not be added to the repository. If implementation appears to require bundling a new third-party component, STOP and request owner review before adding it.


## Blender / 3D asset preservation

- For any task that creates or modifies 3D assets in Blender, save useful editable Blender source projects (`.blend`) to an appropriate repository-controlled asset-source location before completing the task. Do not leave valuable completed work only in a live Blender/MCP session, unsaved scene, or temporary/headless workspace.
- Preserve editable source models in addition to runtime/exported assets such as `.glb` / `.gltf`. Prefer retaining useful intermediate models, experiments and iterations over deleting them; the owner may perform manual cleanup later.
- Do not delete or overwrite an existing Blender source project unless the owner explicitly authorizes it.
- Use descriptive filenames and keep Blender source assets separate from runtime/exported assets where practical.
- Save useful current Blender work before ending a Blender/MCP task, even when final runtime integration is not yet complete.
- When a final 3D asset is accepted, retain both the authoritative editable `.blend` source and the runtime asset(s) used by WAVEZ.
- Do not commit Blender autosaves, caches, temporary renders, Python virtual environments, MCP tooling, Blender installations, or clearly disposable generated working files. Blender/MCP/Codex tooling remains external unless the owner explicitly authorizes vendoring after license review.
