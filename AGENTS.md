# SimScope development

SimScope is the final project name. This directory is the sole authoritative root.
Read README.md, docs/CURRENT_STATUS.md and CONTRIBUTING.md before making changes.

- Preserve accepted G0–G4 behavior. Post-G4 maintenance is authorized; G5/G6 and web/dashboard work require separate authorization.
- Support SIMSCP3 / SceneCapture / SceneReader only; see docs/CAPTURE_FORMAT_POLICY.md. Do not restore retired capture APIs.
- Git is authoritative history. Commit meaningful completed checkpoints and push accepted work
  to the private origin. Synchronize canonical docs; use semantic versions and tags, never versioned folders.
- Inspect staged content, sizes and secrets before committing. Never commit credentials,
  environments, caches, captures or large scientific results. Preserve useful history.
- Keep external simulations and research projects outside this repository.
  Use synthetic fixtures or explicit external paths for optional integration tests. Do not duplicate exporters.
- Validate relevant changes with small generated fixtures; avoid production scientific reruns for housekeeping.
