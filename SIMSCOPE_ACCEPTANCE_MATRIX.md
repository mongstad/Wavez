# SIMSCOPE Next — Acceptance Matrix

**Status:** Roadmap test definitions, not a consolidated execution report.
G0–G3 implementation and retained evidence are summarized in
[docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md) and [docs/EVIDENCE_INDEX.md](docs/EVIDENCE_INDEX.md).
Historical G2b evidence is described in G2_STORAGE.md; G3 evidence is described
in G3_REPORT.md and the current status links. **G4 A01–A23 PASS** for the
declared fixtures and measured workloads; see [the final ledger](docs/G4_ACCEPTANCE.md).
Execution evidence belongs in docs/CURRENT_STATUS.md and docs/EVIDENCE_INDEX.md.
The user accepted G4. G5/G6 remain unimplemented.
The owner accepted PERF-003 on 2026-09-13 based on its
[maintenance report and retained regression evidence](docs/MESH_PLAYBACK_MAINTENANCE_REPORT.md);
the pre-UX retirement intentionally supersedes older capture compatibility gates below.
Earlier compatibility matrices are archived with the prior private development repository.  
**Companions:** `SIMSCOPE_NEXT_DESIGN.md`, [G4_DESIGN.md](G4_DESIGN.md)  
**Rule:** Each test result must identify code revision, fixture, command/interaction, backend and artifact/log. Mark PASS, FAIL, BLOCKED or NOT RUN; do not substitute “implemented” for “tested.”

Use small deterministic fixtures in normal development. Run target-GPU and large-file tests at milestone gates. Store reference scripts/seeds so fixtures can be regenerated; never commit multi-gigabyte captures just to demonstrate scale.

## G0 — existing behavior and baseline

| ID | Test | Required evidence |
|---|---|---|
| B01 | Read supported SIMSCP3 particle, mesh and volume captures | Same timestamps, values, exact identities and representative rendered state as the audited native baseline |
| B02 | Explicit scene/object writer API | Current examples use SceneCapture; shared framing, lossless types and checksum validation preserve native bytes |
| B03 | Live append + interrupted final frame | Reader exposes only complete frames, recovers preceding frames and refreshes correctly |
| B04 | Screenshot first/second/cancel/relaunch behavior | First P asks for a directory; second reuses it; cancel saves nothing; relaunch asks again; filenames are unique |
| B05 | Recorded History startup and toggles | OFF at startup; T/UI enable and disable correctly; presets do not secretly reenable it |
| B06 | Existing offline MP4 | Actual rendered/encoded 1080p clip, expected duration/frame count, state reproduction, cancellation and failed-encode retention |
| B07 | Native output dimensions | Inspect a real generated 3840×2160 image; a requested window size is insufficient |
| B08 | Performance baseline | Median/p95 timings, RAM, measured GPU memory if supported, storage location, effects and fixed test interval for 20k/100k/250k fixtures |

## G1 — interpretation, state and time

| ID | Test | Required evidence |
|---|---|---|
| I01 | Signed channel values [-0.37,+0.31] | Automatic symmetric mode resolves to ±0.37 or documented outward rounding; zero maps to the midpoint |
| I02 | All-zero / invalid-only / constant channels | No division-by-zero, invented nonzero values or silent invalid scientific statistics |
| I03 | Fixed versus per-frame ranges | Fixed range stays fixed across time; automatic mode is labeled; independent comparative ranges are visibly declared |
| I04 | Log/cyclic behavior | Nonpositive values handled explicitly; signed log is not silently enabled; cyclic phase handles its seam |
| I05 | State round trip | Channel, mapping, filter, time and camera recover from saved JSON; incompatible fields yield clear errors/migration messages |
| I06 | Screenshot state barrier | Image and JSON correspond to the same committed state/time after delayed decoding; stale tasks cannot replace the requested frame |
| I07 | Known domain fixture | L64/N128 shows faces ±32, sample centers ±31.75 and absorber r27.2; not initial particle bounds |
| I08 | Unknown geometry and explicit override | Unknown stays unknown; data bounds/reference guide use different labels; override is recorded without editing input |
| I09 | Coordinate transforms | Off-center, anisotropically spaced, non-cubic volume aligns with reference particles after one transform; no double Z/Y swap |
| I10 | Type labels | Declared 0/1 labels display correctly; unknown values remain readable; IDs are not used as type categories |
| I11 | Nonuniform times [0,0.1,1.0] | Linear fixture sampled at 0.55 returns the analytic midpoint of the last pair, not a frame-index midpoint |
| I12 | Missing / duplicate / reverse times | Documented hold/unavailable/index-only behavior; no silent sorting or extrapolation |
| I13 | Video endpoint arithmetic | Exact endpoints, a near-integer output count, short ranges and a still each give documented counts; distinguish source samples from output frames |
| I14 | Multiple layer cadences | UI, video and state sidecar agree which layers are exact, held, interpolated or missing |

## G2 — index, storage and identity

| ID | Test | Required evidence |
|---|---|---|
| D01 | Warm/cold index | Independent reopen uses valid cached offsets; measured lookup/open time and bounded memory |
| D02 | Replacement/truncation/stale cache | Invalid index is rejected/rebuilt; same-name or equal-size replacement cannot silently reuse unrelated offsets |
| D03 | Committed append | Appended complete records extend the index; partial records do not; interrupted index rewrite leaves recoverable data |
| D04 | Python→Godot codec fixture | Decode `none` and Zstandard buffers byte-for-byte, including signed floats, NaN payloads where preserved and integer arrays |
| D05 | Compressed random access | Requested time/channel does not require decoding the entire capture or all prior frames |
| D06 | Corruption and oversized headers | Checksums, bad shapes/counts, integer-overflow sizes and excessive decoded byte requests are rejected before dangerous allocation |
| D07 | Unknown codec/type/version | Clear unsupported-feature error; no silent fallback that interprets bytes incorrectly |
| D08 | Supported-format boundary | Unsupported magic/version is rejected, including files renamed to .ssc; exact IDs are never float-cast |
| D09 | Exact ID round trip | Values around 2^24, 2^53 and the supported int64 limit preserve identity; JSON uses exact decimal strings |
| D10 | Reorder and variable counts | Shared IDs move correctly despite shuffled arrays and births/deaths; unrelated particles are not joined |
| D11 | ID gaps and duplicates | Duplicate IDs fail validation; reappearance gaps break trails; no ID recycling within an object |
| D12 | Categorical/phase/topology transitions | Categories hold; phase follows declared policy; incompatible topology/grid geometry does not interpolate |
| D13 | Large logical capture | Generate or reuse a many-frame fixture with declared size; inspect memory slope over repeated seeks, not just a one-frame load |
| D14 | Archival backpressure / preview dropping | Slow consumer never alters solver dt; archival output remains complete or fails visibly; preview omissions are recorded |

## G3 — mesh, volume and isosurface

| ID | Test | Required evidence |
|---|---|---|
| V01 | Analytic scalar field | Numeric probes recover known values within declared sampling tolerance from source data |
| V02 | Real density source | Direct array data drives rendering; a source-less particle capture reports volume unavailable |
| V03 | Axis slices | XY/XZ/YZ slices match independent array slices with labeled interpolation and units |
| V04 | Oblique plane and transform | Sample a non-axis-aligned plane in known coordinates; errors remain within declared interpolation bounds |
| V05 | Homogeneous slab rendering | Changing ray-march step size does not materially change integrated opacity after step correction; tolerance recorded |
| V06 | Camera/occlusion | Camera inside and outside volume behaves; opaque mesh correctly occludes; unsupported overlapping translucent volumes are flagged |
| V07 | GPU quality fallback | Exceed a safe test budget and verify explicit LOD downgrade/release; analysis still reads original precision |
| V08 | Grid topology change | Dimensions/origin/spacing changes refresh resources or hold discretely; stale texture reuse is prevented |
| V09 | Static/fixed-topology mesh | Triangle positions, winding, normals and face/vertex channel associations are correct |
| V10 | Mesh corruption/topology change | Invalid indices and oversized geometry fail; unrelated topology is not blended |
| V11 | Known isosurfaces | Sphere and torus fixtures meet documented geometric error bounds; anisotropic spacing is honored |
| V12 | Bricks and invalid regions | No artificial extraction cracks at brick boundaries; halos and masked regions behave explicitly |
| V13 | Extraction cancellation/cache | Fast threshold changes cancel or supersede stale jobs; repeat request uses validated cache |
| V14 | Real target-machine demo | 128³ volume + 100k particles + guides/slice/surface; achieved frame time, RAM and VRAM reported, not assumed |
| V15 | New-layer video export | Short render includes correctly timed volume/mesh/particle layers and preserved ranges/transfer functions |

## G4 — selections and temporal analysis

Clarification approved 2026-09-12 against the consolidated G2/G3 implementation.
A01–A10 retain their original goals; changes resolve layer identity, centering,
precision and clock ambiguities. A11–A23 make the corresponding regressions explicit.
No G0–G3 criteria are relaxed. Numerical, rendered and performance evidence must
be reported separately. Fixture IDs and policies are defined in G4_DESIGN.md §3–§9.

| ID | Test | Required evidence |
|---|---|---|
| A01 | Screen pick/region query | Known source IDs/rows/faces and counts under saved visibility/occlusion policy and committed layer time; anonymous/derived picks acquire no inferred identity; volume picks require an explicit location/plane. F01/F07. |
| A02 | Cohort versus spatial ROI | Moving members demonstrate fixed IDs versus reevaluated region; native-clock counts, absent members, predicate and weighting are labeled; display changes do not silently change membership. F01/F03/F05. |
| A03 | Physical sum versus sampled tracer estimate | Physical mass requires declared actual particle masses or a supported field quadrature with units/semantics. Distinguish discrete integral from continuum exactness; unweighted hybrid-tracer density sum is refused as field mass. F05/F06 and tracer-only demo. |
| A04 | Uniform field integral | Integral equals density × effective selected cell volume for both cell-centered and node-centered fixtures; center inclusion, node-cell quadrature, anisotropic spacing and absolute affine determinant included; partial boundary approximation and invalid coverage reported. F05. |
| A05 | Weighted statistics | Independent hand-computed values match; association, selected/present/finite counts, weight validity/sum, quantile convention, source and reduction precision appear in results; empty/invalid support does not become a valid zero. F06. |
| A06 | Diagnostic CSV timeline | Separate explicit CSV clock, units/source binding and row provenance; nonuniform times and missing intervals without fabricated points; supplied and derived series remain separate; bad axes remain index-only. F08. |
| A07 | Space-time diagram | Known traveling pulse follows expected path on native nonuniform times; spatial bins, source support and gaps preserved; direct-grid quadrature/probes distinguished from tracer counts/estimates and display decimation. F05/F08. |
| A08 | Period estimation | Synthetic steady/chirped/noisy signals test window and sampling assumptions; short/noisy data do not claim a precise period |
| A09 | Matched run comparison | Same saved camera/coordinate/range/time semantics; explicit source/selection correspondence and independent brackets; no automatic cross-run ID match. Raw times survive any declared bounce/time alignment; sequential matched snapshots/clips and derived output include both input identities. F08/F09. |
| A10 | Read-only analysis | Input checksums unchanged after selections, analysis, screenshot and CSV export |
| A11 | Persistent-ID lifetime and random seeks | Exact IDs through reorder, births, deaths, empty samples and endpoint holds; random seek reports audit coverage. Prefix audit detects external reuse/duplicates; no gap-bridged history or physical death-time inference. Writer rejection remains unchanged. F01/F02. |
| A12 | Anonymous selection limits | Anonymous SIMSCP3 picks bind record/row only, hold and disable identity history; equal counts/order do not imply identity. Spatial statistics remain available; invalid time axes are not silently sorted. F03. |
| A13 | Mesh identity/topology | Source vertex/face association survives render expansion/winding; vertex-ID traces and G3 position interpolation obey their respective rules. Face/barycentric selection expires on topology change; A→B→A cannot resurrect it. Static no-ID geometry remains reusable. F04. |
| A14 | Grid/slice/derived selection | Fixed coordinates versus geometry-bound grid addresses behave explicitly through geometry changes; moving a displayed slice does not move its saved probe. Source invalid-corner policy retained; remeshed level-set picks stay artifact-local and approximate. F05/F11. |
| A15 | Independent clocks and missing values | No repeated held sample counted as a native observation; exact/held/static/position-interpolated/value-missing statuses and both comparison brackets retained. Missing channels/IDs are not zero or forward-filled; no silent clock conversion or join. F01/F03/F08. |
| A16 | Scientific precision and derivations | f8 results unaffected by GPU LOD, colormap or float32 display helpers; exact IDs/integer values preserved. Source velocity differs from labeled interval derivative; signed cancellation, phase/categorical restrictions, invalid weights and precision-sensitive coordinates have independent numerical oracles. F06. |
| A17 | Display-independent selection | Visibility, filters, clips, colormaps and LOD obey saved pick/overlay policy; numerical results retain source membership, with present/drawn counts separate. Hidden-particle playback fast path is not disabled merely by stored selections. F07/F11. |
| A18 | Recipe compatibility and atomic restore | v1/v2 inspection and old video jobs preserve behavior. v3 state round-trips selections/groups/probes/analysis requests and exact IDs/times; malformed/missing assets, changed source or unsupported fields fail before mutation. Screenshot destination stays session-only. F09. |
| A19 | Worker lifecycle and stale results | Delayed/superseded pick, seek, source replacement, close, worker crash and cancellation cannot publish stale results; bounded UI acknowledgement and no interval decode/hash/reduction on UI callbacks. F10. |
| A20 | Deterministic analysis/image export | Full numerical CSV plus manifest records units/IDs/source channel, native and derived time support, validity, precision and provenance; plot previews are not exported as full data. Pinned extents/revisions and render barriers produce matching overlays/sidecars; append does not extend a job; partial failure is explicit. F09/F10. |
| A21 | Long-capture resource bounds | Eviction-heavy seek/open/close/scan/export loops show bounded caches, viewer+worker RSS, result disk and GPU overlays, no orphan workers, finite quota refusal and measured playback impact; no silent scientific subsampling. F10 and declared 100k-particle performance workload. |
| A22 | G0–G3 validation/compatibility preservation | Existing format, checksum, shape, identity, incomplete-tail and allocation tests still pass after selective/pinned reads; old recipes/PNG/video and optimized playback regressions rerun as relevant. Source mutation is not mistaken for append. F03/F10 plus existing suites. |
| A23 | Multiple selections/groups | Add/subtract/toggle and saved revisions are deterministic; overlap deduplicates within one compatible population; mixed kinds/objects remain separate series and ambiguous group totals are refused. Large sets retain all exact members within explicit quotas. F09. |

G4 implementation gate (2026-09-12): **A01–A23 PASS** for the declared fixtures
and workstation measurements. The [acceptance ledger](docs/G4_ACCEPTANCE.md)
records each ID's tests, actual renderer checks, resource evidence and limitations.
The user subsequently reviewed and accepted G4; this registry is not a universal
performance claim.
The only wording change at completion is “Proposed v3” → “v3”; IDs and goals remain.

A08 remains a G4 requirement for exploratory peak-interval/autocorrelation estimates
with declared windows and sampling checks (F08). Automatic event detection and
event-generated bookmarks remain G6; this clarification does not remove A08.

## G5 — local control, MCP and plugins

| ID | Test | Required evidence |
|---|---|---|
| C01 | Default-off + explicit enable | No listening interface by default; correct capability/auth required after enabling |
| C02 | Scope and path restrictions | Traversal, symlink escape, unauthorized roots, arbitrary shell/eval and writes outside approved output are denied |
| C03 | Atomic inspection | One command selects time/channel/range/camera, waits and returns matching PNG/state; user edits are not lost during restore |
| C04 | Expensive jobs and cancellation | Requests have bounded sizes/budgets; job handles are cancellable; revocation blocks new operations |
| C05 | Client isolation | One client's job/state cannot be silently overwritten or cancelled by another without permission |
| C06 | MCP interoperability | Actual compatible client or official testing tool negotiates the documented protocol and invokes bounded commands |
| C07 | HTTP protection when applicable | Invalid Origin/auth is denied; endpoint binds to loopback; a session ID alone is not authentication |
| C08 | Plugin behavior | Disabled until explicitly installed/enabled; failure is reported without losing viewer; no auto-execution from capture metadata |
| C09 | Honest trust boundary | Trusted-code-only plugins are labeled; no claim of sandbox protection unless isolation tests actually pass |
| C10 | External chat limitation | Docs distinguish a working local server from a configured/authorized connection to any particular chat client |

## G6 — events, adapters and final release

| ID | Test | Required evidence |
|---|---|---|
| R01 | Known event fixtures | Threshold crossing, peak, flux reversal and absorber contact detected at expected times/tolerances |
| R02 | Negative controls | Smooth/no-event signals and intentional absorber loss do not become false conservation or vortex claims |
| R03 | Event provenance | Each result includes measured data, threshold, masks, interval, algorithm version and a reproducible inspection recipe |
| R04 | Adapter invariance | Export-enabled and export-disabled short simulation produce equivalent physics diagnostics under declared tolerance |
| R05 | Optional dependency isolation | Missing optional analysis/external-integration extras affect only those features; ordinary particle viewing still works |
| R06 | Safe imports | NPZ object/pickle payload rejected; imported units/origin/IDs survive; no silent coordinate conversion |
| R07 | Packaging and docs | Clean documented Linux environment launches viewer and ordinary Python writer; optional extension installation verified |
| R08 | Full regression | Re-run supported scene, current-video/PNG and new-feature gates; record any intentional compatibility limitations |
| R09 | Long-session resources | No unbounded decoded cache, leaked GPU resources or orphan workers after repeated seek/open/close/export cycles |
| R10 | Reproducible handoff | Status file links passing artifacts, exact test commands, known limitations and the next unfinished action |

## Reporting template

For every completed gate, fill in:

```text
Gate and code revision:
Previously working behavior preserved:
Files changed:
Fixture(s), seed(s), source identity:
Environment and rendering backend:
Commands or interaction sequence:
PASS / FAIL / BLOCKED / NOT RUN test IDs:
Rendered artifacts inspected:
Measured timings and memory:
Numerical tolerances and source precision:
Known limitations:
Next exact action:
```

Benchmark goals are provisional engineering targets, not permission to invent results. If a feature works correctly but misses a performance target, record both facts separately and optimize the measured bottleneck.
