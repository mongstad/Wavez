# Issue #181: native scene file picker

On 2026-10-03, #181 was the first Ready item in Wavez Development Project 1.
Its existing branch started at accepted `main` commit `dda54ae`, which contains
the owner-merged #182 design and #215 WVZ1 implementation. The working tree was
clean before edits.
Before commit, `main` advanced to `45d80fd` with repository validation guidance
only. The same issue branch was fast-forwarded to that commit; the change
introduced no product-code or build-version conflict.

## Change

The scene-open `FileDialog` now requests the operating system's native picker
with title **Open File** and one `*.wvz ; WAVEZ Scene Format` filter. Godot uses
its built-in picker if the display server cannot provide a native one. Empty
state, open-error and shortcut labels use current file wording; internal
`open_capture` action/loader identifiers are retained. The video-export picker
and WVZ1 reader/writer are unchanged. Candidate application build is 32.

## Validation

Godot 4.7.2 on Linux KDE/Wayland, NVIDIA RTX 3070 Ti:

| Check | Forward+ | Compatibility |
|---|---:|---:|
| File-dialog suite, eight fresh processes | 105 pass | 105 pass |
| Production shell and load-error recovery | 662 pass | 662 pass |
| Status and load-error recovery | 257 pass | 257 pass |
| Temporary Linux release package, shortcut/open-flow suite | 278 pass | 278 pass |

The dialog suite confirmed native picker configuration, desktop feature support
and a popup request. It then exercised Godot's embedded controls to verify
fallback Favorites/Recent persistence, navigation, valid/invalid/busy loads and
Cancel behavior. The package suite asserted the native picker configuration and
opened particle, field, mesh and mixed WVZ1 fixtures through the existing loader.
Fixture hashes were unchanged. The unmodified review package was exported to
`/tmp/wavez-181-owner-package/wavez.x86_64` with its adjacent `wavez.pck`.
The packaged application also exited cleanly after a headless command-line
startup with the real Python-generated quick cavity WVZ1 scene, but that smoke
run did not assert rendered output.

Two Python application-version tests, Godot import and `git diff --check`
passed. The first sandboxed import emitted socket/editor-settings errors and
created five untracked UID cache files; an authorized import/export succeeded,
and the generated UID files were removed. An initial native test expected the
`FileDialog.visible` flag to be true while the OS owns the dialog; that test
assertion was corrected to observe `about_to_popup`. One unchanged final
Compatibility package attempt passed all 255 first-process assertions but had
four window-signal cleanup diagnostics at shutdown, exceeding the harness's
known pair; the unchanged rerun passed 278 checks across startup and restart.
The Compatibility dialog suite retained twelve known GL cleanup diagnostics.

## Limits and owner checks

The automated native phase did not choose a file in the KDE portal or inspect
its actual text and controls. Physical KDE/Wayland interaction, 4K or mixed-DPI
appearance, desktop bookmarks/Recent persistence, and other operating systems
remain unverified.

1. Launch the review package. From the empty view and File → Open file…, confirm
   the desktop's native picker opens with **Open File** and a single **WAVEZ Scene
   Format (`*.wvz`)** filter, without WVZ1 or capture wording. Repeat via an
   assigned **Open File** shortcut.
2. Browse to a WVZ1 scene, use a desktop bookmark, and open it. Confirm the
   scene loads and plays; reopen the picker and inspect the desktop's Recent
   location. Cancel and confirm the current scene remains unchanged.
3. Open an invalid `.wvz`, inspect the file-error banner/status details, then
   open a valid file and confirm the error clears. Check video export's separate
   picker still works.
4. Repeat the picker and filter inspection in Compatibility, at 4K and mixed
   display scaling if available. Check normal and fullscreen window modes.

Leave the PR for owner review; do not merge or enable auto-merge.
