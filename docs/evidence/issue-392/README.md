# Issue #392 — uploaded Linux release license audit and correction proposal

Owner review pending. No published asset, release notes or tag has been changed.
The owner explicitly authorized creating `issue-392-release-license-notices`
from accepted main `1feb37aacbe5ba206be0c7a353fec623a4e1a655`. Issue #392 was
Backlog when prioritized directly by the owner; the updated issue requires this
branch, a PR and owner review before a release correction.

## Actual uploaded asset findings

Downloaded asset ID **634911246** from private GitHub release **v0.1.0.105**:
`Wavez-v0.1.0.105-linux-x86_64.zip`, **40,497,654 bytes**, SHA-256
`3584c15fe4f88b5a0881e2e4bc5f611e6b27b8d7f199009d133b22ebec9f094f`.
The download matches GitHub's asset digest and the attached checksum. ZIP CRC
verification passes; all 175 members extracted outside the Git repository.

The reported wholesale absence of license files is **not reproduced**. These
nine files exist, are nonempty, have readable permission bits, and open as UTF-8
text in the extracted package:

| Extracted path (relative to the package folder) | Bytes |
|---|---:|
| LICENSE | 4,623 |
| THIRD_PARTY_LICENSES.md | 3,543 |
| TRADEMARKS.md | 297 |
| GODOT_LICENSE.txt | 1,149 |
| GODOT_COPYRIGHT.txt | 100,108 |
| GODOT_THIRD_PARTY_NOTICES.txt | 109,789 |
| DISTRIBUTION_NOTICES.md | 1,530 |
| viewer/COLORMAPS_LICENSE.txt | 40,129 |
| viewer/ui/fonts/LICENSE-DejaVu.txt | 8,816 |

**Verified gaps:** the source-oriented THIRD_PARTY_LICENSES.md does not link to
Godot's included full texts or distinguish its distributed runtime explicitly.
Its font/About source-note links point to absent `viewer/ui/fonts/README.md` and
`viewer/ui/about/README.md`. Direct Matplotlib/DejaVu license links do resolve.
The tracked `tools/package_linux.py` exports the executable/PCK but did not
assemble the release documentation, notice files or ZIP; those were assembled
by an external one-off script. This made completeness dependent on that script.
No particular downloader/editor failure is established beyond these link and
workflow defects.

## Verbatim and redistributed-component audit

- Godot MIT LICENSE and full COPYRIGHT match upstream commit **ed1daf0bf**
  byte-for-byte. The packaged executable SHA-256 matches the installed official
  4.7.2 Linux release template exactly. The complete upstream COPYRIGHT includes
  engine component notices and Open Sans; its conservative inventory can include
  components not enabled in that binary. It has not been shortened.
- DejaVu notices match upstream **version_2_37/LICENSE** byte-for-byte; no font
  changes are proposed.
- Palette notices match the full installed **Matplotlib 3.10.8** distribution
  LICENSE, and its base agreement matches that release's upstream LICENSE.
  The ten packaged 256-entry tables reproduce from 3.10.8 definitions. The
  original generation version was not recorded; reproduction is not a claim
  that this was the historical generation environment. The updated inventory
  documents sampling/rounding/JSON conversion separately from the original texts.
- All **652 PCK members** passed their stored MD5 checks. The palette JSON equals
  the source data; the first-party Python archive has 40 owned source entries,
  not Python, NumPy, scikit-image or FFmpeg runtimes. Imported DejaVu font data
  and the exported About notice resource are present.
- A headless offline resource load mounted the **downloaded PCK**, started no
  Main scene or GPU, and recovered all five original About texts. Each equals
  its extracted canonical file exactly. About's existing engine notice routes
  remain source-identical. No new GUI or interactive runtime checks were run.

[The machine-readable actual-asset audit](uploaded-asset-audit.json) records
paths, sizes, digests, readability and the broken inventory links. Original
LICENSE/TRADEMARKS, palette/font license texts and historical evidence remain
unchanged. No binary, template, capture or downloaded ZIP enters Git.

## Proposed workflow correction

The normal packaging command assembles notice files, documentation, versioned
ZIP and SHA256SUMS.txt. It records every member's size/digest, verifies the actual
archive and its local inventory links, and removes the ZIP on verification failure.
It normalizes readable text permissions and preserves executable permission.
Original legal texts are copied as bytes, never rewritten.

Original Godot LICENSE/COPYRIGHT copies are tracked as notice texts only, with
source URLs and digests in `licenses/sources.json`. The audited engine version
and Linux release-template hash are pinned too. Missing/truncated/altered notices,
unaudited engines/templates and stale About metadata fail the command. A short
headless check verifies the **actual exported PCK** notice texts before packaging;
no interactive viewer or renderer is started. Both Godot originals are included
in that resource alongside the existing canonical Wavez/font/palette texts.

## Release correction plan — approval required after PR review

Recommended: owner merges the packaging/licensing PR, then separately authorizes
an official **v0.1.0.106** corrective release from that exact accepted source
commit. BUILD 106 is required by the repository's main.BUILD+1 policy; no
MAJOR/MINOR/PATCH change or release candidate is proposed. Rebuild the accepted
source, tag that same commit, publish one new release and verify the uploaded
ZIP/checksum. Keep **v0.1.0.105**, its source/tag and original asset immutable.

The corrective release would explain that the previous license files existed,
but their discovery/inventory links and repeatable package assembly were
incomplete. Its archive and checksum will differ because inventory, offline
notice resources, documentation and build metadata change. A review-build
checksum is evidence only; the final checksum must come from the accepted-source
rebuild and must not be reused from this candidate.

Alternative: an explicitly approved, distinctly named documentation-only asset
revision for the existing 105 release could preserve its executable/PCK and
include a new manifest/checksum. That would not provide the additional canonical
Godot texts inside its PCK and would separate the corrected archive from the
tracked 106 implementation. Replacing the existing named ZIP/checksum in place
would invalidate earlier download hashes. Neither alternative is executed here.

The original release claim that notices are present is supported by the download.
After approval, an owner-controlled release-note addendum should describe the
confirmed inventory/link/workflow gaps and link the corrective release; it should
not claim the old ZIP had no license files. Original experimental Analysis and
licensing disclaimers remain applicable. Repository privacy is unchanged.

## Focused checks and limits

Seven packaging tests and two application-version tests pass. Negative checks
cover missing/truncated source notices, stale About metadata, unaudited
engine/template, unresolved links, missing/changed ZIP notices, unreadable files
and manifest omissions. Positive extraction checks compare every required file
verbatim and follow local inventory links outside the repository. Source notice
synchronization and diff whitespace checks pass.

The production packaging build and actual exported-resource/archive results are
recorded separately when completed. No GPU, playback, scientific, GUI, extended
regression, platform matrix or performance testing is part of this issue. No
publication or owner acceptance is inferred from these checks.
