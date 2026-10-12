# Scientific integrity: inspection-path audit (#375)

Audited 2026-10-12 against accepted `68f01ccb45dc3e67b5bfad0a36674a2a512e042b`
(**v0.1.0.102**, owner-merged PR #383); candidate **v0.1.0.103** adds documentation
and three assertions in an existing CPU worker test. Owner review is pending.
Scientific algorithms, shaders, renderer behavior and WVZ1 binary semantics are
unchanged. This is a focused source audit, not GPU certification or a new solver campaign.

Read the [canonical three-layer contract](SCIENTIFIC_ANALYSIS.md#21-hardware-independent-scientific-integrity-boundary)
first: authoritative stored data, declared derived measurements, visual presentation.
**PASS below means the named fixture checks passed**, not every function or input.
**Known limits** describe inspected behavior or retained measurements.
**NOT VERIFIED** means this issue supplies no current end-to-end validation for
that behavior. Historical G4 acceptance is preserved; Selection/Analysis remains
experimental beyond declared fixtures.

## Existing paths and evidence

Code links pin the inspected implementation to accepted `68f01cc`, so later edits
cannot silently change the audit's file/line evidence. Test links refer to current
repository tests; [compact run evidence](evidence/issue-375/summary.json) records
the checks executed for this candidate.

| Existing path / classification | Evidence and exact coverage | Status / limits |
|---|---|---|
| Capture and Python reads — source-data access | [SceneCapture `_add`, scene.py:119–177](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/scene.py#L119-L177) preserves supplied f4/f8/i8/u4 precision, associations and binary f64 time. [SceneReader:233–257](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/scene.py#L233-L257) checks requested payload hashes. [SourceSnapshot:254–308](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/source.py#L254-L308) reads typed immutable arrays under a pinned extent. `test_analysis_source` checks none/zstd byte parity, f8 precision, IDs >2^53, native clocks, corruption and append/replacement refusal. | **PASS**, CPU fixtures. Selected reads do not verify unread channels; format/hash correctness does not prove physical correctness. |
| Native particle/field/mesh decoder — source-data access | [scene_channels.gd:6–49](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/layers/scene_channels.gd#L6-L49) decodes original bytes to typed arrays; legal u4 categories widen exactly to f64, triangles use bounded int32. [scene_reader.gd:273–308](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/layers/scene_reader.gd#L273-L308) validates IDs/topology. `validate_payload_integrity.py` compares source hashes, times, IDs and topology for all three kinds, both codecs; exercises strict/structural corruption and stale publication. | **PASS**, 480 headless checks, 63 strict negative cases. Headless proves CPU transport, not pixels or another GPU. Interactive payload SHA checks remain disabled by policy. |
| Particle/mesh stored-sample inspection and grid-address traces — source-data access | [jobs.py:191 onward](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/jobs.py#L191) pages requested source channels; [selectors.py:370–399](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/selectors.py#L370-L399) resolves exact IDs, sample rows, source faces and grid xyz addresses into original zyx array rows. [native_analysis.py:112–134](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/native_analysis.py#L112-L134) returns direct associated values. `test_selections`, `test_native_analysis` cover row/ID distinctions, grid indexing, association and topology epochs. | **PASS**, named CPU cases. Anonymous rows are sample-local; returning topology cannot revive a face. Current pointer/UI behavior is **NOT VERIFIED** by these tests. |
| Python field probes / mesh barycentric readouts — derived computation | [sampling.py:102–130](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/sampling.py#L102-L130) inverse-affine f64 trilinear sampling; [native_analysis.py:112–134](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/native_analysis.py#L112-L134) labels probes `spatially_interpolated`, vertex channels barycentric, face channels direct. `test_analysis_source`, `test_selections`, `test_native_analysis` provide analytic field/mesh oracles. The existing `test_foundation.gd` worker probe now asserts **13.75**, exact f64 token, `f8`, spatial derivation and native held time **0** at cursor **0.75**. | **PASS**, CPU cases and 163 native worker/protocol assertions. Conservative nonfinite support includes zero-weight corners; boundary half-cells clamp. Interpolation is not an original observation or continuum reconstruction. |
| Tools → Source probe — derived computation from source arrays | [grid_view.gd:85–99](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/layers/grid_view.gd#L85-L99) indexes `data.channels`, never `field_texture`; `world_to_grid` and fractional coordinates use float32 Vector3. [scene_layers.gd:649–688](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/layers/scene_layers.gd#L649-L688) binds prepared object/channel/time and flags stale context. Retained FiPy and #360/#374 reports check original source probes separately from GPU sampling. | **Known limits**, historical probe PASS within declared tolerances. Native UI/coordinate accuracy is **NOT VERIFIED** afresh here. It inherits interactive integrity limits; absent/unprepared channels cannot be probed. See the UI-label risk below. |
| Statistics, population, centroid, area, integral, interval velocity — derived computation | [native_analysis.py:186–255](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/native_analysis.py#L186-L255) records source identity, clocks, request, policies and support. [reductions.py:47–158](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/reductions.py#L47-L158) uses compensated f64 sums/scaled population deviation; exact integer extrema and checked signed128 sum, other integer arithmetic f64. [quadrature.py:27–87](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/quadrature.py#L27-L87) integrates whole cells, node eight-corner means, determinant once. [native_analysis.py:331–347](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/native_analysis.py#L331-L347) differentiates consecutive native endpoints. Named reduction/quadrature/native tests cover cancellation, large integers, invalid support, weights, units, area and velocity. | **PASS**, declared CPU cases. No continuum-exact ROI boundary, inferred mass from tracers, implicit unit conversion or physical event claim. Untested request combinations and real-run Analysis workflows are **NOT VERIFIED**. |
| Numerical result/export — source/derived records, independent of display | [result_store.py:19](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/result_store.py#L19) defines exact identity/time/value tokens, source dtype, units and statuses. [export_results.py:10–64](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/export_results.py#L10-L64) streams full checked CSV/support/provenance, not plot pixels. `test_analysis_export` checks exact IDs/f64 tokens, source preservation, dependencies, quotas and cancellation. | **PASS**, seven CPU export cases. Consumers must import identity text without float conversion. Native export-dialog and standalone package workflows are **NOT VERIFIED** afresh. |
| Picking, overlays, plots, derived surfaces — presentation or explicitly approximate derivation | [picking.py:146–244](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/picking.py#L146-L244) picks from source geometry under a captured camera/visibility policy; marker eligibility deliberately emulates display32. [derived.py:16–81](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/wavez_export/analysis/derived.py#L16-L81) checks artifact provenance, retains approximation/no material identity, requires explicit source-probe conversion for numerical interpretation. [native_plot.gd:1–6](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/analysis/native_plot.gd#L1-L6) is a display-only envelope. `test_derived_selection` covers artifact locality and explicit original-grid probes. | **PASS** only for five derived-selection CPU cases. Current screen picks, occlusion, overlay publication, plot decimation and every artifact/render/UI interaction are **NOT VERIFIED** by #375. A camera-dependent selection can choose different members; compare measurements only for the same saved source-scoped definition. |
| RF previews, slices, volume, mesh/particle pixels — display-only | [field_prepare.gd:21–63](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/layers/field_prepare.gd#L21-L63) constructs bounded f32/LOD previews while retaining original arrays; [scene_layers.gd:234–272](https://github.com/mongstad/Wavez/blob/68f01ccb45dc3e67b5bfad0a36674a2a512e042b/viewer/layers/scene_layers.gd#L234-L272) separates position/scalar times and display sampling. [#360 report](FIELD_FILTERING_PRECISION_RESULTS.md) and [accepted #374 slice contract](FIELD_SLICE_INTERPOLATION.md) delimit measured filtering. | **Known limits**; no fresh pixel/GPU tests here. Finite slices use explicit interpolation; volumes retain hardware sampling and approximate ray integration. Other GPUs/drivers and universal visual equivalence are **NOT VERIFIED**. |

## Reused scientific evidence (historical, not rerun)

| Retained report | What it establishes / what it does not |
|---|---|
| [REBOUND](REBOUND_BENCHMARK_RESULTS.md) | 5,005 arrays and 1,001 native times round-trip exactly; refined independent orbit and conservation checks pass. Initial coarse reference convergence failed and remains recorded. Interpolated unsaved positions are display estimates, not new solver states. |
| [PySPH](PYSPH_BENCHMARK_RESULTS.md) | 808 arrays / 101 times preserve dtype/value/time; analytic translation/free-fall, mass and bounded dam-break checks pass. The nonlinear dam-break has no independent solver/experimental certification. |
| [FiPy](FIPY_BENCHMARK_RESULTS.md) | 21 f64 cell-centered fields/times preserve source values; analytic/discrete transport, geometry and source probes have declared tolerances. Renderer volume brightness differed without source corruption; screenshots are not concentration measurements. |
| [FEniCSx](FENICSX_BENCHMARK_RESULTS.md) | Nine exported exterior-mesh samples preserve typed arrays/time, topology and association; independent manufactured-solution/geometry checks pass. The tetrahedral interior is not exported; VTK probes do not certify Wavez Selection/Analysis UI. Historical Compatibility low-value contrast failures remain recorded. |
| [WVZ1 validation](WVZ1_IMPLEMENTATION_VALIDATION.md), [G4 ledger](G4_ACCEPTANCE.md) | Existing wire/identity and declared A01–A23 fixtures establish their recorded gates. They do not replace current scoped evidence or verify every scientific workflow. |

No solver, independent-visualizer campaign or Compatibility/OpenGL test was
rerun. Historical reports, including failures and review-time wording, are unchanged.

## Precise risks and owner follow-up recommendations

These are recommendations for owner decision, not additional implementation or
automatically created issues:

- **Native probe interpretation/units:** `scene_layers.gd:661–662` emits a
  channel/value with **object** units, not a channel-unit lookup, and no spatial
  derivation/dtype label. Per-channel units may differ. Consider a separate scoped
  change that labels the source trilinear estimate, resolves channel units and
  states interactive verification limits; test unlike-unit channels and held time.
- **Native extreme-value behavior:** `grid_view.gd:95–99` checks source corners
  but returns the accumulated result without a final finite-result guard, unlike
  `sampling.py:127–128`. Overflow and large/sheared float32 coordinate cases are
  **NOT VERIFIED** here. A focused finite/overflow oracle and unavailable-value
  policy review are preferable to assuming Python/native equivalence. No defect
  reproduction or algorithm correction is claimed by this audit.
- **Display-dependent membership:** `picking.py:181–242` uses camera, marker
  eligibility, occlusion and potentially interpolated geometry. These inputs can
  affect the selected population even though values subsequently come from source
  arrays. For quantitative comparisons use the same saved definition or explicit
  IDs/grid addresses, and retain creation evidence. Current GPU/UI picking has
  **NOT VERIFIED** status in this audit.

Diagnostics imports, common-schedule comparisons, space-time views, exploratory
period estimates, matched images/video, recipes, long-session lifecycle/resource
paths, packaged UI and other GPU/driver combinations were not exercised here.
They retain documented algorithms and historical evidence, **NOT VERIFIED** as
a fresh end-to-end claim. No new general Selection/Analysis validation is implied.

## Focused validation and owner review

Executed with Python's installed NumPy/codec environment and external Godot
`4.7.2.stable.official.ed1daf0bf`, using isolated writable XDG directories:

```sh
python -m unittest tests.test_analysis_source tests.test_selections \
  tests.test_analysis_reductions tests.test_native_analysis \
  tests.test_analysis_quadrature tests.test_derived_selection \
  tests.test_analysis_export -v
python tools/validate_payload_integrity.py --godot /absolute/path/godot \
  --output-dir /absolute/path/fresh-payload --renderer headless
python tools/validate_analysis_foundation.py --godot /absolute/path/godot \
  --output-dir /absolute/path/fresh-foundation
```

Results: **84 Python tests PASS**, **480 payload assertions PASS**, **63 strict
corruption fixtures rejected**, **163 worker/protocol assertions PASS**. Fixture
source hashes are unchanged. Both version tests and the authorized Godot editor
import pass. Markdown targets, pinned code line bounds and whitespace are checked.
The added three assertions close only the missing
numeric/provenance check in the already-existing affine worker-probe fixture.
No new fixtures, solvers, tolerances or scientific algorithms were added.

The initial payload run failed its wrapper because the sandbox denied Godot's
default user-log writes; file-dialog preference warnings were also emitted.
Repeating with writable external `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and
`XDG_CACHE_HOME` passed with a clean log. The initial failure is retained in the
external run directory, not counted as a passing run. Raw fixtures/logs remain
at `/home/Nozba/Codex/Wavez/scientific-contract-375/`; only compact evidence enters Git.
The sandboxed editor import also reported socket-creation errors and regenerated
four unrelated, previously absent UID sidecars. The authorized import rerun exited
cleanly; those incidental sidecars are excluded from this issue. Existing tracked
resource identities are unchanged.

This test scope covers the inspected source-to-readout and source-to-export
boundaries plus the only changed test. It avoids unrelated camera/playback/video
regressions and broad renderer/package campaigns. Headless checks certify CPU
contracts only. Forward+ Vulkan remains the sole supported GPU renderer;
no native pixel, standalone-package, other-platform or hardware-equivalence
validation was performed for this documentation/test change.

Before accepting, review §2.1 of the scientific contract and the status/limits in
this inventory; confirm the three new assertions use the analytic **13.75** oracle
and held source time **0**. Confirm historical reports are untouched and the diff
contains no algorithm/shader/format change. Optionally repeat the small CPU commands
above with fresh external output directories. No 50 GB capture or solver rerun is
needed to verify this deliverable.
