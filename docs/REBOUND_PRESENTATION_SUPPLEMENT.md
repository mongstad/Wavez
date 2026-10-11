# REBOUND particle presentation: independent visualizer supplement

Issue [#357](https://github.com/mongstad/Wavez/issues/357), executed 2026-10-11.
**PASS:** tested identities, coordinates, temporal policy, screen locations,
clipping and opaque-depth controls. **FAIL:** some local contrast, color and
apparent marker-width comparisons, despite passing aggregate image checks.
The original REBOUND scientific report remains unchanged; this supplement does
not certify all particle presentation or experimental Selection/Analysis.

## Scope and reproduction

Wavez **1fb39d3a9fba2bafaafc25537b327f4ab4670b6b**, **v0.1.0.94**;
Godot **4.7.2.stable.official.ed1daf0bf**, full revision
`ed1daf0bf001b61586d9930840f2f1394092c079`. Native Compatibility/OpenGL and
Forward+/Vulkan on Linux **7.2.9-200.fc44**, x86_64, glibc **2.43**, Ryzen 7
5800X, RTX 3070 Ti 8 GiB, NVIDIA **615.71.09**.

All scripts, images, fixtures, logs and detailed evidence remain external:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/01_REBOUND/issue-357-presentation/`.
The independent reference uses **VTK 9.7.0**, Python **3.12.15**, NumPy **2.5.4**
and Pillow **12.3.0** from the existing external FEniCSx environment. A focused
two-state physical comparison uses the existing REBOUND **4.4.10** environment
(Python **3.14.8**, NumPy **2.4.2**, SciPy **1.17.0**). No dependencies were installed
or bundled for this supplement.

```sh
cd /home/Nozba/Codex/Wavez/Wavez-Benchmarks/01_REBOUND/issue-357-presentation
sha256sum -c SHA256SUMS
../../04_FEniCSx/environment/bin/python prepare.py
python3 reproduce.py owner-review
cat owner-review/assessment.log
```

Use a fresh output name and native GPU/display access. The presentation replay
reuses the capture; it does not rerun the original scientific simulation.
Optional direct physical-state comparison: `../.venv/bin/python direct_midpoints.py`.
Seven original inputs/scripts match their historical SHA-256 manifest. All
**4,004** current source-position/ID/body-index/time checks pass. The source
capture hash remains
`99e412c03c58e7a14e4a53d18785271c0bcaa03b01266f0d4b781c8642bd6b78`.

A complete fresh replay exactly repeated all numerical assessment results,
negative-control results and **1,210 PNGs**. Both positive native runs completed
**1,327 checks, zero failures**, clean logs and exit 0. Those checks establish
source/display geometry and timing, not universal image fidelity. Final assessment:
**2,002 checks: 1,812 PASS / 190 FAIL**, including supplemental blending diagnostics.
Runner exit 0 means collection completed, not scientific acceptance.

## Matched data, cameras and representation

Original `01_REBOUND/run-02/solar.wvz` contains the idealized Sun and eight planets,
AU coordinates, model years and exact int64 IDs above 2^53. Rows deliberately
rotate per sample. This is a constructed Newtonian test model, not observed
ephemerides. Four recorded samples (indices **0, 10, 500, 1000**) and two
midpoints (**10/11, 500/501**) are compared by ID. Wavez and VTK use identical
ID-linear positions at midpoints; body-index scalars hold their source sample.
Native requested/held clocks use original binary float64 time expectations.

Each time has three **800×600** orthographic views:

| View | Target | Vertical extent | Particle size setting |
|---|---|---:|---:|
| Full system | Origin | 72 AU | 8 |
| Inner planets | Origin | 4 AU | 1 |
| Distant body | Exact Neptune position | 6 AU | 4 |

Cameras are target+(0,0,80), up Y, near/far **0.05/200 AU**. Eight further t=0
controls cover **45° perspective**, low contrast, white background, Earth/Sun
aligned overlap, an opaque plane between them, near/far clipping and a marker
on the viewport edge. Every exact camera/vector is recorded in `cases.json`.
The opaque plane is diagnostic geometry, not a celestial body.

Production Scientific particle mode is a camera-facing quad of nominal diameter
**0.36×0.35×Particle size AU**, with Gaussian opacity `exp(-14*r²)` inside unit
radius and additive blending without particle depth writes. These are presentation
markers, **not physical planetary radii**. Fixed viridis maps body_index over
**[0,8]**; gamma/brightness=1, exposure=**0.25** except the **0.025** low-contrast
control. Backgrounds are black, 0.08 gray or white; linear tonemap, no trails,
glow, fog, guides or overlays.

VTK's independent `vtkPointGaussianMapper` uses the same world radius, camera,
source positions, Gaussian falloff and emissive/additive policy. Opaque geometry
is submitted first, then emissive markers. VTK uses explicit nearest-table RGB;
Wavez linearly samples its RGB8 texture from the same 256-entry viridis table.
That small encoding/sampling difference is retained rather than fitted away.
A second VTK run reports its requested sRGB framebuffer as active, yet all
286 images remain byte-identical: this option alone did not match Forward+'s
linear-light blending/tonemapping in this setup.

Each scene includes all-body, background-only and nine isolated-body images.
These expose missing, hidden and overlapping bodies that a whole-image average
could miss. An independent float64 camera basis/projection checks both Godot
`unproject_position` and VTK `WorldToDisplay` numerically.

## Predeclared local gates and measured outcomes

`TOLERANCES.json` was saved before rendering; SHA-256
`6cac88efa4aaaf6de97b220c154bd8c606ceeea260e1855dcf2b113ea777555e`.
No thresholds were relaxed. FWHM diameter is the equivalent circle diameter of
pixels at least half an isolated marker's peak. Centroids use positive
background-subtracted intensity and pixel centers; clipped half-markers are
excluded from the symmetric-centroid gate.

| Gate | Limit | Result |
|---|---|---|
| GPU position by exact ID | 5e-6 AU | **PASS**, max 8.37454e-7 AU |
| Independent screen projection | 0.001 px | **PASS**, Godot max 0.000488282 px; VTK <9.38e-13 px |
| Resolved isolated centroid, native/reference and native/oracle | 0.75 px | **PASS**, maxima 0.134898 / 0.048309 px |
| FWHM difference | max(1.5 px, 20% reference) | Compatibility **PASS**; Forward+ **40 FAIL** |
| Local peak RGB difference | 0.08 | Compatibility **PASS**; Forward+ **108 FAIL** |
| Visible-marker peak contrast | ≥0.02 | **FAIL** in low/white cases as detailed below |
| Local RGB MAE / aggregate RGB MAE | 0.06 / 0.025 | **PASS** for all tested comparisons |
| Fully clipped or opaque-occluded peak | ≤0.008 | **PASS** in both renderers/reference |
| IDs, body-index association, held clock and interpolation status | Exact declared policy | **PASS** |

A supplemental display-byte addition diagnostic uses a 2/255 quantization check.
Its **seven Forward+ FAILs** are retained: adding already encoded sRGB bytes is
not equivalent to Forward+'s linear-light blending. These failures identify a
comparison-domain limitation, not seven additional coordinate or opacity defects.

The assessment includes **958 PASS / 20 FAIL** for Compatibility,
**828 PASS / 170 FAIL** for Forward+, and **26 PASS** VTK projection checks.
Compatibility's 20 failures comprise ten native and ten reference contrast
failures. Forward+'s 170 comprise 108 peak-color, 40 width, ten reference contrast,
five native contrast and seven supplemental byte-addition failures.

## Visibility, color and apparent size

The opaque plane hides the rear Sun marker while preserving foreground Earth.
Near/far and viewport controls agree. Particle-particle overlap remains additive;
it does not model opaque physical-body occultation. Inner-planet clustering in
the full view is exposed by the per-ID isolated images and resolved zoomed views.

All five in-frame inner bodies become invisible on white in both tools: additive
color over saturated white cannot provide contrast. At low exposure against 0.08
gray, all five fail the 0.02 contrast floor in Compatibility and VTK. These local
failures remain significant even when aggregate error passes.

| Representative t=0 marker | Compatibility | VTK | Forward+ |
|---|---:|---:|---:|
| Distant Neptune peak contrast | 0.2431 | 0.2431 | 0.5333 |
| Distant Neptune FWHM | 11.94 px | 11.94 px | 16.27 px |
| Inner Earth peak contrast | 0.1294 | 0.1373 | 0.4039 |
| Inner Earth FWHM | 4.22 px | 4.37 px | 5.97 px |

Nominal world size, positions and IDs agree. Forward+'s brighter encoded Gaussian
has a different visible width; this is not a larger physical body or a displaced
orbit. A separate float64 raster/color model predicts Compatibility's approximate
transfer/display-space addition and Forward+'s linear accumulation/sRGB output.
Across 25 non-occluded scenes, maximum RGB residuals are **0.003897** and
**0.004454**, respectively. This supports a color/blending explanation without
replacing the original VTK comparison or converting its failed gates to PASS.
Opaque-depth behavior is checked separately by the native/VTK controls.

Scoped follow-up [#363](https://github.com/mongstad/Wavez/issues/363) records the
presentation-contract discrepancy and reproduction, with proposed **P2** severity.
It asks for an explicit particle LUT/blending/apparent-size contract before any
correction, coordinated with the existing engine-color experiment #362. No gamma
compensation, renderer change, engine adoption or source normalization is applied.

## Interpolated display versus physical states

Only two additional direct IAS15 states were evaluated from the retained initial
conditions. The independent visualizer compares the same ID-linear display
policy; it is not silently substituted with physical integration at those times.

| Midpoint (model years) | Max component difference from direct REBOUND | Mercury shift in inner view |
|---:|---:|---:|
| 0.15266498422802605 | 0.007210789425 AU | 1.189416 px |
| 9.536573920102345 | 0.011449394710 AU | 2.038756 px |

These are interpolation-versus-trajectory differences, not transport, identity or
projection errors. Native-time and midpoint presentation locations pass against
their respective declared policies. The original scientific report remains valid
for its recorded scope.

## Negative controls, retained attempts and limits

Both renderers detect an actual **1 AU camera/target shift**, the original valid
capture's **0.001 AU position perturbation**, and its **altered Mercury int64 ID**.
The six negative processes each exit 1, with respectively **9, 2 and 4** expected
failures. Positive native runs exit 0; no failed negative is counted as a clean
production run.

Retained VTK harness failures include missing shader material initialization,
opaque geometry submitted after emissive sprites, and an incompatible forced
translucent-pass attempt. Shader and foreground-depth controls exposed them.
Final reference runs retain emissive markers with opaque-first ordering, clean
shader logs and verified front/rear visibility. Earlier native outputs are also
retained; adding binary held-clock assertions did not change their PNGs.

**NOT RUN:** release packages, other operating systems/GPUs/drivers, calibrated
physical display, large-particle/long-session performance, video, experimental
Selection/Analysis, physical body surfaces/radii or observed ephemerides. No
suite-wide independent-visualizer certification is claimed. Validation targeted
this report's presentation scope; unrelated application suites were not run.

Only this original report enters Git. External inventories retain dependency
versions, license/notice hashes and artifact provenance for the reused REBOUND
and VTK environments. No third-party source, runtime, capture or image enters
Wavez; PolyForm Noncommercial 1.0.0, application version and packaging are unchanged.

Before acceptance, confirm the report-only diff and unchanged original benchmark
report; run the commands above; inspect `assessment.json`, negative controls and
per-ID images alongside full/inner/distant views. Review color/width failures and
interpolation-versus-physics differences before interpreting marker appearance.
Owner review is pending; no product fix or release is included.
