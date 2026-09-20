# UX3 persistent transport — issue #42

Implemented, **pending owner review**. Issue #42 was the sole Ready item on Project 1.
Work uses the owner's existing linked branch
`42-ux3-transport-001-migrate-playback-and-seek-into-the-persistent-transport`,
initially identical to accepted `main` at `884ea73` (owner-merged shell PR #45).
No acceptance-only branch/PR or historical-report rewrite was created.

## Behavior and ownership

Issue #49 refines the current presentation as described in
[Media-style playback timing](UX3_MEDIA_TRANSPORT.md). Original review metadata
and validation below remain historical.

The bottom transport is always reachable without dock scrolling, including with
Hide panel/F1 and fullscreen. Normal desktop height is 64 logical pixels; below
1200 logical pixels it reflows to two rows at 104 pixels. Text is not scaled down.
The dock and splitter stop above it, and the existing particle legend moves above
it. The scientific viewport remains full-frame: no camera/projection change.
Issue #43 now places the transport above a 40-pixel [status line](UX3_STATUS.md)
and adds Jobs to its options row. The validation below records the original #42
review checkpoint; it has not been rewritten as new evidence.

Previous sample / Play-Pause / Next sample, the discrete **Sample index** slider,
index/count on hover or while dragging, elapsed/total/remaining playback
duration, **Seek…**, time mode, **Playback speed** and Loop are present. The existing buttons, slider and mode selector
are reparented, retaining their signal connections and readiness ownership.
Legacy playback-section/slider keys remain available to recipes under an invisible
compatibility parent, without a duplicate scrolling UI. The offline renderer
still constructs its original presentation and has no transport.

The slider selects sorted union timestamp indices. Equal slider distances do not
mean equal elapsed time. Playback duration is now a one-decimal presentation at
nominal 1×, derived only from the committed visible clock. Exact displayed source
time remains in the elapsed tooltip; differing **Requested time** reads the
submitted target from the active particle/field/mesh preparation controller and
uses five decimal places with an exact tooltip. Internal clocks, persisted state
and Seek Target retain full precision. A draft never writes those readouts.
Source times and sampling status remain per-layer in Scene layers. Unknown units
are not inferred.

**Seek… → Seek time → Target → Go** invokes the existing seek path. It uses the
accepted float64 number-field component: finite scientific notation, full round-trip
text, explicit local commit, silent cancellation and inline validation. Enter in
the editor commits its local draft only; **Go** alone submits. Cancel submits
nothing. Escape in the editor restores committed text; outside editing it closes
the dialog. Go validates the recorded interval; capture replacement dismisses a
stale form. Invalid input retains the last visible scene and the draft.

Time mode uses existing `index` / `physical` state with visible labels **Sample
index** / **Recorded time**. Playback speed edits the same `playback_fps` /
`physical_rate` through a relative multiplier against defaults 12 / 1. Negative
multipliers preserve reverse behavior; unchanged numeric commits and restoration
preserve exact saved rates. Loop invokes the same controller callback previously
used by the inspector. No new recipe fields or persistence semantics are introduced.

No union-axis, particle/mesh interpolation, scalar/field Hold, independent cadence,
source timestamp, capture-byte, buffering, cache/preparation-window or video-time
algorithm changes. FIELD-001, full workspace migration, touch, shortcut redesign,
final artwork and #43 are excluded.

## Validation

The [passive-precision review refinement](evidence/issue-42/precision/README.md)
passed 62 focused native checks per renderer. The original implementation runs
below remain historical.

Godot 4.7.2 native Forward+ and Compatibility on the existing Fedora KDE/Wayland
host, NVIDIA RTX 3070 Ti. [Evidence and reports](evidence/issue-42/README.md).

| Focused check | Result |
|---|---|
| Transport Forward+, synthetic + retained real capture | 58 checks passed |
| Transport Compatibility, synthetic | 55 checks passed |
| Existing shell native Forward+ | 97 checks passed |
| Live union timeline, native Forward+ | 28 checks passed |
| Recipe/state ownership, headless | 3,051 checks passed |
| Async particle playback equivalence, headless | 2,457 checks passed |
| Mesh/static/mixed-cadence regression, headless | 2,731 checks passed |
| Existing performance/readiness maintenance, headless | 66 checks passed |
| Existing playback lifecycle, headless | 51 checks passed |

The transport suite exercises native controls, exact/fractional seeks, numeric
focus and Enter/Escape behavior, Cancel, rate modes, reverse/Loop, union-index step
and slider, requested/displayed separation behind a real worker publication
barrier, and final-target-only rapid seek completion. One hundred refresh calls
produce no instrumented preparation/decode/upload/scientific work or state change.
This is not a universal CPU/GPU performance bound. Existing suites cover independent
particle/mesh/field clocks, static objects, held/after-last samples, cache bounds,
readiness and recipe restoration. Synthetic and retained source hashes are unchanged.

1440×900 and 1024×640 native screenshots verify layout and the bounded seek form.
The shell suite also retains its logical-scale, hide/recovery and fullscreen
checks. Rendered screenshots are UI review evidence, not scientific pixel-equivalence
claims. Original shell/design reports remain historical and unchanged.

Reproduce from the repository root (each output directory must be new for transport,
shell, recipe and mesh validators):

```sh
python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir results/transport-forward --renderer forward_plus --real-capture /path/to/retained.ssc
python tools/validate_viewer_transport.py --godot /path/to/godot --output-dir results/transport-compatibility --renderer gl_compatibility
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir results/shell --renderer forward_plus
python tools/validate_scene_timeline.py --godot /path/to/godot --label transport-timeline --renderer forward_plus
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir results/recipes --renderer headless
python tools/validate_scene_playback.py --godot /path/to/godot --output-dir results/playback --renderer headless
python tools/validate_mesh_playback.py --godot /path/to/godot --output-dir results/meshes --renderer headless
python tools/validate_performance_maintenance.py --godot /path/to/godot --output-dir results/readiness --renderer headless
```

Development failures corrected: initial sandbox import could not access sockets or
editor settings; authorized native import passed. An unsupported dialog signal was
replaced with visibility notification. The old shell focus test targeted the removed
Playback disclosure/inline input; it now uses a visible section and modal input.
Visual review caught excessive dialog growth after invalid drafts; minimum content
width and explicit popup size now keep Go/Cancel visible, with a regression assertion.
The mode selector's inherited inspector clipping was removed in its new home.

Limitations: old frozen 02B/03B benchmark paths are unavailable. The existing retained
FreeCollapse capture was used read-only instead, without rerunning any solver.
Full external performance comparisons, complete scientific/video/FFmpeg matrices,
physical mixed-DPI/4K, assistive technology and long-session comfort were not rerun.
The headless suites establish semantics, not native image quality. The compact
allocation is 104 pixels (two usable rows); no status-line space is claimed for #43.
The old hidden playback disclosure key remains readable but no longer controls the
visibility of the persistent transport. Exact long clock values remain available in
tooltips; editing retains the component's full-precision horizontally scrollable text.

## Exact manual owner verification

1. Relaunch through Project Manager Run. At 1440×900 and 1024×640, open a representative
   layered capture. Confirm transport controls fit and remain accessible with the dock
   open, scrolled, hidden, and during fullscreen. Confirm Go/Cancel fit inside Seek time.
2. Play/pause, previous/next and drag Sample index in both modes. Check the displayed
   union index, time and unequal per-layer source times. Volumes must Hold between their
   samples; no new interpolation or change to last/static sample behavior is expected.
3. Open Seek time. Type a fractional target and press Enter: the visible scene/clock
   must not change. Cancel must not seek. Reopen, type and click Go. Try invalid and
   out-of-range targets and Escape. Verify finite scientific notation and exact text.
4. On a cold seek, confirm Displayed time stays on the visible scene while Requested
   time shows the submitted target and Play is disabled. Edit a different draft without
   Go; the submitted target must stay unchanged. Submit several rapid replacements;
   only the latest completion may become visible.
5. Change rate in each mode, including a negative rate, and toggle Loop at the boundary.
   Confirm numeric focus suppresses Space/arrow/camera shortcuts. Outside editors,
   existing shortcuts must still work. Save/restore existing scene and analysis recipes;
   rates restore without unsolicited seeks, and playback remains paused where specified.
6. Verify camera, scientific controls, field Hold, source bytes and video time settings
   retain their accepted behavior. Status/Jobs and workspace migration are not included.

Stop for owner review. Do not merge, enable auto-merge, manually close the issue,
move it to Done or begin #43.
