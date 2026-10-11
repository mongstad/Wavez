# Field slice interpolation

Issue #374 proposes **v0.1.0.99** on accepted `4737019` / v0.1.0.98
(owner-merged PR #376). Owner acceptance is pending. Forward+ Vulkan is the
sole supported renderer. The historical [#360 measurements](FIELD_FILTERING_PRECISION_RESULTS.md)
remain unchanged; this is the focused product candidate they recommended.

## Behavior and scientific boundary

`viewer/layers/slice.gdshader` explicitly fetches the eight neighboring RF
preview texels and interpolates their finite values in float32. Its existing
world-to-grid and normalized UV expression remain unchanged. The sampler uses
the actual texture dimensions, clamps to the texel endpoints, and retains the
same node/cell physical bounds, transform and CPU-decimated preview LOD. RF
textures still have no mipmaps. Color ranges, LUTs, logarithmic guards, opaque
slice rendering and slice placement retain their existing paths.

This improves finite-neighborhood display interpolation. It does not recover
precision lost during float32 upload or preview decimation. Stored WVZ1 arrays,
sample clocks, units, CPU source probes and scientific Analysis are unchanged.
Display colors are still presentation, rather than authoritative sample readouts.
`volume.gdshader`, field preparation/upload and playback/cache code are unchanged.
Volumes continue using their existing hardware sampler.

## Deliberate NaN/Inf policy

All eight fetched corners are checked **before** explicit arithmetic, including
corners with exactly zero mathematical weight. If any is NaN, +Inf or -Inf, the
shader uses the existing `texture(field_texture, uv).r` sample at the same UV.
The existing fragment rule discards a nonfinite result. This retains the tested
hardware presentation footprint; it does not fill, replace, average away or
renormalize missing values. Finite values obtained in these neighborhoods retain
hardware filtering precision and device-dependent behavior.

The source probe keeps its stronger rule: any nonfinite corner makes the probe
unavailable, including zero-weight corners. An unavailable source probe can
therefore coexist with a visible slice pixel. These are separate existing
contracts, and the display pixel is not evidence of a valid scientific probe.
Out-of-domain probes remain unavailable. A missing channel refuses upload and
releases the stale slice; it cannot become an invented zero-valued field.

On the tested GPU, both original 63-point #360 controls retain **58 finite outputs**:
NaN has five NaN outputs, and Inf has five Inf outputs, matching baseline.
The production candidate avoids the naive sampler's reduction to 39 finite outputs.
Each additional 144-point exact-zero-weight control (NaN, +Inf, -Inf) retains
140 finite and four invalid outputs. Hardware and candidate encoded bytes match
in every invalid fetch neighborhood. Three real WVZ1 NaN/Inf slice images are
also byte-identical, and original nonfinite source bytes/probe semantics pass.
This preserves this device's behavior; it is not a portable nonfinite arithmetic
guarantee or certification of other drivers.

## Scientific accuracy

The retained #360 captures and original thresholds were reused without alteration.
The linear fixture is `v=0.25+0.3*x+0.1*y+0.12*z`, with a 1.5×1×0.8 m
node box, 17×13×9 samples, a 256×192 orthographic viewport of height 2 m,
slice offset 0.037 m and RGB8 gray LUT. The narrow range is [0.254,0.256].
The independent CPU image oracle retains the **0.02 maximum RGB error** limit.

| Slice case | Baseline maximum RGB error | Candidate maximum RGB error | Candidate |
| --- | ---: | ---: | --- |
| Node | 0.063087 | 0.000396 | PASS |
| Cell | 0.063087 | 0.000396 | PASS |
| Rotation / anisotropic scale / translation | 0.052370 | 0.001389 | PASS |
| Budget-reduced LOD2 | 0.097697 | 0.000396 | PASS |

All four baseline failures reproduce. Candidate wide [-1,3] slices pass the
original **0.012** limit (maximum about 0.002380). Positive log mapping and the
nonpositive-source log refusal also pass. Narrow ranges intentionally amplify
the interpolation difference; this is not a claim that every field looks different.

The exact production sampler is additionally exercised through a calibrated
RGB24 scalar observable over [-8,8]. The original #354 probes, unequal-axis
irregular/smooth grids, constants, centers and clamped boundaries are reused:
**7,703 scalar points**, including the nonfinite controls. The maximum candidate
error in tested all-finite neighborhoods is **1.879e-6**, including encoding,
against the unchanged **0.0002** scalar limit. Calibration passes **2e-6**.
Original typed source bytes and source probes pass **2e-6**, including held
sample transitions; captures are unchanged. No tolerance was relaxed.

## Performance and responsiveness

Measured on Linux, Godot 4.7.2 `ed1daf0bf`, Forward+ Vulkan 1.4.351,
RTX 3070 Ti 8 GB / NVIDIA 615.71.09, Ryzen 7 5800X. GPU clocks were not locked.
Baseline and candidate use identical captures, slice positions, camera, range
and viewport; only the slice shader differs. No Compatibility work was performed.

### Slice GPU component

Retained 256³ and 384³ RF captures use 64 and 216 MiB of field storage.
True 1920×1080 and 3840×2160 SubViewports use three paired, alternating-order
repetitions with 24 warmup and 60 measured frames per variant: **1,440 frames**.
All have a visible draw and stable nonblack, matching center pixels. No workload
group or individual frame was excluded. Godot viewport GPU timestamps measure
the slice render component; synchronous image readbacks are recorded separately
and excluded from GPU time. Their wall time makes this collection unsuitable
for claiming viewer FPS.

| Field / viewport | Hardware GPU ms, repetition medians | Candidate GPU ms, repetition medians |
| --- | --- | --- |
| 256³ / 1080p | 0.122, 0.122, 0.121 | 0.139, 0.139, 0.138 |
| 384³ / 1080p | 1.390, 0.209, 0.211 | 0.230, 0.229, 0.232 |
| 256³ / 4K | 0.433, 1.359, 0.974 | 0.492, 0.915, 1.525 |
| 384³ / 4K | 1.414, 0.897, 0.885 | 1.018, 0.959, 0.488 |

At 256³/1080p the increase is consistently about **0.017 ms / 14%**.
The aggregate 384³/1080p medians increase 0.211→0.230 ms; its first baseline
repetition is much slower. Larger cases vary enough that **a stable 4K cost ratio
is not established**. In particular, the 256³/4K aggregate median decrease is
not evidence of a speedup. All values and readback costs remain in the raw report.
The candidate does not meet #360's old blanket +10% shader-cost gate in every
slice workload; #374 instead asks whether this slice-specific accuracy gain has
a meaningful effect on actual viewer responsiveness. Volume costs were not rerun.

### Actual Wavez viewer

The full native **1920×1080** viewer, including its UI, real async preparation/
playback and normal render pacing, runs at a 60 FPS cap. Three paired repetitions
exercise 120 steering frames on the retained 64³ and 384³ fields, plus complete
four-sample 64³ playback at 0.1× (0→0.375 recorded seconds in about 3.75 wall seconds).
Steering calls the actual camera callback with identical scripted movements;
it does not establish physical input feel. **2,796 drawn frames**, all cases
complete, all four playback sources presented, zero buffering frames/errors.

| Viewer workload | Hardware frame median / p95 ms | Candidate frame median / p95 ms | Measured mean-draw FPS, hardware → candidate |
| --- | ---: | ---: | ---: |
| 64³ navigation | 16.627 / 17.330 | 16.646 / 17.294 | 60.05 → 60.03 |
| 64³ playback | 15.450 / 20.758 | 15.670 / 20.741 | 60.07 → 60.05 |
| 384³ navigation | 16.642 / 17.408 | 16.654 / 17.593 | 60.08 → 60.05 |

FPS uses complete spacings between measured draws; the first partial
warmup-to-draw interval in each run cannot represent a full frame. All raw
frames remain in the report and frame-time distributions. This correction
avoids a small startup bias above the 60 FPS cap.

A separate ordinary **1×** trial also completes every four-sample playback:
three paired repetitions, **36 checks PASS**, 143 total draws, zero buffering
and all four source samples presented. This short capture takes about
0.365–0.382 wall seconds; it is a completion check rather than a sustained
throughput measurement. The 0.1× setting above extends profiling time for the
same short capture; it is set directly by the harness.

The predeclared material gate is a +10% median or p95 increase **and** at least
1 ms absolute increase across the three-repetition workload, added buffering or
failure to complete. Each workload passes. One playback pair's median is
14.020→15.652 ms (+11.6% / 1.632 ms), while the other two increase by 0.424 and
0.297 ms; p95, aggregate statistics, draw rate and completion do not indicate
a repeated degradation. The raw paired measurements are retained for owner review.
These short capped trials detect no meaningful user-visible regression. They do
not establish uncapped throughput, maximum admission stress, long-session latency
or full-viewer 4K responsiveness. The 4K evidence above is the slice component.

## Validation, reproduction and retained attempts

`tools/validate_slice_interpolation.py` creates only small focused fixtures by
default, or accepts read-only retained #360 inputs. It uses
`viewer/layers/test_slice_interpolation.gd`, independent NumPy image/scalar
oracles and the production sampler. Generated payloads, logs, images, packages
and profiles stay external.

Source with retained fixtures: **185 native checks PASS**, plus image/scalar/
nonfinite assessments, unchanged source hashes and clean Vulkan exit/log.
Linux release-template validation with fresh focused fixtures: **165 native checks
PASS**, the same oracle gates, unchanged sources and clean exit/log. Its temporary
entry changes only how validation starts; production scripts/shaders are identical.
All **32 corresponding production image PNGs** match source byte for byte.
The normal standalone Linux package also builds; launch with the saved narrow-slice
preset exits cleanly after 60 process frames. This startup smoke check is separate
from the release-template behavioral run. No product test hooks or external runtimes are bundled.

From the repository root, with external Python/NumPy/Pillow and Godot:

```sh
python tools/validate_slice_interpolation.py --godot /path/to/godot --output-dir /external/new-source-run
python tools/validate_slice_interpolation.py --godot /path/to/godot --output-dir /external/new-package-run --export
```

For the exact retained comparison add
`--baseline-ref 4737019 --fixtures-dir /external/issue-360-filtering/production-inputs
--scalars-dir /external/issue-360-filtering/fixtures`. The original thresholds
are encoded in the validator. `assessment.json` separates the expected baseline
failures from candidate acceptance. The default control uses hardware sampling
at the same UV, making the focused regression reproducible after this PR merges.

Current external evidence root:
`/home/Nozba/Codex/Wavez/Wavez-Benchmarks/issue-374-slices/`:

- `PLAN.md`, `used-input-hashes.json`, `baseline/` and `shaders/` preserve setup.
- `source-retained-final/`, `package-review/`, `production-package/` contain final checks.
- `component-01/`, `viewer-03/`, `viewer-normal-rate-final/`, `performance-summary.json` contain raw timings,
  paired summaries and actual viewer images. Each profile retains `harness.gd`.
- Earlier image/source runs pass their then-smaller scope. `viewer-01` is
  inconclusive: demand-driven paused rendering left its draw wait pending.
  `viewer-02` stops two playback collections at the requested endpoint before
  the final source commit; both variants are affected. Both attempts are excluded
  from the final performance conclusion. The corrected harness waits for committed
  endpoint/source presentation. No product workaround was added.
- The initial ordinary-rate harness transformation omits a loop colon and fails
  parsing before measurement. Its corrected run is `viewer-normal-rate-final`.
  `narrow-comparison.png` displays the four baseline/candidate image pairs and
  their absolute byte differences.
- The initial sandboxed editor import cannot save external editor settings/listen;
  the authorized writable-profile import succeeds. Cached unrelated UID warnings
  are retained separately; the new test's UID is committed.

Remaining limits: other GPUs/drivers/platforms, physical input, physical 4K UI/
mixed DPI, long sessions, uncapped contention, arbitrary LUTs/extreme/subnormal
values, shear/large coordinates and broader scientific workloads are unverified.
The hardware nonfinite policy intentionally retains its previous limitations.
No solver campaign, engine fork, new UI mode or volume rewrite was needed.

## Owner review and rollback

1. Review the isolated slice shader diff and this report; confirm candidate BUILD
   remains accepted `main.BUILD + 1` before merge.
2. Run the focused source/package commands. Confirm all four narrow candidate
   rows pass 0.02 and baseline rows still expose the known failures.
3. Inspect source/nonfinite scalar and real slice comparisons: preserved bytes,
   matching invalid footprints, conservative probe refusal and missing-channel refusal.
4. In native/standalone Wavez, open a field, enable a slice and disable volume.
   Compare wide and narrow fixed ranges at the same camera/plane, then navigate,
   play/seek and inspect the original source probe; check a reduced preview too.
5. Assess the cost tables and raw paired timings, including their variation and
   short-trial limits. Physical navigation feel and heavier/longer workflows remain
   owner checks. Accept or request a scoped revision; no automatic merge/release.

Rollback is local: restore the prior single `texture(field_texture,uv).r`
expression and remove `slice_value`, or revert this dedicated PR. No capture,
recipe, data migration, runtime setting or renderer-policy change needs reversal.
