# Particle contract candidate: feasibility failure and owner decision

Issue [#369](https://github.com/mongstad/Wavez/issues/369), 2026-10-11.
**FAIL: the tested material-only candidate does not establish the proposed
cross-renderer linear-light contract. Do not promote it as a rendering fix.**
Issue #369's implementation/acceptance is incomplete; this review records its
explicit requirement-10 decision gate:

> If a consistent contract cannot be achieved safely in Wavez alone, stop with options and request direction.

The result rules out this local material approach, not every possible Wavez
architecture. A separate linear accumulation/compositing design may be possible,
but its depth, other-layer, export and performance implications are untested.
No such redesign, Godot patch/fork, preset/Bloom change or particle-size UX work
is included. Accepted rendering remains active; rollback from the experiment is
simply an ordinary launch without the external harness.

## Candidate and provenance

Read together with the accepted [contract proposal](PARTICLE_PRESENTATION_CONTRACT.md)
and historical [REBOUND](REBOUND_PRESENTATION_SUPPLEMENT.md) /
[PySPH](PYSPH_PRESENTATION_SUPPLEMENT.md) reports. Their evidence and thresholds
are preserved. The RGBF LUT correction in #363 remains applicable.

Measured accepted main: **c4f3f1a949fe9d8800b882211663576fd2d4954c**, **v0.1.0.95**.
Official Godot **4.7.2**, revision **ed1daf0bf001b61586d9930840f2f1394092c079**;
Compatibility/OpenGL and Forward+/Vulkan, Linux/RTX 3070 Ti/NVIDIA **615.71.09**.
Existing analysis environment: Python **3.12.15**, NumPy **2.5.4**, Pillow **12.3.0**.
No solver rerun, dependency installation or engine modification.

The original external `candidate.gdshader` replaces only the production particle
materials' shader at runtime in the harness. It retains their uniforms, LUT,
source preparation, instancing, world quad vertex path, slice discard, opaque
depth testing, additive blend mode and absence of particle depth writes.
Repository rendering code is untouched. This is executable experimental code,
not an enabled product feature or a completed fix.

Its explicit experimental decisions are:

- Treat direct RGB and interpolated RGBF LUT values as encoded sRGB; apply user
  gamma in that domain, then decode. Apply exposure/global brightness and scalar
  mapped brightness as linear gains, without fitted screenshot multipliers.
- Bound source coverage to [0,1]. Normalize the cinematic kernel by its analytic
  center **2.03**, and retain **2.03** as a separate artistic intensity gain. This
  preserves the unclamped kernel's energy law rather than silently clipping its
  center; the choice itself requires owner review. Gaussian gain is one.
- Multiply coverage and intensity before transfer. Write the linear contribution
  in Forward+, its exact sRGB encoding in Compatibility, and `ALPHA = 1` with
  additive blending. This prevents backend-dependent alpha above one, but does
  **not** change the destination framebuffer's accumulation domain.

The existing CPU path precombines direct RGB and per-particle brightness, so that
combination cannot be separated by this shader. This spike uses fixed brightness;
full direct-brightness/gamma contract validation is **NOT RUN** and would require
an explicit preparation/layout decision. Neither original arrays nor source
categories are altered to compensate for display behavior.

## Predeclared gates and measured results

`CANDIDATE_GATES.json` was saved before candidate rendering: maximum normalized
RGB error **0.012** against an independent linear-light raster target and between
renderers, centroid **0.75 px**, nominal active world-diameter error **1e-6**.
The original `TOLERANCES.json` is unchanged. Conditional visibility/centroid checks
can change the number of evaluated gates; comparisons below also match labels.

The matrix reuses #363's four immutable diagnostic captures and **32 matched
800×600 cases**: direct RGBA/scalar gray/viridis, Gaussian/cinematic kernels,
black/gray/white, low exposure, alpha, overlap, opaque depth, size, perspective,
orthographic and an ID-linear midpoint. Bloom, fog and sky are off. These are
diagnostic swatches, not independent scientific simulation validation.

| Measurement | Accepted | Candidate |
|---|---:|---:|
| Native checks per renderer | 3,270 | 3,270 |
| Forward+ native failures | 0 | 0 |
| Compatibility native precision failures | 140 | 140 |
| Historical image/LUT/Save Image gates | 1,654 PASS / 979 FAIL | 2,020 PASS / 616 FAIL |
| Contrast failures | 400 | 476 |
| Cross-renderer peak-RGB failures | 284 | 2 |
| Cross-renderer FWHM failures | 295 | 138 |
| New full-image cross-renderer maximum-RGB gate | Not a historical gate | 6 PASS / 26 FAIL |
| New linear-target gate, Forward+ | Not a historical gate | 30 PASS / 0 FAIL |
| New linear-target gate, Compatibility | Not a historical gate | 6 PASS / 24 FAIL |

Among **2,601 common historical labels**, **483 FAIL→PASS** and **120 PASS→FAIL**;
35 centroid labels become evaluable and 32 cease to be evaluable. Fewer total
failures therefore do not mean the candidate meets acceptance. No threshold was
changed to make it pass. The six passing Compatibility target cases are saturated
white-background controls, not evidence of useful visibility.

The accepted-main replay exactly matches #363's native JSON and **1,172 matrix
PNGs**. Candidate native JSON is also exactly equal to accepted native JSON:
tested source identities, CPU attributes, GPU coordinates, clocks and projected
centers are unchanged. Compatibility's maximum custom-data error remains
**0.000395298005**; its native process exits 1 rather than claiming all-PASS.
Nominal extent follows the same **0.36 × instance basis scale × point scale**
world quad. This does not make encoded FWHM a physical particle diameter.
Maximum active nominal world-diameter error is **4.291535e-9** in fixture units,
within the declared 1e-6 gate.

All measurable candidate centroids pass, maximum **0.186178 px**; expected hidden
controls pass. All **12 production Save Image** comparisons are pixel-exact with
the same candidate viewport. This is an offscreen production SubViewport test,
not certification of ordinary interactive viewport or exported-worker operation.

### Transfer and blending failure

Forward+ matches the independent source-based linear-light target to maximum
RGB **0.002381**. Compatibility reaches **0.029386** error on black and **0.077845**
over gray. A model of Compatibility's actual approximate transfer followed by
display-space addition fits within **0.003476**. Black-background white Gaussian
peak/FWHM matches exactly between candidates (**0.533333 / 15.472 px**), yet that
single-marker success conceals the background/overlap failure.

A new, original capture places **three white markers at the same projected
center**, with distinct depth and unchanged source identities. Unlike coincident
pure red/green/blue controls, this exercises addition within the same channels.
Both Gaussian and cinematic comparisons reach **0.443138** maximum cross-renderer
RGB error. Gaussian peaks are **1.0 Compatibility / 0.874510 Forward+**; isolated
peaks are both **0.533333**. Display-byte addition predicts Compatibility within
**2/255**; linear addition of isolated values predicts Forward+ within **2/255**.
This is a blending discrepancy, not source movement or nominal size change.

Even ideal transfer cannot solve that discrepancy through an independent
per-fragment color function: three linear contributions of 0.01 require
`encode(0.03) = 0.189748`, whereas summing three individually encoded values gives
`3 × encode(0.01) = 0.299558`. The output contribution cannot know the accumulated
destination. Solving that requires changing the accumulation/compositing path or
the intended contract. Merely reading a screen snapshot also does not accumulate
arbitrary overlapping transparent particles.

This agrees with the pinned official Godot
[GLES3 shader](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/shaders/scene.glsl)
and [blend state](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/rasterizer_scene_gles3.cpp).
The separate #362 transfer experiment alone cannot establish common linear
accumulation. No global gamma adjustment or engine workaround was adopted.

### Precision and appearance costs

An eight-value native MultiMesh probe quantifies an adverse scalar boundary.
For source **0.50045**, Compatibility returns **0.5**, producing **0.11475** RGB
error when evaluated against a synthetic steep black/white RGBF LUT transition.
At an explicitly declared classification threshold **0.50025**, three values
change sides in Compatibility. Forward+ has one boundary flip from float32
rounding of the value exactly on the threshold; maximum steep-LUT error is
**0.000005959**. These are calculated LUT/classification effects from measured
returned attributes, not rendered category images or corruption of source IDs.
Strict source/category decisions must not be reconstructed from approximate GPU
display coordinates. No global color tolerance is relaxed to conceal this.

Compared with accepted appearance, maximum scene RGB change reaches
**0.490197 Compatibility / 0.215687 Forward+**. Source sRGB decoding visibly dims
many Forward+ colors; white/primary peaks are not a sufficient acceptance test.
The additional contrast failures and altered apparent widths require explicit
visual review. Dense saturation and performance cost are still unknown.

## Reproduction and retained evidence

External workspace:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-369-particle-candidate/`.

```sh
cd /home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-369-particle-candidate
sha256sum -c SHA256SUMS
python3 reproduce.py owner-review
cat owner-review/candidate.log owner-review/historical.log owner-review/overlap.log
```

Use a fresh output name and native GPU/display access. Collection exit 0 means
completion, **not scientific acceptance**. Review `candidate.gdshader`,
`CANDIDATE_GATES.json`, `candidate-results.json`, `assessment.json`,
`accepted-replay-verification.json`, native logs, `precision-*.json`, and
`overlap-control/assessment.json`. `review-matrix.png` presents accepted/candidate
images at identical scale; `review-overlap.png` is a labeled 4× nearest-neighbor
crop. Neither changes brightness. Full-resolution originals are retained.

A fresh complete replay exactly repeats the native/assessment/target/overlap
result JSON and **2,426 PNGs**, including the review sheets. Its build-96 metadata
diff does not change any recorded production rendering source hash.

The initial headless precision probe used a dummy renderer and returned zeros;
its `invalid-headless-*` files are excluded from conclusions. Native reruns use
the actual GPU and exit 0. Historical reports, captures, gates and evidence are
unchanged. All experiment code/data/images, engine source excerpts and dependency
inventories remain external; no third-party payload enters Git or a package.

## Stopped scope and requested direction

The material-only feasibility gate failed before proceeding to the acceptance
benchmark. **NOT RUN for this candidate:** original REBOUND/PySPH vs VTK replay,
1080p/4K, ~100k-particle saturation/spatial coverage/GPU-time/RSS/playback,
ordinary interactive viewport, standalone Linux, raw video/MP4, cancellation and
worker lifecycle, full Cinematic look/Bloom, non-unit gamma/brightness mappings,
other GPUs/OSes and physical display calibration. No performance or scientific
suite-wide acceptance claim follows from the small matrix. Candidate shader
overrides are not serialized into generated video jobs; those jobs must not be
used to claim candidate raw-video parity.

Choose a direction before further implementation:

1. **Recommended: authorize a separately scoped Wavez linear accumulation and
   composition feasibility design.** Specify opaque depth/other-layer integration,
   HDR storage, clipping, trails, exports and memory/GPU budgets first. It may
   avoid an engine fork, but feasibility/performance are not established here.
2. **Explicitly narrow the contract to renderer-specific presentation.** Consider
   common source color/coverage semantics with documented blending differences,
   or a Forward+-only linear scientific presentation mode. This changes #369's
   goal and still needs the deferred benchmark; it is not silently selected.
3. **Defer the correction and retain accepted rendering.** Preserve the known
   discrepancies while separately evaluating engine capabilities. This is the
   current product state, not completion of #369.

Only this report and the required **v0.1.0.96** candidate build increment enter
the PR. Rendering sources and current behavior guides remain unchanged. Review
the failed gates and side-by-side images, then choose or amend the implementation
scope. The PR is a draft decision record, not a merge-ready correction.

Both Python version-contract tests pass. The required isolated editor import
exits 0 with no errors and four known missing resize-script UID warnings. Generated
sidecars for those unchanged baseline scripts are retained externally, outside
this issue's two-file diff. Unrelated regression suites were not run.
