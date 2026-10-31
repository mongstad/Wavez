# Spectral methods and observer models — research #135

Research recommendation for owner review, 2026-10-31. This document proposes
contracts; it does not establish an implemented Spectral Mode. Source values,
derived measurements and presentation retain the separation in
[the scientific contract](../../SCIENTIFIC_ANALYSIS.md#21-hardware-independent-scientific-integrity-boundary).
Primary sources linked below were inspected on 2026-10-31. Public specification
summaries and dataset metadata were inspected; full paywalled CIE standards were
not obtained, and no colorimetry conformance claim is made. No third-party
observer tables, libraries or paper copies are added to Wavez.

## Recommendation and meaning

Start with a **3D windowed Fourier spectrum of a selected source-grid region at
one native sample time**. Use a small CPU calculation, retain the conventional
field view, and show the selected region and its spectrum together. This answers
which spatial scales contribute to that region under a declared window. It does
not identify a unique wavelength belonging to one voxel. A later coarse grid of
overlapping regions can associate band power with positions in 3D; a single
whole-domain spectrum cannot do that.

Use the actual selected channel's name. A spectrum of `energy_density` describes
spatial variations of that quantity. It is not a reconstruction of the signed
scalar field, an optical spectrum or a decomposition of conserved Hamiltonian
energy into modes. For example, if `u=A cos(kx+φ)`, then
`u²=A²[1+cos(2kx+2φ)]/2`: squaring creates DC and doubles this example's spatial
frequency, while `u` and `−u` become indistinguishable. Actual model energy may
also contain gradient, momentum and nonlinear potential terms. Its mode weights
require the model's equations, not a channel-name heuristic. These are algebraic
limitations, independent of the chosen FFT library.

## Method comparison

The following costs are algorithmic estimates, not measured viewer performance.
`N` is the number of source samples, `M` samples per local region, `P` region
centers, `B` bands and `D` orientations. Recommendations are this investigation's
design judgment based on the cited methods.

| Method | Localization, direction and phase | Limits and cost | Decision |
| --- | --- | --- | --- |
| Whole-domain 3D FFT | Full wavevectors and complex phase; no independent local support | `O(N log N)`; periodic extension matters. Radial reduction discards direction. | Diagnostic reference and Parseval checks only. |
| Local 3D windowed FFT / spatial STFT | Fixed, explicit neighborhood; full signed wavevector bins and complex coefficients | `O(P M log M)` if evaluated region by region. Smaller regions localize better but broaden spectral response. Overlapping results are correlated. | First algorithm; one region initially, then sparse centers if justified. |
| Complex wavelets / multiscale filter bank | Scale-dependent support; complex filters retain phase; oriented filters measure chosen directions | Scale-to-frequency calibration and edge masks required. Dense outputs grow as `B D N`; no universally best mother wavelet. | Alternative when scale range or transients justify added contracts. |
| Discrete separable wavelets | Compact multiresolution decomposition; signed coefficients and possible exact inverse | Subbands are basis-dependent, with coarse directional partitioning and shift sensitivity for decimated transforms; not a continuously calibrated wavelength map | Useful compression/scale diagnostic, weaker initial user interpretation. |
| Explicit Fourier/Gabor band filters | Direct controlled passbands; complex or real filtered fields, depending on filter | Full FFT plus roughly `B D` inverse FFTs; sharp cutoffs cause long spatial ringing. Squared amplitude needs declared spatial averaging. | Later few-band 3D maps; retain filter shapes and normalization. |

Window shape trades leakage against resolution and amplitude bias; choosing Hann
does not eliminate these tradeoffs. The original window comparison explains
finite-support leakage, coherent gain and bandwidth:
[Harris (1978), DOI 10.1109/PROC.1978.10837](https://www.fceia.unr.edu.ar/prodivoz/Harris_1978.pdf).
SciPy documents sliding-window complex spectra, inverse transforms and separate
magnitude/PSD scaling, but its `ShortTimeFFT` API is a one-dimensional building
block, not a ready-made spatial 3D solution:
[ShortTimeFFT](https://docs.scipy.org/doc/scipy/reference/generated/scipy.signal.ShortTimeFFT.html).
The proposal applies an n-dimensional FFT to explicitly extracted 3D windows:
[SciPy `fftn`](https://docs.scipy.org/doc/scipy/reference/generated/scipy.fft.fftn.html).

Wavelet scale is not automatically wavelength. Wavelet choice determines its
frequency response and spatial extent; boundary contamination must be marked.
Complex coefficients contain phase, whereas power alone discards it. These
properties and the cone of influence are developed in
[Torrence and Compo (1998)](https://paos.colorado.edu/research/wavelets/bams_79_01_0061.pdf).
The official [PyWavelets CWT documentation](https://pywavelets.readthedocs.io/en/latest/ref/cwt.html)
also makes scale calibration and inadequate low-scale sampling explicit. Its CWT
is one-dimensional; citing it does not establish a validated directional 3D
implementation. No wavelet implementation or performance comparison was run in
this research.

## Proposed Fourier contract

These equations specify an auditable first implementation, not a claim that all
existing experimental scripts use this exact estimator. An experiment must
record its actual detrending and normalization. Let a finite uniform source-grid
region have `M_i` samples and spacing `d_i` on axis `i`, total `M=∏M_i`, and source
values `u_n` with unit `U`. Work in float64 after source decoding; this cannot
restore precision discarded by an f4 writer.

1. Use an explicitly named periodic Hann window on each axis,
   `h_i(n)=0.5−0.5 cos(2πn/M_i)`, and `w_n=∏h_i(n_i)`. Require nondegenerate
   dimensions and finite positive spacing. Record region bounds, axis order,
   physical origin and any object transform. “Periodic Hann” names the discrete
   window convention, not a claim that the selected region is periodic.
2. Store the local weighted mean `μ=Σ(w_n u_n)/Σw_n` separately; transform
   `y_n=w_n(u_n−μ)`. This removes the zero Fourier coefficient. It also suppresses
   very long-wave content: record detrending, and do not advertise recovery of
   the region's absolute/DC field from the residual spectrum.
3. Use the unscaled forward DFT
   `F_q=Σ y_n exp(−2πi Σ_i q_i n_i/M_i)`. The spatial frequency components are
   `f_i=q_i/(M_i d_i)` in cycles per source length, using signed FFT indices.
   Angular wavevector is `k=2πf`; for `|f|>0`, wavelength is `λ_s=1/|f|`.
   DC has no finite wavelength. Display cycles/length or radians/length
   explicitly; never silently interchange them.
4. Define a two-sided bin power
   `Q_q=|F_q|²/(M Σw_n²)`. Its unit is `U²`, and discrete Parseval gives
   `ΣQ_q=Σ[w_n²(u_n−μ)²]/Σw_n²`. Call this **window-weighted mean-square
   residual**, not model energy. A spatial PSD is `Q_q/(Δf_x Δf_y Δf_z)`, with
   unit `U²·length³` when all spatial axes share a length unit. Report either bin
   power or PSD consistently.
5. For a real-input half-spectrum, account for omitted conjugates exactly once.
   With an `rfftn` last-axis reduction, double power only on last-axis interior
   positive-frequency planes; do not double its zero or even-length Nyquist
   planes. Verify against a full complex FFT. Retain exact band edges and sum
   bin powers for band power. Radial shell **sum**, shell **mean**, and power per
   radial-frequency interval are different quantities; expose the chosen one.

The normalization above follows directly by applying discrete Parseval to `y`.
It fixes an implementation ambiguity; it is not a physical energy law. Retain
complex coefficients only when needed for reconstruction or phase diagnostics.
The DFT phase is referenced to the first sample of the selected region. Comparing
phase across region centers requires a documented coordinate-origin phase
correction. Taking absolute values, radial averaging or saving only RGB prevents
exact inversion. Inverse filtering requires a separate overlap/dual-window
contract; division by a Hann window at its zeros is not a valid reconstruction.

The component Nyquist boundaries are `|f_i|≤1/(2d_i)`; frequencies above them alias
into the sampled band. For isotropic radial comparisons, the sphere
`|f|≤min_i[1/(2d_i)]` avoids the directionally incomplete outer corners of the FFT
box. That boundary is a sampling limit, not evidence that near-Nyquist estimates
are accurate. The bin interval is `1/(M_i d_i)`; the window response determines
actual resolution. Padding adds sampled frequencies, not new resolving power.

Use actual source geometry and native arrays, not display texture LOD or rendered
colors. Start with complete finite interior regions. Missing/nonfinite samples
must return unsupported coverage rather than silently becoming zeros. A periodic
wrap is permitted only for a source with verified periodic boundaries; reflection
and zero-padding invent different continuations. Reject or visibly mark edge
regions under the selected boundary rule. A nonorthogonal object transform needs
an explicit reciprocal-basis treatment before reporting world-space wavevectors.

One real scalar snapshot has conjugate symmetry: peaks at `±k` encode an
orientation, not a travel direction. Traveling and standing waves can have the
same instantaneous spatial field. Temporal phase evolution needs enough actual
native samples, declared sampling intervals, and a separate space-time estimator.
Temporal Nyquist is `1/(2Δt)` only for uniform cadence; gaps and irregular times
invalidate a naive temporal FFT. Converting spatial wavelength to temporal
frequency requires a justified dispersion relation. None of these quantities
becomes electromagnetic nanometres by choosing a color palette.

## Human Vision: two explicitly separate uses

**Physically calibrated mode** requires a defined optical quantity, for example
spectral radiance `L_λ(x, direction, t, λ)` in `W·m⁻²·sr⁻¹·nm⁻¹`, and a validated
route from the source to that quantity. Spectral irradiance is a different
angularly integrated quantity; emission coefficients, reflectance and arbitrary
scalar power are different again. A scalar model's FFT supplies none of the
missing emission, transport or radiometric calibration. For reflection, the
illuminant and reflection/geometry model must be specified. For participating
volumes, optical transport cannot be replaced by the current scalar opacity
compositing and called physical light.

**Exploratory mapping mode** may deliberately map measured spatial band power
to synthetic visible bands. It must carry a persistent label such as
“Exploratory spatial-frequency color — not emitted light”, with the source
quantity, spatial units, window size, band edges, mapping endpoints and intensity
normalization recorded. Preserve raw band power independently. If converting a
continuous density through `λ_display=g(f)`, include its change-of-variable
Jacobian; alternatively map explicitly integrated band powers without treating
them as per-nanometre densities. A chosen nanometre interval is a display design
parameter, not a measured Model A wavelength. No Human Vision mapping is required
for the first numerical spatial-spectrum panel.

### Observer response before display conversion

For a defined spectral radiance density and energy-based sensitivity `s_i`, the
numerical response is `r_i=Σ_j L_λ(λ_j)s_i(λ_j)Δλ_j`, using declared quadrature.
If inputs are already band-integrated quantities, do not multiply by bandwidth a
second time. Energy and photon weighting differ; any conversion must use the
actual spectrum's wavelength units. Keep relative normalization explicit.
XYZ additionally needs a declared normalization factor: a relative reference may
set reference `Y=1`; an absolute photometric result needs the appropriate
radiometric-to-photometric scale and calibrated input. Relative cone responses
must not be labeled luminance in `cd/m²`.

Use two named, distinct scientific options:

- **CIE 1931 2° XYZ photopic colorimetry:** integrate against the specified
  `x̄,ȳ,z̄` functions. The official table uses 1 nm steps over 360–830 nm;
  record truncation if the input spectrum covers less. This is a standard
  color-matching observer, not three measured cone excitations.
  [CIE table](https://cie.co.at/datatable/cie-1931-colour-matching-functions-2-degree-observer),
  [range and interpolation metadata](https://files.cie.co.at/Publications-datasets/CIE_xyz_1931_2deg.csv_metadata.json).
- **CIE 2006 2° LMS energy-based cone fundamentals:** retain relative L/M/S
  responses with this observer identity. The inspected table spans 390–830 nm
  at 5 nm steps; S-cone support ends earlier in its metadata. Apply the table's
  documented missing/support rules rather than an unexamined generic NaN fill.
  [CIE table](https://cie.co.at/datatable/cie-2006-lms-cone-fundamentals-2-field-size-terms-energy),
  [metadata](https://files.cie.co.at/Publications-datasets/CIE_lms_cf_2deg.csv_metadata.json).

Do not mix one observer's LMS with an arbitrary “LMS to RGB” matrix and label it
CIE 1931 XYZ. A later cone-based display pipeline must select the corresponding
standard colorimetric basis and validated transformation. The CIE explicitly
treats physiological-axis colorimetry as a defined construction:
[CIE 170-2](https://www.cie.co.at/publications/fundamental-chromaticity-diagram-physiological-axes-part-2-spectral-luminous).
For the first future Human Vision color display, direct named XYZ integration is
the simpler auditable choice; LMS can remain a separately labeled diagnostic.

The 1931 observer describes photopic color matching; the 1964 observer has a
different field-size applicability. These are not models of every individual's
vision or low-light behavior:
[ISO/CIE 11664-1 public description](https://www.cie.co.at/publications/colorimetry-part-1-cie-standard-colorimetric-observers-0).
A scotopic approximation would integrate with `V′(λ)` and produce a rod-weighted
brightness diagnostic, not an independent three-channel color perception model:
[CIE scotopic function](https://cie.co.at/datatable/cie-spectral-luminous-efficiency-scotopic-vision).
Mesopic transitions, UV/IR sensors and custom curves need separate response and
calibration contracts. UV/IR false colors are not human-visible source colors.

### Display, adaptation and information loss

After the observer, apply an explicitly selected reference/exposure and display
transform: XYZ → target linear RGB → declared gamut/tone handling → output
transfer encoding. sRGB has defined primaries, D65 white and a piecewise transfer
function; it is not obtained by independently normalizing XYZ or treating LMS
as RGB. Negative or excessive RGB components need a documented gamut policy,
with clipping/compression reported separately from the original XYZ values.
[ICC sRGB registry](https://registry.color.org/rgb-registry/srgb) and
[ICC sRGB conversion description](https://registry.color.org/rgb-registry/files/sRGB.pdf).

Recommendation: initially use fixed exposure/reference normalization with an
out-of-gamut indication and retained numerical XYZ. Automatic per-frame scaling
can hide physical changes and cause misleading playback; if later offered,
record it as presentation. Bloom, artistic exposure and Cinematic tonemapping
remain presentation controls, not observer response. A monitor profile, actual
luminance and viewing conditions would be needed before claiming a calibrated
screen appearance; none was measured in this research.

Adaptation is not the same as an RGB transfer function. A future appearance model
must declare adapting white, luminance and surround; CIECAM16 is explicitly
viewing-condition dependent. Its public description was reviewed, not its full
implementation or conformance data:
[CIECAM16](https://www.cie.co.at/publications/cie-2016-colour-appearance-model-colour-management-systems-ciecam16).
Do not claim retinal dynamics, dark adaptation or perceived brightness from XYZ
integration alone.

Different optical spectra can share the same tristimulus response, which is
metamerism. RGB cannot preserve or reconstruct a full source spectrum, even
before gamut clipping. Always retain raw spectral information for inspection:
[CIE definition](https://cie.co.at/eilvterm/17-23-006).
The inspected CIE XYZ/LMS metadata assigns CC BY-SA 4.0 to those datasets.
Bundling tables would require the repository's separate third-party review;
this report cites them without copying them.

## Validation gates for future implementations

The present research's numerical evidence is separate from these proposed
acceptance gates. A first implementation should pass known-answer spatial tests
for on/off-bin modes, unequal axis spacing, window-size changes, mixed modes,
Parseval and real/full FFT agreement, sign/phase shifts, squared-field ambiguity,
edges, nonfinite support and above-Nyquist aliases. Validate source hashes and
f4/f8 declarations independently. Keep a local region with known content next to
a region with different content to prove localization, not only global peaks.
Use traveling and standing cases to demonstrate the snapshot's direction limit;
do not claim a successful propagation estimator from those tests alone.

Human Vision should have its own later gate: pinned observer tables/checksums
and license review; analytical narrow-band integration cases; quadrature
convergence; declared reference-white normalization; additive spectra remaining
additive before nonlinear display processing; distinct but metameric spectra;
out-of-range/negative-input handling; gamut/encoding checks; fixed versus
adaptive intensity comparisons; and calibrated-source metadata rejection. No
observer numerical implementation, color-calibrated display experiment or
optical interpretation of Model A has been validated here.
