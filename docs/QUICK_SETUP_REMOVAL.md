# Quick setup removal — #160

Implementation is pending owner review. The sole Ready issue was #160; the owner-created branch started at accepted main `197ce0a` (PR #169). Candidate build is 15.

Tools no longer contains Quick setup, and no Quick setup form, layer body or target selector is built. No replacement dialog is introduced. Use Fields Color Mapping / Opacity and Tools Derive range for existing manual, symmetric and percentile actions. Scene Viewing presets and portable view presets remain available.

## Dependency audit

| Dependency | Disposition |
|---|---|
| Tools menu registration/enablement, form and target registration | Quick-setup-only; removed |
| `_build_preset_ui`, `_update_preset_description`, `preset_controls`, periodic descriptions, UI-only preset copy/constants | Quick-setup-only; removed |
| `shared_percentiles` and `share_percentiles` reparenting | Quick-setup-only integration; removed. Original percentile controls stay in Derive range |
| Quick setup UI assertions and screenshots in active tests | Removed; retained tests now call the reusable preset API directly |
| `VolumePresets.problem/resolve`, IDs, `request_volume_preset`, async range worker and optional preset resolution | Retained reusable calculations; exercised by scientific oracle, recipe and export regression tests. No current UI launcher |
| Field/channel/sample state, color normalization and opacity mapping, symmetric/percentile derivation, resets | Shared active functionality; retained |
| `sync_preset_controls` | Retained: portable view preset restoration calls it to update field/mesh panel controls; it is unrelated to the removed chooser |
| Scene Viewing presets, portable view presets and recipe/render state | Shared active functionality; retained |
| Scenes/resources/shortcuts | No separate Quick setup scene/resource or shortcut found; generated controls belonged to the shared Tools host |

No unclear external dependency was identified. Programmatic preset calculations remain callable rather than being removed with their UI. Current handbook/status explain the removal; historical UX design/review documents, screenshots and evidence remain unchanged. The shell validator excludes the retired entry when comparing the historical menu contract with current runtime menus.

## Owner verification

1. Launch without a capture on Forward+ and Compatibility. Open Tools: Quick setup must be absent; startup must be clean.
2. Open a mixed capture and a field-only capture. Check Tools again; no Quick setup route should appear.
3. In Fields, change channel, manual color bounds/colormap and opacity; confirm those controls still work. Open Derive range, edit percentiles, close/reopen, then freeze percentile and symmetric ranges. Confirm color and opacity reset scopes remain separate.
4. Open Slice, Clipping, Isosurface and Source probe and switch field targets. Verify ordinary playback, probe and recipe restoration.
5. Save/load a portable view preset and select a scene Viewing preset. Confirm these existing features remain available.

## Validation

Godot 4.7.2 on Linux passed the following on both Forward+ and Compatibility:

| Suite | Forward+ | Compatibility |
|---|---:|---:|
| Focused Tools, including absent form/menu/body and retained percentile draft | 1,904 PASS | 1,904 PASS |
| Viewer shell, current menu contract and startup/lifecycle | 665 PASS | 665 PASS |
| Retained volume preset calculations, NumPy oracles and recipes | 92 PASS | 92 PASS |
| Volume color policies through Derive range buttons, NumPy oracles and recipes | 138 PASS | 138 PASS |

Each renderer also passed three preset exports and one color-policy export with
identical rendered pixels and resolved state in inspection sidecars. All fixture
hashes remained unchanged. Logs passed the validators' error/warning checks.
Documentation local links and all three executable API examples passed;
application-version tests passed 2/2, generated notices matched canonical sources,
and `git diff --check` passed. Runtime code has no removed Quick setup references;
remaining occurrences are negative regression assertions and the shell validator's
historical-contract exclusion.

Validation used small synthetic fixtures. Production captures, long sessions,
physical mixed-DPI/4K displays and a packaged Linux build were not tested for this
issue. No owner acceptance is claimed here.
