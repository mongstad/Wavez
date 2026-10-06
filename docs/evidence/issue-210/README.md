# Issue #210 — initial Simulation category

Candidate build `v0.1.0.58` chooses the first source object kind in
**Particles → Fields → Meshes** order after a successful interactive file load.
The prior tab, object visibility and selected object do not enter that decision.
Issue #202's mesh-only behavior is included in this single policy. An offline
video-export viewer keeps its explicit workspace choice.

## Focused results

The [focused validation report](focused-validation.json) records **205 passing
checks across seven runs**: 49 each in source Forward+, source Compatibility,
packaged Forward+ and packaged Compatibility; 3 headless offline checks; and
3 checks for each of two real captures. The focused matrix covers all seven
declared-kind combinations, a different tab selected before each load and
reload, controls immediately available, visibility and object-selection
changes, a view-preset apply after load, a failed load, and isolated offline
export precedence. It ran on source and temporary Linux release packages in
both Forward+ and Compatibility. The headless offline case kept an explicitly
selected Fields workspace while loading particle-only, mesh-only and mixed
sources. Generated WVZ1 fixture hashes remained unchanged.

The existing Simulation panel regression also passed in
[Forward+](panel-forward-report.json) (**276 checks**) and
[Compatibility](panel-compat-report.json) (**276 checks**), including the original mesh-only
behavior, disclosures, object controls and selection ownership.

| Source objects | Initial category |
|---|---|
| Particles | Particles |
| Fields | Fields |
| Meshes | Meshes |
| Particles + Fields | Particles |
| Particles + Meshes | Particles |
| Fields + Meshes | Fields |
| Particles + Fields + Meshes | Particles |

Native screenshots were taken after the chosen tab and controls appeared:
[Particles](particles-initial.png), [Fields + Meshes → Fields](field-meshes-initial.png),
[Meshes](meshes-initial.png), and [all three → Particles](mixed-initial.png).

Two existing external simulation captures were opened read-only for their first
sample: `cavity_collapse_torus_quick.wvz` (real mesh-only source) and
`toroidal_throat_flow.wvz` (real particle + field source). The
[source descriptor summary](real-source-descriptors.json) records their declared
object kinds without decoding every payload. The
[mesh report](real-mesh-report.json) and
[particle + field report](real-particle-field-report.json) record the category
and visible controls. No real field-only capture was found in the inspected
locations; the generated field-only fixture covers that case. The large real
captures were not copied, modified, fully decoded, or hashed for payload
integrity. This test checks opening and category selection, not complete
scientific integrity or sustained playback.

## Owner verification

1. Open each available source-kind combination. Confirm its tab follows the
   table and its category controls appear as soon as loading completes.
2. Choose a different tab, then reopen or replace a file. Confirm the newly
   loaded source determines the tab, including mixed and mesh-only files.
3. Hide/show objects and switch selected objects. Confirm the tab does not
   change afterward. Apply a view preset after loading and confirm the
   deliberately chosen tab remains available.
4. Render a video using an explicit offline workspace and confirm that export
   presentation still uses that choice.

Physical owner interaction, other operating systems, mixed-DPI monitors and
long-running capture sessions were not exercised. The temporary package test
used installed external Godot export templates; no binary is committed.

The first source-editor import was sandbox-limited and reported editor socket
and settings errors. With normal desktop access, the first import regenerated
five unrelated cached UID files and warned about them; the unchanged retry
completed without errors or warnings. Those incidental UID files were removed.
The two new test scripts' UID sidecars are retained with their scripts.
