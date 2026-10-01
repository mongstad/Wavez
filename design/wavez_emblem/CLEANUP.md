# #162 cleanup — in-app attempt not accepted

On 2026-10-01 the owner stopped the animated-emblem integration because the
standalone model did not belong in the application chrome. This supersedes
earlier approval to try the contained orb in Godot. No replacement is proposed.
The uncommitted integration was removed; source/model history is retained here.

## Removed and restored

- Restored `viewer/ui/shell/viewer_shell.gd` and `viewer/ui/test_branding.gd`
  exactly from accepted main `9cc2f7dd486ef91964cc1cc286ef2805555b5c18`.
  The upper-left control is again the accepted `WAVEZ` label with its original
  layout, tooltip, mouse routing and drag/maximize behavior.
- Removed the entire untracked `viewer/ui/emblem/` integration: the control
  script and UID, its SubViewport/scene/animation/redraw logic, energy, mantle
  and halo shaders and sidecars, GLB import metadata and emblem-only Godot test.
  The GLB itself was moved to the design archive rather than deleted.
- Removed `tools/validate_wavez_emblem.py`. Restored
  `viewer/scene/test_render_pacing.gd` exactly, including its original full-frame
  pixel comparison and stationary redraw expectations.
- Restored `viewer/project.godot` to build `v0.1.0.14`. Build 15 was a proposal
  for the withdrawn feature; this branch now contains design history only.
- Removed the emblem's generated Godot scene/import cache. A fresh editor import
  cleared stale filesystem/UID references. No emblem path, class or animation
  remains in the Godot project, application tools or tests.
- Removed the disposable `emblem-162-review` workspace: temporary Blender renders,
  runtime screenshots, integration fixtures/logs, diagnostic outputs and the
  generated accepted-main comparison copy. It contained 1,804 generated files
  (155,258,597 bytes), including 531 PNGs. Removed 13 known integration scratch
  scripts and obsolete PR drafts from `/tmp`.

The entire `viewer/`, `tools/`, `tests/`, `docs/` and exporter trees match accepted
main. No accepted branding, theme asset, unrelated historical evidence or global
Blender/MCP installation was changed. The accepted dark reference still hashes to
`4398a96d6aaf89733417d5c6c204c1d0238751bee07ad5250a63bcce1ef21aa3`.

## Preserved

The [design inventory](README.md) lists all five editable `.blend` sources and
the single useful GLB. The latest animated source and export were renamed/moved
without altering their bytes. All five Blender files reopened successfully in a
separate background process, with no linked libraries or external images.
The GLB retains five meshes, five materials and the 289-sample, 12-second
`Wavez_Drift` animation, with no external URIs. No live Blender scene was changed.

Authoring/inspection scripts and numeric reports remain design-only. The export
helper now targets only `design/wavez_emblem/exports/` and refuses to overwrite
the retained model. Original review reports are preserved verbatim below dated
supersession banners. Their earlier approval requests and integration plans are
historical statements, not current instructions.

## Validation completed before the owner stopped testing

Native Godot 4.7.2 checks on the existing NVIDIA desktop, using small synthetic
SSC fixtures:

| Check | Forward+ | Compatibility |
|---|---:|---:|
| Branding / live application surfaces | 4,460 passed | 4,460 passed |
| Viewer shell, layout and routing | 673 passed | 673 passed |
| Pin / edge reveal / fullscreen state | 210 passed | 210 passed |
| Render pacing, playback and interaction | 290 passed | Stopped by owner |
| Scientific video/export checks | 235 passed | Not run; owner stopped testing |

Forward+ recorded **zero extra draws and identical full-frame pixels in all 34
stationary phases**. Export checks covered exact scientific data, deterministic
repeated rendering/timing and unchanged input bytes. Completed native suites
reported no missing-resource, script or import errors. The restored application
was launched and its original wordmark visually inspected. Godot editor import,
the two Python version tests, source hashes and authoring syntax checks passed.

The remaining Compatibility pacing run and subsequent video/native KWin stages
were stopped at the owner's instruction after file cleanup. Physical pointer
dragging and the full desktop maximize/restore sequence were not newly validated
in this cleanup; their production code and existing tests are byte-identical to
accepted main. No broader hardware or native 4K result is claimed.

Cleanup evidence is outside the repository in `emblem-162-cleanup`; no new runtime
test or screenshot is shipped. The pre-existing owner edit to `AGENTS.md` was
preserved separately in local stash `f1548f7c20ef544503a7fdc037a2d6977b4b7e70`
and a patch backup, keeping this branch focused and its working tree clean.
The owner retains branch deletion, main switching, issue disposition and merge
control. No merge or auto-merge is requested.
