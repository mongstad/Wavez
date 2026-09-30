# Retained evidence

## Residual violet UI cleanup — issue #147, pending owner review

[Current behavior and owner checks](UX5_CLEANUP.md) and
[focused evidence](evidence/issue-147/summary.json) cover semantic boolean styling,
File Details, quieter shell chrome and the owner-supplied violet About logo.
#143 was owner-merged in PR #145; its reports below retain their historical
review-time wording.

## Violet visual-system slice — issue #143, pending owner visual review

[Scope, component structure and owner checks](UX5_STYLE_SLICE.md) and
[native evidence](evidence/issue-143/summary.json) cover the representative
production slice. Broader propagation waits for owner approval. Earlier visual
proposals and review-time reports below remain historical records.

The owner reviewed v1 at `0d32d08`, approved its overall direction, and requested
refinement before broader propagation. [Round 2 evidence](evidence/issue-143/round2/README.md)
covers the revised representative surfaces and transport/window interactions.
Round 2 awaits owner visual review on the same Draft PR #145; banner styling is
deferred at the owner's request. The v1 report and evidence remain unchanged.

**2026-09-30 correction round:** the owner subsequently reviewed Round 2 at
`b9a2df3` and requested corrections before propagation approval. The
[new evidence and screenshots](evidence/issue-143/round3/README.md) cover uniform
disclosures/sliders, whole-second clock seeking, filename privacy and real
Fullscreen Tools menu dispatch. This correction round awaits owner review on
Draft PR #145. The original v1/Round 2 records above remain historical.

**Round 4 dropdown consistency correction:** the owner approved the Round 3
direction at `6d1eff6` in principle and found legacy dropdown/popup styling in
Fields/Meshes. [New comparison screenshots and reproduction](evidence/issue-143/round4/README.md)
and [results](evidence/issue-143/round4/summary.json) cover a shared production
selector/popup skin, dynamic rebuilds, native focus/navigation and retained
scientific behavior on both renderers. This round awaits owner visual review;
`0d32d08`, `b9a2df3`, `6d1eff6` and their evidence remain unchanged.

## Paused rendering — issue #118, pending owner review

[Investigation, policy and owner checks](PAUSED_RENDERING.md) and
[compact production evidence](evidence/issue-118/rendering.json) describe redundant
paused frames, the GPU drop on Play, bounded paused orbit and redraw-on-change.
Earlier reports below retain their original review-time wording; current merged
status is recorded in [Current status](CURRENT_STATUS.md).

## Dynamic field preparation — issue #111, pending owner review

[Policy, validation and owner checks](DYNAMIC_FIELD_PREPARATION.md) and
[compact evidence](evidence/issue-111/dynamic.json) cover Auto versus fixed 1–4
lanes, full 192³ 1× playback, 2×/4× trials, measured startup gates, resource
backoff, scientific-value/cache regressions and interaction/close/reopen behavior.
The report explicitly records the fixed-two swap observation and probe repairs.
Historical #109 evidence below retains its original review-time wording.


## Bounded parallel preparation — issue #109, pending owner review

[Investigation and validation](PARALLEL_FIELD_PREPARATION.md) and
[compact evidence](evidence/issue-109/parallel.json) cover matched one-to-four-worker
CPU/native measurements, complete 1× playback, scientific equality, cancellation
and cache races. Earlier #100/#102/#107 reports retain their historical wording.

## UX1 — accepted

[Milestone report](UX1_REPORT.md), [UI audit](UX1_UI_AUDIT.md), [design specification](UX1_DESIGN_SYSTEM.md),
and [compact native evidence](evidence/ux1/summary.json) document the accepted SIMSCP3 baseline.
The owner accepted UX1 on 2026-09-13 at `229d4ea`. The report and evidence retain
their original review-time state. UX1 made no product-code changes. UX2 was
subsequently implemented and accepted as recorded below; UX3 remains on hold.

## Maintenance and G4 evidence

The [post-G4 maintenance record](MAINTENANCE_REPORT.md) and
[compact evidence](evidence/maintenance/validation.json) cover documentation,
legend behavior, G4 panel layouts and focused regressions. G4 and this earlier
maintenance pass are reviewed and accepted.

[PERF-001/002 maintenance](PERFORMANCE_MAINTENANCE_REPORT.md) and its
[compact evidence](evidence/performance-maintenance/validation.json) cover automatic
particle cache selection, field preparation and retained 02B/03B regressions.
Both items were reviewed and accepted by the user on 2026-09-13.

[PERF-003 mesh maintenance](MESH_PLAYBACK_MAINTENANCE_REPORT.md) and its
[compact evidence](evidence/mesh-playback-maintenance/validation.json) cover
bounded mesh preparation, native morph/render equivalence, lifecycle controls and
accepted benchmark 04B source/probe and timing regressions. The owner reviewed and
accepted PERF-003 on 2026-09-13 at implementation checkpoint `7974c78`. GPU submission,
explicit scientific inspection and some renderer/event-loop costs remain synchronous
and outside this maintenance scope. The original benchmark evidence is unchanged.

The [G4 final gate](G4_ACCEPTANCE.md), [gate evidence](evidence/g4f/gate.json) and
[performance evidence](evidence/g4f/performance.json) are the current G4 completion record.
Earlier slice entries below retain their checkpoint-specific pending status.

Historical measurements are not new validation. Raw datasets, plots, trace logs and archive
packages were removed during consolidation and remain in the user’s external backup.

- [G3 contract](../G3_FORMAT.md) and [implementation report](../G3_REPORT.md).
- [G4 implementation checkpoints](../G4_REPORT.md), [G4a source/protocol evidence](evidence/g4a/foundation.json). Historical slice evidence; final G4 acceptance is recorded above.
- [Initial G4b selection evidence](evidence/g4b-initial/selection.json): numerical/picking tests and the initial viewer path on both renderers; G4b remains in progress.
- [G4c native backend evidence](evidence/g4c/native-backend.json): 158 Python tests; full G4 and plot/render integration pending.
- [G4c temporal viewer evidence](evidence/g4c/temporal-viewer.json): native plots/full tables on both renderers, 163 Python tests, 2,457 G3 playback checks; whole G4 gate pending.
- [G4d diagnostics backend](evidence/g4d/diagnostics-backend.json): CSV/period kernels and private-worker transport; G4d UI/comparisons remain in progress.
- [G4d comparison/viewer checkpoint](evidence/g4d/comparisons-viewer.json): 191 Python tests, 23 diagnostic headless checks, 24 checks on each actual renderer; space-time/matched rendering pending.
- [G4d space-time checkpoint](evidence/g4d/space-time.json): 199 Python tests, 21 headless checks, 20 checks per actual renderer; durable state/matched rendering and full gate remain pending.
- [G4e state/export checkpoint](evidence/g4e/state-export.json): 214 Python tests, 34 native viewer checks, 49 legacy inspection checks, 23 storage tests and 36 actual OpenGL G3 checks; image/video extension and full gate remain pending.
- [G4e selection-aware PNG/video](evidence/g4e/selection-render.json): 44 checks per renderer, exact delayed/replayed pixels, 217 Python tests and existing video continuation PASS; matched pairs and G4f remain pending.
- [G4e matched pairs](evidence/g4e/matched-render.json): 222 Python tests, 44 native/GPU checks per renderer and 7 altered-job refusals; full G4f gate pending.

Paths and hashes inside historical evidence identify original runs. Their bulky inputs and
outputs are external backup material, not promised repository files. Current reproduction commands and limitations are in [Quickstart](../QUICKSTART.md).

## UX2 — Theme Foundation & Component Library (accepted)

[Report](UX2_REPORT.md), [theme guide](UX2_THEME_LIBRARY.md), [retained evidence](evidence/ux2/README.md).
The owner reviewed and accepted UX2 on 2026-09-13 at `5fae711`. The report and
evidence retain their original review-time state. UX3 has not started and remains
on hold until further notice from the owner.
Native foundation: 1,174 checks, 300 independent float64 cases, 71 contrast pairs,
16 size/scale combinations, six production isolation checks and six stable HUD
cases. All 195 pre-existing protected source files are unchanged. The UI Laboratory
is opt-in; no production migration or UX3 work has begun.

## SSC format investigation — #102, pending owner review

[Design and measurements](SSC_ACCELERATION.md), [capture parameter inventory](SSC_CAPTURE_PARAMETERS.md),
and [compact evidence](evidence/issue-102/summary.json) cover the clean SIMSCP4
break, exact real-capture equivalence, preparation/switching and finite intervals.
Older SSC reports above retain their original format, results and review state.
