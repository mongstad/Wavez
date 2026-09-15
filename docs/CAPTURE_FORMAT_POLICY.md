# Capture format policy

SimScope supports **SIMSCP3**, normally stored as **`.ssc`**, through
`SceneCapture` and `SceneReader`. This applies to the viewer, analysis, export,
examples, tools and integrations. See the [public API](../SIMSCOPE_API.md) and
[wire contract](../G3_FORMAT.md). Readers verify magic and version; renaming a
file cannot make an unsupported capture valid.

Package version **2.0.0** records the breaking transition to the SIMSCP3-only
public contract. Older writers, readers, dispatch and discovery paths are not part
of this fresh source snapshot. No in-place historical capture conversion is
provided by the current package.

Shared framing, typed arrays, exact int64 identity validation, checksums and
bounded codec helpers serve the native contract. Python stores these in
`simscope_export/storage.py` and `codec.py`. Godot's `data/capture_index.gd` now
contains only shared bounds, numeric validation, hashing and JSON helpers;
`typed_decode.gd` serves native particle preparation. Neither module scans an
older capture format. Source values, corruption refusal and cache limits remain
part of the supported scientific contract.

SIMSCP3 capture format, scene inspection v2, G4 inspection v3 and render jobs
v1/v2 are distinct contracts. Retiring old captures does not retire current
native inspection/export state. Reserved visual fields in existing native
recipes remain serializable without enabling any old capture workflow.

external simulation is an external validation/test simulation, not a supported SimScope
integration. It must not impose compatibility requirements on the product.
Current native benchmark integrations use explicit scene/object writers.

The cleanup awaits review before UX1. G5/G6, web, remote and AI work remain
outside this assignment.
