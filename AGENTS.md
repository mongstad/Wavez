# SimScope development

SimScope is the final project name. This directory is the sole authoritative root.
Read README.md, docs/CURRENT_STATUS.md and CONTRIBUTING.md before making changes.

- Preserve accepted G0–G4 behavior. Post-G4 maintenance is authorized; G5/G6 and web/dashboard work require separate authorization.
- Support SIMSCP3 / SceneCapture / SceneReader only; see docs/CAPTURE_FORMAT_POLICY.md. Do not restore retired capture APIs.
- GitHub Issues, milestones and the SimScope Development project are the authoritative operational work queue. Work only on an issue that has been explicitly placed in a state that authorizes implementation; do not start unrelated issues opportunistically.
- For each authorized issue, create a dedicated branch from the current `main` baseline before making code or documentation changes. Prefer names such as `issue-<number>-<short-slug>`. Keep one issue per branch unless the owner explicitly approves a combined change.
- Never commit directly to `main`. Never push changes directly to `main`. Never merge a branch or pull request into `main`. `main` is owner-controlled and may change only through explicit owner review and approval.
- Push work only to the dedicated issue branch, then open or update a pull request targeting `main`. Reference the issue in the pull request, summarize implementation and validation, and stop for owner review. Do not enable auto-merge or otherwise arrange for unattended merging.
- Do not close an issue merely because implementation is complete. Leave final acceptance/closure to the owner or to the reviewed merge workflow explicitly approved by the owner.
- Never change repository visibility. Do not make the repository public, private, or otherwise alter visibility under any circumstance. Do not rename, transfer, archive, delete, or change the default branch of the repository, and do not modify repository administration, access, security, branch-protection or ruleset settings unless the owner gives an explicit instruction for that exact administrative change.
- Git is authoritative history. Commit meaningful completed checkpoints on the active issue branch and push reviewable work to the private origin. Synchronize canonical docs; use semantic versions and tags, never versioned folders.
- Inspect staged content, sizes and secrets before committing. Never commit credentials, environments, caches, captures or large scientific results. Preserve useful history.
- Keep external simulations and research projects outside this repository. Use synthetic fixtures or explicit external paths for optional integration tests. Do not duplicate exporters.
- Validate relevant changes with small generated fixtures; avoid production scientific reruns for housekeeping.
- At the end of an authorized issue, report the branch, commit(s), files changed, validation performed, failures/skips, known limitations and pull-request state, then STOP and await owner review unless explicitly instructed otherwise.
