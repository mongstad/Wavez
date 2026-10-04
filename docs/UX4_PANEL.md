# UX4 simulation panel — issue #68

Implementation **pending owner review**. The only Ready issue verified on
2026-09-23 was #68, on the existing linked branch
`68-ux4-panel-001-build-the-flat-simulation-panel`. Baseline `3dddf71` is the
owner-merged PR #73; design #66 was merged in PR #72. No branch was created or
switched. Remote references were pruned; the previous local issue branch was
already absent. The working tree and local/remote main matched before work.

The current #68 issue and accepted #67 owner refinements supersede the older
panel sketch where they differ. [The design](UX4_DESIGN.md), [menu report](UX4_MENUS.md)
and prior evidence remain historical records; this document describes the current
panel implementation. This slice does not implement #69's final focused tools,
#70's broader copy audit or #71's milestone acceptance.

## Presentation and retained controls

The permanent panel now uses **Particles**, **Fields**, **Meshes** tabs. At compact
widths the same names appear in a category dropdown. Field and mesh categories
have separate Object selectors, with exact source IDs and one object's form at a
time. A hidden object stays selected; selecting an object does not show it, bind
analysis/selection/probe state, change channels or submit work. Objects and group
expansion are session presentation state. Recipe restoration preserves them while
rebuilding the existing field/mesh controls. Opening a replacement capture creates
fresh object choices for that source. Missing categories show concise empty states.
The three category tabs have no tooltip that repeats their visible names; useful
explanatory tooltips on other controls remain available.

| Category/group | Frequent controls retained |
|---|---|
| Particles / Rendering | Particle size, Brightness, Point rendering |
| Particles / Particle Filters | Existing type toggles, as a sibling of Rendering |
| Particles / Color Mapping | Color by, Colormap, Range policy, Symmetric about zero, Manual Minimum/Maximum, Invert, Show legend |
| Particles / Advanced | Size by, Brightness by, Recorded history [T], Exposure, Gamma |
| Fields / Rendering | Visible, Volume ray march, Ray step |
| Fields / Color Mapping | Channel, Color range minimum/maximum, linear/log color, concise exceptional color indicator, Colormap, Show legend |
| Fields / Opacity | Linear scalar/Magnitude mapping, zero/full-opacity thresholds, Opacity strength |
| Meshes / Rendering | Visible, Wireframe |
| Meshes / Color Mapping | Channel (including fixed mesh color), Range minimum/maximum, Colormap, Show legend |
| View / Global effects | The single existing global Bloom slider |

Every control keeps its existing callback and model. Opacity strength still means
extinction per world unit and Ray step still uses world units; tooltips retain
those definitions. No field/mesh Exposure or Gamma controls are invented.

Known verbose particle type descriptions become **Density tracers** and
**Coverage tracers**. Other descriptions retain their existing label. Full source
descriptions and numeric type IDs remain in tooltips; original control keys and
serialized filtering IDs remain unchanged. Source metadata is never rewritten.

The #67 consolidated Advanced group is retained as explicitly approved, despite
the older #66 prohibition on that label. The redundant particle visibility
checkbox stays removed. The #68 requirement intentionally moves Particle Filters
out of Rendering, undoing only its temporary #67 nesting.

## Shallow disclosure and desktop sizing

Group headers use a right/down chevron, a flat underlined header style and
12-pixel child indentation. Action buttons retain their bordered button treatment;
value selectors retain dropdown arrows. Groups have 8-pixel internal spacing and
12-pixel bottom separation, 36-pixel headers and at least 32-pixel input targets.
Particle slider labels use the normal theme font size instead of the old 12-pixel
override. The nested Advanced normalization disclosure is removed; its manual
bounds remain directly inside Color Mapping. There are no nested expanders.

On a fresh application session, every Particles, Fields and Meshes group starts
collapsed, including groups first made available by opening a capture. Disclosure
choices then remain session UI state: capture replacement, category/object
switching and layer-control rebuilds do not reset matching groups. Field/mesh
choices are retained by category, source object ID and group title, including
when an object temporarily disappears. New logical groups start collapsed.
The existing recipe-owned particle `sections` values are still honored when
explicitly restored; field/mesh disclosures remain outside recipe state.
See [launch-default validation](PANEL_DISCLOSURE_VALIDATION.md).

1440×900 logical pixels is the primary target; 1920×1080 is the roomy check.
1024×640 remains a readable fallback with the category selector, independent
vertical scrolling and existing hide/show recovery. Fully expanded groups may
scroll at any size; controls are not squeezed to meet a no-scroll height budget.
The existing narrower-window temporary-sheet and fullscreen/immersive behavior
remain. Logical 125%, 150% and 200% scaling is covered; physical mixed-DPI monitor
behavior is not claimed.

## Scientific ownership and compatibility

Particle Exposure and Gamma already feed particle shader uniforms only. Particle
size, brightness, rendering mode, color mapping and filters retain particle-owned
state. Field and mesh controls retain the existing dictionaries keyed by exact
object ID, independent field color/opacity models and existing refusal behavior
(including the one-visible-translucent-volume limit). Context navigation changes
only form visibility. No new scientific defaults, shaders or algorithms are added.

Bloom is environment-wide. It moves to **View → Global effects**, a small focused
window explicitly labeled “All simulation content.” There is one global slider,
not category copies. Existing preset eligibility and renderer behavior remain.
The menu contract is unchanged except for this #68-authorized View entry.

Existing visual-state names, slider keys, particle channel preferences and inert
legacy disclosure keys remain readable and round-trip. New field/mesh disclosure
keys are session-only. New object choices are not scene/analysis recipe fields.
The export presentation schema stays unchanged: workspace values now select the
three categories, old outlying valid values clamp to the final category, and
workers use their source's initial field/mesh object choice. Exact per-object panel
selection is not added to export jobs in this slice; scientific scene state is
still restored independently. Existing export timing/camera/output behavior is
unchanged. Scientific-only before/after pixels match on the recorded fixtures.

Low-frequency controls remain at the accepted #67 destinations: File state/export,
Tools analysis/selection, Mapping, Derive range, Quick setup, Slice, Clipping,
Isosurface, Source probe, Performance and Geometry; guides remain in View and
camera navigation beside the viewport. Metadata remains in Details and active
color exceptions remain concise. Tools starts hidden. No duplicate panel actions
or documentation expanders are introduced.

## Validation and owner review

See [the evidence index](evidence/issue-68/README.md) for exact results, initial
failures and limitations. Reproduce from the repository root with an external
Godot binary and fresh output directories:

```sh
python tools/validate_simulation_panel.py --godot /path/to/godot --output-dir /tmp/panel-ownership --renderer gl_compatibility
python tools/validate_viewer_shell.py --godot /path/to/godot --output-dir /tmp/panel-shell --renderer gl_compatibility
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir /tmp/panel-recipes --renderer headless
python tools/validate_volume_color.py --godot /path/to/godot --output-dir /tmp/panel-color --renderer gl_compatibility
python tools/validate_volume_opacity.py --godot /path/to/godot --output-dir /tmp/panel-opacity --renderer gl_compatibility
python tools/validate_volume_presets.py --godot /path/to/godot --output-dir /tmp/panel-presets --renderer gl_compatibility
python tools/validate_video.py --godot /path/to/godot --output-dir /tmp/panel-video --renderer gl_compatibility --overlay-ui
```

Use `--renderer forward_plus` for the native ownership/shell checks on Forward+.
No external research captures or scientific solvers are part of this validation.

Before accepting:

1. Launch at 1440×900 and open a mixed capture. Confirm the three named categories,
   distinguishable expanders, sibling Particle Filters, and no duplicate metadata.
   Verify no Tools window appears until requested.
2. Under Particles, exercise size, brightness, Point rendering, a type filter,
   scalar color/range and Advanced. Confirm fields/meshes retain their settings.
   Inspect the full type tooltip and use Recorded history [T].
3. Switch between multiple field objects, including a hidden one. Confirm the
   selected object stays hidden until explicitly enabled. Exercise color bounds,
   colormap, opacity mapping/strength and Ray step. Try enabling a second translucent
   volume; verify the existing refusal and unchanged first field.
4. Under Meshes, select each object and exercise visibility, wireframe, channel,
   colormap and bounds. Confirm particle/field and other mesh state are unchanged.
5. Open View → Global effects. Confirm Bloom is globally labeled and absent from
   every category; test existing viewing presets and return to normal controls.
6. Save/load scene and analysis state with a non-first object selected and a group
   collapsed. Verify exact restored values, selection state and current UI context.
   Recheck the accepted menu tools, Details, probe marker and source replacement.
7. Repeat at 1920×1080 and 1024×640. Scroll to every control; collapse/reopen groups,
   resize/hide/recover the panel, and test fullscreen/immersive keyboard and mouse
   recovery. Confirm fonts and input targets remain readable.
8. Export an image and short video with the overlay off/on; verify capture timing,
   scientific content and the category presentation limitations described above.

Stop for owner review. No merge, auto-merge, manual issue closure, Project-state
change or subsequent issue work is authorized by passing these checks.
