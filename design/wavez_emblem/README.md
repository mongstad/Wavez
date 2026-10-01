# Wavez emblem — issue #162 visual checkpoint

This is the proposed Blender asset for [issue #162](https://github.com/mongstad/Wavez/issues/162).
It is **awaiting owner visual approval**. The issue explicitly requires approval
of the 3D asset before GLB/glTF export and Godot integration. Neither has started.
The application feature and its acceptance criteria are not complete.
The issue's draft PR proposes **v0.1.0.15**, exactly accepted main build 14 plus
one; later implementation/review commits on this PR keep the same candidate.

## Authoritative reference and interpretation

All six images in the owner's `Wavez_ThemeBranding/Dark_Mode` package were
inspected. `Wavez_Square_Logo_No_Slogan_No_Border_Dark.png` is the source because
it contains the emblem without a wordmark, border or slogan. Its SHA-256 is
`4398a96d6aaf89733417d5c6c204c1d0238751bee07ad5250a63bcce1ef21aa3`.
The existing [bundled artwork](../../viewer/ui/about/wavez-logo-dark.png) is
byte-identical, so no duplicate reference image was copied into this directory.

The candidate preserves a circular dark sphere, flowing cyan/blue/violet lines,
the asymmetric bright central wave, a thin rim and horizontal wave shoulders.
Fourteen central-wave landmarks were sampled from the approved 1254px image.
Fine cross-lines suggest the reference's spherical net. The surrounding stars,
galactic background and strong glow are omitted for compact chrome presentation.
The line density and shoulders are a 3D interpretation requiring visual approval,
not a claim of exact raster reproduction. There is no text or interactive control.

## Editable source

- `wavez_emblem.review.blend`: a safe, provisional checkpoint containing one
  self-contained scene, **Wavez Emblem - Approval Candidate**. It preserves
  reviewable work across sessions; it is not the finalized, approved source.
- `author_emblem.py`: Blender-only construction source. It creates a separate
  scene, refuses to overwrite an existing candidate, and neither saves nor exports.
- `inspect_emblem.py`: read-only geometry and reference-landmark inspection.
- `inspection.json`: results from the actual candidate geometry in Blender 5.2.2 LTS.

The provisional `.blend` snapshot contains only the authored scene and its dependencies. It
was written with `bpy.data.libraries.write`, without saving or replacing the open
interactive file. The original Camera, Cube and Light remain in the original
scene with their inspected transforms. Intermediate scenes created during this
request were removed. Background reopening verified one scene, seven objects
(three asset meshes, root, review camera and two review lights), no linked
libraries and no external image references.

The **Wavez Emblem Asset** collection contains the runtime candidates. The
**Wavez Review Studio (not for export)** collection contains authoring lights and
camera. Future export must select only the asset collection. Colors are authored
vertex data consumed by three simple materials. There are no textures, physics,
modifiers, particle systems or runtime procedural geometry dependencies.

To inspect the saved source in Blender's console, after opening the `.blend`:

```python
import bpy
from pathlib import Path
source = Path(bpy.data.filepath).parent
exec(compile((source / "inspect_emblem.py").read_text(), "inspect_emblem.py", "exec"))
print(result)
```

To reproduce it in a fresh Blender session, execute `author_emblem.py`. It
creates and selects its own scene. Do not rerun it over an existing candidate.
The authored scene's camera is ready for rendering; no compositor bloom is used.

## Verification at this checkpoint

| Measurement | Result |
|---|---:|
| Asset meshes / materials | 3 / 3 |
| Vertices | 14,826 |
| Evaluated triangles | 18,224 |
| Non-finite coordinates / degenerate triangles | 0 / 0 |
| Overall bounds, including shoulders | 3.280096 × 2.012529 × 2.010000 units |
| Central-wave landmark error, mean / maximum | 0.9448 / 2.1955 pixels |
| Linked libraries / external images | 0 / 0 |

Landmark distances compare the authored tube centerline against the fourteen
sampled points at the original image scale. They do not measure whole-image
similarity, perceived resemblance or owner acceptance. The full numeric results
were reproduced by reopening the `.blend` in a separate background Blender.
Python source syntax checks, `git diff --check` and the two existing application
version/CLI tests passed for this draft checkpoint. The source checkpoint is
407,471 bytes; its SHA-256 is
`f44bff45d2a162f3b73c9e2b4c3f565719e99048c0b2960aba19ff68459c181a`.

Blender previews were inspected front-on and at 12 degrees of yaw at 1260×840,
plus 72×48 and 144×96 small presentations. The smallest preview retains the wave
and silhouette, but loses fine lattice detail. These are asset previews, **not**
Godot/KDE scaling validation. Preview PNGs and intermediate renders stay outside
the repository in the task's `emblem-162-review` directory. No temporary renders,
autosaves, runtime tools or caches are included in this checkpoint.

## Owner review and remaining work

Compare the front and angled previews with the approved borderless reference.
Judge the sphere/wave identity, cyan-to-violet balance, shoulders, line density,
and whether the calmer appearance suits the chrome. Inspect the small previews
at native size; they are not a final placement proposal. Approve the asset or
identify visual changes before the next phase.

After explicit owner visual approval, save the finalized emblem to a separate
repository-controlled `wavez_emblem.blend` source file, without overwriting
unrelated Blender work. Export only the approved asset from that approved source
to GLB/glTF, then integrate it into
the existing brand/drag surface, and choose a restrained presentation compatible
with accepted redraw pacing. The 12-degree view is an inspection angle; no
animation speed or runtime animation policy is approved or implemented here.

Godot Forward+/Compatibility, idle GPU and redraw counts, playback, scientific
PNG/video export, window drag/maximize, edge reveal/pins, compact layout, native
4K/KDE scaling and Linux package-resource checks are all **pending**, because the
required approval precedes integration. Geometry counts alone do not demonstrate
runtime cost. No current scientific-rendering or performance result is claimed.
Historical review reports and evidence remain unchanged.
