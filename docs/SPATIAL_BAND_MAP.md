# Spectral band map

**Tools → Spectral band map** computes a bounded plane of regional measurements
from verified native scalar samples. **Compute** pins one sample; **Prepare
selected** prepares a small explicit sequence for exact-time replay. Each center uses a complete **3D**
window and real 3D FFT. The plane is an optional derived presentation beside the
ordinary source field. It is not a 2D FFT, a dense spectral volume, a local
wavelength reconstruction, physical model energy or optical light.

This experimental phase follows [regional spatial spectrum](SPATIAL_SPECTRUM.md)
and the [phase-2/3 proposal](research/spectral-135/ARCHITECTURE.md). Source arrays,
WVZ1/SWSS, Scientific/Cinematic settings and conventional field rendering retain
their existing contracts.

## Compute a pinned map

1. Open a capture and choose **Tools → Spectral band map**. Select the field and
   exact channel. The initial channel is `amplitude`; if absent, no channel is
   silently substituted. Another recorded channel can be selected explicitly,
   but its power describes that quantity. An energy-only source cannot recover
   the missing signed amplitude.
2. Choose a native sample index, or **Use playhead** to pin the object's held
   native record. Requested scene time, actual native time and current playhead
   are distinct. Play/seek does not recompute or retime a completed map.
3. Enter **Support** and **First start** in source XYZ sample indices. Select
   the plane's normal axis. Its first-start coordinate is fixed; the other two
   coordinates advance by **Hop** over **Centers** rows and columns. The form
   labels row/column order: the remaining axes in ZYX order. For a Z-normal
   plane, rows are Y and columns are X.
4. Enter the numerical band `[low, high)` in cycles per source-coordinate unit.
   Edges must satisfy `0 ≤ low < high ≤ min(axis Nyquist)`. They refer to actual
   3D DFT frequency-vector magnitudes, not rounded radial-shell centers. Angular
   wavenumbers require the explicit conversion `k = 2πf`.
5. Choose **Compute**. The existing owned analysis worker verifies the pinned
   committed source prefix, decodes the selected native channel once and computes
   windows sequentially. Source hashing and center progress remain visible.
   **Cancel** clears the publication target immediately; no partial map appears.

The form is nonmodal. Drag its header to reposition it while using the viewport
and application controls. Embedded placement stays below the menu bar and inside
the available viewport; resizing refits the form. Native windows use the desktop
window manager's drag behavior. Its moved position is retained during the session.

**Cancel** is enabled while this form owns an active request and disabled when
idle or after completion. A completed result has nothing left to cancel; use
**Show map** to hide its presentation. Closing and reopening on the same source
retains the inputs, presentation choices and completed pinned result without
starting another calculation. This matches Wavez's retained tool forms. Changing
source still invalidates the result under the source-binding rules below.

Support is never automatically shortened to fit a small capture or reduce cost.
The initial support is 128³. The default hop is 32 samples, with a bounded grid
including an unavailable edge ring. On the signed 192³ Model A reference, the
Z-normal defaults are fixed start Z=32, first starts Y=X=−32, count 5×5 and hop
32×32. Nine of the 25 requested windows have complete support. Center indices
are `start + (support−1)/2`, so this even support produces half-index centers:
Z=95.5 and valid X/Y centers 63.5, 95.5 and 127.5.

The default band is `[0.05, 0.15)`. At Model A spacing 1/6, a 128³ window has
`L = 21⅓` and nominal `Δf = 0.046875` on each axis. The low edge spans only about
1.067 cycles, so this default remains **UNRESOLVED / insufficient support**.
It is an exploratory band-power measurement, not a resolved initial wavelength.
Reduce center count or increase hop for a smaller workload; reducing support
changes the scientific measurement and its resolving limits.

## Prepare and replay selected native records

For `field / amplitude`, enter **First**, **Last** and **Stride** under
**Selected native indices**. The endpoints are inclusive indices into that
field's records, not viewer frames or a resampled clock. At most eight records
and 64 centers per record are admitted. Review the listed native times, number
of windows, estimated worker RAM and disk reservation before choosing
**Prepare selected**. The worker independently checks source descriptors,
memory, reply size and disk quotas; an estimate is not a promise of process RSS.
Missing signed amplitude is refused rather than replaced by energy density.

One source verification serves the sequence, and each native channel is decoded
once. All selected maps must finish before the sequence is published. Cancel,
failure or changed inputs publish no partial sequence. The accepted Hann kernel,
normalization, exact band edges and unavailable-support rules are unchanged.

With **Replay prepared maps at exact native times** enabled, the plane appears
only when the playback time exactly equals a selected native time and the
ordinary scene has committed that same time. At intermediate times, unselected
native records or while the ordinary scene is preparing, the plane hides and
the legend reports unavailable. There is no temporal interpolation, tolerance
window or silently held spectral map. Continuous playback may pass between all
selected times; seek to an exact record to inspect it. Reverse and looping use
the same rule. Disabling replay hides the sequence; **Compute** remains the
separate single-sample pinned workflow.

Replay reads bounded prepared results in viewer memory. It performs no source
hashing, decoding, FFT or disk-cache lookup on a playhead update. It never gates
ordinary playback or extends the teal scene-ready band. Preparation still yields
to ordinary playback underflow through the existing worker pressure handling.

Each map retains its own numerical color range. A color in one native map must
not be compared quantitatively with the same color in another; use the range
and center values. The legend distinguishes map time, playback time, coverage,
cache/preparation state, source provenance and unresolved support. Show map,
Show source field, palette, opacity, presets and navigation remain independent
presentation controls.

## Owned cache and restart behavior

Prepared sequences use the existing transactional analysis result store under
the private analysis-worker registry's `spectral-cache/results` namespace.
Source development uses `.wavez-cache/analysis-workers`; packaged viewing uses
the application's user-data `analysis-workers` directory. This cache is derived,
disposable application data, never part of a WVZ1 capture or scientific export.

Reuse requires the exact selected set and parameters. Overlapping selections
are not assembled from separately cached subsets. The binding includes verified
committed extent/prefix hash, native record/sequence/exact time, object/channel,
dtype and full geometry, grid/support, exact band, units, Hann/normalization and
algorithm/implementation versions. A matching path or UUID alone cannot hit.
The result container and every artifact must pass hash and spectral-schema
validation. Display choices are not scientific cache parameters.

The cache is limited to eight complete sequences and 64 MiB, within the existing
shared 2 GiB / 8192-file analysis quota and free-disk reserve. Each new sequence
reserves 2 MiB. Eviction affects owned derived entries only; unknown files and
links are preserved with refusal. Partial transactions and corrupt known cache
entries cannot become prepared maps. Atomic publication means a cancelled
sequence cannot appear complete after restarting.

Closing and reopening the form retains the session's completed sequence.
Closing or switching the capture, source append/replacement/truncation, changed
parameters or selection revision clears its publication target. Existing Close
File behavior requires cancelling active analysis and waiting for acknowledgement.
Sequence preparation/publication also compares the reader's source stamp with a
fresh file identity before the normal polling interval elapses. A source without
a usable high-resolution file stamp is refused for sequence replay; this path
is validated on the documented Linux local filesystem environment.
After reopening a capture or restarting the app, enter the same parameters and
choose **Prepare selected** to request verified reuse. A new worker independently
verifies the source again before loading durable results; a warm worker may use
its existing identity-checked verification memo. Cached values do not authorize
automatic whole-capture preprocessing or restoration of a stale overlay.
Per-map timings retained in a cache hit describe its original calculation;
current verification/lookup/round-trip costs are reported separately.

## Numerical meaning and unavailable data

The source channel is converted to float64. The periodic separable Hann window,
weighted mean removal and real-FFT folding follow the regional operation:

```text
w = product_i (0.5 - 0.5*cos(2*pi*n_i/N_i))
mu = sum(w*q) / sum(w)
F = unscaled_DFT(w*(q-mu))
band_power = sum_{low <= |f| < high} multiplicity*abs(F)^2 / (N*sum(w^2))
```

`N` is the total number of samples in the 3D window. Real-FFT interior
positive-frequency planes on the last array axis have multiplicity two; DC and
an even-length Nyquist plane have multiplicity one. All-frequency power equals
the **w²-weighted mean-square residual**, within floating-point tolerance.
Band power has squared channel units; it is not Hamiltonian energy. It does not
retain a unique local wavelength, propagation direction or phase.
Summing displayed regional radial bins at these same edges is not an exact
band oracle: an aggregated shell can straddle an edge. The underlying window,
mean removal, folding and normalization are shared with the regional operation.

The source spacing is XYZ, array shape/support is ZYX in the private numerical
contract, and the UI explicitly converts between them. `L_i = N_i*spacing_i`,
`Δf_i = 1/L_i`, and `low*L_i` reports low-edge cycles. Fewer than two cycles on
any axis is insufficient support. Passing that heuristic is not a resolution
guarantee: finite support, Hann broadening, leakage and arbitrary direction remain.
Unknown coordinate/channel units are explicitly unknown. There is no conversion
to nanometres or inferred physical calibration.

A requested window outside the original source, or containing nonfinite source
samples, has **no numerical power value**. Such centers carry a status and null
power; they are not assigned zero, wrapped, padded or partially filled. Numerical
range failures are also unavailable. A map with no available centers is allowed
as a coverage diagnostic: its legend states that the range is unavailable and
shows no quantitative gradient. Unsupported source geometry and malformed
requests fail the whole operation.

**Details and numerical data** exposes the complete pinned path, committed byte
extent, SHA-256, native record, source geometry, grid, support, exact band edges,
source/calculation dtypes, mean-removal and normalization provenance, warnings,
and per-center numerical values/status. Compact legend/support readouts are
rounded for display; the detailed numerical table retains full precision.

## Viewport presentation and source reference

The plane spans the source's first-to-last sample centers along its two axes.
Its normal coordinate is the fixed window center, including the half-index shift
for even support. Numerical `center_xyz` coordinates are data-local;
`center_world_xyz` and the viewport add the source's accepted translation exactly
once. Identity linear transforms and translation are supported; rotation, scale
and shear remain refused by the numerical operation.

Dots mark measured centers. Crosses identify requested unavailable centers;
hatching marks unavailable or unrequested regions, including source edges without
complete windows. Color tiles use the nearest computed-center address. **They
are presentation between centers, not additional measurements or a continuous
reconstruction.** The numerical center values remain authoritative.

**Show map**, **Map opacity** and **Palette** affect presentation only and do not
rerun analysis. The legend reports the numerical range, band, units, measured
coverage, support warning and pinned native time. Each request uses its own
available-center minimum/maximum for display scaling; colors from separate maps
are not a common calibrated scale. Equal-valued maps use one palette midpoint.
All-unavailable maps retain a coverage mask without a numerical color scale.
The UI gradient converts the shader's linear-RGB palette to sRGB at each ramp
sample. It is a palette reference before opacity, scene compositing and 3D tone
mapping. The ordinary viewport's ACES or explicitly loaded tone mapper can
change the displayed plane colors; the UI gradient does not reproduce that
scene transform. The numerical legend and center table remain authoritative.

**Show source field** operates the existing source-visibility control, including
its ordinary one-volume guard. It does not change source channel, colormap or
Scientific/Cinematic settings. Leave the source visible for comparison or hide
it explicitly to inspect the derived plane. The plane is a depth-tested,
transparent, unshaded mesh, so normal scene occlusion/compositing can affect its
appearance. Camera orbit and free movement remain available.

The numerical array stays float64 on the CPU. The GPU receives only a bounded
RF float32 texture of normalized display values, with an embedded unavailable
sentinel; it never supplies scientific values back to analysis. Before making
float32 geometry, the viewer checks each plane corner and measured world center
for finite conversion and no more than one quarter of a source spacing of
coordinate error. Unsupported viewport precision refuses presentation instead
of publishing an overflowed or collapsed plane.

The source reader, ordinary volume renderer, playback cache and prepared timeline
do not receive spectral map entries. Ordinary source visibility changes still
have their usual playback/preparation consequences.

## Ownership, resource limits and export

At most 64 requested centers are admitted. Each support axis requires 4–256
samples, with no more than 192³ samples per window. Windows are processed
sequentially, sharing one verified source and one selected-channel decode per
native record; there is no per-center source verification/decode or simultaneous
FFT stack. Selected-time preparation uses the bounded owned cache above, never
automatic all-time preprocessing. The existing worker memory budget and
physical-memory headroom remain authoritative. Source-channel decode can exceed
the budget even when individual windows are small. The viewer does not silently
reduce scientific support after admission failure.

The map shares the existing analysis worker with Spatial spectrum and other
analysis tools. Active spectral work cannot be replaced by a competing background
request; scoped progress/errors/results reach their owning form. Unrelated
Temporal Cancel/Remove and matched/state actions do not cancel a spectral job.
Cancellation checks run between bounded calculations; a native FFT is not
interruptible inside its library call, and the existing cancellation grace can
terminate an unresponsive worker.

Source replacement/append detection, source or parameter edits, selection
revision, supersession and source close invalidate publication and remove the
old map. A completed **Compute** map stays visibly pinned while playback advances;
prepared-sequence replay follows the exact-time rule above. Closing
the form cancels pending work; a completed map remains visible with its pinned
legend until **Show map** is disabled, its inputs change or the source closes.
Existing **Close File** refusal while analysis is active remains: cancel, wait
for acknowledgement, then close.

**The map and its legend are excluded from ordinary images, inspection images
and offline/video renders.** Viewport image capture temporarily suspends both;
inspection/offline guards also hide them before drawing. Neither map requests nor
presentation settings enter saved inspection/view recipes. Native evidence
screenshots of the interactive viewer may show them, but ordinary scientific
image/video output preserves its established composition.

The plane's logical GPU payload is one RF value per requested center plus six
vertices/UV pairs (for example 220 bytes for a 5×5 grid). Masking is encoded in
that same texture and palettes are analytic shader colors. This estimate excludes
driver/renderer overhead and the separate UI legend gradient. It is not a total
VRAM or process-RSS claim. Cold verification, warm batches, RSS, viewport timing
and real GPU measurements belong to the issue's focused validation evidence.
There is no GPU FFT, new dependency, capture/export format change, release or
claim of real-time all-frame spectral playback.
