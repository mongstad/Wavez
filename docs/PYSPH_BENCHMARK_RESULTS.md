# PySPH dam-break / WVZ1 benchmark results — issue #347

Executed **2026-10-11** against accepted Wavez commit
`80f9568c2951e6e48461ff64e7f21095dd5245c6`, application **v0.1.0.94**.
The declared analytic-reference, invariant, sensitivity, fidelity and native-viewing
checks passed. This does **not** establish agreement with a physical dam-break
experiment or an independent nonlinear dam-break solver. Owner acceptance is pending.

The fresh external workspace is
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/02_PySPH/`.
All benchmark implementation, dependencies, generated extensions, source arrays,
captures and detailed evidence remain external. This original factual report is
the sole application Git deliverable. The issue's report-only requirement takes
precedence over the usual implementation build increment: app source, build,
packaging, licensing files, current guides and historical evidence are unchanged.

## Model and reference scope

The original geometry is a two-dimensional, unit-depth water column occupying
`[0,0.5] × [0,0.5] m` in an open-top `2 × 1 m` tank. No obstacle or imported
geometry/data is used. Cell-centred spacing `dx=0.0125 m` gives **1,600 fluid**
particles; three fixed half-cell-offset floor/sidewall layers add **978 wall**
particles. All **2,578 particles** are recorded. Initial velocities are zero.
Reference density is `1,000 kg/m³`, gravity `(0,−9.81,0) m/s²`, sound-speed
parameter `c₀=30 m/s`, smoothing length `h=1.3 dx`, and particle mass
`ρ₀ dx² kg/m` of out-of-plane depth. Fluid mass is approximately `250 kg/m`.
Initial fluid/wall density is `ρ₀[1+7g max(0.5−y,0)/c₀²]^(1/7)`, with Tait
pressure: an approximate hydrostatic initialization, not an equilibrium claim.

[PySPH WCSPH](https://pysph.readthedocs.io/en/main/reference/scheme.html)
uses a 2D cubic-spline kernel, PECIntegrator/WCSPHStep, continuity-density evolution,
Tait exponent 7, Monaghan artificial viscosity `α=0.1, β=0`, and
[XSPH](https://pysph.readthedocs.io/en/main/reference/equations.html) coefficient 0.5.
Wall density evolves with the Hughes–Graham density floor; wall positions and
velocities stay fixed. Physical viscosity, delta-SPH, tensile correction,
summation density, adaptive timestep and smoothing-length updates are disabled.
Execution is serial CPU, without MPI/OpenMP.

| Run | Spacing / timestep | Population | Duration / saved samples |
| --- | --- | --- | --- |
| Main dam break | 0.0125 m / 0.0001 s | 1,600 fluid + 978 wall | 0.3 s; 3,000 steps; 101 samples |
| Half timestep | 0.0125 m / 0.00005 s | Same IDs/population | 0.3 s; 6,000 steps; 101 samples |
| Coarse spacing | 0.025 m / 0.0001 s | 400 fluid + 498 wall | 0.3 s; 3,000 steps; 101 samples |
| Analytic translation / free fall | 0.025 m / 0.0001 s | 400 fluid, no walls, per case | 0.05 s; 500 steps; 51 samples |

The analytic cases start at zero pressure, constant density and uniform velocity
`(0.3,0.1,0) m/s`. Acceleration is zero for translation and gravity for free fall.
The independent closed-form references are `q=q₀+v₀t+½at²`, `v=v₀+at`, `ρ=ρ₀`.
They test controlled dynamics and integration, not nonlinear pressure/impact
accuracy. The spacing comparison is a **sensitivity bound**, not demonstrated
asymptotic convergence. No experimental dataset or upstream example was imported.

## Numerical results

`TOLERANCES.json` was saved and hashed before execution; no threshold was relaxed.
Step diagnostics cover mass, fluid density, Mach number, containment, wall motion
and energy; recorded arrays are also checked for finite values.

| Check | Measured value | Declared limit | Result |
| --- | ---: | ---: | --- |
| Translation position error, maximum component | 1.287858709e-14 m | 1e-9 m | **PASS** |
| Free-fall position error, maximum component | 1.287858709e-14 m | 1e-9 m | **PASS** |
| Translation / free-fall velocity error | 0 / 1.776356839e-15 m/s | 1e-9 m/s | **PASS** |
| Analytic density error, both cases | 0 kg/m³ | 1e-8 kg/m³ | **PASS** |
| Relative fluid-mass error, all dam runs | 0 | 1e-12 | **PASS** |
| Wall displacement, all dam runs | 0 m | Exactly zero | **PASS** |
| Fluid wall penetration, all dam runs | 0 dx | 1.5 dx | **PASS** |
| Maximum relative density deviation, main / worst of three | 0.0191926 / 0.0210538 | 0.10 | **PASS** |
| Maximum speed/c₀, main / worst of three | 0.1124715 / 0.1124771 | 0.20 | **PASS** |
| Maximum relative energy increase, main / worst of three | 9.96077e-5 / 2.85684e-4 | 0.05 | **PASS** |
| Half-timestep position difference, all fluid samples/components | 1.480705945e-4 m | 0.003 m | **PASS** |
| Fine/coarse 99th-percentile fluid x-front difference | 0.029413369 m | 0.075 m | **PASS** |
| Native-time pairing difference for refinement | 8.16014e-15 s | 1e-11 s | **PASS** |
| Nonfinite recorded values, all dam runs | 0 | Zero | **PASS** |

All **30 numerical checks** passed. The main run's final 99th-percentile x-front
is `1.070630483 m`; this is a measured statistic, not an independent accuracy oracle.
Energy includes kinetic, gravitational and Tait barotropic internal energy
`u=c₀²/7[(r⁶−1)/6+1/r−1]`, where `r=ρ/ρ₀`. Main energy changed from
`614.214975` to `592.106536 J/m`, a 3.60% decrease. Artificial viscosity dissipates,
so energy equality is not required; the test rejects excessive increases.
Gravity and walls exchange momentum with the fluid, so fluid momentum is not
asserted to be conserved. A second main run reproduced **every saved source array
and timestamp exactly**. The documented reproduction script also repeated all
five cases with exact source arrays and passed all 30 numerical checks; the
native reproduction wrapper passed its 104,315 Forward+ checks.

## WVZ1 fidelity and native playback

One particle object records original float64 position, velocity, density,
pressure, mass and smoothing length; native float64 times; solver `gid` widened
losslessly from uint32 to int64 persistent IDs; and a uint32 fluid/wall role.
Coordinates and units are unchanged. There is no decimation, scientific resampling
or channel rounding. Pressure retains the solver's stored integrator-stage value;
export does not recompute it from density. Every 30th main step plus the initial
state is saved, using the actual post-integration clock.

| Boundary | Evidence | Result |
| --- | --- | --- |
| Python source → WVZ1 → source comparison | 101 timestamps and **808 arrays**, exact dtype/value equality; unit metadata and identity checked | **PASS** |
| Strict format/checksum verification | All 101 records in main and each negative capture | **PASS** |
| Altered ID / coordinate / timestamp controls | All three source mismatches detected despite structurally valid captures | **PASS** |
| Native Forward+ | **104,315 checks, zero failures**, clean log and successful exit | **PASS** |
| Native Compatibility | **104,315 checks, zero failures**, clean log and successful exit | **PASS** |
| GPU coordinate error, both renderers | Maximum `1.047536025e-7 m`, limit `1e-6 m` | **PASS**, display precision |

The controls change the first persistent ID throughout the capture, one x value
by `0.01 m`, or sample 10's time by `0.0001 s`. They demonstrate that format
validity alone does not prove source fidelity.

The strict native reader checks every timestamp and all channel hashes, including
exact widening of role categories. The real viewer opens paused; all 2,578 GPU
instances are checked at six exact and four intermediate times, including IDs,
coordinates, requested/source clocks and the held density source. Intermediate
positions are ID-matched linear display estimates; scalars use the lower recorded
sample. **No physical midpoint-error bound is claimed.** Native transport advances
at the configured rate bound and retains time across paused ticks.

Inspected screenshots show initial, middle and final states with role colouring
and Particle size `0.1`; marker size is presentation-only. Particle-hidden/visible
comparisons changed 2,128–2,197 sampled pixels in Forward+ and 1,442–1,531 in
Compatibility. The larger markers used in initial successful runs obscured
individual particles; those runs remain external, alongside both final reruns.
Neither screenshots nor interpolation certify physical correctness or experimental
Selection/Analysis tools.

## Performance, provenance and reproduction

On an AMD Ryzen 7 5800X / NVIDIA GeForce RTX 3070 Ti, Linux x86-64
`7.2.9-200.fc44`, glibc 2.43, NVIDIA driver 615.71.09:

| Measurement | Observed value | Boundary |
| --- | ---: | --- |
| Main solver loop / repeat | 5.189 / 5.228 s | Includes diagnostics and snapshot copies |
| Main setup / warm repeat | 7.449 / 0.035 s | First run includes generated-code compilation |
| Process peak RSS, main / warm repeat | 258,944 / 112,224 KiB | Includes setup; not an isolated solver working set |
| WVZ1 size / export | 24,221,350 bytes / 1.842 s | 101 uncompressed records |
| Python fidelity + whole-file verification | 1.882 s | Instrumented local run |
| Native strict all-record read | 746.930 / 716.295 ms | Forward+ / Compatibility harness |
| Viewer open call | 32.806 / 32.007 ms | Excludes full first-presentation latency |
| Selected synchronous sample calls | 6.415–14.228 / 6.333–14.414 ms | Selected states only, not sustained frame rates |

These are local observations, not throughput, maximum-population or memory-budget
guarantees. Godot engine static-memory measurements are retained externally;
whole-process viewer RSS and GPU VRAM were **NOT RUN**.

Exact versions: PySPH **1.0b2**, CPython **3.11.17**, NumPy **2.2.6**,
Cython **3.0.12**, cyarray **1.2**, compyle **0.9.1**, GCC/G++ **15.3.0**,
micromamba **2.9.0**. Godot is `4.7.2.stable.official.ed1daf0bf`, full commit
`ed1daf0bf001b61586d9930840f2f1394092c079`; renderers are Vulkan Forward+ and
OpenGL Compatibility. External lock files pin all additional setup dependencies.

In the external workspace, using its installed isolated environment and a fresh
output name:

```sh
./reproduce.sh reproduce-01
./run.sh python run_native.py --source reproduce-01/analysis --renderer forward_plus --output reproduce-01/forward_plus
./run.sh python run_native.py --source reproduce-01/analysis --renderer gl_compatibility --output reproduce-01/gl_compatibility
```

External `README.md` supplies exact fresh-install instructions, initial conditions,
energy definitions, source-clock semantics and limitations. `toolchain-explicit.txt`
and `requirements-*.txt` pin setup; `run-01/analysis/results.json` and the two
`*-final/native-results.json` files retain results. `SHA256SUMS` covers stable
scripts, captures, results, logs and screenshots; external environments/caches
are inventoried separately.

| External artifact | SHA-256 |
| --- | --- |
| Main `dam.wvz` | `6d63876e4d1c48f6332c3c0a51377f92a73a2233d14aa6d3df676b72c0e21932` |
| Main `source.npz` | `c69cd7d92ecdd7d30f680b647e6700df45d4b9d1c6f9b9f9058b3000b772ded3` |
| `run_case.py` | `d1a7621549055b1bc16f0214c50866150134fa4c6b6a095000f581893bdd5181` |
| `analyze.py` | `60af07add71b8d532723a0da7f9c142f5ba5cdc39da59a0d1251550422c9d176` |
| `native_check.gd` | `6a008d21432590874f1951e1afdea8d79755d1fe3e5c6f60e00a3c4bcf43d432` |
| Predeclared `TOLERANCES.json` | `075fa90aed4537d4e84ebea3475eeb14f84820fdd9f35cb5d8055d2f2b1dcbcc` |

## Licensing gate, retained failures and owner review

**Report-only gate: PASS.** The sole proposed Git file is this original report.
No third-party benchmark payload enters Wavez or its distributable.
External `LICENSE_INVENTORY.md`, `dependency-inventory.json` and
`toolchain-inventory.json` record exact dependencies, notice paths/hashes,
package sources and artifact provenance:

| External component | Main license / inventory boundary | Enters Wavez Git? |
| --- | --- | --- |
| [PySPH](https://github.com/pypr/pysph), [cyarray](https://github.com/pypr/cyarray), [compyle](https://github.com/pypr/compyle) | BSD main notices; exact installed distributions and exceptions retained externally | No |
| [NumPy](https://numpy.org/doc/2.2/license.html) and compiled wheel components | BSD main terms; OpenBLAS/LAPACK, GCC runtime exceptions and LGPL notices retained | No |
| Cython / Python / setup packages | Apache / PSF / MIT/BSD and other exact package terms in external inventory | No |
| GCC, binutils, sysroot, micromamba | GPL/LGPL/runtime exceptions and BSD/bundled notices as inventoried | No |
| [Godot](https://godotengine.org/license/) | Existing external MIT runtime and bundled notices | No |
| Scripts, data, generated captures and screenshots | Original test work/outputs; no imported datasets or sample problems | No |
| This factual report | Original prose and measured tables only | **Yes** |

No license files, branding or distribution claims change. Wavez retains PolyForm
Noncommercial 1.0.0; no endorsement or relicensing is implied. Physical separation
is not asserted to resolve every licensing question, nor does this report authorize
future redistribution of the benchmark tooling or environment.

Retained **setup failures**: missing cyarray build prerequisites; NumPy 1.26 headers
incompatible with this release's NumPy 2 build requirement; a non-writable default
micromamba cache; and missing explicit serial parallel-manager initialization in
the first harness attempt. These were corrected without modifying PySPH source or
tolerances. Successful concurrent launches also emitted micromamba process-file
cleanup warnings; they remain in logs. Final native logs are clean. Dependency
consistency, Python compilation and shell syntax checks passed.

**NOT RUN:** independent nonlinear dam-break/experimental validation, asymptotic
spatial convergence, 3D, alternative schemes, obstacle/impact cases, other platforms
or GPUs, packaged releases, long sessions, MP4 and Selection/Analysis. The test is
limited to a small 2D column's first 0.3 seconds. Focused dynamics/fidelity/viewer
checks match this report-only scope; unrelated application suites were not rerun.

Before acceptance, review the report-only diff and external license inventory;
run `sha256sum -c SHA256SUMS` in the external workspace; inspect the JSON results
and retained attempts. Open `run-01/analysis/dam.wvz`, confirm paused opening,
play/pause and seeking, and compare the final native screenshots. Use the pinned
reproduction commands for a fresh run. Owner review and merge remain the acceptance
boundary.
