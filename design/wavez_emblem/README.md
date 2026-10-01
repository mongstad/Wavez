# Wavez emblem — preserved branding experiment

**Status, 2026-10-01: the #162 animated application-chrome integration was not
accepted and is superseded by its removal.** The owner considers the standalone
3D model visually useful, but unsuitable for the Wavez chrome. This directory is
an editable design archive, outside the Godot project. It is not an application
feature, runtime resource, or instruction to resume integration.

The application has been restored to accepted main `9cc2f7d`, including its
`WAVEZ` text wordmark and build `v0.1.0.14`. The proposed build 15 was withdrawn
with the runtime attempt. Existing Wavez branding and dark-theme assets remain
unchanged. See [cleanup and validation](CLEANUP.md).

## Preserved assets

All five Blender files are retained without changing their bytes. Earlier
studies include rejected side-wave extensions and remain historical experiments.

| File | Purpose | Bytes |
|---|---|---:|
| `wavez_emblem.drift-experiment.blend` | Latest contained orb with the baked 12-second `Wavez_Drift` animation | 1,702,240 |
| `wavez_emblem.contained-luminous.review.blend` | Contained luminous orb before animation | 1,669,721 |
| `wavez_emblem.layered-flow-studies.review.blend` | Three earlier layered-wave studies | 3,548,477 |
| `wavez_emblem.luminous-bloom-study.review.blend` | First luminous/bloom study | 796,998 |
| `wavez_emblem.review.blend` | Original prototype | 407,471 |
| `exports/wavez_emblem.drift-experiment.glb` | Single preserved model/animation export, moved out of Godot | 2,343,936 |

The latest source was saved after owner approval of the contained-orb appearance.
That approval preceded the rejected in-app trial. Its embedded review metadata
records that earlier stage and does not establish current UI acceptance. It was
renamed from `wavez_emblem.blend` for clarity; the GLB was likewise moved and
renamed without re-exporting or altering it. The model contains five meshes,
60,816 vertices and 65,768 triangles, with no linked libraries or external images.
The GLB contains the 12-second animation and has no external resource URIs.
Blender compositor bloom is a presentation effect, not a portable GLB effect.

SHA-256 of the latest source and export:

```text
02a5ba022d37f87d572ef142f71c51fd2cec486b2ac6a0f51847303f272097ca  wavez_emblem.drift-experiment.blend
6a2155f88bfbb1a11f08148f372b756e598bde2ecc58792ddab43530ab22517c  exports/wavez_emblem.drift-experiment.glb
```

Checksums for the earlier sources remain in [the luminous review](LUMINOUS_REVIEW.md).
The existing [approved dark artwork](../../viewer/ui/about/wavez-logo-dark.png)
remains the original reference; no duplicate raster reference is needed here.

## Authoring and historical evidence

- `author_emblem.py` and `author_luminous_emblem.py` reproduce the earlier models
  in separate Blender scenes without saving or exporting.
- `author_drift_experiment.py` records the saved animation construction. Open the
  contained-luminous checkpoint in a background Blender process first. It refuses
  to overwrite the preserved drift source.
- `export_experiment.py` exports that source only into this directory's `exports`
  folder and refuses to overwrite the preserved export. It has no Godot path or
  application hook.
- `inspect_emblem.py`, `inspect_luminous_emblem.py`, `inspection.json`,
  `luminous-inspection.json` and `drift-experiment-inspection.json` preserve the
  geometry checks and animation poses.
- [Initial review](INITIAL_REVIEW.md) and [luminous review](LUMINOUS_REVIEW.md)
  preserve the original checkpoint reports under explicit supersession banners.

Temporary previews, integration screenshots, test fixtures, scratch scripts,
cached Godot imports and the emblem-only runtime harness were removed. No Blender
or MCP installation is included or modified. Further design or application work
requires a separate owner instruction; this cleanup provides no replacement.
