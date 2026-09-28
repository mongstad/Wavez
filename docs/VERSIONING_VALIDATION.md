# Application version identity — issue #131

Pending owner review. #131 was the only Ready item in the SimScope Development
project when selected. The existing linked branch is
`131-release-version-001-add-simscope-application-version-and-monotonic-build-number`,
based on accepted main `fb75c8c294c4b3105c7a1608e639e9ee6b43a53c` (owner-merged
PR #130). Fetch/prune completed; the old local issue branch was already absent.
Historical reports and evidence are unchanged.

## Implementation

The authoritative `application/config/version` setting in `viewer/project.godot`
starts at `v0.1.0.1`. Help → Version uses the existing copyable details surface,
with no capture required. The runtime reader and standard-library Python CLI
validate the same four-component identity. Missing/malformed metadata produces an
explicit unavailable diagnostic in the viewer and a nonzero CLI exit with no
version output. Neither consumer invents a fallback number.

[Versioning policy](VERSIONING.md), CONTRIBUTING and AGENTS document one BUILD
increment per accepted merge, unchanged through review revisions, reconciliation
against current main, no reset, and owner-controlled release components. README
and current status link the new policy. The exporter package and SIMSCP4 version
remain independent. No scientific/controller behavior or release automation changed.

## Validation

Linux, Godot 4.7.2, NVIDIA RTX 3070 Ti. **668 checks passed on each renderer
(1,336 native checks total), plus two Python unittest methods and two exported-PCK
scenarios.** Final counts and source hashes are recorded in the
[curated ledger](evidence/issue-131/validation.json). The
[Version display](evidence/issue-131/version.png) was visually inspected.

- Python metadata and CLI tests cover the authoritative source, full/release/JSON
  output, alternate source paths, release changes, BUILD beyond 999 and beyond
  machine-integer precision, malformed/non-string/missing values, and failure exit.
- Native shell checks exercise the actual Help menu/details, availability without
  a capture, live source-setting changes, invalid metadata, existing startup,
  capture opening, scientific-state invariants, menus, analysis/data export,
  fullscreen, immersive mode and responsive layout. Synthetic sources remain
  unchanged. The historical menu contract stays intact with Version appended.
- In an isolated viewer copy, exported PCK data preserves the authoritative
  setting and matches the Python reader. Changing only that copy's source from
  the initial identity to `v0.1.0.1000` updates both tool and packaged runtime.
  Both packs start the normal main scene headlessly without script errors.
  Temporary presets, packs and runtime binaries are not committed or distributed.
- Godot editor import generates the new tracked UID. Python syntax and whitespace
  checks pass. Repository Markdown links and three runnable API examples pass.

## Development failures and limits

Initial shell runs on both renderers failed two fullscreen-exit assertions and
one legend assertion. An unchanged accepted-main snapshot reproduced exactly
those three failures (653 checks). The old assertions expected windowed exit
after maximized entry and hidden legends when the panel collapses. They now
assert the accepted #88 restore-mode and #91 independent-legend behavior. No
fullscreen or legend runtime implementation was changed.

The first baseline attempt lacked imported resources and could not initialize;
only that owned test process was stopped, then the snapshot was imported and rerun.
An intermediate corrected Forward+ run had four fullscreen scientific-state
comparison failures; a subsequent run with explicit differing-state diagnostics
passed. The transient cause was not established; those invariants remain asserted.
The first renderer attempts overlapped; final renderer runs were sequential.

Export validation covers a Godot PCK and headless main-scene startup on Linux,
not a redesigned installer, signed binary, Windows/macOS build, or publication.
The merge counter is a documented review convention, not automatically enforced
by CI. No production scientific capture was rerun for this identity-only change.

## Owner verification

1. Open Help → Version before opening a capture. Compare and copy the full
   four-component identity against `viewer/project.godot`.
2. Open a capture, play/pause, and reopen Version. Ordinary viewing must be unchanged.
3. Run `python tools/application_version.py --json` and confirm the same identity.
4. Review the initial numbering and future merge/release policy before acceptance.

Stop for owner review; no merge, auto-merge, release/tag, manual issue closure or
Project completion is performed by this task.
