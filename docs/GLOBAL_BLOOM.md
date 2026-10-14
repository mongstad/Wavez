# Scene-wide Bloom and viewing preferences

On a fresh profile, Wavez starts with **Scientific** selected and Bloom **off**.
Use **View → Global effects → Enable Bloom** to enable or disable the one
scene-wide effect, and **Bloom** to adjust its intensity in any viewing preset.
The slider remains editable while Bloom is off. It covers **0–2**, in **0.02**
steps. Cinematic's fresh default is **on at 0.30**, exactly 15% of the maximum;
Scientific, Temperature, Density, Velocity and Minimal / Presentation start off,
with 0.30 ready if enabled. Visible glow depends on scene brightness/materials.

Each viewing preset remembers its own manual Bloom on/off and intensity.
Selecting another preset recalls that preset's saved pair; it does not copy or
reset the pair you changed. These are preset preferences for the same global
Environment effect, not particle/field/mesh Bloom controls. Enabling Bloom does
not change the viewing-preset name, Point rendering, mappings, backdrop or fog.
Other preset actions retain their existing meanings. Temperature, Density and
Velocity select their corresponding channel when available in an opened capture,
without reapplying Bloom or environment defaults; unavailable channels retain
the normal capture mapping fallback.

The selected preset and all six Bloom pairs persist across restarts, File →
Close File and opening other WVZ captures. Application preferences live in
`user://view_preferences.json`, separately from captures and view recipes.
The complete bounded file is validated before use; writes replace it atomically.
Missing preferences use fresh defaults. Invalid data leaves a loaded profile
unchanged, or uses defaults on startup, with an explanation in Global effects.
A failed save keeps the current session's choices and reports that they were
not saved. To deliberately reset these choices, close Wavez and remove only
that file; the next launch uses the defaults above. Reset Camera does not reset
viewing preferences.

An explicitly loaded view preset or scientific inspection applies its rendering
settings to the current session. It can keep Scientific with Bloom on, or
Cinematic with Bloom off. It does not rewrite application preferences merely
because it was loaded or restored. Closing/opening a capture preserves that
session override. A later manual preset selection recalls application preferences;
a manual Bloom edit saves the current preset's resulting pair. Restart recalls
the last manual selection. Ordinary capture opening never loads a presentation
recipe implicitly. Video/image snapshot restoration and offline workers do not
write application preferences.

New portable view presets include the viewing-preset name. For a partial recipe
that supplies only Point rendering (`clean_view`), the name follows that explicit
representation (Scientific/Cinematic), without inferring it from Bloom. Other
omitted settings remain unchanged. Saved environments remain authoritative for
actual pixels; stale native slider values cannot override their Bloom intensity.

Forward+ Vulkan is the sole supported backend. Unsupported renderer launches
are refused before preferences are used; Compatibility is not a supported Bloom
fallback. No per-category passes, shaders or scientific payload changes are
introduced. See [renderer requirements](RENDERER_REQUIREMENTS.md),
[portable view presets](WAVEZ_VIEW_PRESETS.md) and
[issue #366 review evidence](evidence/issue-366/README.md).

## Historical issue #306 record

The following report retains its original defaults, policy, validation and
review-time wording. The current preference behavior above supersedes its
coupling between Bloom and preset identity; historical evidence is unchanged.

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
