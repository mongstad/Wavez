# Issue #67 review evidence

Pending owner review. Fresh small synthetic fixtures; no external captures or
solver runs. Godot 4.7.2 on NVIDIA RTX 3070 Ti. The implementation and exact owner
checks are in [UX4 menus](../../UX4_MENUS.md).

| Check | Result |
|---|---|
| Native shell/menu workflow, Forward+ | 492 PASS; source hashes unchanged |
| Native shell/menu workflow, Compatibility | 492 PASS; source hashes unchanged; full live 54-label hierarchy matches accepted design |
| Recipe ownership, headless | 2,737 PASS; exact v2/v3 values, legacy section keys and session state preserved |
| Existing maintenance form checks, headless | 28 PASS; focused-host reachability and widths |
| Probe marker, Forward+ | 33 PASS; screenshots and two four-frame MP4s retain identical marker-free video frames/timing; source hash unchanged |
| Volume Quick setup, Compatibility | 99 PASS; three preset exports verified; source unchanged |
| Video with UI overlay, Compatibility | 111 PASS; five export cases including 1080p/4K and repeatability; source unchanged |
| Final Godot editor import | PASS; no errors or warnings |
| Python compilation, documentation links, whitespace | PASS |

The shell suites include actual numerical export through the moved Data controls,
old-sidebar-path absence, tool navigation with no scientific activity, source
replacement, preset/marker routing, recipe/worker lifecycles, focus/fullscreen/
immersive recovery and the three required logical window sizes. The compact
1024×640 case also checks 125%, 150% and 200% content scale, not physical
mixed-monitor behavior. Named tool screenshots show only the content viewport;
native window decorations are outside that image.

## Native screenshots

- [1440×900 desktop](loaded-1440.png)
- [1920×1080 desktop](loaded-1920.png)
- [1024×640 fallback](loaded-1024.png)
- [Selection host](tool-selection.png)
- [Performance host](tool-performance.png)
- [Source probe host](tool-probe.png)

The sidebar still has the existing simulation-control layout; redesign belongs to
#68. Focused tools are minimal hosts around existing controls, pending final #69
composition. Sample scene content is deliberately tiny. The persistent failed
status in shell screenshots is the intentional failed-open durability test, not
an unreported validation failure.

## Failures caught during development

- The first sandboxed import logged local socket/editor-settings permission
  errors and caught a missing explicit GDScript type; it was not a clean pass.
- The first native shell run caught tool-close focus restoration during immersive
  entry and a test using the old immersive menu index. Both were corrected; final
  runs pass. That first Compatibility run also rebuilt a stale shader cache.
- The first recipe run found a test referring to the removed Free camera checkbox;
  its interaction was updated to the retained camera state and the rerun passed.

No obsolete test was treated as passing merely because its process exited zero.
No historical evidence was rewritten. Runtime captures, videos, caches and full
logs stay outside Git under the `/tmp/simscope67-*` validation directories.

Not validated: physical mixed-DPI/4K monitor use, assistive technology, long-session
comfort, external research captures, final #68/#69/#70 layout/composition/copy,
or the full scientific regression suite. These results do not grant acceptance.
