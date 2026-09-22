# PR #73 metadata correction

Pending owner review. This correction removes the duplicated capture header and
verbose diagnostics shown in the owner's screenshots. Earlier issue-67 evidence
remains unchanged and describes the pre-correction checkpoint.

- Native Compatibility shell: **504 checks PASS**, including existing menu, state,
  numerical export, source replacement and viewport recovery checks. Added checks
  confirm metadata takes no panel space, Details retains exact layer/color text,
  and opening Details preserves scientific state and the committed sample.
- Volume color regression: **138 checks PASS**, including NumPy clipping oracles,
  concise warning agreement, clearing stale hidden-layer warnings, invalid future
  sample indication, recipes, GPU results and verified export. Source unchanged.
- Final Godot import and whitespace checks: PASS.

Small synthetic fixtures only. No external capture or scientific solver rerun.
Compatibility was rerun for this correction; earlier Forward+ and other suite
results apply to the previous checkpoint, not a fresh rerun of this correction.
Physical mixed-DPI and long-session usability remain unverified.

## Screenshots

- [1440×900 panel](loaded-1440.png)
- [1920×1080 panel](loaded-1920.png)
- [1024×640 fallback](loaded-1024.png)
- [Expanded field controls](metadata-field.png)
- [Source details](metadata-details.png)

The failed-open notice visible in some screenshots is the deliberate regression
case. The Details dialog is a snapshot refreshed when opened; its scrollable text
preserves the full metadata. Source names in controls remain exact. No controls
were regrouped or reordered; only metadata space was removed. #68 remains gated.

Run the existing `validate_viewer_shell.py` and `validate_volume_color.py` with
`--renderer gl_compatibility`, an external `--godot` executable and fresh
`--output-dir` directories. Full logs and generated exports remain under
`/tmp/simscope67-metadata-*`, outside Git.

Owner checks are in [UX4 menus](../../../UX4_MENUS.md#exact-owner-verification),
including the metadata correction check. These results do not grant acceptance.
