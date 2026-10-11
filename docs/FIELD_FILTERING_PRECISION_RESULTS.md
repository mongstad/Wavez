# Forward+ field filtering: precision, presentation and cost

Issue [#360](https://github.com/mongstad/Wavez/issues/360), executed 2026-10-11.
**Hardware filtering fails the retained 0.0002 scalar limit on tested off-grid
points. Explicit eight-fetch interpolation passes finite-value checks and
removes a measured narrow-range slice error, but increases volume GPU cost and
changes nonfinite behavior. A production replacement is not implemented.**

All product evaluation uses **Forward+ Vulkan**, the sole supported renderer
since owner-merged [#371 / PR #372](https://github.com/mongstad/Wavez/pull/372).
One isolated Compatibility control gave identical scalar results and was then
discontinued. No Compatibility support, product code, version, source/probe
semantics or package is changed. Historical #354/#356 evidence stays unchanged.

## Environment and reproducibility

Accepted Wavez **b15e59aafd40b4af0de55278d3df579b7ecba54e**, **v0.1.0.97**;
Godot **4.7.2.stable.official.ed1daf0bf**, full revision
`ed1daf0bf001b61586d9930840f2f1394092c079`. Linux **7.2.9-200.fc44** x86_64,
glibc **2.43**, Ryzen 7 5800X, RTX 3070 Ti **8 GiB**, NVIDIA **615.71.09**,
device Vulkan **1.4.351**. Native GPU execution; headless results are not substituted.
Python **3.14.8**, NumPy **2.5.4**, Pillow **12.3.0**; external figures use the
existing FiPy environment's Matplotlib **3.11.2**. No new dependency is installed.

All diagnostic scripts, fixtures, captures, images and raw measurements remain
outside application Git in:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-360-filtering/`.
Its README, licensing/dependency inventories, machine report and hash manifest
give exact methods and provenance. From that directory, with native GPU access:

```sh
sha256sum -c SHA256SUMS --quiet
python3 reproduce.py owner-review
python3 reproduce_stress.py owner-stress
./run.sh verify_inputs.py
```

All **2,120** stable external hashes verify. Predeclared tolerances SHA-256:
`e3de9f29c3d8102dd239e96afd1b71aa2c924903f705a4a97f62ae3130cc4939`.

Use a new output directory. Full fresh regeneration/execution was verified in
`reproduction-check`: eight step exits **0,0,0,0,0,0,0,1**. The final exit 1 is
the immutable #354 Wavez upload/probe harness: **695 checks, 13 filtering failures**.
Collection completion is not an all-PASS scientific result. All seven new WVZ1
captures pass strict verification; 25 independent source/probe checks pass.
Two verified native production runs and fresh reproduction each pass **364**
source/shape/allocation/collection checks, while retaining the image/cost failures
below. All **356 PNGs** reproduce byte for byte, including the fresh regeneration.

## Scalar accuracy and mechanism

Predeclared scalar tolerance remains **0.0002**. An independent float64 CPU
eight-corner oracle uses the exact float32 normalized coordinates and RF values;
original-source interpolation is retained separately. RGB24 encoding over
[-8,8] has step **16/16777215**, with calibration limit **2e-6**. Calibration and
intentional [0,1] clamp negative controls pass. Actual queried textures are
**R32_SFLOAT, one mip level** in all 47 final isolated cases (89,709 points).

| Off-grid fixture | Hardware max / p95 / p99 error | Hardware failures | Explicit max error |
|---|---|---:|---:|
| Original #354 probes | 0.00126597 / 0.000919703 / 0.00119672 | **13/16 FAIL** | **1.111e-6 PASS** |
| Signed irregular 7×5×3 grid, seed 360 | 0.0282667 / 0.0144257 / 0.0198254 | **1997/2048 FAIL** | **1.812e-6 PASS** |
| Smooth 64×48×32 grid | 0.000733278 / 0.000426336 / 0.000576163 | **1032/4096 FAIL** | **1.213e-6 PASS** |

The irregular fixture exercises negative, normalized and above-one off-grid
values; explicit interpolation passes all three categories. Centers, clamped
boundaries and negative/positive/above-one constants pass with both samplers.
The larger irregular error belongs to a deliberately steep random field, not
a measured error in every production field. The old 16-bit encoded #354 result
remains valid as written; the finer encoder resolves its quantization uncertainty.

**Measured mechanism:** fine ramps show 256 steps per texel axis, consistent
with this device's `subTexelPrecisionBits=8`. Vulkan documents these divisions as
the locations to which subtexel sampling snaps; this is not a float32 scientific
accuracy guarantee. See [Vulkan device limits](https://docs.vulkan.org/refpages/latest/refpages/source/VkPhysicalDeviceLimits.html).
Implicit filtering, explicit LOD0 and `highp` hardware passes are byte-identical.
The discrepancy survives bypassing Wavez, and uniform encoding is accurate:
neither original-array corruption nor the retired Compatibility raw-readback
clipping explains it.

Only rounding coordinate fractions to eight bits still **FAILS** the predeclared
5e-6 model-residual gate. Separate binary parity-basis textures reveal quantized
corner coefficients: four XY weights sum to one on a 1/256 grid, and full 3D
weights on a 1/65536 grid. The XY weights are not exactly the product of two
independently rounded fractions. Using these independently measured coefficients
reconstructs the three separate scalar arrays with max residual **1.248e-6**,
**PASS**. This identifies the tested filter's coarse effective coefficients;
the precise proprietary GPU/driver rounding algorithm and API conformance are
**NOT VERIFIED**. The empirical reconstruction is not a universal predictor.

[#356's mesh finding](COMPATIBILITY_MESH_CONTRAST_RESULTS.md) traced a different
color-transfer path. Here signed scalar errors are observable before any spatial
colormap/gamma processing and are absent with explicit fetches through the same
observable framebuffer. There is no evidence of a shared cause or reason to
apply a brightness/gamma adjustment to scalar data.

## Scientific presentation

External copies replace only scalar sampling in the real Wavez slice/volume
shaders; GridView upload, camera, RF texture, gray LUT, ranges, transforms,
opacity and ray rules are shared. The float64 linear field is
`v=0.25+0.3*x+0.1*y+0.12*z`, physical node box 1.5×1×0.8 m, 17×13×9 samples.
The 256×192 orthographic camera has height 2 m; slice offset is 0.037 m.
Independent CPU images model the LUT in linear space; volume center-ray checks
integrate extinction/color at the same midpoint steps. Thresholds were saved
before rendering: wide slice/volume RGB **0.012/0.02**, narrow RGB **0.02**.

| Slice color range [0.254,0.256] | Hardware max RGB error | Explicit max RGB error | Max hardware/explicit byte difference |
|---|---:|---:|---:|
| Node centered | **0.06309 FAIL** | **0.000396 PASS** | 16/255 |
| Cell centered | **0.06309 FAIL** | **0.000396 PASS** | 16/255 |
| Rotated/scaled/translated | **0.05237 FAIL** | **0.001390 PASS** | 13/255 |
| Budget-reduced preview, LOD2 | **0.09770 FAIL** | **0.000396 PASS** | 25/255 |

The independently defined node transition band contains 61 pixels; 50 differ by
more than two bytes, p99 difference 16 bytes. Whole-interior p99 is zero because
most pixels intentionally saturate, demonstrating why aggregate metrics alone
miss this local discrepancy. The center pixel differs by six gray levels.
The narrow range deliberately amplifies error; it does not certify general
production inaccuracy. Both samplers pass wide [-1,3] slice images and the tested
nonconstant volume **center-pixel** checks, including narrow color/opacity,
signed/positive/magnitude extinction. Positive log mapping and the nonpositive
source refusal pass. Total image-oracle assessment: **62 PASS / 4 FAIL**, all
four failures in hardware narrow slices; repeat results are identical.

## Practical cost and sampling boundaries

Verified workloads use 32³/64³/128³/256³ RF textures (**128 KiB–64 MiB**),
640×480 views, 64/256 nominal volume ray steps, and 64³ held-sample replay at
128 steps. Each has three alternating-order repetitions, 24 warmup frames and
40 measured frames per sampler. Godot viewport GPU timestamps are separated
from rendering CPU, setup CPU, upload and wall time; [API measurement scope](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu).

| Representative workload | Hardware GPU ms | Explicit GPU ms | Ratio |
|---|---:|---:|---:|
| 32³ volume, 256 steps | 0.414 | 0.785 | 1.90× |
| 128³ volume, 256 steps | 0.455 | 0.808 | 1.78× |
| 256³ volume, 64 steps | 0.179 | 0.256 | 1.43× |
| 256³ volume, 256 steps | 0.562 | 0.902 | 1.60× |
| 64³ held-sample replay, 128 steps | 0.240 | 0.418 | 1.74× |
| 256³ slice | 0.034 | 0.037 | 1.09× |

These are `production-verified-02` medians. Verified repeats show volume ratios
**1.43–1.98×**, all above the predeclared +10% cost gate: **FAIL** for an automatic
default replacement. Slice cost is **0.003–0.004 ms**, about 9–12%, near timer/
variation scale and mixed against that gate. Rendering CPU is about 0.029–0.031
ms for static scenes; replay's actual upload medians are about 0.54/0.55 ms,
held no-op 0.005 ms. A 256³ workload uses 64 MiB field storage and about 78.7 MiB
renderer texture allocation with either sampler.

Supplemental workloads use 256³/384³ fields (**64/216 MiB**), 1920×1080 and
3840×2160 SubViewports, slices and 512/1024 nominal volume steps. The reader's
256 MiB sample ceiling excludes a 512³ RF capture; admission was not bypassed.
Each of 12 groups has three paired repetitions and 40 measured frames after
24 warmups. Corrected collection checks every draw and reads its center pixel;
only whole groups passing nonblack/stability/sampler-match controls contribute
cost conclusions. GPU pass time excludes this synchronous readback; readback
CPU/wait wall time is recorded separately. These are synchronized
component measurements, not viewer FPS. Full-viewer FPS, GPU contention and
multi-volume admission stress are not certified; clocks were not locked.

| Repeated control-passing supplemental workload | Hardware GPU ms | Explicit GPU ms | Ratio |
|---|---:|---:|---:|
| 256³, 1080p volume, 1024 steps | 7.629 | 16.989 | 2.23× |
| 384³, 1080p volume, 1024 steps | 8.282 | 17.137 | 2.07× |
| 256³, 4K volume, 1024 steps | 23.096 | 51.019 | 2.21× |
| 384³, 4K slice | 0.431 | 0.505 | 1.17× |

These medians are from `stress-reproduction-guarded/native`; both corrected
runs complete **11** source/shape/allocation checks with zero failures and
measure **2,880** GPU frames each. Fresh source hashes reproduce exactly;
both supplemental captures pass strict WVZ1 validation. **9/12** whole workload
groups pass rendered-presence controls in both runs. Their five volume groups
cost **1.84–2.26×** across repeats, all **FAIL** the +10% decision gate. Slices
add about **0.012–0.074 ms** in the fresh run; ratios vary across repetitions.
Field storage peaks at 216 MiB, renderer textures about **414.5 MiB** and Godot
static allocation about **270.3 MiB** (not whole-process RSS).

The other three 4K volume groups fail presence controls in at least one run:
17/11 black center pixels among each run's 2,880 measured frames. Their costs
are **NOT VERIFIED**, even where an aggregate median looks plausible. Both
native runs exit 0, but both presence assessments exit **1**. The fresh stress
reproduction step exits are **0,0,0,0,1**, not an all-PASS result. The 4K figures
above certify component measurements only; physical 4K UI/DPI is untested.

**PASS for tested coordinate/source contracts:** finite node/cell grids, unequal axis dimensions and anisotropic
spacing; rotation 0.35 rad, scale (1.2,0.8,1.1), translation (0.3,-0.2,0.1) m;
LOD2 endpoint-preserving preview; original WVZ1 arrays/probes and sample holding.
Replay uses native bracket selection and synchronous GridView uploads, not the
full asynchronous playback controller. GPU mipmaps are absent; preview LOD is
CPU decimation. True mipmapped/anisotropic filtering is **NOT VERIFIED**.

**FAIL for a naïve drop-in sampler:** in 63-point NaN/Inf footprint controls,
hardware retains 58 finite outputs, while unconditional eight-fetch/mix retains
39. Zero-weight nonfinite neighbors can contaminate explicit arithmetic.
These are classified footprints, not a finite numeric oracle or a fix. Source
probes retain their existing conservative missing/nonfinite semantics. Missing
channel refusal was inspected but not separately executed.

## Recommendation, attempts and review boundary

Explicit interpolation is a justified **accuracy candidate for scientific slices**,
especially narrow ranges. Propose a separate owner-reviewed slice-sampling fix
that preserves coordinate/clamp/LOD rules and explicitly tests zero-weight
nonfinite support, source-probe semantics and standalone Vulkan. Do not replace
volume sampling by default from this evidence; assess an owner-defined accuracy
versus workload cost requirement before a separate volume change. No UI mode,
renderer redesign, engine fork, scientific normalization or shader fix is added.

Retained invalid attempts: the initial external production harness reused a
GridView sample key across files, invalidating some transform/grid-size results.
Verified runs explicitly clear and check shape, original-source hashes and GPU
allocation. Initial nonfinite CPU zero-weight propagation and its warning are
retained separately. Thresholds were not relaxed; invalid initial runs are excluded
from reported conclusions. Full fresh reproduction confirms the corrected method.
Initial supplemental stress runs show bimodal static-volume timings;
unguarded summaries are excluded. Per-frame draw/pixel/completion controls
also detect intermittent black volume-center pixels at 4K despite a visible
draw. Affected groups are **NOT VERIFIED** for cost; no individual frames are
trimmed. This external-harness limitation is retained separately from scalar
accuracy failures. Its cause and occurrence in the full viewer are unverified;
it is not attributed to interpolation or fixed by this report.

**NOT VERIFIED:** other GPUs/drivers/OSes, packages, physical display/input,
physical 4K UI/DPI or long sessions, opaque-depth/transparent mixtures, arbitrary LUTs, extreme/
subnormal values, shear/large coordinates, exact driver internals or all production
scientific workloads. No solver rerun or unrelated application suite was needed
for this report-only change. PolyForm Noncommercial and third-party boundaries
are unchanged; tools/notices/assets remain external, with no redistribution claim.

Owner checks: verify the one-report diff and external manifest; run the fresh
commands; inspect `owner-review/sampling/assessment.json`, its `mechanism.json`,
`owner-review/production/assessment.json` and `owner-stress/native/assessment.json`
separately from collection exits; inspect `stress-summary.json` for whole-group
exclusions. Compare external
`narrow-slice-comparison.png`, scalar error and GPU-time figures with the raw
PNG/JSON values. Review narrow-range accuracy, nonfinite limitations and volume
cost before authorizing product work. Owner acceptance remains pending.
