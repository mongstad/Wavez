# UX3 — Main Viewer Shell: integration report

**Issue #44 · 2026-09-21 · Validation package complete; pending owner review.**
This report does not accept UX3 or authorize UX4. The owner controls that decision.

## Baseline and scope

#44, **UX3-VALIDATION-001 — Complete shell integration and UX3 milestone validation**,
was the sole Ready item in SimScope Development (Project 1). The owner-linked
branch `44-ux3-validation-001-complete-shell-integration-and-ux3-milestone-validation`
was already checked out, clean and identical to local/remote `main` at
`c240024cc0cf6f223e96763bf58cbabdfc7fcf85`. PR #63 was verified merged; its stale
remote branch was pruned and the previous local branch was already absent.

All required accepted slices were verified as ancestors of `main`:

| Issue | Owner-merged PR | Merge commit |
|---|---|---|
| #41 shell | #45 | `884ea73` |
| #42 transport | #47 | `a976ec6` |
| #43 status/Jobs | #48 | `1976adc` |
| #49 media timing | #51 | `195bd90` |
| #53 transient feedback | #57 | `deb6b87` |
| #46 immersive fullscreen | #58 | `a32857f` |
| #55 production-shell video overlays | #60 | `2fd44ba` |
| #59 retired left-panel cleanup | #63 | `c240024` |

No production integration defect was found in the tested workflows. This branch
adds a reproducible integration/measurement harness, strengthens native fullscreen
image validation, and reconciles current documentation. Production controllers,
shell behavior, shaders, scientific algorithms, state schemas and exports are
unchanged from the accepted baseline. There is no new worker, polling owner,
playback mode, architecture or compatibility layer.

The roadmap now describes the accepted single recorded-time model rather than a
retired selectable time mode. The status guide's obsolete statement that offline
viewers omit the shell is corrected: offline viewers share the production shell,
with explicit refresh after committed samples. Original issue review metadata,
older test counts, screenshots and reports remain historical and unchanged.

## Production ownership and UX4 handoff

| Region | Production owner and integration boundary | Remaining UX4 work |
|---|---|---|
| Command bar, contextual dock, camera/recovery chrome | `ViewerShell`; menus call existing operations; full-frame scientific viewport retained | Structured capture/object context and actual workspace contents |
| Persistent transport | `ViewerTransport`; canonical recorded-time controller, union-index navigation and exact Seek; no mode selector | Consume the existing transport, not another playback implementation |
| Status and Jobs | `ViewerStatus`; published readiness/job snapshots and existing cancel/reopen callbacks | Keep scientific requests/results in their canonical owners |
| Right inspector | Neutral dock/scroll/VBox plus actual controls built in main/layer/selection/analysis code | Migrate Scene, Appearance, Selection, Analysis/Results, State/Export and Performance access in separately authorized slices |
| Offline overlays | Same shell/transport/status components; worker owns timing and explicit refresh | Preserve current #55 contract; granular overlay options remain #61 |
| Scientific annotations | Existing legend, probe, guides and selection/analysis owners | Independent legends remain #37; do not confuse annotations with application chrome |

The detailed [#59 ownership map](UX3_UI_OWNERSHIP.md) remains the dependency audit.
Retained groups include rendering/mapping/ranges, size/brightness, camera,
trails/filters/postprocessing, layers/volume Quick setup/color/opacity, source
probe, selections, analyses/results/recipes, cache/resource controls and exports.
They remain the canonical right-inspector widgets. Scene/Appearance/Selection/
Analysis are navigation entry points, not completed UX4 migrations. There is no
supported retired left-panel runtime/export fallback.

## Fresh validation

Godot 4.7.2 (`ed1daf0bf`), Fedora KDE/Wayland, NVIDIA RTX 3070 Ti. Both Forward+
and Compatibility were exercised. Tiny generated SIMSCP3 fixtures and one frozen
real particle/volume capture were used read-only; no solver or large research
capture was regenerated. Counts overlap when suites embed other checks.

| Check | Result |
|---|---|
| Production shell | 160 PASS per renderer |
| Transport | 207 PASS Forward+ including real source; 204 PASS Compatibility |
| Status/Jobs | 67 PASS per renderer, including live Details, terminal retention, cancellation and parent-close acknowledgement |
| Current recipe/state ownership | 2,957 PASS headless |
| Recorded-time asynchronous playback | 2,457 PASS headless |
| Readiness/budgets and playback lifecycle | 66 + 51 PASS headless |
| Camera | 13,032 PASS headless; not GPU image validation |
| New integration probe | 56 PASS on a mixed fixture and 56 PASS on the real source per renderer |
| Real KDE/Wayland fullscreen | 11 state checks + 8 independent KWin geometry checks per renderer; 5 identical scientific regions per capture method, per renderer |
| Production-shell video overlays | 111 PASS assertions per renderer, including 62 native UI checks; actual 1080p/4K MP4/PNG, on/off, workspace/remaining and deterministic repeats |
| Selection-aware PNG/video/state replay | 44 PASS Forward+, including exact timing, membership and image/source hashes |
| Retained volume controls | 99 PASS Forward+ plus three preset exports |
| Normal application startup/shutdown/reopen | Two independent normal main-scene processes, exit 0 with clean logs |
| Static checks | Godot import/script parse, Python syntax, local documentation links, viewer UID and Git whitespace checks pass |

[Evidence index, commands, machine-readable reports and images](evidence/issue-44/README.md).
The source SHA-256 remained
`0805d497ad0f69440f3aa7ac30d6cfe9642a4efd142ae406d3a685b595d7d3f5`
for the 11,542,897,957-byte retained FreeCollapse capture (401 union samples,
100,000 particles at the opening sample, particle and volume layers).
The repository contains no copy of this source.

## Required workflow coverage

Numbers refer to #44's required workflows. Automated native input/control calls
are distinguished from physical owner interaction.

| Workflows | Fresh evidence and result | Remaining manual boundary |
|---|---|---|
| 1–2, 27: empty/open/replace/cancel/failure/recovery | Shell160: real picker open/cancel, loading state, failed replacement preserves old scene, durable error and successful replacement; new integration opens real source | Owner chooses files using their usual Project Manager Run path |
| 3–4: Play/Pause/steps/Loop/speeds/reverse | Transport207/204 plus real integration: 0.5×/1×/2×/−0.5×, union steps/drag, signed-rate persistence and Loop | Physical shortcut and perceptual playback check |
| 5–8: cached/cold/replacement/cancel/Pause buffering | Transport: real worker publication barrier, 100/350/550 ms waits, delayed current-target text, cancelled/failed/replaced/generation reset, stable geometry and always-enabled active Pause | Natural waits depend on owner source/cache; no universal seek-latency promise |
| 9–10: index hint/durations | Hover text/drag hint, total/remaining and minute/hour rounding boundaries asserted and captured | Owner hover/drag readability |
| 11–12: camera/dock | Shell and camera suites: reset/frame/tumble, drag-release over chrome, wheel input, resize/hide/F1/recovery/focus | Physical drag/trackpad and keyboard comfort |
| 13–16: native modes/recovery/scientific overlays | Shell: windowed/maximized/interactive/hidden-dock immersive restore, enabled/disabled legends, hint, input guards. Real desktop: native Wayland fullscreen, image/state invariance, actual PID-scoped KWin external exit/recovery | Native maximized restoration is exercised by Godot state tests; separate KWin rectangle audit covers windowed/interactive/immersive, not maximized geometry |
| 17–19: rendering/volume/probe | Mixed fixture and real source preserve layer/mapping/camera state through workspace churn and recipe replay; source probe remains valid. Volume control suite exercises Quick setup and mapping/opacity independence | Full scientific matrix not rerun; no cross-renderer pixel equivalence claim |
| 20–21: scene/analysis state | Recipe2957 and shell worker-backed v2/v3 save/load; G4 render replay checks exact identities, state and output; real scene recipe round trip | Owner's existing current-schema recipes |
| 22–26: PNG/video/Jobs/overlays | Native export and status suites: minimized-parent continuation, close/reopen, live Details, cancel/complete/failure, missing FFmpeg recovery; current UI on/off and desktop-mode-independent export settings; exact replay | No full codec/fault/permutation matrix |
| 28–30: layouts/scales | 1440×900 and 1024×640 native layouts; shell also exercises 1024×640 logical at 100/125/150/200%; real source screenshots; 4K offline images | Not physical 4K or mixed-monitor DPI acceptance |
| 31: Nordic/core shortcuts | Logical-key event tests for F1/F11/Shift+F11/Esc/Space/arrows/R and numeric focus suppression; core shortcuts avoid US punctuation; WASD/QE free movement uses physical key positions | Actual Nordic hardware/layout input and Tab/Shift-Tab walkthrough remain owner-only |
| 32: reopen | New viewer after disposal reopens real source without stale Jobs/failures; two independent normal application launches exit cleanly | Owner repeats ordinary close and Project Manager Run |

These cover the applicable R01–R04 and R10–R13 gates using current alpha semantics.
Older R02 matrix language about switching playback modes is historical and does
not override #49 or the current [transport contract](UX3_MEDIA_TRANSPORT.md).

## Focused measurements and interpretation

The new probe runs 2-second cases at a 60 FPS cap, 1440×900, using existing
512 MiB rolling particle buffering. Source, renderer, camera, rate and layer
settings stay fixed when comparing dock shown/hidden. Cache warmth evolves in
sequence; the first playback pass has preparation misses and the second is warmer.
Their throughput is therefore **not a controlled causal comparison of dock cost**.

On the real source with Forward+, main-viewer callback p95 was 0.356 ms (idle,
dock shown), 0.384 ms (idle, hidden), 21.916 ms (play, shown), and 22.891 ms (play,
hidden). Maximum playback callback was 24.271 ms. First target submission took
4.704 ms; readiness took 807.626 ms; repeating that target took 25.054 ms through
readiness. The first two idle cases submitted no instrumented decode/upload work;
a later idle case completed one existing field prefetch upload (1.767 ms).
Visible playback field staging peaked at 2.043 ms; particle buffer submission
peaked at 2.977 ms. Those are CPU-side submission measurements, not GPU execution
timings. Normal one-second source-tail polling remains controller-owned.

One hundred combined workspace/layout/transport/status refresh cycles took
60.138 ms with zero instrumented scientific stages/counters or state change.
One thousand isolated status refreshes took 15.160 ms in the Forward+ status suite.
Status refreshed 9–10 times per roughly two-second interval. After 100 further
settled workspace switches, node count and reported GPU allocations were identical;
Godot static memory changed by 100 bytes and RSS by 69,632 bytes. This short test
can detect retained duplicate UI nodes but cannot establish a long-session leak bound.

The machine-readable integration reports retain both renderer measurements,
frame intervals, memory, instrumented stages and seek times. Capped frame intervals
include scheduling and rendering and do not isolate viewport GPU time. Offline
export elapsed times include startup/encoding and are not isolated shell-render
benchmarks. Production code is byte-identical to accepted `c240024`; no historical
pre-UX3 benchmark was rerun and no universal speed or memory claim is made.

## Failures, limitations and deferred work

- The first new fixture probe set `playing` directly after recipe restore, leaving
  the intentional inspection pause active. Its two playback-advance assertions
  failed. The harness now uses the real Play/Pause action; all 56 checks pass.
  No production workaround was made.
- The first real Compatibility probe passed all 56 assertions but its strict
  runner rejected Godot's “Failed to load cached shader, recompiling” warning.
  A fresh rerun after recompilation passes with a clean log; the initial warning
  is retained as evidence, not suppressed by a whitelist.
- The initial strengthened Compatibility image check compared compositor PNGs
  directly with Godot readback. Their RGB values differed consistently by at most
  one 8-bit step, while all five stages were already exact within each capture
  method. The harness now compares like capture methods independently, without
  adding a tolerance. This corrects the validation method, not the renderer.
  The Python desktop helper also emits a PyGObject `register_object` deprecation
  warning; its D-Bus checks complete successfully.
- The scientific pixel comparison covers a fixed common unobscured region across
  five fullscreen stages and two capture methods, separately per renderer. It
  does not compare the entire image, which intentionally has different chrome,
  or assert equality between Vulkan and OpenGL.
- Physical Nordic input, mixed-DPI/multiple-monitor/4K hardware, other OS/GPU,
  assistive technologies, long sessions and owner usability acceptance are not
  automated here. Native tests use the real desktop and synthetic Godot input;
  they do not drive a physical keyboard or click the Project Manager Run button.
- Frozen historical 02B/03B performance baselines were not used. One real capture
  plus small fixtures does not establish workload-wide performance. Full solver,
  scientific/analysis/matched-view, FFmpeg failure and performance matrices were
  not rerun. No source changes or research simulation reruns occurred.
- UX4 workspace organization, Settings, detached windows, persistence, independent
  legends, auto-hide bottom panels, granular export overlays, orbit/post-roll and
  other backlog/Idea work remain deferred. Existing annotation/export coupling is
  documented; #44 does not redesign it.

## Owner verification before acceptance

1. Launch through Godot Project Manager **Run**. At **1440×900**, then **1024×640**,
   open your usual layered capture. Cancel Open, replace it, then try a bad file:
   the previous scene must survive, with durable copyable failure details. Reopen
   after ordinary shutdown. Check command/status focus and hover outlines.
2. Play at **0.5×, 1×, 2× and −0.5×**; pause, step both ways and Loop. Hover and drag
   the timeline for the sample index/count hint. Click total for negative remaining.
   Check `59.9 → 1:00.0` and `59:59.9 → 1:00:00.0` on suitable captures; exact source
   values stay in tooltips/Seek. There must be no playback-mode selector.
3. Seek to cached and cold intervals, rapidly replace the target, then cancel a
   draft. Displayed time stays committed until ready; Requested time appears only
   after about **450 ms**, with no stale target or toolbar resize. During playback
   buffering, **Pause stays enabled** and immediately usable.
4. With your Nordic layout, use Tab/Shift-Tab, Enter/Esc, Space/arrows, F1/F11 and
   Shift+F11. Type in Seek without moving the camera/clock. Orbit/zoom/frame/reset,
   drag across the dock edge and release, resize/hide/recover the dock with mouse.
5. Maximize: keep the top menu. Enter interactive fullscreen from View and F11:
   top menu hides, native desktop decorations vanish, camera/dock/transport/status
   and mouse Exit remain. From windowed, maximized, interactive and dock-hidden
   states enter immersive; after three seconds only science remains. Test both
   enabled and disabled legends/probe markers. Esc restores the preceding mode.
   Use KDE's window action to leave immersive fullscreen and check chrome recovery.
6. Change and restore a volume Quick setup/range/opacity and layer visibility;
   make a source probe, selection and small analysis. Save/load current scene and
   analysis recipes. Confirm camera, source, exact IDs, mappings and explicit probe
   state survive; switching workspaces alone must not submit scientific work.
7. Save a PNG. Export short **1080p and 4K** videos with **Include viewer overlays**
   on and off, including with the desktop dock hidden/immersive. On uses the current
   right-hand shell; off follows the existing scientific-only/legend contract.
   Close the export panel, reopen via Jobs, watch live Details, cancel one job and
   complete another. Repeat identical settings and confirm the expected timing,
   appearance, outputs and unchanged live scene.

Stop for owner review. Do not merge, enable auto-merge, close #44 manually, move
Project/milestone state or start UX4/another issue.
