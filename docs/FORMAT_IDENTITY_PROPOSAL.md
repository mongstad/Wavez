# WAVEZ Scene Format clean-break proposal — issue #182

**Status:** revised design for owner review. This PR changes documentation only.
The owner has approved the identity **WAVEZ Scene Format**, **.wvz**, **WVZ1** and
a complete alpha-stage break from SimScope-era files and state. The exact wire
encoding and implementation map below remain review material. No WVZ1 runtime
change is implemented on #182.

## End-state and break policy

WAVEZ writes and reads WVZ1 only. The Python package, native viewer, analysis,
video/export workers, current validation tools, examples and packaged builds
operate on .wvz files. A .ssc file is obsolete alpha data; regenerate it from
its source simulation if it is needed again. Do not ship a SIMSCP4 reader,
signature dispatch, legacy picker filter, dual-write mode, deprecated
SimScope API/serialized-kind alias, automatic migration, or .ssc-to-.wvz
converter. A .wvz filename containing old bytes must fail validation.

This reverses the compatibility exceptions left by branding issue #155. It
replaces the present SIMSCP4-only contract described by
[the format policy](CAPTURE_FORMAT_POLICY.md). It does not change the proven
scientific data model.

## Exact proposed WVZ1 wire identity

| Field | Current accepted bytes/value | Proposed WVZ1 bytes/value |
|---|---|---|
| File prefix layout | 16-byte little-endian <8sII> | Same 16-byte layout |
| Eight-byte magic | ASCII SIMSCP4 followed by one NUL | ASCII WVZ1 followed by four NULs: b'WVZ1\0\0\0\0' |
| Prefix unsigned version | 4 | 1 |
| Metadata JSON version | 4 | 1 |
| Record-header layout and tag | 80-byte <4sIQQdIIQ32s>, tag b'FRM4' | Same layout, tag b'FRM1' |
| Commit layout and tag | 48-byte <8sQ32s>, tag b'COMMIT4\0' | Same layout, tag b'COMMIT1\0' |
| Source format value | SIMSCP4 | WVZ1 |

The reader must require the exact magic, prefix version, metadata version,
record tag and commit tag as one contract; no cross-pairing or old-signature
branch. The new record tags remove the misleading version-4 markers while
keeping record sizes and fields identical. They change header/commit proofs and
whole-file hashes, as expected for newly generated files. Keep SHA-256 rules,
per-chunk stored/raw hashes, descriptor schema, required statistics_v1,
little-endian f4/f8/u4/i8 precision, float64 timestamps, identity policy,
4 MiB chunking, optional lossless Zstandard, allocation limits, incomplete
append behavior and scientific validation guarantees. The string statistics_v1
is the statistics schema revision, not the file-format name; retain it unless
a scientific schema change is separately justified.

Make the public writer and current file-consuming entry points require a .wvz
path as well as WVZ1 bytes. The suffix is a workflow gate, while the full
signature and versions establish the format. Reject both a renamed SIMSCP4
file ending in .wvz and a WVZ1 file presented as .ssc. There is no implicit
rewrite of either file.

Change product-owned format/version metadata and serialized kinds. Preserve
caller-supplied descriptive scientific metadata as data; do not rewrite a
simulation's provenance text merely because it contains a historical name.

Keep independent application build, Python distribution, inspection recipe and
render-job version axes distinct from the WVZ1 wire version. The Python package
metadata is currently 3.0.0 while wavez_export.__version__ says 2.0.0; align
those during the breaking implementation release. Propose a new package major
version for that release, subject to the normal package/version policy. Do not
bump the application build for this documentation-only PR.

## Active migration inventory

The audit covered wavez_export/, viewer/, tools/, tests/, examples/, root
policies/guides and docs/. These are implementation targets, not changes on
this PR. A later implementation should inventory tracked names and content
again, classify every remaining match, and gate on zero active legacy
references. Historical evidence is addressed separately below.

| Active area | Exact paths and legacy surface | Required clean-break action |
|---|---|---|
| Python wire writer/reader | wavez_export/scene.py sets SIMSCP4 magic, prefix/metadata version 4 and FRM4/COMMIT4 tags; wavez_export/storage.py defines framing; wavez_export/{__init__,field_statistics,metadata_budget}.py describe the old format. | Write WVZ1 only; validate only the proposed WVZ1 tuple; remove old magic/version constants and old-format wording. Preserve the shared scientific primitives. Keep generic SceneCapture/SceneReader APIs where they describe the current Wavez scene workflow; do not add old API aliases. |
| Python analysis and source pins | wavez_export/analysis/source.py separately checks SIMSCP4 and publishes format=SIMSCP4. recipes.py, selectors.py, jobs.py and downstream analysis use pinned format, UUID, extent and SHA. | Admit WVZ1 .wvz only; publish/require format=WVZ1 in current source identities and reject old pinned sources. Keep identity checks strong; old recipes/jobs cannot be silently relabeled. |
| Native reader and current UI | viewer/layers/scene_reader.gd checks SIMSCP4, version 4, FRM4 and COMMIT4; viewer/main.gd has the sole .ssc filter and old status text; viewer/ui/shell/viewer_shell.gd, viewer/scene/timeline_sampler.gd and viewer/scene/inspection_state.gd display or validate old identity. | Accept only WVZ1 .wvz. Use one WAVEZ Scene Format (*.wvz) picker filter and current WAVEZ status/details/errors. Remove old detection and references; leave broader file-dialog UX work to its own issue. |
| Saved current state | viewer/scene/{inspection_state,view_preset}.gd, viewer/analysis/inspection_v3.gd, viewer/video/{source_identity,render_job,render_worker,export_dialog}.gd and wavez_export/analysis/{recipes,matched_render,atomic_output,export_results,member_assets}.py produce/parse simscope-inspection, simscope-view-preset, simscope-export-source, simscope-matched-render, simscope-export-staging, simscope-numerical-export and simscope-member-cache. | Replace these seven active kind strings with matching wavez-* kinds in producers and consumers together. Preserve their independent schema numbers if layouts remain unchanged. Do not accept old kind aliases; old presets, inspection bundles, queued jobs and derived outputs become obsolete. |
| Persistent paths and configuration | viewer/project.godot still sets Godot/app_userdata/SimScope; viewer/layers/scene_reader.gd and viewer/analysis/analysis_jobs.gd use .simscope-cache; viewer/video/export_dialog.gd uses .simscope-export-*; viewer/layers/field_buffer.gd, viewer/layers/scene_reader.gd and viewer/video/render_worker.gd read SIMSCOPE_FIELD_WORKERS, SIMSCOPE_METADATA_BUDGET_MIB and SIMSCOPE_VIDEO_PROFILE. | Use WAVEZ user-data, cache, staging and WAVEZ_* environment names, updating diagnostics, .gitignore, launch instructions and test harnesses together. Do not read old paths or env vars as fallbacks. Old preferences/caches/jobs remain where they are and are not imported. |
| Current tools and temporary files | tools/verify_ssc.py, tools/benchmark_scene.py, tools/extract_surface.py, tools/validate_scene.py, tools/validate_scene_playback.py and many tools/validate_*.py/profile_*.py scripts name .ssc fixtures or glob old output; tools/validate_performance_maintenance.py names external old files; viewer/layers/profile_ssc_pipeline.gd has an old format name. tools/import_grid_npz.py is a current input adapter whose output must be WVZ1. | Rename the verifier and profile entry point for WAVEZ, update all active generators, input validation, temporary surfaces, globs, profiling/validation invocations and output names to .wvz. Replace old external inputs with regenerated WVZ1 cases or retire an inapplicable benchmark. Keep the NPZ adapter only as an importer of its actual external input, not as an old-file converter. Remove obsolete old-format tool paths. |
| Tests and fixture builders | tests/test_scene_contract.py tests retired magic and suffix handling; tests/scene_mutation.py hardcodes FRM4/COMMIT4; tests/metadata_fixture.py, tests/g4/fixtures.py, Python scene/analysis tests and viewer/layers/, viewer/scene/, viewer/ui/, viewer/video/, viewer/analysis/ tests refer to .ssc or simscope-* kinds. A stale .sidx3.json path appears in viewer/layers/test_scene_storage.gd. | Regenerate current fixtures as WVZ1 .wvz; update exact byte, source pin, picker and serialized-kind oracles. Test old signatures/kinds only as refusal inputs. Remove obsolete cache-index assumptions rather than perpetuating them. Preserve Godot UID sidecars for renamed scripts. |
| Examples and distribution | examples/{scene_demo,identity_demo,g4_demo}.py default to .ssc. viewer/project.godot supplies packaged runtime user-data paths; the Godot package consumes the same picker/reader and resources; pyproject.toml and wavez_export/__init__.py carry package identity/version text. | Make example and package workflows create/open WVZ1 .wvz only. Reconcile package version and generated wheel metadata; verify release packages include the current docs/resources and no old runtime path or file association. No repository MIME registration or desktop association was found in the current checkout. |
| Current policy and guides | AGENTS.md, CONTRIBUTING.md, README.md, QUICKSTART.md, viewer/README.md, docs/START_HERE.md, docs/CAPTURE_FORMAT_POLICY.md, docs/CAPTURE_FORMAT_AND_API.md, docs/SIMULATION_INTEGRATION_GUIDE.md, G3_FORMAT.md, G3_GUIDE.md and SIMSCOPE_API.md currently direct users to .ssc/SIMSCP4. docs/SIMSCOPE_HANDBOOK.md is a current handbook despite its filename. docs/SSC_METADATA_BUDGET.md and other SSC-named operational guides include current settings. | Make current instructions, executable examples, wire specification and links authoritative for WVZ1 only. Rename current API/handbook/operational document filenames where they present the active identity, repairing links and executable documentation tests. Do not replace historical measurements with claims about WVZ1. |
| Current behavior and schema guides | INSPECTION_STATE.md, VIDEO_EXPORT.md, docs/{VIEW_PRESETS,G4_SCHEMAS,PLAYBACK_INTEGRITY,FILE_DIALOGS,DYNAMIC_FIELD_PREPARATION,PARALLEL_FIELD_PREPARATION}.md and the current sections of docs/CURRENT_STATUS.md and docs/SIMSCOPE_HANDBOOK.md describe old source kinds, settings, paths or workflows. Some files contain both current guidance and review-time evidence. | Update the current contract text, commands and links; retain the separately identified old measurements and review-time claims. Move current guidance out of a mixed historical file if necessary rather than rewriting its historical body. |
| Audit and developer checks | tools/audit_branding.py explicitly allows simscope-* kinds, cache/env names, old user-data paths and old documentation filenames; viewer/ui/test_branding.gd and tools/validate_branding.py allow or generate old identity. .gitignore ignores *.ssc but not *.wvz. | Replace the old active allowlist with an audit that permits old terms only in classified historical records and negative refusal tests. Update branding tests and ignore rules. A repository-wide active-code/docs/fixture scan should fail on unexplained SimScope, simscope, SIMSCP, .ssc, old tags or old paths. |

The established technical names SceneCapture, SceneReader and generic fields such
as capture_path do not themselves encode the former product or wire identity.
Review user-facing wording in the relevant UI scope, but do not create redundant
API renames solely to remove the ordinary word 'capture'. No retired
simscope_export import path or SimScopeCapture API is present in current Python
source; none should be restored.

## Implementation sequence after separate approval

1. Pin accepted-main scientific oracles from small generated particle, mesh,
   volume and mixed scenes: exact arrays, IDs, times, statistics, codec choices,
   validation failures and source hashes. Record that file hashes must differ
   after the new envelope is written.
2. Implement the exact WVZ1 writer and Python/native/analysis readers as one
   version change. Replace all magic/version/record/commit tags together. Remove
   old signature branches instead of adding dispatch. Regenerate fixtures.
3. Change source identities, all seven current serialized kinds, render-job and
   inspection consumers, storage paths, user-data directory and environment
   names together. Refuse old saved state; do not copy or reinterpret it.
4. Change the single picker filter, current messages, active tools, examples,
   packaging and fixture naming. Enforce .wvz paths at public file entry points.
5. Reconcile current policy, wire/API/integration docs, handbook, getting-started
   links, package version and application build. Classify historical files and
   update the active audit to reject unclassified old identifiers.
6. Run the complete focused and renderer/package validation below; inspect the
   staged files and PR for accidental data or history rewrites. The implementation
   requires its own owner-approved scope after this design review.

## Required validation for the implementation

- **Wire oracle:** assert the exact 16-byte prefix, metadata version 1, FRM1 and
  COMMIT1 tags, unchanged 80/48-byte layouts, descriptor/commit proofs, stored
  and raw chunk SHA, statistics_v1 and strict whole-file verification.
- **Scientific parity:** regenerate from the same synthetic source arrays and
  compare decoded f4/f8/u4/i8 bytes, signed zero/nonfinite policy, IDs, geometry,
  channels, timestamps, mesh topology, field statistics and lossless none/Zstd
  output. Preserve append/recovery, resource admission and corruption refusal.
- **Sole-format negatives:** old .ssc/SIMSCP4, a SIMSCP4 file renamed .wvz,
  a WVZ1 file named .ssc, mixed prefix/metadata/record versions, truncated
  records, stale source pins and old serialized kinds must fail clearly. No
  fallback or converter path may run.
- **Whole application:** run Python scene/analysis/tool tests; native Godot
  inspection, playback, presets, selection and video source/export tests;
  Forward+ and Compatibility; and Linux packaged open, rendering, inspection,
  strict verification and export checks. Check the WAVEZ user-data and cache
  paths, environment knobs, generated fixtures and documentation examples.
- **Legacy-name audit:** scan tracked active source, current documentation,
  tests, generated fixture names, packaging and entry points for all old
  terms/paths listed above. Explain each remaining occurrence as an immutable
  historical statement or a negative refusal test. Confirm historical evidence
  files were not modified.

## Consequences and historical boundary

Existing .ssc data, saved presets/inspection bundles, source-pinned jobs,
analysis outputs, caches and old preference directories will not load into
the new build. This is the intended alpha break. Researchers must regenerate
.wvz scenes with the current wavez_export writer; external scripts must change
paths, package version and any renamed environment settings. Renaming an old
file or editing JSON identities is not a valid upgrade. New hashes/UUIDs mean
old sidecars and scientific jobs need new generation, even when source values
are scientifically identical.

Historical reports, evidence JSON, screenshots and recorded external dataset
names keep the identifiers they actually tested. For example,
[the branding migration report](BRANDING_MIGRATION.md) documents its earlier
compatibility decision and must not be rewritten as if it tested WVZ1. Keep
historical documents reachable, but make the current policy and quickstart the
source of truth. If a file mixes a current preface with a historical body,
update the preface or route users to the new current guide without falsifying
the historical record.

**Review gate:** approve or correct the exact WVZ1 envelope, including FRM1
and COMMIT1 tags, and the implementation map. This PR remains a proposal; the
format, file filter and runtime behavior are unchanged until a separately
approved implementation.
