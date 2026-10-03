# WVZ1 implementation validation — issue #215

Issue #215 proposes candidate application build **v0.1.0.31** and Python exporter
package **4.0.0** for owner review. The current contract is
**WAVEZ → WAVEZ Scene Format → `.wvz` → `WVZ1`**. Earlier `.ssc` files and
source-pinned state are obsolete alpha data. No legacy reader, picker, alias or
converter is shipped.

## Real simulation artifact

The external cavity-collapse Python simulation produced
`/home/Nozba/Codex/Wavez/cavity_collapse_mesh_wavez/cavity_collapse_torus_quick.wvz`
(1,695,107 bytes, 37 mesh records, Zstd). It is outside Git. The source script
`/home/Nozba/Codex/Wavez/cavity_collapse_mesh_wavez/cavity_collapse_mesh_wavez.py`
had the same SHA-256 before and after export:
`3ec235f2fc10dc4dc6b804756ef114d3be74c1d9cf388aa47ce88f95a398abdf`.
The generated scene SHA-256 is
`79b7257bc5f95bf41c05e2602b4c1e64f241fd0b11df4d7cc69dd3cb38b8c55a`.

Run from the WAVEZ repository root to regenerate it:

```bash
PYTHONPATH=/home/Nozba/Codex/Wavez/Wavez python \
  /home/Nozba/Codex/Wavez/cavity_collapse_mesh_wavez/cavity_collapse_mesh_wavez.py \
  --quick --output /tmp/cavity_collapse_torus_quick.wvz
python tools/verify_wvz.py /tmp/cavity_collapse_torus_quick.wvz
```

The artifact's first 16 bytes are
`57 56 5a 31 00 00 00 00 01 00 00 00 a7 03 00 00`:
magic `b'WVZ1\0\0\0\0'`, little-endian prefix version **1**, and metadata
length **935**. Its metadata JSON version is **1**, first record tag is `FRM1`,
and last commit tag is `COMMIT1\0`. Strict whole-file verification passed all
37 records. Native mesh playback loaded/rendered it on both Forward+ and
Compatibility (4,637 checks each), and the Linux package opened and exercised
it on both renderers (281 checks each). These checks also confirmed the source
bytes remained unchanged.

## Validation summary

| Check | Result |
|---|---|
| Python unit suite | 217 passed |
| Scene/storage contract, none/Zstd, precision, checksums, append and corruption | 23 scene tests passed; native storage 109 and multichunk 48 checks passed |
| Metadata admission and scientific payload/statistics | 1,535 checks passed; 1,316 records and all payloads/statistics verified |
| Playback, generated particle/field/mesh/mixed scenes | 2,457 checks passed on each renderer |
| Field/session and payload integrity | 332 and 480 checks passed |
| Real simulation mesh playback | 4,637 checks passed on each renderer |
| Inspection/preset, selections and rendered G4 source state | Preset 814 headless, 582 Forward+, 522 Compatibility; selections 32 per renderer; G4 render 44 per renderer |
| Video source/export | Current video 235 Forward+, 225 Compatibility; startup video 57 checks passed |
| File picker and branding/user-data break | File dialogs 90 checks per renderer; branding 4,384 Forward+ checks passed |
| Linux release package with real scene | 281 checks passed per renderer; candidate binary and PCK at `/tmp/wavez-215-package-forward/` |
| Documentation and identity audit | No broken current links; three executable examples passed; 2,631 old-name occurrences classified, zero unexplained active references; historical evidence unchanged |

The explicit refusal tests cover obsolete suffixes, a renamed SIMSCP4 file,
old source pins and old serialized kinds. Exact prefix, metadata, record and
commit values are asserted. Scientific oracles cover particle IDs/positions,
field values and statistics, mesh topology/channels, chunk hashes, and rendered
video/inspection state. Active tests and tools generate `.wvz` fixtures.

## Known limits and owner checks

The optional performance-maintenance lifecycle harness reports one failure in
51 checks: `incomplete append cannot publish a source timestamp`. The same
failure was reproduced on imported accepted `origin/main` with the same Godot
4.7.2 binary and harness, so it is pre-existing; the separate WVZ1 append,
corruption and playback suites above passed. The Python wheel build was not
verified because this host's system Python lacks `setuptools.build_meta`;
native package exports passed. Physical owner interaction remains to be checked.

1. Launch `/tmp/wavez-215-package-forward/wavez.x86_64` with its adjacent
   `wavez.pck`, or run the source viewer with the installed Godot 4.7.2 binary.
2. In **About WAVEZ**, confirm candidate `v0.1.0.31`. In **File → Open capture**,
   confirm the sole scene filter is **WAVEZ Scene Format (`*.wvz`)**.
3. Open the real simulation artifact above; seek and play through the 37 mesh
   records, inspect the mesh and channel/legend controls, and try both renderers
   if available. The automated GPU and packaged checks do not replace this
   physical review.
4. Regenerate a fresh `.wvz` with the command above and open it directly.
   Confirm that a renamed old `.ssc` cannot be opened and that a true WVZ1 file
   renamed to `.ssc` is excluded/refused.

The accepted [design proposal](FORMAT_IDENTITY_PROPOSAL.md) and earlier
SIMSCP4 validation reports remain historical records of their actual builds.
