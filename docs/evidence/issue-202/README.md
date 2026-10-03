# Issue #202 — mesh-only panel focus

Build 30 is proposed for owner review. A successful interactive open selects
**Meshes** only when every source object is a mesh and at least one mesh exists.
The decision uses source object kinds, so changing layer visibility cannot
change the selected category. Other scenes retain the previous category.
An explicit offline video-export workspace continues to take precedence.

The [Compatibility screenshot](mesh-only-initial-compatibility.png) shows the
initial mesh-only state: Meshes selected, the first mesh object in the selector,
and its Rendering and Color Mapping controls visible.

## Validation

- Source simulation-panel regression: 273 checks passed in Forward+ and 273
  in Compatibility. Generated particle-only, field-only, mesh-only and mixed
  `.ssc` source SHA-256 values were unchanged.
- The regression covers fresh mesh-only load, object controls, no empty
  Particles selection, reopening a mesh-only file, particle/field category
  preservation, mixed-scene category preservation, object-visibility changes,
  and a view-preset round trip.
- A temporary packaged Linux release passed mesh-only, particle-only,
  field-only and mixed-scene checks in both Forward+ and Compatibility.
- An isolated headless offline test opened a mesh-only file with an explicit
  Fields export workspace and confirmed that Fields remained selected.
- An early Compatibility test created a second temporary offline viewer in
  the GUI test process. Its assertions passed, but Godot emitted texture
  cleanup errors at shutdown. The offline assertion was moved to the isolated
  headless test; final source and packaged runs exited without those errors.

## Owner checks

1. Open a mesh-only `.ssc` in a clean viewer. Confirm **Meshes** is selected
   and its object list and controls appear without selecting the tab manually.
2. Choose another category, then open the mesh-only file again. Confirm the
   new load selects Meshes.
3. Open particle-only, field-only and mixed files. Confirm their existing
   category behavior is retained, including a category explicitly chosen
   before opening a mixed file.
4. Hide/show a mesh object and restore a view preset. Confirm neither action
   unexpectedly changes the category.

Physical owner interaction with the production desktop remains pending. No
large external scientific capture or physical mixed-DPI/4K display was used;
the focus policy was validated with small generated scenes.
