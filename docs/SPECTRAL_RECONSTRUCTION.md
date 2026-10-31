# Reconstructed spectral volumes

This experimental `spectral`-branch workflow reconstructs one verified native
`field / amplitude` record into three signed, spatially resolved scalar volumes.
It is a full three-dimensional Fourier decomposition. Its colors describe a
derived scalar value; they are not optical wavelengths, emitted light, physical
energy, material identity or proof of persistent structures.

## View a pinned native reconstruction

1. Open the signed capture, then **Tools → Spectral reconstruction**. Select
   `field / amplitude` and its native index, or choose **Use playhead**.
2. Review the two frequency edges and explicitly acknowledge **Assume this whole
   volume is periodic**. Choose **Compute**. Cancel is enabled while computation
   or display transfer is active, and disabled when no operation can be cancelled.
3. Choose **Original**, **Low**, **Intermediate** or **High**. All four views use
   the same verified native record, geometry and signed display range. The legend
   separately shows pinned native time and the moving ordinary playhead.
4. Move the camera or switch Scientific/Cinematic using the existing controls.
   Drag the panel by its header to make space. **Volume opacity**, **Volume**,
   **Slice**, **Clip volume**, axis and world position control the derived view.
   Blue is negative, white is zero and red is positive; opacity follows magnitude.
5. Use **Symmetric signed range • shared by all views** for an explicit contrast change;
   editing either bound keeps the pair symmetric about zero. Choose
   **Use original symmetric range** to reset. The legend identifies a manual
   range. The initial range can clip reconstructed extrema that exceed the
   original extrema because of cancellation between bands or filter ringing.
   A zero source has an explicitly labeled display fallback of −1 to 1 while
   its true numerical range remains zero. Unsupported float32 display ranges
   are refused with a message.
6. Turn off **Show pinned volume** to inspect the ordinary live source, or close
   the panel to clear the result and release its artifacts. Input values remain
   as a draft when reopening; a fresh computation verifies a new result.

Source probes are unavailable while the reconstructed view is shown; they must
not silently report original values as reconstructed values. The older regional
band-map plane is suspended during this presentation. Ordinary image export
temporarily restores the ordinary source and excludes the derived volume and
legend. Ordinary video workers do not receive this transient result. Capturing
the reconstructed view for review therefore uses an explicitly identified
application screenshot, not ordinary scientific/image export.

## Numerical definition

For a finite float64 source array `q[z,y,x]`, the worker computes a full-domain
real FFT in float64/complex128. Frequency coordinates use each axis's native
spacing independently: `f_axis = k / (N_axis * spacing_axis)`. The radial
frequency is the Euclidean norm of the three frequency coordinates, in cycles
per source-coordinate unit. No wavelength or SI conversion is inferred when
the capture's units are unknown.

The default edges are **0.125** and **0.375** cycles per source-coordinate unit:

| View | Retained radial frequencies |
|---|---|
| Original | Verified original signed field |
| Low | `0 <= f < 0.125`, including DC |
| Intermediate | `0.125 <= f < 0.375` |
| High | `f >= 0.375`, through the sampled frequency lattice |

Edges belong to the band on their right. Each mask multiplies the original
complex coefficients; phase is retained. Radial masks are even, preserving the
conjugate symmetry of a real signal, including the real self-conjugate DC and
Nyquist bins. NumPy's inverse normalization divides by the number of grid cells.
The sum of the three float64 reconstructions therefore recovers the original
field to floating-point roundoff. Disjoint masks also partition mean square
under Parseval's identity. AC variance fractions remove each field's mean;
they differ from total mean-square fractions because DC belongs to Low.

The operator assumes a periodic domain. The form requires an explicit periodic
boundary acknowledgment; the reader cannot infer periodicity from arbitrary
captures. There is no window, mean subtraction, taper or padding. A hard band
edge has a long oscillatory spatial response and can introduce ringing. A
nonperiodic boundary can add a discontinuity and contaminate the reconstruction.
These are operator limitations, not repaired by changing the display range.

Anisotropic spacing is supported. Above the smallest axial Nyquist frequency,
radial shells no longer have complete directional coverage; frequencies still
represent the sampled lattice and are not isotropically complete shells.
The initial implementation refuses nonidentity object transforms, nonfinite
values, channels other than the signed `field / amplitude`, non-float64 sources,
dimensions outside 2–192, or more than 192³ cells. Refusal never substitutes a
coarser scientific computation.

## Scientific and display ownership

The existing owned analysis worker verifies the complete committed source prefix
and selected stored/raw payload before deriving a result. Request revisions,
source identity and publication checks guard cancellation and stale replies.
One request processes one native record. It does not prepare the whole capture,
extend the ordinary prepared timeline or enter the ordinary playback cache.
Fresh high-resolution file stamps guard request/publication/transfer boundaries.
An already displayed result follows ordinary reader polling for later filesystem
changes; this can take about one second. Per-frame checks use the reader's
identity/generation and current target, without launching a file-stat process
on each rendered frame. Changing source, selected field/channel or selection
invalidates the result; a changed external file requires fresh verification.

The result owns four float64 arrays and four float32 display copies in private,
hashed files. Float64 files are numerical authority; the single float32 cast is
display only. The handoff is a bounded internal artifact, not a WVZ1, SWSS,
inspection-state or export format. The viewer validates path ownership, shape,
byte count, finiteness and content hash before uploading one full-resolution RF
texture. The ordinary source arrays remain unchanged.

At 192³, each float64 array is 54 MiB and each RF display is 27 MiB. Four pairs
occupy 324 MiB before small metadata/reservations. The existing 2 GiB shared
analysis-disk quota still applies. A dedicated owned namespace prevents the
ordinary CSV/JSONL result collector from treating these dense files as its own
results. Starting another reconstruction replaces the retained result. Graceful
worker exit removes recognized owned artifacts. Forced termination, including
capture shutdown before a release is processed, can defer reclamation until the
next worker starts and checks the abandoned owner's process identity. Unknown
entries are preserved with refusal.

The computation requests a bounded 1 GiB context, including source decoding and
FFT/inverse workspace reservations. Logical budget accounting and measured
process RSS are different quantities; the evidence reports both. GPU display
uses one 27 MiB RF texture at N192, plus existing renderer resources and any
transient transfer allocation. There is no scientific LOD fallback.

## Interpretation and review

Compare Original, Low, Intermediate and High at the same native time, camera,
extent, clipping, opacity and fixed scalar range. A band displayed with an
independently expanded range may reveal weak structure but no longer represents
equal absolute contrast; record that change explicitly. Opacity, ray integration,
color mapping, clipping and view direction can all change apparent connectivity.
Inspect a feature from multiple angles and in orthogonal slices before treating
its appearance as a volumetric pattern. Neither procedure establishes a physical
filament, particle or material object.

The Model A reference uses a periodic N192 grid of length 32, with spacing 1/6
and frequency step 1/32. The selected 0.125/0.375 split is an exploratory scale
choice. It is not a calibrated universal boundary between physical components.
See [the focused evidence and owner checks](evidence/issue-424/README.md) for
independent numerical comparisons, actual Wavez views, timings and limitations.

Animated reconstructions, GPU FFT, automatic all-frame processing, observer/cone
mapping, optical spectra and changes to capture formats are outside this issue.
