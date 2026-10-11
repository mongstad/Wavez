# PySPH particle presentation: independent visualizer supplement

Issue [#358](https://github.com/mongstad/Wavez/issues/358), executed 2026-10-11.
**PASS:** tested particle population, identities, coordinates, roles, clocks,
projections and clipping/opaque-depth controls. **FAIL:** local visibility and
some independent color/width comparisons. The original
[PySPH benchmark report](PYSPH_BENCHMARK_RESULTS.md) remains unchanged and valid
for its stated scope. This is the existing **2D, unit-depth dam-break case viewed
in 3D**, not validation of full 3D SPH or a reconstructed fluid surface.

## Scope and reproduction

Wavez **e98efbb3cf4e390aa01fc3a49b3fc671dff27697**, **v0.1.0.94**;
official Godot **4.7.2**, revision `ed1daf0bf001b61586d9930840f2f1394092c079`.
Native Compatibility/OpenGL and Forward+/Vulkan: Linux **7.2.9-200.fc44**,
x86_64, glibc **2.43**, Ryzen 7 5800X, RTX 3070 Ti **8 GiB**, NVIDIA **615.71.09**.
Independent reference: **VTK 9.7.0**, Python **3.12.15**, NumPy **2.5.4**,
SciPy **1.18.1**, Pillow **12.3.0**, using the existing external FEniCSx environment.
No dependency installation or PySPH solver rerun was needed.

All scripts, captures, images, logs and detailed evidence remain outside Git:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/02_PySPH/issue-358-presentation/`.

```sh
cd /home/Nozba/Codex/Wavez/Wavez-Benchmarks/02_PySPH/issue-358-presentation
sha256sum -c SHA256SUMS
../../04_FEniCSx/environment/bin/python prepare.py
../../04_FEniCSx/environment/bin/python verify_controls.py
python3 reproduce.py owner-review
cat owner-review/assessment.log
```

Use a fresh output name and native GPU/display access. Exit 0 from the replay
means collection completed, **not** all scientific gates passed. Eight original
files match their historical hashes; all **909** typed-array/time checks pass
(808 arrays and 101 clocks). The original `dam.wvz` SHA-256 remains
`6d63876e4d1c48f6332c3c0a51377f92a73a2233d14aa6d3df676b72c0e21932`.

## Matched representation and temporal policy

All **2,578 particles: 1,600 fluid (role 0), 978 fixed wall (role 1)** are retained.
Positions remain in metres, IDs remain exact int64, source channels remain
unchanged. Each renderer uses all particles; no subsampling or coordinate
normalization is performed. A float64 camera/projection oracle is independent
of both rendering implementations.

Five display times cover source indices **0, 50, 100** and midpoints **25/26,
75/76**: **0, 0.07650000000000116, 0.1499999999999998,
0.22649999999999137, 0.3 s**. At midpoints both visualizers use the same
ID-linear display positions and lower-sample scalar policy. Native binary source
clocks, held density and role hashes are checked. These are display estimates,
**not extra solver observations**; physical midpoint error was not measured.
Roles are constant in this capture, so changing role-category transitions are
not established by the holding checks.

There are **29 matched 800×600 views**. At each time, a full-tank view has vertical
extent **1.7 m**, target **(1,0.45,0)**; dense, front and near-wall views have extent
**0.25 m**. Dense/sparse probe ranks use distance to the sixth nearest other
fluid particle, front uses maximum fluid x, and near-wall uses distance to fixed
wall particles. These
geometric ranks are not measurements of physical fluid density. Zoom targets and
all per-ID projections are in `cases.json`; front/dense targets follow each state.
Default orthographic cameras are target+(0,0,3), up Y, near/far **0.05/10 m**.
Nine controls cover perspective (**45°**), oblique depth, crossing/behind opaque
planes, near/far clipping, larger markers, low contrast and white background.
Diagnostic planes are not part of the dam-break source.

Wavez uses the real Scientific particle shader: additive, camera-facing Gaussian
markers, `exp(-14*r²)`, without particle depth writes. Nominal world diameter is
**0.36×0.35×Particle size m**: size **0.1** normally, **0.25** for the larger-marker
control. This is presentation size, **not smoothing length, particle support,
a physical sphere or a fluid surface**. Viridis maps role over fixed **[0,1]**,
gamma/brightness=1, exposure **0.25** (low case **0.025**). Backgrounds are black,
**0.08** gray or white; linear tonemap, no trails, glow, fog or overlays.

VTK's independent
[`vtkPointGaussianMapper`](https://vtk.org/doc/nightly/html/classvtkPointGaussianMapper.html)
uses the same camera, positions, Gaussian radius/falloff and emissive/additive
policy, with opaque geometry submitted first. It uses full-precision explicit
viridis endpoint RGB; Wavez uses its production RGB8 LUT. This small quantization
difference is retained. Matching these inputs does not equate the tools' color
transfer/blending pipelines. Each tool saves **243 images**: all particles,
background, separate roles and selected isolated probes. Particle-particle
occlusion is additive overlap, not an opaque physical-fluid model.

## Predeclared gates and results

`TOLERANCES.json` was saved before rendering; SHA-256
`3f9fa56ee79ea5408a507e7cec8a57eecfd6f9345eca5857248f7112df35061f`.
No thresholds were relaxed. Both native runs completed **299,524 checks, zero
failures**, clean logs and exit 0. These repeated per-view checks establish
attributes/geometry/clocks, not universal appearance fidelity.

A fresh replay exactly repeated the numerical assessment, negative-control and
analytic results, plus all **783 final PNGs** (including negative controls).

Image/reference assessment: **2,278 checks: 1,987 PASS / 291 FAIL**.
Compatibility accounts for **1,052 PASS / 48 FAIL**, Forward+ **877 PASS / 243 FAIL**,
and VTK population/projection checks **58 PASS**. Reference-image gates appear
in both renderer comparisons; totals are gates, not independent experiments.

| Gate | Declared limit | Result |
|---|---|---|
| GPU coordinate component error | 1e-6 m | **PASS**, maximum 9.536744e-8 m in both renderers |
| Independent projection error | 0.001 px | **PASS**, Godot maximum 0.000503309 px; VTK <1.137e-12 px |
| IDs, roles, instance count and source/scalar clocks | Exact declared policy | **PASS** |
| Isolated centroid: native/reference and native/oracle | 0.75 px | **PASS**, maxima 0.742471 / 0.741103 px |
| Apparent FWHM difference | max(1.5 px, 20% reference) | Compatibility **PASS**; Forward+ **95 FAIL** |
| Isolated peak RGB difference | 0.08 | Compatibility **PASS**; Forward+ **116 FAIL** |
| Local RGB MAE | 0.06 | **PASS** |
| Aggregate RGB MAE | 0.025 | One Forward+ **FAIL**, larger markers: **0.0746701**; all others pass |
| Local visible peak contrast | ≥0.02 | **FAIL** in specified cases below |
| Role chromatic direction | Closer to own than other viridis endpoint | **PASS** when visibly resolved; invisible controls **FAIL** |
| Fully clipped / fully opaque-occluded peak | ≤0.008 | **PASS**, both native renderers and VTK |

FWHM is equivalent-circle diameter from isolated half-peak pixel area. Centroids
use background-subtracted intensity and pixel centers. Local coverage inspects a
marker-radius square around **every fully in-frame, nonoccluded expected center**
in its role-only image. This checks presence, not unique resolvability: overlapping
neighbors can contribute to a patch. Exact instance/ID counts and isolated
geometrically selected probes are separate checks; bright blobs are not used to
infer particle counts. Partial plane/viewport markers are excluded from symmetric
visibility expectations. The largest centroid deviation is near an opaque-plane
boundary; it remains within the original gate, not evidence of zero raster error.

## Visibility and scientific presentation discrepancies

Full-tank fluid centers below the 0.02 contrast floor:

| Source index / display time | Compatibility / 1,600 | VTK / 1,600 | Forward+ / 1,600 |
|---|---:|---:|---:|
| 0 | 66 | 0 | 0 |
| 25/26 midpoint | 48 | 3 | 0 |
| 50 | 46 | 2 | 0 |
| 75/76 midpoint | 29 | 0 | 0 |
| 100 | 40 | 0 | 0 |

All 978 full-tank wall centers pass coverage in these five views. All normal
zoomed dense/front/near-wall coverage checks pass. The full-tank fluid marker is
small and dark; failure counts concern the declared display contrast, not missing
source particles. Native populations and positions remain correct.

At low exposure on gray, **all 208 in-frame fluid and 96 wall centers** fail
Compatibility coverage, with zero local contribution; VTK's 208 fluid centers
fail but its wall centers pass; Forward+ passes both roles. On white, all
**304** in-frame centers fail in both Wavez renderers and VTK: additive markers
cannot contrast with saturated white. Role-direction checks fail when the
isolated marker is invisible; no role-ID corruption is inferred.

Representative t=0 near-wall isolated markers:

| Marker measurement | Compatibility | VTK | Forward+ |
|---|---:|---:|---:|
| Fluid row 486 peak contrast | 0.066667 | 0.078431 | 0.313725 |
| Fluid row 486 FWHM | 6.383 px | 7.485 px | 9.305 px |
| Wall row 2118 peak contrast | 0.239216 | 0.239216 | 0.529412 |
| Wall row 2118 FWHM | 6.383 px | 6.383 px | 9.837 px |

Opaque-depth controls hide a rear wall probe while preserving foreground fluid;
a plane behind the source leaves markers visible. Near/far clipping controls
hide the complete population. Color and apparent-width differences do not imply
changed world positions or physical SPH radii.

A separate float64 raster/color diagnostic predicts the observed Compatibility
approximate transfer/display-space addition and Forward+ linear accumulation/sRGB
output. Across **27 non-plane views**, maximum RGB residual is **0.004278 /
0.006629**, respectively. This supports the shared color/blending explanation;
it neither replaces VTK nor changes failed comparison gates to PASS.
Existing scoped [particle follow-up #363](https://github.com/mongstad/Wavez/issues/363)
(proposed **P2**, scientific presentation consistency) covers the color/width
contract; [engine experiment #362](https://github.com/mongstad/Wavez/issues/362)
covers Compatibility low-code transfer. These findings extend their reproductions
to fluid/wall roles. No gamma compensation, rendering fix or engine adoption is
included here.

## Negative controls, reproduction and limits

Both renderers detect a valid capture with **one fluid role flipped** and another
with **one x coordinate shifted by 0.01 m**. Each negative process exits 1 with
two expected native failures; the position control moves its isolated centroid
**24 px**. The altered-role image changes by **0.215686 / 0.490196** peak RGB.
An actual switch to gray LUT preserves source/GPU attributes and native exit 0,
but removes the expected fluid marker in both renderers: the predeclared local
contrast gate detects this image-only failure. All **six controls are detected**.

The initial negative-run wrapper incorrectly demanded >0.08 RGB change even for
a coordinate perturbation. Compatibility's moved dim marker changed by only
0.066667, despite failing the original position/projection gates. That failed
harness attempt is retained. Final control assessment uses the already-declared
0.75 px centroid gate for displacement and 0.02 contrast gate for disappearance;
no tolerance changed. RGB magnitude alone would have missed a scientific error.
An initial editor import logged sandbox socket/global-settings failures; a clean
isolated-profile import succeeded. Both logs remain external; generated sidecars
for unchanged baseline scripts are excluded from the report-only diff.

**NOT RUN:** independent nonlinear dam-break/experimental accuracy, full 3D SPH,
physical midpoint-error bounds, dynamic role changes, alternative marker modes,
release packages, other OS/GPU/driver combinations, calibrated physical displays,
large-population/long-session performance, video and experimental Selection/Analysis.
No suite-wide cross-visualizer certification is claimed. Focused checks match this
report-only issue; unrelated application regressions were not run.

Only this original report enters Git. External license inventories retain source,
PySPH, VTK/environment and Godot provenance, versions and available notice hashes.
No third-party payload, benchmark code/data/image or dependency enters Wavez or
its distributable. PolyForm Noncommercial 1.0.0, product code, version, packaging,
current behavior guides and the accepted baseline report remain unchanged.

Before acceptance, verify the one-file diff; run the reproduction commands and
inspect `assessment.json`, `negative-results.json`, `analytic-pipeline-results.json`
and original PNGs. `review-0/1/2.png` provide labeled comparison sheets without
brightness adjustment. Compare full-tank versus zoomed fluid visibility, both
roles, larger markers, low/white backgrounds and opaque-depth controls. Owner
review is pending; no release or product fix is proposed.
