# Wavez luminous orb — #162 refinement checkpoint

**Current review candidate:** `wavez_emblem.contained-luminous.review.blend`,
scene **Wavez Emblem - Contained Luminous Orb**. Owner visual approval is pending.
This is a safe editable checkpoint, not the finalized approved source. The
earlier `README.md`, inspection and prototype remain unchanged historical evidence.

The refinement uses the same approved borderless dark emblem reference recorded
in the original report. It has a near-black blue body, a much brighter cyan to
violet central wave, a translucent energy mantle, two interlaced wave families,
and localized fine spherical network detail. Two Blender compositor Fog Glow
passes give the crest and rim a luminous halo. The asset has no text.

The current candidate removes **all external side-wave extensions**. Energy
geometry stays on or immediately around the orb; the maximum measured radius is
1.0142 relative to the unit orb. Any future animation should convey energy flow
through internal motion, phase/material changes or a subtle halo, preserving the
spherical silhouette. No whiskers, antennae, tails or nozzles should be reintroduced.

## Preserved editable sources

| File | Purpose | Bytes |
|---|---|---:|
| `wavez_emblem.contained-luminous.review.blend` | Current contained orb candidate; one authored scene | 1,669,721 |
| `wavez_emblem.layered-flow-studies.review.blend` | Three earlier mantle, dark-body and interlaced-flow studies | 3,548,477 |
| `wavez_emblem.luminous-bloom-study.review.blend` | First luminous bloom study | 796,998 |
| `wavez_emblem.review.blend` | Original prototype, unchanged | 407,471 |

Earlier study geometry includes the now-rejected extensions and is preserved for
editable history only. It must not be selected for final export.

New snapshots were written with `bpy.data.libraries.write` to new filenames,
without saving over the open interactive file. All live study scenes and the
original Camera, Cube and Light remain intact. The current candidate has an
asset collection containing five meshes and one empty root, plus a separate
review camera collection. There are no studio lights. The saved current file
has one scene and seven objects, no linked libraries and no external images.
The three-scene study file was also reopened successfully with no external
libraries or images. The original prototype's SHA-256 remains unchanged.

SHA-256 checksums:

```text
2816bec6f2d4aea2714315b0c76ec4e528baf55e58a9c81f89470d12b8d9edb4  wavez_emblem.contained-luminous.review.blend
afc9e4eb16317d3712c1595e7e942e2945fcc7163d370870f4509de333131182  wavez_emblem.layered-flow-studies.review.blend
0c6a5a3f7125baa7e9c7b790ef7c53eca03dc1514fc22e1450792d7be5b1f507  wavez_emblem.luminous-bloom-study.review.blend
f44bff45d2a162f3b73c9e2b4c3f565719e99048c0b2960aba19ff68459c181a  wavez_emblem.review.blend
```

`author_luminous_emblem.py` reproduces the current candidate in Blender 5.2.2
LTS. It creates a separate scene, refuses to overwrite that scene, and neither
saves nor exports. The original `author_emblem.py` still reproduces the first
prototype. The current compositor uses Blender 5.2's node-group output and Glare
input sockets. No Blender, MCP or other authoring runtime is bundled.

## Verification

`inspect_luminous_emblem.py` measures the evaluated current mesh geometry and
returns a JSON-compatible `result`; `luminous-inspection.json` records the run.
Reopening the saved candidate in a separate headless Blender reproduced the
entire numeric report exactly.

| Measurement | Current candidate |
|---|---:|
| Meshes / materials | 5 / 5 |
| Vertices / evaluated triangles | 60,816 / 65,768 |
| Non-finite coordinates or colors | 0 |
| Degenerate triangles | 0 |
| Maximum geometry radius around unit orb | 1.0142 |
| Bounds X / Y / Z | 2.020438 / 2.012592 / 2.007600 |
| Root rotation | 0 / 0 / 0 |
| Particle systems / modifiers | 0 / 0 |
| Mean / maximum reference-wave landmark error | 1.2496 / 2.8707 pixels |

Landmark error is the distance from the actual hero tube centerline to fourteen
sampled points in the original 1254px reference. It is not a whole-image match
score, a visual acceptance result or a runtime performance measurement.

The front hero render (1200×1200, orthographic scale 2.55), full front and
12-degree yaw views (1400×1000, scale 3.0), and 72×48 / 144×96 views (scale 3.3)
were rendered and visually inspected. The root yaw, camera scale and render
settings were restored after rendering. Small previews retain the central wave
and orb; fine lattice detail diminishes. These are Blender asset previews,
not placement or native 4K/KDE acceptance. Preview PNGs remain outside Git in
the task's `emblem-162-review/refinement` directory with `contained-` filenames.

Python syntax and staged whitespace checks passed. The previous checkpoint's
two application-version tests passed; they were not rerun for this asset-only
refinement. The PR candidate stays **v0.1.0.15**. No runtime code changed here.

## Review boundary and limitations

The strong glow shown here includes **Blender compositor presentation**, which
does not automatically transfer through GLB/glTF. Godot material/glow fidelity,
Forward+/Compatibility behavior and idle redraw cost still need measurement.
This detailed authoring candidate has 65,768 triangles; its suitability for a
small chrome element is unproven and runtime optimization remains pending.

No animation, runtime export, Godot placement, window drag/maximize or compact
layout checks, edge reveal/pin checks, playback/scientific-rendering validation,
PNG/video exclusion, native 4K/KDE validation or Linux packaging validation has
been performed for the unintegrated asset. No runtime performance or scientific
regression result is claimed. This PR remains an incomplete feature checkpoint.

For owner review, compare the current front/angled renders with the approved
dark emblem, check the contained circular silhouette, dark/bright contrast,
layered wave structure and cyan/violet balance, then inspect the small previews
at native size. Explicitly approve this asset or request further visual changes.

Issue #162 requires that approval before runtime export/integration. After it,
save a separate finalized `wavez_emblem.blend` under repository control, export
only the approved asset from that source, and continue integration plus the full
acceptance matrix on the same issue branch and PR. Preserve the editable review
checkpoints. Do not overwrite unrelated Blender sources or merge the draft PR.
