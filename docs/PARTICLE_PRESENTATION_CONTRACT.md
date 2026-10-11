# Particle presentation: measured baseline and proposed contract

Issue [#363](https://github.com/mongstad/Wavez/issues/363), 2026-10-11.
**Decision requested: agree the color, blending, opacity and size contract below
before evaluating a correction.** This is an investigation and proposal, not an
implemented rendering fix. Issue §4 requires that agreement first. No candidate
shader or patched engine was evaluated; current appearance remains unchanged.

The measured discrepancy has several distinct boundaries: Compatibility packs
per-instance display attributes into half precision; the renderers interpret and
blend particle RGB differently; cinematic alpha above one also behaves differently.
Source data, units, int64 IDs, positions and sample clocks remain intact in these
tests. Severity remains **P2: scientific presentation consistency**. A global
gamma/brightness adjustment cannot establish the missing shared contract.

## Evidence and reproduction

Wavez **406ad46ed355ec4e528a1fae61ebcf115b2bdb19**, **v0.1.0.94**, official Godot
**4.7.2**, revision `ed1daf0bf001b61586d9930840f2f1394092c079`; Compatibility/OpenGL
and Forward+/Vulkan. Linux **7.2.9-200.fc44**, x86_64, glibc **2.43**, Ryzen 7 5800X,
RTX 3070 Ti **8 GiB**, NVIDIA **615.71.09**. Analysis uses existing Python
**3.12.15**, NumPy **2.5.4**, Pillow **12.3.0**; the original reference uses
**VTK 9.7.0**. No scientific solver was rerun or dependency installed.

External workspace:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-363-particle-contract/`.

```sh
cd /home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-363-particle-contract
sha256sum -c SHA256SUMS
../04_FEniCSx/environment/bin/python verify_source.py
python3 reproduce.py owner-review
cat owner-review/assess.log
```

Use a fresh output name and native GPU/display access. Collection explicitly
retains Compatibility's precision failures; exit 0 from the orchestrator is not
an all-PASS scientific result. The external README gives the separate original
REBOUND replay command, dependencies and artifact/licensing inventory.

The requested #357 replay exactly repeats its **2,002 gates: 1,812 PASS / 190 FAIL**,
negative/analytic results and **1,210 PNGs** on this accepted baseline. Its original
thresholds, scripts, cases and evidence remain unchanged. The first and final
new matrix runs also repeat **1,168 shared PNGs exactly**; final instrumentation
adds CPU-boundary checks and two perspective export snapshots per renderer.
A fresh complete final replay repeats both native result files, all three
assessment/model/export result files and **1,182 PNGs exactly**.

Four original diagnostic captures each contain 16 particles and three samples;
IDs exceed 2^53 and rows rotate. Position translation makes the t=0.125 midpoint
observable. **72** exact typed-array/time comparisons, strict format and identity
checks pass. These swatches are not physical simulation data.

The **32 matched 800×600 cases** cover direct RGBA, gray/viridis scalar mappings,
Gaussian and cinematic kernels, black/0.08-gray/white backgrounds, exposures
0.25/0.025, sizes 2/1, orthographic/perspective cameras, independent opacity/RGBA
alpha, coincident RGB markers and an opaque plane. Cinematic kernels are isolated
with sky, fog and glow disabled; this does not certify the complete artistic
preset. All/world projections, camera settings and per-marker images are external.

## Where the differences arise

### LUT upload is floating point; earlier RGB8 attribution is corrected

`main.gd::_update_colormap` constructs **Image.FORMAT_RGBF**, and has done so since
the original source baseline. The particle sampler has linear filtering and no
`source_color` hint. Texture readback remains RGBF in both tested renderers.
A separate canvas diagnostic samples the **same production texture**, amplifies
the residual 100× and reads RGB8 output. Gray and viridis samples differ from the
original entries by at most **1.960785e-5**, within its **5e-5** gate; a deliberately
injected **0.002** error is detected in both renderers. The readout's own
quantization uncertainty is about 1.96e-5.

The earlier [REBOUND](REBOUND_PRESENTATION_SUPPLEMENT.md) and
[PySPH](PYSPH_PRESENTATION_SUPPLEMENT.md) supplements described an RGB8 LUT and
used that assumption in their supplemental analytic models. **That attribution
is not supported by these direct measurements and is superseded here.** Their
recorded images, errors and PASS/FAIL findings are unchanged; historical reports
are preserved. An approximate image fit alone did not establish upload format.

### Per-instance display attributes lose precision in Compatibility

The shared preparation path retains source values and writes float32 display
buffers. CPU prepared color/alpha matches its float32 expectation exactly here.
Compatibility then truncates those components into 16-bit floating point; Forward+
retains float32. Godot documents this [MultiMesh distinction](https://docs.godotengine.org/en/4.4/classes/class_multimesh.html#class-multimesh-method-set-instance-custom-data),
and the pinned [GLES3 packing code](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/storage/mesh_storage.cpp)
uses `Math::make_half_float`. Its mantissa truncation also affects scalar LUT
coordinates, not just direct RGB. This is separate from LUT texture precision.

The predeclared **1e-6** custom-data error gate fails **140 times** in Compatibility,
maximum **0.000395298005**; Forward+ passes. An independent packing calculation
matches the returned components to numerical roundoff. These failures remain
FAIL, not a retrospectively loosened display-precision tolerance. GPU position
error is only **3.337861e-8 m**, projection error **2.157919e-5 px**; identity, clocks,
source mapping and CPU preparation checks pass. Exact scientific values and IDs
are not recovered from these reduced-precision display attributes.

### Color transfer, blending and cinematic alpha are separate mechanisms

The production shader is unshaded/additive. Its effective color output comes from
ALBEDO; the written EMISSION term does not triple the output in the tested unshaded
engine branches. Raw LUT/direct components, brightness, gamma and exposure reach
that output without a shared explicit sRGB decode. Godot's [output color-space
contract](https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html)
differs by renderer. Pinned official source and measured residuals support:

- **Compatibility:** approximate sRGB→linear→sRGB conversion of the material
  output, followed by addition in display space. Near-black components can vanish.
- **Forward+:** linear accumulation followed by sRGB encoding. The same numerical
  palette values therefore produce brighter encoded peaks and wider visible tails.
- **Cinematic kernel:** its center weight is **2.03**, exceeding one. Compatibility
  matches clamping of effective alpha to one; Forward+ matches unclamped alpha.
  This adds a distinct discrepancy beyond the Gaussian color-space case.

An independent raster model uses original float LUT values, predicted instance
packing and source-projected geometry. Across **30 non-plane cases**, the matching
models have maximum RGB residual **0.003729 Compatibility / 0.002406 Forward+**,
within the declared **0.012** limit. The opposite alpha-clamping hypothesis fails
nine cinematic cases in each renderer, reaching **0.251723 / 0.200157** error.
This identifies effective behavior; no claim is made to have instrumented every
driver stage. Opaque-depth controls are measured separately.

Fixing only the approximate transfer functions in the separate
[engine experiment #362](https://github.com/mongstad/Wavez/issues/362) would not
establish matching palette interpretation, blending, alpha handling or MultiMesh
precision. No #362 engine work or #303 accessibility implementation is included.

## Measured gates, visibility and exports

`TOLERANCES.json` was saved before rendering, SHA-256
`b8383bef11e7fa8b4fc131119983e76014fcb1dd74b11aa19b257583c76e60e9`.
No existing threshold changed. Native totals: **3,270 checks per renderer**;
Forward+ has zero failures; Compatibility has the **140** attribute failures above
and exits 1. Its log is not described as a clean all-PASS run.

The separate image/LUT/Save Image assessment has **2,633 gates: 1,654 PASS /
979 FAIL**: **400 contrast**, **284 cross-renderer peak RGB**, and **295 FWHM**
failures. These are repeated gates, not counts of independently discovered bugs.
Nonzero low-value controls intentionally receive visibility outcomes; not every
contrast failure denotes missing source data. Black/zero-alpha/fully occluded
markers are expected invisible and pass all **68** such checks.

| Gate | Limit | Result |
|---|---|---|
| GPU position / projection | 1e-6 m / 0.001 px | PASS |
| CPU prepared / returned GPU custom data | 1e-6 | CPU and Forward+ PASS; Compatibility FAIL |
| Isolated centroid | 0.75 px | All 601 measurable checks PASS; max 0.115613 px |
| Local visible contrast | ≥0.02 | 400 FAIL, including white-background disappearance |
| Cross-renderer isolated peak RGB | 0.08 | 284 FAIL |
| Cross-renderer FWHM | max(1.5 px, 20% Compatibility width) | 295 FAIL |
| Whole-image RGB MAE | 0.025 | All 32 PASS; max 0.00299451 |
| Save Image versus same live view | max RGB 0.008 | All 12 PASS; exact pixels |
| Production raw video frame versus live perspective view | max RGB 0.008 | All four PASS; max 1/255 |

FWHM is equivalent-circle half-peak area in the **encoded image**. It varies with
exposure, transfer and background; it is not a world radius or physical particle
size. Centroids use background-subtracted intensity. Whole-image averages conceal
the local discrepancies in this sparse fixture.

For a white direct marker, exposure 0.25, black background and identical nominal
size: Gaussian peak/FWHM is **0.247059 / 10.585 px** in Compatibility versus
**0.533333 / 15.472 px** in Forward+. Cinematic peak is **0.247059 versus 0.733333**.
For a direct **4/255** gray marker, Gaussian peaks are **0 versus 0.050980**.
All additive markers disappear over saturated white. Opaque-plane controls hide
rear red/green markers and retain the foreground blue marker; particles do not
become opaque physical spheres or a reconstructed fluid surface.

Four unmodified version-1 workers export perspective Gaussian/cinematic stills
in both renderers, completing real H.264/yuv420p encoding with retained PNGs.
The raw-frame one-code difference reflects the worker's default background;
custom background/projection/orthographic size are not serialized by the existing
visual snapshot. Harness-only orthographic/custom-background jobs are not asserted
as ordinary supported exports. No export-state feature is added here.

Decoded MP4 differs from raw PNG by maximum **0.043137–0.070588** RGB; MAE ranges
**0.00002523–0.00137641**. Those lossy-codec measurements are descriptive, not a
newly invented acceptance gate or proof that video preserves exact scientific
colors. FFmpeg build/configuration, stream metadata and timing manifests remain
external. The original six REBOUND negative controls and four new LUT-error
controls detect their injected discrepancies.

## Proposed contract for owner agreement

**Recommendation: define palette/direct RGB as display-encoded sRGB, with one
explicit decode into a common linear accumulation space.** Retain additive
presentation markers and source geometry. This is a proposed target, not a claim
that either current renderer already implements it.

| Boundary | Proposed requirement |
|---|---|
| Scientific source | Preserve typed arrays, units, int64 IDs, clocks and current ID-linear/held-scalar policy. Display values never replace numerical source data. |
| Palette/direct RGB | Interpret both consistently as encoded sRGB. Keep fixed scalar range/LUT semantics. Specify LUT interpolation in encoded palette space, then decode once; do not independently gamma-correct channels or infer physical emission. |
| Brightness/exposure/gamma | Make brightness and exposure explicit linear presentation gains after decode. Keep user gamma an explicitly recorded display-domain transform before decode; gamma 1 is identity. Defaults and conversion of old visual states require an explicit implementation decision. |
| Opacity and kernel | Source opacity and RGBA alpha multiply as coverage weights in [0,1]. Use the same explicitly clamped effective kernel weight in both renderers; artistic gain must be a separate intensity decision, not backend-dependent alpha above one. |
| Composition | Add linear marker contributions to the linear background, then encode once. Preserve opaque depth testing and no particle depth writes. Disclose saturation and white-background invisibility; changing to alpha-over/opaque markers would be a separate representation decision. |
| Size | Preserve world quad extent and camera projection. Measure geometric extent independently of encoded FWHM. Use linear-intensity kernel width for the nominal profile; retain local encoded contrast/FWHM gates for actual visible appearance. |
| Precision | State per-instance packing limits explicitly. CPU/source checks remain strict. Bound the effect of reduced scalar coordinates on the selected LUT, including steep/category boundaries; do not use a relaxed global color threshold to hide classification errors. |
| Images/video | Apply identical recorded visual state in live and raw-frame paths. Gate raw PNGs separately from lossy encoding; state supported camera/background settings and color metadata. |

With gamma 1, the proposed composition is conceptually
`encode(clamp(decode(background) + sum(weight × exposure × brightness × decode(color)), 0, 1))`.
The formula is a review specification, **not a tested correction**. Kernel-weight
clamping would change current Forward+ cinematic cores; explicit color decoding
would change current output. A current-look preservation choice therefore needs
owner approval rather than a silent “consistency” adjustment.

Display-space addition could instead preserve more of Compatibility's current
appearance, but would define a different intensity law. Alpha-over could improve
white-background visibility, but changes overlap/opacity semantics. Neither
alternative is selected or implemented. A global gamma/brightness tweak cannot
make nonlinear encoding commute with arbitrary opacity, overlap and backgrounds.
An exact-transfer-only engine patch also leaves these contract choices unresolved.

After agreement, evaluate one separately reviewable focused candidate against the
same fixtures and unchanged historical gates; include any required new contract
gates prospectively. If common linear composition requires a larger renderer or
engine change, return that scope decision to the owner instead of adopting a fork.

## Review boundary and limits

**NOT RUN:** correction candidate, patched engine, package, other OS/GPU/driver,
full artistic preset, moving/long video, large-population/performance tests,
physical display calibration or experimental Selection/Analysis. The evidence
supports this bounded contract decision, not universal visualizer certification.

This original report/proposal and the required **v0.1.0.95** candidate build
increment enter Git. The measurements above remain tied to accepted v0.1.0.94;
the production rendering source hashes are unchanged. External scripts, source
excerpts, fixtures, images, dependencies and binaries remain outside Wavez.
Rendering behavior, licensing, packaging, current behavior guides and historical
benchmark reports are unchanged. Focused validation follows the investigation's
actual scope; unrelated application suites were not run.

Both Python version-contract tests pass. The required editor import exits 0;
the initial import reports four pre-existing missing resize-script UID sidecars,
which it regenerates. The build-95 import with those sidecars present exits 0
without errors or warnings. These unrelated generated files are retained in the
external evidence workspace, not added to this investigation's diff.

Before acceptance: inspect the two-file diff, replay the external evidence, review
the failed gates and per-marker images, then agree or amend the proposed contract
and implementation boundary. In particular, review the sRGB interpretation,
linear addition and cinematic-alpha change explicitly. Candidate evaluation
remains gated on that agreement; no merge or release is performed by the agent.
