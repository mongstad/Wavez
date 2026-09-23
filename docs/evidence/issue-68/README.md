# Issue #68 review evidence

**Pending owner review.** Small generated SSC fixtures only; no external research
captures or solver runs. Godot 4.7.2, NVIDIA RTX 3070 Ti. Baseline is owner-merged
PR #73, `3dddf71`. [Implementation and owner checks](../../UX4_PANEL.md).

| Check | Result |
|---|---|
| Native shell, Compatibility | 1,043 PASS; all visible control widths checked in all three categories; source hashes unchanged |
| Native shell, Forward+ | 1,043 PASS; same layout/state/menu/recovery checks; source hashes unchanged |
| Multi-object category ownership, Compatibility | 221 PASS; exact numeric ranges, isolation, refusal, context/session behavior; source hashes unchanged |
| Multi-object category ownership, Forward+ | 220 PASS; same ownership checks before the final unknown-type-label assertion; source hashes unchanged |
| Recipe state, headless | 2,697 PASS; exact values, legacy keys and session ownership |
| Field color, Compatibility | 138 PASS; NumPy oracles, refusals, GPU/recipe checks and verified export; source unchanged |
| Field opacity, Compatibility | 98 PASS; independent opacity behavior and source unchanged |
| Field Quick setup, Compatibility | 99 PASS; three preset exports verified; source unchanged |
| UI-overlay video, Compatibility | 111 PASS across five cases, including 1080p/4K, exact timing, repeated pixels and source unchanged |
| Scientific-only baseline comparison | Scientific and Cinematic pixel-identical against accepted main; see render-comparison.json |
| Final editor import, Python compilation, whitespace and local documentation links | PASS |

Native shell validation includes numerical export, v2/v3 scene/analysis restore,
source replacement, hidden-on-startup Tools, Details metadata, fullscreen/immersive
and hide/show recovery. It checks 1440×900, 1920×1080 and the 1024×640 fallback,
including logical 125%, 150% and 200% scale at compact size. This does not establish
physical mixed-DPI monitor support or long-session comfort.

The new ownership fixture contains one particle object, two fields and two meshes,
plus field-only and particle-only captures. Tests manipulate real UI controls and
compare other objects' dictionaries, particle/global state and exact floating-point
values. Category/object selection preserves the committed sample, source binding,
probe target and request serial; profiling detects no scientific work. Disclosure
checks reject nesting, and width checks detect controls extending past the dock.

## Native screenshots

| Category | 1440×900 | 1920×1080 | 1024×640 fallback |
|---|---|---|---|
| Particles | [View](loaded-1440.png) | [View](loaded-1920.png) | [View](loaded-1024.png) |
| Fields | [View](fields-1440.png) | [View](fields-1920.png) | [View](fields-1024.png) |
| Meshes | [View](meshes-1440.png) | [View](meshes-1920.png) | [View](meshes-1024.png) |

- [Particle Filters and Advanced](particles-advanced.png)
- [Field Opacity](field-opacity.png)
- [Global Bloom surface](global-effects.png) (native title-bar decoration is outside the image)

The size-matrix images use Forward+. The focused group images use Compatibility
and a different multi-object fixture. Small scene content is intentional. The
retained failed-open status in size-matrix screenshots belongs to the deliberate
failed-open durability test; it is not an unreported failure.

## Development failures and evidence corrections

- The initial import caught two missing explicit OptionButton types; corrected
  before native validation. The final import has no errors or warnings.
- The new fixture initially omitted the required mesh identity policy; corrected
  to `none`. An incorrect profiling-helper preload in the new test was corrected.
- The first ownership run compared Godot's float32 environment property with the
  slider's float64 value using exact equality. That assertion now uses the engine's
  float tolerance; exact scientific range comparisons remain unchanged.
- An initial before/after rendering attempt used an obsolete temporary fixture
  path and could silently render an empty viewer. That comparison was discarded.
  The corrected probe explicitly refuses an unloaded capture, uses a verified
  current fixture, and runs accepted main from a temporary archive without changing
  the implementation branch. Only the corrected comparison is retained here.

No failed run is counted as successful. Logs, runtime captures and videos remain
under `/tmp/simscope68-*`, outside Git. Historical #66/#67 evidence is unchanged.

## Limits and owner review

No full scientific regression suite, external captures, physical multi-monitor
checks, assistive-technology evaluation or long-session usability study was run.
Renderer equivalence is limited to the recorded fixture/settings. Existing volume
visibility and renderer limits remain. The export presentation schema is unchanged:
new field/mesh object choices are session-only and exports begin with the source's
initial object choice, while scientific state is restored independently.

The accepted #67 tools are retained; #69 composition, #70 full copy audit and #71
milestone acceptance are not part of this issue. Perform the eight explicit owner
checks in [UX4_PANEL.md](../../UX4_PANEL.md#validation-and-owner-review), then review
this issue alone. Passing tests do not grant acceptance or authorize merging.

## Rendering comparison probe

The following probe was run against the temporary accepted-main viewer archive and
the working viewer with the same `tests.g4.fixtures.scene` capture. Save it outside
the repository and pass output directory, then capture path after `--`.

```gdscript
extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var vp := SubViewport.new();vp.size = Vector2i(960,640);vp.own_world_3d = true;vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var viewer = load("res://main.gd").new();viewer.offline_instance = true;viewer.capture_path = OS.get_cmdline_user_args()[1];vp.add_child(viewer);viewer.set_process(false);viewer.playing = false;viewer.orbit_enabled = false
	if viewer.generic_reader == null or viewer.scene_layers == null:push_error("Comparison capture did not load");quit(1);return
	for preset in ["Scientific","Cinematic"]:
		viewer._apply_preset(preset);viewer.overlay_visible = false;viewer.show_legend = false;viewer.shell.prepare_export({});viewer._seek_time(.5)
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(output.path_join(preset+".png"))
	viewer.free();vp.queue_free();await process_frame;quit()
```
