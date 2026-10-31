# Model A data-readiness audit — issue #135

Research evidence dated 2026-10-31, based on Wavez accepted commit
`681a46f8f8473ee6b5323ec4af71ada883183077`. No simulation was rerun, capture
rewritten, or source/export format modified. This is a sampled data audit, not
certification of every payload or of Model A's physical interpretation.

**A finalized, signed-field Model A capture is available now.** The N192 run
below supports a first spatial-spectrum implementation without a new WVZ1/SWSS
format or exporter feature. The more recent N320 capture contains only
`energy_density`; its spectrum describes local energy structure and cannot be
presented as the spectrum of the underlying signed scalar amplitude.

## Actual captures and provenance

The inspected original runs live under the external read-only parent:

```text
/home/Nozba/Documents/Dev/Sims/Model-A/outputs/
```

Each row's directory is `run_<run ID>` and its capture is `model_a_<run ID>.wvz`.
Full paths, file sizes/stat stamps, WVZ UUIDs, complete structural-index SHA-256,
source/SWSS/exporter hashes, selected decoded-array hashes and checkpoint hashes
are retained in [data_readiness.json](evidence/data_readiness.json). That file
contains no scientific arrays. These external inputs are required to reproduce
the actual-data checks; they are deliberately not bundled into Wavez.

| Run ID | Grid / seed | Actual volume channels | Native volume times | Original bytes | Role in this audit |
| --- | --- | --- | --- | ---: | --- |
| `20261030T193414164759Z_b3a4a787cae945b0909004cac75740ca` | 192³ / 3003 | `amplitude`, `energy_density`, `gradient_magnitude` | 41 samples, 0–40, Δt=1 | 6,965,545,431 | Main reference; all three channels sampled at t=0,20,40; checkpoint comparison at 0,40 |
| `20261030T205345553035Z_678c9919a7b949bb91fb364e0c22c83c` | 256³ / 2854 | `amplitude` | 1,001 samples, 0–100, Δt=0.1 | 134,359,908,291 | Higher-cadence signed-field candidate; structural/provenance audit only |
| `20261030T232217150259Z_4662e0aede704d96b2dd4edfaa85a2d4` | 256³ / 2854 | `gradient_magnitude` | 751 samples, 0–150, Δt=0.2 | 100,803,490,095 | Magnitude-only counterexample; structural/provenance audit only |
| `20261031T083021711514Z_f253e398edcf46669fa53f8fe0e4dbe1` | 320³ / 5452 | `energy_density` | 401 samples, 0–200, Δt=0.5 | 105,125,852,692 | Recent energy-only reference; payload endpoints t=0,200 verified |

All four matching `summary.json` files report `complete`, final time equal to
configured T, and independently state that export validation was not performed
by the run. Every record in all four originals passes the current strict WVZ1
structural scanner; committed EOF equals the complete file size. WVZ1 has
per-sample commit records, **not a terminal run-completion marker**. Here,
finalization is supported jointly by the run summary/configuration, expected
last sample, complete structural scan and unchanged file stat during the audit.
It is not inferred from a `.wvz` extension or a successful open alone.

The N192 capture also has 41 samples of `derived_markers`: anonymous positions
and the three scalar channels sampled at periodic energy maxima. They are not
physical particles, persistent identities, or a uniform spatial grid. Their
metadata/commit structures were checked; marker payloads were not reread.
Use the volume for spatial FFTs; do not FFT the marker row order.

### A misleading partial copy

The Downloads file named
`model_a_20261031T083021711514Z_f253e398edcf46669fa53f8fe0e4dbe1.wvz` contains
38,013,089,300 bytes and 145 committed samples ending at t=72. Its metadata,
UUID and record descriptors match the first 145 records of the N320 original.
It passes a strict structural scan, but is an incomplete copy of a run that
continued to t=200. Payload-by-payload prefix equality was not checked. This
copy was excluded from the completed-run numerical evidence. A future spectral
cache must bind the actual committed extent and sample, not only the filename,
UUID or apparent file validity.

## Measured contract and source meaning

All four frozen `source/` snapshots match their `provenance.json` SHA-256 lists
(seven files each). The four SWSS schema-3 manifests' declared source hashes
also match. The six recorded Wavez exporter source hashes match the accepted
checkout used for this audit. The source packages identify Model A 0.1.5 and
SWSS 3.0. This audit uses those run snapshots, not an assumption that the live
`/home/Nozba/Codex/Cosmos/model_a` checkout produced the recorded data.

The frozen `kernel.py` defines a dimensionless periodic real scalar field q
with conjugate p=q̇, Fourier collocation, and symmetric nonlinear kick / exact
linear flow / kick. Its equations correspond to

```text
q_tt = ∇²q − q + q³ − 0.3q⁵
V(q) = q²/2 − q⁴/4 + 0.05q⁶
```

This is a mathematical scalar amplitude, not mass density or electromagnetic
radiance. Source code and provenance, rather than the channel names alone,
establish these semantics:

| Channel | Exact source definition | Available information / loss |
| --- | --- | --- |
| `amplitude` | q, retained as float64 | Signed nodal field at the recorded instant; enough for its discrete spatial spectrum and complex phase relative to a stated origin/window |
| `gradient_magnitude` | √(Σᵢ (Dᵢq)²), with real spectral derivatives | Nonnegative magnitude, not the three signed derivative components; loses direction and cannot recover q |
| `energy_density` | V(q) + p²/2 + Σᵢ(Dᵢq)²/2 | Local derived energy, combining potential/kinetic/gradient terms; neither q nor a modal energy spectrum |

Even-grid first-derivative Nyquist multipliers are zero in the frozen local
energy definition. The solver's separate Parseval Hamiltonian diagnostic
retains Nyquist gradient power. Its mean energy can therefore differ from the
mean exported local energy; `energy_density_definition_gap` records that
distinction. Do not silently substitute one definition for the other.

No WVZ volume here contains p or the individual signed derivatives. The N192
run does retain q and p in separate float64 `.npz` checkpoints at t=0,8,…,40;
the N320 run similarly retains t=0,8,…,200. Those snapshots support independent
instantaneous analyses at their own times. They do not supply the missing q
at every energy-only WVZ frame, and this research does not convert or mutate
them. A future conversion would need a separately scoped, owner-approved task.

The general metadata lists units for all three possible channels even when
only one channel was exported. **The descriptor array table is the authority
for channel presence.** A units label is not evidence that an array exists.

## Geometry, sampling and limits

All audited volumes use identity `data_to_world`, node centering, xyz origin
(0,0,0), dimensionless length/time/channel units and a periodic box of length
L=32 per axis. Solver arrays/checkpoints are xyz; exported WVZ arrays are zyx.
Coordinates run from 0 to L−h, with h=L/N. The final node is not an additional
sample at L. A periodic Fourier transform uses period **N·h=32**, not the
displayed node span **(N−1)·h**. Periodicity is supported by source/provenance
and the metadata's coordinate convention; it is not a required structured
WVZ boundary-condition field that a generic consumer can assume for all data.

| Grid | h | Per-axis Nyquist f (cycles / model length) | Per-axis angular k Nyquist | Raw float64 bytes/channel/sample |
| --- | ---: | ---: | ---: | ---: |
| 192³ | 1/6 | 3 | 6π ≈ 18.8496 | 56,623,104 (54 MiB) |
| 256³ | 1/8 | 4 | 8π ≈ 25.1327 | 134,217,728 (128 MiB) |
| 320³ | 1/10 | 5 | 10π ≈ 31.4159 | 262,144,000 (250 MiB) |

The full-box frequency-bin spacing is 1/32 cycles/length, or 2π/32 angular
wavenumber. The axis Nyquist wavelength is 2h; treat near-Nyquist estimates
cautiously, especially directional phases. The 3D support is a Cartesian
frequency box: radial shells above the smallest axis Nyquist have incomplete
angular support and are not an isotropic fully sampled band.

All runs integrate with dt=0.02, but **recording cadence determines temporal
analysis limits**. The N192 recording's temporal Nyquist is only 0.5 cycles/model
time; the N256 amplitude recording's is 5; N256 gradient magnitude's is 2.5;
N320 energy's is 1. No temporal interpolation can restore discarded evolution.
These bounds do not impose an extra restriction on an instantaneous spatial
FFT, but they do limit tracking its evolution and distinguishing traveling
from standing waves. Cadence checks must use native object sample times, not
playback FPS. The separate checkpoint cadence 8 has temporal Nyquist 1/16.

An M³ local window has extent M·h and bin spacing 1/(M·h), before the additional
effective bandwidth of its taper. For N192, 32³/64³/128³ windows span
5⅓/10⅔/21⅓ units. The frozen noise initialization is restricted to angular
|k|≤0.9; a 32³ window's first nonzero bin is k≈1.178. It cannot claim to resolve
those initial long wavelengths. Smaller windows are a latency/memory fallback
with explicitly worse scale resolution, not equivalent measurements.

The solver uses no de-aliasing or filtering during nonlinear evolution. Initial
band limiting and a small reported high-k tail do not prove absence of nonlinear
aliasing, timestep error or continuum-resolution error. The audit does not
establish convergence. Signed nodal samples determine a chosen discrete/
trigonometric reconstruction; they do not uniquely determine an arbitrary
continuous physical field between samples.

## Bounded verification results

[audit_model_a.py](audit_model_a.py) performs the complete structural/provenance
audit and five field-sample payload reads. Every selected stored and decoded
chunk checksum passes. All selected arrays are finite. At N192 t=20, amplitude
ranges from −0.9682381568 to 0.6959933384; at t=40, from −1.2275794172 to
2.0287075741. The exporter has demonstrably preserved signed values.

At N192 t=0 and t=40, amplitude is **bitwise equal** to archived q after xyz→zyx
transpose. Independently recomputing the frozen derivative/local-energy
expressions from archived q/p gives maximum absolute error **0.0** for both
`gradient_magnitude` and `energy_density` at both times in this environment.
This verifies sampled source semantics and orientation, not every output frame.

The complete original captures total 347,254,796,509 bytes. This audit deliberately
omits full-file hashing and all-frame payload verification. The separate
[source-path experiment](evidence/source_path.json) subsequently hashes the one
6.97 GB N192 reference through the existing `SourceSnapshot`; it does not verify
every frame's decoded payload. Complete
structural hashes are hashes of the indexed metadata/descriptors, **not hashes
of every payload byte**. Selected array SHA-256 and checkpoint file SHA-256
values identify the bounded numerical inputs. File size, identity and
mtime/ctime remained unchanged for each audited capture and checked checkpoint.
No absolute claim of untouched unexamined external bytes is made from stat
checks alone.

Reproduce from the Wavez repository with existing NumPy and SciPy:

```sh
PYTHONDONTWRITEBYTECODE=1 python docs/research/spectral-135/audit_model_a.py \
  --runs /home/Nozba/Documents/Dev/Sims/Model-A/outputs \
  --partial-copy /home/Nozba/Downloads/model_a_20261031T083021711514Z_f253e398edcf46669fa53f8fe0e4dbe1.wvz \
  --output /tmp/wavez-135-data-readiness.json
```

The script audits four fixed run IDs, not arbitrary future output trees. It
reads five volume samples, two archived checkpoints and small provenance/index
records. It never starts the solver, creates captures, writes external inputs,
or emits raw scientific arrays. Timing fields and file stat values are
environment-dependent; compare scientific hashes, schemas and assertions.

## Readiness decision

**Go** for a source-based local spatial spectrum of explicitly selected
`amplitude` from the finalized N192 reference; use the N256 amplitude run only
after the desired samples receive equivalent payload verification. Conventional
scalar rendering remains the independent comparison. Scientific computations
must read the original float64 arrays, not a float32 RF texture, LOD/downsampled
preview, interpolated color, or screenshot; see [architecture](ARCHITECTURE.md).

**Go with an explicit different label** for a spatial spectrum of
`energy_density` or `gradient_magnitude` as derived observables. Squaring and
magnitude operations mix Fourier modes and erase information. Even in a simple
cosine, squaring introduces DC and doubled frequency; Model A's quartic/sextic
potential and kinetic/gradient terms add further mixtures. An energy-density
spectrum is not a q spectrum, nor is Fourier power of local energy the physical
Hamiltonian energy assigned to each q mode.

**No-go** for reconstructing signed q/phase or physical light from the N320
energy-only capture. For future owner-run N320 captures, the existing
`--quantities=amplitude` option already exports the needed signed field without
a format change. At 320³, each channel costs 250 MiB and the current WVZ1 object
sample ceiling is 256 MiB, so adding a second full-resolution channel to the
same volume sample would exceed the accepted contract. Do not casually advise
`amplitude,energy_density` at this resolution. The N192 three-channel sample is
162 MiB and already fits. No new data generation is required to begin the
proposed first implementation against the available N192 reference.

Current owning code: [WVZ1 reader/writer](../../../wavez_export/scene.py),
[pinned scientific reads](../../../wavez_export/analysis/source.py),
[scientific contract](../../SCIENTIFIC_ANALYSIS.md),
[format policy](../../CAPTURE_FORMAT_POLICY.md). Model A semantics above are
bound to the external frozen files by their hashes in the evidence, not by an
unversioned general description.
