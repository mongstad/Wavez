# Round 4 — shared dropdown/popup consistency, pending owner visual review

The owner approved the Round 3 direction at `6d1eff6` in principle and found
legacy dropdown/popup styling in Fields/Meshes during physical review. This
correction retains `0d32d08`, `b9a2df3`, `6d1eff6` and all earlier evidence.
It continues the same #143 branch and Draft PR #145; build `v0.1.0.10` remains.

[Appended reasoning and owner checks](../../../UX5_STYLE_SLICE.md#owner-review--round-4-dropdown-consistency)
and [compact results](summary.json) document the shared widget theme, internal
PopupMenu binding, source/recipe rebuild hook and normal/disabled owned glyphs.
Only dropdown widgets/popups are extended across production UI. Surrounding
deferred forms, numeric inputs, switches and FileDialog trees retain their
previous review boundary. No option contents or scientific callbacks change.

## Unedited native production screenshots

These use the real Colormap dropdown with the same options in each category.
The checked current row stays `viridis`; pointer hover moves to `plasma` without
changing selection. Popup position varies with the form layout; the skin does
not. The scientific backdrop differs between renderers as expected.

| Renderer/category | Current selection | Pointer hover |
| --- | --- | --- |
| Forward+ Particles | [Selected](forward-particles-selected.png) | [Hover](forward-particles-hover.png) |
| Forward+ Fields | [Selected](forward-fields-selected.png) | [Hover](forward-fields-hover.png) |
| Forward+ Meshes | [Selected](forward-meshes-selected.png) | [Hover](forward-meshes-hover.png) |
| Compatibility Particles | [Selected](compatibility-particles-selected.png) | [Hover](compatibility-particles-hover.png) |
| Compatibility Fields | [Selected](compatibility-fields-selected.png) | [Hover](compatibility-fields-hover.png) |
| Compatibility Meshes | [Selected](compatibility-meshes-selected.png) | [Hover](compatibility-meshes-hover.png) |

Additional checks: [Field channel](forward-fields-channel.png),
[Mesh channel](forward-meshes-channel.png),
[Fields keyboard focus](compatibility-fields-focus.png),
[disabled field popup row](forward-fields-disabled-row.png),
[disabled mesh popup row](compatibility-meshes-disabled-row.png) and
[absent Meshes context](compatibility-meshes-empty.png).

For the disabled-row test, the harness temporarily disables one existing
non-current item, verifies native arrow navigation skips it, then restores its
original availability before the real controller selection. Production option
contents/availability are unchanged. All 18 retained screenshots are direct
1440×900 viewport captures, with no editing or compositing. Additional images,
complete tiny captures, native logs and export jobs remain outside Git under
`/home/Nozba/Codex/SIMSCOPE/style-143/round4/`.

## Validation and reproduction

Godot 4.7.2 / NVIDIA RTX 3070 Ti completed **3,442 checks across 16 final runs**,
plus **2 Python version tests**. Each relevant suite ran on Forward+ and
Compatibility after the final production change. The focused suite resolves
203 selector visits across initial capture, recipe rebuild and capture
replacement; it compares every effective widget/popup theme item, including
fallbacks/local overrides. It checks native Enter/arrow/Tab/Shift+Tab/Esc routes,
moving-pointer hover, focus recovery, disabled-row skipping, one selection
intent, exact object/channel ownership, source binding, camera/clock/playback
preservation and stopped common hover fades.

| Suite | Forward+ | Compatibility |
| --- | ---: | ---: |
| Dropdown parity and native interactions | 493 | 493 |
| Multi-object panel/disclosure/scientific ownership | 263 | 263 |
| Existing theme/contrast/scope | 52 | 52 |
| Preserved Round 2 interactions | 109 | 109 |
| Fullscreen Tools and Round 3 corrections — X11 | 74 | 74 |
| #117 edges/pins/fullscreen restoration | 210 | 210 |
| #118 redraw/retained scientific image | 290 | 290 |
| Current scientific video export | 235 | 225 |

All 34 paused phases per renderer recorded zero new draws and unchanged pixels;
clock/camera and retained-versus-forced full-quality images matched. Complete
fixture hashes stayed unchanged. Scientific comparison reuses the same complete
mixed capture and exact saved job from Round 3, changing only output path. Fresh
accepted-main and candidate jobs compare decoded RGBA frames and timing per
renderer. Exact GPU float32 plane readback remains Forward+-only.

Four fresh 960×540 scientific RGBA frames and both timing manifests match
accepted main `61f6a78` exactly on their respective renderers. All 437 tracked
viewer files in the accepted-main archive were verified byte-for-byte. All 33
historical evidence files and the earlier style-document prefix match `6d1eff6`.

From the repository root, use external Godot/FFmpeg and fresh output directories:

```bash
python tools/validate_violet_dropdowns.py --godot /absolute/path/to/godot --output-dir /tmp/dropdowns-forward --renderer forward_plus
python tools/validate_simulation_panel.py --godot /absolute/path/to/godot --output-dir /tmp/panel-forward --renderer forward_plus
python tools/validate_violet_style_slice.py --godot /absolute/path/to/godot --output-dir /tmp/style-forward --renderer forward_plus
python tools/validate_violet_round2.py --godot /absolute/path/to/godot --output-dir /tmp/round2-forward --renderer forward_plus
python tools/validate_violet_review_corrections.py --godot /absolute/path/to/godot --output-dir /tmp/corrections-forward --renderer forward_plus --display-driver x11
python tools/validate_edge_reveal.py --godot /absolute/path/to/godot --output-dir /tmp/edges-forward --renderer forward_plus
python tools/validate_render_pacing.py --godot /absolute/path/to/godot --output-dir /tmp/pacing-forward --renderer forward_plus
python tools/validate_video_current.py --godot /absolute/path/to/godot --output-dir /tmp/video-forward --renderer forward_plus
python -m unittest tests.test_application_version
```

Repeat with `gl_compatibility` and different output directories. The source
fixture helper is reused from the existing panel validator; no exporter or
capture format is duplicated.

## Diagnostics and limits

Initial test-only assertions used the wrong snapshot key and popup-local motion
delivery. They were corrected against the actual snapshot and embedded-window
input route. Moving pointer events include relative motion/velocity; stationary
warps are ignored by the engine. Keyboard entry uses native Enter and explicitly
checks paused playback during popup opening. No production input handler changes.
The engine input behavior was checked against the
[upstream PopupMenu implementation](https://github.com/godotengine/godot/blob/master/scene/gui/popup_menu.cpp).

An early Compatibility run passed every assertion but emitted a cached-shader
recompilation warning, so strict validation rejected it. A separate clean repeat
and the final unchanged-code matrix pass. The initial read-only audit also had
an incorrect external fixture path; its corrected audit reproduced the mismatch.
These intermediate diagnostics remain in raw output directories.

This round uses native X11. Round 3's Wayland evidence remains historical; it
was not remeasured here. Physical pointer/keyboard feel, 4K/mixed-monitor quality
and production power/utilization still require owner/hardware review. Small
synthetic scientific equality does not establish universal performance.
Owner visual review remains pending. No broad propagation, acceptance, merge,
Ready transition, auto-merge, issue closure or Project move is included.
