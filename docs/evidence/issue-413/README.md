# Issue #413 — regional spatial spectrum review

Candidate **v0.1.0.115**, pending owner review. Issue #413 was the top and only
Ready item in Wavez Development when selected. Work uses its existing assigned
branch, `413-feat-spectral-implement-source-verified-regional-spatial-spectrum-analysis`,
from accepted main `6867d21746190537ed67379c1a44c87b1708f4e1` (PR #412,
v0.1.0.114). The research predecessor is present in main. No second branch,
release, tag, merge, issue closure or Project transition is part of this work.

## Implemented boundary

**Tools → Spatial spectrum** computes one complete grid-aligned region of one
verified scalar source channel at a pinned native sample. It uses the existing
owned Python analysis process, SourceSnapshot verification, memory accounting,
cancellation and revision-gated IPC. NumPy supplies the CPU real FFT. A periodic
Hann window, weighted mean removal, conjugate-half multiplicity and Parseval
normalization produce bounded radial shell sums. There is no persistent spectral
cache, dense transform transfer, playback-cache entry or timeline coverage.

The form shows native versus requested/playhead time, integer XYZ region,
support and frequency step, a numerical plot, and a sample-center region wire.
Details exposes full source path/extent/SHA-256, exact geometry, source/calculation
dtype, mean/detrending, normalization and numerical bins. Source/selection/ROI
changes invalidate publication; moving the playhead leaves a completed result
pinned. Startup failures and progress/results remain scoped to the owning form.
Temporal, matched-view and analysis-state actions cannot steal its active job.
Ordinary image output excludes the indicator. Scientific/Cinematic visual state
and prepared-timeline coverage remain unchanged in focused checks.

The [current workflow and numerical contract](../../SPATIAL_SPECTRUM.md) describes
the supported input, bounds and interpretation. WVZ1/SWSS, exporters, scalar
rendering, scientific capture sources and #135 historical evidence are unchanged.

## Validation and evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Final numerical/source/worker tests | 17 passed, no failures/errors/skips | [backend-final.json](backend-final.json) |
| Actual signed Model A reference | Nine central 32³/64³/128³ regions at native t=0,20,40 match accepted #135 mean, radial bins and total power | [backend-model-a.json](backend-model-a.json) |
| Connected Python source, memo, worker and version tests | 40 passed in 3.269 s | Command below; observed terminal result |
| Existing native source/protocol boundary | 163 checks, zero failures | [foundation.json](foundation.json) |
| Forward+ source UI, including Model A | 50 checks, zero failures | [source-ui.json](source-ui.json) |
| Temporary Linux package, final synthetic UI/worker integration | 48 checks, zero failures | [package-ui.json](package-ui.json) |
| Packaged actual Model A and full details | 50 checks, zero failures | [package-model-a.json](package-model-a.json) |
| Final source import, UID/resource and whitespace review | PASS | [source manifest](source-manifest.json), retained import log |

The independent oracle explicitly evaluates the full complex DFT using
exponentials and reduces its full frequency cube independently. Tests cover
single/mixed/oblique modes, phase interference, odd/even real-FFT folding,
Parseval, anisotropic axis order, complete edge ROIs, nonfinite inputs, missing
amplitude, exact native time, units/transforms, unsupported frequencies, numeric
range, source mutation/truncation/checksum, combined memory admission, cancellation,
supersession and worker close. The final 17-test report adds refusal cases after
the earlier 16-test/full-reference run; valid numerical arithmetic did not change.
Maximum Model A total-power relative difference from #135 is **1.91e-16**.

Native checks exercise real keyboard activation and plot selection, source/hash
and geometry publication checks, tiny positive plot scales, startup RAM refusal,
explicit unavailable-Python fallback, stale replies and selection revisions,
cancel/close/source switching, temporal/matched/durable ownership, Scientific and
Cinematic state, playback and camera movement, unchanged timeline coverage and
pixel-identical ordinary image output with/without the spectral UI. Dark, Light,
normal and compact layouts were inspected. The package stages Wavez-owned Python
sources and uses externally installed Godot templates and Python/NumPy. It is a
temporary review harness, not a published distribution.

Environment: Linux; Godot 4.7.2 stable; Forward+ Vulkan 1.4.351; NVIDIA RTX 3070 Ti;
Python 3.14.8; NumPy 2.4.3. Headless checks provide CPU/state evidence only.
The validation scope follows the numerical subsystem and its immediate worker,
source, UI, image and package boundaries; no unrelated full-suite run was used.

## Measured costs and limits

The reference is the external signed float64 N192 `amplitude` capture identified
by SHA-256 `1af76f2e5e0642808f33119168d8f5e0c7cc847599e414790923c2c3585e3d7d`,
committed extent **6,965,545,431 bytes**, UUID
`5848557b4ddd4d56b48e62f9f5700b23`. Raw captures and array copies are not committed.

- First whole-prefix verification/open: **3.424 s**; later memo opens **21–25 ms**.
  The first measurement is a cold verification memo, not a guaranteed cold disk.
- Selected 54 MiB whole-channel decode: **87.5–96.9 ms**. At 128³, Hann/FFT/power
  calculation: **31.7–39.2 ms**; radial reduction: **9.70–10.39 ms**.
- Warm 128³ worker roundtrip: **177.6–192.4 ms**, including compute and polling;
  this is not isolated IPC latency. Logical peak charge: **309.84 MiB** against
  the 512 MiB budget; measured worker RSS high-water mark: **158.64 MiB**. These
  do not represent total viewer/GPU/system memory.
- Forward+ source request callback: **11.3 ms**; compact plot-array publication:
  **0.195 ms**; warm end-to-end UI publication: **192.5 ms** in the measured pass.
  First Model A native UI publication was about **3.8 s**. Later review runs and
  package timings are retained in their JSON, without claiming repeatable latency.
- Pressure-paused worker cancellation: **21.34 ms**; owner close: **31.45 ms**.
  Native UI cancel callback was **0.285 ms**, with acknowledgement **45.8 ms** in
  the measured pass. Cancellation inside a single NumPy FFT was not measured;
  checks surround the bounded FFT and the existing two-second grace can terminate
  an unresponsive worker.

At spacing 1/6, 32³ and 64³ regions fail the two-cycle heuristic for f=0.1;
128³ is only a candidate. For the more demanding k=0.5 target, even 128³ contains
only **1.69765 cycles** per axis and remains explicitly insufficient. No dominant
wavelength is inferred. The runtime correctly labels the Model A legacy unit
metadata **unknown**; the oracle validator uses explicit dimensionless overrides
based on the accepted audit. No physical conversion is inferred.

## Corrections and unverified scope

[Early attempts](early-attempts.json) preserve the initial UI failures. A real
publication bug compared integer ROI arrays with JSON float arrays by Variant
type; exact numeric comparison fixed it. A subsequent harness assertion repeated
that type mistake, and its report aliased a source dictionary later cleared by
reset; both harness defects were corrected. That interrupted run was terminated
after recording its exception. Numerical tests caught a capped radial-shell
rounding edge and cell-origin interpretation during development; both were
corrected before final numerical evidence. Review also corrected ownership
cancellation/startup routing and an artificial plot scale floor.

The first Forward+ run passed its state checks but screenshot review found
[compact clipping](early-compact-clipping.png) and excessive text above the plot.
The final form enforces a 520 px minimum width, retains footer actions when short,
and puts complete provenance in expandable Details. Later source and package
screenshots show the corrected form. The expected `python3: No such file` line
in native logs is the deliberate isolated fallback test, not a failed dependency
in the validated normal workflow. Initial restricted editor attempts logged
sandbox TCP-listener errors; the final authorized import passed without errors.

Not run or claimed: every Model A sample/ROI; a new solver simulation; the
energy-only 320³ capture; Windows/macOS or other GPUs; high-DPI/window-manager
matrices; dense spectral rendering; optical calibration; GPU FFT; all-frame
analysis; complete video/analysis export regression suites. The output is a
regional radial diagnostic and loses directional/phase information. Rotated,
scaled or sheared source transforms are refused. Whole-channel decoding can
refuse large sources even when their requested ROI is small.

## Reproduction

From the repository root, with external Godot and the optional existing signed
Model A path supplied explicitly:

```sh
python -m unittest tests.test_analysis_worker tests.test_analysis_source tests.test_analysis_memo tests.test_application_version
python tools/validate_spatial_spectrum.py --output /tmp/spectrum-numerical.json --capture /path/to/signed-model-a.wvz
python tools/validate_analysis_foundation.py --godot /path/to/godot --output-dir /tmp/spectrum-foundation
python tools/validate_spatial_spectrum_ui.py --godot /path/to/godot --output-dir /tmp/spectrum-ui --capture /path/to/signed-model-a.wvz
python tools/validate_spatial_spectrum_ui.py --godot /path/to/godot --output-dir /tmp/spectrum-package --package
```

Output directories must be new. Omit `--capture` for generated fixtures only.
`--headless` is an optional source CPU/state check, not graphical acceptance.

## Owner verification and recommendation

1. Confirm Help → About shows candidate v0.1.0.115 and reconcile BUILD with current
   accepted main before merge. Open the signed N192 reference, then Tools →
   Spatial spectrum; choose `field`, `amplitude`, native index 0.
2. Set XYZ start `(32,32,32)`, Samples `(128,128,128)`, Minimum f
   `0.07957747154594767`. Compute; observe verification progress, source-region
   wire, full identity in Details and **Insufficient support** at about 1.698
   cycles. Confirm the unknown-unit labels and normalization are understandable.
3. Inspect numerical bins by clicking/arrowing through the plot and expanding
   Details. Seek or play: native result time must stay pinned while playhead time
   changes. Try Scientific and Cinematic; ordinary mapping and Bloom remain theirs.
4. Try 32³/64³ regions, another channel and native time. Change ROI during a job,
   cancel, close/reopen the form and switch captures. Old results must not reappear;
   Close File must retain its existing busy refusal until cancellation completes.
5. Check Dark/Light and a short window, source-region placement, camera navigation,
   ordinary image capture and familiar playback. Review the
   [packaged Model A view](model-a-viewport.png), [normal form](dark-dialog.png),
   [compact form](compact-dialog.png) and [full Details](details-dialog.png).

Recommend review of this bounded diagnostic as phase 1. Keep dense maps, spectral
volume rendering, automatic wavelength claims and Human Vision behind separate
research/design authorization. Passing these checks does not establish owner
acceptance or authorize merging or publication.
