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

Portable view presets include the viewing-preset name and independent environment
Bloom on/off/intensity. Loading preserves those settings even for Scientific with
Bloom on or Cinematic with Bloom off; it does not reapply preset defaults or
infer the preset name from Bloom. A partial recipe without a name that explicitly
sets `clean_view` uses Scientific/Cinematic for that representation. Other omitted
settings stay unchanged. Loading is transactional and leaves application
preferences untouched; the explicit session view survives capture switching.
A subsequent manual preset selection recalls its stored Bloom pair, and a manual
Bloom edit saves the current pair. See [global Bloom and preference precedence](GLOBAL_BLOOM.md).

The [issue #138 review report](VIEW_PRESETS.md) preserves its original schema
names, test results and owner-review wording as historical evidence.
