# UX4 command menus — issue #67

Implementation **pending owner review**. Baseline `34edfca`, owner-merged #66 in
PR #72. Issue #67 was the only Ready item on Project 1; the existing linked branch
is `67-ux4-menu-001-build-file-view-and-tools-menus`. The accepted
[UX4 design](UX4_DESIGN.md) supplies the hierarchy and scope. This slice does not
implement #68's simulation-panel layout or #69's final scientific form composition.

## Implemented behavior

The command bar now exposes File, View, Tools and Help, with the exact 54-label
hierarchy in the design. The separate Open, State and Export bar buttons/menus
are removed. The capture name retains source details. Frame scene, Reset camera
and Navigate remain viewport actions; Navigate retains Free camera and Auto orbit
and opens the existing Orbit speed editor.

File owns Open capture, scene/analysis state and Image/Video/Data export. The
existing picker, cancellation, source validation and worker callbacks are reused.
Image opens a small host with the existing sidecar option and explicit Image
button. Scene and analysis state hosts retain explicit Save/Load actions and the
same shared folder, quota and deadline controls used by numerical export. Opening
a host does not save or export. Scene save retains its existing promotion to v3
when selections require it. Copy state calls the existing inspection snapshot.
Resolve input is enabled for the current generation's unresolved-source restore
failure; it invokes the existing explicit input locator. The worker's existing
error code is retained only as presentation availability metadata.

View owns panel visibility, fullscreen, immersive, session-only probe marker,
guides and viewing presets. Preset menu text Minimal maps to the existing
`Minimal / Presentation` state value. Unavailable source-dependent actions are
disabled; source/channel names are not rewritten. Help exposes Shortcuts and the
repository handbook in a read-only text dialog. Packaged builds without the
handbook file report it unavailable; no new packaging or external dependency is
introduced.

Tools uses one nonmodal, scrollable host containing only the selected task.
It starts hidden before entering the scene tree and opens only on an explicit
command; [startup regression evidence](evidence/issue-67/tools-startup/README.md)
covers the PR #73 launch-popup correction. The
existing controls and controllers are retained once; navigation does not create
requests or bind a source. Selection remains usable with viewport gestures.
Temporal results and the existing diagnostics subsections have separate Results,
Diagnostics, Compare, Period and Bookmarks destinations. The common diagnostic
name/status controls move between those surfaces instead of being cloned. Shared
request context is shown read-only; edit the existing Temporal inputs through its
menu before Space time or Period. Final shared-context form composition remains
#69 work.

Mapping, Quick setup, Derive range, Slice, Clipping, Isosurface and Source probe
are reachable focused hosts. Field operations retain explicitly labeled source
object blocks and their current callbacks. Quick setup consumes the same
percentile controls exposed in Derive range, with no new scientific defaults or
independent percentile state. #69 owns final target/form composition and probe
provenance presentation; this slice preserves the existing probe result behavior.

Performance owns decoded cache controls, particle buffer policy and metrics,
field/mesh preparation metrics and the GPU budget. Geometry owns existing
metadata and override operations; guide toggles live only in View. Scene-layer
tool controls are rebuilt and cleaned up with their owning source/recipe UI.
A successful capture replacement closes the tool host; a failed replacement
retains the prior usable source and UI. No source-bound controls survive through
stale callbacks to a destroyed layer controller.

Closing a tool hides it without cancelling jobs. Jobs reopens the matching task
and retains existing cancellation behavior. Each task keeps its in-session scroll
position. Immersive entry hides the tool without restoring focus into hidden
chrome. These UI positions and new hosts add no recipe fields.

## Owner-review correction: permanent-panel metadata

PR #73 removes the duplicate capture filename/“Current capture” header and the
capture, sample/interpolation and layer diagnostic blocks from Scene/Appearance.
The existing title-bar source control and status area remain; no new permanent
source label is added. Control order and grouping are unchanged.

The status area's **Details…** and title-bar source details use the same current
metadata snapshot: capture identity, SIMSCP3/sample counts, frame/population and
interpolation/ID/held-scalar text, cache information, complete layer descriptions
and structured metadata (including dtype/stride), plus full color-policy, finite
range and clipping diagnostics. Text wraps and scrolls in the existing dialog;
reopen it for a fresh snapshot. Existing status failures and job details remain.

Only an active **⚠ Color clipping** or **⚠ Color unavailable** indication remains
beside the affected field controls. It clears when the underlying diagnostic
clears; the explanation is in Details. No scientific computations, recipe fields,
source values or callbacks change. This correction does not start #68.

Correction checks and screenshots: [metadata review evidence](evidence/issue-67/metadata-review/README.md).

## Owner-requested Advanced refinement

One **Advanced** expander directly contains Size by, Brightness by, Recorded
history [T], Exposure, Gamma and Bloom. Trails and Advanced Post-processing no
longer have separate expanders. This explicit owner instruction supersedes the
previous Advanced-label restriction for these controls; no nested groups or wider
#68 redesign are introduced. Existing callbacks and scientific values are retained.
The combined expander keeps the Size/Brightness recipe key; retired disclosure
keys remain inert. See [validation](evidence/issue-67/advanced-refinement/README.md).

## State and sidebar boundaries

Removed sidebar command paths include Capture/Export, Selection, all analysis
forms, analysis state/export, probe marker, Performance and Geometry commands.
The Selection/Analysis workspace shortcuts are removed too. Scene and Appearance
remain until #68; retained simulation controls still use their existing scrolling
inspector and section arrangement. No desktop density redesign, new Object
selector or one-level simulation grouping is implemented here.

Moved legacy section expansion keys remain inert recipe data, so old scene/video
payloads round-trip without creating hidden action buttons. The viewing preset
selection is a model value rather than a hidden duplicate OptionButton. Slider
and check-state keys retain their old identities even where visible labels are
shortened. Exact IDs, source data, scientific definitions, color/opacity mappings,
worker budgets, capture timing and export schemas are unchanged.

## Validation

Small repository-generated fixtures only; no scientific solvers or external
research data were run. Commands are reproducible from the repository root with
new output directories and an external Godot executable:

```sh
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/menu-shell --renderer gl_compatibility
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir /tmp/menu-recipes --renderer headless
python tools/validate_maintenance_ui.py --godot /path/to/godot --output-dir /tmp/menu-forms --renderer headless
python tools/validate_probe_marker.py --godot /path/to/godot --output-dir /tmp/menu-probe --renderer forward_plus
python tools/validate_volume_presets.py --godot /path/to/godot --output-dir /tmp/menu-presets --renderer gl_compatibility
python tools/validate_video.py --godot /path/to/godot --output-dir /tmp/menu-video --renderer gl_compatibility --overlay-ui
```

The shell test covers live menu hierarchy against the accepted design, disabled
states, all tool destinations, single-form ownership, absence of competing sidebar
commands, no instrumented scientific activity during navigation, actual numerical
export, v2/v3 restore, source replacement, fullscreen/immersive recovery and
1440×900, 1920×1080 and 1024×640 layouts. Recipe tests retain exact numeric/state
comparisons while updating references to removed presentation controls.

Results and selected native screenshots are in [the evidence index](evidence/issue-67/README.md).
The new evidence is for this issue; historical #66 and UX3 evidence is unchanged.

Known limits: these are minimal focused hosts, not the final #69 workbenches.
Some existing internal scientific form groups/help remain for #69/#70; the
permanent simulation panel is still awaiting #68. Physical mixed-DPI monitors,
assistive technology and long-session comfort have not been validated. Automated
coverage and screenshots do not establish owner acceptance.

## Exact owner verification

1. Launch the viewer normally at 1440×900, then 1920×1080 and 1024×640. Inspect the
   four menus, native submenus, capture-name source details and viewport actions.
   Confirm the compact fallback stays readable and F1/mouse recovery still work.
2. Open a layered capture. Cancel Open, attempt invalid replacement, then replace
   successfully. Confirm retained source/error behavior and that tool controls
   refer to the current source after replacement.
3. From File, copy state; save/load a scene; bind a source and create a selection,
   then save/load analysis. Verify exact IDs and mappings. Try Image with sidecar
   off/on, Video, and Data after a completed small analysis. Cancel each picker
   once. Confirm opening a form never starts the operation.
4. Toggle View probe marker and each applicable guide. Choose Scientific and
   Cinematic, then change Point rendering independently. Verify preset semantics,
   F11, immersive, Esc and mouse recovery with the dock shown and hidden.
5. Open every Tools leaf. Check source binding and selection gestures, existing
   Temporal/Space time inputs, CSV/Compare/Period/Bookmarks, Results and Matched
   runs. Confirm only that task's form appears and jobs continue when it closes.
6. Exercise Quick setup with percentile inputs from Derive range, independent
   opacity/color, field and particle Slice, Clipping, Isosurface and Source probe.
   Inspect Performance and Geometry. Ensure migrated commands are absent from the
   permanent sidebar, and Jobs reopens the correct host.
7. Repeat state restore while a field tool is open. Confirm rebuilt controls work
   once, exact values persist, and no stale or duplicate controls appear.

8. Confirm Scene/Appearance has no repeated capture header or metadata paragraphs.
   Expand a field: only a concise clipping/unavailable warning may remain. Open
   the status area's Details to inspect the full range, interpolation, sample and
   layer information; seek or replace the source and reopen Details to verify it
   reflects the current source. Controls should retain their previous ordering.

Stop for owner review. Do not merge, auto-merge, close #67, change Project state,
or begin #68/#69 or any other issue.
