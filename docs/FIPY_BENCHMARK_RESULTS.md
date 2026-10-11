# FiPy field transport / WVZ1 results — issue #348

Executed **2026-10-11** against accepted Wavez commit
`ecef99a34c1462e402ae61a9328da2ed1719fcb2`, application **v0.1.0.94**.
The declared numerical, transport, probe, geometry and matched-slice checks passed.
Translucent volume brightness differs between renderers; the measured difference
and its scientific significance are reported below. Owner acceptance is pending.

The fresh external workspace is
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/03_FiPy/`. All scripts, environments,
source arrays, captures, reference-visualizer inputs, screenshots and detailed
logs remain there. This original factual report is the **sole Git deliverable**.
The issue's report-only requirement takes precedence over the usual implementation
build increment. Application code, version, packaging, license files, current
guides and earlier benchmark reports are unchanged.

## Model and independent numerical reference

[FiPy](https://www.nist.gov/programs-projects/fipy) solves diffusive scalar transport
`∂c/∂t = D∇²c`, with `D=0.01 m²/s`, no advection, reaction or source, and zero
normal flux on every exterior face. The box starts at `(-0.4,0.2,-0.1) m`, with
lengths `(1.6,0.96,0.48) m`. Concentration is in `mol/m³`.

The original analytic solution is a mean of 2 plus two cosine modes, with mode
indices/amplitudes `(1,2,1)/0.4` and `(2,1,0)/0.2`. For local box coordinates,
`kᵢ=πnᵢ/Lᵢ`; each mode is `A exp(-D|k|²t) ∏cos(kᵢxᵢ)`.
Exact **cell averages** include the factor `∏sin(kᵢhᵢ/2)/(kᵢhᵢ/2)`, with the
zero-argument limit 1. Initialization and analytic error both use those averages.
This is an independent mathematical reference, not a fitted or second FiPy solve.

The method is uniform-grid finite volume with backward Euler, FiPy TransientTerm
and DiffusionTerm, and SciPy LinearLUSolver (tolerance `1e-12`, iterations 10).
Execution is serial CPU with BLAS/OMP threads fixed to one.

| Case | Grid xyz / cell spacing xyz | Timestep / steps | Recorded states |
| --- | --- | --- | --- |
| Main | 16×12×8 / (0.1,0.08,0.06) m | 0.01 s / 100 | 21 |
| Half timestep | Same grid | 0.005 s / 200 | 21 |
| Fine | 32×24×16 / (0.05,0.04,0.03) m | 0.0025 s / 400 | 21 |

All runs cover approximately one second. Repeated floating-point timestep
addition supplies native times; export preserves these values without rounding.
The independent discrete eigenvalue is
`λh = D Σ4sin²(kᵢhᵢ/2)/hᵢ²`. Comparing with `(1+Δt λh)^(-n)` checks the discrete
solver; comparing with `exp(-λh t)` separates temporal error from spatial error.

| Numerical check | Observed | Predeclared limit | Result |
| --- | ---: | ---: | --- |
| Main maximum analytic error, all steps | 0.003353896 mol/m³ | 0.006 | **PASS** |
| Fine maximum analytic error, all steps | 0.000889003 mol/m³ | 0.002 | **PASS** |
| Main/fine final RMS error ratio | 3.929177 | 3–5 | **PASS** |
| Timestep-halving error ratio vs semi-discrete solution | 1.996272 | 1.9–2.1 | **PASS** |
| Discrete eigenmode maximum error, worst run | 3.864e-14 mol/m³ | 1e-9 | **PASS** |
| Relative mass error, worst run | 5.774e-15 | 1e-10 | **PASS** |
| Minimum/maximum principle, every step | No violation | 1e-10 slack | **PASS** |
| Nonfinite source values | 0 | 0 | **PASS** |

Initial total amount is `1.47456 mol`. Final RMS analytic errors are
`0.001117665` (main) and `0.000284453 mol/m³` (fine). These two resolutions support
the measured refinement behavior for this smooth problem, not universal
asymptotic convergence. `TOLERANCES.json` was hashed before execution and remained
unchanged. The complete numerical/transport/reference analysis passed **28 checks**.
A run of the documented reproduction script reproduced **every saved array and
timestamp in all three cases exactly** and passed the same checks.

## Source fidelity, geometry and native playback

FiPy's x-fast values reshape directly to `(nz,ny,nx)=(8,12,16)`. The WVZ1 field is
cell-centered, with first-cell-center origin `(-0.35,0.24,-0.07) m`, xyz spacing
`(0.1,0.08,0.06) m` and identity transform. The exterior lower corner is distinct
from that sample origin. All 1,536 values per state remain float64.

| Boundary | Evidence | Result |
| --- | --- | --- |
| Python source → WVZ1 → readback | All 21 arrays/timestamps exact; dtype, zyx shape, xyz geometry, centering, units and binary source statistics checked | **PASS** |
| Strict verification | Main and three negative captures: 21 records each, checksums/commit proofs/statistics verified | **PASS** |
| Negative controls | x/y axis swap, 0.03 m x-origin offset, one +0.1 mol/m³ value corruption: all detected by transport and independent world probes | **PASS** |
| Native Forward+ | **10,560 checks**, zero failures, successful exit, clean log | **PASS** |
| Native Compatibility | **10,536 checks**, zero failures, successful exit, clean log | **PASS** |
| Wavez source probes vs VTK | Worst absolute difference `2.068e-7 mol/m³` | **PASS**, limit `2e-6` |
| World outer-bound error | `1.193e-7 m` maximum | **PASS**, limit `2e-6 m` |
| Float64 → float32 preview | `1.192e-7 mol/m³` maximum conversion error | **PASS**, limit `2e-7` |

Native readers check every timestamp and source-array hash. All 21 exact times
and three intermediate times check full-resolution field publication, source
statistics, probes and prepared float32 planes. The viewer opens paused;
transport advances within its rate bound and remains stationary while paused.
Intermediate fields hold the earlier source sample. The reproduced capture also
passed the native Forward+ wrapper's 10,560 checks.

The 24-check renderer difference concerns byte-exact GPU texture readback.
Forward+ returned exact float32 texture bytes for every inspected state.
Compatibility clipped RF texture readback to `[0,1]`, also reproduced by an
isolated 2×2×2 Godot upload that never loads Wavez. **Exact Compatibility GPU byte
readback is unsupported here**; its original float64 values, prepared float32
planes, numerical probes and displayed images passed their separate checks.
Source probes retain float64 values but use float32 world-coordinate transforms.

## Independent PyVista/VTK comparison

[PyVista](https://docs.pyvista.org/api/core/_autosummary/pyvista.imagedata) /
[VTK](https://vtk.org/about/) consumes the identical fresh solver arrays as a
cell-center sample lattice. There are **212 fixed world probes at each of 21
times**, including fractional positions and half-cell exterior bands. VTK agrees
with independent NumPy trilinear weights within `1.333e-15 mol/m³`.

The display policy is trilinear interpolation of cell-average samples, clamped
through exterior half-cells. It is a presentation estimate, not exact physical
reconstruction between finite-volume cells. The VTK reference uses repeated ghost
samples for that clamp; ghosts never enter FiPy or WVZ1. Its final volume display
uses an aligned 0.01 m lattice over the exact physical box, independently checked
at every point against the same trilinear field to `1.333e-15 mol/m³`.

Matched views use 800×600 pixels, orthographic vertical span 2 m, camera
`(0.4,0.68,3)`, target `(0.4,0.68,0.14)`, +Y up, identity geometry, black background
and no shading, fog, bloom, guides or occluders. A 256-entry grayscale ramp maps
`[1.4,2.6] mol/m³`; autorange is disabled. The z=0.125 m slice and volume use
source indices 0, 10 and 20. Volume extinction is `c` per meter, reference
opacity-unit-distance is 1 m, and requested ray step is 0.005 m.

| Matched presentation check | Observed across both renderers / three times | Limit | Result |
| --- | ---: | ---: | --- |
| World-point screen projections vs VTK | Maximum 0.0000481 px | 0.05 px | **PASS** |
| Slice and volume visible-support IoU | 1.000 | ≥0.98 | **PASS** |
| Slice RGB mean absolute difference | 0.00174–0.00199 | 0.05 | **PASS** |
| Slice RGB 99th-percentile difference | 0.003922 | 0.15 | **PASS** |

All **26 declared presentation checks** passed. RGB metrics use a two-pixel
interior margin within common visible support; thresholds were declared before
execution. Inspected screenshots support the measured alignment and slice pattern.
They do not replace the numerical probes and projection measurements.

**Translucent volume color is not equivalent across renderers.** Forward+ versus
VTK has RGB mean absolute differences `0.0910–0.1011`, while Compatibility versus
VTK has `0.000777–0.001138`. An independent ray-integration diagnostic fits
Forward+ with linear-light blending (maximum mean residual `0.001673`) and
Compatibility/VTK with blending in sRGB values (maximum mean residual `0.001338`).
This accounts for the brighter Forward+ volume despite matching scalar data and
geometry. Do not infer concentration from composite brightness or treat volume
screenshots as interchangeable. No volume RGB-equivalence PASS is claimed.

## Performance, reproduction and licensing gate

Pinned runtime: **FiPy 4.0.3, PyVista 0.49.0, VTK 9.7.1, NumPy 2.5.4,
SciPy 1.18.1, CPython 3.14.8**. Godot is
`4.7.2.stable.official.ed1daf0bf`, commit
`ed1daf0bf001b61586d9930840f2f1394092c079`. Host: Ryzen 7 5800X, RTX 3070 Ti,
NVIDIA 615.71.09, Linux `7.2.9-200.fc44` x86-64, glibc 2.43. Native Wavez uses
Vulkan Forward+ and OpenGL Compatibility; VTK's recorded GPU capabilities are
retained with its reference results.

Main / half-step / fine solver loops took **1.327 / 2.695 / 156.572 s**, including
step diagnostics. Process peak RSS was **102,100 / 102,396 / 228,576 KiB**, including
setup. The 273,201-byte WVZ1 took 0.0041 s to export. Native strict reads took
97.760 / 99.561 ms and viewer open calls 62.738 / 46.158 ms (Forward+ /
Compatibility). Open-call timing excludes full first-presentation latency.
These are local observations, not sustained-throughput or capacity guarantees.
Whole-process viewer RSS and GPU VRAM were **NOT RUN**.

External `README.md` gives the exact pinned setup and reproduction commands.
`requirements-lock.txt`, 36 retained dependency wheels, license/notice hashes,
`SHA256SUMS`, original NPZ arrays and detailed JSON results support review.

| External artifact | SHA-256 |
| --- | --- |
| Predeclared `TOLERANCES.json` | `5461279a52dea524e51cf56f0fa698f07a07c32ea6d716ad17c4b01e43127c6a` |
| Main `source.npz` | `1835bc67ed3a539febb51397beccc6f19eb06c1718dc641d220c39f94fa1afcd` |
| Main `diffusion.wvz` | `71f2597b7987b8861435ced222746337403d7ef60b7318a904ca03e81995887f` |
| `solve.py` | `6f79fb85b269c94bedda13b5f89b912a9635fbcb87c7d16fe8afebd66253e99c` |
| `native_check.gd` | `aa3d0ee9b6c077c393004be8c1219fb0f880968a1546ba1ca9d81e8d181eba2e` |

**Report-only licensing gate: PASS.** External `LICENSE_INVENTORY.md` and
`dependency-inventory.json` distinguish test-tool use from redistribution and
record exact dependency notices. FiPy carries NIST terms plus separately
attributed dimensional tooling; PyVista uses MIT, VTK BSD, and numerical wheels
retain their own bundled-component notices. The inventory identifies the binary
component audit boundary rather than assuming one license covers everything.
No third-party benchmark payload enters Wavez Git or its distributable; PolyForm
Noncommercial 1.0.0 and existing notices remain unchanged. No endorsement,
relicensing or future redistribution clearance is implied by physical separation.

## Retained failures, limitations and owner checks

Retained attempts include premature analysis before the fine solve completed;
an external native-harness parse error; decimal-JSON precision loss and checking
before pending publication; and a VTK volume reference that retained padded
support despite requested cropping (IoU **0.8778, FAIL**). The corrected harness
uses binary oracle values and waits for publication. The final VTK input covers
the exact physical box with independently verified sampling. Original attempts
remain external; no oracle threshold or application source was changed. Final
native logs are clean. Dependency, Python compilation and shell syntax checks pass.

**NOT RUN:** advective/nonlinear/reactive transport, nonuniform/AMR grids, other
PDEs, experimental data, alternative camera angles/colormaps/ranges, occlusion,
transformed objects, reduced-resolution admission, other OSes/GPUs, packaged app,
long sessions, MP4 or experimental Selection/Analysis. Earlier #346 and #347 have
no retroactive independent-visualizer validation; this report makes **no suite-wide
cross-visualizer assurance**. Unrelated application suites were not rerun.

Before acceptance, inspect the report-only diff and external licensing inventory;
run `sha256sum -c SHA256SUMS` in the external workspace; inspect the result JSONs,
final Wavez/VTK screenshots and retained failures. Open
`run-01/analysis/diffusion.wvz` to check paused opening, seeking, playback and
source probes. Reproduce with the external README's commands. Owner review and
merge remain the acceptance boundary.
