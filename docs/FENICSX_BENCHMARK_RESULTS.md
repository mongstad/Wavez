# FEniCSx elasticity benchmark: scientific, WVZ1 and presentation results

Issue [#349](https://github.com/mongstad/Wavez/issues/349), executed 2026-10-11.
Numerical accuracy, WVZ1 transport and geometry checks **PASS** for this
manufactured small-strain problem. **Compatibility low-value contrast retention
FAILS** in two tested views, despite passing aggregate pixel-error thresholds.
This is a bounded benchmark, not general scientific certification or owner acceptance. Only this original factual report
is added to Wavez; all implementation, dependencies and evidence remain outside Git.

## Provenance and reproduction

External root: `/home/Nozba/Codex/Wavez/Wavez-Benchmarks/04_FEniCSx/`.
Its `README.md` provides exact setup, model, tolerances, commands and evidence paths.
Tested Wavez: `d808593e9a3def3d9e5760ad1ed1d731eddad0a2`, **v0.1.0.94**;
Godot **4.7.2.stable.official.ed1daf0bf**, native Forward+ and Compatibility.
Linux x86_64, Ryzen 7 5800X, RTX 3070 Ti, NVIDIA 615.71.09; full host details in
`machine.json`. No application source, build, licensing or packaging changes.

The isolated conda-forge environment pins Python 3.12.15, DOLFINx/Basix/FFCx
0.11.0, UFL 2026.1.0, PETSc/petsc4py 3.25.6, MPICH 5.0.1, MUMPS 5.8.2,
NumPy 2.5.4, SciPy 1.18.1, PyVista 0.49.0, VTK 9.7.0 and Pillow 12.3.0.
`conda-lock.txt` pins all **279** resolved package archives/builds;
`PACKAGE_SHA256SUMS` verifies their SHA-256 hashes. Micromamba 2.9.0 and its
original archive are external. `TOLERANCES.json` was hashed before solving and
remained unchanged. There are **205** verified stable evidence files in
`SHA256SUMS`; environments, caches and runtime profiles are excluded.

From the external root, with local MPI socket and native display/GPU access:

```sh
./reproduce.sh fresh-run
python3 run_native.py forward_plus fresh-run/analysis fresh-run/forward_plus-r3
python3 run_native.py gl_compatibility fresh-run/analysis fresh-run/gl_compatibility-r3
./run.sh reference.py fresh-run
./run.sh compare.py fresh-run
./run.sh /home/Nozba/Codex/Wavez/Wavez/tools/verify_wvz.py fresh-run/analysis/elasticity.wvz
```

Use a fresh output directory. The installed environment was tested; the separate
lock-based environment reconstruction command is documented but **NOT RUN**.
All 24 source arrays across the three refinement cases reproduced exactly in
`reproduction-check`. Fresh capture UUIDs differ, so reproduction compares
scientific arrays rather than requiring identical whole-capture hashes.

## Original model and independent scientific checks

Reference corner (-0.3,0.2,-0.1) m; lengths (1.2,0.8,0.5) m. For local coordinates
(X,Y,Z) in metres, the original unit-load displacement in metres is
`(0.015 X² + 0.0075 YZ, -0.015 Y² + X²/120, 0.020 X² + 0.018 Z²)`;
coefficients have reciprocal-metre units. No upstream example or dataset was copied.

Solve `-div(sigma)=f`, `epsilon=sym(grad(u))`,
`sigma=2 mu epsilon + lambda trace(epsilon) I`, with E=1000 Pa, Poisson ratio=0.25,
mu=lambda=400 Pa and hand-differentiated force `(-36,88/3,-59.2)` N/m³.
**All six exterior faces have the exact prescribed displacement**; this is not
a free cantilever or an experimental material validation. Continuous vector P1
finite elements on tetrahedra use serial PETSc/MUMPS direct LU. FEniCS error
integrals use degree-six quadrature. Independent NumPy tetrahedral shape gradients,
Duffy/Gauss integration, stresses and nodal force assembly check errors and equilibrium.

| Rectangular grid / tetrahedra | Displacement L2, m^(5/2) | Strain L2, m^(3/2) | Relative linear residual |
|---|---:|---:|---:|
| 4×3×2 / 144 | 4.1407057906e-4 | 3.5665985196e-3 | 2.3875e-16 |
| 8×6×4 / 1,152 | 1.0351764477e-4 | 1.7832992598e-3 | 6.4506e-16 |
| 16×12×8 / 9,216 | 2.5879411191e-5 | 8.9164962990e-4 | 1.0997e-15 |

**PASS:** displacement refinement ratios 4.0 (declared 3–5), strain ratios 2.0
(1.7–2.4). Finest volume-normalized displacement RMS is **3.7353712544e-5 m**
(limit 1e-4 m). Independent integrals agree within 1e-8 relative; maximum independently
assembled interior force residual is **7.750744491e-15 N** (limit 1e-10 N).
Boundary error is within 1e-12 m; total tetrahedral volume is 0.48 m³ within
1e-12 m³. Independently computed cell energy agrees with FEniCS DG0 association
within **3.552713679e-15 J/m³** (check limit 1e-10).

Nine native times are `t=k/8` seconds, k=0..8, load fraction `t²`. Each state
scales the unit-load solution/force linearly and energy quadratically, using
linearity of elasticity; these are not nine separate linear solves. There is
no inertia or transient integrator. Maximum displacement is **0.041703570324 m**,
displayed without exaggeration. Small-strain linear elasticity and the fully
prescribed manufactured boundaries limit the scientific conclusions.

## Full source versus WVZ1 exterior

The main source retains **315 vertices / 1,152 tetrahedra**. An independent
multiplicity/orientation extraction exports only **210 exterior vertices /
416 triangles**. Each boundary face is oriented outward against its parent
cell; closed edge multiplicities and six boundary tags are checked.
Wavez displays this exterior, not the tetrahedral interior or a volumetric FE field.

Stable int64 IDs are `37 * source_vertex_index + 100003`. WVZ1 retains float64
positions, displacement vectors, displacement magnitudes and load fractions;
face channels retain original parent-cell energy density, source tetrahedron ID
and unsigned boundary tag. Units are m, J/m³, dimensionless load and seconds;
identity affine, CCW source winding and uint32 triangle indices are explicit.
Boundary energy is a parent-cell value, not an exact continuum surface stress.

**PASS:** all nine samples preserve every exported array, dtype and timestamp
exactly in Python. Identity history passes. Strict verification passes all nine
records in the ordinary capture and in each of two format-valid negative captures.
One reversed face is independently detected as inward. Swapped vertex IDs cause
an independently detected **1.4233221893 m** physical-association error. Both
changes disable native stable-mesh interpolation. Format validity alone does
not imply scientific correctness.

## Native and independent visualization

| Executed validation | Result |
|---|---|
| Numerical, topology and Python transport analysis | **37 checks PASS**, repeated successfully |
| Additional winding and ID/position sensitivity checks | **2 checks PASS** |
| Native Forward+ | **33,375 checks PASS**, clean exit/log |
| Native Compatibility | **33,375 checks PASS**, clean exit/log |
| Independent VTK geometry, winding and world-space probes | **102 checks PASS** |
| Matched projections, silhouette and aggregate scalar RGB | **48 checks PASS** |
| Supplemental Compatibility low-value contrast diagnostic | **2 views FAIL**; nonzero energy appears uniformly black |
| Source-array reproduction / stable evidence / package archives | **24 / 205 / 279 exact checks PASS** |

Final native evidence is in `run-01/{forward_plus-r3,gl_compatibility-r3}/`;
reference evidence is in `run-01/pyvista-white/`. The harness uses production
`main.gd` in an 800×600 native SubViewport with `offline_instance=true` and hidden
UI/guides. It checks all nine exact times and eight midpoints, both synchronous
and asynchronous preparation, both scalar associations, actual GPU/baked morph
positions, original source hashes, winding, clocks, paused opening and playback/pause.
Maximum GPU geometry error is **1.341104508e-7 m** (limit 2e-6 m). Maximum color
array error is one 8-bit code value (limit 0.0041). Native generic uint32 channels
use exact float64 representation; source hashes are checked after exact uint32
re-encoding, not by confusing that storage with the original byte layout.

PyVista/VTK independently extracts the exterior from the **same full source
tetrahedra**, verifies its topology/parent cells and outward orientation, and
checks 416 triangle-centroid world-space picks and scalar probes at each of
17 requested times. Source geometry and scalar checks use 1e-12 m / scalar-unit
limits. Point values use triangle barycentric interpolation; face energy remains
constant per original parent cell. These probes are independent reference checks,
not certification of Wavez's experimental Selection/Analysis UI.

Both visualizers use geometry interpolated between recorded states with earlier
sample scalars held. At t=0.5625, displayed geometry load is 0.3203125, scalar load
0.25, and unsaved analytic load 0.31640625. Consequently, the intended piecewise
geometry differs from the unsaved analytic state by up to **0.000162904572 m**;
held versus interpolated displacement magnitude differs by **0.002932282288 m**.
Neither difference is a transport error or a new physical solve.

Matched frames use t=0, 0.5, 0.5625, 1; vertex magnitude range 0–0.05 m and face
energy range 0–4 J/m³; gray 256-entry LUT quantized before interpolation. Camera
position (2.2,1.8,2.6), target (0.3,0.6,0.15), up +Y, orthographic height 1.9 m,
near/far 0.01/10 m; white background, opaque unshaded surface, back-face culling,
no transforms, smoothing or deformation scaling. White exposes zero-valued faces.

Maximum projected-vertex difference is **9.507030016e-5 pixel** (limit 0.001).
All silhouettes have **IoU 1.0** (minimum 0.98). RGB comparisons exclude two
pixels at the silhouette border. Forward+ maximum mean / p99 error is
**0.002538436 / 0.007843137**; Compatibility **0.015556660 / 0.031372549**,
within limits **0.025 / 0.06** on normalized RGB. These are measurable presentation
differences, not pixel identity. A 500-ray diagnostic favors linear-light color
interpolation for Forward+ and sRGB-value interpolation for VTK, but does not
fully explain all residuals, especially dark Compatibility views. Color processing
and quantization differ; do not recover precise scientific values from brightness.
Geometry, source values and world-space probes provide the primary evidence.

**FAIL — visible low-value contrast:** image inspection showed that Compatibility
renders all **112,158 / 112,094** measured interior face-energy pixels black at
t=0.5 / 0.5625, while VTK retains grayscale levels **1–6/255**. Its corresponding
vertex views also lose approximately **7.963%** of nonzero reference pixels.
Forward+ loses none in these comparisons. A focused native inspection confirms
nonzero energy **0.000603564453125–0.0952430175781251 J/m³** and nonzero GPU
color attributes through 5/255. Thus correct source values do not prevent loss
of displayed variation. The exact backend cause remains unisolated; no fix is
included. `contrast-diagnostic.json` and `contrast-native.log` retain the evidence.
This supplemental diagnostic was added after visual inspection, without changing
predeclared thresholds. Passing global RGB averages is **insufficient** for
scientific displayed-value assurance in these dark Compatibility views.

## Failures, limitations and licensing boundary

Retained failures: initial MPI startup was blocked by sandbox socket permissions;
the native-access retry passed. The first native harness made 77 incorrect byte-layout
assertions for uint32-as-float64 data; corrected checks preserve values and thresholds.
An integer-versus-JSON-float selection mismatch initially produced no native images;
comparison refused missing files. Final R3 asserts all eight screenshot saves.
Earlier attempts and logs remain external. DOLFINx emits a nonfatal deprecated
`dofmap` accessor warning. No application fix or tolerance relaxation was made.

Nine original Python modules compile; isolated dependency checking passes. Local
setup/solve timings were 0.6573 / 0.0130 / 0.0939 s for coarse/main/fine; the first
includes cold JIT overhead and these are not comparative performance guarantees.
The capture is 282,932 bytes. No unrelated application suite was run: the Git change
is report-only, while the executed checks cover this benchmark's actual contracts.

**NOT RUN:** nonlinear/finite-strain/plasticity, mixed traction boundaries,
dynamic elasticity, experimental materials, interior FE visualization in Wavez,
GUI mesh scalar probing, Selection/Analysis, other camera/affine/colormap cases,
translucent occlusion, packaged builds, other OSes/GPUs, long sessions, MP4 and
whole-process viewer RSS/VRAM. No suite-wide cross-visualizer assurance is claimed;
#346/#347 require separate fresh independent visualization checks.

The external `LICENSE_INVENTORY.md` and `dependency-inventory.json` record all
279 package versions/licenses and 339 available packaged notice files. Nineteen
package records lack separate notice files; this is not absence of obligations.
[DOLFINx/FFCx/UFL](https://github.com/FEniCS/dolfinx) declare LGPL terms;
[Basix](https://github.com/FEniCS/basix) and
[PyVista](https://github.com/pyvista/pyvista/blob/v0.49.0/LICENSE) are MIT;
[VTK](https://vtk.org/about/) is BSD-3-Clause. The environment also contains
[ParMETIS](https://github.com/KarypisLab/ParMETIS/blob/main/LICENSE) with its own
noncommercial terms, Qt/compiler/runtime components and other separately licensed
dependencies. Local test use is not redistribution clearance; physical separation
alone is not a legal conclusion. No transitive redistribution audit is claimed.

**Report-only acceptance gate: PASS.** No third-party benchmark code, data,
binaries, license excerpts, images or other payloads enter Wavez Git or packaging.
This original report describes methods and measurements in original prose.
Wavez's PolyForm Noncommercial license, third-party notices, trademarks, build and
historical reports remain unchanged; no endorsement is implied.

Key SHA-256 provenance (full manifest external):

| Artifact | SHA-256 |
|---|---|
| `TOLERANCES.json` | `6fed401a1aa81a5f6a70d4e960057f29dbc01c1ef01c796c89914369f1e6c576` |
| `solve.py` | `a692807fd10b0035854235de5ede2482bfcb74637460fd0f8a6aa326fff55131` |
| `native_check.gd` | `c921040d6804b297b0dd997e3704e955e10a073b581fcdf7148e3dac99dd2144` |
| `run-01/main/source.npz` | `7cbea9b34b21b5273eea89ac345f7429f39ad0ea401ecb8ebe1589d05714ca56` |
| `run-01/analysis/elasticity.wvz` | `77c6b70f9d81378bd85f65af24cca4aa08710719f0eed53eee3ea4ee2381a1c9` |

## Owner verification before acceptance

1. Confirm the PR diff contains only this report. Read the external inventory,
   retained failures and NOT RUN boundaries; verify both SHA-256 manifests.
2. Run the fresh-output commands above to repeat numerical and presentation checks.
3. Open `run-01/analysis/elasticity.wvz` in Wavez. Confirm paused opening and a
   single deforming exterior; play, pause and seek. Inspect displacement magnitude
   (0–0.05 m) and face strain-energy density (0–4 J/m³), gray palette.
4. Compare the eight final native/reference PNG pairs, `comparison-results.json`
   and `contrast-diagnostic.json`. At t=0.5 / 0.5625, confirm the reported
   Compatibility face-energy contrast loss; decide whether to accept the factual
   benchmark report with this unresolved presentation finding.
   At t=0.5625 expect interpolated geometry with earlier scalar values; do not
   interpret the shell as full volumetric topology or color as an exact probe.

Owner review remains pending. No merge, issue closure or Project completion is performed.
