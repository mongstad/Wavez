# VOLUME-004 — real-capture volume-defaults review

Issue #13; **Pre-UX3/UX4 — Validation & Maintenance** is the authoritative
milestone, confirmed by the owner. The older suggested UX4 heading in the issue
body does not authorize UX4 implementation. Status: investigation complete,
**pending owner review**. Baseline: `b7757636bad0a3fe06c27ea33d55d3c769199743`.

## Conclusion

The current first view is recognizable, but **useful defaults without immediate
tuning are not demonstrated across the requested cases**. The real layered
capture opens as a small, bright tracer cloud; density-only views reveal central
structure while faint structure is weak. The fixed 0–1 range saturates the
collapsing core. Signed channels are more problematic: the default suppresses
negative values, and a symmetric range produces an almost opaque domain box.

This is a validation finding, not an implementation or owner-acceptance claim.
No default, shader, source data, playback, normalization policy, UI layout or
export behavior was changed. Temporary comparison settings were applied only in
the review harness. Do not adopt them as recommended universal presets.

## Real source and coverage

Read-only source: `VB_FreeCollapse_v0_2/runs_free_collapse_v0_2/`
`S2_S2_phase_free_live_20260911_180247_463248/free_collapse_simscope.ssc`.
The existing source is **1,165,229,241 bytes**, SIMSCP3, with a 128³ float32 solver
field and 100,000 persistent-ID passive tracers. Its metadata explicitly labels
tracers as probes without assigned mass. No simulation was rerun, capture copied
into the repository, exporter altered, or new scientific dataset generated.

[Source metadata/statistics and hashes](evidence/issue-13/source.json) identify
the retained run, source-grid geometry/transform, channel units, channel hashes,
probe oracles and distributions. Whole-capture SHA-256 before/after both runs:
`c1931fdaa27a3a063fca1a7cbc3e5523efe2f840c816261dd48533ec7c259ccb`.

Coverage available in this one real run:

| Requested case | Evidence |
|---|---|
| Dense core + faint surroundings | Density at t=12 (largest recorded maximum) and t=80; distribution and native views |
| Signed fields | `psi_real` and `psi_imag`, including negative and positive samples |
| Non-negative density | `density`, all 11 recorded grids; zero negative/nonfinite values |
| Particle + volume | Initial and late layered views with the recorded tracers |

These are representations of one simulation family, not four independent
scientific datasets. Other located captures were small smoke/example runs of the
same solver; they were inventoried but not counted as independent validation.
Previously documented external benchmark directories were no longer at their
recorded workspace paths.

Field times are **0, 5, 10, 12, 14, 16, 20, 30, 40, 60, 80**; tracers have **161**
samples every **0.5** time unit. Thus the largest recorded field gap is 20 time
units. Existing held-field playback is consistent with this cadence; apparent
stepping alone is not evidence of a render-performance bug. No temporal
interpolation was implemented or benchmarked here.

## Method and integrity

`tools/validate_volume_defaults.py` reads all 11 source grids with SceneReader,
computes finite distributions, per-channel hashes and independent source-grid
probe values, then launches `viewer/layers/review_volume_defaults.gd`.
The native harness uses the production viewer, keeps the automatically framed
camera and disables realtime motion. The inspector/legend are hidden for clean
viewport comparisons; these are not full-UI acceptance screenshots.

Sixteen cases per backend cover the opening configuration, Scientific/Cinematic,
layered/volume-only views, default/full-source/p99 range, opacity 0.25/1,
ray step 0.25/0.5/1, and both signed channels with default/symmetric ranges.
The starting volume settings are channel density, viridis, range 0–1,
opacity 0.25/world-unit, ray step 0.5 world-unit. Opening presentation is Cinematic.
Comparisons reset layer settings, so changes do not accumulate between cases.

**81 checks PASS on each backend**: opening, exact recorded sampling, source-array
hashes, source-grid probe agreement (absolute tolerance 1e-7), correct timestamps,
full-grid LOD=1, and successful PNG creation. Both complete capture hashes are
unchanged. Import and native logs are clean. These checks establish integrity
and successful rendering, not that the visuals satisfy the usability criterion.

## Findings

1. **The fixed range is not stable across the real density history.** The maximum
   grows from 0.422494 at t=0 to 6.426058 at t=12, then 1.650049 at t=80.
   At t=12, 0.349% of all grid values exceed 1; these include scientifically
   relevant core values despite the small domain-wide percentage. The
   [default core](evidence/issue-13/peak-default.png) saturates into a bright disk.
   A [0–6.426058 comparison](evidence/issue-13/peak-source-range.png) restores
   variation but dims the surrounding signal. This is display clipping only;
   numeric probes and stored values remain intact.
2. **Faint-structure visibility trades against saturation.** At t=80, density p90
   is 0.00100144, p99 is 0.104020 and max is 1.650049. The
   [default view](evidence/issue-13/late-default.png) exposes bright central lobes
   but little faint structure. The [p99-range comparison](evidence/issue-13/late-p99-range.png)
   expands the visible footprint while saturating more of the core. Raising
   opacity to 1 brightens/thickens the core without independently controlling
   faint values. Percentiles depend heavily on the mostly empty domain; a global
   p99 policy is not established as a safe default by this example.
3. **Signed color range and opacity are coupled.** At t=80, 50.068% of `psi_real`
   and 49.632% of `psi_imag` values are negative. With lower=0, the shader computes
   `u=clamp((value-lower)/(upper-lower),0,1)`: negative values get zero extinction.
   The [default real-component view](evidence/issue-13/psi_real-default.png) is faint
   and incomplete. Setting ±0.865841 with coolwarm maps zero to u=0.5, producing
   the [opaque-box comparison](evidence/issue-13/psi_real-symmetric.png) on both
   renderers. For a 64-unit near-zero ray at opacity 0.25, the shader's accumulated
   opacity approaches `1-exp(-0.25*0.5*64)`, about 0.9997. This follows directly
   from `viewer/layers/volume.gdshader`; changing colormap alone cannot fix it.
   The same problem occurred for the imaginary component's symmetric range.
4. **Presentation and tracers can dominate the first impression.** The
   [opening view](evidence/issue-13/opening.png) is a bright small cloud against
   the Cinematic background. Scientific removes the bloom/background competition;
   hiding tracers helps distinguish the actual grid volume from passive points.
   Cinematic bloom increases apparent extent but is not evidence of extra source
   density. Framing the entire 64-unit domain keeps the core small. No camera or
   particle defaults were changed.
5. **Ray step is a quality/cost control, not an opacity substitute.** At t=80,
   step 0.25 roughly doubles measured GPU time versus 0.5; step 1 reduces it.
   Broad morphology remains similar at the fixed review scale, but no fine-detail
   convergence study establishes an optimal step. The shader accounts for segment
   length in extinction and imposes a 1024-step cap; no reviewed case changes that
   existing algorithm.

## Performance evidence and limits

Godot 4.7.2, NVIDIA RTX 3070 Ti, 960×640 SubViewport; eight warmup frames followed
by 30 measurements per case. GPU render times are measured through Godot's
viewport instrumentation. Values below are medians in milliseconds:

| t=80 comparison | Forward+ | Compatibility |
|---|---:|---:|
| Scientific volume, step 0.5 | 0.562 | 0.723 |
| Step 0.25 | 1.083 | 1.358 |
| Step 1 | 0.397 | 0.480 |
| Opacity 1 | 0.593 | 0.760 |
| p99 upper range | 0.578 | 0.736 |
| Cinematic volume | 0.873 | 1.033 |

[Forward+ cases](evidence/issue-13/forward.json) and
[Compatibility cases](evidence/issue-13/compatibility.json) retain exact settings,
median/p95 GPU times, CPU times and synchronous sample durations. Frame wall time
was approximately 6.94 ms under display pacing; GPU timings are **not** a promised
playback FPS. First synchronous source transitions include decode/preparation
(e.g. 198/362 ms for peak/late transitions in the Forward+ run); later same-sample
comparisons benefit from caches. These are not equivalent workloads or a
regression benchmark. Cross-backend ordering, clock changes and brief measurement
windows also limit interpretation. No default change was made, so there is no
implementation before/after performance claim.

Not run: independent simulation families, alternative GPUs/OSes, physical 4K,
long-session/interactively buffered playback, broad G0–G4 regression, video export,
isosurface extraction, numerical scientific interpretation or a formal user study.
No known final check failed. A helper preload path was corrected before the first
run; both final native runs completed cleanly. Scientific/Cinematic appearances
are not expected to be pixel-identical across renderers.

## Recommendations for later authorized issues — not implemented

- **#10 / VOLUME-001:** explain opacity per world-unit versus ray step; evaluate
  core/faint-structure comparisons before proposing presets. Avoid a universal
  opacity increase based only on this capture.
- **#11 / VOLUME-002:** review separate signed scalar-to-color and magnitude/other
  explicitly defined scalar-to-opacity semantics. Near-zero space must not become
  opaque merely because the color range is symmetric. Preserve numerical probes
  and disclose any nonlinear display transform.
- **#12 / VOLUME-003:** evaluate signed centering, positive/log eligibility,
  percentile/manual/frozen ranges and clipping disclosure together. Do not silently
  treat a symmetric range or p99 range as a complete transfer-function solution.
- **#14 / UX-IA-001:** make field channel/range scope distinct from particle style
  and viewport preset. Keep signed-channel meaning visible during inspection.
- **#9 / FIELD-001:** this source's 0.5 tracer cadence and up-to-20-unit field gaps
  are useful provenance for later interpolation investigation; retain Hold and
  distinguish reconstructed display from recorded source values.

No later milestone is authorized by these findings. The owner can accept this
validation report while deciding separately whether/how to address its findings.

## Reproduction and manual owner review

Set `CAPTURE` to the existing real run above; use the project Python environment,
a native GPU display, and fresh output directories:

```sh
python tools/validate_volume_defaults.py --godot /path/to/godot --capture "$CAPTURE" --output-dir results/volume-review --renderer forward_plus
python tools/validate_volume_defaults.py --godot /path/to/godot --capture "$CAPTURE" --output-dir results/volume-review-gl --renderer gl_compatibility
```

1. Open the real capture in a fresh viewer. Inspect the initial layered view,
   switch Scientific/Cinematic, and hide/show tracers. Decide whether the density
   structure is distinguishable without tuning or mistaking tracers for field cells.
2. At t=12, inspect density range 0–1, then 0–6.426058. At t=80 compare upper range
   1 versus 0.104020. Confirm the saturation/visibility tradeoff rather than treating
   either candidate as a calibrated brightness scale.
3. At t=80 select `psi_real`: compare 0–1/viridis with ±0.865841/coolwarm.
   Confirm negative values are absent in the first and near-zero domain opacity
   dominates the second. Repeat `psi_imag` with ±1.223627.
4. Restore density range 0–1/viridis/opacity 0.25. Compare ray steps 0.25, 0.5, 1
   at the same camera, then opacity 1 at step 0.5. Check detail at your normal
   display scale and distinguish density shape from bloom.
5. Verify source probes remain unchanged when only display controls change.
   Review the stated coverage limits and decide which findings should inform later
   issues. Acceptance here does not approve or implement new defaults.
