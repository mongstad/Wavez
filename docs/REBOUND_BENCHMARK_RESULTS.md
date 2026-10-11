# REBOUND / WVZ1 benchmark results — issue #346

Executed **2026-10-11** against Wavez commit
`c66fbdfaf686408683153c5d980bbdf960a6bc17`, application **v0.1.0.94**.
The final scientific, source-fidelity and native-viewing checks passed within
the scope below. Initial failures are retained and described separately.
This is a finalized execution report; owner acceptance remains pending.

The fresh external workspace is
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/01_REBOUND/`.
All scripts, dependencies, numerical data, captures, screenshots and detailed
logs remain there. This original factual report is the sole Git deliverable.
The issue's explicit report-only restriction takes precedence over the usual
implementation build increment: no application code, build identity, packaging,
license files, current guides or historical reports were changed.

## Method

This is an **idealized Newtonian Solar System**, not observed ephemerides or an
epoch-specific astronomical prediction. Rounded masses/radii and arbitrary
phases/inclinations are declared test inputs, with no imported dataset or sample
problem. Units are AU, model year and solar mass; the model defines `G = 4π²`.
All nine point masses interact; no moons, relativity, collisions, softening or
external forces are included.

| Body | Mass / solar mass | Initial heliocentric radius / AU | Phase / rad | Inclination / rad |
| --- | ---: | ---: | ---: | ---: |
| Sun | 1 | 0 | 0 | 0 |
| Mercury | 1.6601e-7 | 0.387 | 0.3 | 0.07 |
| Venus | 2.4478e-6 | 0.723 | 1.1 | 0.03 |
| Earth | 3.0035e-6 | 1 | 2.2 | 0 |
| Mars | 3.2272e-7 | 1.524 | 3.1 | 0.025 |
| Jupiter | 9.5458e-4 | 5.203 | 4.0 | 0.02 |
| Saturn | 2.8581e-4 | 9.537 | 4.8 | 0.04 |
| Uranus | 4.3658e-5 | 19.191 | 5.5 | 0.015 |
| Neptune | 5.1503e-5 | 30.069 | 6.0 | 0.03 |

Each planet starts at `r(cos φ, sin φ cos i, sin φ sin i)` with velocity
`√(G(1+m)/r)(−sin φ, cos φ cos i, cos φ sin i)`. The Sun initially rests at the
origin; all positions and velocities then shift to the barycentric frame.
Exact Cartesian initial conditions are retained in external `source.npz`.

[REBOUND IAS15](https://rebound.hanno-rein.de/integrators/ias15/), with
`epsilon=1e-9` and `exact_finish_time=1`, records 1,001 nonuniform native times
`20(k/1000)^1.07`, `k=0…1000`. An independently implemented Cartesian pair-force
model and [SciPy DOP853](https://docs.scipy.org/doc/scipy/reference/generated/scipy.integrate.solve_ivp.html)
provide the reference. Shared initial conditions/equations are intentional;
the force and integration implementations are independent. Three reference
settings `(rtol, atol, maximum step in yr)` were evaluated:
`(1e-10, 1e-12, .02)`, `(2.5e-13, 2.5e-15, .005)`, and
`(2.3e-14, 2.3e-16, .0025)`. The third level followed a failed coarse/fine
convergence check; no declared tolerance was relaxed.

A separate circular Sun/Earth-mass binary is compared to closed-form barycentric
motion at 1,001 times over 20 periods. Position errors below are maximum absolute
component errors across all tested bodies/times. Energy drift is
`max |(E−E₀)/E₀|`; angular momentum drift is `max ||L−L₀||/||L₀||`.

## Measurements

| Check | Measurement | Declared limit | Result |
| --- | ---: | ---: | --- |
| Initial coarse/fine reference difference | 1.553873148e-7 AU | 2e-8 AU | **FAIL**, coarse reference not converged |
| Fine/refined reference difference | 1.449238299e-10 AU | 2e-8 AU | **PASS** |
| REBOUND vs refined reference, 9 bodies × 1,001 times | 1.193194848e-11 AU | 2e-7 AU | **PASS** |
| Relative energy drift | 2.152116124e-15 | 1e-11 | **PASS** |
| Relative angular momentum drift | 3.123831498e-16 | 1e-12 | **PASS** |
| Analytic binary position error | 1.648783701e-12 AU | 2e-10 AU | **PASS** |
| Python WVZ1 readback | 5,005 arrays, 1,001 native times | Exact dtype/value/time equality | **PASS** |
| Whole-file verification | 1,001 records per capture | Checksums and structural constraints | **PASS** |
| Altered ID / position / time controls | 3 detected / 3 | Source comparison must reject | **PASS** |
| Repeated execution | All source and 5,005 decoded arrays repeat exactly | Exact numerical equality | **PASS** |
| Native Forward+ | 16,326 checks, 0 failures; clean exit | No failures | **PASS** |
| Native Compatibility | 16,326 checks, 0 failures; clean exit | No failures | **PASS** |
| GPU position error, both renderers | 1.420186944e-6 AU | 5e-6 AU | **PASS**, display precision only |

The capture stores float64 positions, velocity and mass; int64 particle IDs
`9007199254740993…9007199254741001`; uint32 body indices; and original float64
timestamps. Rows cyclically reorder at every sample. Export performs no scientific
resampling or coordinate/unit conversion. Native verification checks the original
binary times, hashes of all decoded position/velocity/mass/ID byte arrays, and
every body-index value. Python also checks units and persistent identity.

Negative captures remain structurally valid: one changes Mercury's persistent
ID, one offsets a position by `0.001 AU`, and one offsets a timestamp by
`0.0001 yr`. All pass format verification and fail comparison with the source.
Format validity alone therefore does not establish scientific fidelity.

## Native visualization and time

The real viewer opened paused and displayed nine particle instances. Seven exact
samples and six intermediate times verified GPU positions, exact persistent IDs,
requested/source clocks, and `exact` versus `interpolated by ID` status. Native
transport advanced through 120 ticks at `1/60 s`, rate 1, with asynchronous
preparation; ten paused ticks retained time. This checks advancement and a rate
bound, not long-run throughput. Both processes exited successfully without
warnings/errors. Particle-visible/hidden image comparisons changed 68 sampled
pixels in Forward+ and 46 in Compatibility; retained screenshots were inspected.
The existing Particle size setting was 8 for legibility, not physical body radii.
Inner planets cluster in the full-system view.

**Interpolation is not a recorded physical observation.** At the six selected
midpoints, linear display estimates differed from direct REBOUND states by up to
`0.013276318 AU`. This is separate from exact WVZ1 storage and the scientific
trajectory checks at native times. Screenshots alone are not scientific proof.

## Provenance, reproduction and licensing boundary

Environment: Linux x86-64, kernel `7.2.9-200.fc44`, glibc 2.43;
AMD Ryzen 7 5800X; NVIDIA GeForce RTX 3070 Ti, driver 615.71.09;
Godot `4.7.2.stable.official.ed1daf0bf` (full hash
`ed1daf0bf001b61586d9930840f2f1394092c079`). Native renderers were Vulkan Forward+
and OpenGL Compatibility. Dependencies: CPython 3.14.8, REBOUND 4.4.10,
NumPy 2.4.2, SciPy 1.17.0; pip 26.0.1 performed setup.

From the external workspace, with the named Wavez revision available:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python benchmark.py --output reproduce-01
.venv/bin/python run_native.py --source reproduce-01 --renderer forward_plus
.venv/bin/python run_native.py --source reproduce-01 --renderer gl_compatibility
```

Use a fresh output name; the native wrapper accepts `--godot /absolute/path`.
External `README.md` gives exact commands, initial conditions, definitions and
retained attempt paths. `run-02/` contains the final execution;
`dependency-inventory.json` records installed license paths/hashes;
`LICENSE_INVENTORY.md` records artifact provenance and attribution boundaries;
`SHA256SUMS` covers the stable scripts, reports, captures and evidence.

| External component/artifact | License/provenance inventory | Enters Wavez Git/distributable? |
| --- | --- | --- |
| [REBOUND 4.4.10](https://github.com/hannorein/rebound/blob/4.4.10/LICENSE) | GPLv3 license text retained with external test installation | No |
| [NumPy 2.4.2](https://github.com/numpy/numpy/blob/v2.4.2/LICENSE.txt), [SciPy 1.17.0](https://github.com/scipy/scipy/blob/v1.17.0/LICENSE.txt) | BSD main licenses; wheel notices retained, including OpenBLAS/LAPACK, GCC runtime exception and LGPL libquadmath | No |
| Python / pip / [Godot](https://godotengine.org/license/) | PSF / MIT / MIT main terms plus their own bundled notices; external tooling | No |
| Benchmark scripts and generated data/captures/screenshots | Original test work and outputs; no imported examples or external dataset | No |
| This report | Original factual prose and measured tables only | **Yes: sole report-only diff** |

This inventory confirms the report-only boundary; it does not assert that physical
separation resolves all licensing questions or authorize future redistribution of
the benchmark environment. Wavez's existing PolyForm Noncommercial 1.0.0 model,
notices, trademarks and packaging remain unchanged. No third-party endorsement
or relicensing is implied.

Selected SHA-256 provenance for the final run:

| Artifact (external) | SHA-256 |
| --- | --- |
| `run-02/solar.wvz` | `99e412c03c58e7a14e4a53d18785271c0bcaa03b01266f0d4b781c8642bd6b78` |
| `run-02/source.npz` | `00208021689b5bbcf9996aaf1a576576dbf146c55dc08c3d9068f73c9543548d` |
| `benchmark.py` | `30b757aac925d31f259e28fec54769fb60c5aea425c260da397ed39d9868c3dd` |
| `native_check.gd` | `8edc996769075f0c42b22b1d58f97f2f7bcbde55de6abed5a10d5fccf539a57c` |

Repeated capture file hashes differ because each WVZ1 header receives a new UUID;
all source values and decoded arrays nevertheless reproduced exactly.

## Retained failures, limits and owner checks

The initial older NumPy/SciPy pins could not install on Python 3.14 without an
unavailable C++ compiler; the final compatible pins installed successfully.
The sandbox initially denied native display access; authorized GPU runs succeeded.
An initial harness reported 129 timestamp mismatches from JSON-decoded expected
times and a tiny-marker pixel-check failure. Exact binary expectations and the
existing presentation-size setting corrected those harness/setup issues, without
loosening data tolerances. Initial logs/scripts and the failed coarse reference
comparison remain intact externally; historical repository evidence is untouched.

**NOT RUN:** packaged releases, other operating systems/GPUs, long-session or
large-particle performance, MP4 export, experimental Selection/Analysis tools,
and comparison to astronomical observations. This finite 20-year idealized model
does not validate actual ephemerides or certify untested analysis tools. Validation
focused on independent dynamics, exact capture fidelity and native particle/time
paths; unrelated application regression suites were not run for a report-only change.

Before acceptance, inspect the report-only PR diff and external license inventory;
verify `sha256sum -c SHA256SUMS` in the benchmark workspace; review final JSON/logs
and the preserved failures. Open `run-02/solar.wvz` in Wavez, confirm paused
opening, play/pause and seek, and inspect the native screenshots. Use the external
reproduction commands if a fresh numerical run is desired. Owner review and merge
remain the acceptance boundary.
