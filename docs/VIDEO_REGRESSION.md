# VIDEO-REGRESSION-001 — current development export baseline

Issue #116 was the only Ready item on 2026-09-27. The owner-created linked branch
`116-video-regression-001-revalidate-video-export-against-current-simscp4-and-viewer`
started at accepted `main` `788de5d` (PR #119), including #103/#108/#110/#113.
Implementation and the evidence below are **pending owner review**.

## Owner-review startup correction

The initial worker-only production result below omitted the UI's source identity
hash and therefore did **not** prove practical Start Export latency. Owner review
reproduced two full 118 GiB prefix passes before frame 1. The correction, full
20–25 production export, cancellation/mutation results and refreshed regression
results are documented in [VIDEO_STARTUP_116.md](VIDEO_STARTUP_116.md). The original
measurements below remain historical evidence, not the final startup claim.

## Reproduced defects and changes

1. **Wrong current-position start.** The dialog combined particle sample endpoints
   with the union-clock interpolation fraction. At scene time 0.75, a mixed scene
   with particle samples at 0/1 and field samples at 0/0.5/1 exported from 0.5.
   Field-only and mesh-only scenes could use the initial placeholder particle
   frame's time. The dialog now consumes `committed_sample.requested_time`, and
   refuses an export without a committed sample. Pending seek targets do not
   replace the displayed clock.
2. **Appearance restored against the opening schema.** Workers loaded sample zero
   before validating/applying the exported state. A field channel appearing later
   could be rejected as unknown; particle mapping could reset to fixed. Workers
   now sample the requested start first, then use the existing visual-state
   validation/restoration. Dedicated later-channel particle and field fixtures
   exercise this boundary.
3. **Incomplete scene reported as successful video.** The worker checked volume
   color-normalization errors but missed field preparation/display failures and
   mesh budget failures recorded in the current layer status. It now refuses an
   unavailable visible layer with an explicit failure reason before publishing
   that frame. Tests reproduce a finite float64 field outside float32 display range
   and a mesh above its selected GPU budget. Neither publishes a final MP4.

The initial three corrections were export-side changes. They did not change the
capture writer/reader, scientific sampling, interactive preparation, source values,
shaders, precision or cache policies. The owner-review correction additionally wires cooperative cancellation
into the existing reader; strict decoding remains unchanged. Historical evidence was preserved.

## Audit of the current path

| Boundary | Current implementation and evidence |
|---|---|
| File → Export → Video | Production shell command opens the current dialog; regression invokes its real menu signal. |
| Settings and launch | Snapshot current visual state, shell presentation, committed source identity, requested backend and independent positive export rate. Launch the installed engine with argument arrays and persistent log; no legacy UI or capture adapter. |
| Worker read/sampling | `offline_instance` selects strict `SceneReader`; the current shared scene sampler supplies independent layer clocks. Version-2 source/selection extent remains pinned. |
| Preparation/memory | Particle/field/mesh interactive preparation workers are disabled offline. Existing synchronous per-sample preparation and bounded decoded cache apply; no whole-capture preparation gate. Source pair and GPU budgets remain enforced. |
| Rendering | Current particle, volume and mesh renderers, current shell, separate layer legends, camera and viewport settings. Manual SubViewport draw/readback is independent of minimized-window redraw. |
| Scientific state | Exact synthetic persistent IDs/positions, mesh interpolation and index winding, held field channel bytes, color/opacity uniforms, full-resolution field planes, requested sample times and deterministic orbit are independently checked. |
| Overlays | Existing explicit export checkbox gates shell and layer legends; guides retain existing independent ownership. Desktop fullscreen is not exported. |
| Jobs | Existing dialog/status controllers own live progress, ETA, background/reopen, terminal state and parent-close cancellation. No replacement job lifecycle. |
| Encoding/publication | Existing PATH FFmpeg discovery, libx264 invocation, error diagnostics, cooperative cancellation, staging and no-overwrite publication. PNG cleanup occurs only after successful final publication. |

Offline strict checks apply to records read, including all payload channels in
those samples. A structurally readable checksum-only corruption in a later field
sample fails export. Whole-file before/after SHA checks prove source invariance;
they do not replace `tools/verify_ssc.py` for auditing every scientific record.

## Validation

Environment: Linux development checkout; Godot 4.7.2 (`ed1daf0bf`), NVIDIA RTX
3070 Ti, driver 615.71.09; native Forward+/Vulkan and Compatibility/OpenGL;
installed FFmpeg/ffprobe. Generated SIMSCP4 fixtures and output are external to Git
under `/home/Nozba/Codex/SIMSCOPE/video-regression-116/`.

Final results: **933 passing assertions, zero failures**, across these focused
suites (repeated common checks count in each suite). The pre-change Compatibility
baseline additionally passed 142 assertions.

| Suite | Backend | Passing assertions |
|---|---|---:|
| Current layer/export regression, including production segment | Forward+ | 268 |
| Current layer/export regression | Compatibility | 225 |
| Full particle/video/FFmpeg acceptance | Forward+ | 142 |
| Production UI overlay, repeat and 4K | Compatibility | 111 |
| Production Jobs/progress/lifecycle | Forward+ | 123 |
| Selection-aware rendering/replay | Forward+ | 44 |
| Pinned extent, mutation, quota and cancellation | Forward+ | 20 |

Retained machine-readable results are in
[evidence/issue-116/summary.json](evidence/issue-116/summary.json). Godot import,
Python harness compilation and `git diff --check` also passed. The UID sidecars
are included. The synthetic [mixed-layer UI frame](evidence/issue-116/mixed-ui-gl.png)
was inspected alongside the production PNG; raw captures and production results
remain external.

- `tools/validate_video_current.py`: particle, field, mesh and mixed scenes;
  later-appearing channels; clock/menu/state boundaries; strict corruption,
  float32 overflow and GPU-budget failures; deterministic delayed repeated output;
  exact source bytes, native scientific state and requested renderer.
- `tools/validate_video.py`: real UI child launch, 1080p/4K MP4 and PNG dimensions,
  30/60 FPS, half-open ranges/rates, orbit/locked camera, rendering cancellation,
  missing/failing FFmpeg, encoding cancellation and conditional PNG cleanup.
- `tools/validate_viewer_status.py`: background/reopen, live/terminal details,
  elapsed/ETA, original worker identity, cancellation and parent-close acknowledgement.
- `tools/validate_g4_render.py`: version-2 selection-aware frame membership,
  scientific positions, sidecars, delayed determinism and PNG replay.
- `tools/validate_g4_render_failures.py`: pinned extent despite later appends,
  mutation/quota refusal and partial-frame cancellation.

The initial Compatibility reproduction found the clock, later-field-channel and
silent-preview failures. Early harness runs also needed syntax/viewport cleanup,
correct Python reader return-shape handling, and JSON timestamp comparison within
1e-14 (binary fractions serialized in decimal). A flat, unshaded triangle was
visibly correct; the initial “many distinct colors” image test was inappropriate
and replaced with a nonempty-pixel check. These intermediate runs are retained
outside Git and are not counted as passing final evidence.

## Production segment and performance

The existing `SIMSCP4_D192_T200_simscope.ssc` is approximately 118 GiB. The bounded
Forward+ test exports [0.1, 0.2) at 30 FPS: three 1920×1080 frames with `psi_imag`
and the full 192³ field. Independent Python strict reads are compared to the
worker's exact source arrays and the uploaded float32 texture planes for every
output frame. Full-file SHA before/after covers the original capture.

| Instrumented export | Peak worker RSS | Peak worker swap | Whole-process wall time | Frames / wall second |
|---|---:|---:|---:|---:|
| Synthetic field, Forward+, 2 frames | 650.72 MiB | 0 | 1.959 s | 1.021 |
| Synthetic field, Compatibility, 2 frames | 262.40 MiB | 0 | 1.658 s | 1.206 |
| Production 192³, Forward+, 3 frames | 1062.98 MiB | 0 | 4.120 s | 0.728 |

Peak worker RSS/swap and elapsed throughput are also in the evidence summary. Sampling
uses `/proc/<pid>/status` every 50 ms. These are instrumented worker-only RSS
measurements, excluding FFmpeg's separate RSS and GPU VRAM. The short-clip rate
includes engine startup, loading, PNG output and encoding, and is not a sustained
long-export benchmark. No scientific solver was rerun.

## Limits and remaining work

- Development checkout and this Linux/GPU/driver combination only. Packaged builds
  and external runtime discovery remain #93; no dependency was bundled.
- Exact repeated mixed-scene pixels are checked within each backend. Cross-backend,
  cross-driver and temporal-AA pixel identity are not promised. Exact float texture
  readback is checked on Forward+; Compatibility is checked using source arrays,
  transfer state, scientific geometry and rendered images.
- The initial production export below covers three frames; the startup correction
  adds the full 1,200-frame owner clip. Neither covers the entire capture. Production 4K
  throughput, long-export resource stability and other hardware remain unmeasured.
  4K uses the small synthetic capture.
- Cancellation boundaries were extended in the owner-review correction; individual
  decode/hash calls, preparation, rendering and PNG writes remain synchronous.
- Existing finite per-sample/GPU/output quotas remain. Export does not make an
  otherwise undisplayable source sample renderable, and may use the viewer's
  existing budget-governed preview policy. The measured 192³ segment remained LOD 1.
- #54 orbit UX, #56 postroll, #61 overlay-panel options, #93 packaged export and
  #97 cancellation confirmation remain deferred and were not implemented.

## Owner verification

1. From this branch, open the development viewer on the production `.ssc`. Pause
   at a nonzero time, select `psi_imag`, set the desired particle/field appearance
   and camera, then choose **File → Export → Video**.
2. Choose **Current position to end** and verify the start matches the displayed
   committed time. For a quick export, switch to **Custom start/end** and use
   0.1–0.2, 30 FPS, 1080p, rate 1 and a fresh output filename.
3. Export with **Current state**, locked camera, overlays off and **Keep PNGs** on.
   Confirm the MP4 opens, has three frames, and matches the current field channel,
   particle settings and framing. Compare PNGs for scientific appearance; MP4 is lossy.
4. Repeat to a new filename with orbit and overlays enabled. Confirm the production
   shell and enabled legends, and the selected orbit rate. Repeat a small 4K export
   if desired; desktop monitor resolution does not limit export dimensions.
5. Start a longer small-fixture export, choose **Run in background**, reopen it from
   **Jobs**, inspect progress/ETA, and cancel. Verify cancelled status, retained
   intermediates and no final MP4. Closing the parent should also request cancellation.

Stop for owner review; successful automated checks are not acceptance.
