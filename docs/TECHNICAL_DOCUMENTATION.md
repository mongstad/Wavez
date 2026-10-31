# Technical Documentation

Start with the [user handbook](WAVEZ_HANDBOOK.md) for ordinary viewer tasks or
[Getting Started](../GETTING_STARTED.md) for installation and Python examples.
This index selects detailed references for integration, scientific interpretation
and development; it is not a catalog of every implementation report.

## Contents

- [Scientific values and analysis](#scientific-values-and-analysis)
- [Capture format and Python integration](#capture-format-and-python-integration)
- [Saved state and export contracts](#saved-state-and-export-contracts)
- [Playback and resource policies](#playback-and-resource-policies)
- [Viewer behavior and runtime requirements](#viewer-behavior-and-runtime-requirements)
- [Development and validation](#development-and-validation)

## Scientific values and analysis

Selection/Analysis is experimental beyond its declared fixtures. Source fidelity,
derived computation and visual presentation have different guarantees.

- [Scientific integrity boundary](SCIENTIFIC_ANALYSIS.md#21-hardware-independent-scientific-integrity-boundary)
  — stored samples versus interpolation/reductions and GPU presentation.
- [Inspection-path audit](SCIENTIFIC_INTEGRITY_AUDIT.md) — scoped PASS, known
  limits and NOT VERIFIED paths; current native-probe precision/units caveats.
- [Scientific analysis contract](SCIENTIFIC_ANALYSIS.md) — identities, membership,
  native clocks, numerical policies, missing support and provenance.
- [Analysis schemas](ANALYSIS_SCHEMAS.md) — request/result/state structures and quotas.
- [Regional spatial spectrum](SPATIAL_SPECTRUM.md) — verified source support,
  Hann normalization, bounded radial diagnostics and interpretation limits.

## Capture format and Python integration

- [Supported-format policy](CAPTURE_FORMAT_POLICY.md) and [WVZ1 wire contract](WVZ1_FORMAT.md)
  — storage precision, chunks/checksums, geometry, identity and sampling semantics.
- [Python API](../WAVEZ_API.md) — `SceneCapture`/`SceneReader` signatures and lifecycle.
- [Integration reference](../GETTING_STARTED.md#part-iii--technical-integration-reference)
  and [simulation integration guide](SIMULATION_INTEGRATION_GUIDE.md) — coordinates,
  units, provenance and independent capture cadence.
- [Playback versus integrity verification](PLAYBACK_INTEGRITY.md) — structural
  opening, strict payload verification and the separate lifetime identity audit.

## Saved state and export contracts

- [Portable view presets](VIEW_PRESETS.md) — presentation fields and restore limits.
- [Native inspection state](../INSPECTION_STATE.md) — source-bound scientific recipes;
  distinct from portable view presets and experimental Analysis workflows.
- [Image export](IMAGE_EXPORT.md) and [video export](VIDEO_EXPORT.md) — composition,
  source/timing ownership, optional sidecars, cancellation and recovery.
- [Analysis export/state guide](ANALYSIS_GUIDE.md#save-restore-and-export) — full
  numerical outputs, support/provenance and scientific bundles.

## Playback and resource policies

- [Rolling cache](ROLLING_PLAYBACK_CACHE.md) and [prepared timeline](PREPARED_TIMELINE.md)
  — readiness, resident coverage, eviction and visible-layer requirements.
- [Particle cache capacity](PARTICLE_CACHE_CAPACITY.md),
  [dynamic field preparation](DYNAMIC_FIELD_PREPARATION.md) and
  [mesh preparation budget](MESH_PREPARATION_BUDGET.md) — CPU/worker admission,
  preparation gates, concurrency and resource limits.
- [Reader metadata budget](WAVEZ_METADATA_BUDGET.md) — descriptor/index admission.

## Viewer behavior and runtime requirements

- [Vulkan requirements](RENDERER_REQUIREMENTS.md) and
  [Linux packaging](PACKAGED_VIDEO_EXPORT.md) — supported backend, external
  dependencies, source/standalone distinctions and startup limitations.
- [Status observation policy](STATUS_PLAYBACK_STATE.md#owner-review-correction-observe-transport-progression)
  — timing thresholds and transport semantics behind the user-facing status.
- [Orbit-center reference](ORBIT_GIZMO.md) — world-unit marker radius, placement
  depth, numeric limits and applied observer-orbit behavior.
- [Field slice interpolation](FIELD_SLICE_INTERPOLATION.md) and
  [volume opacity mapping](VOLUME_OPACITY_MAPPING.md) — sampling/display approximations.
- [Held endpoints](RECORDED_END_IDLE.md) — live follow and redraw behavior.

## Development and validation

- [Development and Maintenance Policy](../CONTRIBUTING.md) — private repository
  access, owner-authorized work, review and release boundaries.
- [Agent/developer guidance](../AGENTS.md) and [version policy](VERSIONING.md) —
  development safeguards, focused checks, packaging identities and owner review.
- [Current status](CURRENT_STATUS.md) — supported scope and current source-of-truth map.
- [Scientific acceptance criteria](SCIENTIFIC_ACCEPTANCE.md) — declared independent
  oracles and fixture coverage, not universal workflow certification.
- [Evidence index](EVIDENCE_INDEX.md) — retained historical validation and measurements.

Detailed guides may include frozen review-time reports, old commands or unsupported
renderer results. Those retain their original provenance; use current contracts
for supported behavior. Historical PASS figures do not certify other hardware,
every scientific workflow or owner acceptance of a new change.
