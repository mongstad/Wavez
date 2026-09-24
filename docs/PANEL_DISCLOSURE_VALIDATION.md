# Simulation-panel launch defaults — issue #84

Implemented on the existing owner-linked branch
`84-reset-simulation-panel-expanders-only-on-app-launch`, pending owner review.
#84 was the only Ready item verified on 2026-09-24. HEAD, local main and origin/main
began at `f74a11f`, the owner-merged PR #88. Fetch/prune completed; the tree was
clean and the previous local issue branch was already absent. No additional
predecessor dependency is specified by #84.

## Change and ownership

Particle Rendering and Color Mapping previously began expanded. Field/mesh groups
also defaulted to expanded each time the layer controller was created. All now
default to collapsed in a fresh application session.

Particle controls already survive capture replacement. Field/mesh controls are
recreated, so their toggle values are retained in a viewer-owned session dictionary
keyed by category, source object ID and group title. Recreated matching groups use
that value; unseen groups start collapsed. Temporarily absent objects retain their
choices when reintroduced during the same session. A fresh viewer process begins
with an empty dictionary. There is no capture-import/rebuild collapse-all action.

Field/mesh disclosures remain outside scene/analysis recipes. Particle `sections`
already belongs to visual recipe state: explicitly restored values are still
honored, rather than forcibly collapsed. Recipe schemas, scientific state,
controllers, rendering algorithms and tool-dialog disclosures are unchanged.

## Validation

Godot 4.7.2, NVIDIA RTX 3070 Ti; small synthetic particle, multi-field and multi-mesh
SIMSCP3 fixtures. [Machine summary](evidence/issue-84/summary.json).

| Gate | Result |
|---|---|
| Forward+, fresh empty launch then capture open | 259 checks PASS |
| Forward+, separate fresh launch directly into capture | 269 checks PASS |
| Compatibility, fresh launch directly into capture | 269 checks PASS after cache warm-up |
| Existing headless v2/v3 recipe-state suite | 2,697 checks PASS |
| Capture SHA-256 before/after | Unchanged in each successful panel run and recipe run |
| Godot import, Python syntax, Git whitespace | PASS |

The panel checks exercise every initial group, a mix of open/closed groups,
repeated category and object switching, matching groups in a different capture,
replacement through particle-only and field-only captures, missing/reintroduced
layers, and recipe-driven layer-control rebuilding. Explicit particle disclosure
restoration is checked separately. New processes independently verify that prior
session choices do not become launch defaults. Existing panel tests also retain
scientific control ownership, numeric precision, refusal and recipe compatibility
coverage. The recipe gate covers repeated scene/v3 analysis restoration.

Commands (each output directory must be new):

```sh
python tools/validate_simulation_panel.py --godot /path/to/Godot --output-dir /tmp/panel-empty --renderer forward_plus
python tools/validate_simulation_panel.py --godot /path/to/Godot --output-dir /tmp/panel-startup --renderer forward_plus --startup-capture
python tools/validate_simulation_panel.py --godot /path/to/Godot --output-dir /tmp/panel-compatibility --renderer gl_compatibility --startup-capture
python tools/validate_recipe_state.py --godot /path/to/Godot --output-dir /tmp/panel-recipes --renderer headless
```

## Failures and limitations

The first Compatibility run passed all 269 assertions but the strict runner
rejected `Failed to load cached shader, recompiling.` The unchanged warm-cache
rerun passed without warnings or errors. All other listed gates passed on their
first run. This initial warning is retained in the machine summary.

Tests use synthetic fixtures and automated native UI callbacks. Production
research captures, long sessions with many distinct object IDs, cross-platform
desktop checks and full video/export regression suites were not rerun. No
scientific solver was run. Object IDs intentionally identify matching logical
groups across captures; newly named objects receive fresh collapsed defaults.
The session dictionary is not persisted and lasts only for the current viewer.

Current panel and current-status documentation was updated. Historical review
reports, including #68, #86 and earlier evidence, were left untouched.

## Owner verification

1. Launch SimScope without a capture, then open one containing particles, fields
   and meshes. Visit each category and object; every group should start collapsed.
2. Open a mix of Rendering, Color Mapping, Opacity, Particle Filters and Advanced
   groups. Leave some closed. Switch categories and field/mesh objects repeatedly;
   each group's chosen state should remain.
3. Replace the capture with another containing matching object IDs. Verify choices
   persist. Open a particle-only capture, then the mixed capture again; field/mesh
   choices should return when their objects reappear.
4. Save and restore scene/analysis state. Field/mesh disclosures should retain
   their current session choices; explicitly saved particle section values should
   restore according to the existing recipe contract.
5. Quit and relaunch directly into a capture. All category groups should start
   collapsed again. Confirm tool-dialog behavior and scientific controls remain
   unchanged.

Owner acceptance and merge remain pending; stop after review handoff.
