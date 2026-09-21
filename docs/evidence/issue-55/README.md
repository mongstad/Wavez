# Issue #55 — current production UI in video overlays

Implementation pending owner review. Baseline `a32857f` includes owner-merged
PR #58. #55 was the sole Ready issue; its exact owner-created linked branch was
checked out clean at accepted main. The previous local branch was absent; its
stale remote ref was pruned. Earlier review-time evidence remains unchanged.

## Cause and implementation

The video worker sets `offline_instance=true` to isolate playback/input and drive
samples deterministically. `_build_ui` used that flag to skip the production
shell as well, leaving the old standalone inspector in exported images.

The worker now explicitly requests the same `ViewerShell`, `ViewerTransport`,
`ViewerStatus`, current theme and retained inspector used by the application.
It stays offline for scientific sampling and camera ownership. There is no copied
export-only UI. The old standalone Hide inspector action is excluded from this
path. Non-video inspection/test viewports still need their existing minimal
construction path, so shared inspector construction was not deleted or reorganized.

A small render-job `presentation` dictionary captures workspace, scroll and
remaining-duration preference. It is validated for both job versions and is not
scientific recipe state. Desktop fullscreen, focus, menus/dialogs and live parent
jobs are deliberately not serialized. Shell/transport/status processing is
explicitly refreshed after each committed output sample, rather than depending
on wall-clock scheduling. The existing worker remains the sole render-job owner.

## Defined overlay contract

See [VIDEO_EXPORT.md](../../../VIDEO_EXPORT.md#4k-and-rendering-quality).

- **On:** current command bar, camera controls, right dock/workspace, transport,
  status and Jobs; existing section/visual settings plus the captured workspace
  and duration preference. Explicit inclusion displays the dock even if hidden
  on the desktop. Fullscreen/immersive desktop visibility does not affect export.
- **Off:** no application chrome. The existing coupled particle colorbar/legend
  gate remains off. Independent scientific guides/probe/selection overlays keep
  their settings. Scientific-only pixels are compared with the prior path.
- Enabled legends are retained subject to existing channel/`show_legend` gates.
  No new legend policy, UI migration, scientific sampling, timing, camera,
  encoding or cancellation change is included.
- UI uses the existing proportionally scaled 1440-wide logical canvas at output
  aspect ratio; the 3D viewport remains the full native requested resolution.
- This is a deterministic presentation, not desktop screen recording. Transport
  time follows the committed source sample; Play is paused and Jobs reflects the
  worker's scene, not the parent export-progress window. The speed control retains
  captured viewer state; explicit export Playback rate owns output timing.

## Native results and images

Fedora KDE / Wayland, Godot 4.7.2, NVIDIA RTX 3070 Ti. Both Forward+ and
Compatibility produced 1080p and 4K MP4s with the requested dimensions, frame
counts, FPS and source/camera timing. Repeated same-renderer UI exports had
identical PNG hashes for every frame. Source fixture hashes remained unchanged.

The agent visually inspected current-shell 1080p/4K output: Midnight Scientific
command bar, right dock, centered transport and status are correctly arranged;
the dock scroll clips its scrolling body normally, without overlapping transport.

- Forward+: [1080p](forward-overlay-1080p.png), [4K](forward-overlay-4K.png),
  [UI off](forward-overlay-disabled.png), [Appearance/remaining](forward-appearance-workspace.png)
- Compatibility: [1080p](compat-overlay-1080p.png), [4K](compat-overlay-4K.png),
  [UI off](compat-overlay-disabled.png), [Appearance/remaining](compat-appearance-workspace.png)
- Exact results: [validation.json](validation.json); logs accompany this report.

## Final validation summary

| Check | Result |
|---|---|
| Full Forward+ video regression | 140 assertions PASS, including 60 final UI checks |
| Corrected Compatibility UI suite | 60 assertions PASS |
| Overlay export suite, Forward+ | 95 assertions PASS (earlier 46-check UI harness) |
| Overlay export suite, Compatibility | 109 assertions PASS; initial offscreen assertion superseded by corrected UI suite |
| Interactive shell + immersive, Forward+ | 148 checks PASS |
| Recipe/state, headless | 2,998 checks PASS |
| Selection-aware render/sidecar replay, Forward+ | 44 checks PASS |
| Godot native import / Python compile / diff whitespace | PASS |

Selection-aware coverage verifies visible GPU selection markers, exact membership,
source and image hashes, frame times, delay-independent PNG pixels and sidecar
replay equivalence. Its selection markers were visually inspected. Full video
coverage includes render/encoding cancellation, missing FFmpeg, encoder failure,
partial-frame retention and atomic output cleanup.

## Failures, corrections and limits

Initial import found a GDScript inference error in the new offline fullscreen
condition; it was fixed with an explicit bool type. The first validation attempt
timed out on that compile failure. A sandboxed import also could not write Godot
settings/open debug sockets; the subsequent native import passed.

An initial comparison test created an offscreen viewport without enabling draws.
Forward+ exposed unrendered texture contents in the top-left 128×128 area;
Compatibility's blank textures happened to compare equal, which was not valid
scientific evidence. The test now explicitly renders both viewports. The corrected
Forward+ comparison has zero differing channels across the full image and over
2.9 million nonzero channel values. No renderer change or pixel tolerance was
introduced to make it pass. Final corrected UI results supersede that assertion
in the earlier export-run logs; their actual worker-rendered export checks remain valid.

This is a synthetic fixture regression, not a new real-dataset scientific audit.
No solver was rerun. Cross-renderer byte equality is not claimed; each renderer's
repeat must match itself. Extreme small/narrow outputs retain existing scaled
layout limits. Other platforms and broad performance/scientific suites were not
run. Physical owner acceptance is still required.

## Reproduction and owner verification

Run `tools/validate_video.py --overlay-ui` with `--godot`, a new `--output-dir`
and `--renderer forward_plus` or `gl_compatibility`; it uses external FFmpeg and
ffprobe. Omit `--overlay-ui` for the full existing cancellation/fallback suite.
The UI test inside that runner covers scientific-only pixel equality, current
shell composition/geometry, camera preservation and invalid presentation fields.

Before acceptance:

1. Open a representative capture. Set a recognizable camera, channel/colormap,
   scientific guides/probe marker and legend. Choose Scene or Appearance and a
   recognizable total/remaining transport preference.
2. Export a short 1080p clip with **Include viewer overlays** on. Confirm current
   command bar, right workspace dock, transport/status/Jobs and Midnight Scientific
   styling. Confirm the old left inspector is absent and time follows the frames.
3. Repeat at 4K and inspect the retained PNG at full size for clipped controls,
   overlapping transport/status/dock or altered scientific framing.
4. Export with overlays off. Confirm application chrome and the coupled legend
   disappear while independently enabled guides/markers remain unchanged.
5. Hide the desktop dock or enter immersive, then use explicit export settings:
   inclusion must still follow the checkbox. No recovery hint/dialog is exported.
6. Repeat a fixed export twice, cancel a longer export, and reopen Jobs/Video Export.
   Confirm repeat timing, retained partial frames and current progress/failure
   behavior. No orbit-start or post-roll feature is included in this issue.
