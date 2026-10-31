# Regional spatial spectrum

**Tools → Spatial spectrum** is an experimental, source-verified diagnostic for
one scalar volume channel at one native sample. It follows the
[accepted #135 research](research/spectral-135/README.md). It does not alter the
scalar viewport or infer optical emission, physical model energy, a voxel's
wavelength, or a precise dominant wavelength.

Choose the source object and channel explicitly. Use `amplitude` for the signed
Model A reference; `energy_density` and `gradient_magnitude` cannot recover its
signed field. Choose a native sample, or pin the sample held at the playhead.
The requested scene time and the actual native time are distinct. Playback can
continue while the calculation runs; moving the playhead does not retime a
completed result.

Enter an integer **XYZ start and size** on the original source grid. Each axis
requires 4–256 samples, with at most 192³ samples in total. Every sample must be
inside the field. There is no partial boundary padding or periodic wrapping.
The source-region wire indicates the requested support; it is not a spectral
rendering and is excluded from scientific/offline output. Choose **Compute**;
the existing owned analysis worker reports source verification, decoding and
calculation progress. **Cancel** dismisses the publication target immediately;
unresponsive work uses the existing worker cancellation grace and termination.

The first request verifies the entire committed capture prefix. Large captures
can spend appreciable time there before decoding the selected channel. Later
requests use the existing identity-checked verification memo. Results carry the
committed byte extent, SHA-256, native record, channel, source geometry and ROI.
An edited, replaced or truncated source is refused. Appended data is outside an
existing pin; reopen the capture to bind a newer committed extent.

## Reading the result

The bounded plot and table show **radial shell sums**, in cycles per declared
source-coordinate unit and squared channel units. Radial reduction discards
direction and phase. Shells above the smallest axis Nyquist frequency have
incomplete directional coverage. Unknown units remain explicitly unknown;
display labels and arbitrary metadata are not physical calibration.

Support length is `L_i = N_i * spacing_i`; the frequency step is `1/L_i`.
The optional lowest frequency of interest must be positive and below the
smallest axis Nyquist limit; it reports cycles contained on each axis.
Fewer than two on any axis is **insufficient support**. Passing that heuristic
is only a candidate, not a resolution guarantee. Hann broadening and leakage
remain. For the signed N192 Model A reference with spacing 1/6, 32³, 64³ and
128³ regions have frequency steps 0.1875, 0.09375 and 0.046875. Even 128³ holds
only about 1.7 cycles of an angular wavenumber 0.5 disturbance. A small-region
peak must not be presented as a reliable wavelength estimate.

The source is converted to float64 for a separable **periodic Hann** window:

```
w = product_i (0.5 - 0.5*cos(2*pi*n_i/N_i))
mu = sum(w*q)/sum(w)
F = unscaled_DFT(w*(q-mu))
power = multiplicity*abs(F)^2 / (N*sum(w^2))
```

The real FFT's last axis uses multiplicity two for interior positive frequencies;
DC and an even-length Nyquist plane have multiplicity one. The power sum equals
`sum((w*(q-mu))^2)/sum(w^2)` within floating-point tolerance. It is a
window-weighted mean-square residual, not the model's Hamiltonian energy. The
result records the mean, normalization, Parseval discrepancy, bin convention,
source dtype and calculation provenance. No rescaling or clipping hides
overflow or nonfinite source values.

## Bounds and current limits

Only a real scalar sample channel on a uniform native grid is supported. Source
spacing, shape, origin, centering and identity linear transform are preserved;
translation is allowed, rotation/scale/shear are refused. Categorical, identifier
and wrapped-phase declarations are refused. Missing channels, malformed units,
nonfinite selected samples and unsupported geometry have explicit failures.

The worker reserves the selected channel's **whole-sample decode**, even for a
small ROI, plus a conservative `64*ROI_cells + 4 MiB` workspace. Default job
memory is 512 MiB. A 320³ float64 source channel can exceed it before any FFT;
cropping does not make that decode free. At most 512 radial bins cross the
bounded IPC channel. One transient result is retained by the dialog; no dense
spectral cube, playback-cache entry, prepared-timeline mark, persistent result
cache, export format or WVZ1/SWSS change is introduced.

Source/selection/request revisions gate publication. Changing inputs makes the
old result ineligible; closing the dialog cancels its job. Existing Close File
behavior refuses while analysis is active; cancel, then close. Source reset
clears the dialog result and indicator. Scientific/Cinematic settings and ordinary
playback remain independent.

External Python and NumPy are required, as for existing analysis. NumPy's CPU
FFT is bounded but not interruptible inside a single call; cancellation is
checked around it and during plane-wise reduction. GPU FFT, all-frame work,
dense spectral maps, Human Vision, inverse synthesis and automatic physical
interpretation remain outside this feature. See the
[implementation evidence and owner checks](evidence/issue-413/README.md).
