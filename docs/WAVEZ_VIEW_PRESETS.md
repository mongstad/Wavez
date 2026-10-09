# Portable WAVEZ view presets

State → **Save view preset…** and **Load view preset…** store portable
presentation settings in bounded UTF-8 JSON. The current kind is
`wavez-view-preset` with schema version 1. Save uses a new `.json` destination
and an atomic sibling temporary file; loading rejects other kinds, including
the former `simscope-view-preset` value. There is no legacy alias or conversion.

A view preset has no source pin, scientific array, selection result or video job.
An inspection bundle remains a separate source-bound contract with kind
`wavez-inspection` and a WVZ1 source identity. Applying a view preset preserves
the current scientific source and validates settings before changing live state.
See [inspection state](../INSPECTION_STATE.md) and [current format policy](CAPTURE_FORMAT_POLICY.md).

Saved environment settings determine whether decorative Bloom is on. After
loading, the viewing-preset checkmark follows that effective state: enabled
Bloom shows Cinematic; disabled Bloom clears a stale Cinematic label to
Scientific. Existing named scientific mappings remain selected when Bloom is
off. Loading does not reapply backdrop, fog, particle representation or other
preset defaults. Select Cinematic to enable the shared Global effects → Bloom
control; its visible effect depends on scene brightness and the renderer.
See [global Bloom behavior and review evidence](GLOBAL_BLOOM.md).

The [issue #138 review report](VIEW_PRESETS.md) preserves its original schema
names, test results and owner-review wording as historical evidence.
