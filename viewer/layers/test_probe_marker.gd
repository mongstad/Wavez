extends SceneTree
const Viewer = preload("res://main.gd")
const Job = preload("res://video/render_job.gd")
var output := ""
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures.append(label);push_error(label)
func shot(viewer, name: String) -> Image:
	check(await viewer._capture_inspection_png(output.path_join(name+".png"),true) == OK,"PNG with sidecar: "+name)
	return Image.load_from_file(output.path_join(name+".png")).get_region(Rect2i(160,100,320,280))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-output="):output = arg.trim_prefix("--probe-output=")
	if output.is_empty():quit(1);return
	create_timer(120).timeout.connect(func():push_error("Probe test timeout");quit(1))
	var viewport := SubViewport.new();viewport.size = Vector2i(640,480)
	viewport.size_2d_override = Vector2i(1440,1080);viewport.size_2d_override_stretch = true
	viewport.own_world_3d = true;viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var viewer = Viewer.new();viewer.offline_instance = true;viewer.capture_path = output.path_join("volume.wvz");viewport.add_child(viewer);viewer.set_process(false)
	viewer.playing = false;viewer.orbit_enabled = false;viewer._apply_preset("Scientific")
	viewer.overlay_visible = false;viewer.overlay_panel.hide();viewer.shell.prepare_export({});viewer.scene_layers.frame_scene()
	var layers = viewer.scene_layers
	check(layers != null and viewer.frame_count == 2,"Fixture opened")
	check(layers.probe_marker_enabled and not is_instance_valid(layers.probe_marker),"No marker before first explicit probe")
	layers.set_probe_marker_enabled(false);layers.set_probe_marker_enabled(true)
	check(not is_instance_valid(layers.probe_marker),"Toggling before probe creates no phantom marker")
	var baseline: Image = await shot(viewer,"baseline")
	layers.probe_selected_volume()
	check(layers.probe_marker.name == "SourceProbeMarker" and layers.probe_marker.get_parent() == layers,"Identified source-probe owner")
	check(layers.probe_marker.visible and layers.probe_label.text.begins_with("value = ") and layers.probe_label.text.trim_prefix("value = ").to_float() == 12.0,"Explicit affine field probe equals source oracle")
	var result: String = layers.probe_label.text
	var vertices = layers.probe_marker.vertices.duplicate()
	var scientific: Dictionary = viewer.committed_sample.duplicate(true)
	var values = layers.views.field.data.channels.value.duplicate()
	var shown: Image = await shot(viewer,"shown")
	check(baseline.get_data() != shown.get_data(),"Shown cross appears in screenshot")
	Job.write_json(output.path_join("shown-state.json"),Job.snapshot(viewer))
	for repeat in 3:
		layers.set_probe_marker_enabled(false)
		check(not layers.probe_marker.visible and layers.probe_label.text == result and layers.probe_marker.vertices == vertices,"Hide retains last result and geometry")
		check(layers.views.field.probe(Vector3.ZERO) == 12.0 and layers.views.field.data.channels.value == values and viewer.committed_sample == scientific,"Visibility leaves source and sampling untouched")
		layers.set_probe_marker_enabled(true)
		check(layers.probe_marker.visible and layers.probe_marker.vertices == vertices,"Restore same marker without re-probing")
	layers.set_probe_marker_enabled(false)
	var hidden: Image = await shot(viewer,"hidden")
	check(hidden.get_data() == baseline.get_data(),"Hidden screenshot equals marker-free baseline")
	Job.write_json(output.path_join("hidden-state.json"),Job.snapshot(viewer))
	check(viewer._save_inspection(output.path_join("recipe.json")) == OK,"Save recipe")
	for enabled in [true,false]:
		layers.set_probe_marker_enabled(enabled)
		check(viewer._load_inspection(output.path_join("recipe.json")).is_empty(),"Restore recipe")
		check(layers.probe_marker_enabled == enabled and layers.probe_marker.visible == enabled and layers.probe_label.text == result,"Recipe rebuild preserves session visibility and result")
	for time in [1.0,0.0,.5]:
		viewer._seek_time(time)
		check(not layers.probe_marker.visible and layers.probe_label.text == result,"Seek keeps hidden last explicit probe")
	viewer.inspection_paused = false;viewer.playing = true;viewer.physical_rate = .2
	layers.tick(.1);viewer.playing = false
	check(viewer.requested_time > .5 and not layers.probe_marker.visible and layers.probe_label.text == result,"Playback advances without resurrecting or recomputing marker")
	viewer._seek_time(1.0);layers.probe_selected_volume()
	check(not layers.probe_marker.visible and layers.probe_label.text.trim_prefix("value = ").to_float() == 22.0,"New probe while hidden updates value but stays hidden")
	layers.set_probe_marker_enabled(true)
	check(layers.probe_marker.visible,"Restore latest hidden probe")
	layers.probe_spins[0].value = 100;layers.probe_selected_volume()
	layers.set_probe_marker_enabled(false);layers.set_probe_marker_enabled(true)
	check(not layers.probe_marker.visible and layers.probe_label.text == "Unavailable","Invalid probe cannot restore stale cross")
	layers.probe_spins[0].value = 0;layers.probe_selected_volume()
	check(layers.probe_marker.visible,"Valid probe recovers visibility")
	viewer._open_capture(output.path_join("volume.wvz"))
	check(viewer.scene_layers.probe_marker_enabled and not is_instance_valid(viewer.scene_layers.probe_marker) and viewer.scene_layers.probe_label.text.is_empty(),"Reopening starts a fresh probe session")
	Job.write_json(output.path_join("probe-report.json"),{"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()})
	viewport.queue_free();await process_frame
	print("PROBE: %d checks, %d failures" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
