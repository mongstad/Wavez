# Independent layer legends — issue #37

Pending owner review. Issue #37 was the top Ready item on 2026-09-24.
The existing owner-linked branch is
`37-ux-legend-001-support-independent-legends-for-particle-and-volume-colormaps`,
based on accepted `main` at `d11e42690266afe24d21128cbca1f442d5a63e46` (PR #91).
Fetch/prune completed; the initial tree was clean and synchronized. No prior local
issue branch remained to remove.

## Controls and presentation

Particles retain their existing **Show legend** toggle under Color Mapping.
Each field and mesh object now has its own **Show legend** control under its
Color Mapping group. Select the object in its category to change that preference.
There is no new master switch that could hide the meaning of the existing toggle.

Only enabled, visible, available scalar-mapped layers produce legends. Hidden
layers, fixed mesh color, direct particle RGB/fixed color, unavailable samples,
and fields with neither volume nor slice rendering are excluded. An unavailable
logarithmic field does not leave a misleading legend. Existing rendering limits
remain: one translucent volume, with additional supported slices and meshes.
Derived fixed-color isosurfaces do not acquire a scalar legend.

Each entry identifies type/object ID, channel, colormap and active display bounds.
Particle text retains its normalization details and now includes its object ID.
Field and mesh cards use the canonical colormap LUT and layer bounds; field cards
also identify linear versus logarithmic mapping. Cards are ordered by capture
object order, including after a legend is hidden and restored.

The accepted #85/#91 particle legend remains at the lower-right of the available
scene area. Additional legends form a shared-theme card stack above it, or against
the same bottom margin when the particle legend is ineligible/disabled. The stack
is bounded to 40% of available scene height (and remaining space above the particle
legend) and scrolls when needed. Scroll inside the stack to reach later entries.
This avoids a hardcoded two-legend limit while keeping the viewport center free.
Visible panels and playback/status controls reserve space; Immersive uses the full
viewport and existing margins. Late text/layout changes reposition the stack.
The particle legend also uses the shared background/border with padded contents;
its outer card edge owns the clearance. See the [review refinement](LEGEND_CARD_REVIEW.md).

## Ownership, recipes and export

Field/mesh preferences live in `scene.legend_visibility`, keyed by object ID,
separately from rendering-layer dictionaries. Toggling one does not resample,
invalidate prepared meshes/fields, change mapping settings, alter committed
samples or write source data. Particle preferences retain the existing
`show_legend` recipe field. New captures start with eligible field/mesh legends
enabled; older recipes without the new map also default to enabled. Explicit
false values round-trip through JSON and synchronize rebuilt controls. Invalid
preference values or unknown object IDs are rejected by recipe validation.

Screenshots include currently visible cards. Video's **Include viewer overlays**
checkbox gates all legends; individual preferences and eligibility still apply.
Video starts the bounded stack at the top, so overflowing entries are not all
visible in one frame. Hide unwanted legends or use a larger output when needed.
The scroll offset is session presentation and is not a new recipe field.

## Validation

Godot 4.7.2, NVIDIA RTX 3070 Ti, native Linux desktop:

| Check | Result |
|---|---|
| New multi-layer regression, Forward+ | 33 PASS; source SHA-256 unchanged |
| New multi-layer regression, Compatibility | 33 PASS; source SHA-256 unchanged |
| Multi-layer MP4 export, Compatibility | One frame each with overlays ON/OFF, successful exits, distinct frame hashes, source unchanged; ON image inspected |
| Existing recipe-state suite, headless | 2,697 PASS |
| Existing first-open/panel/fullscreen legend regression, Forward+ | 989 PASS and 16 KWin geometry stages, source unchanged |
| Existing focused video-overlay suite, Forward+ | 111 PASS lines, including 62 native UX checks, deterministic repeated 1080p, 4K, overlay-off and workspace exports |
| Final editor import and whitespace checks | PASS; new script UIDs tracked |

The new fixture exercises a particle layer, two field layers (volume and slice),
and two scalar meshes together. It covers independent controls, rendering-state/
prepared-key invariance, JSON restoration, legacy defaults, malformed preferences,
scroll access, changed range labels, invalid-log exclusion, panel and Immersive
placement, hidden/fixed-color eligibility and offline overlay gating.
An initial harness run failed to parse two inferred dictionary variables; explicit
types fixed that test error. Subsequent runs passed. The KWin harness logged the
existing libdecor GTK fallback and Gio deprecation warnings. No native legend or
export script errors were reported in final runs.

Reproduce:

```sh
python tools/validate_layer_legends.py --godot /path/to/godot --output-dir /tmp/legends-forward
python tools/validate_layer_legends.py --godot /path/to/godot --output-dir /tmp/legends-package --renderer forward_plus --export
python tools/validate_recipe_state.py --godot /path/to/godot --output-dir /tmp/legends-recipes
python tools/validate_video.py --godot /path/to/godot --output-dir /tmp/legends-video --renderer forward_plus --overlay-ui
```

The existing `validate_immersive_desktop.py --legend-visibility` command in the
prior legend report supplies native window-state coverage. Run desktop tests
sequentially. Retained [summary](evidence/issue-37/summary.json) and screenshots
contain only synthetic evidence. Historical reports/evidence remain unchanged.

Production scientific captures, other operating systems, physical 4K monitor
acceptance, extremely large object counts and a full repository suite were not
run. The video 4K check is output resolution, not physical-monitor validation.

## Owner verification

1. Open a capture with particles and a visible field. Choose distinct scalar
   channels/colormaps (for example particle density/plasma and field psi_real/coolwarm).
   Confirm both legends identify the correct object, channel, map and bounds.
2. Under each category's Color Mapping, disable its Show legend. Only that
   layer's legend should disappear; scientific appearance and probes must remain
   unchanged. Enable it again.
3. Add supported slices or scalar meshes. Confirm additional cards appear and
   scroll to later entries if the stack overflows. Fixed-color and hidden layers
   should not leave cards behind.
4. Toggle panels, resize, enter Shift+F11 Immersive, then press Esc. Legends should
   clear panels/playback and retain their preferences, including on first open.
5. Save a recipe with different legend preferences, change them, and reload.
   Verify the restored checkboxes and displayed legends.
6. Save a screenshot and a short video with overlays ON, then OFF. Confirm ON
   includes the enabled visible legends and OFF excludes them.

Then review the PR. Acceptance and merging remain owner actions.
