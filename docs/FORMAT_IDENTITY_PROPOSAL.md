# WAVEZ Scene Format naming proposal — issue #182

**Review status:** proposal for owner approval. This branch changes no reader, writer,
file filter, file bytes, application version, or scientific behavior. The approved
*naming direction* is `.wvz`, **WAVEZ Scene Format**, and `WVZ1`; the migration
contract below still needs a separate implementation decision.

## Current contract and inventory

| Category | Current name and concrete use | Migration consequence |
|---|---|---|
| Public file identity | `.ssc` in examples, quickstart/API/integration guides, generated fixture paths, CLI examples, and `viewer/main.gd`'s only open filter, `*.ssc ; WAVEZ scene (SIMSCP4)` | New output defaults and the picker must change together. The Python writer and readers currently accept paths regardless of suffix; renaming a file does not change its format. No MIME registration or desktop file association is present in this repository. |
| Cosmetic text | SIMSCP4 appears in `viewer/main.gd` startup/load status, `viewer/ui/shell/viewer_shell.gd` Details, reader errors, guides, and package description | Replace current-facing text when the format implementation is approved. Keep explicitly labeled legacy diagnostics where they help explain an old file. File-open dialog wording beyond format labels belongs to #181. |
| Python API and symbols | `wavez_export.SceneCapture` / `SceneReader`, `wavez_export.scene.MAGIC`, `PREFIX`, `metadata_valid`, `storage.py`, `codec.py`, `field_statistics.py`; `wavez_export.analysis.source.SourceSnapshot` | Keep the established Wavez package and useful scene APIs. Change the format constants, validation and source identity explicitly; no `simscope_export` import shim is needed. `tools/verify_ssc.py` is a filename/CLI entry point to rename or replace with a deprecation path. Package version in `pyproject.toml` is separate from the format version; `wavez_export.__version__` currently differs from it and should be reconciled during an implementation release. |
| On-disk envelope | 16-byte little-endian `<8sII>`: `SIMSCP4\0`, integer `4`, JSON metadata length; metadata has `"version":4` and a UUID. Python and Godot reject other magic/version values. | `WVZ1` needs an exact 8-byte encoding and a consistent prefix and metadata version rule. A suffix-only rename would leave SIMSCP4 bytes. |
| Record framing and scientific payload | 80-byte `FRM4` headers, descriptors with array/chunk hashes and `statistics_v1`, payload chunks, and 48-byte `COMMIT4\0` proofs | These are byte-level contracts, not branding strings. Keep their layout, markers, codecs, checksums, precision, identity and limits if this is a naming-only revision. Changing record markers would require rewriting and revalidating every record without a demonstrated benefit. |
| Serialized source identities | `"format":"SIMSCP4"` in native inspection recipes, video source pins, Python analysis source references, selections and render jobs; source UUID, committed extent and SHA also bind derived work | Dispatch identities by the detected magic. Old identities remain valid for the *same unchanged old source* if legacy reading is approved; converting a source changes bytes/hash and needs newly generated recipes and jobs. Do not relabel stored JSON by search-and-replace. |
| Other `simscope-*` kinds and storage paths | Inspection, view preset, export source, matched render, staging, numerical export and member cache kinds; `.simscope-cache`, `.simscope-export-*`, `SIMSCOPE_*` diagnostics and the old `user://` directory | These identify independent persisted contracts or user data. Keep them for this format issue unless a separately scoped migration proves safety. `simscope-inspection` and `simscope-export-source` are directly involved in source binding, so their values need compatibility tests even when retained. |
| Tests, tools, and distribution | `tests/test_scene_contract.py` checks suffix independence and retired magic; Python scene/analysis tests, Godot scene/inspection/video tests, many `tools/validate_*.py` fixtures/globs, `tools/validate_documentation.py`, `examples/*.py`, and `.gitignore` name `.ssc`. Godot Linux packaging uses the same viewer source/filter. | Update fixture names and glob assertions, exercise both supported signatures, add `.wvz` ignore rules, verify both renderers and the Linux package. There are no tracked production `.ssc` data files; existing research data live outside the repository. Preserve historical reports and evidence unchanged. |

The [current wire contract](../G3_FORMAT.md), [format policy](CAPTURE_FORMAT_POLICY.md),
and [branding migration](BRANDING_MIGRATION.md) remain descriptions of the accepted
SIMSCP4 implementation until a later implementation PR changes it. Application
build `v0.1.0.30`, Python package `3.0.0`, metadata version `4`, `statistics_v1`,
inspection versions `2`/`3`, render-job versions and the proposed `WVZ1` are
different version axes.

## Proposed new contract

1. Write new files as `.wvz`, describe them as **WAVEZ Scene Format**, and identify
   them by `WVZ1`. The proposed exact prefix is `b"WVZ1\0\0\0\0"` in the existing
   8-byte magic slot, integer prefix version `1`, and JSON metadata `"version":1`.
   Confirm these exact bytes in owner review before implementation. Keep the
   object/array schema and record framing above byte-for-byte equivalent; this is
   a new namespace for the same scientific representation, not a fidelity change.
2. **Recommend dual-read, single-write for SIMSCP4 and WVZ1.** Dispatch once from
   the full magic, prefix integer and metadata version, then use one shared
   record/payload validator. This is a narrow, explicit exception to today's
   SIMSCP4-only policy, not a fallback parser or acceptance of SIMSCP1–3. New
   `SceneCapture` output is always WVZ1, including when callers pass an unusual
   suffix; reject or clearly warn on `.ssc` output paths so new files are not
   silently mislabeled. Existing `.ssc` writers remain able to produce old files,
   but are not bundled, maintained as a second write mode, or promised future
   support. Support both signatures in Python `SceneReader`/analysis and the native
   reader. The actual magic, not the suffix, determines format and source identity.
3. Make the normal picker/default examples prefer `*.wvz`, with a clearly named
   **Legacy SIMSCP4 (`*.ssc`)** open filter for existing research data. A file
   whose suffix and magic disagree must be reported by its detected format and
   must never be represented as a WVZ1 file just because it is named `.wvz`.
   No automatic conversion on open. Current save/export workflows expose `.wvz`;
   the legacy filter is a deliberate compatibility entry point.
4. Offer a separate, opt-in streaming converter only if users need a WVZ1 copy of
   archived `.ssc` data. It must write a new path atomically, retain the original,
   validate the old source strictly, preserve metadata other than the envelope
   version and preserve each record/payload byte, then strictly verify the new
   file and compare decoded arrays, timestamps, IDs and field statistics. Record
   old/new hashes and UUID in a conversion manifest. Converting changes the
   source hash and header digest/identity; saved inspection recipes, selections,
   analysis pins and render jobs must be recreated against the converted file.
   Conversion is not required merely to read an old file under the recommended
   dual-read policy.

This recommendation values existing research data without carrying two scientific
parsers or continuing old-format writes. A clean break plus an offline converter
would keep the runtime smaller but make every old dataset unusable in the updated
viewer until converted; a dual-write mode would keep legacy naming in ordinary
export workflows and multiply validation. If the owner instead chooses a clean
break, approve that explicitly and require a finished, verified converter and
documented external-integration cutover before removing old reads.

## Implementation map and required checks after approval

- **Writer/reader:** `wavez_export/scene.py`, `wavez_export/analysis/source.py`,
  `viewer/layers/scene_reader.gd`, `viewer/data/capture_index.gd`; leave the
  shared scientific primitives in `storage.py`, `codec.py` and native typed
  decoding equivalent. Test exact prefix/metadata bytes and reject cross-paired
  magic/version values, truncated inputs and old unsupported signatures.
- **Identity/derived work:** `viewer/scene/inspection_state.gd`,
  `viewer/analysis/inspection_v3.gd`, `viewer/video/source_identity.gd`,
  `viewer/video/render_job.gd`, `viewer/video/render_worker.gd`, and
  `wavez_export/analysis/{source,recipes,selectors,jobs}.py`. Test old recipes
  against their unchanged old source, new recipes against WVZ1, and refusal of
  stale/mismatched hashes, copies and converted sources.
- **User and integration paths:** `viewer/main.gd` picker/status,
  `viewer/ui/shell/viewer_shell.gd` Details, `tools/verify_ssc.py`,
  `examples/*.py`, `pyproject.toml`, `.gitignore`, `README.md`, `QUICKSTART.md`,
  `SIMSCOPE_API.md`, `G3_FORMAT.md`, `docs/CAPTURE_FORMAT_POLICY.md`, and the
  current integration guides. Keep established document filenames and historical
  evidence links unless a separate documentation move is approved.
- **Regression:** create independent `.ssc` and `.wvz` particle, mesh, volume and
  mixed fixtures; compare exact decoded bytes/values, identity, clocks, statistics
  and strict SHA verification. Cover corrupt payloads, incomplete appends, budgets,
  source/preset/video pinning, converter interruption and checksum failure. Update
  affected Python/Godot assertions and fixture globs, run focused suites plus
  Forward+, Compatibility and packaged Linux open/inspection/export checks. For
  a representative external large capture, verify strict integrity before and
  after any opt-in conversion; do not assume playback alone proves integrity.

**Owner decision needed:** approve or change the exact WVZ1 envelope bytes and
dual-read/single-write policy, including the legacy picker entry point and whether
an offline converter belongs in the follow-up implementation scope. Do not change
the on-disk contract on #182 before this review.
