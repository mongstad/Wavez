# UX4 focused scientific tools — issue #69

Implementation is **pending owner review**. The only Ready item on 2026-09-23
was #69, UX4-TOOLS-001. The owner-created linked branch
`69-ux4-tools-001-create-focused-scientific-tool-dialogs` started clean at
`b2f0384`, equal to local and remote main after owner-merged PR #75. The accepted
#66/#67 predecessors are also in that history. Remote references were pruned;
the previous local issue branch was already absent. At publication recheck, the
Project reported In progress; no Project write was performed by this task.

This finishes the existing Tools destinations. It does not migrate workflows
back to the permanent panel, change its Particles / Fields / Meshes structure,
or begin #70's general copy audit or #71's milestone acceptance.

## Composition and ownership

One nonmodal host still starts hidden. Close hides it without cancelling work.
Existing widgets, signals, controller references and drafts are reused. Section
selectors show one shallow task section at a time and reset scroll position when
switching. Long scientific forms scroll; primary analysis/selection actions and
current refusal/status text remain outside that scrolling area. The host uses
600×720 logical pixels when available and fits within a smaller viewport.
1440×900 and 1920×1080 remain desktop targets; 1024×640 is a scrolling fallback.

| Destination | Refined presentation and retained ownership |
|---|---|
| Selection | Source and gestures, Edit selection, Definition, Surfaces and cohorts, Groups. The same name and selection list follow the active section. Definition shows only applicable address/shape and predicate inputs. Exact IDs remain text. Create and Cancel remain explicit; gestures remain nonmodal. |
| Temporal | Request, Scientific options and Shared request sections; fixed Run and Cancel. |
| Space time | Spatial task and tracer weighting sections plus Shared request. Uses the **same input widgets** for source scope, range, channel, component, coordinates, units, weights and gap settings as Temporal. No cloned defaults. |
| Diagnostics | CSV import and parsing/gap sections. Import remains explicit. |
| Compare | One comparison task, shared original result/series selectors and diagnostic name draft, original left/right bindings, mapping, schedule and plot. |
| Matched runs | Left source, Right source, Common meaning and Output sections. Existing side dictionaries and shared output settings; fixed Prepare, Render and Cancel. |
| Period | Original result/series selection and period controls. Edit range reaches the shared Temporal range; Estimate remains explicit. |
| Bookmarks | Existing save, go, offset and delete actions. Time mapping links to the existing Compare inputs; shared name draft remains one widget. |
| Results | Existing result/series controls, plot, member lookup, values, paging, remove and recompute. Original result selector is reused in Compare and Period. |
| Mapping | Original particle Logarithmic, Cyclic phase and Clamp. No duplicate channel, map or range editor. |
| Quick setup | One field target at a time; Dense core, Faint structure or Signed field, then Apply. Original percentile inputs move here for Faint structure and return to Derive range. Eligibility messages remain visible; explanations become tooltips. These remain one-time actions. |
| Derive range | Explicit Particles or field target. Original interval actions, symmetric/percentile sample actions, and separate color/opacity reset scopes. No new mesh or interval-field derivation. |
| Slice | Explicit Particles or field target. Existing fractional particle slice and world-plane field operations remain distinct, with original immediate callbacks. |
| Clipping | One field target, existing Enabled and X controls. |
| Isosurface | One field target, threshold, Extract and Remove. Existing shared extraction result/refusal/provenance status is retained. |
| Source probe | Explicit field, channel and world coordinates. Existing numerical interpolation and marker controller; results now carry an event-time stamp. |
| Performance | Labeled decoded cache, particle playback buffer, field and mesh preparation metrics, and GPU budget. Original allocation scopes and controllers remain separate. GPU tooltip states the scope and units; it is not a process memory ceiling. |
| Geometry | Existing declared geometry/provenance and Load override / Clear override controls, fitted to the focused host. Guide toggles remain in View. |

Field tool target selectors are presentation only. They do not change permanent
panel selection, probe target, visibility, sources, samples or scientific
requests. Capture/recipe-driven UI rebuilding recreates presentation selectors
while preserving the active tool target when it still exists. Navigation uses
no data reads, preparation or uploads. Jobs now routes `space_time` to Space time
and result operations to Results, while retaining the existing controller.

The 96-control disposition is preserved. No permanent-panel control destination,
state/recipe schema, export schema, scientific default or calculation changes.
Current README, status and roadmap point here; #66–68 historical design/review
reports and evidence are preserved verbatim.

## Probe provenance

Only an explicit Probe event records the capture path, existing capture UUID and
committed extent, field object, selected channel, world coordinates and
`GridView.data.time`. This is the **actual prepared source sample time**, not
later playback time. Full capture identity is available in the stamp tooltip.
The displayed value remains the existing exact JSON numeric representation.

The channel choice reads available channels from the already prepared source
sample using the existing trilinear probe. Its default numerical path is
unchanged. Probe neither prepares a hidden field nor changes its display channel;
unprepared channels and unsupported coordinates retain an unavailable result.
The tooltip explains that boundary. Marker visibility remains under View.

A changed target, channel, coordinates or prepared sample marks the old result's
context stale without rewriting its stamp or value. Held samples can therefore
retain their source time while playback advances. Probe draft, result, stamp and
marker remain session state through recipe restoration; opening a capture starts
a new session. Nothing is added to recipes or video exports.

## Validation

Godot 4.7.2 on NVIDIA RTX 3070 Ti. Synthetic captures only. Reports and selected
native screenshots are in [issue-69 evidence](evidence/issue-69/README.md).

| Gate | Result |
|---|---|
| Focused tools, Compatibility | 1,925 checks PASS |
| Focused tools, Forward+ | 1,925 checks PASS |
| Existing simulation panel, Compatibility | 221 PASS |
| Production shell, Compatibility | 1,043 PASS |
| Jobs/status, Compatibility | 67 PASS |
| Recipe/state, headless | 2,697 PASS |
| Selection, headless | 31 PASS |
| Temporal, headless | 23 PASS |
| Space time, headless | 36 PASS |
| Diagnostics, headless | 23 PASS |
| Maintenance UI, Compatibility | 37 PASS |
| Field color, Compatibility | 138 PASS; render export verified |
| Field opacity, Compatibility | 98 PASS |
| Field presets, Compatibility | 99 PASS; three preset exports verified |
| Matched runs, Compatibility | 50 PASS; both GPU exports and source identities verified |
| Probe marker, Compatibility | 33 PASS; two four-frame videos have identical pixels/timing and match marker-free baseline |

The focused gate traverses every Tools destination and task section, checks
layout at all three sizes, reuses exact draft values, checks conditional Selection
inputs and percentile ownership, verifies source-time staleness and recipe
retention, tests Jobs routing and closing an active source query, and checks
normal buffered Performance availability. Navigation snapshots and profiling
show no scientific state or work changes. Source hashes remain unchanged.
Native screenshots were inspected, including dense sections, fallback probe,
normal Performance and matched-export frames.

Initial development runs exposed freed-node iteration during group unwrapping
and an unparented hidden guide label; both were corrected and final logs are
clean. A preset assertion initially looked for explanatory prose in the form;
it now checks the preserved tooltip. Existing maintenance/shell UI assertions
were updated for task sections and footer actions; numerical oracles were not
weakened. Editor import, UID sidecars, whitespace and Python compilation were
checked. These results are implementation evidence, not owner acceptance.

Physical mixed-DPI/4K monitors, assistive technology, prolonged interactive use,
external scientific captures, the full scientific suite and the final UX4
milestone matrix were not run. Native selection algorithms and nonmodal hosting
were exercised; comfortable mouse gesture use still needs owner review. Complex
forms intentionally scroll. Tool page choices and probe provenance are not
persisted across application restarts. No promise of a global process memory
ceiling or background channel preparation is introduced.

## Owner verification

1. Launch with and without a capture. Confirm no Tools window appears until a
   menu action. Confirm the Particles / Fields / Meshes panel and top menus remain
   as accepted in #68.
2. Open Selection, bind a capture, and select a layer. Switch sections; confirm
   name and selected entries persist. Try IDs, sphere and slab definitions,
   predicates, cohorts and groups. Use viewport rectangle/lasso gestures while
   the window is open; close during a query, then reopen through Jobs.
3. Edit an exact range and channel under Temporal → Shared request. Open Space
   time → Shared request and confirm the same draft. Run each task and inspect
   results. Test Compare, Period and Bookmarks with explicit bindings; check
   that changing sections alone submits nothing.
4. In a capture with two fields, switch tool targets for Quick setup, Derive
   range, Slice, Clipping and Isosurface. Confirm the permanent panel's selected
   object and visibility do not change. Apply Faint structure with edited
   percentiles; reopen Derive range and verify the same input values and separate
   reset scopes. Try an incompatible preset and inspect its refusal.
5. Probe a prepared field between recorded samples. Check its actual held source
   time, object, channel and coordinate stamp, plus full identity in the tooltip.
   Advance to another source sample: the old result must stay unchanged and show
   stale context. Re-probe, toggle View → Probe marker, and restore a recipe.
6. Check Performance's separate budgets/readiness and Geometry's override
   actions. Confirm View still owns guides and global Bloom.
7. Prepare a small matched pair, render, close the tool and reopen via Jobs.
   Verify left/right drafts, output, progress and explicit cancellation. Save and
   reload analysis/scene recipes and export a numerical result.
8. Inspect long sections at 1440×900 and 1920×1080, then 1024×640. Scroll all
   inputs into view and confirm the action footer remains available. Review
   labels, spacing, focus recovery and warnings before accepting the PR.
