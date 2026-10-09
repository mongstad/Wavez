# Scene-wide Bloom — issue #306

Wavez retains one **View → Global effects → Bloom** slider. It changes the
existing native Environment glow intensity for the complete scene. Cinematic
enables it for particle-only, field-only, mesh-only and mixed WVZ1 captures.
Scientific and the other scientific viewing presets disable decorative Bloom.
The accepted intensity default is **1.35**, with the existing 0–2 range.

The owner superseded independent-category Bloom on 2026-10-09. Draft PR #309 is
historical research and must not be merged as this fix. This focused branch is
based directly on accepted main, without that prototype's code, buffers or
additional passes. No GPU renderer, shader, capture format or export workflow
changes are introduced.

## Reproduced state defect and correction

On accepted main, applying a Scientific portable preset while Cinematic was
selected restored `Environment.glow_enabled=false` and disabled the slider,
but left Cinematic checked in the Viewing preset menu. The reverse transition
could leave Scientific checked while Bloom was enabled. Portable presets carry
environment values but no viewing-preset name. VisualState and source-bound
inspection recipes could also restore an explicit environment inconsistent
with their stored preset name. Those paths set slider availability from the
environment without reconciling the label. Capture opening itself preserved
the current state; ordinary Cinematic field/mesh loads did not disable Bloom.

`_sync_bloom_control()` now reconciles both the label and slider after preset
selection, portable-preset loading and VisualState/inspection restoration.
Saved rendering settings remain authoritative: Bloom on selects the Cinematic
label; Bloom off replaces a stale Cinematic label with Scientific. Other named
scientific presets remain selected while Bloom is off. This does not reapply
a preset or infer decorative mode from the independent Point rendering
checkbox. Selecting Cinematic through the existing menu enables native global
Bloom and its slider as before, without requiring particles.

This is deliberately a control-state correction. A saved Bloom-off view stays
Bloom-off and keeps its pixels, rather than acquiring new glow on load. It now
shows the corresponding Scientific checkmark. Intensity, backdrop, fog,
tonemapping, particle appearance, camera and scientific data remain as saved.
The tooltip states the existing mode policy and explains that visible glow
depends on scene brightness. Global effects layout and controls are unchanged.

## Evidence and scope of the claim

The [review evidence](evidence/issue-306/global-control/README.md) reproduces this
state mismatch on accepted main and verifies its correction using all four
capture types, Dark/Light, Forward+/Compatibility, source and Linux release.
Mouse clicks/dragging and keyboard arrows traverse the native Window GUI input
path. Scientific images remain invariant to Bloom intensity. Native renderer,
PNG and real MP4 pixels are compared to accepted main.

Working input and visible effect are separate observations. The fixture images
change around fields/meshes as well as particles, but Compatibility's measured
effect is smaller. Those fixtures do not establish a universal glow strength
for the owner's materials or captures. The owner elected to check the change
personally; their original captures and recipes were not supplied, so this
reproduced state defect is not claimed as their confirmed root cause.

Candidate **v0.1.0.80** awaits owner physical review. Issue #306 remains open.
No merge, independent Bloom, new GPU targets, capture migration or unrelated
functionality is part of this change.
