# Native scene inspection

Ordinary State → Save/Load view preset uses the separate [portable presentation
contract](docs/WAVEZ_VIEW_PRESETS.md). This document describes retained scientific
inspection/sidecar and analysis-bundle APIs, not the ordinary preset workflow.

Inspection operates on WVZ1 particles, meshes and scalar fields with independent
source clocks. Scene recipes use version 2; G4 durable inspection uses version 3
with exact selections, groups, analysis results, bookmarks and source provenance.
These state versions are independent of the capture format. See
[G4 schemas](docs/ANALYSIS_SCHEMAS.md), [the G4 guide](docs/ANALYSIS_GUIDE.md) and
[the handbook](docs/WAVEZ_HANDBOOK.md).

Playback uses recorded time only. Recipes retain the exact signed `physical_rate`;
`time_mode`, `playback_fps` and the index-rate slider are no longer state fields.
Recipes containing these obsolete fields are rejected without migration. Sample
indices remain available for navigation and exact lookup.

## Try a native scene

```sh
python -m examples.scene_demo --small --output results/inspection-scene.wvz
# Use a fresh output filename on later runs.
godot --path viewer -- --capture=/absolute/path/to/results/inspection-scene.wvz
```

Pause, seek a physical time, select a particle mapping or field slice, and inspect
the layer source times. Explicit particle IDs and stable mesh topology permit
matched position interpolation. Anonymous particles and scalar/field values hold
their source samples. The timeline slider addresses the union of recorded sample
times. Unknown geometry remains unknown; display guides do not define a domain.

Use Copy Inspection State or Save inspection recipe for the current sample and
visual state. Enable PNG inspection JSON sidecars to bind a screenshot to its
source hash, committed extent, layer sampling, geometry and mappings. The first
Save PNG action chooses a destination; cancelling writes nothing. That destination
lasts for the current session only.

G4 selection-aware inspection uses the durable workflow described in the G4 guide.
Restore validates source identity, exact sampling, selected assets and state before
applying the recipe. An appended capture does not expand a saved committed prefix.
Missing, changed or corrupt source data must be refused rather than relabeled.

## Recipe ownership and restore behavior

Recipes describe a saved inspection, not every current-session preference. v2
and the visual portion of v3 own the following settings:

| Area | Saved settings |
|---|---|
| Particle representation | Point rendering, size, exposure, brightness, gamma, intensity cutoff, slicing and slice position, particle-layer visibility, recorded history, hidden particle types |
| Mapping | Color/size/brightness channels, colormap, automatic/manual/interval normalization, range bounds, log/cyclic/invert/clamp switches, legend, remembered channel preferences |
| Camera and clock | Camera transform/target, distance/yaw/pitch, FOV/near/far/aspect policy, orbit switch/speed, time mode, index playback FPS, physical rate, and saved inspection sample/time |
| Environment | Preset label, starfield visibility, background mode, glow enable/intensity/strength/bloom, fog enable/density, tonemap mode/exposure/white |
| Viewport | MSAA, screen-space AA, TAA, debanding, rendering scale |
| Guides and layout | Geometry override, domain/data/absorber/imposed visibility, reference grid, inspector width/visibility, named inspector section expansion, visual slider positions |
| Layers | GPU budget and per-layer channel, range, colormap, visibility, mesh wireframe, volume/ray/slice/clip/isosurface parameters |
| Layer legend presentation | `scene.legend_visibility` maps field/mesh object IDs to independent boolean preferences; particle visibility retains `show_legend`. Missing preferences in older recipes default to enabled for eligible layers. These preferences are separate from rendering-layer state and do not invalidate prepared data. |

The reserved `mode` and `observer_scale` fields and inert intensity-cutoff slider
remain readable for compatibility. A viewing-preset label is restored as a
label; it does not reapply preset defaults over explicitly saved settings. Point
rendering and the environment remain independent, including Bloom availability.
Control widgets must reflect the restored values without firing edit callbacks.

Volume layers also save `opacity_mapping` with `mode` (`linear` or `magnitude`),
`lower` (zero-opacity threshold) and `upper` (full-opacity threshold), independently
of color `lower`/`upper` and the existing opacity strength. v2 recipes, v3 exact
state and video jobs retain these settings. Older volume states without the whole
mapping field migrate to linear opacity using their saved color bounds; subsequent
color edits no longer change extinction. Partial/invalid mappings are refused by
recipe validation before applying state. Reset restores only the opacity mapping
to linear 0–1. [Mapping details](docs/VOLUME_OPACITY_MAPPING.md) explain threshold
validation and float32 preview limits; numerical probes still use source values.

Volume `color_mapping` independently records `normalization` (`linear`/`log`),
`policy` (`manual`/`symmetric`/`percentile`), percentile endpoints and the derivation
source channel/time. Resolved bounds remain in the layer's `lower`/`upper` fields.
All three policies are frozen: restore and playback use saved bounds without
recomputing percentiles. Manual edits replace the derivation policy with manual;
reset restores only linear color 0–1. Older states missing the whole field migrate
to frozen manual linear color, preserving their bounds and opacity. Partial or
invalid mapping objects are refused. Source-dependent log validity is checked on
each prepared sample; invalid views are explicitly unavailable and video exports
fail rather than publishing blank field frames. See the
[color contract](docs/VOLUME_COLOR_NORMALIZATION.md).

Volume display presets save no preset identifier. They resolve into the existing
`lower`, `upper`, `color_mapping`, `opacity_mapping` and `colormap` fields; v2/v3
recipes and video jobs reproduce those values without rerunning a sample scan.
Selecting an action without applying it changes no saved state. Later manual
edits remain authoritative. Opening defaults and legacy migration are unchanged.
See [display preset semantics](docs/VOLUME_DISPLAY_PRESETS.md).

v3 additionally owns selection definitions/groups/active selection/overlay
settings and the saved analysis summaries, result references, comparison
bindings, bookmarks and selected-series/member-address layout. Numerical results
are restored from validated assets, not recomputed or derived from rendered
pixels. v2 does not restore G4 selections or analysis.

Session-only settings remain at their current values: screenshot destination and
sidecar preference, free-camera input mode, playback loop and RAM-buffer policy,
probe target/coordinates/last result/marker visibility and layer-settings disclosure buttons,
unsaved selection/query drafts, and export destinations/limits. Recipes also do
not own window/fullscreen state, input focus or scroll positions. Source probe
text/markers represent the last explicit probe; loading a recipe does not run a
new probe. Rebuilt layer controls preserve that session context. **View → Probe
marker** hides only the source-probe cross; screenshots include it only
when shown. PNG sidecars/recipes do not serialize this session-only marker or
its visibility, and deterministic video workers do not include it. Reopening a
capture starts a fresh probe session with visibility enabled but no marker until
a valid explicit probe.

Restore intentionally pauses playback and automatic camera motion; the saved
orbit switch remains represented, and explicit playback/orbit actions can resume
motion. Analysis plots are cleared until explicitly requested again, while saved
result references remain available. Required top-level visual fields must be
present or the recipe is refused before mutation. Within the existing partial
`environment`, `guide_visibility` and `sections` dictionaries, omitted members
leave current values untouched. An empty dictionary is not a request to enable
Cinematic defaults. Legacy video-job state that entirely omits `environment`
retains its earlier Point-rendering-based environment defaults; current v2/v3
inspection recipes require that top-level dictionary.

### STATE-001 investigation

Controlled complete v2 payloads restored their visual values correctly in both
Scientific and Cinematic modes (allowing ordinary JSON numeric rounding). The
following independent defects were reproduced before the fix:

- Restored section bodies could be closed while their toggle buttons stayed on.
- v3 selection overlay values could disagree with the Show hidden selection checkbox.
- Rebuilding layer controls cleared session probe coordinates/results and closed
  layer-settings disclosures.
- Accepted partial environment dictionaries ran the preset helper first: with
  Point rendering off this enabled unsaved bloom/fog and a sky background; with
  Point rendering on it disabled those settings. Partial guide dictionaries
  replaced required live entries and caused script errors.

These findings do not identify the exact settings seen in the original owner
report, which were not available. The regression records a field-by-field
inventory for complete v2/v3 payloads, repeated save/load cycles, session-owned
settings and partial-field behavior. It also verifies unchanged capture bytes.

## Regression checks

```sh
python -m unittest discover -s tests -v
python tools/validate_maintenance_ui.py --godot /path/to/godot --output-dir results/check-inspection
python tools/validate_video.py --godot /path/to/godot --output-dir results/check-video --renderer forward_plus
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir /tmp/check-recipes --renderer headless
```

Run the recipe check with `--renderer forward_plus` in a
graphics session for native GPU coverage. Use a fresh output directory per run;
`recipe-state-report.json` records every compared visual field and any mismatch.

Use fresh directories. Actual screenshots/video require a graphics session and
FFmpeg for MP4 encoding. Current inspection and export validation is recorded in
the maintained regression tools and reports; retired formats are not current guidance.

### Local video frame state (#116)

Ordinary video-export sidecars use `source.kind = "wavez-export-source"` with
UUID/header fingerprints, committed extent/counts and a high-resolution local
filesystem stamp. They restore only against the same unchanged local source;
they do not require a whole-source payload hash. This avoids an implicit extra
100+ GiB pass when frame JSON is enabled. Explicit portable inspection recipes
retain their existing SHA-256 contract. See [VIDEO_EXPORT.md](docs/VIDEO_EXPORT.md).
