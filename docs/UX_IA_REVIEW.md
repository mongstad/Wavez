# Issue #14 — walkthrough and review evidence

**Design delivered for owner review; not owner-accepted.** 2026-09-20.
Baseline `68e3b5abb548d2e95ba5ae5b8e57e03d652de502`.
See the [design](UX_INFORMATION_ARCHITECTURE.md), [96-row control map](UX_CONTROL_MAP.md)
and [wireframe gallery](evidence/issue-14/wireframes.md).

## Housekeeping and authorization

Verified origin is `mongstad/SimScope`. PR #38 was merged into main at
`68e3b5a` on 2026-09-20; its head was `7c5dc52`. The workspace already had only
local main, with the completed issue branch removed. Fetch/prune removed
`origin/issue-10-volume-presets`; main fast-forward check was current, clean and
0/0 against origin/main. No local branch deletion remained necessary.
Issue #14 was the only Ready item; its current milestone was
Pre-UX3/UX4 — Validation & Maintenance. Created `issue-14-information-architecture`.
No acceptance-only changes or historical report rewrites were made.

## Refreshed current UI observations

Native Godot 4.7.2, Forward+, NVIDIA RTX 3070 Ti, 1440×900 window. A temporary
SceneTree collector instantiated the actual `main.gd`, paused playback/orbit,
opened each capture through `_open_capture`, pumped bounded preparation, and
recorded Control labels/rectangles and screenshots after settled draws. Field/
mesh settings were expanded through existing toggle signals; `ensure_control_visible`
scrolled Apply into view. This measures constructed layout, not human task time,
physical click effort, assistive technology or a scientific correctness rerun.

| Input | Inspector height initially | Timeline top, initial | Expanded layer height / timeline top |
|---|---:|---:|---:|
| Empty | 1228 | 276 | not applicable |
| Small combined | 2781 | 1507 | 4954 / 3680 |
| Particle-only | 2462 | 1188 | 2462 / 1188 |
| Mesh-only | 1948 | 996 | 2212 / 1260 |
| Field-only | 1959 | 1007 | 3842 / 2890 |
| Real field + particles | 2588 | 1314 | 4497 / 3223 |

Units are logical pixels at scroll=0; these are content positions, not all visible
controls or broken window bounds. Expanded combined opens both mesh and field.
At 900-pixel height, all loaded initial timelines lie below the viewport. The
current inspector scroll viewport ends near y=888; the data gives a reproducible
lower bound on travel needed to bring timeline top into view, not a measured scroll
wheel count. Opening one new field group also moves transport farther away.

On the real expanded field, Apply is at y=1106; lower/upper percentile labels at
1335/1397; opacity heading at 1756; Probe at 2940. Thus Faint inputs are 229/291
pixels below Apply and opacity 650 pixels below it. Scrolling to Apply resulted
in scroll=265 with its button near the bottom; percentile entries remain offscreen.
This reproduces the placement problem without assuming the last preset's label is
an active mode. [Current screenshot](evidence/issue-14/current-real-preset.png).

Small combined source: current `examples.scene_demo --small`, nine particle times,
three field times and two mesh times. Isolated examples: two samples each, two
explicit-ID particles (including an ID >2^53), a triangle mesh and a 4³ scalar grid.
They were generated under ignored `results/issue-14-review`; no new scientific
simulation or large dataset was generated. The field fixture's constant density
is useful for unavailable derivation context, not a proposed universal preset.

The read-only external input was the existing `free_collapse_simscope.ssc` in
`runs_free_collapse_v0_2/S2_20260919_204505_268717`, 11,542,897,957 bytes, opening
at t=0 with field and particles. The native review inspected its actual combined
controls; no solver was rerun, no source was edited, and no new tuning or correctness
claim is made. Full source hashing was not repeated for this layout-only review.
The [compact observation summary](evidence/issue-14/current-layout.json) retains
selected measurements; raw screenshots/tree remain ignored locally.

## Eight annotated task walkthroughs

These are design walkthroughs, not a user study. An **activation** below means one
command, chooser value selection or field edit/commit, excluding keystrokes,
file-picker navigation, scrolling and waiting. Counts are **proposed interaction
counts under stated starting context**, not measured physical mouse clicks or task
times. A chooser may take multiple physical clicks. Current paths are source-traced;
only layout positions above were freshly measured. Workspace switches and scroll
requirements are reported separately to avoid invented precision.

### W1 — Open, play, seek, frame

Start empty. [Empty](evidence/issue-14/empty.png) →
[loaded Scene](evidence/issue-14/scene.png): Open (1), pick source (excluded), Play
(2), Pause (3), drag union slider (4), Frame scene (5). Five activations; no workspace
switch and no dock scroll. A physical-time seek instead uses time input + Go
(two activations), with mode change only if needed. Requested time stays visible
while buffering; committed display/source times are not silently advanced.

Current: Open is in Capture / Export; loaded layers push transport below the fold
(see table). Camera Frame is another collapsed group or F shortcut. The commands
exist, but maintaining time/navigation context requires unrelated inspector travel.
Keyboard route: focus Open/Enter, Tab to transport; Space only outside text editors;
Left/Right step and F frame remain compatible. Disabled Play exposes preparation
reason. Empty/failed open keeps an obvious mouse Open path.

### W2 — Hide particles, apply a signed field view

Start loaded Scene with particles and field visible. In [Scene](evidence/issue-14/scene.png),
particle visibility off (1), field row (2), Appearance (3), signed channel (4),
Signed field action choice (5), Apply (6). Six activations; one workspace switch.
At 1440×900 Color and Opacity are separately named in the
[volume layout](evidence/issue-14/volume.png), no further disclosure. At compact
height, local scrolling is needed to edit the lower opacity fields; its heading
summarizes the active mapping. It never requires visiting particle or viewport controls.

Current: particle visibility is in Geometry / Guides, field channel/starting point
in Settings: field, opacity farther below. Shared inspector travel is layout-dependent;
no physical click count claimed. Refuse Signed on one-signed data without altering
old mapping; one visible translucent field limit remains. Keyboard selects the
visibility checkbox separately from row/context; no US bracket shortcut required.

### W3 — Dense core, explicit 1/99 Faint, manual edit and reset

Start Appearance on a density channel. Choose Dense (1), Apply (2), choose Faint
(3), enter lower 1 (4), upper 99 (5), Apply (6), edit a valid color bound (7).
Seven activations, no workspace switch. [Detail sheet](evidence/issue-14/details.png)
keeps inputs, saturation warning and Apply together. A subsequent Reset color is
one explicit action whose label describes linear 0–1; it does not reset opacity,
colormap, strength or quality. Manual edit leaves no active-preset badge.

Current: Dense stores 0–100. Faint already respects current inputs, but these are
229/291 pixels below Apply on the measured real layout. The proposal changes
placement, not semantics. Keyboard Tab reaches both values then Apply in reading
order. Invalid percentiles retain the draft and prior committed mapping; no silent
1/99 substitution. Exact source values remain unchanged by either display choice.

### W4 — Freeze, seek and inspect provenance

Start selected field Color. Expand Derive range (1), Freeze symmetric (2), seek via
persistent union slider (3). Three activations and one disclosure, no workspace
switch; changing percentiles would add two edits and use percentile Freeze instead.
Read derivation channel/time in Color and current source sample in fixed context.
[Volume layout](evidence/issue-14/volume.png) keeps the frozen policy explicit.

Current: color status already distinguishes derivation source/time and clipping;
transport sits later in the same scrolled inspector, so seeking can displace that
status. Proposal never recomputes a frozen range on seek, does not imply temporal
field interpolation and does not copy particle interval-scan options to volumes.
If log becomes invalid, visible unavailable status offers linear mode/manual
correction; exported invalid frames retain existing failure behavior.

### W5 — Probe, hide marker, advance time

Start selected field in Scene. Enter X/Y/Z (1–3), Probe (4), turn marker off (5),
seek (6). Six activations, no workspace switch; one contextual group and at most
local dock scroll. [Probe detail](evidence/issue-14/details.png) shows last probed
channel/time beside value and distinguishes current displayed time after seek.

Current: target/coordinates/action/result/marker toggle are adjacent below layer
settings (Probe y=2940 on the real expanded layout). Marker toggle already preserves
result and is session-only. Current result text does **not** store/display probe
time: a later consumer must add that provenance binding, and this issue does not
claim it exists. Keyboard toggle hides only the cross; screenshots honor visibility,
video excludes it. Reopening a source starts its existing new probe session.

### W6 — Choose correct recipe scope; background export

Start loaded viewer. State menu (1), Save scene recipe (2), picker action excluded;
State (3), Load scene recipe (4). Four activations, no workspace switch. Analysis
recipe actions use the same path with distinct v3 wording and results/assets options;
they are not interchangeable. Existing validation still gates applying state.

Export (1), Video (2), choose output via Browse (3; picker excluded), Start (4),
Close panel (5), Jobs (6), Cancel job (7). Seven activations for this separate export
path with defaults already inspected. [Export/error layout](evidence/issue-14/export.png)
keeps its footer fixed. If no job has started, Cancel is disabled; if running it
requests cancellation, and completion/failure is acknowledged. No implied overwrite.

Current: both recipe buttons share “inspection recipe” wording but invoke different
readers. Video close already continues the worker; reopening via Export Video
recovers its form, while current start/cancel/close/progress all scroll. No new
worker lifecycle is proposed. Errors stay in Jobs, with retained output location.

### W7 — Explicit selection, population analysis and result export

Start Selection. Bind source snapshot (1), choose source object (2), choose Persistent
IDs (3), enter exact ID (4), Create (5). Analysis workspace (6), Temporal task (7),
Population counts (8), full layer range (9), Run (10), Results (11), chosen named
result (12), Export numerical data (13). Thirteen activations excluding output
picker and optional name edit; one workspace switch plus the Results subview.
[Selection](evidence/issue-14/selection.png) → [request](evidence/issue-14/analysis.png)
→ [results](evidence/issue-14/results.png). No source/range remembered from hidden
controls; explicit selected member stays distinct from the scene-row context.

Current: selections, temporal requests, space-time and durable export occupy
separate groups; space-time reads Selections target and Temporal range/channel;
period reads selected result and Temporal range. These source dependencies were
reviewed in code, not remeasured as a timed interaction. Future adapters must expose
those effective values locally, preserve inclusive ranges/exact IDs and retain full
result export separately from bounded plots. Numerical correctness was not rerun
for these documentation-only diagrams. Keyboard accesses Run/Cancel in a fixed
footer and exact values through full-width editors/copyable result tables.

### W8 — Invalid input, unavailable data, hidden/fullscreen recovery

Start field Color. Enter invalid bound (1); [error layout](evidence/issue-14/error.png)
retains text/error plus last committed model. Correct and Enter (2), or Escape (2)
to discard draft. Two activations, no workspace switch. For ineligible Signed or
unavailable log, visible reason links to compatible data/manual/linear correction;
no silent fallback. Source availability and mapping errors remain distinct.

Hide dock via View, then [Show panels] restores it with a mouse or F1. Exit fullscreen
remains mouse-accessible or F11. The [compact layout](evidence/issue-14/compact.png)
keeps transport/status outside scroll. A keyboard-only route uses named menus,
Tab/Shift-Tab and Enter; focused text fields consume camera/playback shortcuts.
Current F1's hide path also hides the mouse restore affordance; the proposed recovery
is a later shell change, not a fix included here. Below-minimum 512×320 logical
space is an unresolved native feasibility decision, not claimed supported.

## Review checks and limitations

- Source inventory: 96 grouped rows, each with current labels, verified file/symbol,
  scope/destination, disclosure, behavior/refusal, state ownership and later gates.
  Dynamic choices are families, not an asserted fixed widget total. Semantic IDs
  are explicitly proposed; existing state keys and label aliases remain mapped.
- Native layout review: 14 recorded states across six input contexts, clean final
  Godot log. Real combined, synthetic combined and three isolated layer types opened.
  No physical mouse/keyboard study or newly implemented UI was tested.
- Static diagrams: twelve primary wireframes rendered and visually inspected,
  including 1024×640 and 1440×900. 4K diagrams rendered at 100/125/150/200% logical
  allocation; [scale overview](evidence/issue-14/scale-review.png). These verify
  diagram layout, not native widgets, physical monitors or accessibility compliance.
- Documentation local links/anchors, source-symbol references, inventory IDs,
  image dimensions and changed-file scope checked by the retained review checker.
  Git whitespace check passes. Godot headless editor import completed cleanly.
  Runtime/shader/recipe/dependency trees unchanged.
- Full scientific suite, solver runs, export videos, performance benchmarking,
  compatibility backend, screen readers, physical 4K/mixed DPI and human usability
  timing were deliberately not run. They do not validate a documentation-only
  design and remain migration gates.
- Development corrections: the first isolated fixtures omitted required identity
  metadata (then mesh stable identity lacked vertex IDs); corrected to explicit
  particle IDs and a non-stable mesh before the final collection. Initial diagram
  font path was unavailable; used installed Noto Sans for schematic text. Initial
  compact diagram overflow and unsupported arrow glyphs were fixed after inspection.
  Earlier incomplete collections are not used as final evidence.

Diagrams approximate shared typography using installed Noto Sans; they are not
Godot-theme pixel acceptance. Source data, computational behavior and production
controllers are untouched. A traceability review cannot prove every future consumer
will preserve behavior; the migration gates remain mandatory when implemented.

## Exact owner review and next decision

1. Open Scene, Volume and Compact diagrams at native image size. Trace W1–W4 and
   decide whether one right dock plus persistent essentials is the desired shell.
2. In the Detail sheet, start Faint after Dense with 0/100, then explicitly choose
   1/99. Verify the design makes saturation, one-time Apply and independent resets
   understandable without generic help. Review the compact opacity scroll tradeoff.
3. Trace W5 and approve or revise the proposed last-probe timestamp requirement.
4. Trace W6–W7: choose v2 versus v3 deliberately, follow explicit source binding,
   and find result export and running-job cancellation without hidden dependencies.
5. Trace W8 using only named keyboard/menu paths; review draft retention, recipe-load
   conflict handling, mouse recovery and the below-minimum-window open question.
6. Sample the control map against familiar mesh, comparison/matched, selection/group
   and performance controls; report missing destinations or wrong ownership before
   approving the design. Review the five decisions in the architecture document.

Recommendation for later work: approve/revise this design first; explicitly authorize
UX3 shell/transport/status next; review it before bounded UX4 consumers. #37 legend
placement is reserved only. #9/#24/#32 and later UX milestones remain outside scope.
No implementation issue, board change, merge, closure or milestone advance is made.
