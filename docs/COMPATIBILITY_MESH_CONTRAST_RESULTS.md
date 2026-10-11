# Compatibility near-black mesh color limitation

Issue [#356](https://github.com/mongstad/Wavez/issues/356), executed 2026-10-11.
**FAIL: the tested Compatibility renderer loses near-black mesh color distinctions
before framebuffer readback.** This repeats the original FEniCSx observation.
Source arrays, geometry, scientific calculations and uploaded color attributes
remain intact. The measured loss is explained by Godot's approximate color
transfer functions, independently of the RF readback issue in #354.

This investigation documents an unsupported presentation case and qualified
mitigations. No Wavez shader, material, source value or engine binary is changed.

## Reproduction and scope

Wavez **346b5b3d046b6252ea14c3b0f5b04e9801ef1c18**, **v0.1.0.94**;
Godot **4.7.2.stable.official.ed1daf0bf**, full revision
`ed1daf0bf001b61586d9930840f2f1394092c079`. Native Linux
7.2.9-200.fc44 x86_64, glibc 2.43, Ryzen 7 5800X, RTX 3070 Ti 8 GiB,
NVIDIA **615.71.09**. Both Compatibility/OpenGL and Forward+/Vulkan were executed.

All diagnostic code, inputs, images, raw measurements and dependencies are external:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-356-mesh-contrast/`.
Its README details setup, methods and retained attempts. The existing external
`04_FEniCSx` environment and original capture are reused without a solver rerun.
Python **3.12.15**, NumPy **2.5.4**, SciPy **1.18.1**, Pillow **12.3.0**,
VTK **9.7.0**, PyVista **0.49.0**; live inventory and license references are retained.

```sh
cd /home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-356-mesh-contrast
sha256sum -c SHA256SUMS
python3 reproduce.py owner-review
cat owner-review/assessment.log
```

Use a fresh output directory and native GPU/display access. Expect **186 assessment
checks: 154 PASS / 32 FAIL**. Orchestration exit 0 means evidence collection
completed; it does not erase failed scientific display checks. A fresh full run
(`reproduction-check`) exactly repeated every assessment value and all **83 PNGs**.
Six native benchmark runs each completed **33,375 checks, zero failures**, clean
logs and exit 0; those checks cover source/geometry/attributes, not pixel fidelity.
Three VTK benchmark runs each passed **102** source/geometry/probe checks.

Six original inputs/scripts match the historical benchmark hash manifest. All
16 original-view native PNGs byte-match #349's retained r3 PNGs. Original #348,
#349 and #354 reports and evidence remain unchanged. Unrelated application suites,
packaging and particle/field regressions were not run for this report-only change.

## Independent fixtures and predeclared gates

The original capture is
`04_FEniCSx/run-01/analysis/elasticity.wvz`. Face strain-energy density uses gray,
**0–4 J/m³**, at **0.5, 0.5625 and 1 s**; vertex displacement magnitude uses gray,
**0–0.05 m**. At 0.5625 s geometry interpolates while scalars hold the 0.5 s sample.
Camera **(2.2,1.8,2.6)**, target **(0.3,0.6,0.15)**, up Y, orthographic height
**1.9 m**, near/far **0.01/10 m**, **800×600**, white background, opaque unshaded
mesh, linear tonemap, no fog/glow/adjustments. Independent VTK uses the same
physical geometry, camera, scalar association and quantized colormap.

A deterministic mesh contains gray/red/green/blue swatches with byte codes
**0–12, 16, 24, 32, 64, 128, 254, 255**. Twenty quads per row occupy
x=[-10,10], y=[-2,2], z=0; camera (0,0,2), target zero, orthographic height 4,
near/far 0.01/10, **800×160**. Each 40×40 tile is measured at its center.
Unshaded production-style StandardMaterial, custom spatial shader, sRGB-flag,
amplification, CanvasItem and independent VTK controls separate pipeline stages.
The swatch fixture bypasses scientific file loading; the original capture path
separately verifies source and prepared/uploaded attributes.

`TOLERANCES.json` was saved before new rendering. Local gates require:

- Minimal swatches: error ≤**1 byte/channel**, every nonzero reference remains
  nonzero, and codes 1–6 retain at least **five distinct output levels**.
- Original/mitigation interiors: ≥**99%** nonzero-reference retention and RGB
  99th-percentile error ≤**1 byte**.
- Original aggregate gates remain MAE ≤**0.025**, p99 ≤**0.06**, silhouette IoU
  ≥**0.98**, projection error ≤**0.001 pixels**. Native geometry and color bounds
  remain **2e-6 m / 0.0041**.

Two-pixel-eroded original mesh silhouettes define a geometry-fixed interior ROI
for all mappings. This keeps legitimately saturated white faces in the test.
The first assessment incorrectly derived the ROI from each changed image and
failed on an all-white narrow-range case; its source is retained. Correcting the
ROI did not change images or tolerances. Original silhouette IoU is **1** and
maximum independently compared projection error **9.5071e-5 pixels**.

## Measured results

| Check | Compatibility | Forward+ / independent control |
|---|---|---|
| Original source hashes, mesh geometry, channel association, uploaded attributes | **PASS** | **PASS** |
| Gray and primary-color swatches, production-style material | **FAIL**, codes 1–7 become 0; maximum error 7 bytes | **PASS**, exact tested bytes; VTK exact |
| Same swatches through custom spatial shader | **FAIL**, same loss | **PASS**, exact tested bytes |
| Same framebuffer/readback through 2D CanvasItem | **PASS**, exact tested bytes | **PASS**, exact tested bytes |
| Face energy, 0.5 s, original range | **FAIL**, 112,158/112,158 reference-nonzero interior pixels become black | **PASS**, none lost, p99 error 1 byte |
| Face energy, 0.5625 s, original range | **FAIL**, 112,094/112,094 become black | **PASS**, none lost, p99 error 1 byte |
| Aggregate image bounds, all tested mappings/times/channels | **PASS** despite local failures | **PASS** |

Compatibility reference levels 1–6/255 collapse to one level, zero. Forward+
retains native face levels 1, 2, 4 and 5/255 within the declared one-byte bound.
Other illustrative Compatibility input→output codes are **8→1, 12→6, 16→11,
32→30, 64→64, 128→128, 255→255**. Red, green and blue exhibit the same low-code
loss; it is not confined to grayscale.

All **32 failed assessment rows** remain explicit. Besides Compatibility losses,
Forward+ vertex comparisons at 1 s exceed the new one-byte local gate: gray p99
**2 bytes** (original and narrow-face-range controls), viridis p99 **11 bytes**.
Thus even the Forward+ mitigation is supported for the tested low-energy face
views, not a general claim of VTK-equivalent vertex interpolation or color fidelity.

## Where the distinctions disappear

Wavez prepares colormap colors and enables `vertex_color_is_srgb` on its unshaded
mesh material. Godot's generated StandardMaterial vertex conversion is conditional
on `!OUTPUT_IS_SRGB`; toggling this flag leaves Compatibility's result unchanged.
Disabling it in Forward+ produces up to **73 bytes** error in the swatches, so a
flag toggle is not an acceptable cross-renderer correction.

At the tested engine revision, the Compatibility
[scene shader](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/shaders/scene.glsl#L2398)
converts ALBEDO to linear even for unshaded rendering, then converts the output
back to sRGB before writing. Its
[transfer functions](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/shaders/tonemap_inc.glsl#L14)
use a cubic approximation on input and a power expression clamped to zero on
output, omitting the exact piecewise near-black branches. Their composed CPU
prediction matches all tested Compatibility standard/custom/flag/amplified
swatch controls within **one byte**.

The composition mathematically clamps input below approximately **0.02684726**
(**6.846/255**) to zero; framebuffer quantization also rounds input code 7 to zero.
Nonzero attributes survive upload and can be exposed by intentional shader
amplification, but that changes the mapping and saturates other values. This is
diagnostic evidence, not a fix. The opaque constant swatches remove interpolation
and blending as necessary causes; the 2D control proves the framebuffer/readback
can preserve these byte levels. This differs from #354's RF texture readback.
Physical monitor/compositor behavior remains **NOT VERIFIED**: the measured loss
already exists in the captured framebuffer before that stage.

## Mitigations and implementation decision

Prefer **the tested Forward+ path for the original low-energy face-energy views**.
If using Compatibility, explicitly selecting gray **0–0.1 J/m³** restores
nonzero face retention in the two low-energy views, but p99 color error remains
**5 bytes**, failing the fidelity gate. Later higher energies saturate white;
this is a changed physical display range, not an equivalent image.

Selecting **viridis at the original range** also restores nonzero face retention,
but Compatibility p99 error reaches **8 bytes**. Record the chosen range/LUT and
check source probes; neither mitigation certifies accurate color or resolves
all low-value components. Do not infer zero physical energy from a black mesh.

The localized mechanism is in shared engine color conversion. A separately
reviewable candidate is to replace both approximate functions with exact
piecewise sRGB transfers and validate an engine build. Shared lighting, fog,
textures, particle/field colormaps, opacity and tonemapping make an untested
Wavez compensation or custom engine distribution inappropriate here. No arbitrary
brightness/gamma multiplier, nonzero floor or scientific-value normalization is
introduced. Any subsequent product fix needs face/vertex and representative
particle/field tests on both renderers, plus relevant platform/package checks.

**NOT VERIFIED:** other GPUs/drivers/OSes, Mobile, rebuilt/patched engine,
calibrated physical display/HDR/compositor, lit/translucent meshes, fog/glow,
other LUTs, particle/field effects, package/video behavior and long sessions.
No general scientific visualization or GPU precision certification is claimed.

Only this original report enters Git. The external license inventory points to
the reused environment's retained dependency notices and five inspected Godot
source files with their MIT license. No third-party code/assets enter Wavez;
PolyForm Noncommercial, version and packaging remain unchanged.

## Owner verification

1. Confirm the PR adds only this report and preserves historical results.
2. Run the commands above with a fresh directory; expect **154 PASS / 32 FAIL**.
   Inspect `assessment.json` rather than treating runner exit 0 as acceptance.
3. Compare `original-compatibility/face-08.png` and `face-09.png` against
   `original-forward` and `pyvista-white`; inspect the exact nonzero-loss counts.
4. Review `swatches-compatibility/standard_srgb.png`, `canvas_control.png` and
   their JSON byte measurements. Then compare narrow/viridis images and failed
   local fidelity checks before accepting any mitigation for scientific use.

Owner review is pending. No engine/product fix or release is included.
